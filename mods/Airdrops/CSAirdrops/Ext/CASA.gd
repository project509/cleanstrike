# Airdrops: when the crate lands it starts pouring red smoke.
extends "res://Scripts/CASA.gd"

const AD = preload("res://CSAirdrops/Mod.gd")


func Collided(body: Node3D):
	super(body)
	if AD.active():
		AD_MarkLanded()


func AD_MarkLanded() -> void:
	if airdrop == null or airdrop.get_node_or_null("CS_RedSmoke"):
		return
	var smoke := AD.make_smoke(float(AD.setting("smoke_minutes")))
	airdrop.add_child(smoke)
	smoke.top_level = true   # stays upright while the crate settles
	smoke.global_position = airdrop.global_position + Vector3(0, 0.5, 0)
	if bool(AD.setting("night_glow")):
		var glow := OmniLight3D.new()
		glow.name = "CS_RedGlow"
		glow.light_color = Color(1.0, 0.2, 0.1)
		glow.light_energy = 3.0
		glow.omni_range = 12.0
		smoke.add_child(glow)
		glow.position = Vector3(0, 1.0, 0)
	var timer := get_tree().create_timer(float(AD.setting("smoke_minutes")) * 60.0, false)
	timer.timeout.connect(func():
		if is_instance_valid(smoke):
			smoke.emitting = false)
