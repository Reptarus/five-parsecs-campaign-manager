@tool
class_name RaidMission
extends Mission

## Raid Mission Implementation for Five Parsecs Campaign Manager
##
## Implements Five Parsecs raid mechanics with target assessment, loot focus,
## and aggressive tactical requirements.

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const MissionTypeRegistry = preload("res://src/game/missions/enhanced/MissionTypeRegistry.gd")

# Raid target parameters
@export var target_type: String = "outpost"  # outpost, warehouse, convoy, settlement, facility
@export var target_value: int = 2000  # Estimated loot value
@export var target_defenses: int = 3  # Defense strength 1-5
@export var target_size: String = "medium"  # small, medium, large, massive
@export var loot_quality: String = "mixed"  # poor, mixed, good, excellent, legendary

# Raid objectives and loot
@export var primary_loot_types: Array[String] = []
@export var secondary_loot_types: Array[String] = []
@export var destruction_bonus: bool = false  # Extra reward for destroying target
@export var time_pressure: bool = false  # Response forces incoming

# Raid state tracking
var loot_secured: Dictionary = {}
var target_destruction_level: int = 0  # 0-100%
var civilian_casualties: int = 0
var alarm_raised: bool = false
var response_force_eta: int = 0  # Turns until reinforcements
var crew_reputation_change: int = 0

# Combat and tactical state
var assault_phase: String = "approach"  # approach, breach, combat, extraction
var defensive_positions_cleared: int = 0
var total_defensive_positions: int = 3
var extraction_routes_available: int = 2

# Signals for raid events
signal loot_discovered(loot_data: Dictionary)
signal target_alarm_triggered(response_time: int)
signal assault_phase_changed(new_phase: String)
signal defensive_position_cleared(position_id: int)

func _init() -> void:
	super._init()
	mission_type = MissionTypeRegistry.EnhancedMissionType.RAID
	_setup_raid_mission()

## Initialize raid mission with target data
func initialize_raid(raid_data: Dictionary) -> void:
	initialize(raid_data)
	
	# Set target-specific data
	target_type = raid_data.get("target_type", "outpost")
	target_value = raid_data.get("target_value", 2000)
	target_defenses = raid_data.get("target_defenses", 3)
	target_size = raid_data.get("target_size", "medium")
	loot_quality = raid_data.get("loot_quality", "mixed")
	destruction_bonus = raid_data.get("destruction_bonus", false)
	time_pressure = raid_data.get("time_pressure", false)
	
	# Generate raid parameters
	_generate_raid_parameters()
	
	# Set up objectives
	_setup_raid_objectives()
	
	# Calculate raid rewards
	_calculate_raid_rewards()

## Process raid phase progression
func process_raid_phase(phase_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"phase_success": false,
		"loot_found": [],
		"casualties": 0,
		"complications": [],
		"next_phase": assault_phase
	}
	
	var crew_combat_strength: int = phase_data.get("crew_combat", 5)
	var tactical_approach: String = phase_data.get("approach", "direct")
	var equipment_quality: int = phase_data.get("equipment", 2)
	
	match assault_phase:
		"approach":
			result = _process_approach_phase(phase_data)
		"breach":
			result = _process_breach_phase(phase_data)
		"combat":
			result = _process_combat_phase(phase_data)
		"extraction":
			result = _process_extraction_phase(phase_data)
	
	# Update phase if successful
	if result.phase_success:
		_advance_assault_phase()
		result.next_phase = assault_phase
	
	return result

