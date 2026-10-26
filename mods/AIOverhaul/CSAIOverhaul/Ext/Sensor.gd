# AI Overhaul: sight and hearing scaled by faction, weather and your stance,
# on top of the game's (and other mods') night, fog and flashlight rules.
# Applied when targets are chosen, after every Visibility() hook has run this
# frame, so load order doesn't matter.
extends "res://Scripts/Sensor.gd"

const AOS = preload("res://CSAIOverhaul/Mod.gd")

var ao_base_hear := -1.0


func Priority():
	AO_Scale()
	super()


func AO_Scale() -> void:
	if not AOS.active() or boostTimer > 0.0:
		return
	var faction: int = owner.variant.faction if owner and "variant" in owner and owner.variant else -1
	var sim = get_node_or_null("/root/Simulation")
	viewDistance *= AOS.view_factor(gameData, faction, str(sim.weather) if sim else "")
	if ao_base_hear < 0.0:
		ao_base_hear = hearDistance
	hearDistance = ao_base_hear * AOS.hear_factor(gameData)
