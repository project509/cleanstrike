# cleanstrike-loader-version: 1.2.0
# Cleanstrike in-game loader for Road to Vostok (Godot 4.6+).
# Registered by override.cfg as the first autoload. Everything that has to
# happen before the game's own scripts load runs in _init().
#
# Files it reads (written by the Cleanstrike app):
#   <game>/Cleanstrike/active.json         load order + enabled mods
#   <game>/Cleanstrike/mods/*.csmod|vmz|zip mod archives
#   <game>/Cleanstrike/settings/<id>.json  per-mod settings
#   <game>/Cleanstrike/disabled            (empty file) boot vanilla
# Files it writes (read by the app):
#   user://cleanstrike/last_launch.json    what loaded, what failed and why
#   user://cleanstrike/boot.json           crash guard state
#   user://cleanstrike/cleanstrike.log     plain-text log
extends Node

const LOADER_VERSION := "1.2.0"
const API_VERSION := 1
const ARCHIVE_EXTS := ["csmod", "vmz", "zip", "pck"]
const BOOT_OK_SECONDS := 20.0
const CRASH_LIMIT := 2

var game_dir := ""
var cs_dir := ""
var user_dir := "user://cleanstrike"
var game_version := ""
var godot_version := ""
var safe_mode := false
var safe_mode_reason := ""
var mods: Array[Dictionary] = []      # one entry per mod considered, in load order
var loaded_ids: PackedStringArray = []
var _log_lines: PackedStringArray = []
var _boot_cleared := false
var _settings_cache := {}
var _swaps := {}                     # vanilla Script -> mod Script, for class_name scripts


func _init() -> void:
	Engine.set_meta("Cleanstrike", self)
	game_dir = OS.get_executable_path().get_base_dir()
	cs_dir = game_dir.path_join("Cleanstrike")
	game_version = str(ProjectSettings.get_setting("application/config/version", "unknown"))
	var v := Engine.get_version_info()
	godot_version = "%d.%d.%d" % [v.major, v.minor, v.patch]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user_dir))
	_log("Cleanstrike loader %s | game %s | Godot %s" % [LOADER_VERSION, game_version, godot_version])
	_log("Game folder: " + game_dir)

	var boot: Dictionary = _read_json(user_dir.path_join("boot.json"), {})
	var crashes := int(boot.get("crashes", 0))
	if bool(boot.get("pending", false)):
		crashes += 1
		_log("Previous launch did not finish booting (%d in a row)." % crashes)
	else:
		crashes = 0

	var active: Dictionary = _read_json(cs_dir.path_join("active.json"), {})
	if FileAccess.file_exists(cs_dir.path_join("disabled")):
		safe_mode = true
		safe_mode_reason = "disabled_file"
	elif "--cleanstrike-vanilla" in OS.get_cmdline_user_args() or bool(active.get("vanilla", false)):
		safe_mode = true
		safe_mode_reason = "vanilla"
	elif crashes >= CRASH_LIMIT:
		safe_mode = true
		safe_mode_reason = "crash_guard"
		crashes = 0

	_write_json(user_dir.path_join("boot.json"), {"pending": true, "crashes": crashes, "time": Time.get_datetime_string_from_system()})

	if safe_mode:
		_log("Safe mode (%s): no mods will load." % safe_mode_reason)
	else:
		_load_mods(active)
	_write_report()


func _ready() -> void:
	# Mark the boot as healthy once the game has run for a while.
	get_tree().create_timer(BOOT_OK_SECONDS, true, false, true).timeout.connect(_clear_boot_flag)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_clear_boot_flag()


func _clear_boot_flag() -> void:
	if _boot_cleared:
		return
	_boot_cleared = true
	_write_json(user_dir.path_join("boot.json"), {"pending": false, "crashes": 0, "time": Time.get_datetime_string_from_system()})
	_log("Boot marked healthy.")
	_flush_log()


# ---------------------------------------------------------------- loading

