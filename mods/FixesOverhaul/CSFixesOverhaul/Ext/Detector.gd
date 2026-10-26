# Fixes Overhaul: standing in several areas at once (indoors by a fire, at a
# heated workbench...) applies all of them; the game kept only the last one
# it checked, so e.g. a fire indoors didn't warm you.
extends "res://Scripts/Detector.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func Detect():
	if not FO.on("overlapping_areas"):
		super()
		return
	var types := []
	for overlap in get_overlapping_areas():
		if overlap is Area:
			types.append(overlap.type)
			if overlap.type == "Mine" and not overlap.owner.isDetonated:
				overlap.owner.Detonate()
	var f := FO.area_flags(types)
	gameData.indoor = f.indoor
	gameData.isBurning = f.isBurning
	if f.isBurning and not gameData.burn:
		character.Burn(true)
	gameData.isPoisoning = f.isPoisoning
	if f.isPoisoning and not gameData.poisoning:
		character.Poisoning(true)
	gameData.isRazor = f.isRazor
	if f.isRazor and not gameData.bleeding:
		character.Bleeding(true)
	gameData.heat = f.heat
	gameData.PRX_Heat = f.PRX_Heat
	gameData.PRX_Workbench = f.PRX_Workbench
