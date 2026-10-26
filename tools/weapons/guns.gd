# Weapons Pack: how each source gun model becomes a set of rig parts.
# Read by gunsmith.gd (offline). Directions and boxes are in the source
# model's own space (see C:/RTVDev/inspect/<gun>.png and .txt).
#   fwd / up   source directions of the muzzle and of the top of the gun
#   length     real overall length in metres (sets the scale)
#   base       vanilla gun the rig, animations and handling come from
#   skip       source meshes left out (display rounds, built-in scopes...)
#   parts      role -> source meshes ("Name", "Prefix*") or pieces of a
#              merged mesh ({"mesh": name, "box": AABB}: pieces whose centre
#              is inside the box). Anything unlisted is Body.
#   align      role whose box lines up with the base gun's trigger
#   offset     final nudge in rig space (x left, y up, z forward)
#   tex        source material -> textures (relative to the gun's folder)
extends RefCounted

const ROLES := ["Body", "Slide", "Trigger", "Hammer", "Magazine", "MagRelease", "Charge", "Selector", "SightRear", "SightFront", "Bolt"]


static func all() -> Dictionary:
	return {
		"SCAR": {
			"src": "res://cs_assets/scar/SCAR_straight.fbx",
			"dir": "C:/RTVDev/RTVProject/cs_assets/scar/textures/",
			"base": ["KAR-21", "KAR-21_308"],
			"fwd": Vector3(1, 0, 0), "up": Vector3(0, 1, 0),
			"length": 0.997,
			"skip": ["BulletCapsule_Low", "BulletTip_Low"],
			"parts": {
				"Magazine": ["Magazine_Low", "MagTech_Low"],
				"Trigger": ["Trigger_Low"],
				"Selector": ["GunModeR_Low", "GunModeL_Low"],
				"Charge": ["Charge_Low"],
				"MagRelease": ["MagUnlock_Low", "MagazineCatchHold_Low", "MagazineCatchHandle_Low"],
				"BoltRelease": ["BoltCatchHold_Low", "BoltCatchHandle_Low"],
				"SightRear": ["Sight1*"],
				"SightFront": ["Sight2*"],
			},
			"align": "Trigger",
			"muzzle": "Compressor_Low",
			"ejector": "ShellRelease_Low",
			"rail": "TopCap_Low",
			"cells": Vector2i(6, 2), "mag_cells": Vector2i(1, 2),
			"tex": {
				"DefaultMaterial": {"albedo": "DefaultMaterial_Base_Color.jpg", "normal": "DefaultMaterial_Normal_DirectX.jpg", "dx": true, "metallic": "DefaultMaterial_Metallic.jpg", "roughness": "DefaultMaterial_Roughness.jpg", "ao": "DefaultMaterial_Mixed_AO.jpg"},
			},
		},
		"DEAGLE": {
			"src": "res://cs_assets/deagle/deagle.fbx",
			"dir": "C:/RTVDev/RTVProject/cs_assets/deagle/textures/",
			"base": ["Colt_1911", "Colt_1911"],
			"fwd": Vector3(0, 0, 1), "up": Vector3(0, 1, 0),
			"length": 0.267,
			"skip": ["BulletCase_low", "Bullet_low"],
			"parts": {
				"Slide": ["Slide_low", "SlidePart_low", "BoltMain_low", "BoltAdd_low", "BoltButton_low", "BoltBack_low", "Safety_low", "BulletThrow_low"],
				"SightFront": ["FrontSight_low"],
				"SightRear": ["RearSight_low"],
				"Hammer": ["Hammer_low"],
				"Trigger": ["Trigger_low"],
				"Magazine": ["Magazine_low", "MagazineBase_low", "BaseInside_low"],
				"MagRelease": ["Button_03_low"],
			},
			"slide_sights": true,
			"cells": Vector2i(3, 2), "mag_cells": Vector2i(1, 1),
			"align": "Trigger",
			"muzzle": "Barrel_low",
			"ejector": "BoltMain_low",
			"tex": {
				"Slide": {"albedo": "T_Deagle_Slide_BaseColor.png", "normal": "T_Deagle_Slide_Normal.png", "metallic": "T_Deagle_Slide_Metallic.png", "roughness": "T_Deagle_Slide_Roughness.png"},
				"MainBody": {"albedo": "T_Deagle_MainBody_BaseColor.png", "normal": "T_Deagle_MainBody_Normal.png", "metallic": "T_Deagle_MainBody_Metallic.png", "roughness": "T_Deagle_MainBody_Roughness.png"},
				"Magazine": {"albedo": "T_Deagle_Magazine_BaseColor.png", "normal": "T_Deagle_Magazine_Normal.png", "metallic": "T_Deagle_Magazine_Metallic.png", "roughness": "T_Deagle_Magazine_Roughness.png"},
			},
		},
	}
