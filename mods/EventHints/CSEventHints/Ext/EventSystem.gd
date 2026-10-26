# Event Hints: your chances and weights for each event, the start delay, and
# a hint when an event is on its way.
extends "res://Scripts/EventSystem.gd"

const EH = preload("res://CSEventHints/Mod.gd")


func GetAvailableEvents():
	if EH.active():
		EH.apply_chances(events.events)
	super()


func ActivateDynamicEvent():
	if not EH.active():
		super()
		return
	if dynamicEvents.size() == 0:
		return
	var event = EH.choose(dynamicEvents, EH.fair_odds())
	if event == null:
		print("Event failed: Event Roll (Event Hints)")
		return
	if event.night and gameData.TOD != 4:
		print("Event failed: Night requirement")
		return
	var text := EH.hint(event)
	if text != "":
		EH.last_hint = text
		Loader.Message(text, Color(0.86, 0.82, 0.66))
	if event.instant:
		print("Event Activated (Dynamic): " + event.name)
		Callable(self, event.function).call()
		return
	var delay := randi_range(0, maxi(0, int(EH.setting("max_delay"))))
	print("Event Activated (Dynamic): %s | Delay: %02d:%02d" % [event.name, delay / 60, delay % 60])
	if delay > 0:
		await get_tree().create_timer(delay, false).timeout
	Callable(self, event.function).call()
