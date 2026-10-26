# Self-test for CleanStrike Fixes Overhaul (cs_fixes_overhaul). r is the CSTest runner (r.check, r.wait, ...).
extends RefCounted

const M = preload("res://CSFixesOverhaul/Mod.gd")


func run(r) -> void:
	r.check("FixesOverhaul: active", M.active())
