# CleanStrike Weapons Pack: builds the pack's guns, magazines and ammo out of
# the game's own pieces (rigs, arms, animations, sounds, effects) and lets
# the game find them. Static, so it works without an autoload.
extends RefCounted

const MOD_ID := "cs_weapons_pack"
const VERSION := "0.6.0"
const DEFAULTS := {
	"in_loot": true,               # found in loot and at traders
}
const DIR := "res://CSWeaponsPack/Guns/"
const ART := "res://CSWeaponsPack/Ammo/"
const LOOT_MASTER := "res://Loot/LT_Master.tres"
const G = preload("res://CSWeaponsPack/Guns.gd")
const FOLD := -1.6            # the game's own fold angle for flip-up sights
const VIEW_UP := 1.0          # sign of a camera rotation that looks up
const SOUNDS := ["fireSemi", "fireAuto", "fireSuppressed", "tailOutdoor", "tailIndoor", "tailOutdoorSuppressed", "tailIndoorSuppressed"]

static var built := {}        # file -> PackedScene (pickups, rigs)
static var items := {}        # file -> ItemData (guns, magazines, ammo)
static var overrides := {}    # self-test hook: values here win over settings


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
	return fallback if c == null else c.get_setting(MOD_ID, key, fallback)


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])


static func base_path(g: Dictionary, suffix: String) -> String:
	return "res://Items/Weapons/%s/%s%s" % [g.base[0], g.base[1], suffix]


