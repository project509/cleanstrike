# CleanStrike Weapons Pack: puts the support hand on a pack gun. The base
# gun's animations place the left hand on the base gun's handguard,
# magazine and charging handle; near each of those the hand is moved by the
# difference to this gun's (two-bone arm IK, the hand keeps its angle and
# finger pose), and eased back in between. Runs right after the game's
# animation tree poses the skeleton each frame (a child of the skeleton).
extends Node

const HOLD := 0.16          # wrist to magazine middle while holding one (long magazines held low)

@export var upper := -1
@export var lower := -1
@export var wrist := -1
@export var body := -1
@export var mag := -1
@export var mag_point := Vector3.ZERO      # the base magazine's middle, in its bone's frame (where hands hold it)
@export var charge := -1
@export var rest_point := Vector3.ZERO     # where the hand rests on the base gun (gun body frame)
@export var rest_shift := Vector3.ZERO     # ...and how far this gun moves it
@export var mag_shift := Vector3.ZERO      # this gun's magazine vs the base gun's
@export var charge_shift := Vector3.ZERO   # this gun's charging handle vs the base gun's
# A magazine on top (P90): its bone follows the base magazine's motion turned
# over about the gun's side-to-side axis around the wells; the hand works it
# from above.
@export var flip_bone := -1
@export var flip := Transform3D()         # this gun's magazine bone at rest (gun body frame)
@export var flip_rest := Basis()          # the base magazine bone's rest orientation (gun body frame)
@export var flip_side := Vector3.ZERO     # the hand swings round this side of the gun
@export var flip_from := Vector3.ZERO     # the base magazine's seat (gun body frame)
@export var flip_to := Vector3.ZERO       # this gun's


func _ready() -> void:
	var rig := get_parent()
	while rig and not ("animator" in rig):
		rig = rig.get_parent()
	if rig and rig.get("animator"):
		rig.get("animator").mixer_applied.connect(_fit)


func _fit() -> void:
	var sk := get_parent() as Skeleton3D
	if sk == null or wrist < 0 or upper < 0 or lower < 0 or body < 0:
		return
	var g := sk.get_bone_global_pose(body)
	var w := sk.get_bone_global_pose(wrist)
	# one at a time: on the handguard; else working the magazine; else the handle
	var on_rest := _near(w.origin.distance_to(g * rest_point), 0.05, 0.12)
	var off := g.basis * rest_shift * on_rest
	var free := 1.0 - on_rest
	var turn := 0.0
	if flip_bone >= 0 and mag >= 0:
		# the magazine stays flat: near the gun the base magazine's travel is
		# mirrored up (off the top instead of out of the grip), its rear tipping
		# up as it lifts; away from the gun it is carried as usual, round the
		# gun's side in between. The hand moves with it, keeping its own angle.
		var v := sk.get_bone_global_pose(mag)
		var vl := g.affine_inverse() * v
		var disp := vl.origin - flip_from
		var f := _near(disp.length(), 0.07, 0.22)
		var mirrored := Vector3(disp.x, -disp.y, disp.z)
		var delta := (flip_to - flip_from) + (mirrored - disp) * f + flip_side * sin(PI * f)
		var rest_b := flip.basis                        # seated orientation (bone rest)
		var carried := (vl.basis * flip_rest.inverse()) * rest_b
		var tipped := Basis(Vector3.RIGHT, -0.35 * smoothstep(0.0, 0.08, disp.length())) * rest_b
		var mb := carried.slerp(tipped, f).orthonormalized()
		sk.set_bone_pose_position(flip_bone, vl.origin + delta)
		sk.set_bone_pose_rotation(flip_bone, mb.get_rotation_quaternion())
		turn = _near(w.origin.distance_to(v * mag_point), HOLD, HOLD + 0.08) * free
		if turn > 0.0:
			off += g.basis * delta * turn
			free *= 1.0 - turn
	elif mag >= 0 and mag_shift != Vector3.ZERO:
		var on_mag := _near(w.origin.distance_to(sk.get_bone_global_pose(mag) * mag_point), HOLD, HOLD + 0.08) * free
		off += g.basis * mag_shift * on_mag
		free *= 1.0 - on_mag
	if charge >= 0 and charge_shift != Vector3.ZERO:
		off += g.basis * charge_shift * _near(w.origin.distance_to(sk.get_bone_global_pose(charge).origin), 0.07, 0.13) * free
	if off.length_squared() > 0.0000002:
		_reach(sk, w, w.origin + off, w.basis)


static func _near(d: float, full: float, none: float) -> float:
	return 1.0 - smoothstep(full, none, d)


# Two-bone IK: the arm bends so the wrist (now at w) reaches target, then the
# hand takes the orientation `hand`.
func _reach(sk: Skeleton3D, w: Transform3D, target: Vector3, hand: Basis) -> void:
	var s := sk.get_bone_global_pose(upper)
	var e := sk.get_bone_global_pose(lower)
	var S := s.origin
	var E := e.origin
	var a := S.distance_to(E)
	var b := E.distance_to(w.origin)
	if a < 0.001 or b < 0.001:
		return
	var to := target - S
	var d := clampf(to.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to.normalized()
	var pole := (E - S) - dir * (E - S).dot(dir)            # keep the elbow's side
	pole = pole.normalized() if pole.length() > 0.0001 else Vector3.DOWN
	var ang := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var E2 := S + dir * (cos(ang) * a) + pole * (sin(ang) * a)
	_turn(sk, upper, (E - S).normalized(), (E2 - S).normalized())
	var e2 := sk.get_bone_global_pose(lower)
	var cur := (sk.get_bone_global_pose(wrist).origin - e2.origin).normalized()
	_turn(sk, lower, cur, (S + dir * d - e2.origin).normalized())
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(wrist))
	var local := parent.affine_inverse() * Transform3D(hand, sk.get_bone_global_pose(wrist).origin)
	sk.set_bone_pose_rotation(wrist, local.basis.get_rotation_quaternion())


# Turns a bone (about its own head) so `from` points along `to`.
static func _turn(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if from.is_equal_approx(to):
		return
	var gp := sk.get_bone_global_pose(bone)
	gp.basis = Basis(Quaternion(from, to)) * gp.basis
	var p := sk.get_bone_parent(bone)
	var local := gp if p < 0 else sk.get_bone_global_pose(p).affine_inverse() * gp
	sk.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
