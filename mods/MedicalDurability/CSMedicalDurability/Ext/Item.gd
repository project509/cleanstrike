# Medical Durability: the cell's corner shows uses left instead of a %.
extends "res://Scripts/Item.gd"

const MD = preload("res://CSMedicalDurability/Mod.gd")


func UpdateDetails():
	super()
	# Tarkov Looting hides unknown items' details: don't give them away.
	var unknown: bool = "tl_mark" in self and self.get("tl_mark") != null and self.get("tl_mark").visible
	if MD.tracked(slotData) and not unknown:
		var left := MD.uses_left(slotData)
		condition.text = "x%d" % left
		condition.show()
		var f := float(left) / MD.max_uses(slotData.itemData)
		condition.modulate = Color.GREEN if f > 0.5 else (Color.YELLOW if f > 0.25 else Color.RED)
