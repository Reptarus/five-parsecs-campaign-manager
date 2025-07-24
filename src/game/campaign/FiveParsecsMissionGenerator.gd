@tool
extends Node
class_name FiveParsecsMissionGenerator

## Five Parsecs Mission Generator
## Now uses BaseMissionGenerationSystem for unified mission generation logic
## Part of Phase 3A Mission Generation Consolidation

const BaseMissionGenerationSystem = preload("res://src/base/mission/BaseMissionGenerationSystem.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const Character = preload("res://src/core/character/Character.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const MissionObjective = preload("res://src/core/mission/MissionObjective.gd")

signal mission_generated(mission: Mission)
signal mission_validation_failed(reason: String)

# Mission generation system (handles all logic)
var generation_system: BaseMissionGenerationSystem = null

var mission_types: Array[String] = [
	"Patrol", "Salvage", "Trade", "Exploration", "Pursuit",
	"Defending", "Opportunity", "Raid", "Investigation", "Delivery"
]

var deployment_conditions: Array[String] = [
	"Standard", "Delayed", "Rushed", "Stealth", "Assault"
]

var special_rules: Array[String] = [
	"NIGHT_FIGHTING", "ENVIRONMENTAL_HAZARD", "TIME_LIMIT",
	"RIVAL_PRESENCE", "CIVILIAN_PRESENCE", "VALUABLE_CARGO"
]

func _init() -> void:
	name = "FiveParsecsMissionGenerator"
	# Initialize mission generation system
	generation_system = BaseMissionGenerationSystem.new()
	_connect_generation_system_signals()
	_setup_generation_system()

func _connect_generation_system_signals() -> void:
	"""Connect to generation system signals"""
	if generation_system:
		generation_system.mission_generated.connect(_on_system_mission_generated)
		generation_system.mission_validation_failed.connect(_on_system_mission_validation_failed)

func _setup_generation_system() -> void:
	"""Setup generation system in Five Parsecs mode"""
	if generation_system:
		generation_system.setup_mission_generator(BaseMissionGenerationSystem.GenerationMode.FIVE_PARSECS)

func generate_mission(difficulty: int = 1) -> Mission:
	"""Generate mission using the generation system"""
	if generation_system:
		generation_system.set_difficulty(difficulty)
		return generation_system.generate_mission()
	else:
		# Fallback to legacy generation
		return _generate_legacy_mission(difficulty)

func _generate_legacy_mission(difficulty: int = 1) -> Mission:
	"""Legacy mission generation for fallback"""
	var mission := Mission.new()

	# Set basic mission properties  
	mission.mission_type = GlobalEnums.MissionType.PATROL + (randi() % (GlobalEnums.MissionType.DEFENSE - GlobalEnums.MissionType.PATROL + 1))
	mission.mission_difficulty = clampi(difficulty, 1, 5)

	# Generate mission details using legacy methods
	_generate_mission_name(mission)
	_generate_objectives(mission)
	_generate_rewards(mission)

	mission_generated.emit(mission)
	return mission

## Generation system signal handlers
func _on_system_mission_generated(mission: Mission) -> void:
	"""Handle mission generated from generation system"""
	mission_generated.emit(mission)

func _on_system_mission_validation_failed(reason: String) -> void:
	"""Handle mission validation failure from generation system"""
	mission_validation_failed.emit(reason)

## Public API for enhanced mission generation
func enable_enhanced_mode() -> void:
	"""Enable enhanced mission generation mode"""
	if generation_system:
		generation_system.setup_mission_generator(BaseMissionGenerationSystem.GenerationMode.ENHANCED)

func get_generation_system() -> BaseMissionGenerationSystem:
	"""Get generation system for direct access"""
	return generation_system

func generate_mission_batch(count: int = 3, difficulty: int = 1) -> Array[Mission]:
	"""Generate multiple missions at once"""
	if generation_system:
		generation_system.set_difficulty(difficulty)
		return generation_system.generate_mission_batch(count)
	else:
		# Fallback to legacy generation
		var missions: Array[Mission] = []
		for i in range(count):
			missions.append(_generate_legacy_mission(difficulty))
		return missions

func set_campaign_context(campaign_turn: int, crew_experience: String = "regular") -> void:
	"""Set campaign context for mission generation"""
	if generation_system:
		generation_system.set_campaign_turn(campaign_turn)

## Legacy methods for compatibility
func _generate_mission_name(mission: Mission) -> void:
	var prefixes = ["Operation", "Mission", "Assignment", "Contract"]
	var suffixes = ["Alpha", "Beta", "Gamma", "Prime", "Storm", "Shadow"]

	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	mission.mission_title = prefix + " " + suffix

func _generate_objectives(mission: Mission) -> void:
	# Primary objective based on mission type
	var primary_objective := MissionObjective.new()

	match mission.mission_type:
		GlobalEnums.MissionType.PATROL:
			primary_objective.objective_type = GlobalEnums.MissionObjective.PATROL
			primary_objective.description = "Patrol the designated area and eliminate threats"
		GlobalEnums.MissionType.SABOTAGE:
			primary_objective.objective_type = GlobalEnums.MissionObjective.SABOTAGE
			primary_objective.description = "Sabotage the target facility"
		GlobalEnums.MissionType.ESCORT:
			primary_objective.objective_type = GlobalEnums.MissionObjective.DEFENSE
			primary_objective.description = "Escort convoy to destination"
		GlobalEnums.MissionType.RESCUE:
			primary_objective.objective_type = GlobalEnums.MissionObjective.RESCUE
			primary_objective.description = "Rescue the target and extract safely"
		_:
			primary_objective.objective_type = GlobalEnums.MissionObjective.ASSASSINATION
			primary_objective.description = "Complete the assigned objective"

	mission.objectives.append(primary_objective)

	# Add secondary objectives based on difficulty
	if mission.difficulty >= 3:
		_add_secondary_objective(mission)

func _add_secondary_objective(mission: Mission) -> void:
	var secondary_objective := MissionObjective.new()
	var secondary_types = [
		GlobalEnums.MissionObjective.SABOTAGE,
		GlobalEnums.MissionObjective.RESCUE,
		GlobalEnums.MissionObjective.EXPLORE
	]

	secondary_objective.objective_type = secondary_types[randi() % secondary_types.size()]
	secondary_objective.description = "Complete secondary objective for bonus rewards"
	secondary_objective.is_optional = true
	mission.objectives.append(secondary_objective)

func _generate_rewards(mission: Mission) -> void:
	# Base credit reward
	var base_credits = 100 * mission.difficulty
	var credit_variance = base_credits * 0.3
	var credits = base_credits + randi_range(-credit_variance, credit_variance)

	mission.rewards = {
		"credits": credits,
		"experience": 10 * mission.difficulty,
		"reputation": 1 + (mission.difficulty - 1) / 2
	}

	# Add special rewards for higher difficulty
	if mission.difficulty >= 4:
		mission.rewards["equipment_chance"] = 0.3
	if mission.difficulty >= 5:
		mission.rewards["rare_equipment_chance"] = 0.1

func _generate_enemy_forces(mission: Mission) -> void:
	# Generate enemy composition based on mission type and difficulty
	var enemy_count: int = 3 + mission.difficulty
	var enemy_types: Array[String] = [
		"Criminal Gang", "Pirates", "Corporate Security", "Alien Hunters",
		"Rival Crew", "Military Patrol", "Scavengers", "Cultists"
	]

	mission.enemy_forces = {
		"primary_enemy": enemy_types[randi() % enemy_types.size()],
		"enemy_count": enemy_count,
		"elite_units": max(0, mission.difficulty - 2),
		"special_equipment": mission.difficulty >= 3
	}

func _add_special_rules(mission: Mission) -> void:
	# Add special rules based on mission type and random chance
	if randf() < 0.3: # 30% chance for special rules
		var rule = special_rules[randi() % special_rules.size()]
		mission.special_rules.append(rule)

	# Mission type specific rules
	match mission.mission_type:
		"Salvage":
			if randf() < 0.5:
				mission.special_rules.append("ENVIRONMENTAL_HAZARD")
		"Trade":
			if randf() < 0.4:
				mission.special_rules.append("CIVILIAN_PRESENCE")
		"Exploration":
			if randf() < 0.6:
				mission.special_rules.append("TIME_LIMIT")

func get_mission_briefing(mission: Mission) -> String:
	var briefing = "Mission: %s\n" % mission.mission_name
	briefing += "Type: %s\n" % mission.mission_type
	briefing += "Difficulty: %d / 5.0\n\n" % mission.difficulty

	briefing += "Objectives:\n"
	for objective in mission.objectives:
		var optional_text: String = " (Optional)" if objective.is_optional else ""
		briefing += "- %s%s\n" % [objective.description, optional_text]

	briefing += "\nRewards:\n"
	for reward_type in mission.rewards:
		briefing += "- %s: %s\n" % [reward_type.capitalize(), str(mission.rewards[reward_type])]

	if not mission.special_rules.is_empty():
		briefing += "\nSpecial Rules:\n"
		for rule in mission.special_rules:
			briefing += "- %s\n" % rule.replace("_", " ").capitalize()

	return briefing

func validate_mission(mission: Mission) -> bool:
	if not mission:
		mission_validation_failed.emit("Mission is null")
		return false

	if mission.mission_name.is_empty():
		mission_validation_failed.emit("Mission name is empty")
		return false

	if mission.objectives.is_empty():
		mission_validation_failed.emit("Mission has no objectives")
		return false

	if mission.difficulty < 1 or mission.difficulty > 5:
		mission_validation_failed.emit("Invalid difficulty level")
		return false

	return true

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null