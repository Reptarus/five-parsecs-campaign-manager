@tool
class_name EscortMission
extends Mission

## Escort Mission Implementation for Five Parsecs Campaign Manager
##
## Implements Five Parsecs VIP protection mechanics with threat assessment,
## protection protocols, and dynamic threat escalation.

# GlobalEnums available as autoload singleton
const MissionTypeRegistry = preload("res://src/game/missions/enhanced/MissionTypeRegistry.gd")

# VIP and escort data
@export var vip_name: String = ""
@export var vip_type: String = "civilian"  # civilian, corporate, government, criminal, scientist
@export var vip_importance: int = 2  # 1-5, affects threat level and rewards
@export var protection_value: int = 1000
@export var escort_distance: int = 2  # In locations/zones
@export var threat_level: int = 2  # Known threat assessment
@export var vip_cooperation: int = 3  # 1-5, how well VIP follows instructions

# VIP capabilities and limitations
@export var vip_can_fight: bool = false
@export var vip_has_bodyguard: bool = false
@export var vip_movement_restricted: bool = false
@export var vip_has_special_needs: bool = false

# Escort state tracking
var current_location: int = 0
var vip_health: int = 100
var vip_stress_level: int = 0  # 0-100, affects cooperation
var protection_incidents: int = 0
var escort_compromised: bool = false
var route_secure: bool = true

# Threat tracking
var active_threats: Array[Dictionary] = []
var threat_escalation_level: int = 0
var enemy_intelligence: int = 0  # How much enemies know about the escort

# Signals for escort-specific events
signal vip_threatened(threat_data: Dictionary)
signal protection_incident(incident_type: String, severity: int)
signal vip_stress_changed(new_stress_level: int)
signal route_compromised(location: int, threat_type: String)

func _init() -> void:
	super._init()
	mission_type = MissionTypeRegistry.EnhancedMissionType.ESCORT
	_setup_escort_mission()

## Initialize escort mission with VIP and route data
func initialize_escort(escort_data: Dictionary) -> void:
	initialize(escort_data)
	
	# Set VIP-specific data
	vip_name = escort_data.get("vip_name", "Important Person")
	vip_type = escort_data.get("vip_type", "civilian")
	vip_importance = escort_data.get("vip_importance", 2)
	protection_value = escort_data.get("protection_value", 1000)
	escort_distance = escort_data.get("escort_distance", 2)
	threat_level = escort_data.get("threat_level", 2)
	vip_cooperation = escort_data.get("vip_cooperation", 3)
	
	# Set VIP capabilities
	vip_can_fight = escort_data.get("vip_can_fight", false)
	vip_has_bodyguard = escort_data.get("vip_has_bodyguard", false)
	vip_movement_restricted = escort_data.get("vip_movement_restricted", false)
	vip_has_special_needs = escort_data.get("vip_has_special_needs", false)
	
	# Generate threats
	_generate_escort_threats()
	
	# Set up objectives
	_setup_escort_objectives()
	
	# Calculate escort rewards
	_calculate_escort_rewards()

## Process escort movement to next location
func process_escort_movement(movement_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"movement_successful": false,
		"incidents": [],
		"threats_encountered": [],
		"vip_status": "safe",
		"location_reached": current_location
	}
	
	var movement_method: String = movement_data.get("method", "standard")
	var security_level: int = movement_data.get("security_level", 2)
	var route_choice: String = movement_data.get("route", "main")
	
	# Check for threats at current location
	var threats: Array = _check_location_threats(current_location, movement_data)
	result.threats_encountered = threats
	
	if threats.is_empty():
		# Safe movement
		current_location += 1
		result.movement_successful = true
		result.location_reached = current_location
		
		# Update VIP stress (movement can be stressful)
		_update_vip_stress(-5)  # Successful movement reduces stress
		
		# Check if escort complete
		if current_location >= escort_distance:
			_complete_escort()
			result.vip_status = "delivered"
	else:
		# Handle threats
		for threat in threats:
			var incident: Dictionary = _handle_threat_incident(threat, movement_data)
			result.incidents.append(incident)
			
			if incident.vip_endangered:
				_update_vip_stress(20)
				result.vip_status = "endangered"
	
	return result

