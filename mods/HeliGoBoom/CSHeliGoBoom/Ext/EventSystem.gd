# Heli Go Boom: a crash site appears some time after you arrive (not before),
# with an explosion you hear near or far.
extends "res://Scripts/EventSystem.gd"

const HB = preload("res://CSHeliGoBoom/Mod.gd")
const LIB = preload("res://Resources/AudioLibrary.tres")
const AUDIO_2D = preload("res://Resources/AudioInstance2D.tscn")
const AUDIO_3D = preload("res://Resources/AudioInstance3D.tscn")


func CrashSite():
	if not HB.active():
		super()
		return
	var delay := randi_range(0, maxi(0, int(HB.setting("max_delay"))))
	if delay > 0:
		await get_tree().create_timer(delay, false).timeout
	var before := _hb_sites()
	super()
	for site in _hb_sites():
		if not (site in before):
			HB_Boom(site.global_position)


func _hb_sites() -> Array:
	var out := []
	for spot in crashes.get_children():
		out.append_array(spot.get_children())
	return out


# The game's own explosion sounds: close by in 3D, otherwise the distant one.
func HB_Boom(at: Vector3) -> void:
	var distance: float = at.distance_to(gameData.playerPosition)
	if distance < 150.0:
		var a = AUDIO_3D.instantiate()
		get_tree().current_scene.add_child(a)
		a.global_position = at
		a.PlayInstance(LIB.explosionOutdoorClose if distance > 50.0 else LIB.explosionOutdoorNear, 50, 400)
		HB.last_boom = "close"
	else:
		var a = AUDIO_2D.instantiate()
		add_child(a)
		a.PlayInstance(LIB.explosionOutdoorFar)
		HB.last_boom = "far"
