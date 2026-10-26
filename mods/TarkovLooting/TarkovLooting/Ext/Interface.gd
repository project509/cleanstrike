# Tarkov Looting: Tarkov-style looting for the inventory screen.
#  - Containers and bodies must be searched; items reveal one at a time,
#    top-left to bottom-right, and search progress is kept per container.
#  - The item being searched shows as a faint grey ghost under the spinner.
#  - Items you have never examined show as flat silhouettes. Middle-click
#    (or right-click -> Examine) to identify them; knowledge is kept.
#  - Unknown items can be moved, stacked and dropped, but not used,
#    equipped or combined until examined. Weapons, magazines, knives and
#    grenades are the exception: they work while unknown.
extends "res://Scripts/Interface.gd"

const TL = preload("res://TarkovLooting/TL.gd")
const Spinner = preload("res://TarkovLooting/SearchSpinner.gd")

const OPEN_DELAY := 0.5
const EMPTY_SEARCH_TIME := 0.9

var tl_spinner: Control
var tl_target = null          # hidden Item currently being searched
var tl_left := 0.0            # seconds until tl_target is revealed
var tl_empty_left := -1.0     # short "searching" pass for empty containers
var tl_filling := false
var tl_examines := {}         # instance id -> {item, t, total}
var tl_dots := 0.0
var tl_rummage: AudioStreamPlayer   # looping search sound
var tl_queue_label: Label           # examine queue, top right of the screen


# ---------------------------------------------------------------- open/close

func Open():
	super()
	if not TL.active():
		return
	_tl_setup()
	if not TL.is_seeded():
		_tl_seed_knowledge()
	if container:
		_tl_begin_container()
	_tl_refresh_items()


func Close():
	# Examining carries on with the inventory closed (items from the
	# container you just left drop out of the queue as they're freed).
	_tl_stop_search()
	super()


func FillContainerGrid():
	tl_filling = true
	super()
	tl_filling = false


# Containers keep their items as SlotData between openings; carry our
# hidden flag across by tagging the SlotData copies the game stores.
func StorageContainerGrid():
	super()
	if not TL.active() or container == null:
		return
	var children: Array = containerGrid.get_children()
	for i in min(children.size(), container.storage.size()):
		container.storage[i].set_meta("tl_hidden", TL.is_hidden(children[i]))


func LoadGridItem(slotData, targetGrid, gridPosition):
	var before: int = targetGrid.get_child_count()
	super(slotData, targetGrid, gridPosition)
	_tl_tag_new(slotData, targetGrid, before)


func Create(slotData, targetGrid, useDrop):
	var before = targetGrid.get_child_count() if targetGrid else 0
	var ok = super(slotData, targetGrid, useDrop)
	_tl_tag_new(slotData, targetGrid, before)
	return ok


func _tl_tag_new(slotData, targetGrid, before: int) -> void:
	if not tl_filling or targetGrid != containerGrid or not TL.active():
		return
	if targetGrid.get_child_count() <= before:
		return
	var item = targetGrid.get_child(targetGrid.get_child_count() - 1)
	if not (item is Item):
		return
	var hidden := false
	if TL.should_search(container):
		hidden = bool(slotData.get_meta("tl_hidden", true)) if container.storaged else not bool(container.get_meta("tl_searched", false))
		# A body's weapon and worn gear are in plain sight; only what's in
		# its pockets and bags needs searching.
		if hidden and bool(container.get("corpse")) and bool(TL.setting("worn_gear_visible")) and TL.is_worn_gear(item.slotData.itemData):
			hidden = false
	else:
		TL.learn(item.slotData.itemData.file)   # own storage: you know what's in it
	item.set_meta("tl_hidden", hidden)
	item.modulate.a = 0.0 if hidden else 1.0


# ---------------------------------------------------------------- searching

func _tl_setup() -> void:
	if tl_spinner and is_instance_valid(tl_spinner):
		return
	tl_spinner = Spinner.new()
	tl_spinner.name = "TL_Spinner"
	tl_spinner.hide()
	# Child of the container panel, never of the grid: the game treats every
	# grid child as an item.
	containerUI.add_child(tl_spinner)