## Process protection incident during combat or event
func process_protection_incident(incident_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"vip_safe": true,
		"protection_effectiveness": 0.0,
		"stress_impact": 0,
		"cooperation_impact": 0
	}
	
	var threat_severity: int = incident_data.get("severity", 2)
	var crew_protection_skill: int = incident_data.get("protection_skill", 2)
	var bodyguard_present: bool = vip_has_bodyguard
	
	# Calculate protection effectiveness
	var protection_score: float = crew_protection_skill * 20
	if bodyguard_present:
		protection_score += 30
	
	# VIP cooperation affects protection
	protection_score += vip_cooperation * 5
	
	# Special equipment bonuses
	if incident_data.has("armor_provided"):
		protection_score += 25
	if incident_data.has("secure_transport"):
		protection_score += 15
	
	result.protection_effectiveness = protection_score / 100.0
	
	# Determine incident outcome
	var threat_roll: int = randi() % 100 + threat_severity * 10
	var protection_roll: int = randi() % 100 + protection_score
	
	if protection_roll >= threat_roll:
		# Protection successful
		result.vip_safe = true
		result.stress_impact = 5
		_update_vip_stress(5)
	else:
		# Protection partially failed
		var damage: int = (threat_roll - protection_roll) / 20
		_damage_vip(damage)
		result.vip_safe = vip_health > 50
		result.stress_impact = 15 + damage * 5
		result.cooperation_impact = -1
		_update_vip_stress(result.stress_impact)
		_update_vip_cooperation(-1)
	
	protection_incidents += 1
	protection_incident.emit(incident_data.get("type", "unknown"), threat_severity)
	
	return result

## Get escort status information
func get_escort_status() -> Dictionary:
	return {
		"vip_name": vip_name,
		"vip_type": vip_type,
		"vip_importance": vip_importance,
		"vip_health": vip_health,
		"vip_stress": vip_stress_level,
		"vip_cooperation": vip_cooperation,
		"current_location": current_location,
		"total_distance": escort_distance,
		"threat_level": threat_level,
		"active_threats": active_threats.size(),
		"protection_incidents": protection_incidents,
		"escort_compromised": escort_compromised,
		"route_secure": route_secure
	}

## Get mission-specific combat modifiers for escort situations
func get_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# VIP protection priority
	modifiers["vip_protection_priority"] = true
	modifiers["cover_vip"] = true
	
	# VIP capabilities affect tactics
	if vip_can_fight:
		modifiers["additional_combatant"] = true
	else:
		modifiers["protect_noncombatant"] = true
		modifiers["movement_restriction"] = 1
	
	# Bodyguard presence
	if vip_has_bodyguard:
		modifiers["bodyguard_bonus"] = 2
		modifiers["coordinated_protection"] = true
	
	# VIP cooperation affects positioning
	match vip_cooperation:
		1, 2: # Uncooperative
			modifiers["protection_penalty"] = 1
			modifiers["unpredictable_movement"] = true
		4, 5: # Very cooperative
			modifiers["protection_bonus"] = 1
			modifiers["coordinated_movement"] = true
	
	# Stress affects VIP behavior
	if vip_stress_level > 50:
		modifiers["panic_risk"] = true
		modifiers["vip_movement_penalty"] = 1
	
	return modifiers

## Get enemy deployment context for escort encounters
func get_enemy_deployment_context() -> Dictionary:
	var context: Dictionary = {}
	
	# VIP importance affects enemy strength
	context["target_value"] = vip_importance
	context["assassination_attempt"] = true
	
	# VIP type affects enemy types
	match vip_type:
		"corporate":
			context["corporate_enemies"] = true
			context["industrial_espionage"] = true
		"government":
			context["terrorist_threat"] = true
			context["political_assassination"] = true
		"criminal":
			context["rival_gangs"] = true
			context["law_enforcement_risk"] = true
		"scientist":
			context["corporate_interest"] = true
			context["foreign_agents"] = true
		"civilian":
			context["random_threats"] = true
	
	# Threat escalation affects enemy preparation
	context["threat_escalation"] = threat_escalation_level
	context["enemy_intelligence"] = enemy_intelligence
	
	# Location-based threats
	context["current_location"] = current_location
	context["escort_route"] = escort_distance
	
	return context

