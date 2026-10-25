# Road to Tarkov: Tarkov-style looting for the inventory screen.
#  - Containers and bodies must be searched; items reveal one at a time,
#    top-left to bottom-right, and search progress is kept per container.
#  - Items you have never examined show as unknown silhouettes. Right-click
#    -> Examine to identify them; knowledge is kept between sessions.
#  - Unknown items can be moved, stacked and dropped, but not used,
#    equipped or combined until examined.
extends "res://Scripts/Interface.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")
const Spinner = preload("res://RoadToTarkov/SearchSpinner.gd")

const OPEN_DELAY := 0.5
const EMPTY_SEARCH_TIME := 0.9

var rtt_spinner: Control
var rtt_target = null          # hidden Item currently being searched
var rtt_left := 0.0            # seconds until rtt_target is revealed
var rtt_empty_left := -1.0     # short "searching" pass for empty containers
var rtt_filling := false
var rtt_examines := {}         # instance id -> {item, t, total}
var rtt_dots := 0.0


# ---------------------------------------------------------------- open/close

func Open():
	super()
	if not RTT.active():
		return
	_rtt_setup()
	_rtt_setup_map()
	if not RTT.is_seeded():
		_rtt_seed_knowledge()
	if container:
		_rtt_begin_container()
	_rtt_refresh_items()


func Close():
	_rtt_cancel_examines()
	_rtt_stop_search()
	super()


func FillContainerGrid():
	rtt_filling = true
	super()
	rtt_filling = false


# Containers keep their items as SlotData between openings; carry our
# hidden flag across by tagging the SlotData copies the game stores.
func StorageContainerGrid():
	super()
	if not RTT.active() or container == null:
		return
	var children: Array = containerGrid.get_children()
	for i in min(children.size(), container.storage.size()):
		container.storage[i].set_meta("rtt_hidden", RTT.is_hidden(children[i]))


func LoadGridItem(slotData, targetGrid, gridPosition):
	var before: int = targetGrid.get_child_count()
	super(slotData, targetGrid, gridPosition)
	_rtt_tag_new(slotData, targetGrid, before)


func Create(slotData, targetGrid, useDrop):
	var before = targetGrid.get_child_count() if targetGrid else 0
	var ok = super(slotData, targetGrid, useDrop)
	_rtt_tag_new(slotData, targetGrid, before)
	return ok


func _rtt_tag_new(slotData, targetGrid, before: int) -> void:
	if not rtt_filling or targetGrid != containerGrid or not RTT.active():
		return
	if targetGrid.get_child_count() <= before:
		return
	var item = targetGrid.get_child(targetGrid.get_child_count() - 1)
	if not (item is Item):
		return
	var hidden := false
	if RTT.should_search(container):
		hidden = bool(slotData.get_meta("rtt_hidden", true)) if container.storaged else not bool(container.get_meta("rtt_searched", false))
	else:
		RTT.learn(item.slotData.itemData.file)   # own storage: you know what's in it
	item.set_meta("rtt_hidden", hidden)
	item.modulate.a = 0.0 if hidden else 1.0


# ---------------------------------------------------------------- searching

func _rtt_setup() -> void:
	if rtt_spinner and is_instance_valid(rtt_spinner):
		return
	rtt_spinner = Spinner.new()
	rtt_spinner.name = "RTT_Spinner"
	rtt_spinner.hide()
	# Child of the container panel, never of the grid: the game treats every
	# grid child as an item.
	containerUI.add_child(rtt_spinner)


func _rtt_begin_container() -> void:
	rtt_target = null
	rtt_empty_left = -1.0
	if not RTT.should_search(container):
		container.set_meta("rtt_searched", true)
		return
	if _rtt_next_hidden() == null and not bool(container.get_meta("rtt_searched", false)):
		rtt_empty_left = EMPTY_SEARCH_TIME
	rtt_left = OPEN_DELAY
	if rtt_empty_left >= 0.0 or _rtt_next_hidden() != null:
		_rtt_update_header()


func _rtt_stop_search() -> void:
	rtt_target = null
	rtt_empty_left = -1.0
	if rtt_spinner:
		rtt_spinner.hide()
	if container and is_instance_valid(containerName):
		containerName.text = container.containerName


