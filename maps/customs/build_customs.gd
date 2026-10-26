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
var COL: PackedByteArray
var footprints: Array = []    # Rect2 in layout metres around placed buildings (trees stay out)
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
	COL = FileAccess.get_file_as_bytes(dir.path_join("colors.u8"))
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

	load_swatches(dir)
	measure_door()
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
	build_dressing()
	build_set_pieces()
	log_step("buildings & props", t0)
	build_exits()
	build_border()
	build_killboxes()
	log_step("exits & border", t0)
	build_ai()
	log_step("ai points", t0)
	build_trees(dir)
	log_step("trees", t0)
	build_grass()
	log_step("grass", t0)
	bake_navmesh()
	log_step("navmesh", t0)

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
	var a2 := Transform3D(basis, pos) * asset_aabb(path)
	if a2.size.x * a2.size.z > 40.0:
		footprints.append(Rect2(a2.position.x + OX, a2.position.z + OZ, a2.size.x, a2.size.z).grow(3.0))
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
	shape.backface_collision = true   # solid from both sides, whatever the winding
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
		tex.keep_compressed_buffer = true   # without this nothing is saved
		tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		save_res(tex, "TX_Customs_Roads_%d.res" % t)
		var mat := base.duplicate() as ShaderMaterial
		mat.set_shader_parameter("roadMask", tex)
		save_res(mat, "MT_Customs_%d.tres" % t)

		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var tangents := PackedFloat32Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
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
				var ci := (j * nx + i) * 3
				colors.append(Color(COL[ci] / 255.0, COL[ci + 1] / 255.0, COL[ci + 2] / 255.0))
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
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, mat)
		check_winding(mesh, "terrain_%d" % t)
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
	# Smooth the centreline first: a wide ribbon folds over itself on bends
	# tighter than its half width, which flips those triangles.
	var pts := resample(chaikin(river.points, 4), 6.0)
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
			idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])   # clockwise from above
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
	check_winding(mesh, "water")
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
			"generated":
				build_generated(holder, b)
			"dorm":
				build_dorm(holder, b)
			"hall_ruin":
				build_hall_ruin(holder, b)
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
		# Snap to the true playable boundary (extracts sit on the edge in
		# Tarkov), face inward along the boundary normal, flag 1 m inside.
		var raw := v2(e.pos)
		var edge := _closest_boundary(raw)
		var on_edge: Vector2 = edge[0]
		var tangent: Vector2 = edge[1]
		var inward := tangent.orthogonal()
		if not inside_playable(on_edge + inward * 3.0):
			inward = -inward
		var p := on_edge + inward * 1.0
		stats["exit_snap_max_m"] = maxf(float(stats.get("exit_snap_max_m", 0.0)), raw.distance_to(on_edge))
		var to: String = e.to
		var n := "Transition_" + to
		if not e.has("spawn_for") or used.has(n):
			n = "Transition_%s_%s" % [to, String(e.name).replace(" ", "").replace("-", "")]
		used[n] = true
		var tr := instance(SCN_TRANSITION)
		# Face into the map: halfway between the edge normal and the map centre,
		# so arrivals look at Customs, not along the tape or into a fence.
		var face := (inward + (centre - p).normalized()).normalized()
		tr.transform = Transform3D(Basis(Vector3.UP, atan2(face.x, face.y)), W(p.x, p.y))
		tr.set("nextMap", to)
		tr.set("nextZone", "Area 05")
		tr.set("currentMap", "Customs")
		tr.set("time", 2.0 if to == "Outpost" else 1.0)
		add(g, tr, n)
		# Arrive well inside the map, never on the tape.
		var spawn_node: Node3D = tr.get_node("Spawn")
		var depth := 12.0
		while depth < 30.0 and (not inside_playable(p + face * depth) or boundary_distance(p + face * depth) < 10.0 or blocked(p + face * depth)):
			depth += 1.0
		spawn_node.position = Vector3(0, 0, depth)
		var sp2 := p + face * depth
		spawn_node.position.y = ground(sp2.x, sp2.y) - ground(p.x, p.y)
		tr.set("spawn", spawn_node)
		tr.set_meta("rtt_exit_name", String(e.name))
	stats["exits"] = L.exits.size()
	if L.has("preview_spawn"):
		var ps := v2(L.preview_spawn.pos)
		var look := v2(L.preview_spawn.look)
		var marker := Node3D.new()
		var d := Vector3(look.x - ps.x, 0.0, look.y - ps.y).normalized()
		marker.transform = Transform3D(Basis.looking_at(d, Vector3.UP), W(ps.x, ps.y, 0.1))
		add(content, marker, "Spawn_Preview")


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
	var cleared := 0
	for t in trees:
		var x := float(t[0])
		var z := float(t[1])
		var blocked := false
		for r in footprints:
			if (r as Rect2).has_point(Vector2(x, z)):
				blocked = true
				break
		if blocked:
			cleared += 1
			continue
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
	stats["trees_cleared_by_buildings"] = cleared


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


# ================================================================== generated buildings
# Customs' signature buildings, built from boxes with real openings and
# Vostok's own surface textures (cut into tileable swatches by textures.py).

const SHELVES := ["res://Assets/Shelf_Warehouse/Shelf_Warehouse_A.tscn", "res://Assets/Shelf_Warehouse/Shelf_Warehouse_B.tscn"]
const LOOT := ["res://Assets/Crate_Military/Crate_Military.tscn", "res://Assets/Crate_Wood/Crate_Wood.tscn", "res://Assets/Crate_Wood/Crate_Wood_Covered_A.tscn", "res://Assets/Crate_Special/Crate_Special.tscn", "res://Assets/Locker/Locker.tscn"]
const CLUTTER := ["res://Assets/Pallet/Pallet_Group.tscn", "res://Assets/Barrel_Metal/Barrel_Metal_Group_A.tscn", "res://Assets/Barrel_Metal/Barrel_Metal_Group_B.tscn", "res://Assets/Tire/Tire_Group.tscn", "res://Assets/Pile_Cardboard/Pile_Cardboard_A.tscn", "res://Assets/Debris/Metal/Debris_Metal_Pile_A.tscn", "res://Assets/Debris/Metal/Debris_Metal_Pile_B.tscn", "res://Assets/Debris/Wood/Debris_Wood_Pile_A.tscn", "res://Assets/Plywood/Plywood_A_Leaning.tscn", "res://Assets/Cable_Reel/Cable_Reel.tscn", "res://Assets/Slab_Concrete/Slab_Concrete_Group_A.tscn", "res://Assets/Pipe_Concrete/Pipe_Concrete_Group.tscn"]
const STYLE := {
	"brick_red": ["brick_red", "brick_red", "roof_tar"],
	"brick_grey": ["brick_grey", "brick_grey", "roof_tar"],
	"metal_rust": ["brick_grey", "metal_rust", "roof_metal"],
	"metal_red": ["concrete", "metal_red", "roof_metal"],
	"concrete": ["concrete", "concrete", "roof_tar"],
	"garages": ["brick_grey", "brick_grey", "roof_tar"],
}

var SW := {}
var _sw_mats := {}
var _batch := {}                      # material name -> SurfaceTool
var _col := PackedVector3Array()      # collision faces for the current batch
var _swatch_dir := ""


func load_swatches(dir: String) -> void:
	_swatch_dir = dir.path_join("swatches")
	if FileAccess.file_exists(_swatch_dir.path_join("swatches.json")):
		SW = JSON.parse_string(FileAccess.get_file_as_string(_swatch_dir.path_join("swatches.json")))


func png_texture(path: String, file: String) -> Texture2D:
	var img := Image.load_from_file(path)
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true   # without this nothing is saved
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.85)
	return save_res(tex, file)


func swatch(name: String) -> Material:
	if _sw_mats.has(name):
		return _sw_mats[name]
	var mat := StandardMaterial3D.new()
	var al := _swatch_dir.path_join(name + "_AL.png")
	if FileAccess.file_exists(al):
		mat.albedo_texture = png_texture(al, "TX_SW_%s_AL.res" % name)
	var nr := _swatch_dir.path_join(name + "_NR.png")
	if FileAccess.file_exists(nr):
		mat.normal_enabled = true
		mat.normal_texture = png_texture(nr, "TX_SW_%s_NR.res" % name)
	mat.roughness = 0.93
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 6.0
	var m: Array = SW.get(name, {}).get("metres", [4.0, 4.0])
	mat.uv1_scale = Vector3(1.0 / float(m[0]), 1.0 / float(m[1]), 1.0 / float(m[0]))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	save_res(mat, "MT_SW_%s.tres" % name)
	_sw_mats[name] = mat
	return mat


func batch_begin() -> void:
	_batch = {}
	_col = PackedVector3Array()


func _st(mat: String) -> SurfaceTool:
	if not _batch.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batch[mat] = st
	return _batch[mat]


func batch_box(mat: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY, collide := true) -> void:
	var st := _st(mat)
	var h := size / 2.0
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var faces := [[0, 3, 2, 1, Vector3(0, 0, -1)], [4, 5, 6, 7, Vector3(0, 0, 1)], [0, 4, 7, 3, Vector3(-1, 0, 0)],
		[1, 2, 6, 5, Vector3(1, 0, 0)], [3, 7, 6, 2, Vector3(0, 1, 0)], [0, 1, 5, 4, Vector3(0, -1, 0)]]
	for f in faces:
		var n: Vector3 = (basis * (f[4] as Vector3)).normalized()
		var q := [center + basis * (c[f[0]] as Vector3), center + basis * (c[f[1]] as Vector3), center + basis * (c[f[2]] as Vector3), center + basis * (c[f[3]] as Vector3)]
		# Godot front faces are clockwise as seen from outside.
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(Vector2.ZERO)
			st.add_vertex(q[k])
			if collide:
				_col.append(q[k])


