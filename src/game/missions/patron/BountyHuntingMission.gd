@tool
class_name BountyHuntingMission
extends Mission

## Bounty Hunting Mission Implementation for Five Parsecs Campaign Manager
##
## Implements Five Parsecs bounty hunting mechanics with target tracking,
## capture vs elimination choices, and bounty-specific complications.

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const MissionTypeRegistry = preload("res://src/game/missions/enhanced/MissionTypeRegistry.gd")

# Bounty target data
@export var target_name: String = ""
@export var target_type: String = "criminal"  # criminal, rival, fugitive, informant
@export var bounty_value: int = 500
@export var capture_bonus: int = 200  # Extra for alive capture
@export var target_danger_level: int = 2
@export var target_skills: Array[String] = []
@export var target_equipment: Array[String] = []
@export var target_hideout_type: String = "urban"

# Bounty hunting state
var target_location_known: bool = false
var investigation_progress: int = 0
var investigation_required: int = 3  # Clues needed to locate target
var target_captured_alive: bool = false
var target_eliminated: bool = false
var bounty_hunter_license: bool = false

# Target behavior and complications
var target_awareness_level: int = 0  # 0=unaware, 3=fully alert and fleeing
var backup_called: bool = false
var law_enforcement_involved: bool = false

# Signals for bounty-specific events
signal target_located(location_data: Dictionary)
signal investigation_clue_found(clue_data: Dictionary)
signal target_awareness_increased(new_level: int)
signal bounty_complications(complication_type: String)

func _init() -> void:
	super._init()
	mission_type = MissionTypeRegistry.EnhancedMissionType.BOUNTY_HUNTING
	_setup_bounty_mission()

## Initialize bounty mission with target data
func initialize_bounty(bounty_data: Dictionary) -> void:
	initialize(bounty_data)
	
	# Set target-specific data
	target_name = bounty_data.get("target_name", "Unknown Fugitive")
	target_type = bounty_data.get("target_type", "criminal")
	bounty_value = bounty_data.get("bounty_value", 500)
	capture_bonus = bounty_data.get("capture_bonus", 200)
	target_danger_level = bounty_data.get("target_danger_level", 2)
	target_skills = bounty_data.get("target_skills", ["combat"])
	target_equipment = bounty_data.get("target_equipment", ["basic_weapon"])
	target_hideout_type = bounty_data.get("target_hideout_type", "urban")
	
	# Set investigation requirements
	investigation_required = target_danger_level + 1
	bounty_hunter_license = bounty_data.get("crew_has_license", false)
	
	# Generate target behavior
	_generate_target_behavior()
	
	# Set up objectives
	_setup_bounty_objectives()
	
	# Calculate bounty rewards
	_calculate_bounty_rewards()

## Process investigation action
func process_investigation(investigation_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"clue_found": {},
		"complications": [],
		"target_awareness_change": 0
	}
	
	var skill_used: String = investigation_data.get("skill", "savvy")
	var skill_value: int = investigation_data.get("skill_value", 1)
	var stealth_approach: bool = investigation_data.get("stealth", false)
	
	# Calculate success chance
	var success_chance: float = 0.5 + (skill_value * 0.1)
	if stealth_approach:
		success_chance += 0.2
	
	# Skill-specific bonuses
	match skill_used:
		"savvy": success_chance += 0.15  # Best for investigation
		"tech": success_chance += 0.1   # Good for electronic trails
		"combat": success_chance -= 0.1  # Less subtle
	
	if randf() < success_chance:
		var clue: Dictionary = _generate_investigation_clue()
		investigation_progress += 1
		result.success = true
		result.clue_found = clue
		
		investigation_clue_found.emit(clue)
		
		# Check if target is located
		if investigation_progress >= investigation_required:
			_locate_target()
	else:
		# Failed investigation may raise awareness
		if not stealth_approach and randf() < 0.3:
			_increase_target_awareness(1)
			result.target_awareness_change = 1
	
	# Check for complications
	result.complications = _check_investigation_complications(investigation_data)
	
	return result

