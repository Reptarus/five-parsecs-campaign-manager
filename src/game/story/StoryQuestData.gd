@tool
extends Resource

signal reward_calculated(rewards: Dictionary)
signal validation_failed(errors: Array[String])

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")

# Basic Mission Info
@export var mission_id: String
@export var mission_type: int = GameEnums.MissionType.NONE
@export var name: String
@export var description: String
@export var turn_limit: int = -1
@export var required_reputation: int = 0
@export var risk_level: int = 1
@export var event_type: int = 0

# Mission Parameters
@export var enemy_count: int
@export var enemy_types: Array[int]
@export var enemy_level: int
@export var has_boss: bool
@export var boss_type: int = GameEnums.EnemyType.NONE

# Mission Objectives
@export var objectives: Array[Dictionary]
@export var primary_objective: int = GameEnums.MissionObjective.NONE
@export var secondary_objectives: Array[int]

# Mission Rewards
@export var reward_credits: int = 0
@export var reward_reputation: int = 0
@export var reward_items: Array = []
var reward_modifiers: Dictionary = {}

# Mission State
@export var is_active: bool
@export var is_completed: bool
@export var is_failed: bool
@export var current_turn: int
@export var completion_percentage: float

# Mission Requirements
@export var required_crew_size: int
@export var required_equipment: Array[String]
@export var required_resources: Dictionary

# Mission Location
@export var location_type: int = GameEnums.LocationType.NONE
@export var terrain_type: int = GameEnums.PlanetEnvironment.NONE
@export var deployment_type: int = GameEnums.DeploymentType.STANDARD

var game_state: FiveParsecsGameState

# Base reward values
const BASE_CREDIT_REWARD = 100
const BASE_REPUTATION_REWARD = 5
const RISK_LEVEL_MULTIPLIER = 1.5
const OBJECTIVE_COMPLETION_BONUS = 0.2

# Custom Mission Support
var is_custom_mission: bool = false
var custom_mission_data: Dictionary = {}
var custom_validation_rules: Array[Dictionary] = []
var custom_reward_rules: Array[Dictionary] = []

# Quest specific properties
@export var quest_type: int = 0
@export var story_point_reward: int = 0
@export var objective: int = 0
@export var patron: Resource = null
@export var patron_faction: int = 0

func _init() -> void:
	mission_id = str(randi())
	objectives = []
	enemy_types = []
	secondary_objectives = []
	reward_items = []
	required_equipment = []
	required_resources = {}
	is_active = false
	is_completed = false
	is_failed = false
	current_turn = 0
	completion_percentage = 0.0

func configure(p_mission_type: int, p_config: Dictionary = {}) -> void:
	mission_type = p_mission_type
	
	# Apply configuration
	for key in p_config:
		if key in self:
			self[key] = p_config[key]
	
	# Initialize based on mission type
	match mission_type:
		GameEnums.MissionType.PATROL:
			name = "Patrol Mission"
			description = "Patrol and secure the designated area."
			enemy_count = 3
			enemy_level = 1
			has_boss = false
			required_crew_size = 2
			reward_credits = 1000
			reward_reputation = 5
			primary_objective = GameEnums.MissionObjective.PATROL
			
		GameEnums.MissionType.RESCUE:
			name = "Rescue Mission"
			description = "Locate and rescue the target."
			enemy_count = 4
			enemy_level = 2
			has_boss = true
			required_crew_size = 3
			reward_credits = 2000
			reward_reputation = 10
			primary_objective = GameEnums.MissionObjective.RESCUE
			
		GameEnums.MissionType.SABOTAGE:
			name = "Sabotage Mission"
			description = "Eliminate all hostile forces."
			enemy_count = 6
			enemy_level = 3
			has_boss = true
			required_crew_size = 4
			reward_credits = 3000
			reward_reputation = 15
			primary_objective = GameEnums.MissionObjective.SABOTAGE
			
		_:
			push_warning("Unknown mission type: %d" % mission_type)

func configure_custom_mission(config: Dictionary) -> void:
	is_custom_mission = true
	custom_mission_data = config.get("mission_data", {})
	
	# Configure custom validation rules
	custom_validation_rules = config.get("validation_rules", [])
	
	# Configure custom reward rules
	custom_reward_rules = config.get("reward_rules", [])
	
	# Set basic mission properties
	mission_type = config.get("mission_type", GameEnums.MissionType.NONE)
	name = config.get("name", "Custom Mission")
	description = config.get("description", "")
	
	# Set objectives
	primary_objective = config.get("primary_objective", GameEnums.MissionObjective.NONE)
	secondary_objectives = config.get("secondary_objectives", [])
	
	# Set requirements
	required_crew_size = config.get("required_crew_size", 1)
	required_equipment = config.get("required_equipment", [])
	required_resources = config.get("required_resources", {})
	
	# Set base rewards
	reward_credits = config.get("base_credits", BASE_CREDIT_REWARD)
	reward_reputation = config.get("base_reputation", BASE_REPUTATION_REWARD)
	reward_items = config.get("reward_items", [])

