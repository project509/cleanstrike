# Tarkov Looting: loose loot you have never examined reads "Unknown item".
extends "res://Scripts/Pickup.gd"

const TL = preload("res://TarkovLooting/TL.gd")


func UpdateTooltip():
	super()
	if TL.is_unknown(slotData):
		if slotData.itemData.showAmount:
			gameData.tooltip = "Unknown item [x%d]" % slotData.amount
		else:
			gameData.tooltip = "Unknown item"
