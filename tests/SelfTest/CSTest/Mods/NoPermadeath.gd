# Self-test for No Permadeath (cs_no_permadeath). r is the CSTest runner.
# test.sh snapshots the player's saves first, so even a failed run that hits
# the game's save wipe is undone afterwards; the canary file detects it.
extends RefCounted

const M = preload("res://CSNoPermadeath/Mod.gd")
const CANARY := "user://cs_np_canary.tres"
const SCRATCH := "user://cs_np_scratch.tres"


func run(r) -> void:
	var gd = load("res://Resources/GameData.tres")
	r.check("NoPermadeath: active", M.active())
	r.check("NoPermadeath: spares zones and Hardcore by default", M.spares(1) and M.spares(3))
	M.overrides["zones"] = false
	r.check("NoPermadeath: zone setting respected", not M.spares(1) and M.spares(3))
	M.overrides.clear()

	# HUD: no skull icon, no red "Permadeath Zone" hint
	var hud = r.get_node("/root/Map/Core/UI/HUD")
	gd.permadeath = true
	await r.wait(0.4)
	r.check("NoPermadeath: HUD hides the permadeath icon", not hud.permadeath.visible)
	gd.permadeath = false
	var tr = load("res://Resources/Transition.tscn").instantiate()
	tr.nextMap = "Apartments"; tr.nextZone = "Vostok"
	hud.Transition(tr)
	r.check("NoPermadeath: travel hint says permadeath is off", hud.detailsHint.text == "Permadeath off", hud.detailsHint.text)
	tr.free()

	# Keeping gear: worn only vs everything, written over a reset character
	var kept := CharacterSave.new()
	for f in ["res://Items/Weapons/AKM/AKM_Magazine.tres", "res://Items/Weapons/AKM/AKM.tres"]:
		var sd := SlotData.new()
		sd.itemData = load(f)
		kept.inventory.append(sd)
	var worn := SlotData.new()
	worn.itemData = load("res://Items/Weapons/AKM/AKM.tres")
	kept.equipment.append(worn)
	for mode in [M.KEEP_WORN, M.KEEP_ALL]:
		ResourceSaver.save(CharacterSave.new(), SCRATCH)
		M.restore_gear(kept, mode, SCRATCH)
		var back := ResourceLoader.load(SCRATCH, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterSave
		var want_inv := 2 if mode == M.KEEP_ALL else 0
		r.check("NoPermadeath: %s" % mode, back.equipment.size() == 1 and back.inventory.size() == want_inv and back.health == 100.0,
			"%d equipped, %d carried" % [back.equipment.size(), back.inventory.size()])
	DirAccess.remove_absolute(SCRATCH)

	# Quit outside a shelter: keep-gear switch
	var settings = r.get_node("/root/Map/Core/UI/Settings")
	gd.tutorial = false
	r.check("NoPermadeath: quitting loses gear by default", not settings.NP_KeepsGearOnQuit())
	M.overrides["keep_on_quit"] = true
	r.check("NoPermadeath: keep-gear-on-quit switch", settings.NP_KeepsGearOnQuit())
	M.overrides.clear()
	gd.tutorial = true


# Real deaths and exits, then back to the Tutorial.
func run_last(r) -> void:
	var gd = load("res://Resources/GameData.tres")
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	ResourceSaver.save(Resource.new(), CANARY)

	# 1) Quit to the menu outside a shelter, keeping gear
	_carry(interface, "res://Items/Weapons/AKM/AKM_Magazine.tres")
	M.overrides["keep_on_quit"] = true
	gd.tutorial = false
	gd.shelter = false
	r.get_node("/root/Map/Core/UI/Settings")._on_menu_pressed()
	await _wait_scene(r, "Menu", 30.0)
	r.check("NoPermadeath: quit kept the carried item", _saved_has("AKM_Magazine"))
	M.overrides.clear()
	if not await r.reload_tutorial():
		r.check("NoPermadeath: back to Tutorial after quit", false)
		return

	# 2) Die in a permadeath zone, keeping everything
	interface = r.get_node("/root/Map/Core/UI/Interface")
	_carry(interface, "res://Items/Weapons/AKM/AKM_Magazine.tres")
	M.overrides["on_death"] = M.KEEP_ALL
	gd.tutorial = false
	gd.shelter = false
	gd.permadeath = true
	r.get_node("/root/Map/Core/Controller/Character").Death()
	var died: bool = await _wait_scene(r, "Death", 30.0)
	r.check("NoPermadeath: zone death goes to the death screen", died)
	if died:
		var hint: String = r.get_tree().current_scene.get_node("Main/Hint").text
		r.check("NoPermadeath: death screen says Character died", hint == "Character died", hint)
	r.check("NoPermadeath: saves not deleted", FileAccess.file_exists(CANARY))
	r.check("NoPermadeath: kept the carried item", _saved_has("AKM_Magazine"))
	M.overrides.clear()
	DirAccess.remove_absolute(CANARY)
	r.check("NoPermadeath: back to Tutorial", await r.reload_tutorial())


func _carry(interface, path: String) -> void:
	var sd := SlotData.new()
	sd.itemData = load(path)
	interface.Create(sd, interface.inventoryGrid, false)


func _saved_has(file: String) -> bool:
	var c := ResourceLoader.load(M.CHARACTER, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterSave
	if c == null:
		return false
	for sd in c.inventory:
		if sd.itemData and sd.itemData.file == file:
			return true
	return false


func _wait_scene(r, scene_name: String, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		var cur = r.get_tree().current_scene
		if cur and cur.name == scene_name:
			await r.wait(1.0)
			return true
		await r.wait(0.25)
		t += 0.25
	return false
