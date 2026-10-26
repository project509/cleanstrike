# Weapons Pack tool: builds a gun from guns.gd into res://CSWeapons/<ID>/:
#   Parts.scn   one mesh per role (Body, Slide, Magazine...), vertices in the
#               base rig's skeleton space, textures embedded; root meta
#               "landmarks" (muzzle, sights, rail, ejector, magazine top...)
#   Icon.png, Icon_Magazine.png   inventory pictures (right side, muzzle right)
# and C:/RTVDev/gunsmith/<ID>_fit.png: the gun in the base rig's hands at the
# hip and aimed, the vanilla gun as a cyan ghost. GUN=<ID> picks one gun.
extends Node

const GUNS = preload("res://cs_tools/weapons/guns.gd")
const OUT := "res://CSWeapons/"
const TEX_SIZE := 1024


func _ready() -> void:
	get_tree().create_timer(900.0).timeout.connect(func(): print("STAGE timeout"); get_tree().quit())
	DirAccess.make_dir_recursive_absolute("C:/RTVDev/gunsmith")
	var only := OS.get_environment("GUN")
	var specs: Dictionary = GUNS.all()
	for id in specs:
		if only == "" or id == only:
			await build(id, specs[id])
	get_tree().quit()


static func xform_of(n: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	var x: Node = n
	while x and x != root:
		if x is Node3D:
			t = x.transform * t
		x = x.get_parent()
	return t


static func matches(name: String, rules: Array) -> bool:
	for r in rules:
		if r is String:
			if r.ends_with("*") and name.begins_with(r.trim_suffix("*")):
				return true
			if name == r:
				return true
	return false


# Connected pieces of one surface, welded by position: list of triangle-index lists.
static func pieces(arr: Array, weld: float) -> Array:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or idx.size() == 0:
		idx = PackedInt32Array(range(v.size()))
	var key_id := {}
	var wid := PackedInt32Array()
	wid.resize(v.size())
	for i in v.size():
		var k := Vector3i(roundi(v[i].x / weld), roundi(v[i].y / weld), roundi(v[i].z / weld))
		if not key_id.has(k):
			key_id[k] = key_id.size()
		wid[i] = key_id[k]
	var par := PackedInt32Array()
	par.resize(key_id.size())
	for i in par.size():
		par[i] = i
	var tri_count: int = idx.size() / 3
	for t in tri_count:
		var a: int = wid[idx[t * 3]]
		for j in [1, 2]:
			var b: int = wid[idx[t * 3 + j]]
			while par[a] != a:
				a = par[a]
			while par[b] != b:
				b = par[b]
			if a != b:
				par[b] = a
	var groups := {}
	for t in tri_count:
		var r: int = wid[idx[t * 3]]
		while par[r] != r:
			r = par[r]
		if not groups.has(r):
			groups[r] = []
		groups[r].append(t)
	return groups.values()


# Copy of the triangles `tris` of a surface, transformed by xf, compacted.
static func subset(arr: Array, tris: Array, xf: Transform3D) -> Array:
	var idx = arr[Mesh.ARRAY_INDEX]
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if idx == null or idx.size() == 0:
		idx = PackedInt32Array(range(v.size()))
	var remap := {}
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	for t in tris:
		for j in 3:
			var o: int = idx[t * 3 + j]
			if not remap.has(o):
				remap[o] = order.size()
				order.append(o)
			new_idx.append(remap[o])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var nb: Basis = xf.basis.inverse().transposed()
	var pv := PackedVector3Array()
	for o in order:
		pv.append(xf * v[o])
	out[Mesh.ARRAY_VERTEX] = pv
	if arr[Mesh.ARRAY_NORMAL] != null and arr[Mesh.ARRAY_NORMAL].size() == v.size():
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var pn := PackedVector3Array()
		for o in order:
			pn.append((nb * n[o]).normalized())
		out[Mesh.ARRAY_NORMAL] = pn
	if arr[Mesh.ARRAY_TANGENT] != null and arr[Mesh.ARRAY_TANGENT].size() == v.size() * 4:
		var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var pt := PackedFloat32Array()
		for o in order:
			var tv: Vector3 = (xf.basis * Vector3(tg[o * 4], tg[o * 4 + 1], tg[o * 4 + 2])).normalized()
			pt.append_array([tv.x, tv.y, tv.z, tg[o * 4 + 3]])
		out[Mesh.ARRAY_TANGENT] = pt
	for ch in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arr[ch] != null and arr[ch].size() == v.size():
			var uv: PackedVector2Array = arr[ch]
			var pu := PackedVector2Array()
			for o in order:
				pu.append(uv[o])
			out[ch] = pu
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


static func box_of(arrs: Array) -> AABB:
	var b := AABB()
	var first := true
	for a in arrs:
		for p in a[Mesh.ARRAY_VERTEX]:
			if first:
				b = AABB(p, Vector3.ZERO)
				first = false
			else:
				b = b.expand(p)
	return b


func _load(path: String, normal: bool, srgb: bool) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL if normal else (Image.COMPRESS_SOURCE_SRGB if srgb else Image.COMPRESS_SOURCE_GENERIC))
	return ImageTexture.create_from_image(img)


