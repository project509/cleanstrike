# Weapon Position: your offset on top of where the game holds the weapon,
# easing out when you aim so the sights stay where they belong.
extends "res://Scripts/Handling.gd"

const WP = preload("res://CSWeaponPosition/Mod.gd")

var wp_applied := Vector3.ZERO


func _physics_process(delta):
	position -= wp_applied
	super(delta)
	wp_applied = wp_applied.lerp(WP.offset(gameData), clampf(delta * 8.0, 0.0, 1.0))
	position += wp_applied
