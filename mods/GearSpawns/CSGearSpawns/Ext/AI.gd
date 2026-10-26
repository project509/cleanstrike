# Gear Spawns: enemies' guns get scopes, suppressors and lasers by faction
# (more as the days go on), and at night some carry a flashlight or night
# vision (which they drop when killed).
extends "res://Scripts/AI.gd"

const GS = preload("res://CSGearSpawns/Mod.gd")
const PV7 = "res://Items/Electronics/PV7/PV7.tres"

var gs_light: SpotLight3D
var gs_nvg := false
var gs_blink := 0.0


func SelectWeapon():
	super()
	if not GS.active() or weapon == null or weaponData == null or variant == null:
		return
	var faction: String = AIData.Faction.keys()[int(variant.faction)]
	var has := []
	for n in weapon.slotData.nested:
		if n:
			has.append(str(n.subtype))
	for a in GS.roll_attachments(weaponData, GS.group(faction), has):
		GS_Attach(a)
	if bool(GS.setting("night_gear")) and GS.is_night():
		var g := GS.group(faction)
		if randf() * 100.0 < float(GS.setting(g + "_nvg")):
			gs_nvg = true
		elif randf() * 100.0 < float(GS.setting(g + "_flashlight")):
			_gs_flashlight()
		if (gs_nvg or gs_light) and sensor:
			sensor.set_meta("gs_boost", float(GS.setting(g + "_sight")))


# Fit an attachment the way the game does for its own rare ones.
func GS_Attach(data) -> bool:
	var holder = weapon.get_node_or_null("Attachments")
	var node = holder.get_node_or_null(str(data.file)) if holder else null
	if node == null:
		return false
	var lod0 = node.get_node_or_null("LOD0")
	var lod1 = node.get_node_or_null("LOD1")
	if lod0 == null or lod1 == null:
		return false
	node.show()
	lod0.visibility_range_end = 10.0
	lod1.visibility_range_begin = 9.0
	lod1.visibility_range_end = 200.0
	if str(data.subtype) == "Muzzle":
		suppressed = true
		muzzleOffset = 0.2
		flash.position.z = muzzleOffset
	if str(data.subtype) == "Optic":
		optic = true
		if weaponData.useMount:
			var mount = holder.get_node_or_null("Mount")
			var mesh = mount.get_node_or_null("Mesh") if mount else null
			if mount and mesh:
				mesh.visibility_range_end = 200.0
				mount.show()
	weapon.slotData.nested.append(data)
	return true


func _gs_flashlight() -> void:
	gs_light = SpotLight3D.new()
	gs_light.name = "GS_Flashlight"
	gs_light.spot_range = 25.0
	gs_light.spot_angle = 28.0
	gs_light.light_energy = 6.0
	gs_light.shadow_enabled = true
	muzzle.add_child(gs_light)
	gs_light.rotation_degrees = Vector3(0, 180, 0) if muzzle.global_basis.z.dot(weapon.global_basis.z) < 0.0 else Vector3.ZERO
	gs_blink = randf_range(8.0, 20.0)


func _physics_process(delta):
	super(delta)
	if gs_light and not dead:
		gs_blink -= delta
		if gs_blink <= 0.0:
			gs_light.visible = not gs_light.visible
			gs_blink = randf_range(8.0, 20.0) if gs_light.visible else randf_range(3.0, 10.0)


func Death(direction, force):
	var was_dead: bool = dead
	super(direction, force)
	if was_dead or not GS.active():
		return
	if gs_light:
		gs_light.visible = false
	if gs_nvg and container and ResourceLoader.exists(PV7):
		var sd := SlotData.new()
		sd.itemData = load(PV7)
		sd.condition = randi_range(15, 90)
		container.loot.append(sd)
