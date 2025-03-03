@tool
extends Node
class_name BaseBattleEventSystem

# Signals
signal event_triggered(event_id: String, event_data: Dictionary)
signal event_resolved(event_id: String, outcome: Dictionary)
signal event_chain_started(chain_id: String)
signal event_chain_completed(chain_id: String)

# Event types
enum EventType {
	REINFORCEMENT,
	WEATHER_CHANGE,
	TERRAIN_CHANGE,
	OBJECTIVE_CHANGE,
	SPECIAL_RULE,
	NARRATIVE,
	CUSTOM
}

# Event trigger conditions
enum TriggerCondition {
	TURN_START,
	TURN_END,
	UNIT_DEATH,
	UNIT_DAMAGE,
	OBJECTIVE_PROGRESS,
	LOCATION_REACHED,
	CUSTOM
}

# Event storage
var registered_events: Dictionary = {}
var active_events: Array = []
var resolved_events: Array = []
var event_chains: Dictionary = {}

# Battle references
var battle_controller: Node = null
var battle_data: Node = null

# Configuration
var events_enabled: bool = true
var max_concurrent_events: int = 3
var event_probability_modifier: float = 1.0

# Virtual methods to be implemented by derived classes
func initialize(battle_controller_ref: Node = null, battle_data_ref: Node = null) -> void:
	battle_controller = battle_controller_ref
	battle_data = battle_data_ref
	
	registered_events.clear()
	active_events.clear()
	resolved_events.clear()
	event_chains.clear()
	
	_connect_signals()

func register_event(event_data: Dictionary) -> String:
	# Generate ID if not provided
	if not "id" in event_data or event_data.id.is_empty():
		event_data.id = _generate_event_id()
	
	# Set default values if not provided
	if not "type" in event_data:
		event_data.type = EventType.CUSTOM
	if not "name" in event_data:
		event_data.name = "Event " + event_data.id
	if not "description" in event_data:
		event_data.description = "Battle event"
	if not "trigger_conditions" in event_data:
		event_data.trigger_conditions = []
	if not "trigger_probability" in event_data:
		event_data.trigger_probability = 1.0
	if not "trigger_once" in event_data:
		event_data.trigger_once = true
	if not "chain_id" in event_data:
		event_data.chain_id = ""
	if not "chain_position" in event_data:
		event_data.chain_position = -1
	if not "outcomes" in event_data:
		event_data.outcomes = []
	if not "default_outcome" in event_data:
		event_data.default_outcome = {}
	if not "custom_data" in event_data:
		event_data.custom_data = {}
	
	# Store the event
	registered_events[event_data.id] = event_data
	
	# Add to chain if part of one
	if not event_data.chain_id.is_empty():
		if not event_data.chain_id in event_chains:
			event_chains[event_data.chain_id] = []
		
		event_chains[event_data.chain_id].append(event_data.id)
		
		# Sort chain by position if specified
		if event_data.chain_position >= 0:
			event_chains[event_data.chain_id].sort_custom(func(a, b):
				return registered_events[a].chain_position < registered_events[b].chain_position
			)
	
	return event_data.id

func register_event_chain(chain_id: String, events: Array) -> void:
	event_chains[chain_id] = []
	
	for event_data in events:
		event_data.chain_id = chain_id
		var event_id = register_event(event_data)
		event_chains[chain_id].append(event_id)

func trigger_event(event_id: String, trigger_data: Dictionary = {}) -> bool:
	if not events_enabled:
		return false
	
	if not event_id in registered_events:
		push_warning("Event ID not found: " + event_id)
		return false
	
	var event = registered_events[event_id]
	
	# Check if already active
	for active_event in active_events:
		if active_event.id == event_id:
			return false
	
	# Check if already resolved and trigger_once is true
	if event.trigger_once:
		for resolved_event in resolved_events:
			if resolved_event.id == event_id:
				return false
	
	# Check max concurrent events
	if active_events.size() >= max_concurrent_events:
		return false
	
	# Check probability
	var probability = event.trigger_probability * event_probability_modifier
	if randf() > probability:
		return false
	
	# Add to active events
	active_events.append(event)
	
	# Trigger the event
	event_triggered.emit(event_id, event)
	
	return true

func trigger_event_chain(chain_id: String) -> bool:
	if not chain_id in event_chains or event_chains[chain_id].is_empty():
		push_warning("Event chain not found or empty: " + chain_id)
		return false
	
	# Trigger the first event in the chain
	var first_event_id = event_chains[chain_id][0]
	var success = trigger_event(first_event_id)
	
	if success:
		event_chain_started.emit(chain_id)
	
	return success

func resolve_event(event_id: String, outcome_id: String = "") -> bool:
	var event_index = -1
	var event = null
	
	# Find the event in active events
	for i in range(active_events.size()):
		if active_events[i].id == event_id:
			event_index = i
			event = active_events[i]
			break
	
	if event_index == -1:
		push_warning("Event not found in active events: " + event_id)
		return false
	
	# Find the outcome
	var outcome = event.default_outcome
	if not outcome_id.is_empty():
		for o in event.outcomes:
			if o.id == outcome_id:
				outcome = o
				break
	
	# Apply outcome effects
	_apply_outcome_effects(event, outcome)
	
	# Remove from active events
	active_events.remove_at(event_index)
	
	# Add to resolved events
	resolved_events.append(event)
	
	# Emit signal
	event_resolved.emit(event_id, outcome)
	
	# Check if part of a chain
	if not event.chain_id.is_empty():
		_advance_event_chain(event.chain_id, event_id)
	
	return true

