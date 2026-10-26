# CleanStrike Weapons Pack: the guns and the ammo they add.
# Each gun is a vanilla gun's rig, animations and handling ("base") wearing
# its own model (Guns/<ID>/Parts.scn, built by tools/weapons/gunsmith.gd),
# with its own data, magazine and feel:
#   data       ItemData fields set on top of the base gun's
#   magazine   a vanilla magazine's .tres, or a new magazine
#   ammo       a vanilla ammo .tres, or an id from AMMO below
#   feel       recoil (flip, x base), kick (push back), recovery (settling
#              speed, x base), impulse (seconds of view shake per shot),
#              flash (muzzle flash size, 0 = none), pitch / volume (fire
#              sound vs the base gun's)
#   optics     "base" keep the base gun's optics (moved onto the new rail),
#              "rail" the KAR-21's rail optics, "none"
#   fold       flip-up iron sights fold away under an optic
#   hand       move the support hand onto this gun's handguard (not pistols)
#   shift      added to the base gun's carry poses (lowPosition...)
extends RefCounted

const RAIL_DONOR := ["KAR-21", "KAR-21_308"]


static func guns() -> Dictionary:
	return {
		"SCAR": {
			"file": "CS_SCAR",
			"name": "FN SCAR-17",
			"short": "SCAR-17",
			"display": "SCAR",
			"base": ["KAR-21", "KAR-21_308"],
			"magazine": "res://Items/Weapons/KAR-21/KAR-21_308_Magazine.tres",
			"data": {"fireRate": 0.1, "weight": 3.6, "value": 5250},
			"feel": {"recoil": 1.15, "flash": 1.15, "pitch": 0.96, "volume": 1.0},
			"optics": "base",
			"fold": true,
			"credit": "FN SCAR model by Gybels Tristan",
		},
		"VECTOR": {
			"file": "CS_VECTOR",
			"name": "KRISS Vector (.45 ACP)",
			"short": "Vector",
			"display": "Vector",
			"base": ["MP5", "MP5"],
			"magazine": {"file": "CS_VECTOR_Magazine", "name": "Vector Magazine (.45 ACP)", "rounds": 25, "value": 180, "weight": 0.22},
			"ammo": "res://Items/Ammo/Ammo_45ACP/Ammo_45ACP.tres",
			"data": {"caliber": ".45 ACP", "fireRate": 0.05, "weight": 2.7, "value": 4800, "rarity": 2},
			"feel": {"recoil": 0.7, "flash": 0.95, "pitch": 0.9, "volume": 1.0},
			"shift": {"lowPosition": Vector3(0, 0.04, 0), "highPosition": Vector3(0, 0.04, 0), "inspectPosition": Vector3(0, 0.03, 0)},
			"optics": "rail",
			"muzzles": false,
			"fold": true,
		},
		"DEAGLE": {
			"file": "CS_DEAGLE",
			"name": "Desert Eagle (.50 AE)",
			"short": "Desert Eagle",
			"display": "Deagle",
			"base": ["Colt_1911", "Colt_1911"],
			"magazine": {"file": "CS_DEAGLE_Magazine", "name": "Desert Eagle Magazine (.50 AE)", "rounds": 7, "value": 140, "weight": 0.25},
			"ammo": "CS_Ammo_50AE",
			"data": {"caliber": ".50 AE", "damage": 40.0, "penetration": 2, "magazineSize": 7, "weight": 2.0, "value": 2600, "rarity": 2},
			"feel": {"recoil": 2.8, "kick": 2.0, "recovery": 0.3, "impulse": 0.3, "flash": 1.7, "pitch": 0.8, "volume": 3.0},
			"optics": "none",
			"slide_sights": true,
			"hand": false,
		},
	}


# New calibres: boxes like the game's, sold by the Gunsmith.
static func ammo() -> Dictionary:
	return {
		"CS_Ammo_50AE": {
			"name": ".50 AE",
			"base": "res://Items/Ammo/Ammo_45ACP/Ammo_45ACP.tres",
			"art": "Ammo_50AE",
			"box": 20, "stack": 140, "value": 520, "weight": 0.65,
		},
	}
