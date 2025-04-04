@tool
extends Node
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/managers/EventManager.gd")

## Manager for game events, both scripted and dynamic
##
## This system handles event tracking, triggering, and resolution for the game.
## It supports scripted events, random events, and player-triggered events.
## Events can have conditions, choices, and outcomes.

# Dependencies (use preload to avoid circular references)
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")
const ResourceSystem = preload("res://src/core/systems/ResourceSystem.gd")
const MissionGeneratorClass = preload("res://src/core/systems/MissionGenerator.gd")

# Signals
signal event_triggered(event_id: String, event_data: Dictionary)
signal event_completed(event_id: String, outcome: Dictionary)
signal event_choice_made(event_id: String, choice_id: String)
signal random_event_available(event_id: String)
signal campaign_event_triggered(event_data: Dictionary)
signal campaign_event_resolved(event_data: Dictionary)
signal mission_event_triggered(mission_data: Dictionary)
signal mission_event_resolved(mission_data: Dictionary)

# Variables for the legacy event system
var active_events: Array = []
var event_history: Array = []
var event_cooldowns: Dictionary = {}
var campaign_events: Array = []
var mission_events: Array = []

# Event Collection
var _event_catalog: Dictionary = {} # All available events
var _active_events: Array[Dictionary] = [] # Currently active events
var _completed_events: Array[String] = [] # IDs of completed events
var _available_random_events: Array[String] = [] # IDs of available random events

# Dependencies
var game_state: FiveParsecsGameState
var resource_system: ResourceSystem
var mission_generator: Node

# Constants
const MAX_ACTIVE_EVENTS: int = 5
const RANDOM_EVENT_COOLDOWN: int = 3 # Turns

# Configuration
const MAX_HISTORY_SIZE := 100 # Limit event history size
const MIN_EVENT_INTERVAL := 3 # Minimum turns between events
const BASE_EVENT_CHANCE := 0.2 # 20% chance per turn
const COOLDOWN_DURATION := 10 # Turns before same event type can occur again

# Campaign event definitions
const CAMPAIGN_EVENTS = {
	"MARKET_OPPORTUNITY": {
		"category": "upkeep",
		"probability": 0.15,
		"effects": {
			"resources": {
				"CREDITS": {"type": "multiplier", "value": 1.5, "duration": 2},
				"SUPPLIES": {"type": "discount", "value": 0.25, "duration": 2}
			},
			"requirements": ["credits >= 500", "reputation >= 10"]
		}
	},
	"SUPPLY_SHORTAGE": {
		"category": "upkeep",
		"probability": 0.2,
		"effects": {
			"resources": {
				"SUPPLIES": {"type": "multiplier", "value": 2.0, "duration": 3},
				"MEDICAL_SUPPLIES": {"type": "multiplier", "value": 1.5, "duration": 3}
			},
			"requirements": []
		}
	},
	"TECH_REVOLUTION": {
		"category": "world_step",
		"probability": 0.1,
		"effects": {
			"resources": {
				"WEAPONS": {"type": "discount", "value": 0.3, "duration": 4},
				"EXPERIENCE": {"type": "bonus", "value": 50, "duration": 1}
			},
			"requirements": ["tech_level >= 2"]
		}
	},
	"PIRATE_RAID": {
		"category": "world_step",
		"probability": 0.25,
		"effects": {
			"resources": {
				"CREDITS": {"type": "penalty", "value": 0.2, "duration": 2},
				"SUPPLIES": {"type": "penalty", "value": 0.15, "duration": 2}
			},
			"requirements": []
		}
	}
}