## Process bounty capture attempt
func process_capture_attempt(capture_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"method": "",
		"target_status": "",
		"complications": []
	}
	
	if not target_location_known:
		result.complications.append("target_location_unknown")
		return result
	
	var approach_method: String = capture_data.get("method", "direct_assault")
	var crew_combat_strength: int = capture_data.get("crew_combat", 5)
	var non_lethal_equipment: bool = capture_data.get("non_lethal", false)
	
	# Calculate capture success based on method and target awareness
	var success_chance: float = _calculate_capture_chance(approach_method, crew_combat_strength)
	
	if randf() < success_chance:
		result.success = true
		result.method = approach_method
		
		# Determine if target is captured alive or eliminated
		if non_lethal_equipment and approach_method != "lethal_force":
			target_captured_alive = true
			result.target_status = "captured_alive"
			_complete_bounty_capture()
		else:
			target_eliminated = true
			result.target_status = "eliminated"
			_complete_bounty_elimination()
	else:
		# Failed capture - target escapes
		_handle_capture_failure()
		result.complications.append("target_escaped")
		result.target_status = "escaped"
	
	return result

## Get bounty status information
func get_bounty_status() -> Dictionary:
	return {
		"target_name": target_name,
		"target_type": target_type,
		"bounty_value": bounty_value,
		"capture_bonus": capture_bonus,
		"target_danger_level": target_danger_level,
		"investigation_progress": investigation_progress,
		"investigation_required": investigation_required,
		"target_located": target_location_known,
		"target_awareness": target_awareness_level,
		"backup_called": backup_called,
		"law_enforcement_involved": law_enforcement_involved,
		"bounty_hunter_license": bounty_hunter_license
	}

## Get mission-specific combat modifiers for bounty encounters
func get_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Target awareness affects combat
	match target_awareness_level:
		0, 1: # Unaware/slightly aware
			modifiers["surprise_bonus"] = 2
		2: # Alert
			modifiers["initiative_bonus"] = 1
		3: # Fully alert and prepared
			modifiers["target_defensive_bonus"] = 2
			modifiers["backup_chance"] = 0.5
	
	# Capture attempt modifiers
	if not target_eliminated and not target_captured_alive:
		modifiers["non_lethal_preferred"] = true
		modifiers["capture_equipment_bonus"] = 1
	
	# Bounty license affects legal complications
	if not bounty_hunter_license:
		modifiers["law_enforcement_risk"] = 0.3
	
	return modifiers

## Get enemy deployment context for bounty encounters
func get_enemy_deployment_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Target danger level affects enemy strength
	context["primary_target_strength"] = target_danger_level
	
	# Target type affects backup and support
	match target_type:
		"criminal":
			context["gang_backup_chance"] = 0.4
			context["criminal_hideout"] = true
		"rival":
			context["crew_backup"] = true
			context["enhanced_equipment"] = true
		"fugitive":
			context["desperate_combat"] = true
			context["improvised_weapons"] = true
		"informant":
			context["stealth_focus"] = true
			context["escape_routes"] = true
	
	# Hideout type affects terrain and tactics
	context["hideout_type"] = target_hideout_type
	
	# Awareness level affects preparation
	if target_awareness_level >= 2:
		context["prepared_defenses"] = true
		context["trap_chance"] = 0.3
	
	return context

## Private Methods

func _setup_bounty_mission() -> void:
	mission_title = "Bounty Contract"
	mission_description = "Track down and capture a wanted target"
	minimum_crew_size = 2
	required_skills = ["combat", "savvy"]

func _generate_target_behavior() -> void:
	# Target behavior based on type and danger level
	match target_type:
		"criminal":
			target_skills.append_array(["combat", "criminal_contacts"])
		"rival":
			target_skills.append_array(["combat", "tech", "leadership"])
		"fugitive":
			target_skills.append_array(["stealth", "survival"])
		"informant":
			target_skills.append_array(["savvy", "stealth", "tech"])
	
	# Equipment based on danger level
	match target_danger_level:
		1: target_equipment = ["basic_weapon"]
		2: target_equipment = ["combat_armor", "military_rifle"]
		3: target_equipment = ["combat_armor", "military_rifle", "grenades"]
		4: target_equipment = ["power_armor", "assault_weapon", "military_gear"]
		5: target_equipment = ["power_armor", "exotic_weapon", "advanced_tech"]

func _setup_bounty_objectives() -> void:
	objectives.clear()
	
	# Primary: Locate target
	objectives.append({
		"description": "Investigate and locate %s" % target_name,
		"type": "locate_target",
		"is_primary": true,
		"completed": false,
		"progress": 0,
		"target": investigation_required
	})
	
	# Primary: Capture or eliminate target
	objectives.append({
		"description": "Capture or eliminate %s" % target_name,
		"type": "capture_target",
		"is_primary": true,
		"completed": false,
		"requires": ["locate_target"]
	})
	
	# Secondary: Capture alive for bonus
	if capture_bonus > 0:
		objectives.append({
			"description": "Capture %s alive for bonus reward" % target_name,
			"type": "capture_alive",
			"is_primary": false,
			"completed": false,
			"bonus_credits": capture_bonus
		})

