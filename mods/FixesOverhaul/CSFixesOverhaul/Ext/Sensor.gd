# Fixes Overhaul: at night AI see 40 m, in fog 100 m; on a foggy night the
# game let fog win (100 m). The tighter limit applies now.
extends "res://Scripts/Sensor.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func Visibility(delta):
	super(delta)
	if FO.on("ai_night_fog") and boostTimer <= 0.0:
		viewDistance = FO.sight_distance(gameData.fog, gameData.TOD == 4)
