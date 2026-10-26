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
	rig.queue_free()
