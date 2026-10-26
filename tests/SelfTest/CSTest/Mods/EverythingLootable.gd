# Self-test for Everything Lootable (cs_everything_lootable). r is the CSTest runner.
extends RefCounted

const EL = preload("res://CSEverythingLootable/Mod.gd")


func run(r) -> void:
	r.check("EverythingLootable: active", EL.active())
	EL.overrides = {"amount": 2.0}   # the car and truck always hold something
	var made := []
	for path in ["res://Assets/Vehicles/Nissan/Nissan.tscn", "res://Assets/Rack_Coat/Rack_Coat.tscn", "res://Assets/Vehicles/BTR/BTR.tscn"]:
		var p = load(path).instantiate()
		r.get_tree().current_scene.add_child(p)
		p.global_position = Vector3(500 + made.size() * 20, -200, 500)
		made.append(p)
	await r.wait(0.3)
	var car = made[0].get_node_or_null("CS_Loot")
	r.check("EverythingLootable: a car can be searched", car != null and car.containerName == "Car" and car.has_method("Interact"))
	if car:
		var body = car.get_node("StaticBody3D")
		r.check("EverythingLootable: the interactor reaches it", body.is_in_group("Interactable") and body.owner == car and (body.collision_layer & 16) != 0)
		r.check("EverythingLootable: the car holds something", not car.loot.is_empty())
		var military := false
		for sd in car.loot:
			military = military or (sd.itemData.military and not sd.itemData.civilian and not sd.itemData.industrial)
		r.check("EverythingLootable: no military gear", not military)
		var shape: BoxShape3D = body.get_child(0).shape
		r.check("EverythingLootable: box covers the car", shape.size.x > 1.0 and shape.size.z > 1.0, str(shape.size))
	r.check("EverythingLootable: coat rack can be searched", made[1].get_node_or_null("CS_Loot") != null)
	r.check("EverythingLootable: military vehicles stay as they are", made[2].get_node_or_null("CS_Loot") == null)
	EL.overrides = {}
	for p in made:
		p.queue_free()
	await r.wait(0.1)