## Process loot acquisition during raid
func acquire_loot(loot_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"loot_acquired": {},
		"loot_value": 0,
		"carrying_capacity_exceeded": false,
		"time_cost": 1
	}
	
	var loot_type: String = loot_data.get("type", "general")
	var loot_amount: int = loot_data.get("amount", 1)
	var crew_carrying_capacity: int = loot_data.get("crew_capacity", 10)
	
	# Generate specific loot item
	var loot_item: Dictionary = _generate_loot_item(loot_type, loot_amount)
	
	# Check carrying capacity
	var current_load: int = _calculate_current_loot_load()
	if current_load + loot_item.weight <= crew_carrying_capacity:
		loot_secured[loot_item.id] = loot_item
		result.loot_acquired = loot_item
		result.loot_value = loot_item.value
		
		loot_discovered.emit(loot_item)
	else:
		result.carrying_capacity_exceeded = true
		result.time_cost = 2  # Extra time to manage overload
	
	return result

## Get raid status information
func get_raid_status() -> Dictionary:
	return {
		"target_type": target_type,
		"target_value": target_value,
		"target_defenses": target_defenses,
		"target_size": target_size,
		"assault_phase": assault_phase,
		"loot_secured": loot_secured.size(),
		"total_loot_value": _calculate_total_loot_value(),
		"target_destruction": target_destruction_level,
		"alarm_status": alarm_raised,
		"response_eta": response_force_eta,
		"defensive_positions_remaining": total_defensive_positions - defensive_positions_cleared,
		"extraction_routes": extraction_routes_available,
		"civilian_casualties": civilian_casualties
	}

## Get mission-specific combat modifiers for raid encounters
func get_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Raid focuses on aggressive tactics
	modifiers["aggressive_tactics_bonus"] = 2
	modifiers["loot_priority"] = true
	modifiers["rapid_assault"] = true
	
	# Assault phase affects tactics
	match assault_phase:
		"approach":
			modifiers["stealth_possible"] = true
			modifiers["surprise_bonus"] = 1
		"breach":
			modifiers["breaching_equipment_bonus"] = 2
			modifiers["coordinated_assault"] = true
		"combat":
			modifiers["overwhelming_force"] = true
			modifiers["area_denial"] = true
		"extraction":
			modifiers["fighting_withdrawal"] = true
			modifiers["cargo_protection"] = true
	
	# Time pressure affects urgency
	if time_pressure and response_force_eta <= 2:
		modifiers["extreme_urgency"] = true
		modifiers["reckless_tactics_acceptable"] = true
	
	# Alarm status affects enemy preparation
	if alarm_raised:
		modifiers["enemy_prepared"] = true
		modifiers["reinforcement_risk"] = 0.3
	
	return modifiers

## Get enemy deployment context for raid encounters
func get_enemy_deployment_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Target type affects enemy composition
	match target_type:
		"outpost":
			context["military_garrison"] = true
			context["fortified_positions"] = true
		"warehouse":
			context["corporate_security"] = true
			context["automated_defenses"] = true
		"convoy":
			context["mobile_defense"] = true
			context["escort_vehicles"] = true
		"settlement":
			context["militia_defense"] = true
			context["civilian_presence"] = true
		"facility":
			context["specialized_security"] = true
			context["high_tech_defenses"] = true
	
	# Defense strength affects enemy numbers and quality
	context["defense_strength"] = target_defenses
	context["defender_quality"] = target_defenses  # 1-5 scale
	
	# Target size affects enemy deployment points
	match target_size:
		"small": context["deployment_multiplier"] = 0.8
		"medium": context["deployment_multiplier"] = 1.0
		"large": context["deployment_multiplier"] = 1.3
		"massive": context["deployment_multiplier"] = 1.6
	
	# Assault phase affects enemy positioning
	context["assault_phase"] = assault_phase
	
	# Response forces if alarm triggered
	if alarm_raised:
		context["reinforcements_incoming"] = true
		context["response_eta"] = response_force_eta
	
	return context

## Private Methods

func _setup_raid_mission() -> void:
	mission_title = "Raid Operation"
	mission_description = "Assault target location for loot and resources"
	minimum_crew_size = 3  # Raids need firepower
	required_skills = ["combat"]

