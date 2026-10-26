# Self-test for Progression (cs_progression). r is the CSTest runner.
extends RefCounted

const PG = preload("res://CSProgression/Mod.gd")


func run(r) -> void:
	r.check("Progression: active", PG.active())
	var saved: Dictionary = PG.state().duplicate(true)
	PG._state = {}
	PG.overrides = {"messages": false}
	r.check("Progression: level 1 needs 100 XP, rising", PG.need(1) == 100 and PG.need(2) > PG.need(1) and PG.need(5) > 1000)
	var ups := PG.add_xp(120.0, "test")
	var st := PG.state()
	r.check("Progression: levelling up", ups == 1 and int(st.level) == 2 and int(st.xp) == 20 and int(st.points) == 1)
	r.check("Progression: spend a point", PG.spend("strength") and PG.rank("strength") == 1 and int(PG.state().points) == 0 and not PG.spend("barter"))
	PG.state().points = 10
	for i in 10:
		PG.spend("endurance")
	r.check("Progression: ranks stop at 5", PG.rank("endurance") == 5 and int(PG.state().points) == 5)

	# Endurance on the real character: running drains 30% less
	var gd = load("res://Resources/GameData.tres")
	var ch = r.get_node("/root/Map/Core/UI/Interface").character
	var keep := [gd.bodyStamina, gd.isRunning]
	ch.process_mode = Node.PROCESS_MODE_DISABLED
	gd.bodyStamina = 80.0
	gd.isRunning = true
	ch.Stamina(1.0)
	var with_skill: float = 80.0 - gd.bodyStamina
	PG.state().ranks["endurance"] = 0
	gd.bodyStamina = 80.0
	ch.Stamina(1.0)
	var without: float = 80.0 - gd.bodyStamina
	r.check("Progression: Endurance eases sprinting", without > 0.0 and absf(with_skill - without * 0.7) < 0.01, "%.2f vs %.2f" % [with_skill, without])
	gd.bodyStamina = keep[0]
	gd.isRunning = keep[1]
	ch.process_mode = Node.PROCESS_MODE_INHERIT

	# Strength: carry capacity, and the Skills panel
	var ui = r.get_node("/root/Map/Core/UI/Interface")
	await ui.UpdateStats(true)
	var cap_with: float = ui.currentInventoryCapacity
	PG.state().ranks["strength"] = 0
	await ui.UpdateStats(true)
	r.check("Progression: Strength adds carry weight", absf(cap_with - ui.currentInventoryCapacity - 2.0) < 0.01, "%.1f vs %.1f" % [cap_with, ui.currentInventoryCapacity])
	ui.PG_Build()
	ui.PG_Show(true)
	r.check("Progression: Skills panel shows", ui.pg_panel.visible and not ui.characterUI.get_node("Vitals").visible and ui.pg_rows.size() == 6)
	r.check("Progression: panel text", "Level 2" in ui.pg_panel.get_node("VBoxContainer/Head").text)
	ui.PG_Show(false)
	r.check("Progression: back to the stats", not ui.pg_panel.visible and ui.characterUI.get_node("Vitals").visible)
	PG._state = saved
	PG.overrides = {}
