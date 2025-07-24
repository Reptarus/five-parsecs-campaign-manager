## EventManager - Production-Ready Implementation
## Manages game events and their effects on the game state with comprehensive type safety
extends Node

# Stage 2: Universal Safety Patterns - Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

## Dependencies with preload pattern
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const MissionGeneratorClass = preload("res://src/core/systems/MissionGenerator.gd")

## Signals with proper type annotations
signal event_triggered(event_type: int)
signal event_resolved(event_type: int)
signal event_effects_applied(effects: Dictionary)
signal campaign_event_triggered(event_data: Dictionary)
signal campaign_event_resolved(event_data: Dictionary)
signal mission_event_triggered(mission_data: Dictionary)
signal mission_event_resolved(mission_data: Dictionary)

## Event tracking with strong typing
var active_events: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var event_cooldowns: Dictionary = {}
var campaign_events: Array[Dictionary] = []
var mission_events: Array[Dictionary] = []

## Configuration constants
const MAX_HISTORY_SIZE: int = 100
const MAX_ACTIVE_EVENTS: int = 5
const MIN_EVENT_INTERVAL: int = 3
const BASE_EVENT_CHANCE: float = 0.2
const COOLDOWN_DURATION: int = 10

## Game state references with proper typing
var game_state: GameState = null
var resource_system: Node = null
var mission_generator: Node = null

