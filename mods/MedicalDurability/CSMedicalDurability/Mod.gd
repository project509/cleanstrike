# Medical Durability: shared helpers. Uses left are kept in the item's
# condition (100% = full), which the game already saves; without the mod the
# items simply show that condition.
extends RefCounted

const MOD_ID := "cs_medical_durability"
const VERSION := "1.0.0"

# Uses per item (the item's file name).
const USES := {
	"Bandage_Improvised": 2, "Bandage": 3, "Splint_Improvised": 2, "Splint": 3,
	"Tourniquet_Improvised": 3, "Tourniquet": 5, "Painkillers": 6, "Antibiotics": 4,
	"Antiseptic": 5, "IFAK": 6, "AFAK": 7, "Cold_Medicine": 4, "Lotion": 4, "Balm": 4,
	"Melatonin": 6, "Wipes": 8, "Tissues": 8, "Deodorant": 10, "Saline": 2, "Medkit": 8,
}

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
static var DEFAULTS := _defaults()

# Self-test hooks: values here win over the player's settings.
static var overrides := {}


static func _defaults() -> Dictionary:
	var d := {"found_partly_used": true}
	for f in USES:
		d["uses_" + f] = int(USES[f])
	return d


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


# How many uses this item has when full (1 = not tracked).
static func max_uses(item_data) -> int:
	if not active() or item_data == null or not USES.has(str(item_data.file)):
		return 1
	return maxi(1, int(setting("uses_" + str(item_data.file))))


static func tracked(slot) -> bool:
	return slot != null and slot.itemData != null and max_uses(slot.itemData) > 1


static func uses_left(slot) -> int:
	var most := max_uses(slot.itemData)
	return clampi(ceili(float(slot.condition) / 100.0 * most - 0.001), 1, most)


static func set_uses(slot, n: int) -> void:
	slot.condition = clampf(100.0 * n / max_uses(slot.itemData), 0.0, 100.0)


# Found in the world: partly used, never empty.
static func roll_found(slot) -> void:
	if tracked(slot) and bool(setting("found_partly_used")):
		var most := max_uses(slot.itemData)
		set_uses(slot, randi_range(1, maxi(1, most - 1)))
