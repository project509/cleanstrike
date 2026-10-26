# CleanStrike Zombies: one of the dead. Slow, tough and hits hard; hunts by
# sound first, sight second; calls the others; loses interest after three
# minutes without seeing you; breaks doors; loses limbs; crawls when its legs
# are gone. Speaks the spawner's language (Initialize/Activate/Deactivate,
# sensor, currentPoint...) so it can stand in for the game's enemies.
extends Node3D

const ZM = preload("res://CSZombies/Mod.gd")

enum S { IDLE, WANDER, INVESTIGATE, CHASE, ATTACK, DOOR, DEAD }

var gameData = preload("res://Resources/GameData.tres")

# What the spawner and other game code expect of an enemy
var AISpawner
var navmesh
var currentPoint
var lastKnownLocation := Vector3.ZERO
var attackReturn := false
var active := false
var dead := false
var force := false          # sensor.force
var sensor = self
var activeVoice = null
var variant = null

# Body
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var agent: NavigationAgent3D
var hitboxes: Array = []

# Mind
var state := S.IDLE
var health := 250.0
var parts := {}             # part -> damage taken
var lost := {}              # part -> true once severed
var crawler := false
var runner := false
var target := Vector3.ZERO
var last_seen := -1000.0
var last_heard := -1000.0
var last_alert := -1000.0
var attack_ready := 0.0
var door: Node = null
var door_hits := 0
var door_timer := 0.0
var think := 0.0
var current_anim := ""
var path_next := Vector3.ZERO


func _ready() -> void:
	model = get_node("Model")
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	anim = model.get_node("AnimationPlayer")
	agent = get_node("Agent")
	for hb in find_children("*", "StaticBody3D", true, false):
		if hb.has_method("ApplyDamage"):
			hitboxes.append(hb)
	runner = randf() < float(ZM.setting("runners"))
	health = 250.0 * float(ZM.setting("health"))
	think = randf() * 0.3
	ZM.register(self)


# ---------------------------------------------------------------- spawner API

func Initialize() -> void:
	if navmesh:
		agent.set_navigation_map(navmesh)


func Deactivate() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func Activate(_state = "Wander") -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_set_state(S.WANDER)


func ChangeState(_s) -> void:      # the spawner's "go and check this out"
	if not dead:
		Hear(lastKnownLocation if lastKnownLocation != Vector3.ZERO else gameData.playerPosition, false)


func Threat(_id) -> void:          # sensor.Threat: someone shot at the group
	if not dead:
		Hear(gameData.playerPosition, true)


# ---------------------------------------------------------------- senses

# A sound worth walking to. Loud ones bring the pack.
func Hear(at: Vector3, loud: bool) -> void:
	if dead:
		return
	target = at
	last_heard = _now()
	if state in [S.IDLE, S.WANDER, S.INVESTIGATE]:
		_set_state(S.INVESTIGATE)
	if loud and _now() - last_alert > 8.0:
		last_alert = _now()
		ZM.alert_near(self, at)


