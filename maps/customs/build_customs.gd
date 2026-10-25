# Customs builder. Runs as the main scene of the recovered Road to Vostok
# project (so the game's singletons exist and its scripts compile):
#   Godot --headless --path <RTVProject> res://cs_tools/customs/Builder.tscn -- <prebuild_dir> <layout.json>
# Reads prebuild.py output plus layout.json and writes a Vostok-native map scene
# (same structure as the game's own maps) to res://RoadToTarkov/Customs/Build/.
extends Node

const OUT := "res://RoadToTarkov/Customs/Build"
const SAVE_FLAGS := ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_COMPRESS

const SCN_MAP := "res://Scripts/Map.gd"
const SCN_WORLD := "res://Resources/World.tscn"
const SCN_CORE := "res://Resources/Core.tscn"
const SCN_TRANSITION := "res://Resources/Transition.tscn"
const SCN_KILLBOX := "res://Resources/Killbox.tscn"
const SCN_POLE_GROUND := "res://Terrains/Utility/Pole_Ribbon_Ground.tscn"
const SCN_POLE_WATER := "res://Terrains/Utility/Pole_Ribbon_Water.tscn"
const SCN_FLAG := "res://Terrains/Utility/Flag_Transition.tscn"
const MAT_TERRAIN := "res://Terrains/Highway/Files/MT_Highway.tres"
const MAT_RIBBON := "res://Terrains/Utility/Files/MT_Ribbon.tres"
const MAT_WATER := "res://Environment/Water/Files/MT_Water.tres"
const MAT_WATER_LEAK := "res://Environment/Water/Files/MT_Water_Leak.tres"
const SND_SUBMERGED := "res://Audio/Effects/Water/Files/Submerged.wav"
const SND_WATER := "res://Audio/Effects/Water/Files/Water_Ambient_Calm.ogg"
const SCR_SURFACE := "res://Scripts/Surface.gd"
const SCR_WATER := "res://Scripts/Water.gd"
const SCR_BORDER := "res://Scripts/Border.gd"
const MAT_CONCRETE := "res://Assets/Bunker_Concrete/Files/MT_Bunker_Concrete.tres"
const MAT_BRICK := "res://Assets/Fireplace_Brick/Files/MT_Fireplace_Brick.tres"
const MAT_METAL := "res://Assets/Debris/Metal/Files/MT_Debris_Metal.tres"
const TREES := ["res://Nature/Trees/Tree_A.tscn", "res://Nature/Trees/Tree_B.tscn", "res://Nature/Trees/Tree_C.tscn", "res://Nature/Trees/Tree_D.tscn"]
const GRASS_DATA := "res://Nature/Data/Grass.tres"

const KINDS := {
	"warehouse": ["res://Assets/Hangar/Hangar_A.tscn", "res://Assets/Hangar/Hangar_B.tscn", "res://Assets/Hangar/Hangar_C.tscn", "res://Assets/Warehouse_Terminal/Warehouse_Terminal_B.tscn", "res://Assets/Warehouse_Terminal/Warehouse_Terminal_A.tscn"],
	"warehouse_red": ["res://Assets/Hangar/Hangar_B.tscn"],
	"warehouse_compound": ["res://Assets/Warehouse_Terminal/Warehouse_Terminal_A.tscn"],
	"factory": ["res://Assets/Hangar/Hangar_C.tscn", "res://Assets/Warehouse_Terminal/Warehouse_Terminal_B.tscn"],
	"industrial": ["res://Assets/Shack_Brick/Shack_Brick.tscn"],
	"office": ["res://Assets/Shack_Brick/Shack_Brick.tscn"],
	"boiler": ["res://Assets/Office_Airfield/Office_Airfield.tscn"],
	"gas_station": ["res://Assets/Gas_Station/Gas_Station.tscn"],
	"dorm_3storey": ["res://Assets/Khrushchevka/Khrushchevka.tscn"],
	"dorm_2storey": ["res://Assets/Office_Airfield/Office_Airfield.tscn"],
	"booth": ["res://Assets/Booth_Ticket/Booth_Ticket.tscn"],
}

var L: Dictionary
var M: Dictionary
var H: PackedFloat32Array
var CLS: PackedByteArray
var OX := 0.0
var OZ := 0.0
var map_root: Node3D
var content: Node3D
var rng := RandomNumberGenerator.new()
var aabb_cache := {}
var scene_cache := {}
var bridges: Array = []      # [{a: Vector2, b: Vector2, w: float, deck: float}] in layout metres
var stats := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <prebuild_dir> <layout.json>")
		get_tree().quit(1)
		return
	var dir: String = args[0]
	L = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	M = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("meta.json")))
	H = FileAccess.get_file_as_bytes(dir.path_join("heights.f32")).to_float32_array()
	CLS = FileAccess.get_file_as_bytes(dir.path_join("classes.u8"))
	OX = float(L.origin[0])
	OZ = float(L.origin[1])
	rng.seed = 20261025
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var t0 := Time.get_ticks_msec()

	# The builder produces the map content only. Customs.tscn (hand written)
	# wraps it with Map.gd, World.tscn and Core.tscn untouched, because those
	# carry editor tool scripts that must not be re-saved from here.
	content = NavigationRegion3D.new()
	content.name = "Content"
	map_root = content

	build_terrain(dir)
	log_step("terrain", t0)
	build_water()
	log_step("water", t0)
	build_bridges()
	build_rails()
	log_step("rails & bridges", t0)
	build_buildings()
	build_tanks_chimneys_pylons()
	build_props()
	build_fences()
	build_road_details()
	build_backdrop()
	log_step("buildings & props", t0)
	build_exits()
	build_border()
	build_killboxes()
	log_step("exits & border", t0)
	build_trees(dir)
	log_step("trees", t0)
	build_grass()
	log_step("grass", t0)

	var ps := PackedScene.new()
	var err := ps.pack(map_root)
	if err != OK:
		push_error("pack failed %d" % err)
		get_tree().quit(1)
		return
	err = ResourceSaver.save(ps, OUT + "/Customs_Content.scn", ResourceSaver.FLAG_COMPRESS)
	print("[customs] saved %s/Customs_Content.scn (err %d) in %.1fs  stats=%s" % [OUT, err, (Time.get_ticks_msec() - t0) / 1000.0, str(stats)])
	map_root.free()
	get_tree().quit(0 if err == OK else 1)