func _generate_raid_parameters() -> void:
	# Generate loot types based on target
	_generate_primary_loot_types()
	_generate_secondary_loot_types()
	
	# Set defensive positions based on target size
	match target_size:
		"small": total_defensive_positions = 2
		"medium": total_defensive_positions = 3
		"large": total_defensive_positions = 4
		"massive": total_defensive_positions = 5
	
	# Set response time if time pressure enabled
	if time_pressure:
		response_force_eta = target_defenses + randi() % 3  # 3-7 turns typically
	
	# Generate extraction routes
	extraction_routes_available = 2 + (target_size == "small" ? 1 : 0)

func _generate_primary_loot_types() -> void:
	primary_loot_types.clear()
	
	var loot_by_target: Dictionary = {
		"outpost": ["weapons", "ammunition", "military_supplies"],
		"warehouse": ["trade_goods", "raw_materials", "equipment"],
		"convoy": ["cargo", "vehicles", "fuel"],
		"settlement": ["resources", "equipment", "trade_goods"],
		"facility": ["technology", "research_data", "exotic_materials"]
	}
	
	var available_loot: Array = loot_by_target.get(target_type, ["general_supplies"])
	
	# Select 2-3 primary loot types
	var loot_count: int = 2 + (target_defenses > 3 ? 1 : 0)
	for i in range(loot_count):
		if not available_loot.is_empty():
			var loot_type: String = available_loot[randi() % available_loot.size()]
			primary_loot_types.append(loot_type)
			available_loot.erase(loot_type)

func _generate_secondary_loot_types() -> void:
	secondary_loot_types.clear()
	
	var universal_loot: Array[String] = [
		"credits", "personal_equipment", "consumables", 
		"intel", "spare_parts", "medical_supplies"
	]
	
	# Select 1-2 secondary loot types
	for i in range(2):
		if not universal_loot.is_empty():
			var loot_type: String = universal_loot[randi() % universal_loot.size()]
			secondary_loot_types.append(loot_type)
			universal_loot.erase(loot_type)

func _setup_raid_objectives() -> void:
	objectives.clear()
	
	# Primary: Secure valuable loot
	objectives.append({
		"description": "Secure valuable loot from %s" % target_type,
		"type": "secure_loot",
		"is_primary": true,
		"completed": false,
		"loot_value_target": target_value / 2  # At least 50% of estimated value
	})
	
	# Primary: Clear defensive positions
	objectives.append({
		"description": "Neutralize defensive positions",
		"type": "clear_defenses",
		"is_primary": true,
		"completed": false,
		"positions_target": total_defensive_positions
	})
	
	# Secondary: Minimize casualties
	objectives.append({
		"description": "Complete raid with minimal crew casualties",
		"type": "preserve_crew",
		"is_primary": false,
		"completed": false,
		"casualty_limit": 1
	})
	
	# Optional: Destruction bonus
	if destruction_bonus:
		objectives.append({
			"description": "Destroy target infrastructure",
			"type": "destruction_bonus",
			"is_primary": false,
			"completed": false,
			"destruction_target": 75,
			"bonus_credits": target_value / 4
		})
	
	# Time-sensitive: Complete before reinforcements
	if time_pressure:
		objectives.append({
			"description": "Complete raid before reinforcements arrive",
			"type": "beat_response_time",
			"is_primary": true,
			"completed": false,
			"time_limit": response_force_eta
		})

func _calculate_raid_rewards() -> void:
	# Base reward is lower than other missions (loot is main reward)
	var base_credits: int = 200 + (target_defenses * 100)
	
	# Target value affects base payment
	base_credits += target_value / 10
	
	# Size modifier
	match target_size:
		"small": base_credits = roundi(base_credits * 0.8)
		"large": base_credits = roundi(base_credits * 1.2)
		"massive": base_credits = roundi(base_credits * 1.4)
	
	reward_credits = base_credits
	
	# Advanced rules for loot-based rewards
	advanced_rules["loot_multiplier"] = {
		"poor": 0.7,
		"mixed": 1.0,
		"good": 1.3,
		"excellent": 1.6,
		"legendary": 2.0
	}
	
	advanced_rules["destruction_bonus_multiplier"] = 1.25
	advanced_rules["speed_bonus"] = {
		"lightning": 1.3,  # Completed in minimal time
		"fast": 1.1,       # Completed quickly
		"standard": 1.0,   # Normal completion time
		"slow": 0.9        # Took too long
	}

