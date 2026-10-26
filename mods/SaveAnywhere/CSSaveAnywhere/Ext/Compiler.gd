# Save Anywhere: after arriving on the map you quit on, back to your spot.
extends "res://Scripts/Compiler.gd"

const SA = preload("res://CSSaveAnywhere/Mod.gd")


func Spawn():
	var s: Dictionary = SA.pending
	var map = get_tree().current_scene.get_node_or_null("/root/Map")
	var resuming: bool = not s.is_empty() and map != null and str(s.map) == str(map.mapName)
	super()
	if not resuming:
		return
	SA.pending = {}
	SA.clear()
	var pos := Vector3(float(s.pos[0]), float(s.pos[1]), float(s.pos[2]))
	for i in 3:   # the game may still be placing you for a moment
		controller.global_position = pos
		controller.global_rotation.y = float(s.rot)
		await get_tree().create_timer(0.15, false).timeout
	Loader.Message("Back where you left off", Color.GREEN)