func batch_tri(mat: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var st := _st(mat)
	# Both sides: clockwise [a, b, c] faces along -n, [a, c, b] along +n.
	var n := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_normal(-n)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(v)
	for v in [a, c, b]:
		st.set_normal(n)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(v)
	_col.append_array([a, b, c])


func batch_commit(parent: Node, n: String, surface := "Concrete") -> void:
	var holder := Node3D.new()
	add(parent, holder, n)
	for mat in _batch:
		var st: SurfaceTool = _batch[mat]
		var mesh := st.commit()
		check_winding(mesh, "%s/%s/%s" % [parent.name, n, mat])
		var mi := MeshInstance3D.new()
		mi.mesh = save_res(mesh, "MS_%s_%s_%s.res" % [parent.name, n, mat])
		mi.set_surface_override_material(0, swatch(mat))
		add(holder, mi, "Mesh_" + mat)
	if _col.size() > 0:
		static_trimesh(holder, _col, "StaticBody3D", surface)
	_batch = {}
	_col = PackedVector3Array()


# A straight wall from corner a along dir with rectangular openings.
# openings: [[offset, width, bottom, top], ...] in metres along the wall.
func wall(a: Vector3, dir: Vector3, inward: Vector3, length: float, height: float, thick: float, openings: Array, bands: Array) -> void:
	var xs := [0.0, length]
	for o in openings:
		xs.append(clampf(float(o[0]), 0.0, length))
		xs.append(clampf(float(o[0]) + float(o[1]), 0.0, length))
	xs.sort()
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	for i in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 0.01:
			continue
		var gaps: Array = []
		for o in openings:
			if float(o[0]) <= x0 + 0.001 and float(o[0]) + float(o[1]) >= x1 - 0.001:
				gaps.append([float(o[2]), float(o[3])])
		gaps.sort_custom(func(p, q): return p[0] < q[0])
		var spans: Array = []
		var y := 0.0
		for g in gaps:
			if float(g[0]) > y:
				spans.append([y, float(g[0])])
			y = maxf(y, float(g[1]))
		if y < height:
			spans.append([y, height])
		for sp in spans:
			var parts: Array = []
			var lo := 0.0
			for bd in bands:
				var hi := float(bd[0])
				parts.append([maxf(float(sp[0]), lo), minf(float(sp[1]), hi), bd[1]])
				lo = hi
			for part in parts:
				if float(part[1]) - float(part[0]) < 0.01:
					continue
				var mid_x := (x0 + x1) / 2.0
				var mid_y := (float(part[0]) + float(part[1])) / 2.0
				var centre := a + dir * mid_x + Vector3.UP * mid_y + inward * (thick / 2.0)
				batch_box(String(part[2]), centre, Vector3(x1 - x0, float(part[1]) - float(part[0]), thick), basis)


func wall_openings(length: float, height: float, long_side: bool, style: String) -> Array:
	var out: Array = []
	if style == "garages":
		var n := int(length / 4.0)
		for k in n:
			out.append([k * 4.0 + 0.6, 2.8, 0.0, 2.6, "garage"])
		return out
	if long_side:
		out.append([length * 0.25, _door_w, 0.0, _door_h, "door"])
		var rows := [minf(height - 2.5, 2.6)]
		if height >= 12.0:
			rows.append(height - 4.0)
		for r in rows:
			var n := int((length - 4.0) / 6.0)
			for k in n:
				var x := 3.0 + k * 6.0
				if absf(x - length * 0.25) < 3.0 and float(r) < 3.0:
					continue
				out.append([x, 2.2, float(r), float(r) + 1.4, "window"])
	else:
		var w := minf(6.0, length * 0.35)
		out.append([(length - w) / 2.0, w, 0.0, minf(5.5, height - 1.5), "bay"])
		if height >= 8.0:
			out.append([length * 0.15, 2.0, height - 3.0, height - 1.6, "window"])
			out.append([length * 0.85 - 2.0, 2.0, height - 3.0, height - 1.6, "window"])
	return out


func build_generated(holder: Node, b: Dictionary) -> void:
	var r: Array = b.rect
	var style: String = b.get("style", "concrete")
	var mats: Array = STYLE.get(style, STYLE.concrete)
	var height := float(b.height)
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := float(r[2])
	var z1 := float(r[3])
	var floor_y := ground((x0 + x1) / 2.0, (z0 + z1) / 2.0) + 0.05
	var thick := 0.4
	var bands := [[0.55, "concrete"], [3.2, mats[0]], [height + 1.0, mats[1]]] if style != "garages" else [[0.4, "concrete"], [height + 1.0, mats[0]]]
	var w := x1 - x0
	var d := z1 - z0
	var long_x := w >= d
	batch_begin()
	# Walls: north (along +x), east (+z), south (-x), west (-z).
	var sides := [[Vector3(x0 - OX, floor_y, z0 - OZ), Vector3.RIGHT, Vector3.BACK, w, long_x],
		[Vector3(x1 - OX, floor_y, z0 - OZ), Vector3.BACK, Vector3.LEFT, d, not long_x],
		[Vector3(x1 - OX, floor_y, z1 - OZ), Vector3.LEFT, Vector3.FORWARD, w, long_x],
		[Vector3(x0 - OX, floor_y, z1 - OZ), Vector3.FORWARD, Vector3.RIGHT, d, not long_x]]
	var placed_openings: Array = []
	for sd in sides:
		var ops := wall_openings(float(sd[3]), height, bool(sd[4]), style)
		wall(sd[0], sd[1], sd[2], float(sd[3]), height, thick, ops, bands)
		for o in ops:
			placed_openings.append([sd[0], sd[1], sd[2], o])
			_detail_opening(sd[0], sd[1], sd[2], thick, o)
	_detail_roof_edges(x0, z0, x1, z1, floor_y + height)
	var cx := (x0 + x1) / 2.0 - OX
	var cz := (z0 + z1) / 2.0 - OZ
	batch_box("slab", Vector3(cx, floor_y - 0.15, cz), Vector3(w, 0.3, d))
	var top := floor_y + height
	if String(b.get("roof", "flat")) == "gable":
		var span := d if long_x else w
		var run := w if long_x else d
		var pitch := deg_to_rad(13.0)
		var rise := span / 2.0 * tan(pitch)
		var axis := Vector3.RIGHT if long_x else Vector3.BACK
		var across := Vector3.BACK if long_x else Vector3.RIGHT
		for s in [-1.0, 1.0]:
			# Tilt each half so it falls away from the ridge.
			var basis := Basis(axis, float(s) * pitch) if long_x else Basis(axis, -float(s) * pitch)
			var centre := Vector3(cx, top + rise / 2.0, cz) + across * (float(s) * span / 4.0)
			var slope := span / 2.0 / cos(pitch) + 0.5
			var size := Vector3(run + 0.8, 0.25, slope) if long_x else Vector3(slope, 0.25, run + 0.8)
			batch_box(mats[2], centre, size, basis)
		for e in [-1.0, 1.0]:
			var end := Vector3(cx, top, cz) + axis * (float(e) * (run / 2.0 - thick / 2.0))
			batch_tri(mats[1], end - across * span / 2.0, end + across * span / 2.0, end + Vector3.UP * rise)
	else:
		batch_box(mats[2], Vector3(cx, top + 0.15, cz), Vector3(w, 0.3, d))
		batch_box(mats[0], Vector3(cx, top + 0.6, z0 - OZ + 0.15), Vector3(w, 0.9, 0.3))
		batch_box(mats[0], Vector3(cx, top + 0.6, z1 - OZ - 0.15), Vector3(w, 0.9, 0.3))
		batch_box(mats[0], Vector3(x0 - OX + 0.15, top + 0.6, cz), Vector3(0.3, 0.9, d))
		batch_box(mats[0], Vector3(x1 - OX - 0.15, top + 0.6, cz), Vector3(0.3, 0.9, d))
	if style != "garages" and minf(w, d) > 16.0:
		var nx := int(w / 7.0)
		var nz := int(d / 7.0)
		for i in range(1, nx):
			for j in range(1, nz):
				batch_box("metal_rust", Vector3(x0 + i * w / nx - OX, floor_y + height / 2.0, z0 + j * d / nz - OZ), Vector3(0.45, height, 0.45))
	if style != "garages" and height >= 9.0 and minf(w, d) >= 14.0:
		var deck := floor_y + 4.5
		if long_x:
			batch_box("metal_rust", Vector3(cx, deck, z0 - OZ + thick + 1.3), Vector3(w - 2.0 * thick - 0.2, 0.2, 2.4))
			_stairs(Vector3(x0 - OX + 3.0, floor_y, z0 - OZ + thick + 3.6), Vector3.RIGHT, 4.5)
		else:
			batch_box("metal_rust", Vector3(x0 - OX + thick + 1.3, deck, cz), Vector3(2.4, 0.2, d - 2.0 * thick - 0.2))
			_stairs(Vector3(x0 - OX + thick + 3.6, floor_y, z0 - OZ + 3.0), Vector3.BACK, 4.5)
	batch_commit(holder, "Structure", "Concrete")
	for po in placed_openings:
		_place_opening_props(holder, po[0], po[1], po[2], thick, po[3])
	if String(b.get("roof", "flat")) != "gable" and style != "garages":
		_roof_units(holder, x0, z0, x1, z1, floor_y + height + 0.3)
	var area := Area3D.new()
	area.collision_layer = 512
	area.collision_mask = 0
	area.monitoring = false
	area.set_script(load("res://Scripts/Area.gd"))
	area.set("type", "Indoor")
	area.transform.origin = Vector3(cx, floor_y + height / 2.0, cz)
	add(holder, area, "Area")
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(w - 0.8, height, d - 0.8)
	acs.shape = abox
	add(area, acs, "CollisionShape3D")
	footprints.append(Rect2(x0, z0, w, d).grow(3.0))
	_dress_interior(holder, x0, z0, x1, z1, floor_y, style)


func _stairs(start: Vector3, dir: Vector3, rise: float) -> void:
	var steps := int(rise / 0.25)
	var side := dir.cross(Vector3.UP).normalized()
	for k in steps:
		var c := start + dir * (k * 0.32) + Vector3.UP * (k * 0.25 + 0.125)
		batch_box("metal_rust", c, dir.abs() * 0.34 + side.abs() * 1.1 + Vector3(0, 0.25, 0), Basis.IDENTITY, false)
	var length := steps * 0.32
	var mid := start + dir * (length / 2.0) + Vector3.UP * (rise / 2.0)
	var ang := atan2(rise, length)
	# Sloped collider: rotate about the side axis so the slab climbs along dir.
	var basis := Basis(side, -ang)
	var slab := Vector3(1.1, 0.05, sqrt(length * length + rise * rise))
	var b := Basis.looking_at(dir, Vector3.UP)
	batch_box("metal_rust", mid, slab, Basis(b.x, ang) * b, true)


func _dress_interior(holder: Node, x0: float, z0: float, x1: float, z1: float, floor_y: float, style: String) -> void:
	if style == "garages":
		return
	var inner := Rect2(x0 + 2.0, z0 + 2.0, x1 - x0 - 4.0, z1 - z0 - 4.0)
	var area := inner.get_area()
	var n_loot := clampi(int(area / 140.0), 1, 8)
	var n_clutter := clampi(int(area / 90.0), 2, 12)
	for k in n_loot + n_clutter:
		var path: String = LOOT[rng.randi() % LOOT.size()] if k < n_loot else CLUTTER[rng.randi() % CLUTTER.size()]
		var x := rng.randf_range(inner.position.x + 1.0, inner.end.x - 1.0)
		var z := rng.randf_range(inner.position.y + 1.0, inner.end.y - 1.0)
		var n := instance(path)
		n.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x - OX, floor_y, z - OZ))
		add(holder, n)
	var long_x := (x1 - x0) >= (z1 - z0)
	var length := (x1 - x0) if long_x else (z1 - z0)
	var count := int(length * 0.5 / 4.0)
	for k in count:
		var t := 3.0 + k * 4.0
		# Centre each shelf on its measured footprint so it stays inside the wall.
		var sa := asset_aabb(SHELVES[k % 2])
		var depth := minf(sa.size.x, sa.size.z)
		var p := Vector2(x0 + t, z1 - 0.6 - depth / 2.0) if long_x else Vector2(x1 - 0.6 - depth / 2.0, z0 + t)
		var yaw := 0.0 if sa.size.x >= sa.size.z else PI / 2.0
		if not long_x:
			yaw += PI / 2.0
		place(SHELVES[k % 2], holder, p.x, p.y, yaw)


