# Fixes Overhaul: a closed door always swings away from you, never into you.
extends "res://Scripts/Door.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func Interact():
	if FO.on("doors") and not isOpen and not (key and locked) and not jammed and not isOccupied \
			and absf(openAngle.y) > 1.0 and rotation_degrees.distance_to(defaultRotation) < 2.0:
		var away := FO.door_away_sign(self, gameData.playerPosition)
		if away != 0:
			openAngle.y = absf(openAngle.y) * away
	super()