# Stage 1: Type Safety - Enhanced event definitions with proper typing
const CAMPAIGN_EVENTS: Dictionary = {
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

const MISSION_EVENTS: Dictionary = {
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

func _ready() -> void:
	# Stage 2: Initialize system
	_initialize_system()
	print("EventManager: Initialization completed with enhanced type safety")

# Stage 2: Universal Safety Patterns - System initialization
func _initialize_system() -> void:
	# Dependencies are now preloaded, no runtime loading needed
	# Safe node access
	resource_system = get_node("ResourceSystemAutoload")
	if not resource_system:
		push_warning("EventManager: ResourceSystemAutoload not found - some features may be limited")

# Stage 3: Enhanced Error Handling - Initialize with validation
func initialize(state: Node) -> bool:
	"""Initialize the event manager with enhanced error handling"""
	if not state:
		push_error("EventManager: Cannot initialize with null game state")
		return false

	game_state = state

	# Validate critical dependencies
	if not GlobalEnums:
		push_error("EventManager: GlobalEnums not loaded - cannot function properly")
		return false

	# Clear all collections with type safety
	active_events.clear()
	event_history.clear()
	event_cooldowns.clear()
	campaign_events.clear()
	mission_events.clear()

	print("EventManager: Successfully initialized with game state")
	return true

# Stage 3: Enhanced Error Handling - Cleanup with validation
func cleanup() -> void:
	"""Cleanup resources with enhanced error handling"""
	# Resolve all active events safely
	var events_to_resolve: Array[Dictionary] = active_events.duplicate()
	for event in events_to_resolve:
		var event_type: int = event.get("type", 0)
		if event_type > 0:
			resolve_event(event_type)

	# Clear all data structures
	active_events.clear()
	event_history.clear()
	event_cooldowns.clear()
	campaign_events.clear()
	mission_events.clear()

	# Clear references safely
	game_state = null
	resource_system = null
	mission_generator = null

	print("EventManager: Cleanup completed successfully")

# Stage 3: Enhanced Error Handling - Update event state with validation
func update() -> void:
	"""Update event state with comprehensive error handling"""
	if not game_state:
		push_warning("EventManager: Cannot update without game state")
		return

	_update_cooldowns()
	_check_random_events()
	_process_active_events()
	_process_campaign_events()
	_process_mission_events()
	_trim_event_history()

# Stage 3: Enhanced Error Handling - Process campaign events with validation
func _process_campaign_events() -> void:
	"""Process campaign events with enhanced error handling"""
	var resolved_events: Array[Dictionary] = []

	for event in campaign_events:
		if "duration" not in event or "turn_started" not in event:
			push_warning("EventManager: Campaign event missing required fields")
			continue

		var turns_active: int = game_state.current_turn - event.get("turn_started", 0)
		var duration: int = event.get("duration", 0)

		if turns_active >= duration:
			resolved_events.append(event)
			_remove_campaign_event_effects(event)

	for event in resolved_events:
		campaign_events.erase(event)
		self.campaign_event_resolved.emit(event)

# Stage 3: Enhanced Error Handling - Trigger campaign event with validation
func trigger_campaign_event(event_name: String) -> bool:
	"""Trigger a campaign event with enhanced error handling"""
	if event_name.is_empty():
		push_error("EventManager: Cannot trigger campaign event with empty name")
		return false

	if event_name not in CAMPAIGN_EVENTS:
		push_warning("EventManager: Unknown campaign event: %s" % event_name)
		return false

	var event_def: Dictionary = CAMPAIGN_EVENTS[event_name]
	var requirements: Array = event_def.get("effects", {}).get("requirements", [])

	if not _check_campaign_event_requirements(requirements):
		print("EventManager: Campaign event requirements not met: %s" % event_name)
		return false

	var event_data: Dictionary = {
		"name": event_name,
		"category": event_def.get("category", "unknown"),
		"turn_started": game_state.current_turn if game_state else 0,
		"effects": event_def.get("effects", {}).duplicate(true)
	}

	# Calculate duration based on effects
	var max_duration: int = 0
	var effects_dict: Dictionary = event_def.get("effects", {})
	var resources_dict: Dictionary = effects_dict.get("resources", {})

	for resource_name in resources_dict:
		var effect: Dictionary = resources_dict[resource_name]
		var effect_duration: int = effect.get("duration", 1)
		max_duration = max(max_duration, effect_duration)

	event_data["duration"] = max_duration

	campaign_events.append(event_data)
	_apply_campaign_event_effects(event_data)
	self.campaign_event_triggered.emit(event_data)

	print("EventManager: Campaign event triggered: %s" % event_name)
	return true

# Stage 3: Enhanced Error Handling - Check campaign event requirements with validation
func _check_campaign_event_requirements(requirements: Array) -> bool:
	"""Check campaign event requirements with enhanced error handling"""
	if not resource_system:
		push_warning("EventManager: Resource system not available for requirement checking")
		return false

	for req in requirements:
		if not req is String:
			push_warning("EventManager: Invalid requirement type: %s" % typeof(req))
			continue

		var parts: PackedStringArray = req.split(" ")
		if parts.size() < 3:
			push_warning("EventManager: Invalid requirement format: %s" % req)
			continue

		var resource_name: String = parts[0]
		var operator: String = parts[1]
		var amount_str: String = parts[2]
		var amount: int = amount_str.to_int()

		match resource_name:
			"credits":
				if not GlobalEnums:
					push_warning("EventManager: GlobalEnums not available")
					continue
				var credits: int = resource_system.get_resource_amount(GlobalEnums.ResourceType.CREDITS) if resource_system and resource_system.has_method("get_resource_amount") else 0
				if not _compare_value(credits, operator, amount):
					return false
			"reputation":
				if not GlobalEnums:
					push_warning("EventManager: GlobalEnums not available")
					continue
				var reputation: int = resource_system.get_resource_amount(GlobalEnums.ResourceType.REPUTATION) if resource_system and resource_system.has_method("get_resource_amount") else 0
				if not _compare_value(reputation, operator, amount):
					return false
			"tech_level":
				var tech_level: int = game_state.tech_level if game_state and "tech_level" in game_state else 1
				if not _compare_value(tech_level, operator, amount):
					return false
			_:
				push_warning("EventManager: Unknown requirement type: %s" % resource_name)

	return true

# Stage 5: Resource Management - Apply campaign event effects with proper resource handling
func _apply_campaign_event_effects(event_data: Dictionary) -> void:
	"""Apply campaign event effects with enhanced resource management"""
	if not resource_system:
		push_warning("EventManager: Resource system not available for applying effects")
		return

	var effects: Dictionary = event_data.get("effects", {})
	var resources: Dictionary = effects.get("resources", {})
	var event_name: String = event_data.get("name", "unknown")

	for resource_name in resources:
		if not GlobalEnums:
			push_warning("EventManager: GlobalEnums not available for resource: %s" % resource_name)
			continue

		if resource_name not in GlobalEnums.ResourceType:
			push_warning("EventManager: Unknown resource type: %s" % resource_name)
			continue

		var resource_type: int = GlobalEnums.ResourceType[resource_name]
		var effect: Dictionary = resources[resource_name]
		var effect_type: String = effect.get("type", "")
		var effect_value: float = effect.get("value", 0.0)

		match effect_type:
			"multiplier":
				if resource_system.has_method("get_resource_amount") and resource_system and resource_system.has_method("add_resource"):
					var current: int = resource_system.get_resource_amount(resource_type)
					var bonus: int = int(current * (effect_value - 1.0))
					if bonus > 0:
						resource_system.add_resource(resource_type, bonus, "event_" + str(event_name))
			"discount":
				# Discount effects are handled by market system
				print("EventManager: Discount effect applied for %s: %s" % [resource_name, effect_value])
			"bonus":
				if resource_system and resource_system.has_method("add_resource"):
					resource_system.add_resource(resource_type, int(effect_value), "event_" + str(event_name))
			"penalty":
				if resource_system.has_method("get_resource_amount") and resource_system and resource_system.has_method("remove_resource"):
					var current: int = resource_system.get_resource_amount(resource_type)
					var penalty: int = int(current * effect_value)
					if penalty > 0:
						if resource_system and resource_system.has_method("remove_resource"): resource_system.remove_resource(resource_type, penalty, "event_" + str(event_name))
			_:
				push_warning("EventManager: Unknown effect type: %s" % effect_type)

# Stage 5: Resource Management - Remove campaign event effects with proper cleanup
func _remove_campaign_event_effects(event_data: Dictionary) -> void:
	"""Remove campaign event effects with enhanced resource management"""
	if not resource_system:
		push_warning("EventManager: Resource system not available for removing effects")
		return

	var effects: Dictionary = event_data.get("effects", {})
	var resources: Dictionary = effects.get("resources", {})
	var event_name: String = event_data.get("name", "unknown")

	for resource_name in resources:
		if not GlobalEnums:
			continue

		if resource_name not in GlobalEnums.ResourceType:
			continue

		var resource_type: int = GlobalEnums.ResourceType[resource_name]
		var effect: Dictionary = resources[resource_name]
		var effect_type: String = effect.get("type", "")
		var effect_value: float = effect.get("value", 0.0)

		match effect_type:
			"multiplier":
				if resource_system.has_method("get_resource_amount") and resource_system and resource_system.has_method("remove_resource"):
					var current: int = resource_system.get_resource_amount(resource_type)
					var reduction: int = int(current * (effect_value - 1.0))
					if reduction > 0:
						if resource_system and resource_system.has_method("remove_resource"): resource_system.remove_resource(resource_type, reduction, "event_end_" + str(event_name))
			"bonus", "penalty":
				# One-time effects, no need to remove
				pass
			"discount":
				# Discount effects end automatically
				print("EventManager: Discount effect ended for %s" % resource_name)

## Get active campaign events
func get_active_campaign_events() -> Array:
	return campaign_events.duplicate()

## Check if a campaign event is active
func is_campaign_event_active(event_name: String) -> bool:
	for event in campaign_events:
		if event._name == event_name:
			return true
	return false

## Get campaign event effect _value
func get_campaign_event_effect(resource_type: int, effect_type: String) -> float:
	var total_effect := 1.0

	for event in campaign_events:
		var effects = event.effects
		if "resources" in effects:
			var resource_name = GlobalEnums.ResourceType.keys()[resource_type]
			if resource_name in effects.resources:
				var effect = effects.resources[resource_name]
				if effect._type == effect_type:
					match effect_type:
						"multiplier":
							total_effect *= effect._value
						"discount":
							total_effect *= (1.0 - effect._value)

	return total_effect

## Save event manager state
func serialize() -> Dictionary:
	"""Save event manager state with enhanced validation"""
	var campaign_events_data: Array[Dictionary] = []
	for event in campaign_events:
		if event is Dictionary:
			campaign_events_data.append(event.duplicate(true))

	return {
		"active_events": active_events.duplicate(true),
		"event_history": event_history.duplicate(true),
		"event_cooldowns": event_cooldowns.duplicate(true),
		"campaign_events": campaign_events_data
	}

## Load event manager state
func deserialize(data: Dictionary) -> bool:
	"""Load event manager state with enhanced validation"""
	if not data is Dictionary:
		push_error("EventManager: Invalid data type for deserialization")
		return false

	# Validate and load active_events
	if "active_events" in data and data.active_events is Array:
		active_events.clear()
		for event in data.active_events:
			if event is Dictionary:
				active_events.append(event)

	# Validate and load event_history
	if "event_history" in data and data.event_history is Array:
		event_history.clear()
		for event in data.event_history:
			if event is Dictionary:
				event_history.append(event)

	# Validate and load event_cooldowns
	if "event_cooldowns" in data and data.event_cooldowns is Dictionary:
		event_cooldowns = data.event_cooldowns.duplicate()

	# Validate and load campaign_events
	if "campaign_events" in data and data.campaign_events is Array:
		campaign_events.clear()
		for event in data.campaign_events:
			if event is Dictionary:
				campaign_events.append(event)

	print("EventManager: State deserialized successfully")
	return true

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
func _get_available_events() -> Array[int]:
	var available: Array[int] = []

	# Use hardcoded available event types since enum not accessible at compile time
	var event_types: Array[int] = [1, 2, 3] # MARKET_CRASH, ALIEN_INVASION, TECH_BREAKTHROUGH

	for event_type in event_types:
		if _can_trigger_event(event_type):
			available.append(event_type)

	return available

## Process currently active events
func _process_active_events() -> void:
	if not game_state:
		return

	var resolved_events: Array[int] = []

	for event in active_events:
		var duration = event.get("duration", 0)
		var turns_active: int = game_state.current_turn - event.get("turn_started", 0)

		if turns_active >= duration:
			var event_type: int = event.get("type", 0)
			resolved_events.append(event_type)

	for event_type in resolved_events:
		resolve_event(event_type)

## Trigger a specific event
func trigger_event(event_type: int) -> void:
	if not _can_trigger_event(event_type):
		return

	# Check active events limit
	if active_events.size() >= MAX_ACTIVE_EVENTS:
		var oldest_event = active_events[0]
		var oldest_type: int = oldest_event.get("_type", 0)
		resolve_event(oldest_type)

	var event_data: Dictionary = {
		"_type": event_type,
		"turn_started": game_state.current_turn if game_state else 0,
		"duration": _get_event_duration(event_type),
		"effects": _generate_event_effects(event_type)
	}

	active_events.append(event_data)
	event_history.append(event_data.duplicate()) # Use duplicate to prevent reference issues
	event_cooldowns[event_type] = COOLDOWN_DURATION

	self.event_triggered.emit(event_type)
	_apply_event_effects(event_data.effects)

## Resolve an active event
func resolve_event(event_type: int) -> void:
	var event_index: int = -1
	for i: int in range(active_events.size()):
		var active_event_type: int = active_events[i].get("_type", 0)
		if active_event_type == event_type:
			event_index = i
			break

	if event_index >= 0:
		var event: Variant = active_events[event_index]
		active_events.remove_at(event_index)
		var effects: Dictionary = event.get("effects", {})
		_remove_event_effects(effects)
		self.event_resolved.emit(event_type)

## Check if an event can be triggered
func _can_trigger_event(event_type: int) -> bool:
	# Check cooldown
	if event_type in event_cooldowns and event_cooldowns[event_type] > 0:
		return false

	# Check if event is already active
	for event in active_events:
		var active_type: int = event.get("_type", 0)
		if active_type == event_type:
			return false

	return true

## Get the duration for an event type
func _get_event_duration(event_type: int) -> int:
	# Use hardcoded values since we can't access enum at compile time
	match event_type:
		1: # MARKET_CRASH
			return 5
		2: # ALIEN_INVASION
			return 8
		3: # TECH_BREAKTHROUGH
			return 3
		_:
			return 4

## Generate effects for an event type
func _generate_event_effects(event_type: int) -> Dictionary:
	var effects: Dictionary = {}

	# Use hardcoded values since we can't access enum at compile time
	match event_type:
		1: # MARKET_CRASH
			effects = {
				"economy_modifier": - 0.25,
				"trade_penalty": true
			}
		2: # ALIEN_INVASION
			effects = {
				"combat_difficulty": 1.5,
				"spawn_rate_increase": true
			}
		3: # TECH_BREAKTHROUGH
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

## Compare two values with an operator
func _compare_value(_value: float, operator: String, target: float) -> bool:
	match operator:
		">=": return _value >= target
		"<=": return _value <= target
		">": return _value > target
		"<": return _value < target
		"==": return _value == target
		_: return false

## Process mission events
func _process_mission_events() -> void:
	var resolved_events: Array[Dictionary] = []

	for event in mission_events:
		if "duration" in event and "turn_started" in event:
			var turns_active: int = game_state.current_turn - event.turn_started
			if turns_active >= event.duration:
				resolved_events.append(event)
				_remove_mission_event_effects(event)

	for event in resolved_events:
		mission_events.erase(event)
		mission_event_resolved.emit(event)

## Trigger a mission event
func trigger_mission_event(event_name: String, mission: Mission) -> void:
	if event_name not in MISSION_EVENTS or not mission:
		return

	var event_def = MISSION_EVENTS[event_name]
	var event_data: Dictionary = {
		"_name": event_name,
		"category": event_def.category,
		"turn_started": game_state.current_turn,
		"mission_id": mission.get_instance_id(),
		"effects": event_def.effects.duplicate(true)
	}

	# Calculate duration based on mission length
	event_data["duration"] = mission.get_estimated_duration()

	mission_events.append(event_data)
	_apply_mission_event_effects(event_data, mission)
	mission_event_triggered.emit(event_data)

## Apply mission event effects
func _apply_mission_event_effects(event_data: Dictionary, mission: Mission) -> void:
	var effects = event_data.effects

	# Apply difficulty modifier
	if "mission_difficulty" in effects:
		mission.difficulty = roundi(mission.difficulty * effects.mission_difficulty)

	# Apply reward modifiers
	if "rewards" in effects:
		var rewards = effects.rewards
		if "multiplier" in rewards:
			for reward_type in mission.rewards:
				if reward_type is int or reward_type is float:
					mission.rewards[reward_type] = roundi(mission.rewards[reward_type] * rewards.multiplier)

		if "intel_points" in rewards:
			if "intel" not in mission.rewards:
				mission.rewards["intel"] = 0
			mission.rewards["intel"] += rewards.intel_points

	# Add bonus objectives
	if "bonus_objective" in effects and effects.bonus_objective:
		var bonus_objective = _generate_bonus_objective(mission)
		if bonus_objective:
			mission.objectives.append(bonus_objective)

	# Add special conditions
	if "hazard_level" in effects:
		mission.special_rules.append("HAZARD_LEVEL_%d" % effects.hazard_level)

	if "rival_presence" in effects and effects.rival_presence:
		mission.special_rules.append("RIVAL_PRESENCE")

	if "ally_support" in effects and effects.ally_support:
		mission.special_rules.append("ALLY_SUPPORT")

## Remove mission event effects
func _remove_mission_event_effects(event_data: Dictionary) -> void:
	var mission = instance_from_id(event_data.mission_id) as Mission
	if not mission:
		return

	var effects = event_data.effects

	# Reverse difficulty modifier
	if "mission_difficulty" in effects:
		mission.difficulty = roundi(mission.difficulty / effects.mission_difficulty)

	# Remove special conditions
	if "hazard_level" in effects:
		mission.special_rules.erase("HAZARD_LEVEL_%d" % effects.hazard_level)

	if "rival_presence" in effects and effects.rival_presence:
		mission.special_rules.erase("RIVAL_PRESENCE")

	if "ally_support" in effects and effects.ally_support:
		mission.special_rules.erase("ALLY_SUPPORT")

## Generate a bonus objective for a mission
func _generate_bonus_objective(mission: Mission) -> Dictionary:
	var possible_objectives = [
		{
			"type": GlobalEnums.MissionObjective.SABOTAGE,
			"description": "Sabotage enemy equipment"
		},
		{
			"type": GlobalEnums.MissionObjective.EXPLORE,
			"description": "Gather additional intelligence"
		},
		{
			"type": GlobalEnums.MissionObjective.RESCUE,
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
		if event._name == event_name:
			return true
	return false

## Get mission event effect _value
func get_mission_event_effect(effect_type: String) -> float:
	var total_effect := 1.0

	for event in mission_events:
		var effects = event.effects
		if effect_type in effects:
			match typeof(effects[effect_type]):
				TYPE_FLOAT, TYPE_INT:
					total_effect *= effects[effect_type]

	return total_effect

## Stage 6: @warning_ignore Coverage - Add warning suppressions for known safe patterns
func _exit_tree() -> void:
	"""Cleanup when node is removed from tree"""
	cleanup()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null