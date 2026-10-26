# Fixes Overhaul: event chances are real. The game picks one event first and
# rolls only that one, so with four possible events a "15%" event happened
# under 4% of the time. One roll over all of them fixes it. (With Event
# Hints on, it does this itself and this script stands aside.)
extends "res://Scripts/EventSystem.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func ActivateDynamicEvent():
	if not FO.on("event_odds"):
		super()
		return
	if dynamicEvents.size() == 0:
		return
	var event = FO.fair_pick(dynamicEvents, float(FO.setting("event_empty")))
	if event == null:
		print("Event failed: Event Roll (fair odds)")
		return
	if event.night and gameData.TOD != 4:
		print("Event failed: Night requirement")
		return
	if event.instant:
		print("Event Activated (Dynamic): " + event.name)
		Callable(self, event.function).call()
		return
	var delay := randi_range(0, 300)
	print("Event Activated (Dynamic): %s | Delay: %02d:%02d" % [event.name, delay / 60, delay % 60])
	await get_tree().create_timer(delay, false).timeout
	Callable(self, event.function).call()
