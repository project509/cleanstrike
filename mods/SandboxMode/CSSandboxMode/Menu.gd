# Sandbox Mode: the F6 menu. Toggles, world controls and an item spawner.
extends CanvasLayer

const SB = preload("res://CSSandboxMode/Mod.gd")
const TOGGLES := [["god", "God mode"], ["no_needs", "No hunger, thirst or cold"], ["stamina", "Infinite stamina"],
	["no_weight", "No weight limit"], ["ignored", "Enemies ignore you"]]

var gd = preload("res://Resources/GameData.tres")
var panel: Panel
var search: LineEdit
var list: ItemList
var status: Label
var shown := false
var _items: Array = []


func _ready() -> void:
	layer = 60
	panel = Panel.new()
	panel.size = Vector2(620, 520)
	panel.hide()
	add_child(panel)
	var title := Label.new()
	title.text = "Sandbox Mode  (F6 to close)"
	title.position = Vector2(16, 10)
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)
	# Left: cheats and world
	var left := VBoxContainer.new()
	left.position = Vector2(16, 44)
	left.size = Vector2(250, 460)
	panel.add_child(left)
	for t in TOGGLES:
		var c := CheckBox.new()
		c.text = t[1]
		c.focus_mode = Control.FOCUS_NONE
		c.button_pressed = SB.on(t[0])
		c.toggled.connect(func(v): SB.state[t[0]] = v)
		left.add_child(c)
	left.add_child(HSeparator.new())
	for b in [["+1 hour", SB.add_hours.bind(1)], ["Morning", SB.set_time.bind(800)], ["Night", SB.set_time.bind(2200)],
			["Next weather", SB.next_weather], ["Switch season", SB.switch_season],
			["Restock traders", SB.restock], ["Kill all enemies", SB.kill_all]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func():
			b[1].call()
			_status())
		left.add_child(btn)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	left.add_child(status)
	# Right: item spawner
	search = LineEdit.new()
	search.placeholder_text = "Search items"
	search.position = Vector2(286, 44)
	search.size = Vector2(318, 30)
	search.text_changed.connect(_fill)
	panel.add_child(search)
	list = ItemList.new()
	list.position = Vector2(286, 80)
	list.size = Vector2(318, 380)
	list.item_activated.connect(_spawn)
	panel.add_child(list)
	var hint := Label.new()
	hint.text = "Double-click to put it in your inventory"
	hint.position = Vector2(286, 466)
	hint.add_theme_font_size_override("font_size", 12)
	panel.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == OS.find_keycode_from_string(str(SB.setting("menu_key"))):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if get_node_or_null("/root/Map/Core") == null:
		return
	shown = not shown
	panel.visible = shown
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2.0
	if shown:
		gd.freeze = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		_fill(search.text)
		_status()
	elif not gd.interface:
		gd.freeze = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _fill(text: String) -> void:
	list.clear()
	_items = SB.find_items(text)
	for it in _items:
		list.add_item(str(it.name), it.icon)


func _spawn(index: int) -> void:
	if index >= 0 and index < _items.size():
		var ok := SB.spawn(_items[index])
		status.text = ("Added: " if ok else "No room: ") + str(_items[index].name)


func _status() -> void:
	var sim = get_node_or_null("/root/Simulation")
	if sim:
		status.text = "Day %d  %02d:%02d  %s  %s" % [sim.day, int(sim.time) / 100, int(sim.time) % 100, sim.weather, "Summer" if sim.season == 1 else "Winter"]
