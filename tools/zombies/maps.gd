extends SceneTree
# Bone maps from the humanoid profile to the Mixamo rig and the zombie's Biped rig.

const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Little"]
const MIX_F := {"Thumb": "Thumb", "Index": "Index", "Middle": "Middle", "Ring": "Ring", "Little": "Pinky"}
const STEPS := {"Thumb": ["Metacarpal", "Proximal", "Distal"]}
const STD := ["Proximal", "Intermediate", "Distal"]


func _init() -> void:
	var mix := {"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck", "Head": "Head",
		"LeftEye": "LeftEye", "RightEye": "RightEye"}
	var bip := {"Hips": "Pelvis", "Spine": "Spine1", "Chest": "Spine2", "UpperChest": "Ribcage", "Neck": "Neck", "Head": "Head",
		"Jaw": "HeadJaw", "LeftEye": "LEye", "RightEye": "HeadREye"}
	for side: String in ["Left", "Right"]:
		var s: String = side.left(1)
		mix[side + "Shoulder"] = side + "Shoulder"
		mix[side + "UpperArm"] = side + "Arm"
		mix[side + "LowerArm"] = side + "ForeArm"
		mix[side + "Hand"] = side + "Hand"
		mix[side + "UpperLeg"] = side + "UpLeg"
		mix[side + "LowerLeg"] = side + "Leg"
		mix[side + "Foot"] = side + "Foot"
		mix[side + "Toes"] = side + "ToeBase"
		bip[side + "Shoulder"] = s + "ArmCollarbone"
		bip[side + "UpperArm"] = s + "ArmUpperarm"
		bip[side + "LowerArm"] = s + "ArmForearm"
		bip[side + "Hand"] = s + "ArmPalm"
		bip[side + "UpperLeg"] = s + "Thigh" if s == "R" else "LLegThigh"
		bip[side + "LowerLeg"] = s + "Calf" if s == "R" else "LLegCalf"
		bip[side + "Foot"] = s + "Foot" if s == "R" else "LLegFoot"
		bip[side + "Toes"] = s + "Digit11" if s == "R" else "LLegDigit11"
		for fi in FINGERS.size():
			var f: String = FINGERS[fi]
			var steps: Array = STEPS.get(f, STD)
			for k in 3:
				mix[side + f + steps[k]] = "%sHand%s%d" % [side, MIX_F[f], k + 1]
				if f == "Thumb" and k == 2:
					continue        # the Biped thumb has two bones
				bip[side + f + steps[k]] = "%sArmDigit%d%d" % [s, fi + 1, k + 1]
	_save(mix, "mixamorig_", "res://cs_assets/zombies/maps/mixamo.tres")
	_save(bip, "Base Human", "res://cs_assets/zombies/maps/biped.tres")
	quit()


func _save(m: Dictionary, prefix: String, path: String) -> void:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for k in m:
		bm.set_skeleton_bone_name(k, prefix + m[k])
	print("saved ", path, " ", ResourceSaver.save(bm, path), " (", m.size(), " bones)")
