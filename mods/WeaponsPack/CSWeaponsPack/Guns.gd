# CleanStrike Weapons Pack: the guns and the ammo they add.
# Each gun is a vanilla gun's rig, animations and handling ("base") wearing
# its own model (Guns/<ID>/Parts.scn, built by tools/weapons/gunsmith.gd),
# with its own data, magazine and feel:
#   data       ItemData fields set on top of the base gun's
#   magazine   a vanilla magazine's .tres, or a new magazine
#   ammo       a vanilla ammo .tres, or an id from AMMO below
#   feel       recoil (flip, x base), kick (push back), recovery (settling
#              speed, x base), impulse (seconds of view shake per shot),
#              view_kick (radians the view jolts, eases back), climb
#              (radians the aim rises for good), flash (muzzle flash
#              size, 0 = none), pitch / volume (fire sound vs the base gun's)
#   optics     "base" keep the base gun's optics (moved onto the new rail),
#              "rail" the KAR-21's rail optics, "none"
#   fold       flip-up iron sights fold away under an optic
#   hand       move the support hand onto this gun's handguard (not pistols)
#   shift      added to the base gun's carry poses (lowPosition...)
#   voice      fire sounds taken from voice_from's (e.g. suppressed ones)
#   suppressed built-in suppressor: no flash (still heard)
#   silent     no flash; its shots are never heard or noticed
#   head_damage  a hit to the head (zombies take 3x; the game's AI dies at 100)
#   bolt       bolt action fed by a magazine: Reload cycles the bolt
#   energy     energy bolts (Energy.gd) with the pack's own sounds
#   mag_flip   magazine on top: the base reload turned over (HandFit)
#   rounds     false: no rounds showing at the top of the magazine
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
		"MINI14": {
			"file": "CS_MINI14",
			"name": "Ruger Mini-14 (.223)",
			"short": "Mini-14",
			"display": "Mini-14",
			"base": ["AKM", "AKM"],
			"magazine": {"file": "CS_MINI14_Magazine", "name": "Mini-14 Magazine (.223)", "rounds": 20, "value": 150, "weight": 0.2},
			"ammo": "res://Items/Ammo/Ammo_223/Ammo_223.tres",
			"data": {"caliber": ".223", "damage": 40.0, "penetration": 3, "weaponAction": "Semi", "weight": 3.0, "value": 2900},
			"feel": {"recoil": 0.85, "flash": 1.0, "pitch": 1.06, "volume": 0.0},
			"optics": "rail",
			"muzzles": false,
		},
		"M82": {
			"file": "CS_M82",
			"name": "Barrett M82A1 (.50 BMG)",
			"short": "M82A1",
			"display": "M82",
			"base": ["SVD", "SVD"],
			"magazine": {"file": "CS_M82_Magazine", "name": "M82 Magazine (.50 BMG)", "rounds": 10, "value": 650, "weight": 1.4},
			"ammo": "CS_Ammo_50BMG",
			"data": {"caliber": ".50 BMG", "damage": 250.0, "penetration": 6, "weaponAction": "Semi", "fireRate": 0.35, "weight": 12.9, "value": 18500, "rarity": 3},
			"feel": {"recoil": 4.0, "kick": 3.0, "recovery": 0.25, "impulse": 0.7, "view_kick": 0.12, "climb": 0.035, "flash": 3.0, "pitch": 0.68, "volume": 8.0},
			"shift": {"lowPosition": Vector3(0, -0.03, 0), "highPosition": Vector3(0, -0.065, -0.03)},
			"optics": "rail",
			"muzzles": false,
		},
		"WELROD": {
			"file": "CS_WELROD",
			"name": "Welrod Mk I (9×19)",
			"short": "Welrod",
			"display": "Welrod",
			"base": ["Makarov", "Makarov"],
			"magazine": {"file": "CS_WELROD_Magazine", "name": "Welrod Magazine (9×19)", "rounds": 6, "value": 120, "weight": 0.3},
			"ammo": "res://Items/Ammo/Ammo_9x19/Ammo_9x19.tres",
			"data": {"caliber": "9×19", "damage": 15.0, "penetration": 1, "weaponAction": "Semi", "weight": 1.1, "value": 3200, "rarity": 2},
			"head_damage": 100.0,
			"bolt": true,
			"voice_from": "res://Items/Weapons/Glock_17/Glock_17.tres",
			"voice": {"fireSemi": "fireSuppressed", "fireAuto": "fireSuppressed", "fireSuppressed": "fireSuppressed", "tailOutdoor": "tailOutdoorSuppressed", "tailIndoor": "tailIndoorSuppressed", "reload": ["res://Items/Weapons/Mosin/Mosin.tres", "reload"]},
			"feel": {"recoil": 0.5, "kick": 0.5, "flash": 0.0, "pitch": 0.8, "volume": -8.0},
			"silent": true,
			"optics": "none",
			"hand": false,
		},
		"RAYGUN": {
			"file": "CS_RAYGUN",
			"name": "Homemade Ray Gun",
			"short": "Ray Gun",
			"display": "Ray Gun",
			"base": ["Glock_17", "Glock_17"],
			"magazine": {"file": "CS_RAYGUN_Battery", "name": "Ray Gun Battery Pack", "rounds": 20, "value": 650, "weight": 0.35},
			"ammo": "CS_Ammo_PowerCell",
			"data": {"caliber": "Plasma Cell", "damage": 75.0, "penetration": 5, "weaponAction": "Semi", "fireRate": 0.22, "weight": 2.6, "value": 26000, "rarity": 3,
				"civilian": false, "industrial": true, "military": false, "gunsmith": false},
			"head_damage": 200.0,
			"energy": {"fire": ["raygun_fire_1.wav", "raygun_fire_2.wav", "raygun_fire_3.wav"], "charge": ["raygun_charge.wav"], "volume": 2.0},
			"feel": {"recoil": 0.6, "kick": 0.8, "flash": 0.0, "impulse": 0.12, "view_kick": 0.02},
			"shift": {"aimPosition": Vector3(0, 0, -0.07)},
			"optics": "none",
			"hand": false,
		},
		"ASH12": {
			"file": "CS_ASH12",
			"name": "ASh-12 (12.7×55)",
			"short": "ASh-12",
			"display": "ASh-12",
			"base": ["AK-12", "AK-12"],
			"magazine": {"file": "CS_ASH12_Magazine", "name": "ASh-12 Magazine (12.7×55)", "rounds": 20, "value": 420, "weight": 0.6},
			"ammo": "CS_Ammo_127x55",
			"data": {"caliber": "12.7×55", "damage": 75.0, "penetration": 5, "fireRate": 0.092, "weight": 6.2, "value": 14500, "rarity": 2},
			"voice_from": "res://Items/Weapons/VSS/VSS.tres",
			"voice": {"fireSemi": "fireSemi", "fireAuto": "fireAuto", "fireSuppressed": "fireSuppressed", "tailOutdoor": "tailOutdoor", "tailIndoor": "tailIndoor", "tailOutdoorSuppressed": "tailOutdoorSuppressed", "tailIndoorSuppressed": "tailIndoorSuppressed"},
			"feel": {"recoil": 2.0, "kick": 1.15, "recovery": 0.6, "impulse": 0.25, "view_kick": 0.04, "climb": 0.008, "pitch": 0.8, "volume": 4.0},
			"suppressed": true,
			"shift": {"lowPosition": Vector3(0, -0.03, -0.13), "highPosition": Vector3(0, -0.03, -0.11), "inspectPosition": Vector3(0, -0.01, -0.08), "aimPosition": Vector3(0, 0, -0.05)},
			"optics": "rail",
			"muzzles": false,
		},
		"P90": {
			"file": "CS_P90",
			"name": "FN P90 (5.7×28)",
			"short": "P90",
			"display": "P90",
			"base": ["MP7", "MP7"],
			"magazine": {"file": "CS_P90_Magazine", "name": "P90 Magazine (5.7×28)", "rounds": 50, "value": 320, "weight": 0.27, "cells": Vector2(2, 1)},
			"ammo": "CS_Ammo_57x28",
			"data": {"caliber": "5.7×28", "damage": 28.0, "penetration": 3, "fireRate": 0.067, "weight": 2.6, "value": 6800, "rarity": 2},
			"feel": {"recoil": 0.6, "kick": 0.7, "flash": 0.8, "pitch": 1.1, "volume": 0.0},
			"mag_flip": true,
			"rounds": false,
			"optics": "rail",
			"muzzles": false,
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
			"feel": {"recoil": 2.8, "kick": 2.0, "recovery": 0.3, "impulse": 0.3, "view_kick": 0.05, "climb": 0.012, "flash": 1.7, "pitch": 0.8, "volume": 3.0},
			"optics": "none",
			"slide_sights": true,
			"hand": false,
		},
	}