# Mission event definitions
const MISSION_EVENTS = {
	"RIVAL_INTERFERENCE": {
		"category": "mission",
		"probability": 0.2,
		"effects": {
			"mission_difficulty": 1.5,
			"rival_presence": true,
			"rewards": {
				"multiplier": 1.3
			}
		}
	},
	"UNEXPECTED_ALLIES": {
		"category": "mission",
		"probability": 0.15,
		"effects": {
			"mission_difficulty": 0.8,
			"ally_support": true,
			"reputation_bonus": 5
		}
	},
	"ENVIRONMENTAL_HAZARD": {
		"category": "mission",
		"probability": 0.25,
		"effects": {
			"mission_difficulty": 1.2,
			"hazard_level": 2,
			"rewards": {
				"multiplier": 1.2
			}
		}
	},
	"CRITICAL_INTEL": {
		"category": "mission",
		"probability": 0.1,
		"effects": {
			"bonus_objective": true,
			"rewards": {
				"multiplier": 1.5,
				"intel_points": 2
			}
		}
	}
}

# Initialize the event manager
func _init() -> void:
	# Create empty event catalog
	_event_catalog = {}
	
func _ready() -> void:
	# Connect to autoloads if we're not in the editor
	if not Engine.is_editor_hint():
		await get_tree().process_frame
		_connect_signals()

# Connect to required signals
func _connect_signals() -> void:
	# Find autoloaded dependencies
	if not game_state:
		var state = get_node_or_null("/root/GameState")
		if state:
			game_state = state
			
	if not resource_system:
		var resources = get_node_or_null("/root/ResourceSystem")
		if resources:
			resource_system = resources

	if not mission_generator:
		var mission_gen = get_node_or_null("/root/Game/Systems/MissionGenerator")
		if mission_gen is MissionGeneratorClass:
			mission_generator = mission_gen
		else:
			push_error("Failed to get MissionGenerator node")

# Register an event in the catalog
func register_event(event_data: Dictionary) -> void:
	if not _validate_event_data(event_data):
		push_error("Invalid event data: %s" % event_data.get("id", "UNKNOWN"))
		return
		
	var event_id = event_data.id
	_event_catalog[event_id] = event_data
	
	# Check if it's a random event
	if event_data.get("is_random", false):
		_available_random_events.append(event_id)

# Validate event data
func _validate_event_data(event_data: Dictionary) -> bool:
	# Required fields
	var required_fields = ["id", "title", "description", "choices"]
	
	for field in required_fields:
		if not event_data.has(field):
			push_error("Event missing required field: %s" % field)
			return false
			
	# Validate choices
	if event_data.choices.size() == 0:
		push_error("Event must have at least one choice")
		return false
		
	for choice in event_data.choices:
		if not choice.has("id") or not choice.has("text"):
			push_error("Choice missing required fields")
			return false
	
	return true

# Trigger an event by ID in the new event system
func trigger_event_by_id(event_id: String) -> bool:
	if not _event_catalog.has(event_id):
		push_error("Event not found in catalog: %s" % event_id)
		return false
		
	# Check if we can have more active events
	if _active_events.size() >= MAX_ACTIVE_EVENTS:
		push_warning("Too many active events, cannot trigger: %s" % event_id)
		return false
		
	# Check if the event has already been completed
	if event_id in _completed_events:
		# If it's a one-time event, don't trigger again
		if _event_catalog[event_id].get("one_time", false):
			push_warning("One-time event already completed: %s" % event_id)
			return false
			
	# Clone the event data
	var event_data = _event_catalog[event_id].duplicate(true)
	
	# Add to active events
	_active_events.append(event_data)
	
	# Emit signal
	event_triggered.emit(event_id, event_data)
	
	return true

# Make a choice in an active event
func make_choice(event_id: String, choice_id: String) -> bool:
	# Find the active event
	var event_index = -1
	
	for i in range(_active_events.size()):
		if _active_events[i].id == event_id:
			event_index = i
			break
			
	if event_index == -1:
		push_error("Event not active: %s" % event_id)
		return false
		
	var event = _active_events[event_index]
	
	# Find the choice
	var choice = null
	
	for c in event.choices:
		if c.id == choice_id:
			choice = c
			break
			
	if choice == null:
		push_error("Choice not found: %s" % choice_id)
		return false
		
	# Process choice outcome
	var outcome = _process_choice_outcome(event, choice)
	
	# Remove from active events
	_active_events.remove_at(event_index)
	
	# Add to completed events
	_completed_events.append(event_id)
	
	# Emit signals
	event_choice_made.emit(event_id, choice_id)
	event_completed.emit(event_id, outcome)
	
	return true