# One material per source material, from the textures prep_textures.py made
# (<material>_albedo / _normal / _orm (occlusion, roughness, metal) / _emission).
func _material(prep: String, name: String, t: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_texture = _load(prep + name + "_albedo.png", false, true)
	m.albedo_color = t.get("tint", Color.WHITE)
	var n := _load(prep + name + "_normal.png", true, false)
	if n:
		m.normal_enabled = true
		m.normal_texture = n
	var orm := _load(prep + name + "_orm.png", false, false)
	if orm:
		m.metallic = 1.0
		m.metallic_texture = orm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.roughness = 1.0
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = orm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	else:
		m.metallic = t.get("metal", 0.6)
		m.roughness = t.get("rough", 0.55)
	var e := _load(prep + name + "_emission.png", false, true)
	if e:
		m.emission_enabled = true
		m.emission_texture = e
		m.emission_energy_multiplier = t.get("glow", 1.0)
	return m


func build(id: String, s: Dictionary) -> void:
	print("=== ", id)
	var base_dir := "res://Items/Weapons/%s/" % s.base[0]
	var rig: Node3D = load(base_dir + s.base[1] + "_Rig.tscn").instantiate()
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var data: Resource = load(base_dir + s.base[1] + ".tres")
	# source -> rig orientation
	var fwd: Vector3 = s.fwd.normalized()
	var up: Vector3 = (s.up - fwd * s.up.dot(fwd)).normalized()
	var R := Basis(up.cross(fwd), up, fwd).transposed()
	var src: Node = load(s.src).instantiate()
	add_child(src)
	var rules: Dictionary = s.parts
	var mats := {}                    # source material -> our material
	var role_arrs := {}               # role -> {material: [arrays]}
	var all_arrs := []
	var named := {}                   # source mesh name -> [arrays] (for landmarks)
	var weld := 0.00001
	for m in src.find_children("*", "MeshInstance3D", true, false):
		var nm := str(m.name)
		if matches(nm, s.get("skip", [])):
			continue
		var xf: Transform3D = Transform3D(R, Vector3.ZERO) * xform_of(m, src)
		for si in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(si)
			var mat = m.mesh.surface_get_material(si)
			var mkey: String = mat.resource_name if mat else "default"
			var box_rules := []
			for role in rules:
				for r in rules[role]:
					if r is Dictionary and r.mesh == nm:
						box_rules.append([role, r.box])
			var groups: Array
			if box_rules.is_empty() and not s.has("drop_box"):
				var idx = arr[Mesh.ARRAY_INDEX]
				var n: int = (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
				groups = [range(n)]
			else:
				groups = pieces(arr, weld)
			for g in groups:
				var role := "Body"
				for role_name in rules:
					if matches(nm, rules[role_name]):
						role = role_name
				if not box_rules.is_empty() or s.has("drop_box"):
					var piece := subset(arr, g, xform_of(m, src))
					var c: Vector3 = box_of([piece]).get_center()
					var dropped := false
					for db in s.get("drop_box", []):
						if db.mesh == nm and db.box.has_point(c):
							dropped = true
					if dropped:
						continue
					for br in box_rules:
						if br[1].has_point(c):
							role = br[0]
				var a := subset(arr, g, xf)
				if not role_arrs.has(role):
					role_arrs[role] = {}
				if not role_arrs[role].has(mkey):
					role_arrs[role][mkey] = []
				role_arrs[role][mkey].append(a)
				all_arrs.append(a)
				if not named.has(nm):
					named[nm] = []
				named[nm].append(a)
	src.queue_free()
	# scale to the real length, then line the trigger up with the base gun's
	var full := box_of(all_arrs)
	var k: float = s.length / full.size.z if s.has("length") else s.get("scale", 1.0)
	var scaled := func(p: Vector3) -> Vector3: return p * k
	var trig_bone := -1
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).ends_with("_Trigger"):
			trig_bone = b
	var base_trig: Vector3 = sk.get_bone_global_rest(trig_bone).origin
	var ab := box_of(_role_list(role_arrs, s.align))
	var new_trig: Vector3 = Vector3(ab.get_center().x, ab.end.y, ab.get_center().z) * k
	var shift: Vector3 = base_trig - new_trig + s.get("offset", Vector3.ZERO)
	var F := Transform3D(Basis().scaled(Vector3.ONE * k), shift)
	for role in role_arrs:
		for mk in role_arrs[role]:
			for a in role_arrs[role][mk]:
				var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				for i in pv.size():
					pv[i] = F * pv[i]
				a[Mesh.ARRAY_VERTEX] = pv
	# materials
	for mk in s.tex:
		mats[mk] = _material(s.dir + "../prep/", mk, s.tex[mk])
	# meshes per role
	var root := Node3D.new()
	root.name = id
	for role in role_arrs:
		var am := ArrayMesh.new()
		for mk in role_arrs[role]:
			var st := SurfaceTool.new()
			for a in role_arrs[role][mk]:
				var part := ArrayMesh.new()
				part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
				st.append_from(part, 0, Transform3D())
			var arrs := st.commit_to_arrays()
			if arrs[Mesh.ARRAY_TANGENT] == null and arrs[Mesh.ARRAY_TEX_UV] != null:
				st = SurfaceTool.new()
				st.create_from_arrays(arrs)
				st.generate_tangents()
				arrs = st.commit_to_arrays()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
			var mat: Material = mats.get(mk, mats.values()[0] if mats.size() > 0 else null)
			am.surface_set_material(am.get_surface_count() - 1, mat)
		var mi := MeshInstance3D.new()
		mi.name = role
		mi.mesh = am
		mi.layers = 2
		root.add_child(mi)
		mi.owner = root
		print("  ", role, ": ", am.get_faces().size() / 3, " tris, box ", _box_str(box_of(_role_list(role_arrs, role))))
	# landmarks (rig skeleton space)
	var L := {}
	var mb := box_of(named[s.muzzle])
	L.muzzle = Vector3(mb.get_center().x, mb.get_center().y, mb.end.z)
	L.bore_y = mb.get_center().y
	if s.has("ejector"):
		var eb := box_of(named[s.ejector])
		L.ejector = Vector3(eb.position.x, eb.get_center().y, eb.get_center().z)
	if role_arrs.has("Magazine"):
		var gb := box_of(_role_list(role_arrs, "Magazine"))
		L.mag_top = Vector3(gb.get_center().x, gb.end.y, gb.get_center().z)
		L.mag_box = gb
	if role_arrs.has("SightFront"):
		var fb := box_of(_role_list(role_arrs, "SightFront"))
		L.sight_front = Vector3(fb.get_center().x, fb.end.y, fb.get_center().z)
		L.sight_front_box = fb
	if role_arrs.has("SightRear"):
		var rb := box_of(_role_list(role_arrs, "SightRear"))
		L.sight_rear = Vector3(rb.get_center().x, rb.end.y, rb.get_center().z)
		L.sight_rear_box = rb
	if s.has("sight_line"):              # sights that are not separate parts
		L.sight_front = F * s.sight_line
	if s.has("rail"):
		var rl: AABB = box_of(_select(named, s.rail, F))
		L.rail_top = rl.end.y
		L.rail_z = Vector2(rl.position.z, rl.end.z)
	L.box = box_of(all_arrs)
	L.scale = k
	root.set_meta("landmarks", L)
	root.set_meta("base", s.base)
	print("  landmarks ", L)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + id))
	await _icons(id, root, s)
	var ps := PackedScene.new()
	ps.pack(root)
	print("  saved ", ResourceSaver.save(ps, OUT + id + "/Parts.scn", ResourceSaver.FLAG_COMPRESS))
	await _fit(id, root, rig, sk, data, L)
	root.free()
	rig.free()


