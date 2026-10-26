# Hold Breath: the weapon's sway shrinks while you hold your breath, and
# grows for a moment if you hold it until you run out.
extends "res://Scripts/Noise.gd"

const HB = preload("res://CSHoldBreath/Mod.gd")

static var hb_frame := -1   # the breath advances once per frame, whatever the rig count


func _physics_process(delta):
	super(delta)
	if not HB.active() or not is_visible_in_tree():
		return
	var frame := Engine.get_physics_frames()
	if frame != hb_frame:
		hb_frame = frame
		HB.step(gameData, delta)
	if HB.sway != 1.0:
		rotation *= HB.sway
