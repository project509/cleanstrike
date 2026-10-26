# Self-test for Tactical Watch (cs_tactical_watch). r is the CSTest runner.
extends RefCounted

const TW = preload("res://CSTacticalWatch/Mod.gd")


func run(r) -> void:
	r.check("TacticalWatch: active", TW.active())
	var hud = r.get_node("/root/Map/Core/UI/HUD")
	var panel = hud.get_node_or_null("CS_Watch")
	r.check("TacticalWatch: panel on the HUD", panel != null)
	var w = load("res://Items/Electronics/Watch_Tactical/Watch_Tactical.tres")
	r.check("TacticalWatch: watch sold by the Gunsmith, found in civilian loot", w.gunsmith and w.civilian)
	r.check("TacticalWatch: no watch, no panel", not TW.wearing() and not (TW.shown and TW.visible_now()))
	TW.overrides = {"needs_watch": false}
	var e := InputEventKey.new()
	e.physical_keycode = KEY_Y
	e.pressed = true
	TW.shown = false
	panel._unhandled_input(e)
	r.check("TacticalWatch: Y shows the panel", TW.visible_now())
	await r.wait(0.1)
	var text := ""
	for l in panel.lines:
		text += str(l[0]) + " | "
	r.check("TacticalWatch: time, day, place and heading", panel.lines.size() >= 4 and ":" in str(panel.lines[0][0]) and "Day" in text and "Tutorial" in text and not "(Tutorial)" in text and "Heading" in text, text)
	r.check("TacticalWatch: compass words", TW.compass(0) == "N" and TW.compass(91) == "E" and TW.compass(225) == "SW")
	r.check("TacticalWatch: bearings", absf(TW.bearing(Vector3.ZERO, Vector3(10, 0, 0)) - 90.0) < 0.01)
	panel._unhandled_input(e)
	r.check("TacticalWatch: Y hides it again", not TW.visible_now())
	TW.overrides = {}