static func tex(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# A copy of a resource's typed array property with new contents.
static func _list(res: Resource, prop: String, contents: Array) -> void:
	var arr = res.get(prop).duplicate()
	arr.clear()
	for c in contents:
		arr.append(c)
	res.set(prop, arr)


static func gun_of(data) -> Dictionary:
	if data == null:
		return {}
	var gs := G.guns()
	for id in gs:
		if gs[id].file == str(data.file):
			return gs[id]
	return {}


# ---------------------------------------------------------------- ammo

static func ammo_item(aid: String) -> Resource:
	if items.has(aid):
		return items[aid]
	var a: Dictionary = G.ammo()[aid]
	var d: Resource = load(a.base).duplicate()
	d.file = aid
	for k in ["name", "inventory", "rotated", "equipment", "display"]:
		d.set(k, a.name)
	d.defaultAmount = a.box
	d.maxAmount = a.stack
	d.value = a.value
	d.weight = a.weight
	var icon := tex(ART + a.art + "_Icon.png")
	if icon:
		d.icon = icon
	d.tetris = _retexture(d.tetris, d.icon, aid)
	items[aid] = d
	var p: Node = load(str(a.base).replace(".tres", ".tscn")).instantiate()
	var box := tex(ART + a.art + "_Box.png")
	for m in p.find_children("*", "MeshInstance3D", true, false):
		var mat = m.get_active_material(0)
		if box and mat is BaseMaterial3D:
			mat = mat.duplicate()
			mat.albedo_texture = box
			m.material_override = mat
	_set_slot(p, d, a.box)
	p.name = aid
	built[aid] = _pack(p)
	return d


# ---------------------------------------------------------------- guns

static func ammo_for(g: Dictionary, base_data: Resource) -> Resource:
	var a: String = g.get("ammo", "")
	if a == "":
		return base_data.ammo
	if a.begins_with("res://"):
		return load(a)
	return ammo_item(a)


static func base_magazine(base_data: Resource) -> Resource:
	for c in base_data.compatible:
		if c and c.subtype == "Magazine":
			return c
	return null


static func build_gun(id: String) -> void:
	var g: Dictionary = G.guns()[id]
	if items.has(g.file) or not ResourceLoader.exists(DIR + id + "/Parts.scn"):
		return
	var src: Node3D = load(DIR + id + "/Parts.scn").instantiate()
	var L: Dictionary = src.get_meta("landmarks")
	var base_data: Resource = load(base_path(g, ".tres"))
	var ammo := ammo_for(g, base_data)
	var bmag := base_magazine(base_data)
	var mag := _magazine(id, g, src, L, ammo, bmag)
	var rig: Node3D = load(base_path(g, "_Rig.tscn")).instantiate()
	var fit := _fit_rig(rig, src, L, g)
	var d: Resource = base_data.duplicate()
	d.file = g.file
	d.name = g.name
	d.inventory = g.name
	d.rotated = g.short
	d.equipment = g.short
	d.display = g.get("display", g.short)
	for k in g.get("data", {}):
		d.set(k, g.data[k])
	for k in g.get("shift", {}):                 # carry poses moved for this gun's shape
		d.set(k, d.get(k) + g.shift[k])
	d.ammo = ammo
	d.magazineSize = mag.maxAmount
	var compat: Array = [mag]
	for a in fit.attachments:
		if not compat.has(a):
			compat.append(a)
	_list(d, "compatible", compat)
	d.aimPosition = Vector3(-fit.aim.x, -fit.aim.y, base_data.aimPosition.z)
	if fit.fold:
		d.foldSights = true
		d.foldSightsRotation = FOLD
	if g.get("optics", "base") == "rail":
		d.useMount = false
	_feel(d, g.get("feel", {}))
	var icon := tex(DIR + id + "/Icon.png")
	d.icon = icon
	d.tetris = _gun_tetris(base_data, icon, tex(DIR + id + "/Icon_Inserted.png"), bmag, mag, compat, src, fit)
	rig.set("data", d)
	rig.name = g.file + "_Rig"
	items[g.file] = d
	built[g.file + "_Rig"] = _pack(rig)
	built[g.file] = _gun_pickup(g, d, src, L, fit, bmag, mag)
	src.free()


# Recoil and sound from the base gun, tuned to this one.
static func _feel(d: Resource, f: Dictionary) -> void:
	var r: float = f.get("recoil", 1.0)
	d.verticalRecoil *= r
	d.horizontalRecoil *= r
	d.kick *= f.get("kick", r)
	var rec: float = f.get("recovery", 1.0)
	d.rotationRecovery *= rec
	d.kickRecovery *= rec
	var pitch: float = f.get("pitch", 1.0)
	var vol: float = f.get("volume", 0.0)
	if pitch != 1.0 or vol != 0.0:
		for k in SOUNDS:
			d.set(k, _voiced(d.get(k), pitch, vol))


static func _voiced(ev, pitch: float, vol: float):
	if ev == null:
		return null
	var e = ev.duplicate()
	var clips: Array[AudioStreamWAV] = []
	for c in ev.audioClips:
		var w: AudioStreamWAV = c.duplicate()
		w.mix_rate = int(c.mix_rate * pitch)
		clips.append(w)
	e.audioClips = clips
	e.volume = clampf(ev.volume + vol, -20.0, 20.0)
	return e


static func _bone(sk: Skeleton3D, ends: Array) -> int:
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		for e in ends:
			if n.ends_with(e):
				return b
	return -1


static func _skin_bone(m: MeshInstance3D, sk: Skeleton3D) -> int:
	if m and m.skin:
		for i in m.skin.get_bind_count():
			var n := str(m.skin.get_bind_name(i))
			var b := sk.find_bone(n) if n != "" else m.skin.get_bind_bone(i)
			if b >= 0:
				var bn := sk.get_bone_name(b)
				if bn.contains("Magazine") and not bn.contains("Release") and not bn.contains("Well"):
					return b
	return _bone(sk, ["_Magazine"])


static func _add_bone(sk: Skeleton3D, name: String, parent: int, global: Transform3D) -> int:
	sk.add_bone(name)
	var i := sk.get_bone_count() - 1
	sk.set_bone_parent(i, parent)
	var local := sk.get_bone_global_rest(parent).affine_inverse() * global
	sk.set_bone_rest(i, local)
	sk.set_bone_pose_position(i, local.origin)
	sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
	sk.set_bone_pose_scale(i, local.basis.get_scale())
	return i


# A gun's vanilla meshes are emptied (the rig and its animations still refer
# to them) and the new parts ride the bones that move them.
static func _fit_rig(rig: Node3D, src: Node3D, L: Dictionary, g: Dictionary) -> Dictionary:
	var sk: Skeleton3D = rig.get("skeleton")
	var arms: MeshInstance3D = rig.get("arms")
	var old_mag: MeshInstance3D = rig.get("magazine")
	var info := {"fold": false, "attachments": [], "optic_pos": {}, "base_muzzle": Vector3.ZERO, "rail_shift": 0.0}
	var mag_bone := _skin_bone(old_mag, sk)
	var old_mag_box: AABB = old_mag.get_aabb() if old_mag and old_mag.mesh else AABB()
	var base_box := AABB()
	var base_top := -INF
	var first := true
	for m in sk.get_children():
		if m is MeshInstance3D and m != arms and m.mesh and m.visible:
			var b: AABB = m.get_aabb()
			base_box = b if first else base_box.merge(b)
			first = false
			if str(m.name).ends_with("Body"):
				base_top = b.end.y
	info.base_box = base_box
	var refs: BoneAttachment3D = sk.get_node_or_null("References")
	var rb := Transform3D()
	if refs:
		rb = sk.get_bone_global_rest(sk.find_bone(refs.bone_name))
		if refs.has_node("Muzzle"):
			info.base_muzzle = rb * refs.get_node("Muzzle").position
	for m in sk.get_children():
		if m is MeshInstance3D and m != arms:
			m.mesh = null
	var bones := {
		"Body": maxi(0, _bone(sk, ["_Body"])),
		"Slide": rig.get("slideIndex") if rig.get("dynamicSlide") else _bone(sk, ["_Slide", "_Bolt"]),
		"Trigger": _bone(sk, ["_Trigger"]),
		"Hammer": _bone(sk, ["_Hammer"]),
		"Magazine": mag_bone,
		"MagRelease": _bone(sk, ["_Magazine_Release", "_Release_Lever", "_Mag_Release"]),
		"Charge": _bone(sk, ["_Charging_Handle", "_Charge", "_Cocking_Handle"]),
		"Selector": rig.get("selectorIndex") if rig.get("dynamicSelector") else _bone(sk, ["_Selector", "_Safety"]),
		"BoltRelease": _bone(sk, ["_Slide_Release", "_Bolt_Release", "_Bolt_Catch"]),
	}
	bones.Bolt = bones.Slide
	if g.get("fold", false) and L.has("sight_rear_box") and L.has("sight_front_box"):
		# hinges at the foot of each sight; the rear one turned round so the
		# game's single fold angle lays it forward and the front one back
		var body: int = bones.Body
		var rbx: AABB = L.sight_rear_box
		var fbx: AABB = L.sight_front_box
		var rp := _add_bone(sk, "CS_Sight_Rear_Pivot", body, Transform3D(Basis(Vector3.UP, PI), Vector3(rbx.get_center().x, rbx.position.y, rbx.get_center().z)))
		var fp := _add_bone(sk, "CS_Sight_Front_Pivot", body, Transform3D(Basis(), Vector3(fbx.get_center().x, fbx.position.y, fbx.get_center().z)))
		bones.SightRear = _add_bone(sk, "CS_Sight_Rear", rp, sk.get_bone_global_rest(rp))
		bones.SightFront = _add_bone(sk, "CS_Sight_Front", fp, sk.get_bone_global_rest(fp))
		rig.set("backSightIndex", bones.SightRear)
		rig.set("frontSightIndex", bones.SightFront)
		info.fold = true
	elif g.get("slide_sights", false):
		bones.SightRear = bones.Slide
		bones.SightFront = bones.Slide
	var atts := {}
	for part in src.get_children():
		var role := str(part.name)
		if role == "Round":
			continue
		var b: int = bones.get(role, bones.Body)
		if b < 0:
			b = bones.Body
		if not atts.has(b):
			var a := BoneAttachment3D.new()
			a.name = "CS_" + sk.get_bone_name(b)
			a.bone_name = sk.get_bone_name(b)
			sk.add_child(a)
			a.owner = rig
			atts[b] = a
		var mi := MeshInstance3D.new()
		mi.name = "CS_" + role
		mi.mesh = part.mesh
		mi.layers = arms.layers
		mi.transform = sk.get_bone_global_rest(b).affine_inverse()
		atts[b].add_child(mi)
		mi.owner = rig
		if role == "Magazine":
			rig.set("magazine", mi)
			mi.visible = false
	# the support hand onto this gun's handguard, magazine and charging handle
	var hf: Node = load("res://CSWeaponsPack/HandFit.gd").new()
	hf.name = "CS_HandFit"
	var brest := sk.get_bone_global_rest(bones.Body)
	var to_body := brest.basis.inverse()
	hf.upper = sk.find_bone("Arm_Upper_L")
	hf.lower = sk.find_bone("Arm_Lower_L")
	hf.wrist = sk.find_bone("Wrist_L")
	hf.body = bones.Body
	hf.mag = bones.Magazine
	hf.charge = bones.Charge
	if L.has("hand_rest") and g.get("hand", true):
		hf.rest_point = brest.affine_inverse() * L.hand_rest
		hf.rest_shift = to_body * Vector3(0, L.get("hand_dy", 0.0), 0)
	hf.mag_shift = to_body * L.get("mag_shift", Vector3.ZERO)
	hf.charge_shift = to_body * L.get("charge_shift", Vector3.ZERO)
	sk.add_child(hf)
	hf.owner = rig
	# muzzle, aiming ray and ejection on the new gun
	if refs:
		var to_ref := rb.affine_inverse()
		var shift := Vector3.ZERO
		var muzzle: Node3D = refs.get_node_or_null("Muzzle")
		if muzzle:
			var old := muzzle.position
			muzzle.position = to_ref * L.muzzle
			shift = muzzle.position - old
		var ray: Node3D = refs.get_node_or_null("Raycast")
		if ray:
			ray.position += shift
		var ej: Node3D = refs.get_node_or_null("Ejector")
		if ej and L.has("ejector"):
			ej.position = to_ref * L.ejector
	# the rounds showing at the top of the magazine: this gun's, seated in it
	var am: BoneAttachment3D = sk.get_node_or_null("Ammo_Magazine")
	if am and am.has_node("Bullets") and src.has_node("Round") and L.has("round_top"):
		_seat(am.get_node("Bullets"), src.get_node("Round").mesh, sk.get_bone_global_rest(sk.find_bone(am.bone_name)).affine_inverse(), L, arms.layers, rig)
	_fit_attachments(rig, sk, L, g, base_top, info)
	# where the sights are, in the frame the game aims with
	var sight: Vector3 = L.get("sight_front", Vector3(0, L.get("bore_y", 0.0), 0))
	info.aim = sight
	var holder: BoneAttachment3D = rig.get("attachments")
	if holder:
		info.aim = sk.get_bone_global_rest(sk.find_bone(holder.bone_name)).affine_inverse() * sight
	return info


# Optics, lasers and muzzle devices: moved onto the new gun's rail and
# muzzle, swapped for the KAR-21's rail optics, or removed.
static func _fit_attachments(rig: Node3D, sk: Skeleton3D, L: Dictionary, g: Dictionary, base_top: float, info: Dictionary) -> void:
	var holder: BoneAttachment3D = rig.get("attachments")
	if holder == null:
		return
	var ab := sk.get_bone_global_rest(sk.find_bone(holder.bone_name))
	var mode: String = g.get("optics", "base")
	var rail: bool = L.has("rail_top") and mode != "none"
	if rail and base_top > -INF:
		info.rail_shift = L.rail_top - base_top
	if mode == "rail" and rail:
		for c in holder.get_children():
			var ad = c.get("attachmentData")
			if c.name == "Mount" or (ad and ad.subtype in ["Optic", "Laser"]):
				holder.remove_child(c)
				c.free()
		var donor: Node3D = load("res://Items/Weapons/%s/%s_Rig.tscn" % G.RAIL_DONOR).instantiate()
		var dsk: Skeleton3D = donor.get("skeleton")
		var dh: BoneAttachment3D = donor.get("attachments")
		var dab := dsk.get_bone_global_rest(dsk.find_bone(dh.bone_name))
		var dtop := -INF
		for m in dsk.get_children():
			if m is MeshInstance3D and str(m.name).ends_with("Body") and m.mesh:
				dtop = m.get_aabb().end.y
		var to_att := ab.affine_inverse()
		for c in dh.get_children():
			var ad = c.get("attachmentData")
			if ad and ad.subtype in ["Optic", "Laser"]:
				var n: Node3D = c.duplicate()
				var p: Vector3 = dab * c.position + Vector3(0, L.rail_top - dtop, 0)
				if L.has("rail_z"):                # on this gun's rail, and slides only along it
					p.z = clampf(p.z, L.rail_z.x + 0.03, L.rail_z.y - 0.03)
					if "minPosition" in n:
						n.minPosition = (to_att * Vector3(p.x, p.y, L.rail_z.x + 0.02)).z
						n.maxPosition = (to_att * Vector3(p.x, p.y, L.rail_z.y - 0.02)).z
				n.position = to_att * p
				if "defaultPosition" in n:
					n.defaultPosition = n.position.z
				holder.add_child(n)
				n.owner = rig
		donor.free()
	for c in holder.get_children():
		var ad = c.get("attachmentData")
		var sub: String = ad.subtype if ad else ("Mount" if c.name == "Mount" else "")
		var keep := true
		if sub in ["Optic", "Laser", "Mount"]:
			keep = rail and not (sub == "Mount" and mode == "rail")
			if keep and mode == "base":
				c.position += ab.basis.inverse() * Vector3(0, info.rail_shift, 0)
		elif sub == "Muzzle":
			keep = g.get("muzzles", true)
			if keep:
				c.position += ab.basis.inverse() * (L.muzzle - info.base_muzzle)
		if not keep:
			holder.remove_child(c)
			c.free()
			continue
		if ad and not info.attachments.has(ad):
			info.attachments.append(ad)
			info.optic_pos[str(ad.file)] = [sub, ab * c.position]


# A new magazine (or the vanilla one this gun takes).
static func _magazine(id: String, g: Dictionary, src: Node3D, L: Dictionary, ammo: Resource, bmag: Resource) -> Resource:
	if g.magazine is String:
		return load(g.magazine)
	var m: Dictionary = g.magazine
	if items.has(m.file):
		return items[m.file]
	var md: Resource = bmag.duplicate()
	md.file = m.file
	md.name = m.name
	_list(md, "compatible", [ammo])
	md.defaultAmount = m.rounds
	md.maxAmount = m.rounds
	md.value = m.get("value", bmag.value)
	md.weight = m.get("weight", bmag.weight)
	if m.has("cells"):
		md.size = m.cells
	md.icon = tex(DIR + id + "/Icon_Magazine.png")
	md.tetris = _retexture(bmag.tetris, md.icon, m.file)
	items[m.file] = md
	# lying in the world: the vanilla magazine's pickup with this one's model
	var p: Node3D = load(str(bmag.resource_path).replace(".tres", ".tscn")).instantiate()
	var lod0: MeshInstance3D = p.get_node_or_null("LOD0")
	var pbox: AABB = lod0.transform * lod0.get_aabb() if lod0 else AABB()
	var mbox: AABB = L.mag_box
	var off: Vector3 = pbox.get_center() - mbox.get_center()
	for n in ["LOD0", "LOD1"]:
		var mi: MeshInstance3D = p.get_node_or_null(n)
		if mi:
			mi.mesh = src.get_node("Magazine").mesh
			mi.transform = Transform3D(Basis(), off)
	var col: CollisionShape3D = p.get_node_or_null("Collision")
	if col and col.shape is BoxShape3D:
		col.shape = col.shape.duplicate()
		col.shape.size = mbox.size
		col.position = mbox.get_center() + off
	var bullets: Node3D = p.get_node_or_null("Bullets")
	if bullets and src.has_node("Round") and L.has("round_top"):
		var layers: int = lod0.layers if lod0 else 1
		_seat(bullets, src.get_node("Round").mesh, Transform3D(Basis(), off), L, layers, p)
	_set_slot(p, md, -1)
	p.name = m.file
	built[m.file] = _pack(p)
	return md


# The gun lying in the world: the base gun's pickup with this model; the
# attachment models on it moved like the rig's.
static func _gun_pickup(g: Dictionary, d: Resource, src: Node3D, L: Dictionary, fit: Dictionary, bmag: Resource, mag: Resource) -> PackedScene:
	var p: Node3D = load(base_path(g, ".tscn")).instantiate()
	var lod0: MeshInstance3D = p.get_node("LOD0")
	var pbox: AABB = lod0.transform * lod0.get_aabb()
	var bbox: AABB = fit.base_box
	var off: Vector3 = pbox.get_center() - bbox.get_center()
	var whole := ArrayMesh.new()
	for part in src.get_children():
		if part.name == "Magazine" or part.name == "Round":
			continue
		var pm: Mesh = part.mesh
		for s in pm.get_surface_count():
			whole.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pm.surface_get_arrays(s))
			whole.surface_set_material(whole.get_surface_count() - 1, pm.surface_get_material(s))
	for n in ["LOD0", "LOD1"]:
		var mi: MeshInstance3D = p.get_node_or_null(n)
		if mi:
			mi.mesh = whole
			mi.transform = Transform3D(Basis(), off)
	if p.get("mesh") != null:
		p.set("mesh", lod0)
	var col: CollisionShape3D = p.get_node_or_null("Collision")
	var box: AABB = L.box
	if col and col.shape is BoxShape3D:
		col.shape = col.shape.duplicate()
		col.shape.size = box.size
		col.position = box.get_center() + off
	var holder: Node3D = p.get_node_or_null("Attachments")
	if holder:
		for c in holder.get_children():
			var nm := str(c.name)
			if bmag and nm == str(bmag.file):
				c.name = str(mag.file)
				c.transform = Transform3D(Basis(), off)
				for lod in c.get_children():
					if lod is MeshInstance3D:
						lod.mesh = src.get_node("Magazine").mesh
						lod.transform = Transform3D()
			elif fit.optic_pos.has(nm) and g.get("optics", "base") != "rail":
				if fit.optic_pos[nm][0] == "Muzzle":
					c.position += L.muzzle - fit.base_muzzle
				else:
					c.position.y += fit.rail_shift
			else:
				holder.remove_child(c)
				c.free()
	_set_slot(p, d, -1)
	p.name = g.file
	return _pack(p)


