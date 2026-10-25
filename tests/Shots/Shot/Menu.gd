extends "res://Scripts/Menu.gd"
func _ready():
	super()
	if not get_node("/root/CSShot").started:
		get_node("/root/CSShot").started = true
		Loader.LoadScene("Tutorial")
