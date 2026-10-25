extends "res://Scripts/Menu.gd"
func _ready():
	super()
	if not get_node("/root/CSTest").started:
		get_node("/root/CSTest").started = true
		Loader.LoadScene("Tutorial")
