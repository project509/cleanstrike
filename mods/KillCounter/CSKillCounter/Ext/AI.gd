# Kill Counter: counts enemies the player kills (not ones killed by others).
extends "res://Scripts/AI.gd"

const KC = preload("res://CSKillCounter/Mod.gd")

var kc_by_player := false


func WeaponDamage(hitbox: String, damage: float, vector: Vector3, id: Node3D):
	kc_by_player = id != null and id.is_in_group("Player")
	super(hitbox, damage, vector, id)


func ExplosionDamage(direction, id: Node3D):
	kc_by_player = id != null and id.is_in_group("Player")
	super(direction, id)


func Death(direction, force):
	var was_dead: bool = dead
	super(direction, force)
	if was_dead or not kc_by_player or not KC.active() or variant == null:
		return
	var faction: String = variant.name if variant.faction == variant.Faction.Boss else AIData.Faction.keys()[int(variant.faction)]
	var n := KC.add(faction)
	if bool(KC.setting("messages")):
		Loader.Message("%s killed (%d)  ·  %d kills" % [faction, n, KC.total()], Color(0.9, 0.85, 0.7))
