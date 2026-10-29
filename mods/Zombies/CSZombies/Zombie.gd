# CleanStrike Zombies: one of the dead. Tough and hits hard; hunts by sound
# first, sight second; calls the others; stays on your trail while it has
# seen you in the last ten seconds and loses you after that; breaks doors;
# loses limbs; crawls when its legs are gone. Speaks the spawner's language
# (Initialize/Activate/Deactivate, sensor, currentPoint...) so it can stand in
# for the game's enemies, and moves the way they do: along the navigation mesh
# in 3D, so it goes wherever they go (stairs, ramps, upper floors) and never
# through a wall.
extends Node3D

const ZM = preload("res://CSZombies/Mod.gd")

enum S { IDLE, WANDER, INVESTIGATE, CHASE, ATTACK, DOOR, DEAD }

# The game's own collision masks: what is walked on (terrain and the walking
# hulls of floors, stairs and ramps), what blocks sight (terrain, doors,
# detailed hulls, water; foliage hides nobody from the dead) and what the
# forward probe finds doors with (the game's enemies' Forward ray).
const GROUND_MASK := 33
const SIGHT_MASK := 268435481
const PROBE_MASK := 57
const HEIGHT_OFFSET := 0.2      # as the game's agents: the path runs this far above the root
const ATTACK_RATE := 1.2        # swings play a little quicker than the clips
const MIN_RATE := 0.35          # moving clips play at least this fast
const MAX_RATE := 2.0           # ...and at most this fast
const CRAWL_KEEP := 0.49 / 0.43  # the crawl clip re-measured slower: slow crawlers keep their old pace, less the quarter

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
var body: StaticBody3D
var hitboxes: Array = []

# Mind
var state := S.IDLE
var health := 125.0
var parts := {}             # part -> damage taken
var lost := {}              # part -> true once severed
var crawler := false
var enraged_until := -1000.0   # shot at: now and then one charges you
var target := Vector3.ZERO
var last_seen := -1000.0
var last_heard := -1000.0
var heard_loud := -1000.0
var last_alert := -1000.0
var attack_ready := 0.0
var door: Node = null
var door_at := Vector3.ZERO
var door_timer := 0.0
var think := 0.0
var current_anim := ""
var voice: AudioStreamPlayer3D
var path_to := Vector3.INF      # where the current path leads
var path_age := 0.0
var moan_in := 0.0
var screamed := -1000.0
var stagger_ready := 0.0
var move_dir := Vector3.ZERO
var flank := 0.0                # the side it comes at you from, so a pack spreads
var pace := 1.0                 # a little faster or slower than the rest
var stuck_at := Vector3.ZERO
var stuck_t := 0.0
var stuck_n := 0
var tick := 0
var clock := 0.0                # its own time: stands still while the game is paused
var played_at := 0.0


func _ready() -> void:
	model = get_node("Model")
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	anim = model.get_node("AnimationPlayer")
	agent = get_node("Agent")
	body = get_node("Collision")
	for hb in find_children("*", "StaticBody3D", true, false):
		if hb.has_method("ApplyDamage"):
			hitboxes.append(hb)
	health = 125.0 * float(ZM.setting("health"))
	think = randf() * 0.3
	flank = float(get_instance_id() % 16) / 16.0 * TAU
	pace = 0.92 + float(get_instance_id() % 7) * 0.027
	voice = AudioStreamPlayer3D.new()
	voice.bus = &"SFX"
	voice.unit_size = 6.0
	voice.max_distance = 45.0
	voice.position = Vector3(0, 1.5, 0)
	voice.finished.connect(func(): ZM.speaking = maxi(0, ZM.speaking - 1))
	add_child(voice)
	moan_in = randf_range(1.0, 8.0)
	ZM.register(self)


# ---------------------------------------------------------------- spawner API

func Initialize() -> void:
	if navmesh:
		agent.set_navigation_map(navmesh)


func Deactivate() -> void:
	active = false
	visible = false
	force = false
	process_mode = Node.PROCESS_MODE_DISABLED


func Activate(_state = "Wander") -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	# Fresh from the pool: nothing left over from last time
	if anim.has_meta("cs_once_until"):
		anim.remove_meta("cs_once_until")
	current_anim = ""
	model.position.y = 0.0
	_play(_idle_anim(), 0.0)
	_snap()
	state = S.IDLE
	if str(_state) == "Attack" or force:           # sent at you (minions, bosses)
		last_seen = _now()
		target = gameData.playerPosition
		_set_state(S.CHASE)
	else:
		_set_state(S.WANDER)
		if ZM.heat > 0.35 and randf() < ZM.heat:      # the swarm closes in on you
			Hear(gameData.playerPosition, false)


