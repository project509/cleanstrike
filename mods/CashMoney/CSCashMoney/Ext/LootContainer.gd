# Cash Money: a little cash in some civilian and military containers.
extends "res://Scripts/LootContainer.gd"

const CM = preload("res://CSCashMoney/Mod.gd")


func _ready():
	super()
	if CM.active() and custom.is_empty() and not locked and not furniture and not corpse and not stash \
			and (civilian or military) and randf() * 100.0 < float(CM.setting("container_chance")):
		loot.append(CM.stack(randi_range(5, 120 if military else 60)))