# ================================================================== dressing

func build_dressing() -> void:
	var g := group(content, "Dressing")
	var fence := "res://Assets/Fence_PO2/Fence_PO2.tscn"
	var fa := asset_aabb(fence)
	var panel_len := maxf(fa.size.x, fa.size.z)
	var panel_along_x := fa.size.x >= fa.size.z
	var walls := group(g, "ConcreteFences")
	for wdef in L.get("walls", []):
		var pts: Array = wdef.points
		var gates: Array = wdef.get("gates", [])
		for i in pts.size() - 1:
			var a := v2(pts[i])
			var b := v2(pts[i + 1])
			var len := a.distance_to(b)
			var dir := (b - a) / len
			var n := int(len / panel_len)
			for k in n:
				var mid := a + dir * ((k + 0.5) * panel_len)
				var skip := false
				for gt in gates:
					if mid.distance_to(Vector2(float(gt[0]), float(gt[1]))) < float(gt[2]) / 2.0:
						skip = true
				if skip or rng.randf() < 0.04:
					continue
				var yaw := yaw_of(dir) if panel_along_x else yaw_of(dir) + PI / 2.0
				place(fence, walls, mid.x, mid.y, yaw)
	var pipes := group(g, "Pipelines")
	for pdef in L.get("pipelines", []):
		var pts := resample(pdef.points, 20.0)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if a.distance_to(b) < 2.0:
				continue
			var mid := (a + b) / 2.0
			var path := "res://Assets/Pipeline/Pipeline_C_Overpass.tscn" if _near_road(mid) else "res://Assets/Pipeline/Pipeline_C.tscn"
			if bool(pdef.get("small", false)):
				path = "res://Assets/Pipeline/Pipeline_A.tscn"
			var from := W(a.x, a.y)
			var to := W(b.x, b.y)
			to.y = from.y
			var n := instance(path)
			n.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP).scaled(Vector3(1, 1, a.distance_to(b) / 20.0)), from)
			add(pipes, n)
	var cont := "res://Assets/Container_Shipping/Container_Shipping.tscn"
	var conts := group(g, "Containers")
	for cdef in L.get("containers", []):
		var c := v2(cdef.center)
		var yaw := rng.randf() * PI
		var dir := Vector2(cos(yaw), -sin(yaw))
		var side := Vector2(-dir.y, dir.x)
		for k in int(cdef.count):
			var row := k % 3
			var layer := 1 if k >= 3 and rng.randf() < 0.5 else 0
			var p := c + side * (row * 2.6) + dir * rng.randf_range(-0.6, 0.6)
			place(cont, conts, p.x, p.y, yaw + rng.randf_range(-0.06, 0.06), layer * 2.6)
			if layer == 0:
				cover_objects.append([p, 2.0])
	var cars := ["res://Assets/Vehicles/Lada/Lada_White.tscn", "res://Assets/Vehicles/Lada/Lada_Blue.tscn", "res://Assets/Vehicles/Lada/Lada_Red.tscn", "res://Assets/Vehicles/Volvo/Volvo.tscn", "res://Assets/Vehicles/Nissan/Nissan.tscn", "res://Assets/Vehicles/PAZ/PAZ.tscn", "res://Assets/Vehicles/Ural/Ural.tscn", "res://Assets/Vehicles/Truck_Trailers/Truck_Trailer_Cargo/Truck_Trailer_Cargo.tscn", "res://Assets/Vehicles/Transporter/Transporter.tscn"]
	var wrecks := group(g, "Vehicles")
	for r in L.roads:
		if r.get("surface", "") == "dirt":
			continue
		var pts := resample(r.points, 32.0)
		for i in range(1, pts.size() - 1):
			if rng.randf() > 0.42:
				continue
			var p: Vector2 = pts[i]
			var dir: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
			var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var q := p + side * (float(r.width) / 2.0 - rng.randf_range(0.5, 2.0))
			if bridge_height(q) > -INF:
				continue
			place(cars[rng.randi() % cars.size()], wrecks, q.x, q.y, yaw_of(dir) + PI / 2.0 + rng.randf_range(-0.35, 0.35))
			cover_objects.append([q, 1.8])
	var yard := group(g, "Clutter")
	for b in L.buildings:
		if b.kind != "generated":
			continue
		var r: Array = b.rect
		var perim := 2.0 * ((float(r[2]) - float(r[0])) + (float(r[3]) - float(r[1])))
		for k in int(perim / 12.0):
			if rng.randf() > 0.55:
				continue
			var t := rng.randf()
			var edge := rng.randi() % 4
			var x := lerpf(float(r[0]), float(r[2]), t)
			var z := lerpf(float(r[1]), float(r[3]), t)
			match edge:
				0: z = float(r[1]) - 2.0
				1: z = float(r[3]) + 2.0
				2: x = float(r[0]) - 2.0
				3: x = float(r[2]) + 2.0
			if _near_road(Vector2(x, z)):
				continue
			place(CLUTTER[rng.randi() % CLUTTER.size()], yard, x, z, rng.randf() * TAU)
	var bar := group(g, "Barriers")
	for p in [[118, 336], [124, 340], [1022, 300], [1018, 306], [690, 382], [517, 432]]:
		place("res://Assets/Barrier_Construction/Barrier_Construction.tscn", bar, float(p[0]), float(p[1]), rng.randf_range(0, PI))
	if L.has("crane"):
		build_crane(g)


func _near_road(p: Vector2) -> bool:
	for r in L.roads:
		var pts: Array = r.points
		for i in pts.size() - 1:
			var a := v2(pts[i])
			var b := v2(pts[i + 1])
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if p.distance_to(a + ab * t) < float(r.width) / 2.0 + 1.0:
				return true
	return false


# Tower crane over the scav base: lattice mast, jib, counter-jib and cab.
func build_crane(parent: Node) -> void:
	if not L.has("crane"):
		return
	var cr: Dictionary = L.crane
	var p := v2(cr.pos)
	var base := W(p.x, p.y)
	var h := float(cr.height)
	batch_begin()
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			batch_box("metal_red", base + Vector3(float(cx) * 0.9, h / 2.0, float(cz) * 0.9), Vector3(0.22, h, 0.22))
	var y := 0.0
	while y < h:
		for s in 4:
			var rot := Basis(Vector3.UP, s * PI / 2.0)
			batch_box("metal_red", base + rot * Vector3(0, 0, 0.9) + Vector3(0, y + 1.5, 0), Vector3(2.5, 0.12, 0.12), rot * Basis(Vector3.BACK, deg_to_rad(45.0)), false)
		y += 3.0
	var heading := deg_to_rad(float(cr.heading))
	var dir := Vector3(sin(heading), 0, cos(heading))
	var jib := float(cr.jib)
	var jb := Basis.looking_at(dir, Vector3.UP)
	batch_box("metal_red", base + Vector3(0, h + 0.6, 0) + dir * (jib / 2.0), Vector3(1.2, 1.2, jib), jb, false)
	batch_box("metal_red", base + Vector3(0, h + 0.6, 0) - dir * 6.0, Vector3(1.2, 1.0, 12.0), jb, false)
	batch_box("concrete", base + Vector3(0, h - 0.4, 0) - dir * 10.5, Vector3(3.0, 2.6, 2.4), jb, false)
	batch_box("metal_red", base + Vector3(0, h + 3.5, 0), Vector3(0.5, 6.0, 0.5), Basis.IDENTITY, false)
	batch_box("brick_grey", base + Vector3(1.6, h - 1.5, 0), Vector3(2.0, 2.4, 2.0), Basis.IDENTITY, false)
	batch_commit(parent, "TowerCrane", "Metal")



# ------------------------------------------------------------------ building details

var _door_w := 1.3
var _door_h := 2.3
const DOOR_SCENE := "res://Modular/Doors/Door_Metal_L.tscn"
const ROOF_UNITS := ["res://Assets/Airduct/Airduct_Vent.tscn", "res://Assets/Airduct/Airduct_Intake.tscn", "res://Assets/Airduct/Airduct_Controller.tscn"]


func measure_door() -> void:
	if ResourceLoader.exists(DOOR_SCENE):
		var a := asset_aabb(DOOR_SCENE)
		_door_w = clampf(a.size.x + 0.08, 0.9, 1.8)
		_door_h = clampf(a.size.y + 0.05, 2.0, 2.6)
		stats["door_size"] = Vector2(_door_w, _door_h)


func _wp(a: Vector3, dir: Vector3, inward: Vector3, x: float, y: float, depth: float) -> Vector3:
	return a + dir * x + Vector3.UP * y + inward * depth


