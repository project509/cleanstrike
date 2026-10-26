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
const BASE_DATA := "res://Items/Weapons/KAR-21/KAR-21_308.tres"
const BASE_PICKUP := "res://Items/Weapons/KAR-21/KAR-21_308.tscn"
const ICON := "res://CSWeaponsPack/Model/Icon_SCAR.png"
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
const MUZZLE_SHIFT := 0.048   # the SCAR's muzzle is this much further out than the KAR-21's

static var scar_rig: PackedScene
static var scar_data: Resource
static var scar_pickup: PackedScene


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
			elif o is Node3D and o.position.z > 0.5:
				o.position.z += MUZZLE_SHIFT          # muzzle devices on the SCAR's muzzle
	var refs = sk.get_node_or_null("References")
	if refs:
		for n in ["Muzzle", "Raycast"]:
			var r = refs.get_node_or_null(n)
			if r:
				r.position.z += MUZZLE_SHIFT
	rig.name = "CS_SCAR_Rig"
	rig.set("data", scar_item())
	rig.set_meta("cs_rail_lift", lift)
	scar_rig = PackedScene.new()
	scar_rig.pack(rig)
	rig.free()
	return scar_rig


static func release() -> void:
	scar_rig = null
	scar_data = null
	scar_pickup = null

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


# The SCAR as an item: the KAR-21 (.308)'s data (ammo, magazines, attachments,
# sounds, handling) with its own name, picture and a SCAR-17's rate of fire.
static func scar_item() -> Resource:
	if scar_data:
		return scar_data
	var d: Resource = load(BASE_DATA).duplicate()
	d.file = SCAR_FILE
	d.name = "FN SCAR-17"
	d.inventory = "FN SCAR-17"
	d.rotated = "SCAR-17"
	d.equipment = "SCAR-17"
	d.display = "SCAR"
	d.fireRate = 0.1                 # about 600 rounds a minute
	d.kick = d.kick * 1.15
	d.value = int(d.value * 1.25)
	var img := Image.load_from_file(ICON)
	d.icon = ImageTexture.create_from_image(img) if img else d.icon
	var sprite := Sprite2D.new()
	sprite.name = SCAR_FILE
	sprite.texture = d.icon
	sprite.position = Vector2(32, 32) * d.size
	sprite.scale = Vector2(0.5, 0.5)
	if ResourceLoader.exists("res://UI/Effects/MT_Item.tres"):
		sprite.material = load("res://UI/Effects/MT_Item.tres")
	d.tetris = PackedScene.new()
	d.tetris.pack(sprite)
	sprite.free()
	scar_data = d
	return d


# The SCAR lying in the world: the KAR-21 (.308) pickup with the SCAR model in
# its place (attachments still show on it).
static func scar_pickup_scene() -> PackedScene:
	if scar_pickup:
		return scar_pickup
	var p: Node3D = load(BASE_PICKUP).instantiate()
	var lod0: MeshInstance3D = p.get_node("LOD0")
	var kar_box: AABB = lod0.transform * lod0.get_aabb()
	for n in ["LOD0", "LOD1"]:
		p.get_node(n).visible = false
	var parts: Node3D = load(SCAR_PARTS).instantiate()
	var scar_box := AABB()
	var first := true
	for c in parts.get_children():
		if c is MeshInstance3D:
			var b: AABB = c.transform * c.get_aabb()
			scar_box = b if first else scar_box.merge(b)
			first = false
	var holder := Node3D.new()
	holder.name = "SCAR"
	p.add_child(holder)
	holder.owner = p
	holder.position = kar_box.get_center() - scar_box.get_center()
	var main: MeshInstance3D = null
	for c in parts.get_children():
		if c is MeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.name = c.name
			mi.mesh = c.mesh
			mi.material_override = c.material_override
			mi.transform = c.transform
			mi.layers = lod0.layers
			holder.add_child(mi)
			mi.owner = p
			if str(c.name) == "Gun_Low":
				main = mi
	parts.free()
	if main:
		p.set("mesh", main)
	var sd = p.get("slotData")
	if sd:
		sd = sd.duplicate()
		sd.itemData = scar_item()
		p.set("slotData", sd)
	p.name = SCAR_FILE
	scar_pickup = PackedScene.new()
	scar_pickup.pack(p)
	p.free()
	return scar_pickup


# The game finds items by name: the SCAR and its rig.
static func register() -> void:
	var reg: Dictionary = Engine.get_meta("cs_items") if Engine.has_meta("cs_items") else {}
	reg[SCAR_FILE] = scar_pickup_scene()
	reg[SCAR_FILE + "_Rig"] = build_scar_rig()
	Engine.set_meta("cs_items", reg)
