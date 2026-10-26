# Self-test for Burst Fire (cs_burst_fire). r is the CSTest runner.
extends RefCounted

const BF = preload("res://CSBurstFire/Mod.gd")


func run(r) -> void:
	r.check("BurstFire: active", BF.active())
	var sd := SlotData.new()
	sd.itemData = load("res://Items/Weapons/AKM/AKM.tres")
	sd.mode = 1
	var seen := []
	for i in 4:
		BF.next_mode(sd)
		seen.append("burst" if BF.is_burst(sd) else ("auto" if sd.mode == 2 else "semi"))
	r.check("BurstFire: semi -> auto -> burst -> semi", seen == ["auto", "burst", "semi", "auto"], str(seen))
	r.check("BurstFire: burst is saved as auto", sd.mode == 2)
	# The rig hook compiles and is wired (a real rig swaps it in when equipped)
	var rig = load("res://Items/Weapons/AKM/AKM_Rig.tscn").instantiate()
	r.get_tree().current_scene.add_child(rig)
	await r.wait(0.1)
	r.check("BurstFire: weapon rigs use the mod", rig.has_method("FireInput") and "bf_left" in rig)
	rig.queue_free()