# Frames, mullions, sills and roll-up doors, drawn into the current batch.
func _detail_opening(a: Vector3, dir: Vector3, inward: Vector3, thick: float, o: Array) -> void:
	var kind: String = o[4] if o.size() > 4 else "window"
	var off := float(o[0])
	var ow := float(o[1])
	var ob := float(o[2])
	var ot := float(o[3])
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	var fw := 0.12
	var hd := thick / 2.0
	match kind:
		"window":
			batch_box("metal_rust", _wp(a, dir, inward, off + ow / 2.0, ob + fw / 2.0, hd), Vector3(ow, fw, 0.18), basis)
			batch_box("metal_rust", _wp(a, dir, inward, off + ow / 2.0, ot - fw / 2.0, hd), Vector3(ow, fw, 0.18), basis)
			batch_box("metal_rust", _wp(a, dir, inward, off + fw / 2.0, (ob + ot) / 2.0, hd), Vector3(fw, ot - ob, 0.18), basis)
			batch_box("metal_rust", _wp(a, dir, inward, off + ow - fw / 2.0, (ob + ot) / 2.0, hd), Vector3(fw, ot - ob, 0.18), basis)
			batch_box("metal_rust", _wp(a, dir, inward, off + ow / 2.0, (ob + ot) / 2.0, hd), Vector3(0.07, ot - ob, 0.1), basis, false)
			batch_box("metal_rust", _wp(a, dir, inward, off + ow / 2.0, ob + (ot - ob) * 0.62, hd), Vector3(ow, 0.07, 0.1), basis, false)
			batch_box("concrete", _wp(a, dir, inward, off + ow / 2.0, ob - 0.06, -0.08), Vector3(ow + 0.2, 0.12, 0.3), basis)
		"door":
			batch_box("metal_rust", _wp(a, dir, inward, off - 0.06, ot / 2.0, hd), Vector3(0.12, ot + 0.1, thick + 0.06), basis)
			batch_box("metal_rust", _wp(a, dir, inward, off + ow + 0.06, ot / 2.0, hd), Vector3(0.12, ot + 0.1, thick + 0.06), basis)
			batch_box("metal_rust", _wp(a, dir, inward, off + ow / 2.0, ot + 0.06, hd), Vector3(ow + 0.24, 0.12, thick + 0.06), basis)
			batch_box("concrete", _wp(a, dir, inward, off + ow / 2.0, 0.08, -0.6), Vector3(ow + 1.0, 0.16, 1.2), basis)
		"bay", "garage":
			# Roll-up doors: some open, some half way, garages sometimes shut.
			var roll := rng.randf()
			var shut := 0.0
			if kind == "garage":
				shut = 1.0 if roll < 0.45 else (0.5 if roll < 0.75 else 0.0)
			else:
				shut = 0.0 if roll < 0.4 else rng.randf_range(0.25, 0.5)
			var hgt := ot - ob
			if shut > 0.0:
				var ph := hgt * shut
				batch_box("metal_rust", _wp(a, dir, inward, off + ow / 2.0, ot - ph / 2.0, thick * 0.7), Vector3(ow, ph, 0.08), basis, shut >= 1.0)
			batch_box("metal_rust", _wp(a, dir, inward, off + ow / 2.0, ot + 0.25, thick * 0.7), Vector3(ow + 0.3, 0.5, 0.45), basis, false)
			batch_box("concrete", _wp(a, dir, inward, off - 0.12, hgt / 2.0, hd), Vector3(0.24, hgt, thick + 0.1), basis)
			batch_box("concrete", _wp(a, dir, inward, off + ow + 0.12, hgt / 2.0, hd), Vector3(0.24, hgt, thick + 0.1), basis)


# Openable Vostok doors in the man-door openings.
func _place_opening_props(holder: Node, a: Vector3, dir: Vector3, inward: Vector3, thick: float, o: Array) -> void:
	var kind: String = o[4] if o.size() > 4 else ""
	if kind != "door" or not ResourceLoader.exists(DOOR_SCENE):
		return
	var centre := _wp(a, dir, inward, float(o[0]) + float(o[1]) / 2.0, 0.0, thick / 2.0)
	var n := instance(DOOR_SCENE)
	var basis := Basis(Vector3.UP, yaw_of(Vector2(dir.x, dir.z)))
	var aa := asset_aabb(DOOR_SCENE)
	n.transform = Transform3D(basis, centre - basis * Vector3(aa.get_center().x, 0.0, aa.get_center().z))
	add(holder, n)


# Eave trim around the roof line and downpipes at the corners.
func _detail_roof_edges(x0: float, z0: float, x1: float, z1: float, top: float) -> void:
	var cx := (x0 + x1) / 2.0 - OX
	var cz := (z0 + z1) / 2.0 - OZ
	var w := x1 - x0
	var d := z1 - z0
	batch_box("metal_rust", Vector3(cx, top - 0.15, z0 - OZ - 0.05), Vector3(w + 0.3, 0.3, 0.15), Basis.IDENTITY, false)
	batch_box("metal_rust", Vector3(cx, top - 0.15, z1 - OZ + 0.05), Vector3(w + 0.3, 0.3, 0.15), Basis.IDENTITY, false)
	batch_box("metal_rust", Vector3(x0 - OX - 0.05, top - 0.15, cz), Vector3(0.15, 0.3, d + 0.3), Basis.IDENTITY, false)
	batch_box("metal_rust", Vector3(x1 - OX + 0.05, top - 0.15, cz), Vector3(0.15, 0.3, d + 0.3), Basis.IDENTITY, false)
	var floor_y := ground((x0 + x1) / 2.0, (z0 + z1) / 2.0)
	for c in [[x0, z0, -1.0, -1.0], [x1, z0, 1.0, -1.0], [x1, z1, 1.0, 1.0], [x0, z1, -1.0, 1.0]]:
		var px := float(c[0]) - OX + float(c[2]) * 0.18
		var pz := float(c[1]) - OZ + float(c[3]) * 0.18
		batch_box("metal_rust", Vector3(px, (floor_y + top) / 2.0, pz), Vector3(0.12, top - floor_y, 0.12), Basis.IDENTITY, false)