func _process_approach_phase(phase_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"phase_success": false, "complications": []}
	
	var stealth_skill: int = phase_data.get("stealth_skill", 1)
	var reconnaissance: bool = phase_data.get("reconnaissance", false)
	var approach_route: String = phase_data.get("route", "direct")
	
	# Calculate approach success
	var success_chance: float = 0.6
	
	# Stealth approach bonuses
	if approach_route == "stealth":
		success_chance += stealth_skill * 0.1
		success_chance += 0.2
	
	# Reconnaissance bonus
	if reconnaissance:
		success_chance += 0.15
	
	# Target defenses penalty
	success_chance -= target_defenses * 0.05
	
	if randf() < success_chance:
		result.phase_success = true
		if approach_route == "stealth":
			# Stealth approach grants surprise bonus
			advanced_rules["surprise_assault"] = true
	else:
		# Approach failed - alarm raised
		_trigger_alarm()
		result.complications.append("alarm_raised")
	
	return result

func _process_breach_phase(phase_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"phase_success": false, "casualties": 0}
	
	var demolitions_skill: int = phase_data.get("demolitions", 1)
	var breaching_equipment: bool = phase_data.get("breaching_gear", false)
	var assault_method: String = phase_data.get("method", "explosive")
	
	var success_chance: float = 0.7
	
	# Equipment and skill bonuses
	if breaching_equipment:
		success_chance += 0.2
	success_chance += demolitions_skill * 0.1
	
	# Method modifiers
	match assault_method:
		"explosive": success_chance += 0.1  # But may cause casualties
		"technical": success_chance += 0.15  # Safer but slower
		"brute_force": success_chance -= 0.1  # Simple but dangerous
	
	if randf() < success_chance:
		result.phase_success = true
		
		# Check for casualties during breach
		if assault_method == "explosive" and randf() < 0.2:
			result.casualties = 1
			civilian_casualties += 1
	else:
		# Breach failed - defenders alerted
		if not alarm_raised:
			_trigger_alarm()
		result.casualties = 1  # Breach failure casualties
	
	return result

func _process_combat_phase(phase_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"phase_success": false, "loot_found": []}
	
	var crew_combat: int = phase_data.get("crew_combat", 5)
	var tactical_coordination: int = phase_data.get("coordination", 2)
	
	# Combat success based on relative strength
	var crew_strength: int = crew_combat + tactical_coordination
	var defender_strength: int = target_defenses * 2
	
	var success_chance: float = float(crew_strength) / float(crew_strength + defender_strength)
	success_chance = clampf(success_chance, 0.2, 0.9)
	
	if randf() < success_chance:
		result.phase_success = true
		
		# Successful combat allows loot search
		var loot_found: int = 1 + (crew_combat / 3)
		for i in range(loot_found):
			var loot: Dictionary = _generate_combat_loot()
			result.loot_found.append(loot)
			loot_secured[loot.id] = loot
		
		# Clear defensive positions
		defensive_positions_cleared = total_defensive_positions
		
		for i in range(total_defensive_positions):
			defensive_position_cleared.emit(i)
	else:
		# Combat setback
		defensive_positions_cleared = maxii(defensive_positions_cleared - 1, 0)
	
	return result

