# Death and Hit Effects: a pool of blood spreads under the fallen.
extends "res://Scripts/AI.gd"

const DHE = preload("res://CSDeathHitEffects/Mod.gd")


func Death(direction, force):
	super(direction, force)
	if DHE.active():
		_dhe_pool.call_deferred()


func _dhe_pool() -> void:
	await get_tree().create_timer(2.0, false).timeout   # let the body settle
	if is_instance_valid(self) and is_inside_tree():
		var chest = skeleton.get_node_or_null("Chest") if skeleton else null
		DHE.pool(chest if chest is Node3D else self)
