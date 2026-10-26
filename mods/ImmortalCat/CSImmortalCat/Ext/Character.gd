# Immortal Cat: the cat's hunger never reaches zero, so it never dies
# (optionally it's never hungry at all).
extends "res://Scripts/Character.gd"

const IC = preload("res://CSImmortalCat/Mod.gd")


func Cat(delta):
	if IC.active() and gameData.catFound and not gameData.catDead:
		if bool(IC.setting("never_hungry")):
			gameData.cat = 100.0
		elif gameData.cat - delta / 50.0 <= 1.0:
			gameData.cat = 1.0 + delta / 50.0   # stays at 1% after the game's drain
	super(delta)
