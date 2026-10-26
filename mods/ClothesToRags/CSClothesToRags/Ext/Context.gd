# Clothes to Rags: "Tear into rags" in the right-click menu of clothing.
extends "res://Scripts/Context.gd"

const CR = preload("res://CSClothesToRags/Mod.gd")

var cr_tear: Button


func Update(slotData: SlotData):
	super(slotData)
	if not CR.active():
		return
	if cr_tear == null or not is_instance_valid(cr_tear):
		cr_tear = useButton.duplicate(0)   # the game's look, without its signals
		cr_tear.name = "CR_Tear"
		cr_tear.text = "Tear into rags"
		cr_tear.disabled = false
		cr_tear.pressed.connect(_cr_on_tear)
		buttons.add_child(cr_tear)
	var item = interface.contextItem
	var hidden: bool = ResourceLoader.exists("res://TarkovLooting/TL.gd") and load("res://TarkovLooting/TL.gd").active() \
		and load("res://TarkovLooting/TL.gd").is_unknown(item)
	cr_tear.visible = interface.contextGrid != null and not hidden and CR.yield_of(item.slotData.itemData) > 0
	if cr_tear.visible:
		panel.size = Vector2(80.0, 0.0)
		panel.global_position = get_global_mouse_position() - Vector2(0, panel.size.y)
		centerPosition = get_global_mouse_position() - Vector2(-panel.size.x / 2, panel.size.y / 2)


func _cr_on_tear() -> void:
	if interface.visible and interface.contextItem:
		if CR.tear(interface, interface.contextItem, interface.contextGrid) > 0:
			interface.HideContext()
			interface.PlayClick()
			interface.Reset()
