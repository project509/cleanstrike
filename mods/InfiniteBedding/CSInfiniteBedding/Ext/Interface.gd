# Infinite Bedding: sleeping on a sleeping bag, mattress or pillow doesn't
# use it up (the game deleted it).
extends "res://Scripts/Interface.gd"

const IB = preload("res://CSInfiniteBedding/Mod.gd")


func ContextSleep():
	if contextItem == null or contextGrid == null or not IB.keeps(contextItem):
		super()
		return
	var sleepItem = contextItem.slotData.itemData
	HideContext()
	PlayClick()
	Reset()
	UIManager.ToggleInterface()
	Sleep(sleepItem)
