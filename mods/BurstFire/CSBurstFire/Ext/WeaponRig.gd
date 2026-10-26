# Burst Fire: a third fire mode for automatic weapons. One pull fires a short
# burst at the gun's own rate of fire.
extends "res://Scripts/WeaponRig.gd"

const BF = preload("res://CSBurstFire/Mod.gd")

var bf_left := 0


func Firemode():
	if not BF.active() or data.weaponAction != "Semi-Auto" or not Input.is_action_just_pressed("firemode"):
		super()
		return
	BF.next_mode(slotData)
	gameData.firemode = int(slotData.mode)
	PlayFiremode()
	if BF.is_burst(slotData):
		Loader.Message("Burst (%d)" % int(BF.setting("burst_size")), Color(0.9, 0.85, 0.7))


func FireInput():
	if not BF.is_burst(slotData):
		bf_left = 0
		super()
		return
	if not gameData.weaponPosition == 2 and not gameData.isAiming and not gameData.isCanted:
		bf_left = 0
		return
	if not slotData.chamber or slotData.state == "Jammed":
		bf_left = 0
		return
	if Input.is_action_just_pressed("fire") and bf_left == 0:
		bf_left = maxi(1, int(BF.setting("burst_size")))
	if bf_left > 0:
		fireRate = data.fireRate
		fireImpulse = data.fireRate
		FireEvent()
		if fireTimer == 0.0:   # a round went off
			bf_left -= 1
