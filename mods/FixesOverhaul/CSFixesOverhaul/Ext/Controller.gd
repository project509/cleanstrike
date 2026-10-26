# Fixes Overhaul: unstuck. Hold the unstuck key (F9) for 2 seconds to go back
# to where you last stood on solid ground a few seconds ago.
extends "res://Scripts/Controller.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")
const SAFE_EVERY := 1.0      # seconds between remembered spots
const SAFE_KEEP := 30        # how many spots to remember
const BACK := 5.0            # go back to a spot at least this old
const HOLD := 2.0            # hold the key this long

var fo_safe: Array = []      # [time, position]
var fo_clock := 0.0
var fo_last_safe := -100.0
var fo_held := 0.0


func _physics_process(delta):
	super(delta)
	if not FO.on("unstuck"):
		return
	fo_clock += delta
	if is_on_floor() and not gameData.isSwimming and not gameData.freeze and fo_clock - fo_last_safe >= SAFE_EVERY:
		fo_last_safe = fo_clock
		fo_safe.append([fo_clock, global_position])
		if fo_safe.size() > SAFE_KEEP:
			fo_safe.pop_front()
	var code := OS.find_keycode_from_string(str(FO.setting("unstuck_key")))
	if code != KEY_NONE and Input.is_key_pressed(code) and not gameData.freeze:
		fo_held += delta
		if fo_held >= HOLD:
			fo_held = -1000.0   # once per press
			FO_Unstuck()
	elif fo_held != 0.0:
		fo_held = 0.0


# Back to the newest remembered spot that's at least BACK seconds old
# (or the oldest one there is).
func FO_Unstuck() -> bool:
	if fo_safe.is_empty():
		Loader.Message("Unstuck: nowhere safe remembered yet", Color.ORANGE)
		return false
	var spot = fo_safe[0]
	for s in fo_safe:
		if fo_clock - float(s[0]) >= BACK:
			spot = s
	global_position = spot[1]
	velocity = Vector3.ZERO
	Loader.Message("Unstuck: moved back to where you stood %d s ago" % int(fo_clock - float(spot[0])), Color.GREEN)
	return true
