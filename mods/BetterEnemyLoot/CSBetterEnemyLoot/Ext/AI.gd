# Better Enemy Loot: when an enemy dies, its body gets extra loot on top of
# what it already carried.
extends "res://Scripts/AI.gd"

const BEL = preload("res://CSBetterEnemyLoot/Mod.gd")


func Death(direction, force):
	var was_dead: bool = dead
	super(direction, force)
	if was_dead or not BEL.active() or container == null:
		return
	var extra := BEL.extra_loot(variant, weaponData)
	for sd in extra:
		container.loot.append(sd)
	if not extra.is_empty():
		BEL.say("%s body: %d extra item(s)." % [BEL.faction_of(variant), extra.size()])
