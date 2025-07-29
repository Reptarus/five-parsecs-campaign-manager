@tool
class_name DeliveryMission
extends Mission

## Delivery Mission Implementation for Five Parsecs Campaign Manager
##
## Implements Five Parsecs delivery contract mechanics with cargo protection,
## time pressure, and route-based complications.

# GlobalEnums is inherited from Mission parent class
const MissionTypeRegistry = preload("res://src/game/missions/enhanced/MissionTypeRegistry.gd")
const MissionDifficultyScaler = preload("res://src/game/missions/enhanced/MissionDifficultyScaler.gd")

# Delivery-specific data
@export var cargo_type: String = ""
@export var cargo_value: int = 0
@export var delivery_distance: int = 1 # In parsecs
@export var time_limit: int = 3 # In campaign turns
@export var fragile_cargo: bool = false
@export var dangerous_cargo: bool = false
@export var requires_special_handling: bool = false

# Route and complication tracking
var route_complications: Array[Dictionary] = []
var cargo_condition: String = "intact" # intact, damaged, lost
var delivery_progress: int = 0

# Mission properties not in base class
var objectives: Array[Dictionary] = []
var minimum_crew_size: int = 2
var required_skills: Array[String] = []

# Signals for delivery-specific events
signal cargo_damaged(damage_type: String, severity: int)
signal route_complication_encountered(complication: Dictionary)
signal delivery_progress_updated(current_progress: int, total_distance: int)

func _init() -> void:
	super._init()
	mission_type = MissionTypeRegistry.EnhancedMissionType.DELIVERY
	_setup_delivery_mission()

## Initialize delivery mission with specific parameters
func initialize_delivery(delivery_data: Dictionary) -> void:
	# Set basic mission data from dictionary
	mission_id = delivery_data.get("mission_id", "")
	mission_title = delivery_data.get("mission_title", "Delivery Contract")
	mission_description = delivery_data.get("mission_description", "Transport cargo safely to destination")
	mission_difficulty = delivery_data.get("mission_difficulty", 1)
	reward_credits = delivery_data.get("reward_credits", 200)
	turn_offered = delivery_data.get("turn_offered", 0)
	
	# Set delivery-specific data
	cargo_type = delivery_data.get("cargo_type", "Standard Goods")
	cargo_value = delivery_data.get("cargo_value", 1000)
	delivery_distance = delivery_data.get("delivery_distance", 1)
	time_limit = delivery_data.get("time_limit", 3)
	fragile_cargo = delivery_data.get("fragile_cargo", false)
	dangerous_cargo = delivery_data.get("dangerous_cargo", false)
	requires_special_handling = delivery_data.get("requires_special_handling", false)
	
	# Generate route complications
	_generate_route_complications()
	
	# Set up objectives
	_setup_delivery_objectives()
	
	# Calculate enhanced rewards
	_calculate_delivery_rewards()

## Process delivery turn - called each campaign turn
func process_delivery_turn(turn_context: Dictionary) -> Dictionary:
	var turn_result: Dictionary = {
		"complications": [],
		"progress_made": 0,
		"cargo_status": cargo_condition,
		"mission_status": "ongoing"
	}
	
	# Check for route complications
	var complications: Array = _check_route_complications(turn_context)
	turn_result.complications = complications
	
	# Update delivery progress
	var progress: int = _calculate_turn_progress(turn_context)
	delivery_progress += progress
	turn_result.progress_made = progress
	
	# Check delivery completion
	if delivery_progress >= delivery_distance:
		_complete_delivery()
		turn_result.mission_status = "delivered"
	
	# Check time limit
	var current_turn: int = turn_context.get("current_turn", 0)
	var start_turn: int = turn_offered
	if current_turn - start_turn >= time_limit:
		_fail_delivery_time_limit()
		turn_result.mission_status = "failed_time"
	
	# Emit progress signal
	delivery_progress_updated.emit(delivery_progress, delivery_distance)
	
	return turn_result

