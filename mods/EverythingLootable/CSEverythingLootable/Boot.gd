# Everything Lootable: as a map loads, props it knows get a container.
extends Node

const EL = preload("res://CSEverythingLootable/Mod.gd")


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Node3D and EL.PROPS.has(node.scene_file_path) and EL.active():
		EL.attach.call_deferred(node)