func log_step(what: String, t0: int) -> void:
	print("[customs] %s done at %.1fs" % [what, (Time.get_ticks_msec() - t0) / 1000.0])


# ------------------------------------------------------------------ helpers

func add(parent: Node, child: Node, n := "") -> Node:
	if n != "":
		child.name = n
	parent.add_child(child, true)
	child.owner = map_root
	return child


func own_tree(n: Node) -> void:
	for c in n.get_children():
		c.owner = map_root
		own_tree(c)


func group(parent: Node, n: String) -> Node3D:
	var g := parent.get_node_or_null(n)
	if g:
		return g
	var node := Node3D.new()
	add(parent, node, n)
	return node


func instance(path: String) -> Node3D:
	if not scene_cache.has(path):
		scene_cache[path] = load(path)
	return (scene_cache[path] as PackedScene).instantiate()


func save_res(res: Resource, file: String) -> Resource:
	var p := OUT + "/" + file
	var err := ResourceSaver.save(res, p, SAVE_FLAGS)
	if err != OK:
		push_error("save %s failed %d" % [p, err])
	return res


# Layout metres (x east, z south) -> world position, on the ground.
func W(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x - OX, ground(x, z) + lift, z - OZ)


func ground(x: float, z: float) -> float:
	var fx := (x - float(M.x0)) / float(M.spacing)
	var fz := (z - float(M.z0)) / float(M.spacing)
	var nx: int = M.nx
	var nz: int = M.nz
	fx = clampf(fx, 0.0, nx - 1.001)
	fz = clampf(fz, 0.0, nz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := H[iz * nx + ix]
	var h10 := H[iz * nx + ix + 1]
	var h01 := H[(iz + 1) * nx + ix]
	var h11 := H[(iz + 1) * nx + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func surface_class(x: float, z: float) -> int:
	var ix := clampi(int(round((x - float(M.x0)) / float(M.spacing))), 0, int(M.nx) - 1)
	var iz := clampi(int(round((z - float(M.z0)) / float(M.spacing))), 0, int(M.nz) - 1)
	return CLS[iz * int(M.nx) + ix]


func v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func yaw_of(dir: Vector2) -> float:
	# Basis(UP, yaw) maps local +X to (cos, 0, -sin): yaw that points +X along dir.
	return atan2(-dir.y, dir.x)


func asset_aabb(path: String) -> AABB:
	if aabb_cache.has(path):
		return aabb_cache[path]
	var inst := instance(path)
	var acc := [null]
	_merge_aabb(inst, Transform3D.IDENTITY, acc)
	inst.free()
	var a: AABB = acc[0] if acc[0] != null else AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	aabb_cache[path] = a
	return a


func _merge_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).layers != 0:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_merge_aabb(c, t, acc)


# Place a scene so its footprint is centred on (x, z) with the given yaw.
func place(path: String, parent: Node, x: float, z: float, yaw: float, lift := 0.0, scale := 1.0, centre := true) -> Node3D:
	var n := instance(path)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var pos := W(x, z, lift)
	if centre:
		var a := asset_aabb(path)
		var c := a.get_center()
		pos -= basis * Vector3(c.x, 0.0, c.z)
	n.transform = Transform3D(basis, pos)
	add(parent, n)
	return n


# Best fit of a scene into a layout rect: choose 0 or 90 degrees.
func fit_rect(path: String, rect: Array) -> Dictionary:
	var a := asset_aabb(path)
	var w := float(rect[2]) - float(rect[0])
	var d := float(rect[3]) - float(rect[1])
	var e0 := absf(a.size.x - w) + absf(a.size.z - d)
	var e90 := absf(a.size.z - w) + absf(a.size.x - d)
	return {"yaw": 0.0 if e0 <= e90 else PI / 2.0, "err": minf(e0, e90)}


func box_mesh_instance(parent: Node, size: Vector3, pos: Vector3, mat_path: String, yaw := 0.0, n := "Box", collide := true, surface := "Concrete") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = triplanar(mat_path)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	add(parent, mi, n)
	if collide:
		var body := StaticBody3D.new()
		body.set_script(load(SCR_SURFACE))
		body.set("surface", surface)
		add(mi, body, "StaticBody3D")
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		add(body, cs, "CollisionShape3D")
	return mi


var _triplanar_cache := {}
func triplanar(path: String) -> Material:
	if _triplanar_cache.has(path):
		return _triplanar_cache[path]
	var m: Material = load(path)
	if m is StandardMaterial3D:
		var sm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.uv1_triplanar = true
		sm.uv1_world_triplanar = true
		sm.uv1_scale = Vector3(0.25, 0.25, 0.25)
		save_res(sm, "MT_%s_Triplanar.tres" % path.get_file().get_basename())
		m = sm
	_triplanar_cache[path] = m
	return m


func static_trimesh(parent: Node, faces: PackedVector3Array, n: String, surface: String, layer_bit := 1, mask := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer_bit
	body.collision_mask = mask
	if surface != "":
		body.set_script(load(SCR_SURFACE))
		body.set("surface", surface)
	add(parent, body, n)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = save_res(shape, "COL_%s_%s.res" % [parent.name, n])
	add(body, cs, "CollisionShape3D")
	return body


func resample(points: Array, step: float) -> Array:
	var out: Array = []
	for i in points.size() - 1:
		var a := v2(points[i])
		var b := v2(points[i + 1])
		var len := a.distance_to(b)
		var n := maxi(1, int(ceil(len / step)))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	out.append(v2(points[-1]))
	return out


# ------------------------------------------------------------------ terrain

func build_terrain(dir: String) -> void:
	var terrain := group(content, "Terrain")
	var elements := group(terrain, "Elements")
	var nx: int = M.nx
	var nz: int = M.nz
	var sp: float = M.spacing
	var tile: float = M.tile
	var cols := int(tile / sp)
	var base: ShaderMaterial = load(MAT_TERRAIN)
	for t in int(M.tiles):
		var img := Image.load_from_file(dir.path_join("mask_%d.png" % t))
		img.generate_mipmaps()
		var tex := PortableCompressedTexture2D.new()
		tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		save_res(tex, "TX_Customs_Roads_%d.res" % t)
		var mat := base.duplicate() as ShaderMaterial
		mat.set_shader_parameter("roadMask", tex)
		save_res(mat, "MT_Customs_%d.tres" % t)

		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var tangents := PackedFloat32Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var c0 := t * cols
		var tx0: float = float(M.x0) + t * tile
		for j in nz:
			for i in range(c0, c0 + cols + 1):
				var x: float = float(M.x0) + i * sp
				var z: float = float(M.z0) + j * sp
				var h := H[j * nx + i]
				verts.append(Vector3(x - OX, h, z - OZ))
				var hl := H[j * nx + maxi(i - 1, 0)]
				var hr := H[j * nx + mini(i + 1, nx - 1)]
				var hu := H[maxi(j - 1, 0) * nx + i]
				var hd := H[mini(j + 1, nz - 1) * nx + i]
				var nrm := Vector3(hl - hr, 2.0 * sp, hu - hd).normalized()
				normals.append(nrm)
				var tan := Vector3(1, 0, 0)
				tan = (tan - nrm * nrm.dot(tan)).normalized()
				tangents.append_array([tan.x, tan.y, tan.z, 1.0])
				uvs.append(Vector2((x - tx0) / tile, (z - float(M.z0)) / tile))
		var w := cols + 1
		for j in nz - 1:
			for i in cols:
				var a := j * w + i
				idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, mat)
		save_res(mesh, "MS_Customs_Terrain_%d.res" % t)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add(elements, mi, "Terrain_%d" % t)

	# Collision split by surface, like Vostok's Grass / Dirt / Asphalt elements.
	var f0 := PackedVector3Array()
	var f1 := PackedVector3Array()
	var f2 := PackedVector3Array()
	for j in nz - 1:
		for i in nx - 1:
			var cls := CLS[j * nx + i]
			var k: int = 1 if cls == 3 else int(cls)
			var x: float = float(M.x0) + i * sp - OX
			var z: float = float(M.z0) + j * sp - OZ
			var p00 := Vector3(x, H[j * nx + i], z)
			var p10 := Vector3(x + sp, H[j * nx + i + 1], z)
			var p01 := Vector3(x, H[(j + 1) * nx + i], z + sp)
			var p11 := Vector3(x + sp, H[(j + 1) * nx + i + 1], z + sp)
			var quad := [p00, p10, p01, p10, p11, p01]
			if k == 0:
				f0.append_array(quad)
			elif k == 1:
				f1.append_array(quad)
			else:
				f2.append_array(quad)
	var faces := {0: f0, 1: f1, 2: f2}
	var names := {0: ["Grass", "Grass"], 1: ["Dirt", "Dirt"], 2: ["Asphalt", "Concrete"]}
	for k in faces:
		var holder := MeshInstance3D.new()
		holder.layers = 0
		add(elements, holder, names[k][0])
		static_trimesh(holder, faces[k], "StaticBody3D", names[k][1])
	stats["terrain_tris"] = idx_count()


func idx_count() -> int:
	return (int(M.nx) - 1) * (int(M.nz) - 1) * 2


# ------------------------------------------------------------------ water

func build_water() -> void:
	var river: Dictionary = L.river
	var level: float = M.water_level
	var pts := resample(river.points, 6.0)
	var half: float = float(river.width) / 2.0 + 18.0
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in pts.size():
		var p: Vector2 = pts[i]
		var nxt: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var prv: Vector2 = pts[maxi(i - 1, 0)]
		var d := (nxt - prv).normalized()
		var side := Vector2(-d.y, d.x)
		for s in [-1.0, 1.0]:
			var q: Vector2 = p + side * half * s
			verts.append(Vector3(q.x - OX, level, q.y - OZ))
			uvs.append(Vector2(q.x, q.y) / 8.0)
		if i > 0:
			var a := (i - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	save_res(mesh, "MS_Customs_Water.res")

	var water := Node3D.new()
	water.set_script(load(SCR_WATER))
	add(content, water, "Water")
	var surf := MeshInstance3D.new()
	surf.mesh = mesh
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surf.set_surface_override_material(0, load(MAT_WATER))
	add(water, surf, "Water")
	var faces := PackedVector3Array()
	for k in range(0, idx.size(), 3):
		faces.append_array([verts[idx[k]], verts[idx[k + 1]], verts[idx[k + 2]]])
	static_trimesh(surf, faces, "StaticBody3D", "Water", 268435456, 1)
	var leak := MeshInstance3D.new()
	leak.mesh = mesh
	leak.transform.origin = Vector3(0, -1, 0)
	leak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leak.set_surface_override_material(0, load(MAT_WATER_LEAK))
	add(water, leak, "Leak")
	var sub := AudioStreamPlayer.new()
	sub.stream = load(SND_SUBMERGED)
	add(water, sub, "Submerged")

	var audio := group(content, "Audio")
	var k := 0
	for p in resample(river.points, 70.0):
		var a := AudioStreamPlayer3D.new()
		a.stream = load(SND_WATER)
		a.unit_size = 100.0
		a.max_distance = 100.0
		a.autoplay = true
		a.bus = &"Ambient"
		a.transform.origin = Vector3(p.x - OX, level, p.y - OZ)
		add(audio, a, "Water_%02d" % k)
		k += 1


# ------------------------------------------------------------------ bridges & rails

func deck_height(path: String) -> float:
	# The largest upward-facing surface above 2 m is the deck.
	var inst := instance(path)
	var buckets := {}
	_deck_scan(inst, Transform3D.IDENTITY, buckets)
	inst.free()
	var best := 0.0
	var best_area := 0.0
	for k in buckets:
		if float(k) > 2.0 and float(buckets[k]) > best_area:
			best_area = buckets[k]
			best = float(k)
	return best


func _deck_scan(n: Node, xf: Transform3D, buckets: Dictionary) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).layers != 0:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix = arr[Mesh.ARRAY_INDEX]
			var count: int = ix.size() if ix != null and ix.size() > 0 else v.size()
			for k in range(0, count, 3):
				var a := t * v[ix[k] if ix != null and ix.size() > 0 else k]
				var b := t * v[ix[k + 1] if ix != null and ix.size() > 0 else k + 1]
				var c := t * v[ix[k + 2] if ix != null and ix.size() > 0 else k + 2]
				var cr := (b - a).cross(c - a)
				var area := cr.length() * 0.5
				if area < 0.01:
					continue
				if absf(cr.normalized().y) > 0.97:
					var key := snappedf((a.y + b.y + c.y) / 3.0, 0.25)
					buckets[key] = float(buckets.get(key, 0.0)) + area
	for c in n.get_children():
		_deck_scan(c, t, buckets)


func build_bridges() -> void:
	var g := group(content, "Bridges")
	for b in L.bridges:
		var a := v2(b.from)
		var c := v2(b.to)
		var mid := (a + c) / 2.0
		var dir := (c - a).normalized()
		var road_h := maxf(ground(a.x, a.y), ground(c.x, c.y)) + 0.15
		if b.name == "road_bridge":
			var path := "res://Assets/Bridge_Highway/Bridge_Highway_B.tscn"
			var deck := deck_height(path)
			var n := instance(path)
			var basis := Basis(Vector3.UP, yaw_of(dir))
			var aa := asset_aabb(path)
			var centre := basis * Vector3(aa.get_center().x, 0, aa.get_center().z)
			n.transform = Transform3D(basis, Vector3(mid.x - OX, road_h - deck, mid.y - OZ) - centre)
			add(g, n, "Road_Bridge")
			bridges.append({"a": a, "b": c, "w": float(b.width), "deck": road_h})
			stats["road_bridge_deck"] = deck
		else:
			# Concrete rail bridge: deck on two piers, built to the map's scale.
			var length := a.distance_to(c) + 8.0
			var yaw := yaw_of(dir)
			var deck_top := road_h + 0.4
			var span := group(g, "Rail_Bridge")
			box_mesh_instance(span, Vector3(length, 1.2, float(b.width)), Vector3(mid.x - OX, deck_top - 0.6, mid.y - OZ), MAT_CONCRETE, yaw, "Deck")
			for s in [-0.25, 0.25]:
				var p := mid + dir * length * float(s)
				var bottom := ground(p.x, p.y) - 2.0
				var hgt := deck_top - 1.2 - bottom
				box_mesh_instance(span, Vector3(2.0, hgt, float(b.width) - 1.0), Vector3(p.x - OX, bottom + hgt / 2.0, p.y - OZ), MAT_CONCRETE, yaw, "Pier")
			bridges.append({"a": a, "b": c, "w": float(b.width), "deck": deck_top})


func bridge_height(p: Vector2) -> float:
	for b in bridges:
		var a: Vector2 = b.a
		var c: Vector2 = b.b
		var ab := c - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), -0.08, 1.08)
		if p.distance_to(a + ab * t) < float(b.w) / 2.0 + 1.0:
			return float(b.deck)
	return -INF


