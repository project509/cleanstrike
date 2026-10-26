# Faction Warfare: who an AI counts as a target, by faction; your chosen
# side leaves you alone.
extends "res://Scripts/Sensor.gd"

const FW = preload("res://CSFactionWarfare/Mod.gd")


func Targets():
	if not FW.active() or not ("variant" in owner) or owner.variant == null:
		super()
		return
	var mine: int = owner.variant.faction
	var found: Array[Node3D] = []
	for group in ["AI", "Nomad"]:
		for t in get_tree().get_nodes_in_group(group):
			var them = t.owner
			if them == owner or them == null or not ("variant" in them) or them.variant == null:
				continue
			if them.active and not them.dead and FW.hostile(mine, them.variant.faction):
				found.append(t)
	if PlayerValid():
		found.append(get_tree().get_first_node_in_group("Player"))
	targets = found


func PlayerValid() -> bool:
	if FW.active() and "variant" in owner and owner.variant and FW.allied(owner.variant.faction):
		return false
	return super()
