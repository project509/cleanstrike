# Self-test for No Permadeath (cs_no_permadeath). r is the CSTest runner (r.check, r.wait, ...).
extends RefCounted

const M = preload("res://CSNoPermadeath/Mod.gd")


func run(r) -> void:
	r.check("NoPermadeath: active", M.active())