# The inventory picture: the base gun's, with this gun's icon and its
# magazine, optic and muzzle pictures placed on this gun.
static func _gun_tetris(base_data: Resource, icon: Texture2D, inserted: Texture2D, bmag: Resource, mag: Resource, compat: Array, src: Node3D, fit: Dictionary) -> PackedScene:
	var s: Sprite2D = base_data.tetris.instantiate()
	s.texture = icon
	var im: Dictionary = src.get_meta("icon")
	var ppm: float = float(im.px.y) / float(im.cam_size)
	var c3: Vector3 = im.center
	var L: Dictionary = src.get_meta("landmarks")
	# how big the base gun's picture was, to size its attachment pictures
	var k := 1.0
	var bimg: Image = base_data.icon.get_image() if base_data.icon else null
	if bimg:
		if bimg.is_compressed():
			bimg.decompress()
		var used := bimg.get_used_rect()
		if used.size.x > 0 and fit.base_box.size.z > 0:
			k = ppm / (float(used.size.x) / fit.base_box.size.z)
	var files := []
	for a in compat:
		files.append(str(a.file))
	for c in s.get_children():
		var nm := str(c.name)
		if bmag and nm == str(bmag.file):
			c.name = str(mag.file)
			if c is Sprite2D and inserted:
				c.texture = inserted
				c.position = Vector2.ZERO
				c.scale = Vector2.ONE
				c.offset = Vector2.ZERO
				c.rotation = 0.0
		elif fit.optic_pos.has(nm) and c is Node2D:
			var info: Array = fit.optic_pos[nm]
			var p: Vector3 = L.muzzle if info[0] == "Muzzle" else info[1]
			c.scale *= k
			c.position = Vector2((p.z - c3.z) * ppm, -(p.y - c3.y) * ppm)
			if info[0] == "Muzzle" and c is Sprite2D and c.texture:
				c.position.x += c.texture.get_width() * c.scale.x * 0.5
		elif nm != "Camo" and not files.has(nm):
			s.remove_child(c)
			c.free()
	s.name = str(base_data.file)
	_own(s, s)
	return _pack(s)