func _roof_units(holder: Node, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var area := (x1 - x0) * (z1 - z0)
	for k in clampi(int(area / 220.0), 1, 6):
		var path: String = ROOF_UNITS[rng.randi() % ROOF_UNITS.size()]
		if not ResourceLoader.exists(path):
			continue
		var x := rng.randf_range(x0 + 3.0, x1 - 3.0)
		var z := rng.randf_range(z0 + 3.0, z1 - 3.0)
		var n := instance(path)
		n.transform = Transform3D(Basis(Vector3.UP, (rng.randi() % 4) * PI / 2.0), Vector3(x - OX, y, z - OZ))
		add(holder, n)



# ================================================================== dorms
# Tarkov-style dormitory: long block, central corridor with rooms both sides,
# switchback stairwells at both ends, roof access, furnished rooms.

const FLOOR_H := 3.2
const WOOD_DOOR := "res://Modular/Doors/Door_Wood_L.tscn"
const ROOM_SETS := [
	["res://Assets/Bed_Civilian/Bed_Civilian.tscn", "res://Assets/Nightstand/Nightstand.tscn", "res://Assets/Cabinet_Wood/Cabinet_Wood.tscn", "res://Assets/Table_Round/Table_Round.tscn"],
	["res://Assets/Bed_Frame/Bed_Frame.tscn", "res://Assets/Mattress/Mattress.tscn", "res://Assets/Locker/Locker.tscn", "res://Assets/Chair_School/Chair_School_Fallen.tscn"],
	["res://Assets/Sofa_Leather/Sofa_Leather.tscn", "res://Assets/Television/Television.tscn", "res://Assets/Bookshelf/Bookshelf.tscn", "res://Assets/Carpet/Carpet_Rag.tscn"],
	["res://Assets/Fridge/Fridge.tscn", "res://Assets/Stove/Stove.tscn", "res://Assets/Table_Kitchen/Table_Kitchen.tscn", "res://Assets/Cupboard/Cupboard.tscn"],
	["res://Assets/Bed_Civilian/Bed_Civilian.tscn", "res://Assets/Cabinet_Office/Cabinet_Office.tscn", "res://Assets/Table_Office/Table_Office.tscn", "res://Assets/Chair_Office/Chair_Office.tscn"],
]


# Local dorm frame: u along the long axis (0..L), v across (0..W).
var _d_origin := Vector3.ZERO
var _d_u := Vector3.BACK
var _d_v := Vector3.RIGHT


func _dp(u: float, v: float, y: float) -> Vector3:
	return _d_origin + _d_u * u + _d_v * v + Vector3.UP * y


func _dbox(mat: String, u0: float, v0: float, y0: float, u1: float, v1: float, y1: float, collide := true) -> void:
	# Local u/v map onto world x/z, so boxes stay axis aligned.
	var c := _dp((u0 + u1) / 2.0, (v0 + v1) / 2.0, (y0 + y1) / 2.0)
	var su := absf(u1 - u0)
	var sv := absf(v1 - v0)
	var size := Vector3(sv, absf(y1 - y0), su) if _d_u == Vector3.BACK else Vector3(su, absf(y1 - y0), sv)
	batch_box(mat, c, size, Basis.IDENTITY, collide)


func _interior_bands(floors: int) -> Array:
	var out: Array = []
	for f in floors:
		out.append([f * FLOOR_H + 1.45, "paint_green"])
		out.append([(f + 1) * FLOOR_H, "plaster"])
	out.append([floors * FLOOR_H + 2.0, "plaster"])
	return out


func build_dorm(holder: Node, b: Dictionary) -> void:
	var r: Array = b.rect
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := float(r[2])
	var z1 := float(r[3])
	var floors := int(b.get("floors", 3))
	var along_z := (z1 - z0) >= (x1 - x0)
	var L := (z1 - z0) if along_z else (x1 - x0)
	var Wd := (x1 - x0) if along_z else (z1 - z0)
	var base_y := ground((x0 + x1) / 2.0, (z0 + z1) / 2.0) + 0.05
	_d_origin = Vector3(x0 - OX, base_y, z0 - OZ)
	_d_u = Vector3.BACK if along_z else Vector3.RIGHT
	_d_v = Vector3.RIGHT if along_z else Vector3.BACK
	var H := floors * FLOOR_H
	var ext := 0.35
	var inn := 0.15
	var cw := 2.2                         # corridor width
	var c0 := Wd / 2.0 - cw / 2.0
	var c1 := Wd / 2.0 + cw / 2.0
	var stair_len := 5.0
	var room_w := 3.7
	var rooms_len := L - 2.0 * stair_len
	var n_rooms := int(rooms_len / room_w)
	room_w = rooms_len / n_rooms
	# Stair core (local to each end zone, u measured from the building end):
	# flight A climbs along the long axis in lane v 0.3..2.3, a landing spans
	# both lanes, flight B returns in lane v 2.5..4.5 and arrives on the strip
	# u < 1.0, which joins the corridor along v > 4.5.
	var hole := Rect2(1.0, 0.3, 3.3, 4.2)     # u, v, size_u, size_v
	var door_w := 1.0
	if ResourceLoader.exists(WOOD_DOOR):
		door_w = clampf(asset_aabb(WOOD_DOOR).size.x + 0.06, 0.8, 1.3)

	batch_begin()
	# ---- exterior walls (brick, concrete floor bands)
	var ext_bands: Array = [[0.5, "concrete"]]
	for f in floors:
		ext_bands.append([f * FLOOR_H + FLOOR_H - 0.25, "brick_grey"])
		ext_bands.append([(f + 1) * FLOOR_H, "concrete"])
	ext_bands.append([H + 1.0, "brick_grey"])
	var long_ops: Array = []
	for f in floors:
		for k in n_rooms:
			var uc := stair_len + (k + 0.5) * room_w
			long_ops.append([uc - 0.75, 1.5, f * FLOOR_H + 0.9, f * FLOOR_H + 2.4, "window"])
		long_ops.append([1.2, 1.2, f * FLOOR_H + FLOOR_H / 2.0 + 0.6, f * FLOOR_H + FLOOR_H / 2.0 + 1.8, "window"])
		long_ops.append([L - 2.4, 1.2, f * FLOOR_H + FLOOR_H / 2.0 + 0.6, f * FLOOR_H + FLOOR_H / 2.0 + 1.8, "window"])
	var mid_door := [L / 2.0 - 0.8, 1.6, 0.0, 2.4, "door2"]
	var end_ops: Array = [[Wd / 2.0 - 0.8, 1.6, 0.0, 2.4, "door2"]]
	for f in range(1, floors):
		end_ops.append([Wd / 2.0 - 0.7, 1.4, f * FLOOR_H + 0.9, f * FLOOR_H + 2.3, "window"])
	var side_a_ops := long_ops.duplicate()
	var side_b_ops := long_ops.duplicate()
	side_b_ops.append(mid_door)
	# Walls are laid in the local frame: side A at v=0, side B at v=W, ends at u=0 and u=L.
	var A0 := _dp(0, 0, 0)
	wall(A0, _d_u, _d_v, L, H + 0.9, ext, side_a_ops, ext_bands)
	wall(_dp(L, Wd, 0), -_d_u, -_d_v, L, H + 0.9, ext, _mirror_ops(side_b_ops, L), ext_bands)
	wall(_dp(0, Wd, 0), -_d_v, _d_u, Wd, H + 0.9, ext, _mirror_ops(end_ops, Wd), ext_bands)
	wall(_dp(L, 0, 0), _d_v, -_d_u, Wd, H + 0.9, ext, end_ops, ext_bands)
	for o in side_a_ops:
		_detail_opening(A0, _d_u, _d_v, ext, o)
	for o in _mirror_ops(side_b_ops, L):
		_detail_opening(_dp(L, Wd, 0), -_d_u, -_d_v, ext, o)
	for o in end_ops:
		_detail_opening(_dp(L, 0, 0), _d_v, -_d_u, ext, o)
	for o in _mirror_ops(end_ops, Wd):
		_detail_opening(_dp(0, Wd, 0), -_d_v, _d_u, ext, o)
	# ---- corridor walls with a door per room per floor
	var ib := _interior_bands(floors)
	var corr_ops: Array = []
	for f in floors:
		for k in n_rooms:
			var uc := stair_len + (k + 0.5) * room_w
			corr_ops.append([uc - stair_len - door_w / 2.0, door_w, f * FLOOR_H, f * FLOOR_H + 2.15, "room_door"])
	wall(_dp(stair_len, c0, 0), _d_u, -_d_v, rooms_len, H, inn, corr_ops, ib)
	wall(_dp(stair_len, c1, 0), _d_u, _d_v, rooms_len, H, inn, corr_ops, ib)
	# ---- partitions between rooms, and room-zone end walls
	for k in range(0, n_rooms + 1):
		var u := stair_len + k * room_w
		wall(_dp(u, ext + 0.05, 0), _d_v, _d_u, c0 - ext - 0.05, H, inn, [], ib)
		wall(_dp(u, c1, 0), _d_v, _d_u, Wd - c1 - ext - 0.05, H, inn, [], ib)
	# Painted inner skin on the outer walls (same openings as the brick).
	var skin := 0.04
	wall(_dp(0, ext, 0), _d_u, _d_v, L, H, skin, side_a_ops, ib)
	wall(_dp(L, Wd - ext, 0), -_d_u, -_d_v, L, H, skin, _mirror_ops(side_b_ops, L), ib)
	wall(_dp(ext, Wd, 0), -_d_v, _d_u, Wd, H, skin, _mirror_ops(end_ops, Wd), ib)
	wall(_dp(L - ext, 0, 0), _d_v, -_d_u, Wd, H, skin, end_ops, ib)
	# ---- floors, ceilings and roof (with stair openings)
	for f in floors + 1:
		var y := f * FLOOR_H
		var mat := "tiles" if f == 0 else ("roof_tar" if f == floors else "parquet")
		_dbox(mat, stair_len, 0, y - 0.25, L - stair_len, Wd, y)
		for e in 2:
			var solid := f == 0 or (f == floors and e == 1)
			for piece in _end_slab_pieces(e, L, Wd, stair_len, hole, solid):
				_dbox(mat, piece[0], piece[1], y - 0.25, piece[2], piece[3], y)
				if f > 0:
					_dbox("plaster", piece[0], piece[1], y - 0.28, piece[2], piece[3], y - 0.25, false)
		if f > 0:
			_dbox("plaster", stair_len, 0, y - 0.28, L - stair_len, Wd, y - 0.25, false)
	_dbox("concrete", 0, 0, H, L, 0.3, H + 0.9)
	_dbox("concrete", 0, Wd - 0.3, H, L, Wd, H + 0.9)
	_dbox("concrete", 0, 0, H, 0.3, Wd, H + 0.9)
	_dbox("concrete", L - 0.3, 0, H, L, Wd, H + 0.9)
	# ---- stairs: end 0 continues to the roof, end 1 stops at the top floor
	for e in 2:
		var sg := 1.0 if e == 0 else -1.0
		var top_floor := floors if e == 0 else floors - 1
		for f in top_floor:
			var y := f * FLOOR_H
			var ua := _eu(e, L, 1.0)
			_flight(_dp(ua, 1.3, y), _d_u * sg, _d_v, 2.0, FLOOR_H / 2.0)
			var l0 := _eu(e, L, 2.8)
			var l1 := _eu(e, L, 4.3)
			_dbox("concrete", minf(l0, l1), 0.3, y + FLOOR_H / 2.0 - 0.2, maxf(l0, l1), 4.5, y + FLOOR_H / 2.0)
			_flight(_dp(l0, 3.5, y + FLOOR_H / 2.0), -_d_u * sg, _d_v, 2.0, FLOOR_H / 2.0)
	# roof stair house over end 0, door facing the roof (+v)
	var rh := H + 2.6
	_dbox("brick_grey", 0.0, 0.0, H, 0.25, 4.8, rh)
	_dbox("brick_grey", 4.55, 0.0, H, 4.8, 4.8, rh)
	_dbox("brick_grey", 0.0, 0.0, H, 4.8, 0.25, rh)
	_dbox("brick_grey", 0.0, 4.55, H, 1.6, 4.8, rh)
	_dbox("brick_grey", 3.0, 4.55, H, 4.8, 4.8, rh)
	_dbox("brick_grey", 1.6, 4.55, H + 2.2, 3.0, 4.8, rh)
	_dbox("roof_tar", -0.2, -0.2, rh, 5.0, 5.0, rh + 0.2)
	batch_commit(holder, "Structure", "Concrete")
	# ---- doors and furniture
	if ResourceLoader.exists(WOOD_DOOR):
		for f in floors:
			for k in n_rooms:
				var uc := stair_len + (k + 0.5) * room_w
				for side in [c0, c1]:
					var p := _dp(uc, float(side), f * FLOOR_H)
					var n := instance(WOOD_DOOR)
					var aa := asset_aabb(WOOD_DOOR)
					var basis := Basis(Vector3.UP, yaw_of(Vector2(_d_u.x, _d_u.z)))
					n.transform = Transform3D(basis, p - basis * Vector3(aa.get_center().x, 0.0, aa.get_center().z))
					add(holder, n)
	for f in floors:
		for k in n_rooms:
			for side in 2:
				_furnish_room(holder, k, side, f, room_w, stair_len, c0, c1, Wd)
	var area := Area3D.new()
	area.collision_layer = 512
	area.collision_mask = 0
	area.monitoring = false
	area.set_script(load("res://Scripts/Area.gd"))
	area.set("type", "Indoor")
	area.transform.origin = _dp(L / 2.0, Wd / 2.0, H / 2.0)
	add(holder, area, "Area")
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(Wd - 0.7, H, L - 0.7) if along_z else Vector3(L - 0.7, H, Wd - 0.7)
	acs.shape = abox
	add(area, acs, "CollisionShape3D")
	footprints.append(Rect2(x0, z0, x1 - x0, z1 - z0).grow(3.0))
	stats[String(b.name)] = "dorm %d floors, %d rooms" % [floors, n_rooms * 2 * floors]


# Openings listed from the other end of a wall (walls laid in reverse).
func _mirror_ops(ops: Array, length: float) -> Array:
	var out: Array = []
	for o in ops:
		var m: Array = o.duplicate()
		m[0] = length - float(o[0]) - float(o[1])
		out.append(m)
	return out


# One stair flight: visual steps plus a sloped collider.
func _flight(start: Vector3, dir: Vector3, side: Vector3, width: float, rise: float) -> void:
	var steps := int(round(rise / 0.25))
	var step_r := rise / steps
	var tread := 0.3
	for k in steps:
		var c := start + dir * (k * tread + tread / 2.0) + Vector3.UP * (k * step_r + step_r / 2.0) + side * 0.0
		var size := dir.abs() * tread + side.abs() * width + Vector3(0, step_r, 0)
		batch_box("concrete", c, size, Basis.IDENTITY, false)
	var length := steps * tread
	var mid := start + dir * (length / 2.0) + Vector3.UP * (rise / 2.0)
	var b := Basis.looking_at(dir, Vector3.UP)
	var ang := atan2(rise, length)
	batch_box("concrete", mid, Vector3(width, 0.05, sqrt(length * length + rise * rise)), Basis(b.x, ang) * b, true)


func _furnish_room(holder: Node, k: int, side: int, f: int, room_w: float, stair_len: float, c0: float, c1: float, Wd: float) -> void:
	var set: Array = ROOM_SETS[rng.randi() % ROOM_SETS.size()]
	var u0 := stair_len + k * room_w + 0.5
	var u1 := stair_len + (k + 1) * room_w - 0.5
	var v_wall := 0.6 if side == 0 else Wd - 0.6          # exterior wall side
	var v_door := c0 - 0.5 if side == 0 else c1 + 0.5
	var y := f * FLOOR_H
	var spots := [
		[u0 + 0.9, v_wall + (0.9 if side == 0 else -0.9)],
		[u1 - 0.6, lerpf(v_wall, v_door, 0.45)],
		[u0 + 0.5, lerpf(v_wall, v_door, 0.55)],
		[(u0 + u1) / 2.0, lerpf(v_wall, v_door, 0.5)],
	]
	for i in set.size():
		if rng.randf() < 0.15 or not ResourceLoader.exists(set[i]):
			continue
		var s: Array = spots[i]
		var p := _dp(float(s[0]), float(s[1]), y)
		var n := instance(set[i])
		# Backs against the outer wall: local +Z faces into the room.
		var into := _d_v * (1.0 if side == 0 else -1.0)
		if i == 1:
			into = -_d_u      # second piece stands against the partition
		n.transform = Transform3D(Basis(Vector3.UP, atan2(into.x, into.z)), p)
		add(holder, n)
	if rng.randf() < 0.35:
		var junk: String = CLUTTER[rng.randi() % 4]
		var n2 := instance(junk)
		n2.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _dp((u0 + u1) / 2.0, lerpf(v_wall, v_door, 0.7), y))
		add(holder, n2)