func ChangeState(_s) -> void:      # the spawner's "go and check this out"
	if not dead:
		Hear(lastKnownLocation if lastKnownLocation != Vector3.ZERO else gameData.playerPosition, false)


func Threat(_id) -> void:          # sensor.Threat: someone shot at the group
	if not dead:
		Hear(gameData.playerPosition, true)


# ---------------------------------------------------------------- senses

# A sound worth walking to. Loud ones bring the pack, running.
func Hear(at: Vector3, loud: bool) -> void:
	if dead:
		return
	target = at
	last_heard = _now()
	if loud:
		heard_loud = _now()
	if state in [S.IDLE, S.WANDER, S.INVESTIGATE]:
		_set_state(S.INVESTIGATE)
	if loud and _now() - last_alert > 8.0:
		last_alert = _now()
		ZM.alert_near(self, at)


func Sees() -> bool:
	var me := model.global_position + Vector3.UP * (0.5 if crawler else 1.6)
	var you: Vector3 = gameData.playerPosition + Vector3.UP * 1.2
	var d := me.distance_to(you)
	if d > float(ZM.setting("sight")):
		return false
	var fwd := -global_basis.z
	# a hunter keeps you in view all round; only a broken line of sight loses you
	if d > 3.0 and not _aggro() and rad_to_deg(fwd.angle_to((you - me) * Vector3(1, 0, 1))) > 70.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(me, you, SIGHT_MASK)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _listen() -> void:
	var d: float = global_position.distance_to(gameData.playerPosition)
	var h := float(ZM.setting("hearing"))
	if gameData.isRunning and d < 40.0 * h:
		Hear(gameData.playerPosition, false)
	elif gameData.isWalking and d < (6.0 if gameData.isCrouching else 15.0) * h:
		Hear(gameData.playerPosition, false)
	elif d < 3.0:
		Hear(gameData.playerPosition, false)


# ---------------------------------------------------------------- brain

func _physics_process(delta: float) -> void:
	clock += delta
	if not active or dead or gameData.isCaching:
		return
	tick += 1
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
			_play(_idle_anim(), 0.0)


func _decide() -> void:
	_listen()
	moan_in -= 0.25
	if moan_in <= 0.0:
		moan_in = randf_range(3.0, 7.0) if state in [S.CHASE, S.INVESTIGATE] else randf_range(6.0, 14.0)
		Say("moan")
	var now := _now()
	var you: Vector3 = gameData.playerPosition
	var d: float = global_position.distance_to(you)
	if not gameData.isDead and Sees():
		if last_seen < now - 5.0:
			ZM.alert_near(self, you)       # it screams; the others come
			if now - screamed > 20.0:
				screamed = now
				Say("scream", true)
				if not crawler and d > 8.0 and randf() < 0.5:
					_play("scream", 0.0, true, 1.2)     # stops to scream, then comes
		last_seen = now
		ZM.notice(0.004)
		target = you
		if state != S.ATTACK and state != S.DOOR:
			_set_state(S.CHASE)
	elif state == S.CHASE and now - last_seen < _aggro_time() and not gameData.isDead:
		target = you                       # on your trail: round the corner, up the stairs
	if state == S.CHASE or state == S.INVESTIGATE:
		var flat_d := ((you - global_position) * Vector3(1, 0, 1)).length()
		if flat_d < (1.3 if crawler else 1.7) and d < (1.7 if crawler else 2.2) and now - last_seen < 1.5 and not gameData.isDead:
			_set_state(S.ATTACK)
		elif state == S.CHASE and (now - last_seen >= _aggro_time() or gameData.isDead):
			_set_state(S.WANDER)                              # out of sight too long: lost you
		elif state == S.INVESTIGATE and _arrived() and now - last_seen > 3.0:
			_set_state(S.WANDER)
	elif state == S.DOOR and (gameData.isDead or (now - maxf(last_seen, last_heard) >= _aggro_time() and now - heard_loud >= 20.0)):
		door = null                                           # nothing seen or heard behind it for a while: gives up
		_set_state(S.WANDER)
	if state == S.WANDER and _arrived():
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
		path_to = Vector3.INF          # repath on the next move


