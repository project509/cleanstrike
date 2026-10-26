# Self-test for Kill Counter (cs_kill_counter). r is the CSTest runner.
extends RefCounted

const KC = preload("res://CSKillCounter/Mod.gd")


func run(r) -> void:
	r.check("KillCounter: active", KC.active())
	var before := KC.total()
	KC.add("Bandit")
	KC.add("Bandit")
	KC.add("Military")
	r.check("KillCounter: counts by faction", KC.total() == before + 3 and int(KC.tally()["Bandit"]) >= 2)
	var hooked := false
	var s = load("res://Scripts/AI.gd")
	while s:
		if s.get_script_constant_map().has("KC"):
			hooked = true
		s = s.get_base_script()
	r.check("KillCounter: kill hook installed", hooked)
	var ui = r.get_node("/root/Map/Core/UI")
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	ui.ToggleInterface()
	await r.wait(0.4)
	var cell = interface.characterUI.get_node_or_null("Stats/Elements/KC_Kills")
	r.check("KillCounter: shown in the character panel", cell != null and cell.visible and cell.get_node("Header").text == "Kills" and int(cell.get_node("Value").text) == KC.total(), cell.get_node("Value").text if cell else "")
	r.close_ui(ui)
	await r.wait(0.3)
	KC.wipe()
	r.check("KillCounter: wiped with the save", KC.total() == 0)