func _eu(e: int, L: float, u: float) -> float:
	return u if e == 0 else L - u


# Slab pieces of an end zone around the stair hole (or one solid piece).
func _end_slab_pieces(e: int, L: float, Wd: float, stair_len: float, hole: Rect2, solid: bool) -> Array:
	var pieces: Array = []
	var u_a := 0.0
	var u_b := stair_len
	if solid:
		pieces.append([u_a, 0.0, u_b, Wd])
	else:
		var hu0 := hole.position.x
		var hu1 := hole.end.x
		var hv0 := hole.position.y
		var hv1 := hole.end.y
		pieces.append([u_a, 0.0, hu0, Wd])
		pieces.append([hu1, 0.0, u_b, Wd])
		pieces.append([hu0, hv1, hu1, Wd])
		pieces.append([hu0, 0.0, hu1, hv0])
	if e == 1:
		for p in pieces:
			var a := L - float(p[2])
			var b := L - float(p[0])
			p[0] = a
			p[2] = b
	return pieces



# Guard against inside-out geometry: Godot renders clockwise triangles as
# front faces, so each triangle's clockwise normal must agree with the
# stored vertex normal. Mismatches are counted in the build stats.
func check_winding(mesh: Mesh, label: String) -> void:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx = arr[Mesh.ARRAY_INDEX]
	var count: int = idx.size() if idx != null and idx.size() > 0 else v.size()
	var bad := 0
	for k in range(0, count, 3):
		var i0: int = idx[k] if idx != null and idx.size() > 0 else k
		var i1: int = idx[k + 1] if idx != null and idx.size() > 0 else k + 1
		var i2: int = idx[k + 2] if idx != null and idx.size() > 0 else k + 2
		var front := (v[i2] - v[i0]).cross(v[i1] - v[i0])
		if front.length_squared() < 1e-10:
			continue
		if front.dot(nrm[i0]) <= 0.0:
			bad += 1
	if bad > 0:
		stats["flipped_faces"] = int(stats.get("flipped_faces", 0)) + bad
		push_warning("flipped faces in %s: %d" % [label, bad])



func chaikin(points: Array, iterations: int) -> Array:
	var pts: Array = []
	for p in points:
		pts.append([float(p[0]), float(p[1])])
	for it in iterations:
		var out: Array = [pts[0]]
		for i in pts.size() - 1:
			var a := v2(pts[i])
			var b := v2(pts[i + 1])
			var q := a.lerp(b, 0.25)
			var r := a.lerp(b, 0.75)
			out.append([q.x, q.y])
			out.append([r.x, r.y])
		out.append(pts[-1])
		pts = out
	return pts



# ================================================================== AI
# Same setup as Vostok's own maps: an AISpawner node with its pools, typed
# AI points (waypoints, spawns, patrols, covers, hides, groups, lurks) and a
# navigation mesh baked from the map's static colliders.

const AI_POINT := {
	"WP": "res://AI/Tools/AI_WP.tscn", "SP": "res://AI/Tools/AI_SP.tscn", "PP": "res://AI/Tools/AI_PP.tscn",
	"CP": "res://AI/Tools/AI_CP.tscn", "HP": "res://AI/Tools/AI_HP.tscn", "GP": "res://AI/Tools/AI_GP.tscn",
	"LP": "res://AI/Tools/AI_LP.tscn",
}
var cover_objects: Array = []     # [Vector2 centre, float radius] in layout metres
var ai_counts := {}


func ai_point(parent: Node, kind: String, x: float, z: float, face := Vector2.ZERO, lift := 0.0) -> Node3D:
	var n := instance(AI_POINT[kind])
	var pos := W(x, z, lift)
	var basis := Basis.IDENTITY
	if face != Vector2.ZERO:
		# -Z of the point looks at `face` (Vostok's cover test uses basis.z).
		var d := Vector3(face.x - x, 0.0, face.y - z).normalized()
		basis = Basis.looking_at(d, Vector3.UP)
	n.transform = Transform3D(basis, pos)
	add(parent, n)
	ai_counts[kind] = int(ai_counts.get(kind, 0)) + 1
	return n


func inside_playable(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _boundary())


var _boundary_cache := PackedVector2Array()
func _boundary() -> PackedVector2Array:
	if _boundary_cache.is_empty():
		for q in L.playable_boundary:
			_boundary_cache.append(v2(q))
	return _boundary_cache


func blocked(p: Vector2, margin := 0.0) -> bool:
	for r in footprints:
		var rr := (r as Rect2).grow(margin - 3.0)
		if rr.size.x > 0.0 and rr.size.y > 0.0 and rr.has_point(p):
			return true
	return ground(p.x, p.y) < float(M.water_level) + 0.4


func build_ai() -> void:
	var ai := Node3D.new()
	ai.set_script(load("res://Scripts/AISpawner.gd"))
	ai.set("active", true)
	ai.set("zone", 0)
	add(map_root, ai, "AI")
	for n in ["E_Pool", "N_Pool", "B_Pool", "Enemies", "Nomads"]:
		add(ai, Node3D.new(), n)
	var groups_node := group(ai, "Groups")
	var lurks := group(ai, "Lurks")
	var wps := group(ai, "Waypoints")
	var pts := group(ai, "Points")
	print("[customs] ai: nodes ok")

	# Waypoints: 20 m grid over open, walkable ground.
	var bb := Rect2(v2(_boundary()[0]), Vector2.ZERO)
	for q in _boundary():
		bb = bb.expand(q)
	var x := bb.position.x + 10.0
	while x < bb.end.x:
		var z := bb.position.y + 10.0
		while z < bb.end.y:
			var p := Vector2(x + rng.randf_range(-4, 4), z + rng.randf_range(-4, 4))
			if inside_playable(p) and not blocked(p, 2.0):
				ai_point(wps, "WP", p.x, p.y)
			z += 20.0
		x += 20.0

	print("[customs] ai: waypoints ", ai_counts)
	# Scav spawns where Tarkov puts them, and patrol loops through the map.
	for s in L.get("ai", {}).get("spawns", []):
		ai_point(pts, "SP", float(s[0]), float(s[1]))
	for r in L.roads:
		if r.get("surface", "") == "dirt":
			continue
		var road_pts := resample(r.points, 40.0)
		for i in road_pts.size():
			var p: Vector2 = road_pts[i]
			var nxt: Vector2 = road_pts[mini(i + 1, road_pts.size() - 1)]
			var prv: Vector2 = road_pts[maxi(i - 1, 0)]
			var side := (nxt - prv).normalized().orthogonal() * (float(r.width) / 2.0 + 2.0)
			var q := p + side * (1.0 if i % 2 == 0 else -1.0)
			if inside_playable(q) and not blocked(q):
				ai_point(pts, "PP", q.x, q.y)

	print("[customs] ai: spawns/patrols ", ai_counts)
	# Cover behind containers, wrecks and building corners, facing the object.
	for c in cover_objects:
		var centre: Vector2 = c[0]
		var rad: float = c[1]
		for k in 4:
			var ang := k * PI / 2.0 + rng.randf_range(-0.3, 0.3)
			var q := centre + Vector2(cos(ang), sin(ang)) * (rad + 1.2)
			if inside_playable(q) and not blocked(q):
				ai_point(pts, "CP", q.x, q.y, centre)
	for b in L.buildings:
		if b.kind != "generated" and b.kind != "dorm":
			continue
		var r: Array = b.rect
		var corners: Array[Vector2] = [Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[1])), Vector2(float(r[2]), float(r[3])), Vector2(float(r[0]), float(r[3]))]
		var centre: Vector2 = (corners[0] + corners[2]) / 2.0
		for cn in corners:
			var out: Vector2 = (cn - centre).normalized()
			var q: Vector2 = cn + out * 2.2
			if inside_playable(q) and not blocked(q, -3.0):
				ai_point(pts, "CP", q.x, q.y, cn)
		# Hiding spots inside.
		if b.kind == "generated" and String(b.get("style", "")) != "garages":
			for k in 2:
				var hx := lerpf(float(r[0]) + 2.5, float(r[2]) - 2.5, rng.randf())
				var hz := lerpf(float(r[1]) + 2.5, float(r[3]) - 2.5, rng.randf())
				var hp := ai_point(pts, "HP", hx, hz)
				hp.position.y = ground((float(r[0]) + float(r[2])) / 2.0, (float(r[1]) + float(r[3])) / 2.0) + 0.05

	print("[customs] ai: covers ", ai_counts)
	# Groups: each set of points under one parent spawns together.
	for gdef in L.get("ai", {}).get("groups", []):
		var holder := Node3D.new()
		add(groups_node, holder, "Group")
		var c := v2(gdef)
		for k in 3:
			var ang := k * TAU / 3.0 + rng.randf()
			var q := c + Vector2(cos(ang), sin(ang)) * 2.5
			ai_point(holder, "GP", q.x, q.y, c)

	# Lurkers in the forest edge.
	for l in L.get("ai", {}).get("lurks", []):
		ai_point(lurks, "LP", float(l[0]), float(l[1]))
	stats["ai_points"] = ai_counts


