# Better Traders: shared helpers (settings, reputation, stock, dailies, kills).
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_better_traders"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"tabs": true,
	"goods_count": 40,
	"furniture_count": 8,
	"stock": true,
	"stock_per_level": 3,
	"keys": true,
	"key_price": 3000,
	"reputation": true,
	"dailies": true,
	"kill_contracts": true,
	"repairs": true,
	"refresh_key": "F1",
	"refresh_cooldown": 0,
}

# Trader reputation: points from tasks (10 each), dailies and trading.
const LEVELS := ["Unknown", "Acquaintance", "Trusted", "Reliable", "Valued", "Partner"]
const THRESHOLDS := [0.0, 10.0, 25.0, 45.0, 70.0, 100.0]
const POINTS_PER_TASK := 10.0
const VALUE_PER_POINT := 1000.0      # trading: 1 point per 1000 of deal value

# The traders' own keys, sold from Stock once you're Reliable.
const KEYS := {
	"Generalist": "res://Items/Keys/Key_Cellar.tres",
	"Doctor": "res://Items/Keys/Key_Gymnasium.tres",
	"Gunsmith": "res://Items/Keys/Key_Tunnel.tres",
}
const KEY_LEVEL := 3

# Who repairs what.
const REPAIRS := {"Gunsmith": ["Weapon"], "Doctor": ["Armor", "Helmet"]}

const DAILY_LABELS := ["Simple", "Easy", "Moderate", "Challenging"]
const DAILY_COLORS := [Color(0.6, 0.85, 0.6), Color.GREEN, Color.ORANGE, Color.RED]
const KILL_FACTIONS := ["Bandit", "Guard", "Military"]

# Self-test hooks: values here win over the player's settings / saved data.
static var overrides := {}

static var _data := {}
static var _loaded := false


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


static func active() -> bool:
	var c := cs()
	return c == null or c.is_loaded(MOD_ID)


static func setting(key: String):
	if overrides.has(key):
		return overrides[key]
	var fallback = DEFAULTS.get(key)
	var c := cs()
	if c == null:
		return fallback
	var v = c.get_setting(MOD_ID, key, fallback)
	# Settings files store every number as a float: convert to the default's type.
	if typeof(fallback) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(round(v))
	if typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	return v if typeof(v) == typeof(fallback) else fallback


static func on(key: String) -> bool:
	return active() and bool(setting(key))


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])


static func game() -> Resource:
	return load("res://Resources/GameData.tres")


# ---------------------------------------------------------------- saved data

static func _path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://cleanstrike/data/" + MOD_ID
	return dir.path_join("traders.json")


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		_data = {}
		if FileAccess.file_exists(_path()):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if parsed is Dictionary:
				_data = parsed
		for k in ["rep", "dailies", "kills"]:
			if not (_data.get(k) is Dictionary):
				_data[k] = {}
		if not _data.has("seed"):
			_data["seed"] = randi()
	return _data


static func save() -> void:
	if game().tutorial:
		return   # the tutorial never touches your real progress
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data(), "\t"))


# New game, or a permadeath wipe: reputation and dailies start over.
static func wipe() -> void:
	_data = {}
	_loaded = true
	data()
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(_path())
	say("Trader reputation reset (new game or save wipe).")


# ---------------------------------------------------------------- reputation

# Tasks always count; dailies and trading only with reputation on (without
# it, stock tiers follow tasks alone, like Trader Tabs).
static func points(trader) -> float:
	if overrides.has("rep"):
		return float(overrides["rep"])
	var p: float = POINTS_PER_TASK * trader.tasksCompleted.size()
	if on("reputation"):
		p += float(data().rep.get(trader.traderData.name, 0.0))
	return p


static func level_for(p: float) -> int:
	var lvl := 0
	for i in THRESHOLDS.size():
		if p >= THRESHOLDS[i]:
			lvl = i
	return lvl


static func level(trader) -> int:
	return level_for(points(trader))


static func rep_text(trader) -> String:
	return "%s (%d)" % [LEVELS[level_for(points(trader))], int(points(trader))]


# Add earned points; announce a new level.
static func add_rep(trader, p: float) -> void:
	if not on("reputation") or p <= 0.0:
		return
	var before := level(trader)
	var name: String = trader.traderData.name
	data().rep[name] = float(data().rep.get(name, 0.0)) + p
	save()
	announce(trader, before)


static func announce(trader, before: int) -> void:
	var after := level(trader)
	if after > before:
		Loader.Message("%s: you are now %s. New stock unlocked." % [trader.traderData.name, LEVELS[after]], Color.GREEN)


# ---------------------------------------------------------------- supply

static func make_slot(item: ItemData) -> SlotData:
	var sd := SlotData.new()
	sd.itemData = item
	if item.defaultAmount != 0 and item.subtype != "Magazine":
		sd.amount = item.defaultAmount
	return sd


static func is_furniture(item) -> bool:
	return item != null and str(item.type) == "Furniture"


