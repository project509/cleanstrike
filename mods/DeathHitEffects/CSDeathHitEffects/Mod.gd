# Death and Hit Effects: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_death_hit_effects"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"hit_marker": true,
	"splatter": true,
	"pools": true,
	"pool_size": 1.6,        # metres across when fully spread
	"pool_seconds": 20.0,    # time to spread
	"max_decals": 60,
}

const MARKER = preload("res://CSDeathHitEffects/Marker.gd")

static var decals: Array = []
static var _tex := {}


# A blood texture, drawn once: an irregular splat or a smooth pool.
static func texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7 if kind == "pool" else 13
	noise.frequency = 0.02 if kind == "pool" else 0.05
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var p := Vector2(x, y) - c
			var d := p.length() / (n / 2.0)
			var edge := 0.75 + 0.25 * noise.get_noise_2d(x, y) if kind == "pool" else 0.45 + 0.5 * noise.get_noise_2d(x, y)
			var a := clampf((edge - d) * 8.0, 0.0, 1.0)
			if kind == "splat":   # droplets around the splat
				a = maxf(a, clampf((noise.get_noise_2d(x * 3.0, y * 3.0) - 0.55) * 6.0, 0.0, 1.0) * float(d < 0.95))
			if a > 0.0:
				var shade := 0.2 + 0.05 * noise.get_noise_2d(x * 2.0, y * 2.0)   # dark maroon, not paint red
				img.set_pixel(x, y, Color(shade, 0.0, 0.005, a * 0.9))
	_tex[kind] = ImageTexture.create_from_image(img)
	return _tex[kind]


# A decal lying on a surface with normal n.
static func place(parent: Node, at: Vector3, n: Vector3, size: float, kind: String) -> Decal:
	var d := Decal.new()
	d.name = "CS_Blood"
	d.texture_albedo = texture(kind)
	d.size = Vector3(size, 0.3, size)
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.modulate = Color(0.85, 0.75, 0.75)
	d.lower_fade = 0.2
	parent.add_child(d)
	var y := n.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	d.global_transform = Transform3D(Basis(x, y, x.cross(y)).rotated(y, randf() * TAU), at)
	decals.append(d)
	decals = decals.filter(func(e): return is_instance_valid(e))
	while decals.size() > int(setting("max_decals")):
		decals.pop_front().queue_free()
	return d


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = exclude
	return space.intersect_ray(q)


# Blood on whatever is behind the target, along the shot.
static func splatter(world: Node3D, at: Vector3, dir: Vector3, exclude: Array = []) -> Decal:
	if not active() or not bool(setting("splatter")):
		return null
	var hit := _ray(world.get_world_3d().direct_space_state, at, at + dir.normalized() * 2.5, exclude)
	if hit.is_empty():
		return null
	return place(world.get_tree().current_scene, hit.position, hit.normal, randf_range(0.45, 0.8), "splat")


# A pool under a body that spreads out.
static func pool(body: Node3D, exclude: Array = []) -> Decal:
	if not active() or not bool(setting("pools")):
		return null
	var from := body.global_position + Vector3.UP * 0.6
	var hit := _ray(body.get_world_3d().direct_space_state, from, from + Vector3.DOWN * 2.5, exclude)
	if hit.is_empty():
		return null
	var d := place(body.get_tree().current_scene, hit.position, hit.normal, 0.1, "pool")
	var tw := d.create_tween()
	var full := float(setting("pool_size"))
	tw.tween_property(d, "size", Vector3(full, 0.3, full), float(setting("pool_seconds"))).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return d


static func marker(tree: SceneTree, is_kill: bool) -> Control:
	if not active() or not bool(setting("hit_marker")):
		return null
	var hud = tree.root.get_node_or_null("Map/Core/UI/HUD")
	if hud == null:
		return null
	var m = hud.get_node_or_null("CS_HitMarker")
	if m == null:
		m = MARKER.new()
		m.name = "CS_HitMarker"
		hud.add_child(m)
	m.show_hit(is_kill)
	return m


static func release() -> void:
	_tex.clear()
	decals.clear()

# Self-test hook: values here win over the player's settings.
static var overrides := {}


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


# False when Cleanstrike rolled this mod back: stay vanilla.
static func active() -> bool:
	var c := cs()
	return c == null or c.is_loaded(MOD_ID)


static func setting(key: String):
	if overrides.has(key):
		return overrides[key]
	var fallback = DEFAULTS.get(key)
	var c := cs()
	if c == null:
		return fallback
	var v = c.get_setting(MOD_ID, key, fallback)
	# Settings files store every number as a float: convert to the default's type.
	if typeof(fallback) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(round(v))
	if typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	return v if typeof(v) == typeof(fallback) else fallback


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])