func get_active_events() -> Array:
	return active_events

func get_resolved_events() -> Array:
	return resolved_events

func get_event(event_id: String) -> Dictionary:
	if not event_id in registered_events:
		return {}
	
	return registered_events[event_id]

func is_event_active(event_id: String) -> bool:
	for event in active_events:
		if event.id == event_id:
			return true
	
	return false

func is_event_resolved(event_id: String) -> bool:
	for event in resolved_events:
		if event.id == event_id:
			return true
	
	return false

func set_events_enabled(enabled: bool) -> void:
	events_enabled = enabled

func set_event_probability_modifier(modifier: float) -> void:
	event_probability_modifier = max(0.0, modifier)

# Helper methods
func _connect_signals() -> void:
	# To be implemented by derived classes
	# Connect to battle controller signals to listen for trigger conditions
	pass

func _check_trigger_conditions(event: Dictionary, condition_type: int, condition_data: Dictionary) -> bool:
	# Check if the event has the specified trigger condition
	for condition in event.trigger_conditions:
		if condition.type == condition_type:
			# Check specific condition parameters
			var matches = true
			
			for key in condition:
				if key != "type" and key in condition_data:
					if condition[key] != condition_data[key]:
						matches = false
						break
			
			if matches:
				return true
	
	return false

func _apply_outcome_effects(event: Dictionary, outcome: Dictionary) -> void:
	# To be implemented by derived classes
	# Apply the effects of the outcome
	pass

func _advance_event_chain(chain_id: String, current_event_id: String) -> void:
	if not chain_id in event_chains:
		return
	
	var chain = event_chains[chain_id]
	var current_index = chain.find(current_event_id)
	
	if current_index == -1 or current_index >= chain.size() - 1:
		# End of chain
		event_chain_completed.emit(chain_id)
		return
	
	# Trigger next event in chain
	var next_event_id = chain[current_index + 1]
	trigger_event(next_event_id)

func _generate_event_id() -> String:
	return "event_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

# Event checking methods - called by signal handlers
func check_turn_start_events(turn: int, faction: String) -> void:
	if not events_enabled:
		return
	
	for event_id in registered_events:
		var event = registered_events[event_id]
		
		if _check_trigger_conditions(event, TriggerCondition.TURN_START, {
			"turn": turn,
			"faction": faction
		}):
			trigger_event(event_id, {
				"turn": turn,
				"faction": faction
			})

func check_turn_end_events(turn: int, faction: String) -> void:
	if not events_enabled:
		return
	
	for event_id in registered_events:
		var event = registered_events[event_id]
		
		if _check_trigger_conditions(event, TriggerCondition.TURN_END, {
			"turn": turn,
			"faction": faction
		}):
			trigger_event(event_id, {
				"turn": turn,
				"faction": faction
			})

func check_unit_death_events(unit: Node, killer: Node = null) -> void:
	if not events_enabled:
		return
	
	for event_id in registered_events:
		var event = registered_events[event_id]
		
		if _check_trigger_conditions(event, TriggerCondition.UNIT_DEATH, {
			"unit": unit,
			"killer": killer
		}):
			trigger_event(event_id, {
				"unit": unit,
				"killer": killer
			})

func check_unit_damage_events(unit: Node, damage: int, source: Node = null) -> void:
	if not events_enabled:
		return
	
	for event_id in registered_events:
		var event = registered_events[event_id]
		
		if _check_trigger_conditions(event, TriggerCondition.UNIT_DAMAGE, {
			"unit": unit,
			"damage": damage,
			"source": source
		}):
			trigger_event(event_id, {
				"unit": unit,
				"damage": damage,
				"source": source
			})

func check_objective_progress_events(objective_id: String, progress: float) -> void:
	if not events_enabled:
		return
	
	for event_id in registered_events:
		var event = registered_events[event_id]
		
		if _check_trigger_conditions(event, TriggerCondition.OBJECTIVE_PROGRESS, {
			"objective_id": objective_id,
			"progress": progress
		}):
			trigger_event(event_id, {
				"objective_id": objective_id,
				"progress": progress
			})

func check_location_reached_events(unit: Node, location: Vector2) -> void:
	if not events_enabled:
		return
	
	for event_id in registered_events:
		var event = registered_events[event_id]
		
		if _check_trigger_conditions(event, TriggerCondition.LOCATION_REACHED, {
			"unit": unit,
			"location": location
		}):
			trigger_event(event_id, {
				"unit": unit,
				"location": location
			})

func check_custom_condition_events(condition_id: String, condition_data: Dictionary) -> void:
	if not events_enabled:
		return
	
	for event_id in registered_events:
		var event = registered_events[event_id]
		
		if _check_trigger_conditions(event, TriggerCondition.CUSTOM, {
			"condition_id": condition_id,
			"data": condition_data
		}):
			trigger_event(event_id, {
				"condition_id": condition_id,
				"data": condition_data
			})

# Utility methods
func get_event_description(event_id: String) -> String:
	if not event_id in registered_events:
		return ""
	
	return registered_events[event_id].description

func get_outcome_description(event_id: String, outcome_id: String) -> String:
	if not event_id in registered_events:
		return ""
	
	var event = registered_events[event_id]
	
	for outcome in event.outcomes:
		if outcome.id == outcome_id:
			return outcome.get("description", "")
	
	return ""