# CleanStrike Zombies: a hitbox on one body part. The game's weapons only
# shoot things that are a Hitbox, so this is one; it tells the zombie which
# part was hit and with how much.
extends "res://Scripts/Hitbox.gd"

@export var part := "torso"   # exported: it has to survive packing


func ApplyDamage(damage: float, vector: Vector3, id: Node3D):
	if owner and owner.has_method("Hit"):
		owner.Hit(part, damage, vector, id, global_position)