func apply_custom_validation_rules() -> Array[String]:
	var custom_errors: Array[String] = []
	
	for rule in custom_validation_rules:
		var condition = rule.get("condition", "")
		var error_message = rule.get("error_message", "Custom validation failed")
		
		match condition:
			"min_crew_level":
				var min_level = rule.get("value", 1)
				if not _validate_crew_level(min_level):
					custom_errors.append(error_message)
			"required_faction_standing":
				var faction = rule.get("faction", "")
				var min_standing = rule.get("value", 0)
				if not _validate_faction_standing(faction, min_standing):
					custom_errors.append(error_message)
			"special_equipment":
				var equipment = rule.get("equipment", [])
				if not _validate_special_equipment(equipment):
					custom_errors.append(error_message)
	
	return custom_errors

func apply_custom_reward_rules() -> Dictionary:
	var modified_rewards := {}
	
	for rule in custom_reward_rules:
		var condition = rule.get("condition", "")
		var modifier = rule.get("modifier", 1.0)
		
		match condition:
			"crew_size_bonus":
				if game_state.get_crew_size() >= rule.get("min_crew_size", 1):
					modified_rewards["credits"] = reward_credits * modifier
			"reputation_threshold":
				if game_state.reputation >= rule.get("threshold", 0):
					modified_rewards["reputation"] = reward_reputation * modifier
			"special_item_chance":
				if randf() <= rule.get("chance", 0.0):
					modified_rewards["items"] = rule.get("items", [])
	
	return modified_rewards

func _validate_crew_level(min_level: int) -> bool:
	return game_state.get_average_crew_level() >= min_level

func _validate_faction_standing(faction: String, min_standing: int) -> bool:
	return game_state.get_faction_standing(faction) >= min_standing

func _validate_special_equipment(required_equipment: Array) -> bool:
	for equipment in required_equipment:
		if not game_state.has_equipment(equipment):
			return false
	return true

func validate() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate basic properties
	if mission_id.is_empty():
		errors.append("Mission ID is required")
	
	if name.is_empty():
		errors.append("Mission name is required")
	
	if description.is_empty():
		warnings.append("Mission description is empty")
	
	# Validate mission type
	if mission_type == GameEnums.MissionType.NONE:
		errors.append("Invalid mission type")
	
	# Validate objectives
	if primary_objective == GameEnums.MissionObjective.NONE:
		errors.append("Primary objective is required")
	
	var has_primary = false
	for objective in objectives:
		if objective.type == primary_objective:
			has_primary = true
			break
	
	if not has_primary:
		errors.append("Primary objective not found in objectives list")
	
	# Validate requirements
	if required_crew_size < 1:
		errors.append("Required crew size must be at least 1")
	
	if required_crew_size > 6:
		errors.append("Required crew size cannot exceed 6")
	
	# Validate rewards
	if reward_credits < 0:
		errors.append("Reward credits cannot be negative")
	
	if reward_reputation < 0:
		errors.append("Reward reputation cannot be negative")
	
	# Validate state consistency
	if is_completed and is_failed:
		errors.append("Mission cannot be both completed and failed")
	
	if is_active and (is_completed or is_failed):
		errors.append("Active mission cannot be completed or failed")
	
	# Handle custom mission validation if applicable
	if is_custom_mission:
		var custom_errors = apply_custom_validation_rules()
		errors.append_array(custom_errors)
	
	# Emit validation failed signal if there are errors
	if not errors.is_empty():
		validation_failed.emit(errors)
	
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}