func build_rails() -> void:
	var g := group(content, "Rails")
	var seg := "res://Assets/Railroad/Railroad.tscn"
	var count := 0
	for r in L.rails:
		var pts := resample(r.points, 10.0)
		var line := group(g, String(r.name))
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var len := a.distance_to(b)
			if len < 0.5:
				continue
			var ha := maxf(ground(a.x, a.y), bridge_height(a)) + 0.05
			var hb := maxf(ground(b.x, b.y), bridge_height(b)) + 0.05
			var from := Vector3(a.x - OX, ha, a.y - OZ)
			var to := Vector3(b.x - OX, hb, b.y - OZ)
			var basis := Basis.looking_at(to - from, Vector3.UP).scaled(Vector3(1, 1, len / 10.0))
			var n := instance(seg)
			n.transform = Transform3D(basis, from)
			add(line, n)
			count += 1
	stats["rail_segments"] = count


# ------------------------------------------------------------------ buildings

func build_buildings() -> void:
	var g := group(content, "Buildings")
	for b in L.buildings:
		var kind: String = b.kind
		var rect: Array = b.rect
		var cx := (float(rect[0]) + float(rect[2])) / 2.0
		var cz := (float(rect[1]) + float(rect[3])) / 2.0
		var holder := group(g, String(b.name))
		match kind:
			"gas_station_old":
				build_old_gas_station(holder, rect)
			"checkpoint":
				build_checkpoint(holder, rect)
			"storage_sheds":
				build_sheds(holder, rect)
			"concrete_frame":
				build_frame(holder, rect, float(b.height), MAT_CONCRETE, 0.6, 6.0, 3.3, "Concrete")
			"steel_frame":
				build_frame(holder, rect, float(b.height), MAT_METAL, 0.35, 5.0, 4.0, "Metal")
			_:
				if KINDS.has(kind):
					var best := ""
					var fit := {}
					for path in KINDS[kind]:
						var f := fit_rect(path, rect)
						if best == "" or float(f.err) < float(fit.err):
							best = path
							fit = f
					place(best, holder, cx, cz, float(fit.yaw))
					stats[String(b.name)] = best.get_file()
				else:
					var size := Vector3(float(rect[2]) - float(rect[0]), float(b.height), float(rect[3]) - float(rect[1]))
					box_mesh_instance(holder, size, W(cx, cz, size.y / 2.0), MAT_CONCRETE)


