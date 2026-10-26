# Medical Durability: using a medical item takes one use; the item is only
# used up on its last one.
extends "res://Scripts/Interface.gd"

const MD = preload("res://CSMedicalDurability/Mod.gd")


func Use(targetItem, targetGrid):
	if targetItem == null or not MD.tracked(targetItem.slotData) or MD.uses_left(targetItem.slotData) <= 1:
		return await super(targetItem, targetGrid)
	gameData.isOccupied = true
	PlayUse(targetItem.slotData.itemData)
	var bar = progress.instantiate()
	add_child(bar)
	bar.global_position = targetItem.global_position
	bar.size = targetItem.size
	bar.Use(4.0)
	activeProgress = bar
	await activeProgress.completed
	if gameData.isDead:
		return
	if activeProgress:
		character.Consume(targetItem.slotData.itemData)
		if is_instance_valid(targetItem):
			MD.set_uses(targetItem.slotData, MD.uses_left(targetItem.slotData) - 1)
			targetItem.UpdateDetails()
		activeProgress.queue_free()
		activeProgress = null
		gameData.isOccupied = false
		Reset()