# New calibres: boxes like the game's, sold by the Gunsmith.
static func ammo() -> Dictionary:
	return {
		"CS_Ammo_57x28": {
			"name": "5.7×28",
			"base": "res://Items/Ammo/Ammo_46x30/Ammo_46x30.tres",
			"art": "Ammo_57x28",
			"box": 50, "stack": 300, "value": 650, "weight": 0.35,
		},
		"CS_Ammo_127x55": {
			"name": "12.7×55",
			"base": "res://Items/Ammo/Ammo_9x39/Ammo_9x39.tres",
			"art": "Ammo_127x55",
			"box": 20, "stack": 120, "value": 1100, "weight": 0.9,
		},
		"CS_Ammo_PowerCell": {
			"name": "Plasma Cells",
			"base": "res://Items/Ammo/Ammo_9x19/Ammo_9x19.tres",
			"art": "Ammo_PowerCell",
			"box": 20, "stack": 200, "value": 900, "weight": 0.4,
			"flags": {"industrial": true, "gunsmith": true},
		},
		"CS_Ammo_50BMG": {
			"name": ".50 BMG",
			"base": "res://Items/Ammo/Ammo_308/Ammo_308.tres",
			"art": "Ammo_50BMG",
			"box": 10, "stack": 60, "value": 1500, "weight": 1.2,
		},
		"CS_Ammo_50AE": {
			"name": ".50 AE",
			"base": "res://Items/Ammo/Ammo_45ACP/Ammo_45ACP.tres",
			"art": "Ammo_50AE",
			"box": 20, "stack": 140, "value": 520, "weight": 0.65,
		},
	}