func build_old_gas_station(holder: Node, rect: Array) -> void:
	var cx := (float(rect[0]) + float(rect[2])) / 2.0
	var cz := (float(rect[1]) + float(rect[3])) / 2.0
	place("res://Assets/Kiosk/Kiosk.tscn", holder, cx - 10, cz - 6, 0.0)
	for k in 3:
		place("res://Assets/Gas_Station/Gas_Station_Canopy.tscn", holder, cx + 2 + k * 7.0, cz + 4, 0.0)
	place("res://Assets/Gas_Station/Gas_Station_Totem.tscn", holder, cx + 15, cz + 10, PI / 2.0)
	place("res://Assets/Shack_A/Shack_A.tscn", holder, cx - 12, cz + 7, PI / 2.0)


func build_checkpoint(holder: Node, rect: Array) -> void:
	var cx := (float(rect[0]) + float(rect[2])) / 2.0
	place("res://Assets/Booth_Ticket/Booth_Ticket.tscn", holder, cx - 6, float(rect[1]) + 4, 0.0)
	place("res://Assets/Booth_Ticket/Booth_Ticket.tscn", holder, cx + 6, float(rect[3]) - 4, PI)
	for k in 4:
		place("res://Assets/Barrier_Highway/Barrier_Highway.tscn", holder, float(rect[0]) + 3 + k * 6.0, float(rect[1]) - 4, 0.0)