# Process the outcome of a choice
func _process_choice_outcome(event: Dictionary, choice: Dictionary) -> Dictionary:
	var outcome = {
		"event_id": event.id,
		"choice_id": choice.id,
		"result_text": choice.get("result_text", ""),
		"resources_changed": [],
		"flags_set": []
	}
	
	# Process resource changes
	var resource_changes = choice.get("resource_changes", [])
	
	for change in resource_changes:
		var type = change.get("type", 0)
		var amount = change.get("amount", 0)
		
		if amount != 0 and resource_system:
			if amount > 0:
				resource_system.add_resource(type, amount, "event:" + event.id)
			else:
				resource_system.remove_resource(type, abs(amount), "event:" + event.id)
			
			outcome.resources_changed.append({
				"type": type,
				"amount": amount
			})
	
	# Process flag changes
	var flag_changes = choice.get("flag_changes", [])
	
	for flag in flag_changes:
		var flag_name = flag.get("name", "")
		var flag_value = flag.get("value", true)
		
		if not flag_name.is_empty() and game_state:
			game_state.set_flag(flag_name, flag_value)
			
			outcome.flags_set.append({
				"name": flag_name,
				"value": flag_value
			})
	
	return outcome

# Check for random events
func check_random_events() -> bool:
	if _available_random_events.is_empty():
		return false
		
	# Check if we're on a cooldown
	if game_state:
		var last_random_event = game_state.get_meta("last_random_event_turn", -RANDOM_EVENT_COOLDOWN)
		var current_turn = game_state.turn_number
		
		if current_turn - last_random_event < RANDOM_EVENT_COOLDOWN:
			return false
	
	# Random chance to trigger event
	if randf() > 0.25: # 25% chance each check
		return false
		
	# Select a random event
	var random_index = randi() % _available_random_events.size()
	var event_id = _available_random_events[random_index]
	
	# Mark this turn for cooldown
	if game_state:
		game_state.set_meta("last_random_event_turn", game_state.turn_number)
	
	random_event_available.emit(event_id)
	
	return true

# Get the list of active events
func get_active_events() -> Array:
	var events = []
	for event in _active_events:
		events.append(event.duplicate())
	return events

# Get the list of available events
func get_available_events() -> Array:
	var events = []
	for event_id in _event_catalog.keys():
		# Skip events that have been completed if they're one-time
		if _event_catalog[event_id].get("one_time", false) and event_id in _completed_events:
			continue
			
		events.append(_event_catalog[event_id].duplicate())
	
	return events

# Clear all events
func reset() -> void:
	_active_events.clear()
	_completed_events.clear()
	_available_random_events.clear()
	
	# Re-add all random events
	for event_id in _event_catalog.keys():
		if _event_catalog[event_id].get("is_random", false):
			_available_random_events.append(event_id)
		
# Save event state for the new event system
func serialize_v2() -> Dictionary:
	var active_events = []
	for event in _active_events:
		active_events.append(event.duplicate())
	
	return {
		"active_events": active_events,
		"completed_events": _completed_events.duplicate(),
		"available_random_events": _available_random_events.duplicate()
	}

# Load event state for the new event system
func deserialize_v2(data: Dictionary) -> void:
	_active_events.clear()
	for event in data.get("active_events", []):
		_active_events.append(event)
		
	_completed_events = data.get("completed_events", []).duplicate()
	_available_random_events = data.get("available_random_events", []).duplicate()

# Save event manager state for the legacy system
func serialize_legacy() -> Dictionary:
	var campaign_events_data = []
	for event in campaign_events:
		campaign_events_data.append(event.duplicate(true))
	
	return {
		"active_events": active_events,
		"event_history": event_history,
		"event_cooldowns": event_cooldowns,
		"campaign_events": campaign_events_data
	}

