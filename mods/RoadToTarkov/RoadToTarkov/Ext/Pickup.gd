# Road to Tarkov: loose loot you have never examined reads "Unknown item".
extends "res://Scripts/Pickup.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")


func UpdateTooltip():
	super()
	if RTT.is_unknown(slotData):
		if slotData.itemData.showAmount:
			gameData.tooltip = "Unknown item [x%d]" % slotData.amount
		else:
			gameData.tooltip = "Unknown item"
