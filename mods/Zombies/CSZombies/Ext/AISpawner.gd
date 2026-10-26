# Road to Hell: every enemy pool is filled with the dead (bosses too), many
# more of them than the game's soldiers, no nomads. Some are already about
# when you arrive; the dead are replaced; and the longer you stay noticed, the
# more come, the faster and the closer, until you hide out of sight.
extends "res://Scripts/AISpawner.gd"

const ZS = preload("res://CSZombies/Mod.gd")

var zs_base_limit := 0
var zs_base_distance := 100.0


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
	zs_base_limit = activeEnemyLimit
	zs_base_distance = spawnDistance
	ZS.spawners.append(self)
	for i in int(activeEnemyLimit * float(ZS.setting("start_share"))):
		if activeEnemies < activeEnemyLimit and EPool.get_child_count() > 0:
			SpawnEnemy()


func _physics_process(delta):
	if ZS.active() and zs_base_limit > 0:
		ZS.cool(delta)
		var h: float = ZS.heat
		activeEnemyLimit = int(round(zs_base_limit * (1.0 + h)))       # up to twice as many at once
		spawnDistance = lerpf(zs_base_distance, 40.0, h)                 # and closer
		if h > 0.5:
			enemyTimer = minf(enemyTimer, lerpf(10.0, 2.0, h))          # and faster
	super(delta)


# A fresh zombie for the pool (a killed one, replaced).
func ZS_Replenish() -> void:
	if not is_inside_tree() or not active:
		return
	var z = ZS.scene().instantiate()
	EPool.add_child(z, true)
	z.AISpawner = self
	z.navmesh = get_world_3d().get_navigation_map()
	z.global_position = EPool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	z.Initialize()
	z.Deactivate()
