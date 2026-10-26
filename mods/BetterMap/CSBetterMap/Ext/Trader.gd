# Better Map: meeting a trader puts them on the map.
extends "res://Scripts/Trader.gd"

const BM = preload("res://CSBetterMap/Mod.gd")


func _ready():
	super()
	if BM.active() and traderData:
		BM.meet(str(traderData.name))
