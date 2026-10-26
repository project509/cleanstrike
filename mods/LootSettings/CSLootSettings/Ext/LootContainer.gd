# Loot Settings: containers roll their loot with the chosen preset.
extends "res://Scripts/LootContainer.gd"

const LS = preload("res://CSLootSettings/Mod.gd")


func _ready():
	super()
	# Mega Loot: every stash is on the map, with a legendary inside.
	if stash and LS.changes_loot() and bool(LS.value("stashes_always")):
		process_mode = Node.PROCESS_MODE_INHERIT
		show()
		if bool(LS.value("stash_legendary")) and not legendaryBucket.is_empty():
			CreateLoot(legendaryBucket.pick_random())


func GenerateLoot():
	if not LS.changes_loot():
		super()
		return
	for item in LS.roll(LS.weighted(commonBucket), LS.weighted(rareBucket), legendaryBucket, joker, corpse):
		if item:
			CreateLoot(item)


func CreateLoot(item: ItemData):
	super(item)
	if LS.changes_loot() and not gameData.tutorial and not loot.is_empty() and loot[-1].itemData == item:
		if item.type == "Weapon" or item.subtype == "Light" or item.subtype == "NVG":
			loot[-1].condition = LS.condition()