const NAV_CELL := 0.24     # Customs' navigation map is set to this on load (Compiler ext)


func bake_navmesh() -> void:
	# One seamless region. Tree trunks are left out: 11k trunk holes push a
	# single Recast mesh past its 65535-vertex limit, and tiled meshes don't
	# stitch reliably at runtime. Agents slide around trunks physically.
	var src_all := PackedVector3Array()
	var water := float(M.water_level)
	var tri := _collect_faces(content, Transform3D.IDENTITY, src_all, water)
	var bb := Rect2(v2(_boundary()[0]), Vector2.ZERO)
	for q in _boundary():
		bb = bb.expand(q)
	bb = bb.grow(4.0)
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.24
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.36
	nm.agent_max_slope = 60.0
	nm.cell_size = NAV_CELL
	nm.cell_height = 0.12
	nm.region_min_size = 300.0
	nm.filter_baking_aabb = AABB(Vector3(bb.position.x - OX, -20.0, bb.position.y - OZ), Vector3(bb.size.x, 90.0, bb.size.y))
	var src := NavigationMeshSourceGeometryData3D.new()
	src.add_faces(src_all, Transform3D.IDENTITY)
	var t0 := Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var verts := nm.get_vertices().size()
	if verts >= 65000:
		push_error("navmesh near Recast's 65535-vertex limit (%d): it will be cut into islands" % verts)
	(content as NavigationRegion3D).navigation_mesh = save_res(nm, "NM_Customs.res")
	stats["navmesh"] = {"source_tris": tri, "polys": nm.get_polygon_count(), "verts": verts, "bake_s": (Time.get_ticks_msec() - t0) / 1000.0}


func _collect_faces(n: Node, xf: Transform3D, src: PackedVector3Array, water: float) -> int:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	var count := 0
	if n.name.begins_with("Trees_"):
		return 0
	if n is CollisionShape3D and n.get_parent() is StaticBody3D:
		var body := n.get_parent() as StaticBody3D
		var shape: Shape3D = (n as CollisionShape3D).shape
		if shape and (body.collision_layer & 2081) != 0:
			var faces := PackedVector3Array()
			if shape is ConcavePolygonShape3D:
				faces = (shape as ConcavePolygonShape3D).get_faces()
			else:
				var dm := shape.get_debug_mesh()
				if dm:
					faces = dm.get_faces()
			var keep := PackedVector3Array()
			for k in range(0, faces.size() - 2, 3):
				var a: Vector3 = t * faces[k]
				var b: Vector3 = t * faces[k + 1]
				var c: Vector3 = t * faces[k + 2]
				if a.y < water - 0.5 and b.y < water - 0.5 and c.y < water - 0.5:
					continue          # river bed: AI stay out of the water
				keep.append_array([a, b, c])
			if keep.size() > 0:
				src.append_array(keep)
				count += keep.size() / 3
	for c in n.get_children():
		count += _collect_faces(c, t, src, water)
	return count



# ================================================================== fidelity pass 2
# Set pieces traced from re3mr's map: placements, cranes, gantries, the
# ruined scav-base hall, pipe tower and bridge, parked wagons, crossings.

func build_set_pieces() -> void:
	var g := group(content, "SetPieces")
	for pl in L.get("placements", []):
		var path: String = pl.scene
		if not ResourceLoader.exists(path):
			push_warning("missing scene " + path)
			continue
		var p := v2(pl.pos)
		place(path, g, p.x, p.y, deg_to_rad(float(pl.get("yaw", 0.0))), float(pl.get("lift", 0.0)))
		var a := asset_aabb(path)
		if a.size.y > 1.0 and a.size.y < 6.0:
			cover_objects.append([p, maxf(a.size.x, a.size.z) / 2.0])
	for cr in L.get("cranes", []):
		build_tower_crane(g, cr)
	for gd in L.get("gantries", []):
		build_gantry(g, gd)
	for t in L.get("pipe_towers", []):
		build_pipe_tower(g, t)
	for pb in L.get("pipe_bridges", []):
		build_pipe_bridge(g, pb)
	build_wagons(g)
	build_crossings(g)


func build_tower_crane(parent: Node, cr: Dictionary) -> void:
	var p := v2(cr.pos)
	var base := W(p.x, p.y)
	var h := float(cr.height)
	batch_begin()
	batch_box("concrete", base + Vector3(0, 0.4, 0), Vector3(4.0, 0.8, 4.0))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			batch_box("metal_red", base + Vector3(float(cx) * 0.9, h / 2.0, float(cz) * 0.9), Vector3(0.22, h, 0.22))
	var y := 0.0
	while y < h:
		for s in 4:
			var rot := Basis(Vector3.UP, s * PI / 2.0)
			batch_box("metal_red", base + rot * Vector3(0, 0, 0.9) + Vector3(0, y + 1.5, 0), Vector3(2.5, 0.12, 0.12), rot * Basis(Vector3.BACK, deg_to_rad(45.0)), false)
		y += 3.0
	var heading := deg_to_rad(float(cr.heading))
	var dir := Vector3(sin(heading), 0, cos(heading))
	var jib := float(cr.jib)
	var jb := Basis.looking_at(dir, Vector3.UP)
	batch_box("metal_red", base + Vector3(0, h + 0.6, 0) + dir * (jib / 2.0), Vector3(1.2, 1.2, jib), jb, false)
	batch_box("metal_red", base + Vector3(0, h + 0.6, 0) - dir * 6.0, Vector3(1.2, 1.0, 12.0), jb, false)
	batch_box("concrete", base + Vector3(0, h - 0.4, 0) - dir * 10.5, Vector3(3.0, 2.6, 2.4), jb, false)
	batch_box("metal_red", base + Vector3(0, h + 3.5, 0), Vector3(0.5, 6.0, 0.5), Basis.IDENTITY, false)
	batch_box("brick_grey", base + Vector3(1.6, h - 1.5, 0), Vector3(2.0, 2.4, 2.0), Basis.IDENTITY, false)
	# hoist cable and hook block part way along the jib
	var hook := base + dir * (jib * 0.6)
	batch_box("metal_rust", hook + Vector3(0, h - 6.0, 0), Vector3(0.05, 12.0, 0.05), Basis.IDENTITY, false)
	batch_box("metal_rust", hook + Vector3(0, h - 12.4, 0), Vector3(0.6, 0.8, 0.4), Basis.IDENTITY, false)
	batch_commit(parent, String(cr.get("name", "TowerCrane")), "Metal")
	footprints.append(Rect2(p - Vector2(3, 3), Vector2(6, 6)))


# Overhead gantry crane: two A-frame legs, a box girder and a hoist.
func build_gantry(parent: Node, gd: Dictionary) -> void:
	var a := v2(gd.from)
	var b := v2(gd.to)
	var span := float(gd.span)
	var h := float(gd.height)
	var dir := (b - a).normalized()
	var side := dir.orthogonal()
	batch_begin()
	for end in [a, b]:
		for s in [-1.0, 1.0]:
			var foot: Vector2 = end + side * (span / 2.0 * float(s))
			var fp := W(foot.x, foot.y)
			batch_box("metal_rust", fp + Vector3(0, h / 2.0, 0), Vector3(0.5, h, 0.5))
		var mid := W(end.x, end.y)
		var across := Basis.looking_at(Vector3(side.x, 0, side.y), Vector3.UP)
		batch_box("metal_rust", mid + Vector3(0, h, 0), Vector3(0.6, 0.8, span + 0.6), across, false)
	var len := a.distance_to(b)
	var c := (a + b) / 2.0
	var along := Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP)
	var top := maxf(ground(a.x, a.y), ground(b.x, b.y)) + h
	for s in [-1.0, 1.0]:
		var gp: Vector2 = c + side * (span / 2.0 - 0.4) * float(s)
		batch_box("metal_red", Vector3(gp.x - OX, top + 0.8, gp.y - OZ), Vector3(0.7, 1.0, len + 0.8), along, false)
	var hoist := c + dir * (len * 0.15)
	batch_box("metal_rust", Vector3(hoist.x - OX, top + 1.6, hoist.y - OZ), Vector3(span - 1.0, 0.8, 2.0), Basis.looking_at(Vector3(side.x, 0, side.y), Vector3.UP), false)
	batch_box("metal_rust", Vector3(hoist.x - OX, top - 2.0, hoist.y - OZ), Vector3(0.05, 6.0, 0.05), Basis.IDENTITY, false)
	batch_commit(parent, "Gantry", "Metal")


func build_pipe_tower(parent: Node, t: Dictionary) -> void:
	var p := v2(t.pos)
	var h := float(t.height)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = h
	cyl.top_radius = float(t.radius)
	cyl.bottom_radius = float(t.radius)
	cyl.radial_segments = 16
	mi.mesh = cyl
	mi.material_override = swatch("metal_rust")
	mi.transform.origin = W(p.x, p.y, h / 2.0)
	add(parent, mi, "PipeTower")
	var body := StaticBody3D.new()
	body.set_script(load(SCR_SURFACE))
	body.set("surface", "Metal")
	add(mi, body, "StaticBody3D")
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = h
	shape.radius = float(t.radius)
	cs.shape = shape
	add(body, cs, "CollisionShape3D")
	# ring platforms every 6 m
	batch_begin()
	var y := 6.0
	while y < h:
		batch_box("metal_rust", W(p.x, p.y, y), Vector3(float(t.radius) * 2.0 + 1.6, 0.15, float(t.radius) * 2.0 + 1.6), Basis.IDENTITY, false)
		y += 6.0
	batch_commit(parent, "PipeTowerRings", "Metal")