func _tl_begin_container() -> void:
	tl_target = null
	tl_empty_left = -1.0
	if not TL.should_search(container):
		container.set_meta("tl_searched", true)
		return
	if _tl_next_hidden() == null and not bool(container.get_meta("tl_searched", false)):
		tl_empty_left = EMPTY_SEARCH_TIME
	tl_left = OPEN_DELAY
	if tl_empty_left >= 0.0 or _tl_next_hidden() != null:
		_tl_update_header()


func _tl_stop_search() -> void:
	_tl_unpreview()
	_tl_set_rummage(false)
	tl_target = null
	tl_empty_left = -1.0
	if tl_spinner:
		tl_spinner.hide()
	if container and is_instance_valid(containerName):
		containerName.text = container.containerName


func _tl_next_hidden():
	var best = null
	for child in containerGrid.get_children():
		if child is Item and TL.is_hidden(child) and not child.is_queued_for_deletion():
			if best == null or child.position.y < best.position.y or (is_equal_approx(child.position.y, best.position.y) and child.position.x < best.position.x):
				best = child
	return best


func _tl_search_tick(delta: float) -> void:
	if not container or not containerUI.visible:
		return
	tl_dots += delta

	if tl_empty_left >= 0.0:
		tl_empty_left -= delta
		_tl_set_rummage(true)
		_tl_place_spinner(containerGrid.global_position, Vector2(cellSize, cellSize))
		if tl_empty_left < 0.0:
			_tl_finish_container()
		else:
			_tl_update_header()
		return

	if tl_target == null or not is_instance_valid(tl_target) or not TL.is_hidden(tl_target):
		tl_target = _tl_next_hidden()
		if tl_target == null:
			if not bool(container.get_meta("tl_searched", false)) and TL.should_search(container):
				_tl_finish_container()
			elif tl_spinner.visible:
				_tl_stop_search()
			return
		tl_left = maxf(tl_left, 0.0) + TL.search_time(tl_target.slotData.itemData)
		tl_target.TL_SetPreview(true)
		tl_target.modulate.a = 1.0

	_tl_place_spinner(tl_target.global_position, tl_target.size)
	# Holding an item pauses the search, as in Tarkov.
	var paused: bool = itemDragged != null and bool(TL.setting("pause_while_dragging"))
	tl_spinner.modulate.a = 0.45 if paused else 1.0
	_tl_set_rummage(not paused)
	if paused:
		_tl_update_header(true)
		return
	tl_left -= delta
	_tl_update_header()
	if tl_left <= 0.0:
		_tl_reveal(tl_target)
		tl_target = null
		tl_left = 0.0


func _tl_place_spinner(pos: Vector2, item_size: Vector2) -> void:
	tl_spinner.size = item_size
	tl_spinner.global_position = pos
	tl_spinner.show()


# A ghosted item that wasn't revealed (container closed) goes back to hidden.
func _tl_unpreview() -> void:
	if tl_target and is_instance_valid(tl_target) and TL.is_hidden(tl_target):
		tl_target.TL_SetPreview(false)
		tl_target.modulate.a = 0.0


func _tl_reveal(target) -> void:
	target.set_meta("tl_hidden", false)
	target.TL_SetPreview(false)
	target.UpdateDetails()
	# Brief flash as the ghost turns into the real item (or its silhouette).
	target.modulate = Color(1.7, 1.7, 1.7, 1.0)
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color.WHITE, 0.22)
	if bool(TL.setting("reveal_sound")):
		_tl_play("found", -6.0)


func _tl_finish_container() -> void:
	tl_empty_left = -1.0
	container.set_meta("tl_searched", true)
	_tl_stop_search()


func _tl_update_header(paused := false) -> void:
	if not is_instance_valid(containerName):
		return
	if paused:
		containerName.text = "%s  -  Searching (paused)" % container.containerName
		return
	var dots := ".".repeat(int(tl_dots * 3.0) % 4)
	containerName.text = "%s  -  Searching%s" % [container.containerName, dots]