func build_sheds(holder: Node, rect: Array) -> void:
	var path := "res://Assets/Garage_Rural/Garage_Rural_A.tscn"
	var a := asset_aabb(path)
	var w := float(rect[2]) - float(rect[0])
	var d := float(rect[3]) - float(rect[1])
	var along_z := d > w
	var step := a.size.x + 0.4
	var length := d if along_z else w
	var n := maxi(1, int(length / step))
	for k in n:
		var t := (k + 0.5) * length / n
		var x := (float(rect[0]) + w / 2.0) if along_z else (float(rect[0]) + t)
		var z := (float(rect[1]) + t) if along_z else (float(rect[1]) + d / 2.0)
		place(path, holder, x, z, PI / 2.0 if along_z else 0.0)


# Unfinished frame: columns on a grid and partial floor slabs.
func build_frame(holder: Node, rect: Array, height: float, mat: String, col: float, grid: float, floor_h: float, surface: String) -> void:
	var x0 := float(rect[0]) + 1.0
	var z0 := float(rect[1]) + 1.0
	var x1 := float(rect[2]) - 1.0
	var z1 := float(rect[3]) - 1.0
	var base := ground((x0 + x1) / 2.0, (z0 + z1) / 2.0)
	var floors := maxi(1, int(height / floor_h))
	var nx := maxi(1, int((x1 - x0) / grid))
	var nz := maxi(1, int((z1 - z0) / grid))
	for f in floors:
		var y0 := base + f * floor_h
		for i in nx + 1:
			for j in nz + 1:
				if f == floors - 1 and rng.randf() < 0.35:
					continue
				var x := lerpf(x0, x1, float(i) / nx)
				var z := lerpf(z0, z1, float(j) / nz)
				box_mesh_instance(holder, Vector3(col, floor_h, col), Vector3(x - OX, y0 + floor_h / 2.0, z - OZ), mat, 0.0, "Column", true, surface)
		if f > 0 or surface == "Concrete":
			var cover := 1.0 if f < floors - 1 else 0.55
			var sx := (x1 - x0) * cover
			box_mesh_instance(holder, Vector3(sx, 0.3, z1 - z0), Vector3(x0 + sx / 2.0 - OX, y0 + floor_h, (z0 + z1) / 2.0 - OZ), mat, 0.0, "Slab", true, surface)


func build_tanks_chimneys_pylons() -> void:
	var g := group(content, "Industry")
	for t in L.tanks:
		var c := v2(t.center)
		place("res://Assets/Tank_Oil/Tank_Oil_A.tscn", g, c.x, c.y, rng.randf() * TAU, 0.0, float(t.radius) / 9.5)
	for ch in L.chimneys:
		var p := v2(ch.pos)
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.height = float(ch.height)
		cyl.bottom_radius = float(ch.radius)
		cyl.top_radius = float(ch.radius) * 0.7
		cyl.radial_segments = 20
		mi.mesh = cyl
		mi.material_override = triplanar(MAT_BRICK)
		mi.transform.origin = W(p.x, p.y, float(ch.height) / 2.0 - 0.5)
		add(g, mi, String(ch.name))
		var body := StaticBody3D.new()
		body.set_script(load(SCR_SURFACE))
		body.set("surface", "Concrete")
		add(mi, body, "StaticBody3D")
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.height = float(ch.height)
		shape.radius = float(ch.radius)
		cs.shape = shape
		add(body, cs, "CollisionShape3D")
	var pylons: Array = L.pylons
	for i in pylons.size():
		var p := v2(pylons[i])
		var q := v2(pylons[i + 1] if i + 1 < pylons.size() else pylons[i - 1])
		var dir := (q - p).normalized()
		# Cross arms (+X) perpendicular to the line.
		place("res://Assets/Tower_Electric/Tower_Electric.tscn", g, p.x, p.y, yaw_of(Vector2(-dir.y, dir.x)))