func _process_extraction_phase(phase_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"phase_success": false, "loot_lost": []}
	
	var extraction_route: int = phase_data.get("route_choice", 0)
	var cargo_management: int = phase_data.get("cargo_skill", 2)
	var pursuit_evasion: int = phase_data.get("evasion_skill", 2)
	
	# Base extraction success
	var success_chance: float = 0.8
	
	# Route quality affects success
	if extraction_route < extraction_routes_available:
		success_chance += 0.1
	
	# Cargo load affects extraction
	var loot_load: int = _calculate_current_loot_load()
	if loot_load > 10:  # Overloaded
		success_chance -= 0.3
	
	# Alarm and pursuit
	if alarm_raised and response_force_eta <= 1:
		success_chance -= 0.4  # Active pursuit
		success_chance += pursuit_evasion * 0.1
	
	if randf() < success_chance:
		result.phase_success = true
		_complete_raid()
	else:
		# Extraction complications - may lose loot
		var loot_loss_chance: float = 0.3
		for loot_id in loot_secured.keys():
			if randf() < loot_loss_chance:
				result.loot_lost.append(loot_secured[loot_id])
				loot_secured.erase(loot_id)
	
	return result

func _advance_assault_phase() -> void:
	match assault_phase:
		"approach": assault_phase = "breach"
		"breach": assault_phase = "combat"
		"combat": assault_phase = "extraction"
		"extraction": assault_phase = "complete"
	
	assault_phase_changed.emit(assault_phase)

func _trigger_alarm() -> void:
	alarm_raised = true
	if time_pressure:
		response_force_eta = maxii(response_force_eta - 1, 1)
	target_alarm_triggered.emit(response_force_eta)

func _generate_loot_item(loot_type: String, amount: int) -> Dictionary:
	var base_value: int = 100
	
	# Type-specific values
	match loot_type:
		"weapons": base_value = 200
		"technology": base_value = 500
		"exotic_materials": base_value = 800
		"trade_goods": base_value = 150
		"credits": base_value = 50
	
	# Quality modifier
	var quality_multiplier: float = advanced_rules.loot_multiplier.get(loot_quality, 1.0)
	var final_value: int = roundi(base_value * amount * quality_multiplier)
	
	return {
		"id": str(Time.get_unix_time_from_system()) + "_" + loot_type,
		"type": loot_type,
		"amount": amount,
		"value": final_value,
		"weight": amount * 2,
		"quality": loot_quality
	}

func _generate_combat_loot() -> Dictionary:
	var loot_type: String = primary_loot_types[randi() % primary_loot_types.size()]
	return _generate_loot_item(loot_type, 1)

func _calculate_current_loot_load() -> int:
	var total_weight: int = 0
	for loot in loot_secured.values():
		total_weight += loot.get("weight", 1)
	return total_weight

func _calculate_total_loot_value() -> int:
	var total_value: int = 0
	for loot in loot_secured.values():
		total_value += loot.get("value", 0)
	return total_value

func _complete_raid() -> void:
	# Calculate final rewards including loot
	var loot_value: int = _calculate_total_loot_value()
	var destruction_bonus_value: int = 0
	
	if destruction_bonus and target_destruction_level >= 75:
		destruction_bonus_value = target_value / 4
	
	# Speed bonus calculation
	var speed_rating: String = _calculate_speed_rating()
	var speed_multiplier: float = advanced_rules.speed_bonus.get(speed_rating, 1.0)
	
	var total_credits: int = roundi((reward_credits + destruction_bonus_value) * speed_multiplier)
	reward_credits = total_credits
	
	# Store loot value for external systems
	advanced_rules["total_loot_value"] = loot_value
	advanced_rules["loot_items"] = loot_secured.values()
	
	complete_mission()

func _calculate_speed_rating() -> String:
	# This would be calculated based on actual turns taken vs expected
	# For now, simplified based on response time pressure
	if time_pressure and response_force_eta > 2:
		return "lightning"
	elif time_pressure and response_force_eta > 0:
		return "fast"
	elif not time_pressure:
		return "standard"
	else:
		return "slow"