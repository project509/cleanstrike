# Road to Tarkov: main-menu entry for walking around Customs.
# Preview runs in the game's tutorial mode, so nothing is loaded from or
# written to the player's saves (no gear, no progress, quitting is safe).
extends "res://Scripts/Menu.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")

var rtt_preview: Button


func _ready():
	super()
	if not RTT.customs_enabled() or not bool(RTT.setting("customs_preview_button")):
		return
	rtt_preview = tutorialButton.duplicate(0)
	rtt_preview.name = "RTT_CustomsPreview"
	rtt_preview.text = "Customs (Preview)"
	rtt_preview.disabled = false
	rtt_preview.pressed.connect(_rtt_on_preview)
	tutorialButton.get_parent().add_child(rtt_preview)
	tutorialButton.get_parent().move_child(rtt_preview, tutorialButton.get_index() + 1)


func _rtt_on_preview() -> void:
	Loader.LoadScene("CustomsPreview")