func _rtt_next_hidden():
	var best = null
	for child in containerGrid.get_children():
		if child is Item and RTT.is_hidden(child) and not child.is_queued_for_deletion():
			if best == null or child.position.y < best.position.y or (is_equal_approx(child.position.y, best.position.y) and child.position.x < best.position.x):
				best = child
	return best


func _rtt_search_tick(delta: float) -> void:
	if not container or not containerUI.visible:
		return
	rtt_dots += delta

	if rtt_empty_left >= 0.0:
		rtt_empty_left -= delta
		_rtt_place_spinner(containerGrid.global_position, Vector2(cellSize, cellSize))
		if rtt_empty_left < 0.0:
			_rtt_finish_container()
		else:
			_rtt_update_header()
		return

	if rtt_target == null or not is_instance_valid(rtt_target) or not RTT.is_hidden(rtt_target):
		rtt_target = _rtt_next_hidden()
		if rtt_target == null:
			if not bool(container.get_meta("rtt_searched", false)) and RTT.should_search(container):
				_rtt_finish_container()
			elif rtt_spinner.visible:
				_rtt_stop_search()
			return
		rtt_left = maxf(rtt_left, 0.0) + RTT.search_time(rtt_target.slotData.itemData)

	_rtt_place_spinner(rtt_target.global_position, rtt_target.size)
	rtt_left -= delta
	_rtt_update_header()
	if rtt_left <= 0.0:
		_rtt_reveal(rtt_target)
		rtt_target = null
		rtt_left = 0.0


func _rtt_place_spinner(pos: Vector2, item_size: Vector2) -> void:
	var s := minf(cellSize, minf(item_size.x, item_size.y))
	rtt_spinner.size = Vector2(s, s)
	rtt_spinner.global_position = pos
	rtt_spinner.show()


func _rtt_reveal(target) -> void:
	target.set_meta("rtt_hidden", false)
	target.UpdateDetails()
	var tw := create_tween()
	tw.tween_property(target, "modulate:a", 1.0, 0.18)
	if bool(RTT.setting("reveal_sound")):
		PlayClick()


func _rtt_finish_container() -> void:
	rtt_empty_left = -1.0
	container.set_meta("rtt_searched", true)
	_rtt_stop_search()


func _rtt_update_header() -> void:
	if not is_instance_valid(containerName):
		return
	var dots := ".".repeat(int(rtt_dots * 3.0) % 4)
	containerName.text = "%s  -  Searching%s" % [container.containerName, dots]


# Never let the player interact with what they haven't found yet.
func GetHoverItem():
	var element = super()
	if element and RTT.is_hidden(element):
		return null
	return element


# Don't silently merge a stack into an item the player can't see.
func AutoStack(slotData, targetGrid):
	if RTT.active() and targetGrid == containerGrid and slotData and slotData.itemData:
		for child in containerGrid.get_children():
			if RTT.is_hidden(child) and child.slotData.itemData.file == slotData.itemData.file:
				return false
	return super(slotData, targetGrid)


# ---------------------------------------------------------------- unknown items

func Hover():
	super()
	if not RTT.examining():
		return
	if (itemDragged and RTT.is_unknown(itemDragged)) or (itemDragged and hoverItem and RTT.is_unknown(hoverItem)):
		canEquip = false
		canSlotSwap = false
		canCombine = false
		canCombineSwap = false
		canCombineLoad = false
		canCombineCharge = false
		# Stacking two unknown stacks of the same thing is still fine.
		if canCombineStack and not (RTT.is_unknown(itemDragged) and hoverItem and hoverItem.slotData.itemData.file == itemDragged.slotData.itemData.file):
			canCombineStack = false


func FastEquip():
	if hoverItem and RTT.is_unknown(hoverItem):
		_rtt_need_examine()
		return
	super()


func ContextEquip():
	if contextItem and RTT.is_unknown(contextItem):
		_rtt_need_examine()
		HideContext()
		Reset()
		return
	super()


func Use(targetItem, targetGrid):
	if targetItem and RTT.is_unknown(targetItem):
		_rtt_need_examine()
		return
	return await super(targetItem, targetGrid)


func _rtt_need_examine() -> void:
	PlayError()
	Loader.Message("Unknown item - examine it first (right-click > Examine)", Color.ORANGE)


# Trader stock and crafting results count as known.
func FillSupplyGrid():
	super()
	if RTT.active():
		var files := []
		for child in supplyGrid.get_children():
			if child is Item:
				files.append(child.slotData.itemData.file)
		RTT.learn_many(files)