func _aggro() -> bool:
	return state in [S.CHASE, S.ATTACK, S.DOOR] and _now() - last_seen < _aggro_time()


# How long it keeps after you with the line of sight broken; every glimpse
# starts it again.
func _aggro_time() -> float:
	return float(ZM.setting("aggro_seconds"))


# There, or as near as the navigation mesh lets it get.
func _arrived() -> bool:
	if global_position.distance_to(target) < 2.0:
		return true
	if path_to == Vector3.INF or not agent.is_navigation_finished():
		return false
	var p := agent.get_current_navigation_path()
	return not p.is_empty() and global_position.distance_to(p[p.size() - 1] - Vector3.UP * HEIGHT_OFFSET) < 1.5


func _pick_wander() -> void:
	var pts: Array = AISpawner.waypoints if AISpawner and "waypoints" in AISpawner and not AISpawner.waypoints.is_empty() else []
	for i in 4:
		if not pts.is_empty() and randf() < 0.6:
			target = pts.pick_random().global_position
			break
		target = global_position + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		var on := _on_mesh(target)
		if ((on - target) * Vector3(1, 0, 1)).length() < 1.5:         # not inside a house or a rock
			target = on
			break
	path_to = Vector3.INF          # repath on the next move


# ---------------------------------------------------------------- moving

func _map() -> RID:
	return agent.get_navigation_map()


func _nav_ready() -> bool:
	return _map().is_valid() and NavigationServer3D.map_get_iteration_id(_map()) > 0


# The nearest point on the navigation mesh (the game's MoveToPoint does the
# same), or the point itself where there is none.
func _on_mesh(p: Vector3) -> Vector3:
	if not _nav_ready():
		return p
	var q := NavigationServer3D.map_get_closest_point(_map(), p)
	return p if q == Vector3.ZERO else q


func _snap() -> void:
	var on := _on_mesh(global_position + Vector3.UP * HEIGHT_OFFSET)
	if on.distance_to(global_position) < 4.0:
		global_position = on - Vector3.UP * HEIGHT_OFFSET


# Running at you: seen, on your trail, enraged, or a gunshot heard.
func _hunting() -> bool:
	return _enraged() or state in [S.CHASE, S.ATTACK, S.DOOR] or (state == S.INVESTIGATE and _now() - heard_loud < 20.0)


func _lunging() -> bool:
	return state == S.CHASE and _now() - last_seen < 0.5 and global_position.distance_to(gameData.playerPosition) < 4.0


# How fast it moves (m/s). Always its clip's own speed times the clip rate, so
# the feet stay planted: wanderers drift, the ones that heard something
# shamble briskly, hunters jog, enraged ones sprint, and a last lunge.
func _speed() -> float:
	var natural := float(ZM.CLIP_SPEED.get(_move_anim(), 0.4))
	var keep := CRAWL_KEEP if _move_anim() == "crawl" else 1.0
	var want := natural * keep * 0.94
	if _hunting():
		want = float(ZM.setting("chase_speed")) * pace * (0.7 if crawler else 1.0)
		if _enraged():
			want *= 1.6
		elif _lunging():
			want *= 1.3
	elif state != S.WANDER:
		want = natural * keep * 1.2
	want *= float(ZM.setting("speed"))
	return natural * clampf(want / natural, MIN_RATE, MAX_RATE)


# One step along the path, in 3D like the game's enemies: the path's own
# height takes it up stairs and ramps and onto every floor. No path, no step:
# it never heads straight through a wall.
func _move(delta: float) -> void:
	if _busy():
		return                          # a one-shot (hit, scream, fall) plays where it stands
	_repath(delta)
	var next := agent.get_next_path_position()
	var to := next - global_position
	var you: Vector3 = gameData.playerPosition
	if agent.is_navigation_finished() or to.length() < 0.01 or (state == S.CHASE and global_position.distance_to(you) < 1.1):
		if not _close_in(delta):
			_play(_idle_anim(), 0.0)
		_ground()
		return
	if (_hunting() or tick % 4 == 0) and _check_door():
		return                          # a shut door on the way
	var flat := to * Vector3(1, 0, 1)
	if flat.length() > 0.01:
		move_dir = flat.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), minf(1.0, delta * 8.0))
	var spd := _speed() * clampf(-global_basis.z.dot(move_dir), 0.3, 1.0)   # turns before it strides off
	global_position += to.normalized() * minf(spd * delta, to.length())
	_ground()
	_play(_move_anim(), spd)
	_unstick(delta)


