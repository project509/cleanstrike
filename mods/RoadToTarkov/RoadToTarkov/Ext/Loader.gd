# Road to Tarkov: teaches the game's scene loader where Customs lives.
# LoadScene only assigns scenePath for maps it knows, then loads scenePath,
# so setting it first is all an unknown map needs.
extends "res://Scripts/Loader.gd"

const CUSTOMS_SCENE := "res://RoadToTarkov/Customs/Customs.tscn"


func LoadScene(scene: String):
	if scene == "Customs":
		scenePath = CUSTOMS_SCENE
		gameData.menu = false
		gameData.shelter = false
		gameData.permadeath = false
		gameData.tutorial = false
	super(scene)
