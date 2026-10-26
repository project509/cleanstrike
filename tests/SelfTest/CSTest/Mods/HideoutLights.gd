# Self-test for Hideout Lights (cs_hideout_lights). r is the CSTest runner.
extends RefCounted

const HL = preload("res://CSHideoutLights/Mod.gd")


func run(r) -> void:
	r.check("HideoutLights: active", HL.active())
	var t := 0.0
	while HL.scenes.size() < HL.FIXTURES.size() and t < 20.0:
		await r.wait(0.2)
		t += 0.2
	r.check("HideoutLights: all fixtures built", HL.scenes.size() == HL.FIXTURES.size(), str(HL.scenes.size()))
	var db = r.get_node("/root/Database")
	var all_found := true
	var master = load("res://Loot/LT_Master.tres")
	for f in HL.FIXTURES:
		all_found = all_found and db.get(f) is PackedScene and master.items.has(HL.items[f]) and HL.items[f].icon != null
	r.check("HideoutLights: in the Database and trader stock, with icons", all_found)
	r.check("HideoutLights: vanilla furniture still found", db.get("Rack_Coat") is PackedScene)
	var made := []
	var cam = r.get_viewport().get_camera_3d()
	var i := 0
	var ok := true
	var detail := ""
	for f in HL.FIXTURES:
		var fx = db.get(f).instantiate()
		r.get_tree().current_scene.add_child(fx)
		fx.global_position = cam.global_position + Vector3(i * 1.5, -1.5, -4)
		made.append(fx)
		var furn = fx.get_node_or_null("Furniture")
		var body = fx.get_node("Collider_R").get_child(0)
		var lights: Array = fx.find_children("*", "Light3D", true, false)
		var good: bool = furn != null and furn.itemData == HL.items[f] and body.is_in_group("Furniture") and body.is_in_group("Interactable") \
			and furn.area.get_child_count() > 0 and not lights.is_empty() and fx.has_method("Interact")
		if not good:
			detail += f + " "
		ok = ok and good
		i += 1
	r.check("HideoutLights: each fixture is real furniture with a light", ok, detail)
	await r.wait(0.1)
	var lamp = made[2]
	var light: Light3D = lamp.find_children("*", "Light3D", true, false)[0]
	lamp.Interact()
	r.check("HideoutLights: Use turns it off", not light.visible and not lamp.lit)
	lamp.Interact()
	r.check("HideoutLights: and on again", light.visible)
	var floor_box: AABB = lamp.get_node("Mesh").get_aabb()
	r.check("HideoutLights: floor lamp stands on its base", absf(lamp.get_node("Mesh").position.y - floor_box.size.y / 2.0) < 0.02 and floor_box.size.y > 1.0, str(floor_box.size))
	for m in made:
		m.queue_free()
