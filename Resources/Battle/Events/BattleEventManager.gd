class_name BattleEventManager
extends Node

signal event_triggered(event: Dictionary)
signal event_resolved(event: Dictionary, results: Dictionary)

const BattleEventTypes = preload("res://Resources/Battle/Events/BattleEventTypes.gd")

var active_events: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var current_turn: int = 0

# Core Rules event handling
func check_for_events(context: Dictionary) -> void:
	for event_name in BattleEventTypes.BATTLE_EVENTS:
		var event = BattleEventTypes.BATTLE_EVENTS[event_name]
		
		if randf() < event.probability and BattleEventTypes.check_event_requirements(event_name, context):
			_trigger_event(event_name, context)

func _trigger_event(event_name: String, context: Dictionary) -> void:
	var event = BattleEventTypes.BATTLE_EVENTS[event_name].duplicate()
	event.name = event_name
	event.turn_triggered = current_turn
	event.context = context
	
	active_events.append(event)
	event_triggered.emit(event)
	
	_apply_event_effects(event)

func _apply_event_effects(event: Dictionary) -> void:
	var effect = event.effect
	var results = {}
	
	match effect.type:
		"damage_multiplier":
			results.damage = _apply_damage_multiplier(effect.value, event.context)
		"disable_weapon":
			results.disabled = _disable_weapon(effect.duration, event.context)
		"defense_bonus":
			results.defense = _apply_defense_bonus(effect.value, effect.duration, event.context)
		_:
			push_warning("Unknown effect type: " + effect.type)
	
	event_resolved.emit(event, results)

# Effect application methods
func _apply_damage_multiplier(multiplier: float, context: Dictionary) -> float:
	var base_damage = context.get("base_damage", 0.0)
	return base_damage * multiplier

func _disable_weapon(duration: int, context: Dictionary) -> bool:
	var character = context.get("character")
	if character and character.has_method("disable_weapon"):
		character.disable_weapon(duration)
		return true
	return false

func _apply_defense_bonus(bonus: int, duration: int, context: Dictionary) -> int:
	var character = context.get("character")
	if character and character.has_method("add_defense_bonus"):
		character.add_defense_bonus(bonus, duration)
		return bonus
	return 0

# Turn management
func advance_turn() -> void:
	current_turn += 1
	_update_active_events()

func _update_active_events() -> void:
	var expired_events = []
	
	for event in active_events:
		if "duration" in event.effect:
			event.effect.duration -= 1
			if event.effect.duration <= 0:
				expired_events.append(event)
	
	for event in expired_events:
		active_events.erase(event)
		event_history.append(event)

# Serialization
func serialize() -> Dictionary:
	return {
		"active_events": active_events,
		"event_history": event_history,
		"current_turn": current_turn
	}

func deserialize(data: Dictionary) -> void:
	active_events = data.get("active_events", [])
	event_history = data.get("event_history", [])
	current_turn = data.get("current_turn", 0)