## Private Methods

func _setup_escort_mission() -> void:
	mission_title = "VIP Escort"
	mission_description = "Safely escort a VIP to their destination"
	minimum_crew_size = 3  # Need dedicated protection team
	required_skills = ["combat"]

func _generate_escort_threats() -> void:
	active_threats.clear()
	
	# Number of threats based on VIP importance and threat level
	var threat_count: int = vip_importance + threat_level - 1
	threat_count = clampi(threat_count, 1, 6)
	
	var possible_threats: Array[Dictionary] = [
		{
			"type": "assassination_attempt",
			"description": "Professional assassin targets the VIP",
			"severity": 4,
			"location_range": [1, escort_distance],
			"preparation_time": 2
		},
		{
			"type": "kidnapping_attempt",
			"description": "Criminal organization attempts kidnapping",
			"severity": 3,
			"location_range": [0, escort_distance - 1],
			"preparation_time": 1
		},
		{
			"type": "rival_ambush",
			"description": "Rival faction sets up ambush",
			"severity": 3,
			"location_range": [1, escort_distance - 1],
			"preparation_time": 3
		},
		{
			"type": "terrorist_attack",
			"description": "Terrorist cell targets VIP for political reasons",
			"severity": 5,
			"location_range": [escort_distance - 1, escort_distance],
			"preparation_time": 4
		},
		{
			"type": "corporate_extraction",
			"description": "Corporate agents attempt to extract VIP",
			"severity": 2,
			"location_range": [0, escort_distance],
			"preparation_time": 1
		}
	]
	
	# Add VIP-type specific threats
	match vip_type:
		"government":
			possible_threats.append({
				"type": "foreign_agents",
				"description": "Foreign intelligence operatives target VIP",
				"severity": 4,
				"location_range": [0, escort_distance],
				"preparation_time": 3
			})
		"criminal":
			possible_threats.append({
				"type": "law_enforcement_raid",
				"description": "Law enforcement attempts to arrest VIP",
				"severity": 2,
				"location_range": [1, escort_distance],
				"preparation_time": 1
			})
	
	# Select threats randomly
	for i in range(threat_count):
		if not possible_threats.is_empty():
			var threat: Dictionary = possible_threats[randi() % possible_threats.size()]
			threat["threat_id"] = i
			threat["active"] = true
			active_threats.append(threat)
			possible_threats.erase(threat)

func _setup_escort_objectives() -> void:
	objectives.clear()
	
	# Primary: Deliver VIP safely
	objectives.append({
		"description": "Escort %s to destination" % vip_name,
		"type": "escort_vip",
		"is_primary": true,
		"completed": false,
		"progress": 0,
		"target": escort_distance
	})
	
	# Secondary: Maintain VIP health
	objectives.append({
		"description": "Keep VIP in good health",
		"type": "maintain_health",
		"is_primary": false,
		"completed": false,
		"health_threshold": 75
	})
	
	# Secondary: Minimize stress
	objectives.append({
		"description": "Keep VIP stress levels low",
		"type": "minimize_stress",
		"is_primary": false,
		"completed": false,
		"stress_threshold": 30
	})
	
	# Bonus: No protection incidents
	objectives.append({
		"description": "Complete escort with no incidents",
		"type": "perfect_protection",
		"is_primary": false,
		"completed": false,
		"bonus_multiplier": 1.5
	})