func Sees() -> bool:
	var me := global_position + Vector3.UP * (0.5 if crawler else 1.5)
	var you: Vector3 = gameData.playerPosition + Vector3.UP * 1.2
	var d := me.distance_to(you)
	if d > float(ZM.setting("sight")):
		return false
	var fwd := -global_basis.z
	if d > 3.0 and rad_to_deg(fwd.angle_to((you - me) * Vector3(1, 0, 1))) > 70.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(me, you, 1)
	q.exclude = hitboxes.map(func(h): return h.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _listen() -> void:
	var d: float = global_position.distance_to(gameData.playerPosition)
	var h := float(ZM.setting("hearing"))
	if (gameData.isFiring or _now() - ZM.last_shot < 1.0) and ZM.last_shot_at.distance_to(global_position) < 140.0 * h:
		Hear(ZM.last_shot_at if ZM.last_shot_at != Vector3.ZERO else gameData.playerPosition, true)
	elif gameData.isRunning and d < 30.0 * h:
		Hear(gameData.playerPosition, false)
	elif gameData.isWalking and not gameData.isCrouching and d < 10.0 * h:
		Hear(gameData.playerPosition, false)
	elif d < 2.5:
		Hear(gameData.playerPosition, false)


# ---------------------------------------------------------------- brain

func _physics_process(delta: float) -> void:
	if not active or dead or gameData.isCaching:
		return
	think -= delta
	if think <= 0.0:
		think = 0.25
		_decide()
	match state:
		S.WANDER, S.INVESTIGATE, S.CHASE:
			_move(delta)
		S.ATTACK:
			_attack(delta)
		S.DOOR:
			_bash(delta)
		S.IDLE:
			_play("idle" if not crawler else "crawl", 0.0)


func _decide() -> void:
	_listen()
	var now := _now()
	var d: float = global_position.distance_to(gameData.playerPosition)
	if not gameData.isDead and Sees():
		if last_seen < now - 5.0:
			ZM.alert_near(self, gameData.playerPosition)       # it moans; the others come
		last_seen = now
		target = gameData.playerPosition
		if state != S.ATTACK and state != S.DOOR:
			_set_state(S.CHASE)
	if state == S.CHASE or state == S.INVESTIGATE:
		if d < (1.3 if crawler else 1.6) and now - last_seen < 1.0 and not gameData.isDead:
			_set_state(S.ATTACK)
		elif state == S.CHASE and now - last_seen > float(ZM.setting("forget_seconds")) and now - last_heard > 20.0:
			_set_state(S.WANDER)                              # lost you
		elif state == S.INVESTIGATE and global_position.distance_to(target) < 2.0 and now - last_seen > 3.0:
			_set_state(S.WANDER)
		else:
			_check_door()
	if state == S.WANDER and global_position.distance_to(target) < 2.0:
		_pick_wander()


func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	match s:
		S.WANDER:
			_pick_wander()
		S.ATTACK:
			attack_ready = 0.0
	if s in [S.WANDER, S.INVESTIGATE, S.CHASE]:
		agent.target_position = target


func _pick_wander() -> void:
	var pts: Array = AISpawner.waypoints if AISpawner and "waypoints" in AISpawner and not AISpawner.waypoints.is_empty() else []
	if not pts.is_empty() and randf() < 0.6:
		target = pts.pick_random().global_position
	else:
		target = global_position + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
	agent.target_position = target


func _speed() -> float:
	if crawler:
		return 0.45
	if state == S.WANDER:
		return 0.6
	return 2.4 if runner else 1.05


func _move(delta: float) -> void:
	if state != S.WANDER:
		agent.target_position = target
	var next: Vector3 = agent.get_next_path_position() if not agent.is_navigation_finished() else target
	if next.distance_to(global_position) < 0.05 or agent.get_current_navigation_path().is_empty():
		next = target                                       # no navmesh here: head straight for it
	var dir := (next - global_position) * Vector3(1, 0, 1)
	if dir.length() < 0.3:
		_play(_idle_anim(), 0.0)
		return
	dir = dir.normalized()
	var spd := _speed()
	global_position += dir * spd * delta
	_ground()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 4.0)
	_play(_move_anim(), spd)


func _ground() -> void:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.DOWN * 2.0, 1)
	q.exclude = hitboxes.map(func(h): return h.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		global_position.y = lerpf(global_position.y, hit.position.y, 0.5)


func _face(at: Vector3, delta: float) -> void:
	var dir := (at - global_position) * Vector3(1, 0, 1)
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 6.0)


func _attack(delta: float) -> void:
	_face(gameData.playerPosition, delta)
	attack_ready -= delta
	var reach := 1.4 if crawler else 1.9
	if global_position.distance_to(gameData.playerPosition) > reach + 0.4 or gameData.isDead:
		_set_state(S.CHASE)
		return
	if attack_ready <= 0.0:
		attack_ready = 1.8
		var a: String = "bite_2" if crawler else ["attack", "punch", "headbutt", "bite_2"].pick_random()
		_play(a, 0.0, true)
		get_tree().create_timer(0.55, false).timeout.connect(_land_blow.bind(reach))


func _land_blow(reach: float) -> void:
	if dead or state != S.ATTACK or gameData.isDead:
		return
	if global_position.distance_to(gameData.playerPosition) <= reach + 0.2:
		ZM.hurt_player(get_tree(), float(ZM.setting("damage")) * (0.6 if crawler else 1.0))


# ---------------------------------------------------------------- doors

