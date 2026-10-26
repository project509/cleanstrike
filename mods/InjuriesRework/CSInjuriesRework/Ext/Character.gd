# Injuries Rework: each injury has its own effect instead of a health drain.
extends "res://Scripts/Character.gd"

const IR = preload("res://CSInjuriesRework/Mod.gd")

var ir_bleed := 0.0       # seconds the current bleed has run
var ir_head_bleed := false


func Health(delta):
	if not IR.active():
		super(delta)
		return
	# The game's drains, without the injuries this mod handles itself
	var keep := [gameData.bleeding, gameData.fracture, gameData.rupture, gameData.headshot, gameData.burn]
	gameData.bleeding = false
	gameData.fracture = false
	gameData.rupture = false
	gameData.headshot = false
	gameData.burn = gameData.burn and bool(IR.setting("burn_damage"))
	super(delta)
	gameData.bleeding = keep[0]
	gameData.fracture = keep[1]
	gameData.rupture = keep[2]
	gameData.headshot = keep[3]
	gameData.burn = keep[4]
	if gameData.isDead:
		return
	gameData.health -= IR.drain(gameData, delta)
	# A bleed runs its course
	if gameData.bleeding:
		ir_bleed += delta
		var limit := float(IR.setting("bleed_seconds"))
		if ir_head_bleed and str(IR.setting("headshot_bleed")) == "vanilla":
			limit = 0.0
		if limit > 0.0 and ir_bleed >= limit:
			Bleeding(false)
	else:
		ir_bleed = 0.0
		ir_head_bleed = false
	if gameData.rupture:
		var m := float(IR.setting("rupture_hunger")) - 1.0
		gameData.energy -= delta / 30.0 * m
		gameData.hydration -= delta / 22.0 * m
	if gameData.health <= 0 and not gameData.isDead and not gameData.decor:
		Death()


func Stamina(delta):
	super(delta)
	if IR.active() and gameData.headshot:
		gameData.bodyStamina = 0.0                       # no running
		gameData.armStamina = maxf(0.0, gameData.armStamina - delta * 6.0)   # shaky aim


func Mental(delta):
	if IR.active() and not bool(IR.setting("injury_mental")):
		var keep := [gameData.bleeding, gameData.fracture, gameData.burn, gameData.rupture, gameData.headshot, gameData.poisoning]
		gameData.bleeding = false
		gameData.fracture = false
		gameData.burn = false
		gameData.rupture = false
		gameData.headshot = false
		gameData.poisoning = false
		super(delta)
		gameData.bleeding = keep[0]
		gameData.fracture = keep[1]
		gameData.burn = keep[2]
		gameData.rupture = keep[3]
		gameData.headshot = keep[4]
		gameData.poisoning = keep[5]
		return
	super(delta)


func Headshot(active: bool):
	super(active)
	if active and IR.active() and str(IR.setting("headshot_bleed")) != "none" and not gameData.bleeding:
		Bleeding(true)
		ir_head_bleed = true