## Get delivery status information
func get_delivery_status() -> Dictionary:
	return {
		"cargo_type": cargo_type,
		"cargo_value": cargo_value,
		"cargo_condition": cargo_condition,
		"delivery_progress": delivery_progress,
		"total_distance": delivery_distance,
		"time_remaining": maxi(time_limit - (Time.get_unix_time_from_system() - turn_offered), 0),
		"complications_remaining": route_complications.size(),
		"is_fragile": fragile_cargo,
		"is_dangerous": dangerous_cargo,
		"special_handling": requires_special_handling
	}

## Handle cargo damage from combat or complications
func damage_cargo(damage_source: String, severity: int) -> void:
	if cargo_condition == "lost":
		return # Already lost
	
	# Fragile cargo takes more damage
	if fragile_cargo:
		severity += 1
	
	match severity:
		1:
			if cargo_condition == "intact":
				cargo_condition = "minor_damage"
		2:
			cargo_condition = "major_damage"
		3, 4, 5:
			cargo_condition = "lost"
			_fail_delivery_cargo_lost()
	
	cargo_damaged.emit(damage_source, severity)

## Get mission-specific combat modifiers
func get_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Cargo protection requirements
	if fragile_cargo:
		modifiers["avoid_explosives"] = true
		modifiers["movement_penalty"] = 1 # Careful movement
	
	if dangerous_cargo:
		modifiers["explosion_risk"] = true
		modifiers["special_equipment_required"] = ["hazmat_gear"]
	
	# Delivery urgency affects tactics
	var urgency: float = float(delivery_progress) / float(delivery_distance)
	if urgency > 0.8:
		modifiers["time_pressure"] = true
		modifiers["aggressive_tactics_bonus"] = 1
	
	return modifiers

## Calculate delivery-specific enemy deployment
func get_enemy_deployment_context() -> Dictionary:
	var context: Dictionary = {}
	
	# High-value cargo attracts more attention
	if cargo_value > 5000:
		context["threat_multiplier"] = 1.3
		context["pirate_interest"] = true
	
	# Dangerous cargo may attract specific enemies
	if dangerous_cargo:
		context["corporate_interest"] = true
		context["enforcement_attention"] = true
	
	# Route-based enemy types
	context["route_based_enemies"] = _get_route_enemy_types()
	
	return context

## Private Methods

func _setup_delivery_mission() -> void:
	mission_title = "Delivery Contract"
	mission_description = "Transport cargo safely to the destination within the time limit"
	minimum_crew_size = 2 # Need pilot + escort minimum
	required_skills = ["pilot"] # Essential for delivery missions

func _generate_route_complications() -> void:
	route_complications.clear()
	
	# Number of complications based on distance and difficulty
	var complication_count: int = delivery_distance + (mission_difficulty - 1)
	complication_count = clampi(complication_count, 1, 5)
	
	var possible_complications: Array[Dictionary] = [
		{
			"type": "pirate_patrol",
			"description": "Pirate patrol spotted along the route",
			"combat_encounter": true,
			"difficulty_modifier": 1
		},
		{
			"type": "customs_inspection",
			"description": "Customs checkpoint requires inspection",
			"skill_challenge": "tech",
			"failure_consequence": "delay"
		},
		{
			"type": "mechanical_failure",
			"description": "Ship systems malfunction during transit",
			"skill_challenge": "tech",
			"failure_consequence": "damage"
		},
		{
			"type": "rival_interference",
			"description": "Rival crew attempts to intercept delivery",
			"combat_encounter": true,
			"difficulty_modifier": 2
		},
		{
			"type": "client_betrayal",
			"description": "Client has set up an ambush at the destination",
			"combat_encounter": true,
			"difficulty_modifier": 3,
			"story_consequence": true
		}
	]
	
	# Add complications specific to cargo type
	if dangerous_cargo:
		possible_complications.append({
			"type": "hazmat_leak",
			"description": "Dangerous cargo containment breach",
			"environmental_hazard": true,
			"cargo_damage_risk": 2
		})
	
	if fragile_cargo:
		possible_complications.append({
			"type": "rough_transit",
			"description": "Turbulent space conditions threaten fragile cargo",
			"skill_challenge": "pilot",
			"cargo_damage_risk": 1
		})
	
	# Randomly select complications
	for i in range(complication_count):
		if not possible_complications.is_empty():
			var complication: Dictionary = possible_complications[randi() % possible_complications.size()]
			route_complications.append(complication)
			possible_complications.erase(complication) # No duplicates

