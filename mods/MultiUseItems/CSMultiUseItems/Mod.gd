# Multi-Use Items: shared helpers. Uses are stored in the item's condition,
# the same way Medical Durability does, so the two work side by side.
extends RefCounted

const MOD_ID := "cs_multi_use_items"
const VERSION := "1.0.0"

# Max uses per item (file name). Medical ones go to Medical Durability when
# that mod is on; these numbers apply when it is off.
const USES := {
	"Cigarettes": 5, "Cigars": 3, "Gum": 3, "Energy_Drink": 3, "Water_Bottle": 3,
	"AFAK": 6, "Antibiotics": 3, "Antiseptic": 5, "Balm": 3, "Bandage": 3,
	"Bandage_Improvised": 2, "Cold_Medicine": 3, "Deodorant": 5, "IFAK": 4,
	"Lotion": 3, "Medkit": 3, "Melatonin": 5, "Painkillers": 3, "Saline": 2,
	"Splint": 3, "Splint_Improvised": 2, "Tissues": 5, "Tourniquet": 5,
	"Tourniquet_Improvised": 3, "Wipes": 5,
}

const MD_PATH := "res://CSMedicalDurability/Mod.gd"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"found_partly_used": true,
	"split_effects": true,   # each use gives its share (a third of a drink)
	"crafting": true,        # crafting takes one use
	"extra": "",             # more items: File=uses, comma separated
}

# Self-test hooks: values here win over the player's settings.
static var overrides := {}


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


# Medical Durability is on and handles this item.
static func md_owns(data) -> bool:
	if not ResourceLoader.exists(MD_PATH):
		return false
	var md = load(MD_PATH)
	return md.active() and md.max_uses(data) > 1


static func _table() -> Dictionary:
	var t := USES.duplicate()
	for pair in str(setting("extra")).split(",", false):
		var kv := pair.split("=")
		if kv.size() == 2 and kv[1].strip_edges().is_valid_int():
			t[kv[0].strip_edges()] = int(kv[1])
	return t


# Uses when full, from whichever mod owns the item (1 = single use).
static func max_uses(data) -> int:
	if data == null:
		return 1
	if md_owns(data):
		return load(MD_PATH).max_uses(data)
	if not active():
		return 1
	return maxi(1, int(_table().get(str(data.file), 1)))


# Tracked by this mod (not by Medical Durability).
static func mine(slot) -> bool:
	return active() and slot != null and slot.itemData != null and not md_owns(slot.itemData) and max_uses(slot.itemData) > 1


static func tracked(slot) -> bool:
	return slot != null and slot.itemData != null and max_uses(slot.itemData) > 1


static func uses_left(slot) -> int:
	var most := max_uses(slot.itemData)
	return clampi(ceili(float(slot.condition) / 100.0 * most - 0.001), 1, most)


static func set_uses(slot, n: int) -> void:
	slot.condition = clampf(100.0 * n / max_uses(slot.itemData), 0.0, 100.0)


# Found in the world: partly used, never empty.
static func roll_found(slot) -> void:
	if mine(slot) and bool(setting("found_partly_used")):
		set_uses(slot, randi_range(1, maxi(1, max_uses(slot.itemData) - 1)))


# One use's worth of the item's effects.
static func share(data: ItemData) -> ItemData:
	if not bool(setting("split_effects")):
		return data
	var d: ItemData = data.duplicate()
	var n := float(max_uses(data))
	for k in ["health", "energy", "hydration", "mental", "temperature"]:
		d.set(k, float(data.get(k)) / n)
	return d
