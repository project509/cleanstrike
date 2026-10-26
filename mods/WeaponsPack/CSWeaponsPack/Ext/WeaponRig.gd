# CleanStrike Weapons Pack: after each shot of one of the pack's guns, its
# own touches (muzzle flash size, effects).
extends "res://Scripts/WeaponRig.gd"

const WPR = preload("res://CSWeaponsPack/Mod.gd")


func FireEvent():
	var before = fireTimer
	super()
	if fireTimer == 0.0 and before > 0.0:
		WPR.on_fire(self)