func _calculate_escort_rewards() -> void:
	# Base reward based on VIP importance and protection value
	var base_credits: int = protection_value + (vip_importance * 200)
	
	# Distance modifier
	base_credits += escort_distance * 100
	
	# Threat level modifier
	base_credits = roundi(base_credits * (1.0 + threat_level * 0.2))
	
	reward_credits = base_credits
	
	# Advanced rules for performance bonuses
	advanced_rules["health_bonus"] = {
		100: 1.2,  # Perfect health
		75: 1.0,   # Good health
		50: 0.8,   # Poor health
		25: 0.6    # Critical health
	}
	
	advanced_rules["stress_bonus"] = {
		"low": 1.1,     # 0-30 stress
		"medium": 1.0,  # 31-60 stress
		"high": 0.9     # 61+ stress
	}
	
	advanced_rules["incident_penalty"] = 0.1  # -10% per incident

func _check_location_threats(location: int, movement_data: Dictionary) -> Array:
	var encountered_threats: Array = []
	
	for threat in active_threats:
		if not threat.active:
			continue
			
		var threat_range: Array = threat.location_range
		if location >= threat_range[0] and location <= threat_range[1]:
			# Check if threat triggers
			var trigger_chance: float = 0.4  # Base chance
			
			# Security level affects trigger chance
			var security_level: int = movement_data.get("security_level", 2)
			trigger_chance *= (6 - security_level) / 4.0
			
			# Route choice affects chance
			var route: String = movement_data.get("route", "main")
			match route:
				"stealth": trigger_chance *= 0.5
				"secure": trigger_chance *= 0.7
				"fast": trigger_chance *= 1.3
			
			if randf() < trigger_chance:
				encountered_threats.append(threat)
				threat.active = false  # Threat used
	
	return encountered_threats

func _handle_threat_incident(threat: Dictionary, movement_data: Dictionary) -> Dictionary:
	var incident: Dictionary = {
		"threat_type": threat.type,
		"severity": threat.severity,
		"vip_endangered": false,
		"protection_required": true,
		"enemy_strength": threat.severity + threat_escalation_level
	}
	
	# Threat escalation affects future incidents
	threat_escalation_level += 1
	enemy_intelligence += 1
	
	# VIP endangerment check
	var protection_roll: int = randi() % 100
	var threat_roll: int = randi() % 100 + threat.severity * 15
	
	if threat_roll > protection_roll + 30:  # High threshold for endangerment
		incident.vip_endangered = true
		vip_threatened.emit(threat)
	
	return incident

func _update_vip_stress(change: int) -> void:
	vip_stress_level = clampi(vip_stress_level + change, 0, 100)
	vip_stress_changed.emit(vip_stress_level)
	
	# High stress affects cooperation
	if vip_stress_level > 70 and vip_cooperation > 1:
		_update_vip_cooperation(-1)

func _update_vip_cooperation(change: int) -> void:
	vip_cooperation = clampi(vip_cooperation + change, 1, 5)

func _damage_vip(damage: int) -> void:
	vip_health = maxii(vip_health - damage * 10, 0)
	
	if vip_health <= 0:
		_fail_escort_vip_killed()
	elif vip_health <= 25:
		escort_compromised = true

func _complete_escort() -> void:
	# Calculate final rewards based on performance
	var health_multiplier: float = _get_health_bonus_multiplier()
	var stress_multiplier: float = _get_stress_bonus_multiplier()
	var incident_penalty: float = 1.0 - (protection_incidents * advanced_rules.incident_penalty)
	
	var final_reward: int = roundi(reward_credits * health_multiplier * stress_multiplier * incident_penalty)
	reward_credits = maxii(final_reward, reward_credits / 2)  # Minimum 50% payment
	
	complete_mission()

func _fail_escort_vip_killed() -> void:
	fail_mission()
	advanced_rules["failure_reason"] = "vip_killed"

func _get_health_bonus_multiplier() -> float:
	for health_threshold in advanced_rules.health_bonus.keys():
		if vip_health >= health_threshold:
			return advanced_rules.health_bonus[health_threshold]
	return 0.5  # Severely injured

func _get_stress_bonus_multiplier() -> float:
	if vip_stress_level <= 30:
		return advanced_rules.stress_bonus.low
	elif vip_stress_level <= 60:
		return advanced_rules.stress_bonus.medium
	else:
		return advanced_rules.stress_bonus.high