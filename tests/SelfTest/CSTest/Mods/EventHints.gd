# Self-test for Event Hints (cs_event_hints). r is the CSTest runner.
extends RefCounted

const EH = preload("res://CSEventHints/Mod.gd")
const N := 20000


func run(r) -> void:
	r.check("EventHints: active", EH.active())
	var all: Array = load("res://Events/Events.tres").events
	var dynamic := all.filter(func(e): return str(e.type) == "Dynamic")
	var unknown := dynamic.filter(func(e): return EH.key_of(e) == "")
	r.check("EventHints: knows every dynamic event", unknown.is_empty() and dynamic.size() == 8, "%d dynamic, unknown: %s" % [dynamic.size(), str(unknown.map(func(e): return e.name))])
	var airdrop = dynamic.filter(func(e): return EH.key_of(e) == "airdrop")[0]
	var jets = dynamic.filter(func(e): return EH.key_of(e) == "jets")[0]
	var outpost = dynamic.filter(func(e): return EH.key_of(e) == "outpost")[0]
	r.check("EventHints: Outpost BTR is its own event", EH.key_of(outpost) == "outpost" and str(outpost.function) == "BTR")
	r.check("EventHints: game chances by default", EH.chance(airdrop) == 15 and EH.chance(jets) == 25)

	# Chances show in the game's Events panel
	EH.overrides = {"airdrop_chance": 50}
	EH.apply_chances(all)
	r.check("EventHints: Events panel shows the chance", airdrop.possibility == 50)
	EH.overrides = {}
	EH.apply_chances(all)

	# The game's way: pick one, roll it (0-100 inclusive)
	var counts := _sample([airdrop, jets], false)
	var want_a := 0.5 * 16.0 / 101.0
	var want_j := 0.5 * 26.0 / 101.0
	r.check("EventHints: game odds kept", absf(counts.a - want_a) < 0.012 and absf(counts.j - want_j) < 0.015, "airdrop %.3f (%.3f), jets %.3f (%.3f)" % [counts.a, want_a, counts.j, want_j])
	EH.overrides = {"airdrop_weight": 0.0}
	counts = _sample([airdrop, jets], false)
	r.check("EventHints: weight 0 = never", counts.a == 0.0 and counts.j > 0.15, "jets %.3f" % counts.j)
	EH.overrides = {"airdrop_weight": 3.0}
	counts = _sample([airdrop, jets], false)
	r.check("EventHints: weights shift the pick", absf(counts.a - 0.75 * 16.0 / 101.0) < 0.015, "airdrop %.3f" % counts.a)
	EH.overrides = {}

	# Fair odds (CleanStrike Fixes Overhaul): stated chances are real
	counts = _sample([airdrop, jets], true)
	r.check("EventHints: fair odds = stated chances", absf(counts.a - 0.15) < 0.012 and absf(counts.j - 0.25) < 0.015, "airdrop %.3f, jets %.3f" % [counts.a, counts.j])
	var busy := dynamic.filter(func(e): return EH.key_of(e) in ["btr", "outpost", "helicopter", "jets", "airdrop"])
	var quiet := 0
	for i in N:
		if EH.fair_pick(busy, 20.0) == null:
			quiet += 1
	r.check("EventHints: fair odds keep 20% quiet when chances add past 80%", absf(float(quiet) / N - 0.2) < 0.015, "%.3f quiet" % (float(quiet) / N))

	# The real hook: an airdrop with a hint, no delay
	var sys := Node3D.new()
	sys.set_script(load("res://Scripts/EventSystem.gd"))
	sys.dynamicEvents.append(airdrop)
	EH.overrides = {"airdrop_chance": 100, "max_delay": 0}
	EH.last_hint = ""
	sys.ActivateDynamicEvent()
	r.check("EventHints: event starts with its hint", sys.get_child_count() == 1 and EH.last_hint == EH.EVENTS.airdrop[2], EH.last_hint)
	EH.overrides = {"airdrop_chance": 100, "max_delay": 0, "airdrop_hint": false}
	EH.last_hint = ""
	sys.ActivateDynamicEvent()
	r.check("EventHints: hint can be switched off", sys.get_child_count() == 2 and EH.last_hint == "")
	sys.free()
	EH.overrides = {}


func _sample(pool: Array, fair: bool) -> Dictionary:
	var a := 0
	var j := 0
	for i in N:
		var e = EH.choose(pool, fair)
		if e == pool[0]:
			a += 1
		elif e == pool[1]:
			j += 1
	return {"a": float(a) / N, "j": float(j) / N}
