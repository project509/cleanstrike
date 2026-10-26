# Weather and Seasons: steers the game's Simulation autoload. Weather is
# rolled with our odds just before the game would roll its own; seasons turn
# after so many days, on the next map change.
extends Node

const WS = preload("res://CSWeatherSeasons/Mod.gd")

var last_day := -1
var last_map := 0


func _process(_delta: float) -> void:
	var sim = get_node_or_null("/root/Simulation")
	if sim == null or not WS.active() or not sim.simulate:
		return
	# Weather: beat the game's roll by a moment
	if sim.weatherTime <= 0.25:
		var w := WS.roll_weather()
		sim.weather = w[0]
		sim.weatherTime = w[1]
	# Seasons: count days, turn when due
	if bool(WS.setting("seasons")):
		if last_day == -1:
			last_day = int(sim.day)
		elif int(sim.day) < last_day:   # a new game: count afresh
			last_day = int(sim.day)
			WS.reset()
		elif int(sim.day) != last_day:
			last_day = int(sim.day)
			WS.new_day(int(sim.season))
		var m = get_node_or_null("/root/Map")
		var id := m.get_instance_id() if m else 0
		if id != last_map:
			last_map = id
			var s := WS.take_pending(int(sim.season))
			if s != int(sim.season):
				sim.season = s
