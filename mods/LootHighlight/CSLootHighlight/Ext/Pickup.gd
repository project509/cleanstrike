# Loot Highlight: every item lying in the world is known to the highlighter.
extends "res://Scripts/Pickup.gd"

const LH = preload("res://CSLootHighlight/Mod.gd")


func _ready():
	super()
	LH.register(self)
