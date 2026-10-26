# CleanStrike Weapons Pack: puts the support hand on a pack gun. The base
# gun's animations place the left hand on the base gun's handguard,
# magazine and charging handle; near each of those the hand is moved by the
# difference to this gun's (two-bone arm IK, the hand keeps its angle and
# finger pose), and eased back in between.
extends SkeletonModifier3D

@export var upper := -1
@export var lower := -1
@export var wrist := -1
@export var body := -1
@export var mag := -1
@export var charge := -1
@export var rest_point := Vector3.ZERO     # where the hand rests on the base gun (gun body frame)
@export var rest_shift := Vector3.ZERO     # ...and how far this gun moves it
@export var mag_shift := Vector3.ZERO      # this gun's magazine vs the base gun's
@export var charge_shift := Vector3.ZERO   # this gun's charging handle vs the base gun's


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or wrist < 0 or upper < 0 or lower < 0 or body < 0:
		return
	var g := sk.get_bone_global_pose(body)
	var w := sk.get_bone_global_pose(wrist)
	var off := g.basis * rest_shift * _near(w.origin.distance_to(g * rest_point), 0.05, 0.12)
	if mag >= 0 and mag_shift != Vector3.ZERO:
		off += g.basis * mag_shift * _near(w.origin.distance_to(sk.get_bone_global_pose(mag).origin), 0.09, 0.17)
	if charge >= 0 and charge_shift != Vector3.ZERO:
		off += g.basis * charge_shift * _near(w.origin.distance_to(sk.get_bone_global_pose(charge).origin), 0.07, 0.13)
	if off.length_squared() > 0.0000002:
		_reach(sk, w, w.origin + off)


static func _near(d: float, full: float, none: float) -> float:
	return 1.0 - smoothstep(full, none, d)


func _reach(sk: Skeleton3D, w: Transform3D, target: Vector3) -> void:
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
	# the hand keeps its orientation
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(wrist))
	var local := parent.affine_inverse() * Transform3D(w.basis, sk.get_bone_global_pose(wrist).origin)
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
