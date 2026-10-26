# Better Enemy Loot: shared helpers and the extra loot an enemy carries.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_better_enemy_loot"
const VERSION := "1.0.0"

const AMOUNTS := ["None", "Low", "Normal", "More", "Lots"]

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"ammo_amount": "Normal",
	"ammo_max": 10,
	"magazines_amount": "Low",
	"magazines_max": 2,
	"consumables_amount": "Normal",
	"consumables_max": 2,
	"medical_amount": "Low",
	"medical_max": 2,
	"rare_chance": 0.25,
}

# Self-test hook: values here win over the player's settings.
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


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])


# ---------------------------------------------------------------- amounts

# How many of a category: weighted toward zero. Low = the lowest of three
# rolls from 0 to the maximum, Normal = lowest of two, More = one roll,
# Lots = highest of two.
static func amount(category: String) -> int:
	var mode := str(setting(category + "_amount"))
	var most := maxi(0, int(setting(category + "_max")))
	match mode:
		"Low": return mini(randi_range(0, most), mini(randi_range(0, most), randi_range(0, most)))
		"Normal": return mini(randi_range(0, most), randi_range(0, most))
		"More": return randi_range(0, most)
		"Lots": return maxi(randi_range(0, most), randi_range(0, most))
	return 0


# What each faction's people carry: bandits and nomads civilian things,
# guards add industrial, military (and bosses) everything.
static func carries(faction: String, item) -> bool:
	match faction:
		"Bandit", "Nomad": return bool(item.civilian)
		"Guard": return bool(item.civilian) or bool(item.industrial)
	return bool(item.civilian) or bool(item.industrial) or bool(item.military)


static func pick(type: String, faction: String):
	var common := []
	var rare := []
	for item in load("res://Loot/LT_Master.tres").items:
		if item and str(item.type) == type and carries(faction, item):
			if int(item.rarity) == 0:
				common.append(item)
			elif int(item.rarity) == 1:
				rare.append(item)
	if not rare.is_empty() and (common.is_empty() or randf() < float(setting("rare_chance"))):
		return rare.pick_random()
	return common.pick_random() if not common.is_empty() else null


static func faction_of(variant) -> String:
	if variant == null:
		return "Bandit"
	return str(AIData.Faction.keys()[int(variant.faction)])


# The extra loot for one body: ammo and spare magazines for the gun it had,
# plus food/drink and medical supplies. Added on top of what it already had.
static func extra_loot(variant, weapon_data) -> Array[SlotData]:
	var out: Array[SlotData] = []
	var faction := faction_of(variant)
	if weapon_data and "ammo" in weapon_data and weapon_data.ammo:
		var rounds := amount("ammo")
		if rounds > 0:
			var sd := SlotData.new()
			sd.itemData = weapon_data.ammo
			sd.amount = rounds
			out.append(sd)
	if weapon_data and "compatible" in weapon_data and weapon_data.compatible.size() > 0:
		var mag = weapon_data.compatible[0]
		if mag and str(mag.subtype) == "Magazine":
			var size := int(weapon_data.magazineSize) if "magazineSize" in weapon_data else 0
			for i in amount("magazines"):
				var sd := SlotData.new()
				sd.itemData = mag
				sd.amount = randi_range(0, size)
				out.append(sd)
	for spec in [["consumables", "Consumables"], ["medical", "Medical"]]:
		for i in amount(spec[0]):
			var item = pick(spec[1], faction)
			if item:
				var sd := SlotData.new()
				sd.itemData = item
				if item.defaultAmount != 0 and item.subtype != "Magazine":
					sd.amount = randi_range(1, item.defaultAmount)
				out.append(sd)
	return out