# Load event manager state for the legacy system
func deserialize_legacy(data: Dictionary) -> void:
	if data.has("active_events"):
		active_events = data.active_events
	if data.has("event_history"):
		event_history = data.event_history
	if data.has("event_cooldowns"):
		event_cooldowns = data.event_cooldowns
	if data.has("campaign_events"):
		campaign_events = data.campaign_events

## Update event state
func update() -> void:
	_update_cooldowns()
	_check_random_events()
	_process_active_events()
	_process_campaign_events()
	_process_mission_events()
	_trim_event_history()

## Process campaign events
func _process_campaign_events() -> void:
	var resolved_events := []
	
	for event in campaign_events:
		if event.has("duration") and event.has("turn_started"):
			var turns_active = game_state.current_turn - event.turn_started
			if turns_active >= event.duration:
				resolved_events.append(event)
	
	for event in resolved_events:
		campaign_events.erase(event)
		campaign_event_resolved.emit(event)

## Trigger a campaign event
func trigger_campaign_event(event_name: String) -> void:
	if not CAMPAIGN_EVENTS.has(event_name):
		return
	
	var event_def = CAMPAIGN_EVENTS[event_name]
	if not _check_campaign_event_requirements(event_def.effects.requirements):
		return
	
	var event_data = {
		"name": event_name,
		"category": event_def.category,
		"turn_started": game_state.current_turn,
		"effects": event_def.effects.duplicate(true)
	}
	
	# Calculate duration based on effects
	var max_duration := 0
	for resource in event_def.effects.resources:
		var effect = event_def.effects.resources[resource]
		if effect.has("duration"):
			max_duration = max(max_duration, effect.duration)
	event_data["duration"] = max_duration
	
	campaign_events.append(event_data)
	_apply_campaign_event_effects(event_data)
	campaign_event_triggered.emit(event_data)

## Check campaign event requirements
func _check_campaign_event_requirements(requirements: Array) -> bool:
	for req in requirements:
		var parts = req.split(" ")
		match parts[0]:
			"credits":
				var amount = int(parts[2])
				if not _compare_value(resource_system.get_resource_amount(GameEnums.ResourceType.CREDITS), parts[1], amount):
					return false
			"reputation":
				var amount = int(parts[2])
				if not _compare_value(resource_system.get_resource_amount(GameEnums.ResourceType.REPUTATION), parts[1], amount):
					return false
			"tech_level":
				var level = int(parts[2])
				if not _compare_value(game_state.tech_level, parts[1], level):
					return false
	return true

## Apply campaign event effects
func _apply_campaign_event_effects(event_data: Dictionary) -> void:
	var effects = event_data.effects
	if effects.has("resources"):
		for resource_name in effects.resources:
			var resource_type = GameEnums.ResourceType[resource_name]
			var effect = effects.resources[resource_name]
			
			match effect.type:
				"multiplier":
					var current = resource_system.get_resource_amount(resource_type)
					var bonus = int(current * (effect.value - 1.0))
					if bonus > 0:
						resource_system.add_resource(resource_type, bonus, "event_" + event_data.name)
				"discount":
					# Handled by market system
					pass
				"bonus":
					resource_system.add_resource(resource_type, effect.value, "event_" + event_data.name)
				"penalty":
					var current = resource_system.get_resource_amount(resource_type)
					var penalty = int(current * effect.value)
					if penalty > 0:
						resource_system.remove_resource(resource_type, penalty, "event_" + event_data.name)

## Remove campaign event effects
func _remove_campaign_event_effects(event_data: Dictionary) -> void:
	var effects = event_data.effects
	if effects.has("resources"):
		for resource_name in effects.resources:
			var resource_type = GameEnums.ResourceType[resource_name]
			var effect = effects.resources[resource_name]
			
			match effect.type:
				"multiplier":
					var current = resource_system.get_resource_amount(resource_type)
					var reduction = int(current * (effect.value - 1.0))
					if reduction > 0:
						resource_system.remove_resource(resource_type, reduction, "event_end_" + event_data.name)
				"bonus", "penalty":
					# One-time effects, no need to remove
					pass