# The last metres to a player it can see on the same floor, where the path
# ends short of you; only while each step stays on walkable ground.
func _close_in(delta: float) -> bool:
	if state != S.CHASE or _now() - last_seen > 0.5 or not _nav_ready():
		return false
	var to: Vector3 = gameData.playerPosition - global_position
	var flat := to * Vector3(1, 0, 1)
	if flat.length() > 3.0 or flat.length() < 1.1 or absf(to.y) > 1.6:
		return false
	var at := global_position + flat.normalized() * _speed() * delta
	var on := NavigationServer3D.map_get_closest_point(_map(), at + Vector3.UP * HEIGHT_OFFSET)
	if ((on - at) * Vector3(1, 0, 1)).length() > 0.5 or absf(on.y - HEIGHT_OFFSET - global_position.y) > 0.5:
		return false
	global_position = Vector3(at.x, on.y - HEIGHT_OFFSET, at.z)
	_face(gameData.playerPosition, delta)
	_play(_move_anim(), _speed())
	return true


# A new path when the goal has really moved, or now and then: path searches
# across a whole map are the expensive part, so far ones repath less often.
func _repath(delta: float) -> void:
	path_age += delta
	var goal := target
	var d := global_position.distance_to(target)
	var every := clampf(d / 15.0, 0.4, 3.0) if state == S.CHASE else 2.0
	if path_to == Vector3.INF or path_to.distance_to(goal) > 6.0 \
			or (path_age > every and path_to.distance_to(goal) > 0.5) \
			or (agent.is_navigation_finished() and path_age > 1.5 and d > 2.0):
		agent.target_position = _flanked(d)
		path_to = goal
		path_age = 0.0


# A hunter comes at you from its own side, so a pack spreads; only where that
# side is open floor on your level (not the ground below your window, nor the
# far side of a wall).
func _flanked(d: float) -> Vector3:
	var aim := _on_mesh(target)
	var off := Vector3(cos(flank), 0, sin(flank)) * clampf((d - 5.0) * 0.2, 0.0, 3.0)
	if state != S.CHASE or off.length() < 0.1:
		return aim
	var side := _on_mesh(target + off)
	if absf(side.y - aim.y) > 1.0:
		return aim
	var q := PhysicsRayQueryParameters3D.create(aim + Vector3.UP, side + Vector3.UP, SIGHT_MASK)
	return side if get_world_3d().direct_space_state.intersect_ray(q).is_empty() else aim


# Hardly moved for two seconds while walking: a fresh path; then back onto
# the navigation mesh and somewhere else to go.
func _unstick(delta: float) -> void:
	stuck_t += delta
	if stuck_t < 2.0:
		return
	if global_position.distance_to(stuck_at) < 0.3:
		stuck_n += 1
		path_to = Vector3.INF
		if stuck_n >= 2:
			stuck_n = 0
			_snap()
			if state == S.WANDER:
				_pick_wander()
	else:
		stuck_n = 0
	stuck_at = global_position
	stuck_t = 0.0


# The feet onto the floor right under it: between its points the path can run
# a little above or below the floor (slopes, steps). Only the body is moved;
# the path itself is followed exactly.
func _ground() -> void:
	if tick % 6 != 0 and global_position.distance_to(gameData.playerPosition) > 40.0:
		return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * (HEIGHT_OFFSET + 0.5), global_position + Vector3.DOWN * 0.5, GROUND_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		model.position.y = lerpf(model.position.y, clampf(hit.position.y - global_position.y, -0.3, HEIGHT_OFFSET + 0.45), 0.35)


func _face(at: Vector3, delta: float) -> void:
	var dir := (at - global_position) * Vector3(1, 0, 1)
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))


func _attack(delta: float) -> void:
	_face(gameData.playerPosition, delta)
	attack_ready -= delta
	var reach := 1.4 if crawler else 1.9
	if global_position.distance_to(gameData.playerPosition) > reach + 0.4 or gameData.isDead:
		_set_state(S.CHASE)
		return
	if attack_ready <= 0.0 and not _busy():
		var t := _swing(["bite_2"] if crawler else ["attack", "punch", "headbutt"])
		if t > 0.0:
			attack_ready = t * 0.85
			Say("attack")
			get_tree().create_timer(t * 0.4, false).timeout.connect(_land_blow.bind(reach))
		else:
			attack_ready = 0.15
	elif not _busy():
		_play(_idle_anim(), 0.0)


