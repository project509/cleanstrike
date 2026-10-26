# Self-test for Sandbox Mode (cs_sandbox_mode). r is the CSTest runner.
extends RefCounted

const SB = preload("res://CSSandboxMode/Mod.gd")


func run(r) -> void:
	r.check("SandboxMode: active", SB.active())
	r.check("SandboxMode: every cheat starts off", SB.state.is_empty() or not SB.state.values().has(true))
	var gd = load("res://Resources/GameData.tres")
	var keep := {"health": gd.health, "energy": gd.energy, "hydration": gd.hydration, "bodyStamina": gd.bodyStamina}
	SB.state = {"god": true, "no_needs": true, "stamina": true, "no_weight": true, "ignored": true}
	gd.health = 40.0
	gd.energy = 20.0
	gd.bodyStamina = 5.0
	gd.bleeding = true
	for i in 3:
		await r.get_tree().physics_frame
	r.check("SandboxMode: god mode heals and stops bleeding", gd.health == 100.0 and not gd.bleeding)
	r.check("SandboxMode: no needs, full stamina", gd.energy == 100.0 and gd.bodyStamina == 100.0)
	var ch = r.get_node("/root/Map/Core/UI/Interface").character
	ch.Overweight(true)
	r.check("SandboxMode: no weight limit", not gd.overweight)
	var sensor := MeshInstance3D.new()
	sensor.set_script(load("res://Scripts/Sensor.gd"))
	r.check("SandboxMode: enemies ignore you", not sensor.PlayerValid())
	sensor.free()
	var found := SB.find_items("bandage")
	r.check("SandboxMode: item search", found.size() >= 1 and "andage" in str(found[0].name))
	var inv = r.get_node("/root/Map/Core/UI/Interface").inventoryGrid
	var before: int = inv.get_child_count()
	SB.spawn(found[0])
	await r.wait(0.2)
	r.check("SandboxMode: spawns into the inventory", inv.get_child_count() == before + 1)
	var added = inv.get_child(inv.get_child_count() - 1)
	var sim = r.get_node("/root/Simulation")
	var s_keep := [sim.time, sim.weather, sim.season]
	SB.set_time(2200)
	SB.add_hours(3)
	r.check("SandboxMode: time controls", is_equal_approx(sim.time, 100.0))
	SB.next_weather()
	r.check("SandboxMode: weather control", sim.weather != s_keep[1])
	SB.switch_season()
	r.check("SandboxMode: season control", sim.season != s_keep[2])
	r.check("SandboxMode: restock traders", SB.restock() >= 1)
	var menu = r.get_node("/root/CSSandboxModeBoot/Menu")
	menu.toggle()
	r.check("SandboxMode: F6 menu opens and freezes you", menu.panel.visible and gd.freeze and menu.list.item_count > 50)
	menu.toggle()
	r.check("SandboxMode: and closes", not menu.panel.visible and not gd.freeze)
	sim.time = s_keep[0]
	sim.weather = s_keep[1]
	sim.season = s_keep[2]
	SB.state = {}
	gd.bleeding = false
	for k in keep:
		gd.set(k, keep[k])
	if is_instance_valid(added):
		inv.Pick(added)
		added.queue_free()