func Complete(data: Resource):
	if RTT.active() and data and "output" in data:
		var files := []
		for out in data.output:
			if out:
				files.append(out.file)
		RTT.learn_many(files)
	super(data)


# Called by the Examine button in the context menu.
func RTT_ContextExamine():
	var target = contextItem
	HideContext()
	Reset()
	if target == null or not RTT.is_unknown(target):
		return
	var key: int = target.get_instance_id()
	if rtt_examines.has(key):
		return
	rtt_examines[key] = {"item": target, "t": 0.0, "total": RTT.examine_time(target.slotData.itemData)}
	target.RTT_SetProgress(0.0)
	PlayClick()


func RTT_IsExamining(target) -> bool:
	return target != null and rtt_examines.has(target.get_instance_id())


func _rtt_examine_tick(delta: float) -> void:
	if rtt_examines.is_empty():
		return
	for key in rtt_examines.keys():
		var e: Dictionary = rtt_examines[key]
		var it = e.item
		if not is_instance_valid(it) or it.is_queued_for_deletion():
			rtt_examines.erase(key)
			continue
		if it == itemDragged:
			continue   # paused while held
		e.t += delta
		it.RTT_SetProgress(e.t / e.total)
		if e.t >= e.total:
			rtt_examines.erase(key)
			it.RTT_SetProgress(-1.0)
			var data = it.slotData.itemData
			if RTT.learn(data.file):
				Loader.Message("Examined: " + data.name, Color.GREEN)
			PlayAttach()
			_rtt_refresh_items()


func _rtt_cancel_examines() -> void:
	for key in rtt_examines.keys():
		var it = rtt_examines[key].item
		if is_instance_valid(it):
			it.RTT_SetProgress(-1.0)
	rtt_examines.clear()


func _rtt_refresh_items() -> void:
	for grid in [inventoryGrid, containerGrid]:
		for child in grid.get_children():
			if child is Item and child.slotData and child.slotData.itemData:
				child.UpdateDetails()
	for slot in equipment.get_children():
		if slot is Slot and slot.get_child_count() != 0 and slot.get_child(0) is Item:
			slot.get_child(0).UpdateDetails()


# First run with the mod: everything the player already carries is known,
# so existing saves are not suddenly full of question marks.
func _rtt_seed_knowledge() -> void:
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
	RTT.learn_many(files)
	RTT.mark_seeded()
	RTT.say("Seeded item knowledge with %d owned item(s)." % files.size())


# ---------------------------------------------------------------- map tool

const CUSTOMS_MAP := "res://RoadToTarkov/Customs/customs_map.jpg"
const CUSTOMS_MARKER_POS := Vector2(1560, 1080)   # on Vostok's world map, past the school
var rtt_map_ready := false


# In Customs the map tool shows re3mr's Customs map; everywhere else the
# world map gets a Customs marker next to School.
func _rtt_setup_map() -> void:
	if rtt_map_ready or not RTT.customs_enabled():
		return
	rtt_map_ready = true
	var scroll = mapScroll
	if scroll == null or scroll.get_child_count() == 0:
		return
	var world: TextureRect = scroll.get_child(0) as TextureRect
	if world == null:
		return
	var current = get_tree().current_scene.get_node_or_null("/root/Map")
	if current and current.mapName == "Customs":
		var Picker = load("res://RoadToTarkov/Customs/Picker.gd")
		var tex: Texture2D = Picker.load_texture(CUSTOMS_MAP)
		if tex:
			world.texture = tex
		for marker in world.get_children():
			marker.hide()
		var here := Control.new()
		here.name = "Customs"
		here.position = Vector2(1920, 1080)
		world.add_child(here)
	elif world.get_node_or_null("Customs") == null and world.get_node_or_null("School") != null:
		var marker: Node = world.get_node("School").duplicate()
		marker.name = "Customs"
		if marker is Control:
			marker.position = CUSTOMS_MARKER_POS
		_rtt_relabel(marker, "CUSTOMS")
		world.add_child(marker)


func _rtt_relabel(node: Node, text: String) -> void:
	if node is Label:
		node.text = text
	for c in node.get_children():
		_rtt_relabel(c, text)


# ---------------------------------------------------------------- loop

func _physics_process(delta):
	super(delta)
	if not visible or not RTT.active():
		return
	if container:
		_rtt_search_tick(delta)
	_rtt_examine_tick(delta)
