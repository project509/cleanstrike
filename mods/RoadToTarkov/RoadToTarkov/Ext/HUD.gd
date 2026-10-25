# Road to Tarkov: the travel prompt at School exits mentions Customs too.
extends "res://Scripts/HUD.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")


func Transition(transitionData):
	super(transitionData)
	if transitionData and transitionData.has_method("RTT_OffersCustoms") and transitionData.RTT_OffersCustoms():
		destination.text = "School / Customs"