func _load_mods(active: Dictionary) -> void:
	var mods_dir := cs_dir.path_join("mods")
	var queue: Array[Dictionary] = []
	if active.has("mods"):
		for entry in active["mods"]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var path := mods_dir.path_join(str(entry.get("file", "")))
			queue.append({"file": str(entry.get("file", "")), "path": path, "enabled": bool(entry.get("enabled", true)), "expected_id": str(entry.get("id", ""))})
	else:
		# No profile written yet: load every archive in the mods folder.
		for f in DirAccess.get_files_at(mods_dir):
			if f.get_extension().to_lower() in ARCHIVE_EXTS:
				queue.append({"file": f, "path": mods_dir.path_join(f), "enabled": true, "expected_id": ""})

	# Read manifests first so the fallback order can honour priority.
	for q in queue:
		var m := {"file": q.file, "path": q.path, "id": q.expected_id, "name": q.file, "version": "", "status": "pending", "reason": "", "enabled": q.enabled}
		if not FileAccess.file_exists(q.path):
			m.status = "missing"
			m.reason = "Mod file not found: " + q.file
		elif q.path.get_extension().to_lower() != "pck":
			var cfg := _read_manifest(q.path)
			if cfg == null:
				m.manifest = null
			else:
				m.manifest = cfg
				m.id = str(cfg.get_value("mod", "id", m.id if m.id != "" else q.file.get_basename()))
				m.name = str(cfg.get_value("mod", "name", m.id))
				m.version = str(cfg.get_value("mod", "version", ""))
				m.priority = int(cfg.get_value("mod", "priority", 0))
		mods.append(m)
	if not active.has("mods"):
		mods.sort_custom(func(a, b): return int(a.get("priority", 0)) < int(b.get("priority", 0)))

	for m in mods:
		if m.status != "pending":
			continue
		if not m.enabled:
			m.status = "disabled"
			continue
		_load_one(m)

	var ok := 0
	for m in mods:
		if m.status == "loaded":
			ok += 1
	_log("%d of %d mod(s) loaded." % [ok, mods.size()])


func _load_one(m: Dictionary) -> void:
	var cfg: ConfigFile = m.get("manifest")
	var problem := _check_compat(cfg)
	if problem != "":
		m.status = "incompatible"
		m.reason = problem
		_log("[%s] skipped: %s" % [m.id, problem])
		return
	if cfg != null:
		for dep in cfg.get_value("dependencies", "required", []):
			if not (str(dep) in loaded_ids):
				m.status = "failed"
				m.reason = "Needs mod '%s' loaded before it." % dep
				_log("[%s] skipped: %s" % [m.id, m.reason])
				return

	if not ProjectSettings.load_resource_pack(_mountable_path(m), true):
		m.status = "failed"
		m.reason = "Could not mount the archive (corrupt or not a zip/pck)."
		_log("[%s] %s" % [m.id, m.reason])
		return

	if cfg != null:
		var err := _apply_extends(m, cfg)
		if err != "":
			m.status = "failed"
			m.reason = err
			_log("[%s] failed: %s" % [m.id, err])
			return
		_spawn_autoloads(m, cfg)

	m.status = "loaded"
	loaded_ids.append(m.id)
	_log("[%s] loaded (v%s)." % [m.id, m.version])


# Godot only mounts files ending in .zip/.pck, so other archive extensions
# are mounted through a cached .zip copy (refreshed when the source changes).
func _mountable_path(m: Dictionary) -> String:
	var ext := str(m.path).get_extension().to_lower()
	if ext == "zip" or ext == "pck":
		return m.path
	var cache_dir := user_dir.path_join("cache")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	var cached := ProjectSettings.globalize_path(cache_dir.path_join(str(m.file).get_basename() + ".zip"))
	var src_time := FileAccess.get_modified_time(m.path)
	var src_size := FileAccess.get_size(m.path)
	if not FileAccess.file_exists(cached) or FileAccess.get_modified_time(cached) < src_time or FileAccess.get_size(cached) != src_size:
		DirAccess.copy_absolute(m.path, cached)
	return cached


