# Road to Tarkov: containers you haven't finished searching say [Search].
extends "res://Scripts/LootContainer.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")


func UpdateTooltip():
	super()
	if not locked and RTT.should_search(self) and not bool(get_meta("rtt_searched", false)):
		gameData.tooltip = containerName + " [Search]"
