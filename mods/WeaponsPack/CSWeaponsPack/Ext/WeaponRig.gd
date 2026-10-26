# CleanStrike Weapons Pack: the pack's guns on the game's weapon rig. After
# each shot: its own touches (muzzle flash size, view kick); a bolt action
# (Welrod) leaves the chamber empty until the bolt is cycled with Reload;
# silent guns stay silent; head damage of its own while the shot resolves.
extends "res://Scripts/WeaponRig.gd"

const WPR = preload("res://CSWeaponsPack/Mod.gd")
const WPE = preload("res://CSWeaponsPack/Energy.gd")


func FireEvent():
	if slotData == null:
		super()
		return
	var rounds = slotData.amount
	var chambered = slotData.chamber
	if data and data.has_meta("cs_head_damage"):
		Engine.set_meta("cs_head_damage", data.get_meta("cs_head_damage"))
	super()
	if Engine.has_meta("cs_head_damage"):
		Engine.remove_meta("cs_head_damage")
	# a shot went off: the chambered round is spent (fed from the magazine, or the last one)
	if slotData.amount < rounds or (chambered and not slotData.chamber):
		if data.has_meta("cs_bolt"):
			slotData.amount = rounds          # the next round stays in the magazine
			slotData.chamber = false
			slideLocked = false
			UpdateBullets()
		WPR.on_fire(self)


# Bolt action: Reload cycles the bolt while the magazine still has rounds
# (the rig's own charging motion); an empty magazine is swapped as usual.
func Reload():
	if data and data.has_meta("cs_bolt") and Input.is_action_just_pressed("reload") and magazine and magazine.visible 			and slotData and not slotData.chamber and slotData.amount > 0 			and not gameData.isReloading and not gameData.isInspecting and not gameData.isOccupied:
		gameData.isReloading = true
		PlayReload()
		animator["parameters/conditions/Charge"] = true
		await get_tree().create_timer(0.1, false).timeout
		animator["parameters/conditions/Charge"] = false
		slotData.chamber = true
		slotData.amount -= 1
		UpdateBullets()
		return
	super()


# Energy guns (Ray Gun): the shot is a bolt that hits when it arrives.
func Raycast(spread: float):
	if data and data.has_meta("cs_energy"):
		WPE.shot(self)
		return
	super(spread)


# A silent gun's shots never count as firing: nothing hears or notices them.
func FireImpulse(delta):
	if data and data.has_meta("cs_silent"):
		fireImpulse = 0.0
		fireImpulseTimer = 0.0
		gameData.isFiring = false
		return
	super(delta)