func calculate_rewards() -> Dictionary:
	var total_credits := BASE_CREDIT_REWARD
	var total_reputation := BASE_REPUTATION_REWARD
	var bonus_items := []
	
	# Apply risk level modifier
	var risk_multiplier = pow(RISK_LEVEL_MULTIPLIER, risk_level)
	total_credits = roundi(total_credits * risk_multiplier)
	total_reputation = roundi(total_reputation * risk_multiplier)
	
	# Add completion bonuses
	var completion_bonus = completion_percentage * OBJECTIVE_COMPLETION_BONUS
	total_credits = roundi(total_credits * (1 + completion_bonus))
	total_reputation = roundi(total_reputation * (1 + completion_bonus))
	
	# Apply mission type modifiers
	match mission_type:
		GameEnums.MissionType.PATRON:
			total_credits *= 2
			total_reputation *= 1.5
		GameEnums.MissionType.RESCUE:
			total_reputation *= 2
		GameEnums.MissionType.SABOTAGE:
			total_credits *= 1.5
	
	# Apply any custom modifiers
	for modifier_type in reward_modifiers:
		match modifier_type:
			"credits":
				total_credits = roundi(total_credits * reward_modifiers[modifier_type])
			"reputation":
				total_reputation = roundi(total_reputation * reward_modifiers[modifier_type])
	
	# Handle custom mission rewards if applicable
	if is_custom_mission:
		var custom_rewards = apply_custom_reward_rules()
		for reward_type in custom_rewards:
			match reward_type:
				"credits":
					total_credits = custom_rewards[reward_type]
				"reputation":
					total_reputation = custom_rewards[reward_type]
				"items":
					bonus_items.append_array(custom_rewards[reward_type])
	
	var rewards := {
		"credits": total_credits,
		"reputation": total_reputation,
		"items": bonus_items
	}
	
	reward_calculated.emit(rewards)
	return rewards

static func create_mission(p_mission_type: int, p_config: Dictionary = {}) -> StoryQuestData:
	var mission := StoryQuestData.new()
	mission.configure(p_mission_type, p_config)
	return mission

func add_objective(objective_type: int, description: String = "", required: bool = true) -> void:
	var objective := {
		"type": objective_type,
		"description": description,
		"required": required,
		"completed": false,
		"progress": 0,
		"target": 1
	}
	
	objectives.append(objective)
	
	if required:
		secondary_objectives.append(objective_type)

func complete_objective(objective_type: int) -> void:
	for objective in objectives:
		if objective.type == objective_type:
			objective.completed = true
			objective.progress = objective.target
			_update_completion_percentage()
			break

func update_objective_progress(objective_type: int, progress: int) -> void:
	for objective in objectives:
		if objective.type == objective_type:
			objective.progress = mini(progress, objective.target)
			if objective.progress >= objective.target:
				objective.completed = true
			_update_completion_percentage()
			break

func _update_completion_percentage() -> void:
	var total_objectives := objectives.size()
	if total_objectives == 0:
		completion_percentage = 0.0
		return
		
	var completed_objectives := 0
	for objective in objectives:
		if objective.completed:
			completed_objectives += 1
	
	completion_percentage = float(completed_objectives) / float(total_objectives) * 100.0

func add_enemy_type(enemy_type: int) -> void:
	if not enemy_type in enemy_types:
		enemy_types.append(enemy_type)

func add_reward_item(item: Dictionary) -> void:
	reward_items.append(item)

func add_required_equipment(equipment: Dictionary) -> void:
	required_equipment.append(equipment)

func set_required_resource(resource_type: int, amount: int) -> void:
	required_resources[resource_type] = amount

func is_requirement_met(game_state: FiveParsecsGameState) -> bool:
	# Check reputation requirement
	if game_state.reputation < required_reputation:
		return false
		
	# Check crew size
	if game_state.crew_members.size() < required_crew_size:
					return false
	
	# Check resources
	for resource_type in required_resources:
		var required = required_resources[resource_type]
		if game_state.get_resource(resource_type) < required:
					return false
	
	# Check equipment
	for equipment in required_equipment:
		if not game_state.has_equipment(equipment):
					return false
	
	return true

func _generate_mission_id() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000]

func serialize() -> Dictionary:
	return {
		"mission_id": mission_id,
		"mission_type": mission_type,
		"name": name,
		"description": description,
		"turn_limit": turn_limit,
		"required_reputation": required_reputation,
		"risk_level": risk_level,
		"enemy_count": enemy_count,
		"enemy_types": enemy_types,
		"enemy_level": enemy_level,
		"has_boss": has_boss,
		"boss_type": boss_type,
		"objectives": objectives,
		"primary_objective": primary_objective,
		"secondary_objectives": secondary_objectives,
		"reward_credits": reward_credits,
		"reward_reputation": reward_reputation,
		"reward_items": reward_items,
		"reward_modifiers": reward_modifiers,
		"is_active": is_active,
		"is_completed": is_completed,
		"is_failed": is_failed,
		"current_turn": current_turn,
		"completion_percentage": completion_percentage,
		"required_crew_size": required_crew_size,
		"required_equipment": required_equipment,
		"required_resources": required_resources,
		"location_type": location_type,
		"terrain_type": terrain_type,
		"deployment_type": deployment_type
	}

