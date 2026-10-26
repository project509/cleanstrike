# Faction Warfare: rival squads mix into each zone, and optionally more
# enemies are about at once.
extends "res://Scripts/AISpawner.gd"

const FW = preload("res://CSFactionWarfare/Mod.gd")


func CreatePools():
	if not FW.active() or enemy == null:
		return await super()
	var density := maxf(1.0, float(FW.setting("density")))
	activeEnemyLimit = int(round(activeEnemyLimit * density))
	EPoolSize = int(round(EPoolSize * density))
	await super()
	await FW_AddRivals()


func FW_AddRivals() -> void:
	var probe = enemy.instantiate()
	var mine: int = probe.variants[0].faction if "variants" in probe and not probe.variants.is_empty() else -1
	probe.free()
	var rivals: Array = FW.RIVAL_SCENES.get(mine, [])
	if rivals.is_empty():
		return
	var count := int(round(EPool.get_child_count() * float(FW.setting("rivals")) / 100.0))
	for i in count:
		var r = load(rivals.pick_random()).instantiate()
		EPool.add_child(r, true)
		r.AISpawner = self
		r.navmesh = get_world_3d().get_navigation_map()
		r.global_position = EPool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		r.Initialize()
		r.Deactivate()
		await get_tree().process_frame
	# Spawns take the first in the pool: mix them
	var kids := EPool.get_children()
	kids.shuffle()
	for i in kids.size():
		EPool.move_child(kids[i], i)
