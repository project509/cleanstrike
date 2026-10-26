# Better Traders: count kills by faction for the traders' kill contracts.
extends "res://Scripts/AI.gd"

const M = preload("res://CSBetterTraders/Mod.gd")


func Death(direction, force):
	var was_dead: bool = dead
	super(direction, force)
	if not was_dead and M.on("kill_contracts") and variant:
		M.record_kill(AIData.Faction.keys()[variant.faction])