## Get active campaign events
func get_active_campaign_events() -> Array:
	return campaign_events.duplicate()

## Check if a campaign event is active
func is_campaign_event_active(event_name: String) -> bool:
	for event in campaign_events:
		if event.name == event_name:
			return true
	return false

## Get campaign event effect value
func get_campaign_event_effect(resource_type: int, effect_type: String) -> float:
	var total_effect := 1.0
	
	for event in campaign_events:
		var effects = event.effects
		if effects.has("resources"):
			var resource_name = GameEnums.ResourceType.keys()[resource_type]
			if effects.resources.has(resource_name):
				var effect = effects.resources[resource_name]
				if effect.type == effect_type:
					match effect_type:
						"multiplier":
							total_effect *= effect.value
						"discount":
							total_effect *= (1.0 - effect.value)
	
	return total_effect

## Trim event history to prevent unbounded growth
func _trim_event_history() -> void:
	if event_history.size() > MAX_HISTORY_SIZE:
		event_history = event_history.slice(-MAX_HISTORY_SIZE)

## Update event cooldowns
func _update_cooldowns() -> void:
	var expired_cooldowns := []
	
	for event_type in event_cooldowns:
		event_cooldowns[event_type] = max(0, event_cooldowns[event_type] - 1)
		if event_cooldowns[event_type] <= 0:
			expired_cooldowns.append(event_type)
			
	for event_type in expired_cooldowns:
		event_cooldowns.erase(event_type)

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

## Trigger a specific event by enum type in the legacy system
func trigger_event_by_type(event_type: GameEnums.GlobalEvent) -> void:
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
	
	event_triggered.emit(event_type, event_data)
	_apply_event_effects(event_data.effects, event_type)

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
		event_completed.emit(event.id, _process_choice_outcome(event, event.choices[0]))

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
				"economy_modifier": - 0.25,
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
## @param effects: Dictionary of effects to apply
## @param source_event_type: The type of event that generated these effects
func _apply_event_effects(effects: Dictionary, source_event_type: int = 0) -> void:
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
	
	event_triggered.emit(source_event_type, effects)

## Remove event effects from game state
func _remove_event_effects(effects: Dictionary) -> void:
	if not game_state:
		return
		
	for effect in effects:
		if effect == "resource_penalties":
			var penalties = effects[effect]
			for resource_type in penalties:
				game_state.add_resource_penalty(resource_type, -penalties[resource_type])
		elif effect == "tech_discount":
			game_state.apply_tech_discount(-effects[effect])

## Compare two values with an operator
func _compare_value(value: float, operator: String, target: float) -> bool:
	match operator:
		">=": return value >= target
		"<=": return value <= target
		">": return value > target
		"<": return value < target
		"==": return value == target
		_: return false

## Process mission events
func _process_mission_events() -> void:
	var resolved_events := []
	
	for event in mission_events:
		if event.has("duration") and event.has("turn_started"):
			var turns_active = game_state.current_turn - event.turn_started
			if turns_active >= event.duration:
				resolved_events.append(event)
	
	for event in resolved_events:
		mission_events.erase(event)
		mission_event_resolved.emit(event)

## Trigger a mission event
func trigger_mission_event(event_name: String, mission: Mission) -> void:
	if not MISSION_EVENTS.has(event_name) or not mission:
		return
	
	var event_def = MISSION_EVENTS[event_name]
	var event_data = {
		"name": event_name,
		"category": event_def.category,
		"turn_started": game_state.current_turn,
		"mission_id": mission.get_instance_id(),
		"effects": event_def.effects.duplicate(true)
	}
	
	# Calculate duration based on mission length
	event_data["duration"] = mission.get_estimated_duration()
	
	mission_events.append(event_data)
	_apply_mission_event_effects(event_data, mission)
	event_triggered.emit(event_name, event_data)