func _land_blow(reach: float) -> void:
	if dead or state != S.ATTACK or gameData.isDead:
		return
	if global_position.distance_to(gameData.playerPosition) <= reach + 0.4:
		ZM.hurt_player(get_tree(), float(ZM.setting("damage")) * (0.6 if crawler else 1.0))


# A swing from the pool, never the one just played (starting that again would
# snap the pose back to its first frame): with only the one, a beat at rest
# first. Its length, or 0 when nothing swung.
func _swing(pool: Array) -> float:
	var fresh := pool.filter(func(c): return c != current_anim)
	if fresh.is_empty():
		_play(_idle_anim(), 0.0)
		return 0.0
	if not _play(fresh.pick_random(), 0.0, true, ATTACK_RATE):
		return 0.0
	return anim.current_animation_length / ATTACK_RATE


# ---------------------------------------------------------------- doors

# The navigation mesh runs through doorways, shut or not: a closed door on the
# way stops a hunter, which breaks it; a wanderer turns elsewhere. The probe
# runs along the path (round the next corner too), so only doors the route
# goes through count. True if it found one.
func _check_door() -> bool:
	var path := agent.get_current_navigation_path()
	var i := agent.get_current_navigation_path_index()
	var from := model.global_position + Vector3.UP * 1.0
	var left := maxf(1.2, 0.5 + _speed() * 0.35)
	var space := get_world_3d().direct_space_state
	for k in 2:
		if i + k >= path.size() or left <= 0.0:
			return false
		var to: Vector3 = path[i + k] + Vector3.UP * (1.0 - HEIGHT_OFFSET)
		var seg := to - from
		if seg.length() < 0.01:
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + seg.limit_length(left), PROBE_MASK))
		if not hit.is_empty():
			return _at_door(hit)
		left -= seg.length()
		from = to
	return false


func _at_door(hit: Dictionary) -> bool:
	var d = ZM.door_of(hit.collider)
	if d == null or d.isOpen:
		return false
	if state == S.WANDER:
		_pick_wander()
		return true
	door = d
	door_at = hit.position
	door_timer = 0.0
	_set_state(S.DOOR)
	return true


func _bash(delta: float) -> void:
	if door == null or not is_instance_valid(door) or door.isOpen:
		_door_done()
		return
	var gap := (door_at - global_position) * Vector3(1, 0, 1)
	if gap.length() > 0.9 and not _busy():                  # up to it (nothing between: the probe saw the door first)
		_face(door_at, delta)
		global_position += gap.normalized() * minf(_speed() * delta, gap.length() - 0.75)
		_ground()
		_play(_move_anim(), _speed())
		return
	_face(door_at, delta)
	door_timer -= delta
	if door_timer <= 0.0 and not _busy():
		var t := _swing(["bite_2"] if crawler else ["punch", "punch", "attack", "kick"])   # a crawler gnaws at it
		if t > 0.0:
			door_timer = t * 0.85
			get_tree().create_timer(t * 0.4, false).timeout.connect(_door_blow)
		else:
			door_timer = 0.15
	elif not _busy():
		_play(_idle_anim(), 0.0)


func _door_blow() -> void:
	if dead or state != S.DOOR or door == null or not is_instance_valid(door):
		return
	if ZM.hit_door(door, global_position):
		_door_done()


func _door_done() -> void:
	door = null
	_set_state(S.CHASE if _now() - last_seen < _aggro_time() else S.INVESTIGATE)


# ---------------------------------------------------------------- damage