# ---------------------------------------------------------------- helpers

# The two rounds the game shows at the top of a magazine (child 1 is the top
# round, shown alone when one is left; child 0 the one under it).
static func _seat(bullets: Node3D, mesh: Mesh, to_local: Transform3D, L: Dictionary, layers: int, owner: Node) -> void:
	for c in bullets.get_children():
		bullets.remove_child(c)
		c.free()
	bullets.transform = Transform3D()
	for p in [L.round_second, L.round_top]:
		var r := MeshInstance3D.new()
		r.name = "CS_Round"
		r.mesh = mesh
		r.layers = layers
		r.transform = to_local * Transform3D(Basis(), p)
		bullets.add_child(r)
		r.owner = owner


static func _retexture(scene: PackedScene, texture: Texture2D, name: String) -> PackedScene:
	var s: Node = scene.instantiate()
	if texture and s is Sprite2D:
		s.texture = texture
	s.name = name
	_own(s, s)
	return _pack(s)


static func _set_slot(p: Node, d: Resource, amount: int) -> void:
	var sd = p.get("slotData")
	if sd:
		sd = sd.duplicate()
		sd.itemData = d
		if amount >= 0:
			sd.amount = amount
		p.set("slotData", sd)


static func _own(n: Node, owner: Node) -> void:
	for c in n.get_children():
		if c.owner == null:
			c.owner = owner
		_own(c, owner)


