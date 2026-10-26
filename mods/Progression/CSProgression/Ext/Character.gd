# Progression: Endurance, Steady Hands and Metabolism ease the drains.
extends "res://Scripts/Character.gd"

const PG = preload("res://CSProgression/Mod.gd")


func Stamina(delta):
	var body: float = gameData.bodyStamina
	var arms: float = gameData.armStamina
	super(delta)
	PG.ease_drain(gameData, "bodyStamina", body, PG.bonus("endurance"))
	PG.ease_drain(gameData, "armStamina", arms, PG.bonus("steady"))


func Energy(delta):
	var before: float = gameData.energy
	super(delta)
	PG.ease_drain(gameData, "energy", before, PG.bonus("metabolism"))


func Hydration(delta):
	var before: float = gameData.hydration
	super(delta)
	PG.ease_drain(gameData, "hydration", before, PG.bonus("metabolism"))
