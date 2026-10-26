# Multi-Use Items: uses left / max in the cell's corner.
extends "res://Scripts/Item.gd"

const MU = preload("res://CSMultiUseItems/Mod.gd")


func UpdateDetails():
	super()
	# Tarkov Looting hides unknown items' details: don't give them away.
	var unknown: bool = "tl_mark" in self and self.get("tl_mark") != null and self.get("tl_mark").visible
	if MU.mine(slotData) and not unknown:
		var left := MU.uses_left(slotData)
		var most := MU.max_uses(slotData.itemData)
		condition.text = "%d/%d" % [left, most]
		condition.show()
		var f := float(left) / most
		condition.modulate = Color.GREEN if f > 0.5 else (Color.YELLOW if f > 0.25 else Color.RED)