func _setup_delivery_objectives() -> void:
	objectives.clear()
	
	# Primary objective: Deliver cargo
	objectives.append({
		"description": "Deliver %s to destination" % cargo_type,
		"type": "deliver_cargo",
		"is_primary": true,
		"completed": false,
		"progress": 0,
		"target": delivery_distance
	})
	
	# Secondary objective: Maintain cargo condition
	if fragile_cargo or dangerous_cargo:
		objectives.append({
			"description": "Maintain cargo integrity",
			"type": "preserve_cargo",
			"is_primary": false,
			"completed": false,
			"condition_required": "intact"
		})
	
	# Time objective
	objectives.append({
		"description": "Complete delivery within %d turns" % time_limit,
		"type": "time_limit",
		"is_primary": true,
		"completed": false,
		"turns_remaining": time_limit
	})

func _calculate_delivery_rewards() -> void:
	# Base reward calculation
	var base_credits: int = 200 + (cargo_value * 0.1)
	
	# Distance multiplier
	base_credits += delivery_distance * 50
	
	# Special handling bonuses
	if fragile_cargo:
		base_credits = roundi(base_credits * 1.2)
	if dangerous_cargo:
		base_credits = roundi(base_credits * 1.3)
	if requires_special_handling:
		base_credits = roundi(base_credits * 1.1)
	
	# Time pressure bonus
	if time_limit <= 2:
		base_credits = roundi(base_credits * 1.25)
	
	reward_credits = base_credits
	
	# Advanced rules for bonus calculations
	advanced_rules["cargo_condition_bonus"] = {
		"intact": 1.0,
		"minor_damage": 0.9,
		"major_damage": 0.7,
		"lost": 0.0
	}
	
	advanced_rules["time_bonus"] = {
		"early": 1.2,
		"on_time": 1.0,
		"late": 0.8
	}

func _check_route_complications(turn_context: Dictionary) -> Array:
	var encountered_complications: Array = []
	
	# Check if any complications trigger this turn
	for complication in route_complications:
		var trigger_chance: float = 0.3 # Base 30% chance per turn
		
		# Modify chance based on context
		if turn_context.has("stealth_approach") and turn_context.stealth_approach:
			trigger_chance *= 0.5
		
		if turn_context.has("rushed_movement") and turn_context.rushed_movement:
			trigger_chance *= 1.5
		
		if randf() < trigger_chance:
			encountered_complications.append(complication)
			route_complications.erase(complication)
			route_complication_encountered.emit(complication)
	
	return encountered_complications

func _calculate_turn_progress(turn_context: Dictionary) -> int:
	var base_progress: int = 1 # Standard 1 parsec per turn
	
	# Modify based on ship capabilities
	if turn_context.has("ship_speed_bonus"):
		base_progress += turn_context.ship_speed_bonus
	
	# Cargo may slow progress
	if fragile_cargo and not turn_context.get("careful_handling", false):
		base_progress = maxi(base_progress - 1, 0)
	
	return base_progress

func _complete_delivery() -> void:
	# Check cargo condition for final rewards
	var condition_multiplier: float = advanced_rules.cargo_condition_bonus.get(cargo_condition, 1.0)
	reward_credits = roundi(reward_credits * condition_multiplier)
	
	complete(true)

func _fail_delivery_time_limit() -> void:
	fail(true)
	advanced_rules["failure_reason"] = "time_limit_exceeded"

func _fail_delivery_cargo_lost() -> void:
	fail(true)
	advanced_rules["failure_reason"] = "cargo_lost"

func _get_route_enemy_types() -> Array[String]:
	var enemy_types: Array[String] = ["Pirates"] # Default threat
	
	# High-value cargo attracts organized crime
	if cargo_value > 5000:
		enemy_types.append("CorporateSecurity")
		enemy_types.append("Mercenaries")
	
	# Dangerous cargo attracts law enforcement
	if dangerous_cargo:
		enemy_types.append("Enforcers")
	
	return enemy_types