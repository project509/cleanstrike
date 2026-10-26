# Self-test for Save Anywhere (cs_save_anywhere). r is the CSTest runner.
extends RefCounted

const SA = preload("res://CSSaveAnywhere/Mod.gd")


func run(r) -> void:
	r.check("SaveAnywhere: active", SA.active())
	SA.write("Village", Vector3(1, 2, 3), 0.5)
	var s := SA.read()
	r.check("SaveAnywhere: spot saved and read back", str(s.map) == "Village" and Vector3(s.pos[0], s.pos[1], s.pos[2]) == Vector3(1, 2, 3))
	SA.clear()
	r.check("SaveAnywhere: cleared", SA.read().is_empty())


# A real quit away from a shelter, then Continue.
func run_last(r) -> void:
	var gd = load("res://Resources/GameData.tres")
	var ctrl = r.get_node("/root/Map/Core/Controller")
	var spot: Vector3 = ctrl.global_position + Vector3(2.0, 0.0, -3.0)
	ctrl.global_position = spot
	gd.tutorial = false
	gd.shelter = false
	var settings = r.get_node("/root/Map/Core/UI/Settings")
	r.check("SaveAnywhere: quitting here suspends", settings.SA_CanSuspend())
	settings._on_menu_pressed()
	var t := 0.0
	while (r.get_tree().current_scene == null or r.get_tree().current_scene.name != "Menu") and t < 30.0:
		await r.wait(0.25)
		t += 0.25
	r.check("SaveAnywhere: spot written", str(SA.read().get("map", "")) == "Tutorial")
	Loader.LoadScene(Loader.ValidateShelter())   # the menu's Continue
	var ok: bool = await r.wait_for_map("Tutorial", 60.0)
	await r.wait(1.0)
	ctrl = r.get_node_or_null("/root/Map/Core/Controller")
	r.check("SaveAnywhere: Continue puts you back there", ok and ctrl != null and ctrl.global_position.distance_to(spot) < 1.5, str(ctrl.global_position) if ctrl else "")
	r.check("SaveAnywhere: only once", SA.read().is_empty())
	await r.wait(3.0)