func Hit(part: String, damage: float, vector: Vector3, id: Node3D, at: Vector3) -> void:
	if dead:
		return
	if part == "head" and Engine.has_meta("cs_head_damage") and id and id.is_in_group("Player"):
		damage = maxf(damage, float(Engine.get_meta("cs_head_damage")))   # e.g. the Welrod's headshot
	var mult: float = {"head": 3.0, "torso": 1.0}.get(part, 0.6)
	health -= damage * mult
	parts[part] = float(parts.get(part, 0.0)) + damage
	ZM.gore_hit(self, at, vector)
	if id and id.is_in_group("Player"):
		Hear(gameData.playerPosition, true)
		if not crawler and not _enraged() and randf() < float(ZM.setting("rage_chance")):
			enraged_until = _now() + randf_range(6.0, 12.0)    # it charges, screaming
			Say("scream", true)
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
	elif randf() < 0.5:
		Say("hit", true)
	# Now and then it staggers (never twice in a row, so gunfire can't pin it)
	if not dead and not crawler and state != S.ATTACK and _now() > stagger_ready and randf() < 0.25:
		stagger_ready = _now() + 4.0
		_play(["hit", "hit_2"].pick_random(), 0.0, true, 1.3)


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
		health = maxf(health, 30.0)
		# It goes down (the first half of a fall) and crawls on from there
		if _play("dying", 0.0, true, 1.0, true):
			anim.set_meta("cs_once_until", _now() + anim.current_animation_length * 0.55)
		var low := SphereShape3D.new()
		low.radius = 0.3
		var shape: CollisionShape3D = body.get_node("Shape")
		shape.shape = low
		shape.position = Vector3(0, HEIGHT_OFFSET + 0.3, 0)


func Death(vector: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	active = false
	state = S.DEAD
	for hb in hitboxes:
		hb.collision_layer = 0
	body.collision_layer = 0
	if not crawler:
		_play(["death", "dying"].pick_random(), 0.0, true, 1.0, true)
	elif current_anim != "dying":       # already on all fours: the rest of the fall, lying down
		anim.play("dying", 0.3)
		anim.seek(anim.current_animation_length * 0.55, true)
		anim.speed_scale = 1.0
		current_anim = "dying"
	Say("death", true)
	ZM.died(self, vector)
	if AISpawner and "activeEnemies" in AISpawner:
		AISpawner.activeEnemies -= 1


# ---------------------------------------------------------------- voice

# A sound from this zombie. Urgent ones (screams, pain, death) cut in;
# moans wait their turn so a horde doesn't drown everything.
func Say(kind: String, urgent := false) -> void:
	if voice == null or not is_inside_tree():
		return
	if voice.playing and not urgent:
		return
	if not voice.playing and ZM.speaking >= ZM.MAX_VOICES and not urgent:
		return
	var s := ZM.sound(kind)
	if s == null:
		return
	if not voice.playing:
		ZM.speaking += 1
	voice.stream = s
	voice.pitch_scale = randf_range(0.85, 1.1)
	voice.volume_db = 3.0 if kind == "scream" else 0.0
	voice.play()


# ---------------------------------------------------------------- animation

func _idle_anim() -> String:
	return "crawl" if crawler else ["idle", "idle_2", "idle_3", "idle_scratch"][get_instance_id() % 4]


func _move_anim() -> String:
	var id := get_instance_id()
	if crawler:
		return "crawl_run" if _hunting() else "crawl"
	if _hunting():
		return "run" if id % 2 == 0 else "run_2"
	if state == S.WANDER:
		return ["walk", "walk_3", "walk_2"][id % 3]
	return "walk_2"                                    # heard something: a brisk shamble


# Crossfade into a clip; moving clips are sped to the feet; one-shots finish
# before anything else plays, unless forced (death, the fall). True if it plays.
func _play(clip: String, move_speed: float, once := false, rate := 1.0, force_it := false) -> bool:
	if not force_it and current_anim != clip and _busy():
		return false
	if current_anim != clip:
		anim.play(clip, 0.5 if current_anim in ["dying", "death"] else 0.25)
		current_anim = clip
		played_at = _now()
	elif once:
		anim.seek(0.0, true)                           # the same swing again, from the start
	if move_speed > 0.0:
		anim.speed_scale = clampf(move_speed / float(ZM.CLIP_SPEED.get(clip, 1.0)), MIN_RATE * 0.3, MAX_RATE)   # down to the slowest turn
	elif ZM.CLIP_SPEED.has(clip):
		anim.speed_scale = 1.0 if _now() - played_at < 0.3 else 0.0   # a crawler at rest settles, then lies still
	else:
		anim.speed_scale = rate
	if once:
		anim.set_meta("cs_once_until", _now() + anim.current_animation_length / rate * 0.85)
	return true


func _busy() -> bool:
	return anim.has_meta("cs_once_until") and _now() < float(anim.get_meta("cs_once_until"))


func _enraged() -> bool:
	return _now() < enraged_until


func _now() -> float:
	return clock
