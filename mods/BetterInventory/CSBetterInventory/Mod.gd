# Better Inventory and Equipment: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_better_inventory"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"carry_weight": 15.0,   # base carry weight before gear (game: 10)
}

const TYPE_ORDER := ["Weapon", "Attachment", "Ammo", "Medical", "Consumables", "Consumable",
	"Armor", "Helmet", "Rig", "Backpack", "Clothing", "Electronics", "Key", "Misc", "Furniture"]


static func _key(item) -> Array:
	var d = item.slotData.itemData
	var t := TYPE_ORDER.find(str(d.type))
	return [t if t >= 0 else TYPE_ORDER.size(), -int(d.size.x * d.size.y), -int(maxf(d.size.x, d.size.y)), str(d.name)]


static func _before(a, b) -> bool:
	var ka := _key(a)
	var kb := _key(b)
	for i in ka.size():
		if ka[i] != kb[i]:
			return ka[i] < kb[i]
	return false


# Re-lay a grid's items by type, then size. All or nothing: if they would not
# all fit, everything goes back where it was.
static func sort_grid(grid) -> bool:
	var items: Array = grid.get_children().filter(func(c): return c is Item and grid.items.has(c))
	if items.size() < 2:
		return true
	var was := {}
	for it in items:
		was[it] = [it.global_position, it.rotated]
		grid.Pick(it)
	items.sort_custom(_before)
	var placed := []
	for it in items:
		if grid.Spawn(it):
			placed.append(it)
			continue
		for p in placed:     # undo
			grid.Pick(p)
		for i in items:
			i.global_position = was[i][0]
			grid.Place(i)
		return false
	return true


# Inventory items whose kind the container already holds.
static func stackable_into(inv, box) -> Array:
	var kinds := {}
	for c in box.get_children():
		if c is Item and c.slotData:
			kinds[str(c.slotData.itemData.file)] = true
	return inv.get_children().filter(func(c): return c is Item and c.slotData and kinds.has(str(c.slotData.itemData.file)) and not c.equipped)


static func matches(item, text: String) -> bool:
	text = text.strip_edges().to_lower()
	if text == "" or item.slotData == null:
		return true
	var d = item.slotData.itemData
	return text in str(d.name).to_lower() or text in str(d.type).to_lower() or text in str(d.subtype).to_lower()

# Self-test hook: values here win over the player's settings.
static var overrides := {}


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


# False when Cleanstrike rolled this mod back: stay vanilla.
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


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])
