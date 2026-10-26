# Cash Money: a euro is worth a euro, but trading with cash costs the markup.
extends "res://Scripts/Item.gd"

const CM = preload("res://CSCashMoney/Mod.gd")


func Value() -> int:
	if not CM.is_cash(slotData.itemData):
		return super()
	var v := float(slotData.amount)
	if CM.active() and interface and interface.trader and get_parent():
		if get_parent() == interface.supplyGrid:
			v *= CM.rate()          # the trader's cash costs you more
		elif get_parent() == interface.inventoryGrid:
			v /= CM.rate()          # your cash buys less
	return int(round(v))
