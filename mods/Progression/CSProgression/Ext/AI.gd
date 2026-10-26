# Progression: XP for your kills (more for headshots, knives and explosives).
extends "res://Scripts/AI.gd"

const PG = preload("res://CSProgression/Mod.gd")

var pg_by_player := false
var pg_bonus := 1.0


func WeaponDamage(hitbox: String, damage: float, vector: Vector3, id: Node3D):
	pg_by_player = id != null and id.is_in_group("Player")
	pg_bonus = 2.0 if gameData.knife else (1.25 if hitbox == "Head" else 1.0)
	super(hitbox, damage, vector, id)


func ExplosionDamage(direction, id: Node3D):
	pg_by_player = id != null and id.is_in_group("Player")
	pg_bonus = 1.5
	super(direction, id)


func Death(direction, force):
	var was_dead: bool = dead
	super(direction, force)
	if was_dead or not pg_by_player or variant == null:
		return
	PG.add_xp(PG.KILL_XP.get(int(variant.faction), 20) * pg_bonus, "kill")
