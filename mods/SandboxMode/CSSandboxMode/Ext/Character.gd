# Sandbox Mode: god mode, no needs, infinite stamina, no weight limit.
extends "res://Scripts/Character.gd"

const SB = preload("res://CSSandboxMode/Mod.gd")


func _physics_process(delta):
	super(delta)
	if not SB.active():
		return
	if SB.on("god"):
		gameData.health = 100.0
		for f in ["bleeding", "fracture", "burn", "poisoning", "rupture", "headshot", "frostbite"]:
			if gameData.get(f):
				gameData.set(f, false)
	if SB.on("no_needs"):
		gameData.energy = 100.0
		gameData.hydration = 100.0
		gameData.mental = 100.0
		gameData.temperature = 100.0
	if SB.on("stamina"):
		gameData.bodyStamina = 100.0
		gameData.armStamina = 100.0


func Overweight(active: bool):
	super(active and not (SB.active() and SB.on("no_weight")))


func Death():
	if SB.active() and SB.on("god"):
		gameData.health = 100.0
		return
	super()
