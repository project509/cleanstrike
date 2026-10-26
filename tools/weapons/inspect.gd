# Weapons Pack tool: inspect a source gun model. Lists every mesh and, inside
# each mesh, every connected piece (welded by position) with its box; renders
# a side view with each piece coloured and numbered to
# C:/RTVDev/inspect/<gun>.png. Pick the guns with GUNS below.
extends Node

const GUNS := {
	"ash12": "res://cs_assets/ash12/ash12.glb",
	"deagle": "res://cs_assets/deagle/deagle.fbx",
	"raygun": "res://cs_assets/raygun/raygun.fbx",
	"mini14": "res://cs_assets/mini14/mini14.fbx",
	"welrod": "res://cs_assets/welrod/welrod.glb",
	"m82": "res://cs_assets/m82/m82_low.glb",
	"vector": "res://cs_assets/vector/vector.dae",
	"p90": "res://cs_assets/p90/p90.dae",
	"scar": "res://cs_assets/scar/SCAR_straight.fbx",
}
const MAX_LABELS := 60


func _ready() -> void:
	get_tree().create_timer(600.0).timeout.connect(func(): print("STAGE timeout"); get_tree().quit())
	DirAccess.make_dir_recursive_absolute("C:/RTVDev/inspect")
	var only := OS.get_environment("GUN")
	for gun in GUNS:
		if only != "" and gun != only:
			continue
		await _inspect(gun, GUNS[gun])
	get_tree().quit()


func _xform(n: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	var x: Node = n
	while x and x != root:
		if x is Node3D:
			t = x.transform * t
		x = x.get_parent()
	return t


# Connected pieces of a mesh (all surfaces), welded by position.
func _pieces(mesh: Mesh, xf: Transform3D, weld: float) -> Array:
	var parent := {}
	var find := func(a): return a
	var pos_id := {}
	var verts: Array = []
	var tris: Array = []      # [surface, i0, i1, i2] as welded ids
	var tri_pos: Array = []
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var ids := PackedInt32Array()
		ids.resize(v.size())
		for i in v.size():
			var p: Vector3 = xf * v[i]
			var key := Vector3i(roundi(p.x / weld), roundi(p.y / weld), roundi(p.z / weld))
			if not pos_id.has(key):
				pos_id[key] = verts.size()
				verts.append(p)
				parent[verts.size() - 1] = verts.size() - 1
			ids[i] = pos_id[key]
		if idx == null or idx.size() == 0:
			idx = PackedInt32Array(range(v.size()))
		for t in range(0, idx.size(), 3):
			tris.append([s, ids[idx[t]], ids[idx[t + 1]], ids[idx[t + 2]]])
			tri_pos.append([xf * v[idx[t]], xf * v[idx[t + 1]], xf * v[idx[t + 2]]])
	# union-find
	var par := PackedInt32Array()
	par.resize(verts.size())
	for i in verts.size():
		par[i] = i
	var root_of := func(a: int) -> int:
		while par[a] != a:
			par[a] = par[par[a]]
			a = par[a]
		return a
	for t in tris:
		var a: int = root_of.call(t[1])
		var b: int = root_of.call(t[2])
		var c: int = root_of.call(t[3])
		if a != b: par[b] = a
		var a2: int = root_of.call(a)
		var c2: int = root_of.call(c)
		if a2 != c2: par[c2] = a2
	var groups := {}
	for ti in tris.size():
		var r: int = root_of.call(tris[ti][1])
		if not groups.has(r):
			groups[r] = {"tris": [], "box": AABB(tri_pos[ti][0], Vector3.ZERO)}
		groups[r].tris.append(ti)
		for p in tri_pos[ti]:
			groups[r].box = groups[r].box.expand(p)
	var out: Array = []
	for r in groups:
		out.append({"tris": groups[r].tris, "box": groups[r].box, "tri_pos": tri_pos})
	out.sort_custom(func(a, b): return a.box.size.length() > b.box.size.length())
	return out


func _inspect(gun: String, path: String) -> void:
	print("=== ", gun, " ", path)
	var src: Node = load(path).instantiate()
	add_child(src)
	var meshes: Array = src.find_children("*", "MeshInstance3D", true, false)
	var all := AABB()
	var first := true
	for m in meshes:
		var b: AABB = _xform(m, src) * m.get_aabb()
		all = b if first else all.merge(b)
		first = false
	print("overall ", all)
	var weld: float = all.size.length() * 0.00002
	var view := SubViewport.new()
	view.size = Vector2i(2400, 1000)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.92, 0.92, 0.92)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 40, 0)
	view.add_child(sun)
	var n := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for m in meshes:
		var xf := _xform(m, src)
		var mats := []
		for s in m.mesh.get_surface_count():
			var mt = m.mesh.surface_get_material(s)
			mats.append(mt.resource_name if mt else "-")
		var pcs := _pieces(m.mesh, xf, weld)
		print("MESH %-34s verts %6d surf %d pieces %4d mats %s box %s" % [m.name, m.mesh.get_faces().size(), m.mesh.get_surface_count(), pcs.size(), mats, _xform(m, src) * m.get_aabb()])
		for p in pcs:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for ti in p.tris:
				for q in p.tri_pos[ti]:
					st.add_vertex(q)
			st.generate_normals()
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.from_hsv(rng.randf(), 0.55 + rng.randf() * 0.4, 0.55 + rng.randf() * 0.4)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = mat
			view.add_child(mi)
			if n < MAX_LABELS and p.box.size.length() > all.size.length() * 0.015:
				print("  #%-3d %-28s tris %5d box pos %s size %s" % [n, m.name, p.tris.size(), _v(p.box.position), _v(p.box.size)])
				var l := Label3D.new()
				l.text = str(n)
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.no_depth_test = true
				l.fixed_size = true
				l.pixel_size = 0.0012
				l.font_size = 26
				l.outline_size = 8
				l.modulate = Color.BLACK
				l.outline_modulate = Color.WHITE
				l.position = p.box.get_center()
				view.add_child(l)
				n += 1
	src.queue_free()
	# side view: look along the smallest axis, longest axis horizontal
	var s := all.size
	var axes := [0, 1, 2]
	axes.sort_custom(func(a, b): return s[a] > s[b])
	var long_ax: int = axes[0]
	var thin_ax: int = axes[2]
	var up_ax: int = axes[1]
	var dir := Vector3.ZERO
	dir[thin_ax] = 1.0
	var up := Vector3.ZERO
	up[up_ax] = 1.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = max(s[up_ax] * 1.15, s[long_ax] * 1.15 * 1000.0 / 2400.0)
	cam.near = 0.001
	cam.far = s.length() * 10.0
	view.add_child(cam)
	var c := all.get_center()
	cam.look_at_from_position(c + dir * s.length() * 2.0, c, up)
	print("view: long axis ", "XYZ"[long_ax], ", up ", "XYZ"[up_ax], ", from +", "XYZ"[thin_ax])
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("C:/RTVDev/inspect/%s.png" % gun)
	view.queue_free()
	await get_tree().process_frame


func _v(v: Vector3) -> String:
	return "(%.6f, %.6f, %.6f)" % [v.x, v.y, v.z]