## Apply mission event effects
func _apply_mission_event_effects(event_data: Dictionary, mission: Mission) -> void:
	var effects = event_data.effects
	
	# Apply difficulty modifier
	if effects.has("mission_difficulty"):
		mission.difficulty = roundi(mission.difficulty * effects.mission_difficulty)
	
	# Apply reward modifiers
	if effects.has("rewards"):
		var rewards = effects.rewards
		if rewards.has("multiplier"):
			for reward_type in mission.rewards:
				if reward_type is int or reward_type is float:
					mission.rewards[reward_type] = roundi(mission.rewards[reward_type] * rewards.multiplier)
		
		if rewards.has("intel_points"):
			if not mission.rewards.has("intel"):
				mission.rewards["intel"] = 0
			mission.rewards["intel"] += rewards.intel_points
	
	# Add bonus objectives
	if effects.has("bonus_objective") and effects.bonus_objective:
		var bonus_objective = _generate_bonus_objective(mission)
		if bonus_objective:
			mission.objectives.append(bonus_objective)
	
	# Add special conditions
	if effects.has("hazard_level"):
		mission.special_rules.append("HAZARD_LEVEL_%d" % effects.hazard_level)
	
	if effects.has("rival_presence") and effects.rival_presence:
		mission.special_rules.append("RIVAL_PRESENCE")
	
	if effects.has("ally_support") and effects.ally_support:
		mission.special_rules.append("ALLY_SUPPORT")

## Remove mission event effects
func _remove_mission_event_effects(event_data: Dictionary) -> void:
	var mission = instance_from_id(event_data.mission_id) as Mission
	if not mission:
		return
	
	var effects = event_data.effects
	
	# Reverse difficulty modifier
	if effects.has("mission_difficulty"):
		mission.difficulty = roundi(mission.difficulty / effects.mission_difficulty)
	
	# Remove special conditions
	if effects.has("hazard_level"):
		mission.special_rules.erase("HAZARD_LEVEL_%d" % effects.hazard_level)
	
	if effects.has("rival_presence") and effects.rival_presence:
		mission.special_rules.erase("RIVAL_PRESENCE")
	
	if effects.has("ally_support") and effects.ally_support:
		mission.special_rules.erase("ALLY_SUPPORT")

## Generate a bonus objective for a mission
func _generate_bonus_objective(mission: Mission) -> Dictionary:
	var possible_objectives = [
		{
			"type": GameEnums.MissionObjective.SABOTAGE,
			"description": "Sabotage enemy equipment"
		},
		{
			"type": GameEnums.MissionObjective.RECON,
			"description": "Gather additional intelligence"
		},
		{
			"type": GameEnums.MissionObjective.RESCUE,
			"description": "Rescue stranded allies"
		}
	]
	
	# Filter out objectives that are already in the mission
	possible_objectives = possible_objectives.filter(func(obj: Dictionary) -> bool:
		for existing in mission.objectives:
			if existing.type == obj.type:
				return false
		return true
	)
	
	if possible_objectives.is_empty():
		return {}
	
	return possible_objectives.pick_random()

## Get active mission events
func get_active_mission_events() -> Array:
	return mission_events.duplicate()

## Check if a mission event is active
func is_mission_event_active(event_name: String) -> bool:
	for event in mission_events:
		if event.name == event_name:
			return true
	return false

## Get mission event effect value
func get_mission_event_effect(effect_type: String) -> float:
	var total_effect := 1.0
	
	for event in mission_events:
		var effects = event.effects
		if effects.has(effect_type):
			match typeof(effects[effect_type]):
				TYPE_FLOAT, TYPE_INT:
					total_effect *= effects[effect_type]
	
	return total_effect

# Check for random events in the legacy system
func _check_random_events() -> void:
	if not game_state:
		return
		
	if randf() < BASE_EVENT_CHANCE:
		var available_events := _get_available_events()
		if not available_events.is_empty():
			var random_event = available_events[randi() % available_events.size()]
			trigger_event_by_type(random_event)

# Get list of events that can be triggered
func _get_available_events() -> Array:
	var available := []
	
	for event_type in GameEnums.GlobalEvent.values():
		if event_type != GameEnums.GlobalEvent.NONE and _can_trigger_event(event_type):
			available.append(event_type)
			
	return available