func build_props() -> void:
	var g := group(content, "Props")
	for pr in L.props:
		var r: Array = pr.rect
		var w := float(r[2]) - float(r[0])
		var d := float(r[3]) - float(r[1])
		var along_z := d >= w
		var cx := (float(r[0]) + float(r[2])) / 2.0
		var cz := (float(r[1]) + float(r[3])) / 2.0
		match String(pr.kind):
			"rail_tankers":
				var n := maxi(1, int((d if along_z else w) / 12.8))
				for k in n:
					var t := (k + 0.5) / n
					place("res://Assets/Train_Oil/Train_Oil.tscn", g, cx if along_z else lerpf(float(r[0]), float(r[2]), t), lerpf(float(r[1]), float(r[3]), t) if along_z else cz, 0.0 if along_z else PI / 2.0)
			"buses":
				for k in 4:
					place("res://Assets/Vehicles/PAZ/PAZ.tscn", g, float(r[0]) + 3 + k * 5.5, cz, 0.05 * k)
			"tanker_yard":
				for i in 4:
					for j in 3:
						place("res://Assets/Tank_Fuel/Tank_Fuel.tscn", g, float(r[0]) + 4 + i * 6.0, float(r[1]) + 5 + j * 8.0, 0.0)
				place("res://Assets/Vehicles/Truck_Trailers/Truck_Trailer_Fuel/Truck_Trailer_Fuel.tscn", g, cx + 8, cz, PI / 2.0)
			"parking":
				var cars := ["res://Assets/Vehicles/Lada/Lada_White.tscn", "res://Assets/Vehicles/Lada/Lada_Blue.tscn", "res://Assets/Vehicles/Lada/Lada_Red.tscn"]
				for k in 5:
					place(cars[k % 3], g, float(r[0]) + 3 + k * 5.0, float(r[1]) + 4 + (k % 2) * 3.0, PI / 2.0 + rng.randf_range(-0.2, 0.2))


func build_fences() -> void:
	var g := group(content, "Fences")
	var panel := "res://Assets/Fence_Military/Fence_Military.tscn"
	for f in L.fences:
		var pts: Array = f.points.duplicate()
		if bool(f.get("closed", false)):
			pts.append(pts[0])
		var gates: Array = f.get("gates", [])
		for i in pts.size() - 1:
			var a := v2(pts[i])
			var b := v2(pts[i + 1])
			var len := a.distance_to(b)
			var dir := (b - a) / len
			var n := int(len / 5.0)
			for k in n:
				var p := a + dir * (k * 5.0)
				var mid := p + dir * 2.5
				var skip := false
				for gt in gates:
					if mid.distance_to(Vector2(float(gt[0]), float(gt[1]))) < float(gt[2]) / 2.0:
						skip = true
				if skip:
					continue
				var n3 := instance(panel)
				n3.transform = Transform3D(Basis(Vector3.UP, yaw_of(dir)), W(p.x, p.y))
				add(g, n3)
		for gt in gates:
			place("res://Assets/Gate_Metal/Gate_Metal.tscn", g, float(gt[0]), float(gt[1]), 0.0)


func build_road_details() -> void:
	# Concrete street lights along the main road, like Vostok's highway.
	var g := group(content, "Roadside")
	for r in L.roads:
		if r.name != "main_road":
			continue
		var pts := resample(r.points, 45.0)
		for i in range(1, pts.size() - 1):
			var p: Vector2 = pts[i]
			var dir: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
			var side := Vector2(-dir.y, dir.x)
			var q := p + side * (float(r.width) / 2.0 + 1.5)
			if bridge_height(q) > -INF:
				continue
			place("res://Assets/Pole_Light_Concrete/Pole_Light_Concrete.tscn", g, q.x, q.y, yaw_of(side), 0.0, 1.0, false)


func build_backdrop() -> void:
	# Outside the border: cooling towers and the factory hall behind Railroad Passage.
	var g := group(content, "Backdrop")
	for b in L.backdrop:
		match String(b.kind):
			"cooling_tower":
				var p := v2(b.pos)
				var r := float(b.radius)
				var hgt := float(b.height)
				for part in 2:
					var mi := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					cyl.height = hgt / 2.0
					cyl.bottom_radius = r if part == 0 else r * 0.68
					cyl.top_radius = r * 0.68 if part == 0 else r * 0.78
					cyl.radial_segments = 32
					cyl.cap_top = false
					mi.mesh = cyl
					mi.material_override = triplanar(MAT_CONCRETE)
					mi.transform.origin = W(p.x, p.y, hgt / 4.0 + part * hgt / 2.0)
					add(g, mi, "CoolingTower")
			"factory_hall":
				var r: Array = b.rect
				var size := Vector3(float(r[2]) - float(r[0]), float(b.height), float(r[3]) - float(r[1]))
				box_mesh_instance(g, size, W((float(r[0]) + float(r[2])) / 2.0, (float(r[1]) + float(r[3])) / 2.0, size.y / 2.0), MAT_CONCRETE, 0.0, String(b.get("name", "Hall")), false)


# ------------------------------------------------------------------ exits, border, killbox

