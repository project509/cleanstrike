# Cash Money: traders keep some cash you can take for your goods.
extends "res://Scripts/Trader.gd"

const CM = preload("res://CSCashMoney/Mod.gd")


func CreateSupply():
	super()
	if CM.active() and bool(CM.setting("trader_cash")):
		for amount in [20, 50, 100, 250, 500]:
			supply.append(CM.stack(amount))