func _role_list(role_arrs: Dictionary, role: String) -> Array:
	var out := []
	if role_arrs.has(role):
		for mk in role_arrs[role]:
			out.append_array(role_arrs[role][mk])
	return out


func _select(named: Dictionary, rule, F: Transform3D) -> Array:
	var out := []
	for nm in named:
		if matches(nm, [rule] if rule is String else rule):
			out.append_array(named[nm])
	return out


func _box_str(b: AABB) -> String:
	return "pos (%.3f, %.3f, %.3f) size (%.3f, %.3f, %.3f)" % [b.position.x, b.position.y, b.position.z, b.size.x, b.size.y, b.size.z]


func _studio(size: Vector2i, transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.33, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.58)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -115, 0)
	key.light_energy = 1.1
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 70, 0)
	fill.light_energy = 0.35
	vp.add_child(fill)
	return vp


# Inventory pictures: the gun without its magazine, right side, muzzle right;
# the magazine on its own, slightly turned. Same framing as the game's icons.
func _icons(id: String, root: Node3D, s: Dictionary) -> void:
	var cells: Vector2i = s.get("cells", Vector2i(3, 2))
	var px := Vector2i(cells.x * 128, cells.y * 128)
	var vp := _studio(px * 2, true)
	var gun: Node3D = root.duplicate()
	vp.add_child(gun)
	var b := AABB()
	var first := true
	for c in gun.get_children():
		c.layers = 1
		if c.name == "Magazine":
			c.visible = false
			continue
		var cb: AABB = c.get_aabb()
		b = cb if first else b.merge(cb)
		first = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = max(b.size.y / 0.78, b.size.z / 0.9 * float(px.y) / float(px.x))
	vp.add_child(cam)
	var c3 := b.get_center()
	cam.look_at_from_position(c3 + Vector3(-2, 0, 0), c3, Vector3.UP)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(px.x, px.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT + id + "/Icon.png"))
	# icon pixel = (px/2) + ((z - c.z), -(y - c.y)) * px.y / cam.size
	root.set_meta("icon", {"cam_size": cam.size, "center": c3, "px": px})
	if gun.has_node("Magazine"):          # the magazine alone, same framing: drawn over the gun when loaded
		for c in gun.get_children():
			c.visible = c.name == "Magazine"
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var mimg := vp.get_texture().get_image()
		mimg.resize(px.x, px.y, Image.INTERPOLATE_LANCZOS)
		mimg.save_png(ProjectSettings.globalize_path(OUT + id + "/Icon_Inserted.png"))
	vp.queue_free()
	if root.has_node("Magazine"):
		var mcells: Vector2i = s.get("mag_cells", Vector2i(1, 1))
		var mpx := Vector2i(mcells.x * 128, mcells.y * 128)
		var vp2 := _studio(mpx * 2, true)
		var mag: MeshInstance3D = root.get_node("Magazine").duplicate()
		mag.layers = 1
		var holder := Node3D.new()
		vp2.add_child(holder)
		holder.add_child(mag)
		var mbx: AABB = mag.get_aabb()
		mag.position = -mbx.get_center()
		holder.rotation_degrees = Vector3(s.get("mag_tilt", 12.0), 0, 0)
		var cam2 := Camera3D.new()
		cam2.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam2.size = max(mbx.size.y, mbx.size.z) * 1.12
		vp2.add_child(cam2)
		cam2.look_at_from_position(Vector3(-2, 0, 0), Vector3.ZERO, Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2 := vp2.get_texture().get_image()
		img2.resize(mpx.x, mpx.y, Image.INTERPOLATE_LANCZOS)
		img2.save_png(ProjectSettings.globalize_path(OUT + id + "/Icon_Magazine.png"))
		vp2.queue_free()


# The gun in the base rig's hands (idle pose): hip, and aimed at the new iron
# sights; the vanilla gun drawn as a ghost in the hip view.
func _fit(id: String, root: Node3D, base_rig: Node3D, base_sk: Skeleton3D, data: Resource, L: Dictionary) -> void:
	var shots := []
	for mode in ["hip", "aim"]:
		var vp := _studio(Vector2i(1280, 720), false)
		var cam := Camera3D.new()
		cam.fov = 70
		cam.near = 0.01
		vp.add_child(cam)
		var mgr := Node3D.new()
		mgr.rotation_degrees = Vector3(0, 180, 0)
		cam.add_child(mgr)
		var rig: Node3D = base_rig.duplicate()
		for n in [rig] + rig.find_children("*", "", true, false):
			if n is AnimationTree:
				n.active = false
			if n.get_script() and not (n is AnimationPlayer):
				n.set_script(null)
		mgr.add_child(rig)
		var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
		var ghost := StandardMaterial3D.new()
		ghost.albedo_color = Color(0.2, 0.9, 1.0, 0.35)
		ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost.no_depth_test = true
		for m in sk.get_children():
			if m is MeshInstance3D and m.name != "Arms":
				if mode == "hip":
					m.material_override = ghost
				else:
					m.visible = false
			elif m is BoneAttachment3D:
				m.visible = false
		var parts: Node3D = root.duplicate()
		var att := BoneAttachment3D.new()
		att.bone_name = sk.get_bone_name(0)
		sk.add_child(att)
		for c in parts.get_children():
			var mi: MeshInstance3D = c.duplicate()
			mi.transform = sk.get_bone_global_rest(0).affine_inverse()
			att.add_child(mi)
		parts.free()
		for m in rig.find_children("*", "MeshInstance3D", true, false):
			m.layers = 1
		var ap: AnimationPlayer = rig.find_children("*", "AnimationPlayer", true, false)[0]
		for a in ap.get_animation_list():
			if a.ends_with("_Idle") and not a.contains("Inspect"):
				ap.play(a)
				ap.seek(0.0, true)
				ap.pause()
		var handling: Node3D = rig.get_node("Handling")
		# Handling.gd: position = (-target.x, target.y, -target.z), rotation as is
		var target: Vector3
		if mode == "hip":
			target = data.lowPosition
			handling.rotation_degrees = data.lowRotation
		else:
			var sp: Vector3 = _attach_pt(sk, L.get("sight_front", Vector3(0, 0.03, 0)))
			target = Vector3(-sp.x, -sp.y, data.aimPosition.z)
			print("  aim (iron sights) ", target, "  vanilla ", data.aimPosition)
			handling.rotation_degrees = data.aimRotation
		handling.position = Vector3(-target.x, target.y, -target.z)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var probe: Node3D = att.get_child(0)
		print("  [fit ", mode, "] cam current ", cam.current, ", part at ", cam.global_transform.affine_inverse() * probe.global_transform * Vector3(0, 0, 0.1), ", visible ", probe.is_visible_in_tree(), ", arms ", sk.get_node("Arms").is_visible_in_tree() if sk.has_node("Arms") else "none")
		shots.append(vp.get_texture().get_image())
		vp.queue_free()
	var out := Image.create(1280, 1440, false, shots[0].get_format())
	out.blit_rect(shots[0], Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	out.blit_rect(shots[1], Rect2i(0, 0, 1280, 720), Vector2i(0, 720))
	out.save_png("C:/RTVDev/gunsmith/%s_fit.png" % id)
	print("  fit saved")


# A skeleton-space point in the Attachments frame (where the game measures
# sight lines: aim = -height).
static func _attach_pt(sk: Skeleton3D, p: Vector3) -> Vector3:
	for c in sk.get_children():
		if c is BoneAttachment3D and c.name == "Attachments":
			return sk.get_bone_global_rest(sk.find_bone(c.bone_name)).affine_inverse() * p
	return p
