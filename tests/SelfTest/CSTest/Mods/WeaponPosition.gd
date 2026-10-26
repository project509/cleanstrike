# Self-test for Weapon Position (cs_weapon_position). r is the CSTest runner.
extends RefCounted

const WP = preload("res://CSWeaponPosition/Mod.gd")


func run(r) -> void:
	r.check("WeaponPosition: active", WP.active())
	var gd = load("res://Resources/GameData.tres")
	r.check("WeaponPosition: offset at the hip", WP.offset(gd).is_equal_approx(Vector3(0.02, -0.02, 0.0)) or gd.isAiming)
	var rig = load("res://Items/Weapons/AKM/AKM_Rig.tscn").instantiate()
	r.get_tree().current_scene.add_child(rig)
	var handling = null
	for n in rig.find_children("*", "Node3D", true, false):
		if "wp_applied" in n:
			handling = n
	r.check("WeaponPosition: weapon handling uses the mod", handling != null)
	if handling:
		WP.overrides = {"side": 0.1, "height": 0.0, "depth": 0.0}
		await r.wait(1.0)
		r.check("WeaponPosition: weapon moves over", absf(handling.wp_applied.x - 0.1) < 0.01, "%.3f" % handling.wp_applied.x)
		# (the game clears isAiming each frame without a weapon in hand: the rule)
		r.check("WeaponPosition: no offset when aiming", WP.offset({"isAiming": true, "isCanted": false, "isInspecting": false}) == Vector3.ZERO)
	WP.overrides = {}
	rig.queue_free()
