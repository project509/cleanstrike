# Fixes Overhaul (optional, off by default): no shadows from the lights
# around traders and the traders themselves, for players who get frame drops
# looking toward a trader. Changes nothing on disk.
extends "res://Scripts/Trader.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")
const RADIUS := 15.0


func _ready():
	super()
	if FO.on("trader_shadows"):
		FO_QuietShadows()


func FO_QuietShadows() -> int:
	var changed := 0
	for n in find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		changed += 1
	for l in get_tree().current_scene.find_children("*", "Light3D", true, false):
		var light := l as Light3D
		if light.shadow_enabled and light.global_position.distance_to(global_position) <= RADIUS:
			light.shadow_enabled = false
			changed += 1
	return changed
