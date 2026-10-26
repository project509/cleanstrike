# Progression: XP for searching, crafting and trading; Strength and Barter;
# the Skills panel on the Character view.
extends "res://Scripts/Interface.gd"

const PG = preload("res://CSProgression/Mod.gd")

var pg_searched := {}       # containers already searched this visit
var pg_button: Button
var pg_panel: Panel
var pg_rows := {}


func Open():
	if PG.active() and container and not pg_searched.has(container.get_instance_id()):
		pg_searched[container.get_instance_id()] = true
		var name := str(container.containerName)
		PG.add_xp(20.0 if name == "Airdrop" else (10.0 if container.joker else 5.0), "searched " + name)
	super()
	if PG.active():
		PG_Build()
		PG_Refresh()


func Complete(data: Resource):
	if PG.active() and data is RecipeData:
		PG.add_xp(3.0 if (data.repair or data.upgrade) else 15.0, "crafted " + str(data.name))
	super(data)


func CompleteDeal():
	var offered := 0.0
	for e in inventoryGrid.get_children():
		if e.selected:
			offered += e.Value()
	super()
	if PG.active() and offered > 0.0:
		PG.add_xp(offered / 25.0, "trade")


func UpdateTraderInfo():
	super()
	if PG.active() and PG.rank("barter") > 0:
		trader.tax = maxi(0, trader.tax - int(PG.bonus("barter")))
		traderTax.text = str(trader.tax) + "%"


func UpdateStats(updateLabels: bool):
	var keep: float = baseCarryWeight
	baseCarryWeight += PG.bonus("strength")
	await super(updateLabels)
	baseCarryWeight = keep


# ---------------------------------------------------------------- panel

func PG_Build() -> void:
	if pg_panel and is_instance_valid(pg_panel):
		return
	pg_button = Button.new()
	pg_button.text = "Skills"
	pg_button.focus_mode = Control.FOCUS_NONE
	pg_button.position = Vector2(132, -32)
	pg_button.size = Vector2(90, 30)
	pg_button.toggle_mode = true
	pg_button.toggled.connect(PG_Show)
	characterUI.add_child(pg_button)
	pg_panel = Panel.new()
	pg_panel.name = "CS_Skills"
	pg_panel.position = Vector2(0, 0)
	pg_panel.size = Vector2(384, 192)
	pg_panel.hide()
	characterUI.add_child(pg_panel)
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.position = Vector2(10, 6)
	box.size = Vector2(364, 180)
	box.add_theme_constant_override("separation", 2)
	pg_panel.add_child(box)
	var head := Label.new()
	head.name = "Head"
	head.add_theme_font_size_override("font_size", 14)
	box.add_child(head)
	for key in PG.SKILLS:
		var row := HBoxContainer.new()
		var name := Label.new()
		name.custom_minimum_size = Vector2(110, 0)
		name.add_theme_font_size_override("font_size", 13)
		name.tooltip_text = PG.SKILLS[key][1]
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name)
		var pips := Label.new()
		pips.custom_minimum_size = Vector2(160, 0)
		pips.add_theme_font_size_override("font_size", 13)
		row.add_child(pips)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 20)
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(func():
			if PG.spend(key):
				PlayClick()
				UpdateStats(true)
			PG_Refresh())
		row.add_child(plus)
		box.add_child(row)
		pg_rows[key] = [name, pips, plus]


func PG_Show(on: bool) -> void:
	pg_panel.visible = on
	for n in ["Vitals", "Medical", "Stats"]:
		var p = characterUI.get_node_or_null(n)
		if p:
			p.visible = not on
	PG_Refresh()


func PG_Refresh() -> void:
	if pg_panel == null:
		return
	var st := PG.state()
	pg_panel.get_node("VBoxContainer/Head").text = "Level %d   XP %d / %d   Points %d" % [int(st.level), int(st.xp), PG.need(int(st.level)), int(st.points)]
	for key in pg_rows:
		var r: Array = pg_rows[key]
		r[0].text = PG.SKILLS[key][0]
		var n := PG.rank(key)
		r[1].text = "●".repeat(n) + "○".repeat(PG.MAX_RANK - n)
		r[2].disabled = not PG.can_spend(key)
