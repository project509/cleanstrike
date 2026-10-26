# Death and Hit Effects: your hits on people show a marker and splatter
# blood on what is behind them.
extends "res://Scripts/WeaponRig.gd"

const DHE = preload("res://CSDeathHitEffects/Mod.gd")


func BloodEffect(hitCollider, hitPoint, hitNormal):
	super(hitCollider, hitPoint, hitNormal)
	if not DHE.active():
		return
	var target = hitCollider.owner if hitCollider else null
	var killed: bool = target != null and "dead" in target and target.dead
	DHE.marker(get_tree(), killed)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dir: Vector3 = hitPoint - cam.global_position
		DHE.splatter(self, hitPoint + dir.normalized() * 0.05, dir, [hitCollider.get_rid()] if hitCollider is CollisionObject3D else [])
