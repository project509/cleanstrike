# CleanStrike Zombies: every enemy pool is filled with the dead (bosses too),
# more of them than the game's soldiers, no nomads. They keep coming quickly,
# and some are already about when you arrive.
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
	spawnFrequency = SpawnFrequency.High
	await super()
	for i in int(activeEnemyLimit * float(ZS.setting("start_share"))):
		if activeEnemies < activeEnemyLimit and EPool.get_child_count() > 0:
			SpawnEnemy()