func _calculate_bounty_rewards() -> void:
	# Base bounty value
	reward_credits = bounty_value
	
	# Advanced rules for bonus calculations
	advanced_rules["capture_alive_bonus"] = capture_bonus
	advanced_rules["target_danger_multiplier"] = 1.0 + (target_danger_level * 0.2)
	
	# License bonus/penalty
	if bounty_hunter_license:
		advanced_rules["license_bonus"] = 1.1
	else:
		advanced_rules["legal_risk_penalty"] = 0.9

func _generate_investigation_clue() -> Dictionary:
	var clue_types: Array[Dictionary] = [
		{
			"type": "informant_contact",
			"description": "A local informant provides information about the target's activities",
			"reliability": 0.8
		},
		{
			"type": "surveillance_footage",
			"description": "Security footage shows the target's recent movements",
			"reliability": 0.9
		},
		{
			"type": "financial_trail",
			"description": "Credit transactions reveal the target's spending patterns",
			"reliability": 0.7
		},
		{
			"type": "associate_questioning",
			"description": "Known associates provide reluctant information",
			"reliability": 0.6
		},
		{
			"type": "hideout_discovery",
			"description": "Investigation reveals the target's likely hideout location",
			"reliability": 1.0
		}
	]
	
	var clue: Dictionary = clue_types[randi() % clue_types.size()]
	clue["investigation_progress"] = investigation_progress
	return clue

func _locate_target() -> void:
	target_location_known = true
	var location_data: Dictionary = {
		"hideout_type": target_hideout_type,
		"target_awareness": target_awareness_level,
		"defensive_preparations": target_awareness_level >= 2,
		"backup_available": _calculate_backup_availability()
	}
	target_located.emit(location_data)

func _increase_target_awareness(amount: int) -> void:
	target_awareness_level = minii(target_awareness_level + amount, 3)
	target_awareness_increased.emit(target_awareness_level)
	
	# High awareness triggers additional complications
	if target_awareness_level >= 2 and not backup_called:
		backup_called = randf() < 0.6
		
	if target_awareness_level >= 3 and not law_enforcement_involved:
		law_enforcement_involved = randf() < 0.4

func _check_investigation_complications(investigation_data: Dictionary) -> Array:
	var complications: Array = []
	
	# Law enforcement interference
	if not bounty_hunter_license and randf() < 0.2:
		complications.append("law_enforcement_interference")
		law_enforcement_involved = true
		bounty_complications.emit("law_enforcement")
	
	# Target's allies interfere
	if target_type == "criminal" and randf() < 0.3:
		complications.append("gang_interference")
		bounty_complications.emit("gang_interference")
	
	# Information broker demands payment
	if randf() < 0.25:
		complications.append("information_cost")
		bounty_complications.emit("information_cost")
	
	return complications

func _calculate_capture_chance(method: String, crew_strength: int) -> float:
	var base_chance: float = 0.6
	
	# Method modifiers
	match method:
		"stealth_approach":
			base_chance += 0.2
			if target_awareness_level <= 1:
				base_chance += 0.2
		"direct_assault":
			base_chance -= 0.1
			base_chance += (crew_strength * 0.05)
		"negotiation":
			base_chance += 0.1
			if target_type == "informant":
				base_chance += 0.3
		"ambush":
			base_chance += 0.25
			if target_awareness_level >= 2:
				base_chance -= 0.3
	
	# Target danger level penalty
	base_chance -= (target_danger_level * 0.1)
	
	# Awareness penalty
	base_chance -= (target_awareness_level * 0.15)
	
	return clampf(base_chance, 0.1, 0.9)

func _calculate_backup_availability() -> bool:
	match target_type:
		"criminal": return randf() < 0.6
		"rival": return randf() < 0.8
		"fugitive": return randf() < 0.2
		"informant": return randf() < 0.3
		_: return false

func _complete_bounty_capture() -> void:
	var final_reward: int = bounty_value + capture_bonus
	reward_credits = final_reward
	complete_mission()

func _complete_bounty_elimination() -> void:
	reward_credits = bounty_value
	complete_mission()

func _handle_capture_failure() -> void:
	# Target escapes, becomes more aware
	_increase_target_awareness(2)
	target_location_known = false  # Need to track again
	investigation_progress = maxii(investigation_progress - 1, 0)