func _check_compat(cfg: ConfigFile) -> String:
	if cfg == null:
		return ""
	var api := int(cfg.get_value("cleanstrike", "api", API_VERSION))
	if api > API_VERSION:
		return "Needs a newer Cleanstrike (mod API %d, this loader has %d). Update Cleanstrike." % [api, API_VERSION]
	var gmin := str(cfg.get_value("cleanstrike", "game_min", ""))
	var gmax := str(cfg.get_value("cleanstrike", "game_max", ""))
	if gmin != "" and compare_versions(game_version, gmin) < 0:
		return "Needs game version %s or newer (you have %s)." % [gmin, game_version]
	if gmax != "" and compare_versions(game_version, gmax) > 0:
		return "Supports game versions up to %s (you have %s)." % [gmax, game_version]
	var godot_min := str(cfg.get_value("cleanstrike", "godot_min", ""))
	if godot_min != "" and compare_versions(godot_version, godot_min) < 0:
		return "Needs a game built on Godot %s or newer." % godot_min
	return ""


# Replace vanilla scripts with mod scripts that extend them. Each mod is
# all-or-nothing: if one of its scripts fails to compile against this game
# version, the ones already applied are rolled back.
#
# Two strategies:
#  - Scripts without a class_name: take_over_path, so every later load of the
#    vanilla path gets the mod script. Several mods can chain this way.
#  - Scripts with a class_name (Item, LootContainer, ...): taking over their
#    path breaks Godot's `is ClassName` checks in every script compiled
#    afterwards (they silently degrade to the native base type). Instead the
#    mod script is swapped onto each node using the vanilla script as it
#    enters the tree, keeping its variables. Instances still pass `is Item`.
func _apply_extends(m: Dictionary, cfg: ConfigFile) -> String:
	var section := ""
	for s in ["script_extend", "script_overrides"]:
		if cfg.has_section(s):
			section = s
			break
	if section == "":
		return ""
	var applied: Array = []   # [kind, target_path, script]
	var deferred := _deferred_targets(m, cfg)
	for target in cfg.get_section_keys(section):
		if target in deferred:
			_log("[%s] leaves %s to %s." % [m.id, target, cfg.get_value("cleanstrike", "defer_to", "")])
			continue
		var ext_path := str(cfg.get_value(section, target))
		var fail := ""
		if not ResourceLoader.exists(target):
			fail = "The game no longer has %s." % target
		elif not ResourceLoader.exists(ext_path):
			fail = "Missing file %s inside the mod." % ext_path
		else:
			var base = load(target)
			var ext = load(ext_path)
			if ext == null or not (ext is Script) or not ext.can_instantiate():
				fail = "%s does not compile against this game version (see godot.log)." % ext_path.get_file()
			elif ext.get_base_script() != base:
				fail = "%s must start with: extends \"%s\"" % [ext_path.get_file(), target]
			elif String(base.get_global_name()) != "":
				var prev = _swaps.get(base)
				if prev != null:
					fail = _chain_onto(ext, target, prev)
				if fail == "":
					applied.append(["swap", target, base, prev])
					_swaps[base] = ext
			else:
				ext.take_over_path(target)
				applied.append(["path", target, base, null])
		if fail != "":
			for i in range(applied.size() - 1, -1, -1):
				var a = applied[i]
				if a[0] == "path":
					a[2].take_over_path(a[1])
				elif a[3] != null:
					_swaps[a[2]] = a[3]
				else:
					_swaps.erase(a[2])
			return fail
	m.extends_applied = applied.size()
	if not _swaps.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
	return ""


# Several mods extending the same class_name script: point this mod's
# script at the previous mod's version (instead of vanilla) and recompile,
# so nodes get one chain with every mod's changes, like path takeover gives.
func _chain_onto(ext: Script, target: String, prev: Script) -> String:
	var src: String = ext.source_code
	var line := 'extends "%s"' % target
	var at := src.find(line)
	if at < 0:
		return "%s can't be combined with other mods (no source to chain)." % ext.resource_path.get_file()
	ext.source_code = src.substr(0, at) + 'extends "%s"' % prev.resource_path + src.substr(at + line.length())
	if ext.reload(true) != OK or ext.get_base_script() != prev:
		ext.source_code = src
		ext.reload(true)
		return "%s doesn't combine with %s from another mod (see godot.log)." % [ext.resource_path.get_file(), prev.resource_path]
	_log("  %s chained onto %s" % [ext.resource_path, prev.resource_path])
	return ""