# ---------------------------------------------------------------- sounds

func _tl_play(name: String, db: float) -> void:
	var s := TL.sound(name)
	if s == null:
		PlayClick()
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func _tl_set_rummage(on: bool) -> void:
	on = on and bool(TL.setting("search_sounds"))
	if not on:
		if tl_rummage and tl_rummage.playing:
			tl_rummage.stop()
		return
	if tl_rummage == null:
		var s = TL.sound("rummage")
		if s == null:
			return
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
		tl_rummage = AudioStreamPlayer.new()
		tl_rummage.name = "TL_Rummage"
		tl_rummage.stream = s
		tl_rummage.bus = &"SFX"
		tl_rummage.volume_db = -12.0
		add_child(tl_rummage)
	if not tl_rummage.playing:
		tl_rummage.play()


# Never let the player interact with what they haven't found yet.
func GetHoverItem():
	var element = super()
	if element and TL.is_hidden(element):
		return null
	return element


# Don't silently merge a stack into an item the player can't see.
func AutoStack(slotData, targetGrid):
	if TL.active() and targetGrid == containerGrid and slotData and slotData.itemData:
		for child in containerGrid.get_children():
			if TL.is_hidden(child) and child.slotData.itemData.file == slotData.itemData.file:
				return false
	return super(slotData, targetGrid)


# ---------------------------------------------------------------- unknown items

func Hover():
	super()
	if not TL.examining():
		return
	if (itemDragged and TL.is_restricted(itemDragged)) or (itemDragged and hoverItem and TL.is_restricted(hoverItem)):
		canEquip = false
		canSlotSwap = false
		canCombine = false
		canCombineSwap = false
		canCombineLoad = false
		canCombineCharge = false
		# Stacking two unknown stacks of the same thing is still fine.
		if canCombineStack and not (TL.is_unknown(itemDragged) and hoverItem and hoverItem.slotData.itemData.file == itemDragged.slotData.itemData.file):
			canCombineStack = false


func FastEquip():
	if hoverItem and TL.is_restricted(hoverItem):
		_tl_need_examine()
		return
	super()


func ContextEquip():
	if contextItem and TL.is_restricted(contextItem):
		_tl_need_examine()
		HideContext()
		Reset()
		return
	super()


func Use(targetItem, targetGrid):
	if targetItem and TL.is_restricted(targetItem):
		_tl_need_examine()
		return
	return await super(targetItem, targetGrid)


func _tl_need_examine() -> void:
	PlayError()
	Loader.Message("Unknown item - examine it first (middle-click)", Color.ORANGE)


# Trader stock and crafting results count as known.
func FillSupplyGrid():
	super()
	if TL.active():
		var files := []
		for child in supplyGrid.get_children():
			if child is Item:
				files.append(child.slotData.itemData.file)
		TL.learn_many(files)


func Complete(data: Resource):
	if TL.active() and data and "output" in data:
		var files := []
		for out in data.output:
			if out:
				files.append(out.file)
		TL.learn_many(files)
	super(data)


# Called by the Examine button in the context menu.
func TL_ContextExamine():
	var target = contextItem
	HideContext()
	Reset()
	TL_Examine(target)


# Start examining an unknown item. Returns false if there was nothing to do.
func TL_Examine(target) -> bool:
	if target == null or not is_instance_valid(target) or not TL.is_unknown(target) or TL.is_hidden(target):
		return false
	var key: int = target.get_instance_id()
	if tl_examines.has(key):
		return false
	tl_examines[key] = {"item": target, "t": 0.0, "total": TL.examine_time(target.slotData.itemData)}
	target.TL_SetProgress(0.0)
	PlayClick()
	return true


# Middle mouse examines the hovered item, Tarkov's default binding.
func _input(event):
	if not visible or not TL.examining() or not bool(TL.setting("examine_middle_mouse")):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		if itemDragged or context.visible:
			return
		if TL_Examine(hoverItem):
			get_viewport().set_input_as_handled()


func TL_IsExamining(target) -> bool:
	return target != null and tl_examines.has(target.get_instance_id())


