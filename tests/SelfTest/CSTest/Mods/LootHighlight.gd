# Self-test for Loot Highlight (cs_loot_highlight). r is the CSTest runner.
extends RefCounted

const LH = preload("res://CSLootHighlight/Mod.gd")


func run(r) -> void:
	r.check("LootHighlight: active", LH.active())
	var player = r.get_node("/root/Map/Core/Controller")
	var pickup = load("res://Items/Weapons/AKM/AKM_Magazine.tscn").instantiate()
	r.get_tree().current_scene.add_child(pickup)
	pickup.global_position = player.global_position + Vector3(2, 0.5, 0)
	await r.wait(0.2)
	r.check("LootHighlight: world loot is tracked", pickup in LH.pickups)
	LH.overrides = {"mode": "always"}
	await r.wait(0.2)
	r.check("LootHighlight: nearby loot glows", pickup.mesh and pickup.mesh.material_overlay != null)
	var rarity: int = pickup.slotData.itemData.rarity
	r.check("LootHighlight: coloured by rarity", pickup.mesh and pickup.mesh.material_overlay.albedo_color.r == LH.COLORS[rarity].r)
	LH.overrides = {"mode": "always", "in_shelters": false}
	LH.tick(0.0, player.global_position, true)
	r.check("LootHighlight: off in shelters", pickup.mesh.material_overlay == null)
	LH.overrides = {"mode": "press", "range": 1.0}
	LH.until = Time.get_ticks_msec() / 1000.0 + 5.0
	await r.wait(0.2)
	r.check("LootHighlight: out of range stays dark", pickup.mesh.material_overlay == null)
	LH.overrides = {"mode": "press"}
	await r.wait(0.2)
	r.check("LootHighlight: glows after a press", pickup.mesh.material_overlay != null)
	LH.until = 0.0
	await r.wait(0.2)
	r.check("LootHighlight: glow ends", pickup.mesh.material_overlay == null)
	LH.overrides = {}
	pickup.queue_free()