func build_exits() -> void:
	var g := group(group(content, "Terrain"), "Transitions")
	var centre := Vector2(540, 340)
	var used := {}
	for e in L.exits:
		var p := v2(e.pos)
		var inward := (centre - p).normalized()
		p += inward * 4.0
		var to: String = e.to
		var n := "Transition_" + to
		if not e.has("spawn_for") or used.has(n):
			n = "Transition_%s_%s" % [to, String(e.name).replace(" ", "").replace("-", "")]
		used[n] = true
		var tr := instance(SCN_TRANSITION)
		tr.transform = Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.y)), W(p.x, p.y))
		tr.set("nextMap", to)
		tr.set("nextZone", "Area 05")
		tr.set("currentMap", "Customs")
		tr.set("time", 2.0 if to == "Outpost" else 1.0)
		add(g, tr, n)
		tr.set("spawn", tr.get_node("Spawn"))
		tr.set_meta("rtt_exit_name", String(e.name))
	stats["exits"] = L.exits.size()


func build_border() -> void:
	var border := Node3D.new()
	border.set_script(load(SCR_BORDER))
	border.set("layers", 268435473)
	add(group(content, "Terrain"), border, "Border")
	var poles := group(border, "Poles")
	var flags := group(border, "Flags")
	var level: float = M.water_level
	var pts: Array = L.playable_boundary.duplicate()
	pts.append(pts[0])
	var positions: Array = []      # [Vector3, is_water]
	for i in pts.size() - 1:
		var a := v2(pts[i])
		var b := v2(pts[i + 1])
		var len := a.distance_to(b)
		var d := 0.0
		while d < len:
			var p := a.lerp(b, d / len)
			var gh := ground(p.x, p.y)
			var wet := gh < level - 0.3
			positions.append([Vector3(p.x - OX, level if wet else gh, p.y - OZ), wet])
			d += 20.0 if wet else 10.0
	var k := 0
	for item in positions:
		var wet: bool = item[1]
		var pole := instance(SCN_POLE_WATER if wet else SCN_POLE_GROUND)
		pole.transform.origin = item[0]
		add(poles, pole, "Pole_Ribbon_%s_%d" % ["Water" if wet else "Ground", k])
		k += 1
	for e in L.exits:
		var p := v2(e.pos)
		var f := instance(SCN_FLAG)
		f.transform.origin = W(p.x, p.y, 1.5)
		add(flags, f)
	border.add_child(make_ribbon(positions), true)
	border.get_child(-1).owner = map_root
	add_wall(border, positions, "Border", 2147483648, "", 100.0, -100.0)
	add_blocker(border, positions)
	stats["border_poles"] = positions.size()


func make_ribbon(positions: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(load(MAT_RIBBON))
	var count := 0
	for i in positions.size():
		var a: Vector3 = positions[i][0] + Vector3(0, 0.9 if positions[i][1] else 1.4, 0)
		var nb = positions[(i + 1) % positions.size()]
		var b: Vector3 = nb[0] + Vector3(0, 0.9 if nb[1] else 1.4, 0)
		var steps := maxi(2, int(a.distance_to(b) * 0.5))
		for s in steps + 1:
			var t := float(s) / steps
			var p := a.lerp(b, t)
			p.y -= 1.0 * t * (1.0 - t)
			var fwd := (b - a).normalized()
			var right := fwd.cross(Vector3.UP).normalized()
			for corner in 2:
				st.set_uv(Vector2(t, float(corner)))
				st.set_normal(right)
				st.add_vertex(p + Vector3(0, 0.05 if corner == 0 else -0.05, 0))
				count += 1
			if s > 0:
				var i0 := count - 4
				st.add_index(i0)
				st.add_index(i0 + 2)
				st.add_index(i0 + 3)
				st.add_index(i0)
				st.add_index(i0 + 3)
				st.add_index(i0 + 1)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Ribbon"
	mi.mesh = save_res(st.commit(), "MS_Customs_Ribbon.res")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func add_wall(parent: Node, positions: Array, n: String, layer_bit: int, surface: String, top: float, bottom: float) -> void:
	var faces := PackedVector3Array()
	for i in positions.size():
		var a: Vector3 = positions[i][0]
		var b: Vector3 = positions[(i + 1) % positions.size()][0]
		var bl := Vector3(a.x, bottom, a.z)
		var br := Vector3(b.x, bottom, b.z)
		var tl := Vector3(a.x, top, a.z)
		var trr := Vector3(b.x, top, b.z)
		faces.append_array([bl, tl, br, br, tl, trr])
	var holder := MeshInstance3D.new()
	holder.layers = 0
	add(parent, holder, n)
	static_trimesh(holder, faces, "StaticBody3D", surface, layer_bit, 0)


func add_blocker(parent: Node, positions: Array) -> void:
	var faces := PackedVector3Array()
	for i in positions.size():
		var a: Vector3 = positions[i][0] + Vector3(0, 1.5, 0)
		var b: Vector3 = positions[(i + 1) % positions.size()][0] + Vector3(0, 1.5, 0)
		var fwd := (b - a).normalized()
		var right := fwd.cross(Vector3.UP).normalized() * 2.5
		faces.append_array([a - right, a + right, b - right, a + right, b + right, b - right])
	var holder := MeshInstance3D.new()
	holder.layers = 0
	add(parent, holder, "Blocker")
	static_trimesh(holder, faces, "StaticBody3D", "Border", 1073741824, 0)


func build_killboxes() -> void:
	var g := group(content, "Killboxes")
	for i in 4:
		for j in 2:
			var kb := instance(SCN_KILLBOX)
			kb.transform.origin = Vector3(-600 + i * 400, 0, -200 + j * 400)
			add(g, kb, "Killbox")


# ------------------------------------------------------------------ vegetation

func build_trees(dir: String) -> void:
	var trees: Array = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("trees.json")))
	var parts: Array = []
	for path in TREES:
		var inst := instance(path)
		var part := {}
		for k in ["Mesh", "Billboard", "Shadow", "Collider", "Obstruction"]:
			var nd := inst.get_node_or_null(k) as MeshInstance3D
			if nd:
				part[k] = {"mesh": nd.mesh, "xf": nd.transform, "m0": nd.get_surface_override_material(0),
					"m1": nd.get_surface_override_material(1) if nd.mesh.get_surface_count() > 1 else null,
					"end": nd.visibility_range_end, "begin": nd.visibility_range_begin}
		parts.append(part)
		inst.free()
	var veg := group(content, "Vegetation")
	var chunks := {}
	for t in trees:
		var x := float(t[0])
		var z := float(t[1])
		var key := "%d_%d" % [int(floor(x / 100.0)), int(floor(z / 100.0))]
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
	var total := 0
	for key in chunks:
		var holder := group(veg, "Trees_" + key)
		var shadow_st := SurfaceTool.new()
		shadow_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var col_faces := PackedVector3Array()
		var obs_faces := PackedVector3Array()
		var shadow_mat: Material = null
		var n := 0
		for t in chunks[key]:
			var part: Dictionary = parts[int(t[2])]
			var x := float(t[0])
			var z := float(t[1])
			var s := float(t[3])
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.1, 0.1), float(t[4]), rng.randf_range(-0.1, 0.1))).scaled(Vector3.ONE * s)
			var xf := Transform3D(basis, W(x, z, -0.1))
			var m: Dictionary = part.Mesh
			var tree := MeshInstance3D.new()
			tree.mesh = m.mesh
			tree.transform = xf * (m.xf as Transform3D)
			if m.m0:
				tree.set_surface_override_material(0, m.m0)
			if m.m1:
				tree.set_surface_override_material(1, m.m1)
			tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tree.visibility_range_end = float(m.end)
			add(holder, tree, "Tree" if n == 0 else "Tree_%02d" % n)
			if part.has("Billboard"):
				var bbd: Dictionary = part.Billboard
				var bb := MeshInstance3D.new()
				bb.mesh = bbd.mesh
				bb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				bb.visibility_range_begin = float(bbd.begin)
				if bbd.m0:
					bb.set_surface_override_material(0, bbd.m0)
				add(tree, bb, "Billboard")
			if part.has("Shadow"):
				var sd: Dictionary = part.Shadow
				shadow_st.append_from(sd.mesh, 0, xf * (sd.xf as Transform3D))
				shadow_mat = sd.m0
			for kind in ["Collider", "Obstruction"]:
				if part.has(kind):
					var cd: Dictionary = part[kind]
					var faces: PackedVector3Array = (cd.mesh as Mesh).get_faces()
					var cxf: Transform3D = xf * (cd.xf as Transform3D)
					for v in faces:
						if kind == "Collider":
							col_faces.append(cxf * v)
						else:
							obs_faces.append(cxf * v)
			n += 1
		var shadow_mesh := shadow_st.commit()
		if shadow_mesh.get_surface_count() > 0:
			var sh := MeshInstance3D.new()
			sh.mesh = save_res(shadow_mesh, "MS_Trees_Shadow_%s.res" % key)
			if shadow_mat:
				sh.set_surface_override_material(0, shadow_mat)
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			add(holder, sh, "Shadow")
		if col_faces.size() > 0:
			static_trimesh(holder, col_faces, "Collider", "Wood", 1, 1)
		if obs_faces.size() > 0:
			static_trimesh(holder, obs_faces, "Obstruction", "", 1 << 10, 1)
		total += n
	stats["trees"] = total


