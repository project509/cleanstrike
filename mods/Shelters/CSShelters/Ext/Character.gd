# Shelters: inside a shelter needs drain slower, you heal while unhurt, and
# the cat gets hungry more slowly.
extends "res://Scripts/Character.gd"

const SH = preload("res://CSShelters/Mod.gd")


func Energy(delta):
	var before: float = gameData.energy
	super(delta)
	SH.slow(gameData, "energy", before, "needs_rate")


func Hydration(delta):
	var before: float = gameData.hydration
	super(delta)
	SH.slow(gameData, "hydration", before, "needs_rate")


func Mental(delta):
	var before: float = gameData.mental
	super(delta)
	SH.slow(gameData, "mental", before, "mental_rate")


func Cat(delta):
	var before: float = gameData.cat
	super(delta)
	if not gameData.catDead:
		SH.slow(gameData, "cat", before, "cat_rate")


func Health(delta):
	super(delta)
	if SH.resting(gameData):
		gameData.health = minf(100.0, gameData.health + float(SH.setting("heal_per_minute")) / 60.0 * delta)
