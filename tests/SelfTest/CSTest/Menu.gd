extends "res://Scripts/Menu.gd"
func _ready():
	super()
	get_node("/root/CSTest").menu_preview_button = find_child("RTT_CustomsPreview", true, false) != null
	if not get_node("/root/CSTest").started:
		get_node("/root/CSTest").started = true
		Loader.LoadScene("Tutorial")