# A mod can step aside for another one: [cleanstrike] defer_to="other_id"
# and defer_targets=[...] skip those extensions when the other mod is
# enabled in this launch, whatever the load order.
func _deferred_targets(m: Dictionary, cfg: ConfigFile) -> Array:
	var other := str(cfg.get_value("cleanstrike", "defer_to", ""))
	if other == "":
		return []
	for o in mods:
		if o.id == other and o.enabled and o.status in ["pending", "loaded"]:
			return cfg.get_value("cleanstrike", "defer_targets", [])
	return []


func _on_node_added(node: Node) -> void:
	var s = node.get_script()
	if s == null:
		return
	var ext = _swaps.get(s)
	if ext == null:
		return
	var saved := {}
	for p in s.get_script_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			saved[p.name] = node.get(p.name)
	node.set_script(ext)
	for k in saved:
		node.set(k, saved[k])


func _spawn_autoloads(m: Dictionary, cfg: ConfigFile) -> void:
	if not cfg.has_section("autoload"):
		return
	var root := (Engine.get_main_loop() as SceneTree).root
	for key in cfg.get_section_keys("autoload"):
		# The app registers autoloads in override.cfg so Godot creates them
		# itself, right after the game's own. Only spawn the ones it didn't.
		if ProjectSettings.has_setting("autoload/" + key):
			continue
		var path := str(cfg.get_value("autoload", key))
		var early := path.begins_with("!")
		path = path.trim_prefix("!").trim_prefix("*")
		var res = load(path)
		var node: Node = null
		if res is PackedScene:
			node = res.instantiate()
		elif res is Script and res.can_instantiate():
			node = res.new()
		if node == null:
			_log("[%s] autoload %s could not be created from %s" % [m.id, key, path])
			continue
		node.name = key
		if early:
			root.add_child(node)
		else:
			root.add_child.call_deferred(node)


func _read_manifest(path: String) -> ConfigFile:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return null
	var text := ""
	if zip.file_exists("mod.txt"):
		text = zip.read_file("mod.txt").get_string_from_utf8()
	zip.close()
	if text == "":
		return null
	var cfg := ConfigFile.new()
	if cfg.parse(text) != OK:
		_log("mod.txt in %s could not be parsed." % path.get_file())
		return null
	return cfg


# ---------------------------------------------------------------- mod API
# Mods reach this through Engine.get_meta("Cleanstrike").

func is_loaded(mod_id: String) -> bool:
	return mod_id in loaded_ids


func get_setting(mod_id: String, key: String, default_value = null):
	if not _settings_cache.has(mod_id):
		_settings_cache[mod_id] = _read_json(cs_dir.path_join("settings").path_join(mod_id + ".json"), {})
	return _settings_cache[mod_id].get(key, default_value)


func get_data_dir(mod_id: String) -> String:
	var d := user_dir.path_join("data").path_join(mod_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	return d


func log_message(mod_id: String, text: String) -> void:
	_log("[%s] %s" % [mod_id, text])


static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in max(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0


# ---------------------------------------------------------------- io

func _write_report() -> void:
	var list := []
	for m in mods:
		list.append({"id": m.id, "name": m.name, "version": m.version, "file": m.file, "status": m.status, "reason": m.reason})
	_write_json(user_dir.path_join("last_launch.json"), {
		"loader_version": LOADER_VERSION,
		"game_version": game_version,
		"godot_version": godot_version,
		"safe_mode": safe_mode,
		"safe_mode_reason": safe_mode_reason,
		"time": Time.get_datetime_string_from_system(),
		"mods": list,
	})
	_flush_log()


func _log(text: String) -> void:
	print("[Cleanstrike] " + text)
	_log_lines.append(text)


func _flush_log() -> void:
	var f := FileAccess.open(user_dir.path_join("cleanstrike.log"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_log_lines) + "\n")


func _read_json(path: String, fallback):
	if not FileAccess.file_exists(path):
		return fallback
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == typeof(fallback) else fallback


func _write_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
