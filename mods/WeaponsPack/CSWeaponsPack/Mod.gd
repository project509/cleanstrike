# CleanStrike Weapons Pack: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_weapons_pack"
const VERSION := "0.1.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"scar_iron_sights": true,     # folding iron sights shown with no optic
}

const BASE_RIG := "res://Items/Weapons/KAR-21/KAR-21_308_Rig.tscn"
const SCAR_PARTS := "res://CSWeaponsPack/Model/SCAR_Parts.scn"
const SCAR_FILE := "CS_SCAR"

# Which rig bone each SCAR part rides on (everything else: the body).
const SCAR_BONES := {
	"Charge_Low": "KAR-21_Charging_Handle",
	"Trigger_Low": "KAR-21_Trigger",
	"GunModeR_Low": "KAR-21_Selector", "GunModeL_Low": "KAR-21_Selector",
	"Magazine_Low": "KAR-21_Magazine_308", "MagTech_Low": "KAR-21_Magazine_308",
	"MagUnlock_Low": "KAR-21_Release_Lever", "MagazineCatchHold_Low": "KAR-21_Release_Lever", "MagazineCatchHandle_Low": "KAR-21_Release_Lever",
	"BoltCatchHold_Low": "KAR-21_Slide_Release", "BoltCatchHandle_Low": "KAR-21_Slide_Release",
}
const BODY_BONE := "KAR-21_Body"
const OPTIC_RAIL_Y := 0.075   # optics on the KAR-21 sit at about this height

static var scar_rig: PackedScene


# The SCAR's first-person rig: the KAR-21 (.308) rig with its meshes swapped
# for the SCAR's, each part on the bone that moves it, optics raised to the
# SCAR's rail. Everything else (arms, animations, magazines, attachments,
# recoil, sounds) is the game's own.
static func build_scar_rig() -> PackedScene:
	if scar_rig:
		return scar_rig
	var rig: Node3D = load(BASE_RIG).instantiate()
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	for m in sk.get_children():
		if m is MeshInstance3D and m.name != "Arms":
			m.visible = false
	var parts: Node3D = load(SCAR_PARTS).instantiate()
	var atts := {}
	var rail_top := -INF
	for p in parts.get_children():
		if not (p is MeshInstance3D):
			continue
		var bone_name: String = SCAR_BONES.get(str(p.name), BODY_BONE)
		var bone := sk.find_bone(bone_name)
		if bone < 0:
			bone_name = BODY_BONE
			bone = sk.find_bone(bone_name)
		if not atts.has(bone_name):
			var a := BoneAttachment3D.new()
			a.name = "SCAR_" + bone_name
			a.bone_name = bone_name
			sk.add_child(a)
			a.owner = rig
			atts[bone_name] = a
		var mi := MeshInstance3D.new()
		mi.name = p.name
		mi.mesh = p.mesh
		mi.material_override = p.material_override
		mi.layers = p.layers
		mi.transform = sk.get_bone_global_rest(bone).affine_inverse() * p.transform
		atts[bone_name].add_child(mi)
		mi.owner = rig
		if str(p.name) == "Gun_Low":
			rail_top = (p.transform * p.get_aabb()).end.y
	parts.free()
	# Optics sit on the SCAR's rail
	var lift := rail_top - OPTIC_RAIL_Y if rail_top > -INF else 0.0
	var mounts = sk.get_node_or_null("Attachments")
	if mounts:
		for o in mounts.get_children():
			if o is Node3D and o.position.y > 0.05:
				o.position.y += lift
	rig.name = "CS_SCAR_Rig"
	rig.set_meta("cs_rail_lift", lift)
	scar_rig = PackedScene.new()
	scar_rig.pack(rig)
	rig.free()
	return scar_rig


static func release() -> void:
	scar_rig = null

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
