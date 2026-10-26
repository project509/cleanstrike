# Self-test for Better Enemy Loot (cs_better_enemy_loot). r is the CSTest runner.
extends RefCounted

const BEL = preload("res://CSBetterEnemyLoot/Mod.gd")


func run(r) -> void:
	r.check("BetterEnemyLoot: active", BEL.active())
	var bandit = load("res://AI/Bandit/AI_Bandit_A.tres")
	var military = load("res://AI/Military/AI_Military_A.tres")
	var akm = load("res://Items/Weapons/AKM/AKM.tres")
	# The death hook sits in the game's AI script chain (with other mods' AI hooks).
	var hooked := false
	var s = load("res://Scripts/AI.gd")
	while s:
		if s.get_script_constant_map().has("BEL"):
			hooked = true
		s = s.get_base_script()
	r.check("BetterEnemyLoot: enemy death hook installed", hooked)
	r.check("BetterEnemyLoot: factions read", BEL.faction_of(bandit) == "Bandit" and BEL.faction_of(military) == "Military")

	BEL.overrides = {"ammo_amount": "Lots", "ammo_max": 10, "magazines_amount": "Lots", "magazines_max": 2,
		"consumables_amount": "Lots", "consumables_max": 3, "medical_amount": "Lots", "medical_max": 3}
	var ammo := 0
	var mags := 0
	var supplies := 0
	var civilian_only := true
	for i in 200:
		for sd in BEL.extra_loot(bandit, akm):
			if sd.itemData == akm.ammo:
				ammo += 1
				civilian_only = civilian_only and sd.amount >= 1 and sd.amount <= 10
			elif sd.itemData == akm.compatible[0]:
				mags += 1
				civilian_only = civilian_only and sd.amount <= int(akm.magazineSize)
			else:
				supplies += 1
				civilian_only = civilian_only and bool(sd.itemData.civilian)
	r.check("BetterEnemyLoot: ammo for the enemy's gun", ammo > 100, "%d of 200 bodies" % ammo)
	r.check("BetterEnemyLoot: spare magazines for it", mags > 100, "%d magazines" % mags)
	r.check("BetterEnemyLoot: food, drink and medical", supplies > 300, "%d items" % supplies)
	r.check("BetterEnemyLoot: bandits carry civilian things only, sane amounts", civilian_only)

	# Defaults are weighted toward zero
	BEL.overrides = {}
	var total := 0
	for i in 400:
		total += BEL.extra_loot(bandit, akm).size()
	r.check("BetterEnemyLoot: defaults are modest", total / 400.0 > 0.5 and total / 400.0 < 4.0, "%.2f extra items per body" % (total / 400.0))
	BEL.overrides = {"ammo_amount": "None", "magazines_amount": "None", "consumables_amount": "None", "medical_amount": "None"}
	r.check("BetterEnemyLoot: None means nothing", BEL.extra_loot(military, akm).is_empty())
	BEL.overrides = {}