# Stock: 3 items (stock_per_level) for each reputation level reached, drawn
# from progressively better slices of the trader's own range; plus the
# trader's key once you're Reliable.
static func make_stock(trader) -> Array[SlotData]:
	var out: Array[SlotData] = []
	var pool: Array = []
	for item in trader.traderBucket:
		if item and not is_furniture(item) and str(item.type) != "Key":
			pool.append(item)
	if pool.is_empty():
		return out
	pool.sort_custom(func(a, b): return float(a.value) < float(b.value))
	var bands := LEVELS.size()
	var lvl := level(trader)
	var per := int(setting("stock_per_level"))
	for b in range(0, lvl + 1):
		var lo := int(floor(float(b) / bands * pool.size()))
		var hi := maxi(lo + 1, int(floor(float(b + 1) / bands * pool.size())))
		var band := pool.slice(lo, hi)
		band.shuffle()
		for i in per:
			out.append(make_slot(band[i % band.size()]))
	var name: String = trader.traderData.name
	if on("keys") and lvl >= KEY_LEVEL and KEYS.has(name) and ResourceLoader.exists(KEYS[name]):
		out.append(make_slot(load(KEYS[name]) as ItemData))
	return out


static func key_price(trader, item) -> int:
	var name: String = trader.traderData.name
	if item and on("keys") and KEYS.has(name) and item.resource_path == KEYS[name]:
		return int(setting("key_price"))
	return -1


static func repair_types(trader) -> Array:
	if not on("repairs") or trader == null:
		return []
	return REPAIRS.get(trader.traderData.name, [])


static func repair_cost(trader, slot: SlotData) -> float:
	var missing := clampf(100.0 - float(slot.condition), 0.0, 100.0) / 100.0
	return missing * float(slot.itemData.value) * 0.5 * (1.0 + float(trader.tax) * 0.005)


# ---------------------------------------------------------------- dailies

static func today() -> int:
	return int(Simulation.day)


# The trader's dailies for today: 1 + reputation level (max 6). Built the
# same every time you look today; a new set tomorrow.
static func dailies_for(trader) -> Array[TaskData]:
	var out: Array[TaskData] = []
	if not on("dailies"):
		return out
	var name: String = trader.traderData.name
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d" % [name, today(), int(data().seed)])
	var lvl := level(trader)
	var count := mini(1 + lvl, 6)
	var common: Array = []
	var better: Array = []
	for item in trader.traderBucket:
		if item == null or is_furniture(item) or str(item.type) == "Key":
			continue
		if int(item.rarity) == 0:
			common.append(item)
		else:
			better.append(item)
	if common.is_empty():
		return out
	common.sort_custom(func(a, b): return float(a.value) < float(b.value))
	var rewards: Array = common + better
	rewards.sort_custom(func(a, b): return float(a.value) < float(b.value))
	for i in count:
		var td := TaskData.new()
		td.trader = name
		var id := "%d:%d" % [today(), i]
		td.set_meta("bt_daily", id)
		var tier := clampi(rng.randi_range(0, mini(lvl, 3)), 0, 3)
		td.difficulty = DAILY_LABELS[tier]
		if on("kill_contracts") and lvl >= 1 and i == count - 1:
			var faction: String = KILL_FACTIONS[rng.randi_range(0, mini(lvl - 1, KILL_FACTIONS.size() - 1))]
			var n := 2 + tier + rng.randi_range(0, 1)
			td.set_meta("bt_kill", {"faction": faction, "count": n})
			var reward = rewards[clampi(int(rewards.size() * (0.55 + 0.1 * tier)), 0, rewards.size() - 1)]
			td.name = "Contract: %d %ss [Daily]" % [n, faction]
			td.description = "Kill %d %ss today and I'll give you 1x %s." % [n, faction, reward.name]
			td.receive.append(reward)
		else:
			var item = common[rng.randi_range(0, int((common.size() - 1) * (0.4 + 0.2 * tier)))]
			var n := 1 + mini(tier, 2) + (1 if rng.randf() < 0.3 else 0)
			var want := float(item.value) * n * (1.3 + 0.2 * tier)
			var reward = rewards[0]
			for r in rewards:
				if float(r.value) <= want and r != item:
					reward = r
			for k in n:
				td.deliver.append(item)
			td.receive.append(reward)
			td.name = "%s: %s [Daily]" % [td.difficulty, item.name]
			td.description = "Bring me %dx %s and I'll give you 1x %s." % [n, item.name, reward.name]
		out.append(td)
	return out


static func daily_points(td: TaskData) -> float:
	return 2.0 + DAILY_LABELS.find(td.difficulty) * 1.5


static func daily_done(trader, td: TaskData) -> bool:
	var d: Dictionary = data().dailies.get(trader.traderData.name, {})
	return int(d.get("day", -1)) == today() and str(td.get_meta("bt_daily", "")) in d.get("done", [])


static func mark_daily_done(trader, td: TaskData) -> void:
	var name: String = trader.traderData.name
	var d: Dictionary = data().dailies.get(name, {})
	if int(d.get("day", -1)) != today():
		d = {"day": today(), "done": []}
	d.done.append(str(td.get_meta("bt_daily", "")))
	data().dailies[name] = d
	save()


# ---------------------------------------------------------------- kills

static func record_kill(faction: String) -> void:
	var k: Dictionary = data().kills
	if int(k.get("day", -1)) != today():
		k.clear()
		k["day"] = today()
	k[faction] = int(k.get(faction, 0)) + 1
	save()


static func kills_today(faction: String) -> int:
	var k: Dictionary = data().kills
	return int(k.get(faction, 0)) if int(k.get("day", -1)) == today() else 0