func deserialize(data: Dictionary) -> void:
	mission_id = data.get("mission_id", _generate_mission_id())
	mission_type = data.get("mission_type", GameEnums.MissionType.NONE)
	name = data.get("name", "")
	description = data.get("description", "")
	turn_limit = data.get("turn_limit", -1)
	required_reputation = data.get("required_reputation", 0)
	risk_level = data.get("risk_level", 1)
	enemy_count = data.get("enemy_count", 0)
	enemy_types = data.get("enemy_types", [])
	enemy_level = data.get("enemy_level", 1)
	has_boss = data.get("has_boss", false)
	boss_type = data.get("boss_type", GameEnums.EnemyType.NONE)
	objectives = data.get("objectives", [])
	primary_objective = data.get("primary_objective", GameEnums.MissionObjective.NONE)
	secondary_objectives = data.get("secondary_objectives", [])
	reward_credits = data.get("reward_credits", 0)
	reward_reputation = data.get("reward_reputation", 0)
	reward_items = data.get("reward_items", [])
	reward_modifiers = data.get("reward_modifiers", {})
	is_active = data.get("is_active", false)
	is_completed = data.get("is_completed", false)
	is_failed = data.get("is_failed", false)
	current_turn = data.get("current_turn", 0)
	completion_percentage = data.get("completion_percentage", 0.0)
	required_crew_size = data.get("required_crew_size", 0)
	required_equipment = data.get("required_equipment", [])
	required_resources = data.get("required_resources", {})
	location_type = data.get("location_type", GameEnums.LocationType.NONE)
	terrain_type = data.get("terrain_type", GameEnums.PlanetEnvironment.NONE)
	deployment_type = data.get("deployment_type", GameEnums.DeploymentType.STANDARD)

func validate_requirements(game_state: FiveParsecsGameState) -> Dictionary:
	var validation_result := {
		"can_start": true,
		"missing_requirements": []
	}
	
	# Check reputation
	if game_state.reputation < required_reputation:
		validation_result.missing_requirements.append({
			"type": "reputation",
			"required": required_reputation,
			"current": game_state.reputation
		})
	
	# Check crew size
	if game_state.crew_members.size() < required_crew_size:
		validation_result.missing_requirements.append({
			"type": "crew_size",
			"required": required_crew_size,
			"current": game_state.crew_members.size()
		})
	
	# Check resources
	for resource_type in required_resources:
		var required = required_resources[resource_type]
		var current = game_state.get_resource(resource_type)
		if current < required:
			validation_result.missing_requirements.append({
				"type": "resource",
				"resource_type": resource_type,
				"required": required,
				"current": current
			})
	
	# Check equipment
	for equipment in required_equipment:
		if not game_state.has_equipment(equipment):
			validation_result.missing_requirements.append({
				"type": "equipment",
				"equipment": equipment
			})
	
	# Update validation status
	validation_result.can_start = validation_result.missing_requirements.is_empty()
	return validation_result

func validate_completion() -> Dictionary:
	var validation_result := {
		"is_complete": false,
		"failed_objectives": [],
		"completion_status": {}
	}
	
	# Check primary objective
	var primary_complete := false
	for objective in objectives:
		if objective.type == primary_objective:
			primary_complete = objective.completed
			validation_result.completion_status["primary"] = {
				"completed": objective.completed,
				"progress": objective.progress,
				"target": objective.target
			}
	
	# Check secondary objectives
	var secondary_complete := true
	var secondary_status := []
	for objective in objectives:
		if objective.type in secondary_objectives:
			if not objective.completed and objective.required:
				secondary_complete = false
				validation_result.failed_objectives.append(objective.type)
			secondary_status.append({
				"type": objective.type,
				"completed": objective.completed,
				"required": objective.required,
				"progress": objective.progress,
				"target": objective.target
			})
	
	validation_result.completion_status["secondary"] = secondary_status
	
	# Check turn limit
	if turn_limit > 0:
		validation_result.completion_status["turns"] = {
			"current": current_turn,
			"limit": turn_limit,
			"within_limit": current_turn <= turn_limit
		}
		if current_turn > turn_limit:
			validation_result.failed_objectives.append("turn_limit")
	
	# Update completion status
	validation_result.is_complete = primary_complete and secondary_complete and \
								  (turn_limit <= 0 or current_turn <= turn_limit)
	
	return validation_result

func can_complete() -> bool:
	var completion_check = validate_completion()
	return completion_check.is_complete

func can_start(game_state: FiveParsecsGameState) -> bool:
	var validation = validate()
	if not validation.is_valid:
			return false
			
	var requirement_check = validate_requirements(game_state)
	return requirement_check.can_start

func add_reward_modifier(modifier_type: String, value: float) -> void:
	reward_modifiers[modifier_type] = value

func get_reward_modifier(modifier_type: String) -> float:
	return reward_modifiers.get(modifier_type, 1.0)