# 0..1 for the item being examined, 0 for queued ones, -1 if not queued.
func TL_ExamineProgress(target) -> float:
	if not TL_IsExamining(target):
		return -1.0
	var e: Dictionary = tl_examines[target.get_instance_id()]
	return e.t / e.total


# Items are examined one at a time, in the order you asked (Tarkov's queue).
# It keeps running with the inventory closed.
func _tl_examine_tick(delta: float) -> void:
	for k in tl_examines.keys():
		var gone = tl_examines[k].item
		if not is_instance_valid(gone) or gone.is_queued_for_deletion() or not gone.is_inside_tree():
			tl_examines.erase(k)
	_tl_update_queue_label()
	if tl_examines.is_empty():
		return
	var first_key = tl_examines.keys()[0]
	var e: Dictionary = tl_examines[first_key]
	var it = e.item
	if it == itemDragged:
		return   # paused while held
	e.t += delta
	it.TL_SetProgress(e.t / e.total)
	if e.t >= e.total:
		tl_examines.erase(first_key)
		it.TL_SetProgress(-1.0)
		var data = it.slotData.itemData
		if TL.learn(data.file):
			Loader.Message("Examined: " + data.name, Color.GREEN)
		PlayAttach()
		_tl_refresh_items()
		_tl_update_queue_label()


func _tl_update_queue_label() -> void:
	if tl_examines.is_empty():
		if tl_queue_label:
			tl_queue_label.hide()
		return
	if tl_queue_label == null or not is_instance_valid(tl_queue_label):
		tl_queue_label = Label.new()
		tl_queue_label.name = "TL_ExamineQueue"
		tl_queue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tl_queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tl_queue_label.add_theme_font_size_override("font_size", 15)
		tl_queue_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.62))
		tl_queue_label.add_theme_color_override("font_outline_color", Color.BLACK)
		tl_queue_label.add_theme_constant_override("outline_size", 5)
		tl_queue_label.z_index = 20
		get_parent().add_child(tl_queue_label)
	var first: Dictionary = tl_examines.values()[0]
	var text := "Examining  %d%%" % int(first.t / first.total * 100.0)
	if tl_examines.size() > 1:
		text += "   (+%d queued)" % (tl_examines.size() - 1)
	tl_queue_label.text = text
	var vp := get_viewport().get_visible_rect().size
	tl_queue_label.size = Vector2(360, 24)
	tl_queue_label.global_position = Vector2(vp.x - 380, 16)
	tl_queue_label.show()


func _tl_cancel_examines() -> void:
	for key in tl_examines.keys():
		var it = tl_examines[key].item
		if is_instance_valid(it):
			it.TL_SetProgress(-1.0)
	tl_examines.clear()


func _tl_refresh_items() -> void:
	for grid in [inventoryGrid, containerGrid]:
		for child in grid.get_children():
			if child is Item and child.slotData and child.slotData.itemData:
				child.UpdateDetails()
	for slot in equipment.get_children():
		if slot is Slot and slot.get_child_count() != 0 and slot.get_child(0) is Item:
			slot.get_child(0).UpdateDetails()


# First run with the mod: everything the player already carries is known,
# so existing saves are not suddenly full of question marks.
func _tl_seed_knowledge() -> void:
	var files := []
	for child in inventoryGrid.get_children():
		if child is Item:
			files.append(child.slotData.itemData.file)
			for n in child.slotData.nested:
				if n:
					files.append(n.file)
	for slot in equipment.get_children():
		if slot is Slot and slot.get_child_count() != 0 and slot.get_child(0) is Item:
			var sd = slot.get_child(0).slotData
			files.append(sd.itemData.file)
			for n in sd.nested:
				if n:
					files.append(n.file)
	TL.learn_many(files)
	TL.mark_seeded()
	TL.say("Seeded item knowledge with %d owned item(s)." % files.size())


# ---------------------------------------------------------------- loop

func _physics_process(delta):
	super(delta)
	if not TL.active():
		return
	_tl_examine_tick(delta)
	if visible and container:
		_tl_search_tick(delta)
