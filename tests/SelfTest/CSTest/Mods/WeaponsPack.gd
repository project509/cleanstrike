# Self-test for CleanStrike Weapons Pack (cs_weapons_pack). r is the CSTest runner.
extends RefCounted

const WP = preload("res://CSWeaponsPack/Mod.gd")


func run(r) -> void:
	r.check("WeaponsPack: active", WP.active())
	var ps: PackedScene = WP.build_scar_rig()
	r.check("WeaponsPack: SCAR rig builds", ps != null)
	var rig: Node3D = ps.instantiate()
	r.get_tree().current_scene.add_child(rig)
	rig.global_position = Vector3(0, -600, 0)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var kar_visible := sk.get_children().filter(func(m): return m is MeshInstance3D and m.name != "Arms" and m.visible)
	r.check("WeaponsPack: the KAR-21 is hidden", kar_visible.is_empty(), str(kar_visible.map(func(m): return m.name)))
	var handle = sk.get_node_or_null("SCAR_KAR-21_Charging_Handle/Charge_Low")
	var body = sk.get_node_or_null("SCAR_KAR-21_Body/Gun_Low")
	var mag = sk.get_node_or_null("SCAR_KAR-21_Magazine_308/Magazine_Low")
	r.check("WeaponsPack: SCAR parts on their bones", handle != null and body != null and mag != null)
	r.check("WeaponsPack: arms kept", sk.get_node_or_null("Arms") != null and sk.get_node("Arms").visible)
	r.check("WeaponsPack: still the game's weapon rig", rig.has_method("FireEvent") and rig.get("data") != null)
	r.check("WeaponsPack: rig carries the SCAR's data", rig.get("data") == WP.scar_item())
	WP.update_sights(rig)
	var sights: Array = rig.find_children("Sight*", "MeshInstance3D", true, false)
	r.check("WeaponsPack: iron sights up with no optic", sights.size() > 5 and sights.all(func(x): return x.visible))
	rig.activeOptic = Node3D.new()
	WP.update_sights(rig)
	r.check("WeaponsPack: iron sights fold away under an optic", sights.all(func(x): return not x.visible))
	rig.activeOptic.free()
	rig.activeOptic = null
	rig.queue_free()
	var d = WP.scar_item()
	r.check("WeaponsPack: SCAR item: its own name and icon, the KAR-21 (.308)'s ammo and magazines", d.file == "CS_SCAR" and d.name == "FN SCAR-17" and d.icon != null and d.caliber == ".308" and d.compatible == load(WP.BASE_DATA).compatible)
	var db = r.get_node("/root/Database")
	var lt = load("res://Loot/LT_Master.tres")
	r.check("WeaponsPack: SCAR is in the game's loot list: military loot and the Gunsmith", lt.items.has(d) and d.military and d.gunsmith)
	r.check("WeaponsPack: the game's Database finds the SCAR and its rig", db.get("CS_SCAR") is PackedScene and db.get("CS_SCAR_Rig") is PackedScene)
	var pk = db.get("CS_SCAR").instantiate()
	r.get_tree().current_scene.add_child(pk)
	pk.global_position = Vector3(0, -620, 0)
	r.check("WeaponsPack: the SCAR on the ground is a SCAR", pk is Pickup and pk.slotData.itemData.file == "CS_SCAR" and pk.get_node("SCAR/Gun_Low") != null and not pk.get_node("LOD0").visible)
	pk.queue_free()
	# Saved and loaded (the game writes the item into the save), then fired.
	var sd := SlotData.new()
	sd.itemData = d
	sd.amount = 20
	sd.chamber = true
	sd.condition = 100
	var path := "user://cs_wp_test.tres"
	ResourceSaver.save(sd, path)
	var back = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	r.check("WeaponsPack: a saved SCAR loads back as a SCAR", back.itemData.file == "CS_SCAR" and back.itemData.name == "FN SCAR-17" and back.amount == 20)
	var fr = db.get(back.itemData.file + "_Rig").instantiate()
	fr.process_mode = Node.PROCESS_MODE_DISABLED
	r.get_tree().current_scene.add_child(fr)
	fr.slotData = back
	fr.fireTimer = 1.0
	if fr.has_method("FireEvent"):
		fr.FireEvent()
	r.check("WeaponsPack: the loaded SCAR fires: a round used", back.amount == 19)
	fr.queue_free()
