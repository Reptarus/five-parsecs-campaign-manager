## EventManager
## Manages game events and their effects on the game state
class_name EventManager
extends Node

## Dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/data/resources/GameState/GameState.gd")
const StoryQuestData := preload("res://src/core/story/StoryQuestData.gd")

## Signals
signal event_triggered(event_type: GameEnums.GlobalEvent)
signal event_resolved(event_type: GameEnums.GlobalEvent)
signal event_effects_applied(effects: Dictionary)

## Event tracking
var active_events: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var event_cooldowns: Dictionary = {}

## Configuration
const MAX_HISTORY_SIZE := 100  # Limit event history size
const MAX_ACTIVE_EVENTS := 5   # Limit concurrent active events

## Game state reference
var game_state: FiveParsecsGameState

## Event configuration
const MIN_EVENT_INTERVAL := 3  # Minimum turns between events
const BASE_EVENT_CHANCE := 0.2  # 20% chance per turn
const COOLDOWN_DURATION := 10  # Turns before same event type can occur again

## Initialize the event manager
func initialize(state: FiveParsecsGameState) -> void:
	game_state = state
	active_events.clear()
	event_history.clear()
	event_cooldowns.clear()

## Cleanup when node is removed
func _exit_tree() -> void:
	cleanup()

## Cleanup resources
func cleanup() -> void:
	# Clear all events and remove effects
	var events_to_resolve = active_events.duplicate()
	for event in events_to_resolve:
		resolve_event(event.type)
	
	# Clear arrays and dictionaries
	active_events.clear()
	event_history.clear()
	event_cooldowns.clear()
	
	# Clear game state reference
	game_state = null

## Update event state
func update() -> void:
	_update_cooldowns()
	_check_random_events()
	_process_active_events()
	_trim_event_history()

## Trim event history to prevent unbounded growth
func _trim_event_history() -> void:
	if event_history.size() > MAX_HISTORY_SIZE:
		event_history = event_history.slice(-MAX_HISTORY_SIZE)

## Trigger a specific event
func trigger_event(event_type: GameEnums.GlobalEvent) -> void:
	if not _can_trigger_event(event_type):
		return
		
	# Check active events limit
	if active_events.size() >= MAX_ACTIVE_EVENTS:
		var oldest_event = active_events[0]
		resolve_event(oldest_event.type)
	
	var event_data := {
		"type": event_type,
		"turn_started": game_state.current_turn if game_state else 0,
		"duration": _get_event_duration(event_type),
		"effects": _generate_event_effects(event_type)
	}
	
	active_events.append(event_data)
	event_history.append(event_data.duplicate()) # Use duplicate to prevent reference issues
	event_cooldowns[event_type] = COOLDOWN_DURATION
	
	event_triggered.emit(event_type)
	_apply_event_effects(event_data.effects)

## Resolve an active event
func resolve_event(event_type: GameEnums.GlobalEvent) -> void:
	var event_index := -1
	for i in range(active_events.size()):
		if active_events[i].type == event_type:
			event_index = i
			break
			
	if event_index >= 0:
		var event = active_events[event_index]
		active_events.remove_at(event_index)
		_remove_event_effects(event.effects)
		event_resolved.emit(event_type)

## Check if an event can be triggered
func _can_trigger_event(event_type: GameEnums.GlobalEvent) -> bool:
	# Check cooldown
	if event_cooldowns.has(event_type) and event_cooldowns[event_type] > 0:
		return false
		
	# Check if event is already active
	for event in active_events:
		if event.type == event_type:
			return false
			
	return true

## Get the duration for an event type
func _get_event_duration(event_type: GameEnums.GlobalEvent) -> int:
	match event_type:
		GameEnums.GlobalEvent.MARKET_CRASH:
			return 5
		GameEnums.GlobalEvent.ALIEN_INVASION:
			return 8
		GameEnums.GlobalEvent.TECH_BREAKTHROUGH:
			return 3
		_:
			return 4

## Generate effects for an event type
func _generate_event_effects(event_type: GameEnums.GlobalEvent) -> Dictionary:
	var effects := {}
	
	match event_type:
		GameEnums.GlobalEvent.MARKET_CRASH:
			effects = {
				"economy_modifier": -0.25,
				"trade_penalty": true
			}
		GameEnums.GlobalEvent.ALIEN_INVASION:
			effects = {
				"combat_difficulty": 1.5,
				"spawn_rate_increase": true
			}
		GameEnums.GlobalEvent.TECH_BREAKTHROUGH:
			effects = {
				"research_bonus": true,
				"tech_discount": 0.2
			}
		_:
			effects = {}
	
	return effects

## Apply event effects to game state
func _apply_event_effects(effects: Dictionary) -> void:
	if not game_state:
		return
		
	# Apply effects to game state
	for effect in effects:
		match effect:
			"economy_modifier":
				game_state.apply_economy_modifier(effects[effect])
			"combat_difficulty":
				game_state.modify_combat_difficulty(effects[effect])
			"tech_discount":
				game_state.apply_tech_discount(effects[effect])
	
	event_effects_applied.emit(effects)

## Remove event effects from game state
func _remove_event_effects(effects: Dictionary) -> void:
	if not game_state:
		return
		
	# Remove effects from game state
	for effect in effects:
		match effect:
			"economy_modifier":
				game_state.apply_economy_modifier(-effects[effect])
			"combat_difficulty":
				game_state.modify_combat_difficulty(1.0 / effects[effect])
			"tech_discount":
				game_state.apply_tech_discount(-effects[effect])

## Update event cooldowns
func _update_cooldowns() -> void:
	var expired_cooldowns := []
	
	for event_type in event_cooldowns:
		event_cooldowns[event_type] = max(0, event_cooldowns[event_type] - 1)
		if event_cooldowns[event_type] <= 0:
			expired_cooldowns.append(event_type)
			
	for event_type in expired_cooldowns:
		event_cooldowns.erase(event_type)

## Check for random event triggers
func _check_random_events() -> void:
	if not game_state:
		return
		
	if randf() < BASE_EVENT_CHANCE:
		var available_events := _get_available_events()
		if not available_events.is_empty():
			var random_event = available_events[randi() % available_events.size()]
			trigger_event(random_event)

## Get list of events that can be triggered
func _get_available_events() -> Array:
	var available := []
	
	for event_type in GameEnums.GlobalEvent.values():
		if event_type != GameEnums.GlobalEvent.NONE and _can_trigger_event(event_type):
			available.append(event_type)
			
	return available

## Process currently active events
func _process_active_events() -> void:
	if not game_state:
		return
		
	var resolved_events := []
	
	for event in active_events:
		var duration = event.duration
		var turns_active = game_state.current_turn - event.turn_started
		
		if turns_active >= duration:
			resolved_events.append(event.type)
			
	for event_type in resolved_events:
		resolve_event(event_type)

## Save event manager state
func serialize() -> Dictionary:
	return {
		"active_events": active_events,
		"event_history": event_history,
		"event_cooldowns": event_cooldowns
	}

## Load event manager state
func deserialize(data: Dictionary) -> void:
	active_events = data.get("active_events", [])
	event_history = data.get("event_history", [])
	event_cooldowns = data.get("event_cooldowns", {}) 