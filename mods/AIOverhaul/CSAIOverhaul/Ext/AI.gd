# AI Overhaul: aim spread around the real line of fire, accuracy by faction,
# bursts up close, and wounded enemies patching themselves up.
extends "res://Scripts/AI.gd"

const AO = preload("res://CSAIOverhaul/Mod.gd")

var ao_last_hit := -1000.0
var ao_last_heal := -1000.0
var ao_healing := 0.0


func FireAccuracy() -> Vector3:
	if not AO.active():
		return super()
	var mult := 2.5 if fullAuto else 1.0
	var reduce := 0.1 if optic else 0.0
	var offset: float = variant.accuracy.x if sensor.PDistance <= 10 else (variant.accuracy.y if sensor.PDistance <= 50 else variant.accuracy.z)
	offset *= AO.spread_mult(variant.faction)
	var target: Vector3 = sensor.PLocation - Vector3(0.0, 0.5, 0.0)
	return AO.spread_point(fire.global_position, target, offset * (mult - reduce))


func Selector(delta):
	super(delta)
	if AO.active() and sensor.PDistance < float(AO.setting("burst_range")) and not fullAuto and randf() < delta * 2.0:
		fullAuto = true
		selectorTime = randf_range(0.6, 1.5)


func WeaponDamage(hitbox: String, damage: float, vector: Vector3, id: Node3D):
	ao_last_hit = Time.get_ticks_msec() / 1000.0
	ao_healing = 0.0
	super(hitbox, damage, vector, id)


func _physics_process(delta: float) -> void:
	super(delta)
	if not AO.active() or dead or not active or not bool(AO.setting("self_heal")):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if health < 50 and now - ao_last_hit > 3.0 and now - ao_last_heal > float(AO.setting("heal_cooldown")):
		ao_healing += delta                   # six quiet seconds to patch up
		if ao_healing >= 6.0:
			health = minf(100.0, health + float(AO.setting("heal_amount")))
			ao_last_heal = now
			ao_healing = 0.0
	else:
		ao_healing = 0.0
