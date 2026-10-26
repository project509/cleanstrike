# CleanStrike Zombies: every enemy pool is filled with the dead (bosses too),
# more of them than the game's soldiers, and no nomads.
extends "res://Scripts/AISpawner.gd"

const ZS = preload("res://CSZombies/Mod.gd")


func CreatePools():
	if not ZS.active():
		return await super()
	var horde := maxf(1.0, float(ZS.setting("horde")))
	enemy = ZS.scene()
	punisher = ZS.scene()
	bogeyman = ZS.scene()
	NPoolSize = 0
	activeNomadLimit = 0
	EPoolSize = int(round(EPoolSize * horde))
	activeEnemyLimit = int(round(activeEnemyLimit * horde))
	await super()