func build_grass() -> void:
	var data: Resource = load(GRASS_DATA)
	var mesh: Mesh = data.get("mesh")
	var mat: Material = data.get("material")
	var chunk_size: float = float(data.get("size")) if data.get("size") != null else 50.0
	var max_scale: float = float(data.get("maxScale"))
	var render_end: float = float(data.get("renderEnd")) if data.get("renderEnd") != null else 100.0
	var layer: int = int(data.get("layer")) if data.get("layer") != null else 4
	var veg := group(content, "Vegetation")
	var holder := group(veg, "Grass")
	var nx: int = M.nx
	var nz: int = M.nz
	var sp: float = M.spacing
	var bounds := Rect2(-60, 120, 1180, 460)      # boundary plus a margin, layout metres
	var chunks := {}
	for j in nz:
		for i in nx:
			if CLS[j * nx + i] != 0:
				continue
			var x: float = float(M.x0) + i * sp
			var z: float = float(M.z0) + j * sp
			if not bounds.has_point(Vector2(x, z)):
				continue
			for k in 3:
				var px := x + rng.randf_range(-sp / 2.0, sp / 2.0)
				var pz := z + rng.randf_range(-sp / 2.0, sp / 2.0)
				var key := "%d_%d" % [int(floor(px / chunk_size)), int(floor(pz / chunk_size))]
				if not chunks.has(key):
					chunks[key] = []
				var h := ground(px, pz)
				var nrm := Vector3(ground(px - 1, pz) - ground(px + 1, pz), 2.0, ground(px, pz - 1) - ground(px, pz + 1)).normalized()
				var vx := Vector3.FORWARD.cross(nrm).normalized()
				var vz := vx.cross(nrm).normalized()
				var basis := Basis(vx, nrm, vz).rotated(nrm, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, max_scale))
				chunks[key].append(Transform3D(basis, Vector3(px - OX, h, pz - OZ)))
	var count := 0
	for key in chunks:
		var list: Array = chunks[key]
		var origin := Vector3.ZERO
		for xf in list:
			origin += (xf as Transform3D).origin
		origin /= list.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i]
			xf.origin -= origin
			mm.set_instance_transform(i, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = save_res(mm, "MM_Grass_%s.res" % key)
		if mat:
			mmi.material_override = mat
		mmi.layers = 1 << (layer - 1)
		mmi.visibility_range_end = render_end
		mmi.transform.origin = origin
		add(holder, mmi, "Chunk")
		count += list.size()
	stats["grass"] = count
