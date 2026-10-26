# Self-test for Weather and Seasons (cs_weather_seasons). r is the CSTest runner.
extends RefCounted

const WS = preload("res://CSWeatherSeasons/Mod.gd")


func run(r) -> void:
	r.check("WeatherSeasons: active", WS.active())
	WS.overrides = {"w_neutral": 0, "w_rain": 0, "w_storm": 5, "w_overcast": 0, "w_wind": 0, "w_aurora": 0, "min_minutes": 2.0, "max_minutes": 3.0}
	var ok := true
	for i in 20:
		var w := WS.roll_weather()
		ok = ok and w[0] == "Storm" and w[1] >= 120.0 and w[1] <= 180.0
	r.check("WeatherSeasons: weights and durations", ok)
	var sim = r.get_node("/root/Simulation")
	var keep := [sim.weather, sim.weatherTime, sim.simulate, sim.season]
	sim.simulate = true
	sim.weatherTime = 0.1
	for i in 3:
		await r.get_tree().process_frame
	r.check("WeatherSeasons: the game's weather uses our odds", sim.weather == "Storm" and sim.weatherTime > 100.0, "%s %.0f" % [sim.weather, sim.weatherTime])
	var saved: Dictionary = WS.state().duplicate()
	WS._state = {}
	WS.overrides = {"summer_days": 2}
	var first := WS.new_day(1)
	var second := WS.new_day(1)
	r.check("WeatherSeasons: winter due after the summer days", not first and second)
	r.check("WeatherSeasons: winter arrives on travel", WS.take_pending(1) == 2 and WS.take_pending(2) == 2 and int(WS.state().days) == 0)
	WS._state = saved
	WS.overrides = {}
	sim.weather = keep[0]
	sim.weatherTime = keep[1]
	sim.simulate = keep[2]
	sim.season = keep[3]