func _check_door() -> void:
	var from := global_position + Vector3.UP * 1.0
	var to := from - global_basis.z * 1.1
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = hitboxes.map(func(h): return h.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var d = ZM.door_of(hit.collider)
	if d and not d.isOpen:
		door = d
		door_timer = 0.8
		_set_state(S.DOOR)


func _bash(delta: float) -> void:
	if door == null or not is_instance_valid(door) or door.isOpen:
		door = null
		_set_state(S.CHASE if _now() - last_seen < 10.0 else S.INVESTIGATE)
		return
	_face(door.global_position, delta)
	door_timer -= delta
	if door_timer <= 0.0:
		door_timer = 1.3
		_play(["punch", "attack", "kick"].pick_random(), 0.0, true)
		if ZM.hit_door(door):
			door = null
			_set_state(S.CHASE if _now() - last_seen < 10.0 else S.INVESTIGATE)


# ---------------------------------------------------------------- damage

func Hit(part: String, damage: float, vector: Vector3, id: Node3D, at: Vector3) -> void:
	if dead:
		return
	var mult: float = {"head": 3.0, "torso": 1.0}.get(part, 0.6)
	health -= damage * mult
	parts[part] = float(parts.get(part, 0.0)) + damage
	ZM.gore_hit(self, at, vector)
	if id and id.is_in_group("Player"):
		Hear(gameData.playerPosition, true)
		last_seen = _now()
		target = gameData.playerPosition
		if state in [S.IDLE, S.WANDER, S.INVESTIGATE]:
			_set_state(S.CHASE)
	if part != "torso" and part != "head" and not lost.has(part) and parts[part] >= ZM.limb_health(part):
		Sever(part, vector)
	if health <= 0.0 or (part == "head" and parts[part] >= ZM.limb_health("head")):
		if part == "head" and parts[part] >= ZM.limb_health("head"):
			Sever("head", vector)
		Death(vector)
	elif randf() < 0.25 and state != S.ATTACK:
		_play("hit" if not crawler else "crawl", 0.0, true)


# This WeaponDamage is what explosions and other AI use.
func WeaponDamage(hitbox: String, damage: float, vector: Vector3, id: Node3D) -> void:
	Hit("torso", damage, vector, id, global_position + Vector3.UP)


func ExplosionDamage(direction, id: Node3D) -> void:
	for p in ["leg_l_lower", "leg_r_lower", "arm_l_lower", "arm_r_lower"]:
		if randf() < 0.5:
			Sever(p, direction if direction is Vector3 else Vector3.UP)
	Hit("torso", 400.0, direction if direction is Vector3 else Vector3.UP, id, global_position + Vector3.UP)


func Sever(part: String, vector: Vector3) -> void:
	if lost.has(part):
		return
	lost[part] = true
	ZM.sever(self, part, vector)
	if part.begins_with("leg") and not crawler:
		crawler = true
		_play("transition", 0.0, true)                    # falls to the ground
		health = maxf(health, 60.0)


func Death(vector: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	active = false
	state = S.DEAD
	for hb in hitboxes:
		hb.collision_layer = 0
	_play("dying" if crawler else ["death", "dying"].pick_random(), 0.0, true)
	ZM.died(self, vector)
	if AISpawner and "activeEnemies" in AISpawner:
		AISpawner.activeEnemies -= 1


# ---------------------------------------------------------------- animation

func _idle_anim() -> String:
	return "crawl" if crawler else ["idle", "idle_2", "idle_3", "idle_scratch"][get_instance_id() % 4]


func _move_anim() -> String:
	if crawler:
		return "crawl_run" if state == S.CHASE else "crawl"
	if state == S.WANDER:
		return ["walk", "walk_3", "stumble"][get_instance_id() % 3]
	return ("run" if get_instance_id() % 2 == 0 else "run_2") if runner else ["walk", "walk_2", "walk_3"][get_instance_id() % 3]


# Crossfade into a clip; moving clips are sped to the feet; one-shots finish
# before anything else plays.
func _play(clip: String, move_speed: float, once := false) -> void:
	if anim.is_playing() and current_anim != clip and _busy():
		return
	if current_anim != clip:
		anim.play(clip, 0.3)
		current_anim = clip
	if move_speed > 0.0:
		anim.speed_scale = clampf(move_speed / ZM.CLIP_SPEED.get(clip, 1.0), 0.5, 1.6)
	else:
		anim.speed_scale = 1.0
	if once:
		anim.set_meta("cs_once_until", _now() + anim.current_animation_length * 0.85)


func _busy() -> bool:
	return anim.has_meta("cs_once_until") and _now() < float(anim.get_meta("cs_once_until"))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
