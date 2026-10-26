# Sandbox Mode: enemies ignore you.
extends "res://Scripts/Sensor.gd"

const SBS = preload("res://CSSandboxMode/Mod.gd")


func PlayerValid() -> bool:
	if SBS.active() and SBS.on("ignored"):
		return false
	return super()
