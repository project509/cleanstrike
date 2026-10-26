# Better Inventory and Equipment: a toolbar above the inventory (search,
# Sort, Stack) and a higher base carry weight.
extends "res://Scripts/Interface.gd"

const BI = preload("res://CSBetterInventory/Mod.gd")

var bi_bar: HBoxContainer
var bi_search: LineEdit
var bi_stack: Button


func Open():
	super()
	if not BI.active():
		if bi_bar:
			bi_bar.hide()
		return
	baseCarryWeight = float(BI.setting("carry_weight"))
	BI_Toolbar()
	bi_bar.show()
	bi_stack.visible = container != null
	BI_Filter(bi_search.text)


func BI_Toolbar() -> void:
	if bi_bar and is_instance_valid(bi_bar):
		return
	var parent = inventoryGrid.get_parent()
	bi_bar = HBoxContainer.new()
	bi_bar.name = "CS_Toolbar"
	bi_bar.position = Vector2(0, -66)
	bi_bar.size = Vector2(320, 30)
	bi_bar.add_theme_constant_override("separation", 6)
	parent.add_child(bi_bar)
	bi_search = LineEdit.new()
	bi_search.placeholder_text = "Search"
	bi_search.custom_minimum_size = Vector2(170, 30)
	bi_search.clear_button_enabled = true
	bi_search.text_changed.connect(BI_Filter)
	bi_search.text_submitted.connect(func(_t): bi_search.release_focus())
	bi_bar.add_child(bi_search)
	var sort := _bi_button("Sort", BI_Sort)
	sort.tooltip_text = "Sort the inventory by type and size"
	bi_stack = _bi_button("Stack", BI_QuickStack)
	bi_stack.tooltip_text = "Move items the open container already holds into it"


func _bi_button(label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(66, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		action.call()
		PlayClick())
	bi_bar.add_child(b)
	return b


func BI_Sort() -> bool:
	var ok := BI.sort_grid(inventoryGrid)
	if not ok:
		PlayError()
	UpdateStats(true)
	return ok


func BI_QuickStack() -> int:
	if container == null:
		return 0
	var moved := 0
	for item in BI.stackable_into(inventoryGrid, containerGrid):
		if AutoPlace(item, containerGrid, inventoryGrid, false):
			moved += 1
	if moved == 0:
		PlayError()
	BI_Filter(bi_search.text if bi_search else "")
	return moved


# Items that don't match the search fade out (both grids).
func BI_Filter(text: String) -> void:
	for grid in [inventoryGrid, containerGrid]:
		if grid:
			for c in grid.get_children():
				if c is Item:
					c.modulate.a = 1.0 if BI.matches(c, text) else 0.25