func build_pipe_bridge(parent: Node, pb: Dictionary) -> void:
	var a := v2(pb.from)
	var b := v2(pb.to)
	var h := float(pb.height)
	var dir := (b - a).normalized()
	var len := a.distance_to(b)
	var along := Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP)
	var y := maxf(ground(a.x, a.y), ground(b.x, b.y)) + h
	batch_begin()
	var c := (a + b) / 2.0
	for s in [-0.6, 0.6]:
		var q: Vector2 = c + dir.orthogonal() * float(s)
		batch_box("metal_rust", Vector3(q.x - OX, y + 0.9, q.y - OZ), Vector3(0.18, 0.18, len), along, false)
		batch_box("metal_rust", Vector3(q.x - OX, y, q.y - OZ), Vector3(0.18, 0.18, len), along, false)
	var n := int(len / 3.0)
	for k in n + 1:
		var q := a + dir * (k * len / n)
		batch_box("metal_rust", Vector3(q.x - OX, y + 0.45, q.y - OZ), Vector3(1.4, 0.9, 0.12), along, false)
		if k % 4 == 0:
			var gy := ground(q.x, q.y)
			batch_box("metal_rust", Vector3(q.x - OX, (gy + y) / 2.0, q.y - OZ), Vector3(0.3, y - gy, 0.3))
	batch_commit(parent, "PipeBridge", "Metal")
	# the pipes themselves
	var pipe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = len
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.radial_segments = 12
	pipe.mesh = cyl
	pipe.material_override = swatch("metal_rust")
	pipe.transform = Transform3D(along * Basis(Vector3.RIGHT, PI / 2.0), Vector3(c.x - OX, y + 0.45, c.y - OZ))
	add(parent, pipe, "BridgePipe")


func _rail_points(name: String) -> Array:
	for r in L.rails:
		if r.name == name:
			return resample(r.points, 1.0)
	return []


func build_wagons(parent: Node) -> void:
	var wagon := "res://Assets/Train_Oil/Train_Oil.tscn"
	var wl := maxf(asset_aabb(wagon).size.z, 10.0) + 1.0
	for w in L.get("wagons", []):
		var pts := _rail_points(String(w.rail))
		if pts.size() < 3:
			continue
		var d := float(w.from)
		for k in int(w.count):
			var i0 := clampi(int(d), 0, pts.size() - 2)
			var i1 := clampi(int(d + wl), 1, pts.size() - 1)
			if i1 <= i0:
				break
			var a: Vector2 = pts[i0]
			var b: Vector2 = pts[i1]
			var c := (a + b) / 2.0
			var from := W(a.x, a.y, 0.05)
			var to := W(b.x, b.y, 0.05)
			var n := instance(wagon)
			n.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), W(c.x, c.y, 0.05))
			add(parent, n, "Wagon")
			cover_objects.append([c, 2.0])
			d += wl
	stats["wagons"] = parent.get_children().filter(func(x): return x.name.begins_with("Wagon")).size()


# Level crossings wherever a rail meets a road (not on bridges).
func build_crossings(parent: Node) -> void:
	var xing := "res://Assets/Railroad/Railroad_Crossing.tscn"
	var count := 0
	for r in L.rails:
		var rp: Array = r.points
		for i in rp.size() - 1:
			var a := v2(rp[i])
			var b := v2(rp[i + 1])
			for road in L.roads:
				var qp: Array = road.points
				for j in qp.size() - 1:
					var c := v2(qp[j])
					var d := v2(qp[j + 1])
					var hit = Geometry2D.segment_intersects_segment(a, b, c, d)
					if hit == null or bridge_height(hit) > -INF:
						continue
					var dir := (b - a).normalized()
					var n := instance(xing)
					var from := W(hit.x, hit.y, 0.02)
					n.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP), from)
					add(parent, n, "Crossing")
					count += 1
	stats["crossings"] = count


# Ruined hall (Tarkov's scav base "fortress"): tall brick walls with big
# openings, exposed roof trusses, part of the roof still clad.
func build_hall_ruin(holder: Node, b: Dictionary) -> void:
	var r: Array = b.rect
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := float(r[2])
	var z1 := float(r[3])
	var h := float(b.height)
	var floor_y := ground((x0 + x1) / 2.0, (z0 + z1) / 2.0) + 0.05
	var w := x1 - x0
	var d := z1 - z0
	var thick := 0.5
	var bands := [[0.6, "concrete"], [h + 1.0, "brick_red"]]
	batch_begin()
	var long_ops := func(len: float) -> Array:
		var ops: Array = []
		var k := 4.0
		while k < len - 6.0:
			ops.append([k, 3.4, 2.0, h - 3.0, "window"])
			k += 6.0
		ops.append([len * 0.5 - 3.0, 6.0, 0.0, 6.0, "bay"])
		return ops
	var short_ops := func(len: float) -> Array:
		return [[len * 0.5 - 3.5, 7.0, 0.0, 7.0, "bay"], [2.0, 2.4, h - 5.0, h - 2.0, "window"], [len - 4.4, 2.4, h - 5.0, h - 2.0, "window"]]
	var sides := [[Vector3(x0 - OX, floor_y, z0 - OZ), Vector3.RIGHT, Vector3.BACK, w, w >= d],
		[Vector3(x1 - OX, floor_y, z0 - OZ), Vector3.BACK, Vector3.LEFT, d, d > w],
		[Vector3(x1 - OX, floor_y, z1 - OZ), Vector3.LEFT, Vector3.FORWARD, w, w >= d],
		[Vector3(x0 - OX, floor_y, z1 - OZ), Vector3.FORWARD, Vector3.RIGHT, d, d > w]]
	for sd in sides:
		var ops: Array = long_ops.call(float(sd[3])) if bool(sd[4]) else short_ops.call(float(sd[3]))
		wall(sd[0], sd[1], sd[2], float(sd[3]), h, thick, ops, bands)
		for o in ops:
			if o[4] == "window":
				_detail_opening(sd[0], sd[1], sd[2], thick, o)
	batch_box("slab", Vector3((x0 + x1) / 2.0 - OX, floor_y - 0.15, (z0 + z1) / 2.0 - OZ), Vector3(w, 0.3, d))
	# Trusses across the short span every 6 m along the long axis.
	var long_x := w >= d
	var run := w if long_x else d
	var span := d if long_x else w
	var rise := span * 0.22
	var n := int(run / 6.0)
	for k in n + 1:
		var t := 1.0 + k * (run - 2.0) / n
		var base := Vector3(x0 + t - OX, floor_y + h, (z0 + z1) / 2.0 - OZ) if long_x else Vector3((x0 + x1) / 2.0 - OX, floor_y + h, z0 + t - OZ)
		var across := Vector3.BACK if long_x else Vector3.RIGHT
		var ang := atan2(rise, span / 2.0)
		var rafter := Vector3(0.25, 0.3, span / 2.0 / cos(ang))
		for s in [-1.0, 1.0]:
			var mid := base + across * (float(s) * span / 4.0) + Vector3.UP * (rise / 2.0)
			var bas := Basis.looking_at(across * float(s), Vector3.UP)
			batch_box("metal_rust", mid, rafter, Basis(bas.x, -ang) * bas, false)
		batch_box("metal_rust", base, (Vector3(0.25, 0.25, span) if long_x else Vector3(span, 0.25, 0.25)), Basis.IDENTITY, false)
		batch_box("metal_rust", base + Vector3.UP * (rise / 2.0), Vector3(0.18, rise, 0.18), Basis.IDENTITY, false)
	# Purlins along the run, and roof cladding on the first ~40 %.
	for s in [-1.0, 1.0]:
		for f in [0.25, 0.5, 0.75]:
			var off: float = float(s) * span / 2.0 * (1.0 - float(f))
			var y: float = floor_y + h + rise * float(f)
			var pos := Vector3((x0 + x1) / 2.0 - OX, y, (z0 + z1) / 2.0 - OZ + off) if long_x else Vector3((x0 + x1) / 2.0 - OX + off, y, (z0 + z1) / 2.0 - OZ)
			batch_box("metal_rust", pos, (Vector3(run, 0.15, 0.15) if long_x else Vector3(0.15, 0.15, run)), Basis.IDENTITY, false)
		var clad := run * 0.4
		var ang2 := atan2(rise, span / 2.0)
		var cpos := Vector3(x0 + clad / 2.0 - OX, floor_y + h + rise / 2.0 + 0.2, (z0 + z1) / 2.0 - OZ + float(s) * span / 4.0) if long_x else Vector3((x0 + x1) / 2.0 - OX + float(s) * span / 4.0, floor_y + h + rise / 2.0 + 0.2, z0 + clad / 2.0 - OZ)
		var size := Vector3(clad, 0.1, span / 2.0 / cos(ang2)) if long_x else Vector3(span / 2.0 / cos(ang2), 0.1, clad)
		var tilt := Basis(Vector3.RIGHT, float(s) * ang2) if long_x else Basis(Vector3.BACK, -float(s) * ang2)
		batch_box("roof_metal", cpos, size, tilt)
	batch_commit(holder, "Structure", "Concrete")
	var area := Area3D.new()
	area.collision_layer = 512
	area.collision_mask = 0
	area.monitoring = false
	area.set_script(load("res://Scripts/Area.gd"))
	area.set("type", "Indoor")
	area.transform.origin = Vector3((x0 + x1) / 2.0 - OX, floor_y + h / 2.0, (z0 + z1) / 2.0 - OZ)
	add(holder, area, "Area")
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(w - 1.0, h, d - 1.0)
	acs.shape = abox
	add(area, acs, "CollisionShape3D")
	footprints.append(Rect2(x0, z0, w, d).grow(3.0))
	_dress_interior(holder, x0, z0, x1, z1, floor_y, "concrete")



func boundary_distance(p: Vector2) -> float:
	var b := _boundary()
	var best := INF
	for i in b.size():
		var a := b[i]
		var c := b[(i + 1) % b.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, c)))
	return best



# Closest point on the playable boundary to p, and the boundary direction there.
func _closest_boundary(p: Vector2) -> Array:
	var b := _boundary()
	var best := INF
	var out := [p, Vector2.RIGHT]
	for i in b.size():
		var a := b[i]
		var c := b[(i + 1) % b.size()]
		var q := Geometry2D.get_closest_point_to_segment(p, a, c)
		var d := p.distance_to(q)
		if d < best and a.distance_to(c) > 0.01:
			best = d
			out = [q, (c - a).normalized()]
	return out
