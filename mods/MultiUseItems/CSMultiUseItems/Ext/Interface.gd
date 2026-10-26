# Multi-Use Items: using an item takes one use (its share of the effect);
# crafting takes one use of each multi-use ingredient.
extends "res://Scripts/Interface.gd"

const MU = preload("res://CSMultiUseItems/Mod.gd")


func Use(targetItem, targetGrid):
	if targetItem == null or not MU.mine(targetItem.slotData):
		return await super(targetItem, targetGrid)
	var last := MU.uses_left(targetItem.slotData) <= 1
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
		var data: ItemData = targetItem.slotData.itemData
		character.Consume(MU.share(data))
		if last:
			targetGrid.Pick(targetItem)
			targetItem.queue_free()
			for leftover in data.used:   # the empty bottle and so on
				var sd := SlotData.new()
				sd.itemData = leftover
				if not AutoStack(sd, targetGrid):
					Create(sd, targetGrid, true)
		elif is_instance_valid(targetItem):
			MU.set_uses(targetItem.slotData, MU.uses_left(targetItem.slotData) - 1)
			targetItem.UpdateDetails()
		activeProgress.queue_free()
		activeProgress = null
		gameData.isOccupied = false
		Reset()


func DestroyInputItems(data: Resource):
	if MU.active() and bool(MU.setting("crafting")) and data is RecipeData and not data.upgrade:
		for child in inventoryGrid.get_children():
			if child.selected and MU.tracked(child.slotData) and MU.uses_left(child.slotData) > 1:
				MU.set_uses(child.slotData, MU.uses_left(child.slotData) - 1)
				child.State("Static")   # kept: super() only takes selected items
				child.UpdateDetails()
	super(data)
