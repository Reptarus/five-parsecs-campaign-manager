class_name CampaignEventGenerator
extends Node

var game_state: GameStateManagerNode

func _init(_game_state: GameStateManagerNode):
	game_state = _game_state

func generate_event() -> Dictionary:
	var event_types = [
		"Market Crash",
		"Economic Boom",
		"Trade Embargo",
		"Resource Shortage",
		"Technological Breakthrough"
	]
	var event_type = event_types[randi() % event_types.size()]
	
	return create_event(event_type)

func create_event(event_type: String) -> Dictionary:
	var event = {
		"type": event_type,
		"description": get_event_description(event_type),
		"effect": get_event_effect(event_type)
	}
	return event

func get_event_description(event_type: String) -> String:
	match event_type:
		"Market Crash":
			return "A sudden economic downturn has affected the sector."
		"Economic Boom":
			return "The sector is experiencing unprecedented economic growth."
		"Trade Embargo":
			return "A trade embargo has been imposed on certain goods."
		"Resource Shortage":
			return "A critical resource has become scarce in the sector."
		"Technological Breakthrough":
			return "A new technology has been developed, changing the market dynamics."
		_:
			return "An unexpected event has occurred in the sector."

func get_event_effect(event_type: String) -> Callable:
	match event_type:
		"Market Crash":
			return func(): game_state.modify_credits(int(game_state.credits * -0.2))
		"Economic Boom":
			return func(): game_state.modify_credits(int(game_state.credits * 0.2))
		"Trade Embargo":
			return func(): game_state.apply_trade_restrictions()
		"Resource Shortage":
			return func(): game_state.increase_item_prices()
		"Technological Breakthrough":
			return func(): game_state.update_item_availability()
		_:
			return func(): push_warning("Unhandled event type: " + event_type)