static func _pack(n: Node) -> PackedScene:
	var ps := PackedScene.new()
	ps.pack(n)
	n.free()
	return ps


# ---------------------------------------------------------------- the game

# Builds everything and lets the game find it: Database lookups by file name,
# and the master loot list (loot spawns, traders) like any vanilla item.
static func register() -> void:
	for id in G.guns():
		build_gun(id)
	var reg: Dictionary = Engine.get_meta("cs_items") if Engine.has_meta("cs_items") else {}
	for f in built:
		reg[f] = built[f]
	Engine.set_meta("cs_items", reg)
	var lt = load(LOOT_MASTER)
	if lt and bool(setting("in_loot")):
		for f in items:
			if str(f).begins_with("CS_") and not lt.items.has(items[f]):
				lt.items.append(items[f])


static func unregister() -> void:
	var lt = load(LOOT_MASTER)
	if lt:
		for f in items:
			lt.items.erase(items[f])


static func release() -> void:
	built.clear()
	items.clear()


# After every shot of one of our guns: its own muzzle flash size and how
# long the shot shakes the view.
static func on_fire(rig: Node) -> void:
	var g := gun_of(rig.get("data"))
	if g.is_empty():
		return
	var f: Dictionary = g.get("feel", {})
	if f.has("impulse"):
		rig.set_deferred("fireImpulse", f.impulse)
	# the view itself kicks (and eases back), and the aim climbs for good
	var head: Node3D = rig.get_node_or_null("/root/Map/Core/Controller/Pelvis/Riser/Head")
	if head and f.has("view_kick"):
		var imp: Node3D = head.get_node_or_null("Bob/Impulse")
		if imp and "currentRotation" in imp:
			imp.currentRotation = Vector3(f.view_kick * VIEW_UP, randf_range(-0.25, 0.25) * f.view_kick, 0.0)
	if head and f.has("climb"):
		head.rotation.x = clampf(head.rotation.x + f.climb * VIEW_UP, deg_to_rad(-90), deg_to_rad(90))
	var flash: float = f.get("flash", 1.0)
	var muzzle: Node3D = rig.get("muzzle")
	if muzzle and flash != 1.0:
		var n := muzzle.get_child_count()
		for i in range(n - 1, maxi(-1, n - 3), -1):
			var fx = muzzle.get_child(i)
			if fx is Node3D and not fx.has_meta("cs_scaled"):
				fx.set_meta("cs_scaled", true)
				fx.scale *= flash
