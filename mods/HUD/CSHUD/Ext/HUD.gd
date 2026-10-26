# CleanStrike HUD: adds the overlay to the game's HUD, the centre dot and
# hide-HUD keys, and hides the game's vitals text while the bars show.
extends "res://Scripts/HUD.gd"

const HM = preload("res://CSHUD/Mod.gd")

var hm_overlay: Control


func _ready():
	super()
	if not HM.active():
		return
	if not HM.dot_init:
		HM.dot_init = true
		HM.dot_on = bool(HM.setting("dot"))
	hm_overlay = HM.OVERLAY.new()
	hm_overlay.name = "CS_HUD"
	add_child(hm_overlay)


func _physics_process(delta):
	super(delta)
	if hm_overlay == null:
		return
	hm_overlay.visible = not HM.hidden
	if HM.hidden:
		stats.hide()
	elif bool(HM.setting("bars")) and bool(HM.setting("hide_game_vitals")):
		vitals.hide()


func _unhandled_input(event):
	if hm_overlay == null:
		return
	if HM.key_pressed(event, "dot_key"):
		HM.dot_on = not HM.dot_on
	elif HM.key_pressed(event, "hide_key"):
		HM.hidden = not HM.hidden
		if not HM.hidden:
			stats.show()
