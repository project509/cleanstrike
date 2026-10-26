# Better Traders: a daily task row. Uses the game's task row (deliveries work
# exactly like normal tasks); kill contracts complete once you've made the
# kills today. Dailies never go into the trader's real task list.
extends "res://Scripts/Task.gd"

const M = preload("res://CSBetterTraders/Mod.gd")


func BT_Setup(done: bool) -> void:
	var i := M.DAILY_LABELS.find(taskData.difficulty)
	if i >= 0:
		difficulty.modulate = M.DAILY_COLORS[i]
	var kill = taskData.get_meta("bt_kill") if taskData.has_meta("bt_kill") else null
	if kill:
		inputButton.hide()
		inputGrid.hide()
		inputItems.text = "%d / %d %ss killed today" % [mini(M.kills_today(kill.faction), kill.count), kill.count, kill.faction]
	if done:
		Completed()
		inputButton.text = "Completed today"
	else:
		Default()
		if kill:
			CanComplete()


func UpdateNoteButtons():
	addButton.hide()
	removeButton.hide()


func CanComplete():
	var kill = taskData.get_meta("bt_kill") if taskData and taskData.has_meta("bt_kill") else null
	if kill:
		completeButton.disabled = completed or M.kills_today(kill.faction) < int(kill.count)
		return
	super()
