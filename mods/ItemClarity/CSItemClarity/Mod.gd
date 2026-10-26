# Item Clarity: shared helpers (task needs, crafting uses, price tiers).
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_item_clarity"
const VERSION := "1.0.0"

const TRADERS := [
	"res://Traders/Generalist/Generalist.tres", "res://Traders/Doctor/Doctor.tres",
	"res://Traders/Gunsmith/Gunsmith.tres", "res://Traders/Driver/Driver.tres",
	"res://Traders/Hunter/Hunter.tres",
]
const TIERS := ["Low", "Fair", "Good", "Great", "Elite"]
const TIER_CUTS := [0.4, 0.7, 0.88, 0.97]
const TIER_COLORS := [Color(0.6, 0.6, 0.6), Color(0.85, 0.85, 0.85), Color(0.45, 0.8, 0.45), Color(0.4, 0.65, 1.0), Color(0.95, 0.75, 0.25)]

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"task_markers": true,
	"noted_only": false,
	"task_tooltips": true,
	"craft_tooltips": true,
	"price_tier": true,
	"highlight_compatible": true,
}

# Self-test hooks: values here win over the player's settings.
static var overrides := {}

static var _needs := {}        # item file -> [{task, trader, count}]
static var _uses := {}         # item file -> [recipe names]
static var _cuts := []


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


# ---------------------------------------------------------------- tasks

# Rebuild what open tasks need (call when the inventory opens).
static func refresh_tasks() -> void:
	_needs = {}
	var save: TraderSave = null
	if FileAccess.file_exists("user://Traders.tres"):
		save = ResourceLoader.load("user://Traders.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as TraderSave
	var noted := []
	if save and bool(setting("noted_only")):
		for t in save.taskNotes:
			if t:
				noted.append(t.name)
	for path in TRADERS:
		if not ResourceLoader.exists(path):
			continue
		var trader = load(path)
		var done: Array = save.get(str(trader.name).to_lower()) if save and str(trader.name).to_lower() in save else []
		for task in trader.tasks:
			if task == null or task.name in done:
				continue
			if bool(setting("noted_only")) and not (task.name in noted):
				continue
			var counts := {}
			for item in task.deliver:
				if item:
					counts[item.file] = int(counts.get(item.file, 0)) + 1
			for f in counts:
				if not _needs.has(f):
					_needs[f] = []
				_needs[f].append({"task": task.name, "trader": trader.name, "count": counts[f]})


static func needs(file: String) -> Array:
	return _needs.get(file, [])


static func most_needed(file: String) -> int:
	var n := 0
	for e in needs(file):
		n = maxi(n, int(e.count))
	return n


# ---------------------------------------------------------------- crafting

static func uses(file: String) -> Array:
	if _uses.is_empty():
		var all = load("res://Crafting/Recipes.tres")
		for group in ["consumables", "medical", "equipment", "weapons", "electronics", "misc", "furniture"]:
			for recipe in all.get(group):
				if recipe == null:
					continue
				for item in recipe.input:
					if item:
						if not _uses.has(item.file):
							_uses[item.file] = []
						if not (recipe.name in _uses[item.file]):
							_uses[item.file].append(recipe.name)
		_uses["_built"] = []
	return _uses.get(file, [])


# ---------------------------------------------------------------- price

static func per_slot(data) -> float:
	return float(data.value) / maxf(1.0, data.size.x * data.size.y)


static func tier(data) -> int:
	if _cuts.is_empty():
		var vals := []
		for it in load("res://Loot/LT_Master.tres").items:
			if it:
				vals.append(per_slot(it))
		vals.sort()
		for q in TIER_CUTS:
			_cuts.append(vals[int((vals.size() - 1) * q)])
	var v := per_slot(data)
	var t := 0
	for i in _cuts.size():
		if v > _cuts[i]:
			t = i + 1
	return t


# ---------------------------------------------------------------- compatible

# Does `other` go with the weapon/magazine `data`? (magazines, attachments,
# its ammo)
static func goes_with(data, other) -> bool:
	if data == null or other == null or data == other:
		return false
	if "compatible" in data and data.compatible.has(other):
		return true
	if "ammo" in data and data.ammo == other:
		return true
	return false


# ---------------------------------------------------------------- display

# Items Tarkov Looting keeps unexamined give nothing away.
static func hidden(item) -> bool:
	if ResourceLoader.exists("res://TarkovLooting/TL.gd"):
		var tl = load("res://TarkovLooting/TL.gd")
		return tl.active() and tl.is_unknown(item)
	return false


static var _tasks_built := false

static func ensure_tasks() -> void:
	if not _tasks_built:
		_tasks_built = true
		refresh_tasks()


static func owned(ui, file: String) -> int:
	var n := 0
	if ui and "inventoryGrid" in ui and ui.inventoryGrid:
		for c in ui.inventoryGrid.get_children():
			if c is Item and c.slotData and c.slotData.itemData and c.slotData.itemData.file == file:
				n += 1
	return n


# Extra tooltip lines: [text, color]
static func tooltip_lines(data, ui) -> Array:
	var out := []
	if on("task_tooltips"):
		ensure_tasks()
		for e in needs(data.file):
			var have := owned(ui, data.file)
			out.append(["Task: %s (%s)  %d/%d" % [e.task, e.trader, mini(have, e.count), e.count],
				Color(0.45, 0.85, 0.45) if have >= e.count else Color(1.0, 0.8, 0.3)])
	if on("craft_tooltips"):
		var u := uses(data.file)
		if not u.is_empty():
			var shown := u.slice(0, 4)
			out.append(["Crafting: " + ", ".join(shown) + ("..." if u.size() > 4 else ""), Color(0.6, 0.8, 1.0)])
	if on("price_tier") and int(data.value) > 0:
		var t := tier(data)
		out.append(["Per slot: %d  (%s)" % [int(per_slot(data)), TIERS[t]], TIER_COLORS[t]])
	return out
