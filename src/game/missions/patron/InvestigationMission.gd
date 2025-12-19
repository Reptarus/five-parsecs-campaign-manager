@tool
class_name InvestigationMission
extends Mission

## Investigation Mission Implementation for Five Parsecs Campaign Manager
##
## Implements Five Parsecs investigation mechanics with evidence gathering,
## stealth requirements, and information-based rewards.

# GlobalEnums available as autoload singleton
const FPCM_MissionTypeRegistry = preload("res://src/game/missions/enhanced/MissionTypeRegistry.gd")

# Investigation parameters
@export var investigation_type: String = "corporate" # corporate, criminal, scientific, personal, political
@export var target_organization: String = ""
@export var investigation_complexity: int = 3 # 1-5, affects evidence requirements
@export var stealth_requirement: bool = true
@export var time_sensitive: bool = false
@export var evidence_destruction_risk: bool = false

# Investigation objectives and evidence
@export var required_evidence_types: Array[String] = []
@export var optional_evidence_types: Array[String] = []
@export var investigation_budget: int = 500

# Investigation state
var evidence_collected: Dictionary = {}
var investigation_progress: int = 0
var required_evidence_count: int = 3
var stealth_maintained: bool = true
var investigation_discovered: bool = false
var security_alertness: int = 0 # 0-5, increases detection chances

# Information contacts and sources
var active_contacts: Array[Dictionary] = []
var compromised_sources: Array[String] = []
var information_network_quality: int = 2 # 1-5, affects info quality

# Signals for investigation events
signal evidence_discovered(evidence_data: Dictionary)
signal investigation_compromised(discovery_method: String)
signal contact_established(contact_data: Dictionary)
signal security_alert_raised(alert_level: int)

# Mission base properties
var minimum_crew_size: int = 2
var required_skills: Array[String] = ["savvy", "tech"]
var objectives: Array[Dictionary] = []

# Reference the parent class for proper inheritance
const MissionClass = preload("res://src/core/campaign/Mission.gd")

func _init() -> void:
	super._init()
	# Use base MissionType for patron missions
	mission_type = MissionClass.MissionType.PATRON_JOB
	_setup_investigation_mission()

## Initialize investigation mission with specific parameters
func initialize_investigation(investigation_data: Dictionary) -> void:
	# Set investigation-specific data (skip parent initialization since it's not available)
	investigation_type = investigation_data.get("investigation_type", "corporate")
	target_organization = investigation_data.get("target_organization", "Unknown Entity")
	investigation_complexity = investigation_data.get("investigation_complexity", 3)
	stealth_requirement = investigation_data.get("stealth_requirement", true)
	time_sensitive = investigation_data.get("time_sensitive", false)
	evidence_destruction_risk = investigation_data.get("evidence_destruction_risk", false)
	investigation_budget = investigation_data.get("investigation_budget", 500)
	
	# Set evidence requirements
	required_evidence_count = investigation_complexity
	_generate_evidence_requirements()
	
	# Generate contacts and sources
	_generate_information_network()
	
	# Set up objectives
	_setup_investigation_objectives()
	
	# Calculate investigation rewards
	_calculate_investigation_rewards()

## Process investigation action
func process_investigation_action(action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"evidence_found": {},
		"contacts_made": [],
		"complications": [],
		"stealth_status": "maintained",
		"cost": 0
	}
	
	var action_type: String = action_data.get("action", "search")
	var location: String = action_data.get("location", "public")
	var skill_used: String = action_data.get("skill", "savvy")
	var skill_value: int = action_data.get("skill_value", 2)
	var stealth_approach: bool = action_data.get("stealth", true)
	var budget_used: int = action_data.get("budget_used", 0)
	
	# Process the specific action
	match action_type:
		"gather_evidence":
			result = _process_evidence_gathering(action_data)
		"contact_informant":
			result = _process_informant_contact(action_data)
		"infiltrate_facility":
			result = _process_facility_infiltration(action_data)
		"surveillance":
			result = _process_surveillance_operation(action_data)
		"data_analysis":
			result = _process_data_analysis(action_data)
		"interview_witness":
			result = _process_witness_interview(action_data)
	
	# Check stealth status
	if stealth_requirement and not stealth_approach:
		_check_discovery_risk(action_data, result)
	
	# Update investigation progress
	if result.success:
		investigation_progress += 1
		_check_investigation_completion()
	
	return result

## Get investigation status information
func get_investigation_status() -> Dictionary:
	return {
		"investigation_type": investigation_type,
		"target_organization": target_organization,
		"investigation_complexity": investigation_complexity,
		"investigation_progress": investigation_progress,
		"required_evidence_count": required_evidence_count,
		"evidence_collected": evidence_collected.size(),
		"stealth_maintained": stealth_maintained,
		"investigation_discovered": investigation_discovered,
		"security_alertness": security_alertness,
		"budget_remaining": investigation_budget,
		"active_contacts": active_contacts.size(),
		"compromised_sources": compromised_sources.size()
	}

## Get available investigation actions based on current state
func get_available_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	
	# Standard evidence gathering
	actions.append({
		"action": "gather_evidence",
		"name": "Gather Evidence",
		"description": "Search for physical or digital evidence",
		"skill_required": "savvy",
		"base_cost": 50,
		"stealth_possible": true
	})
	
	# Contact informants (if network available)
	if active_contacts.size() > 0:
		actions.append({
			"action": "contact_informant",
			"name": "Contact Informant",
			"description": "Gather information from network contacts",
			"skill_required": "savvy",
			"base_cost": 100,
			"stealth_possible": true
		})
	
	# Facility infiltration (high risk, high reward)
	if not investigation_discovered:
		actions.append({
			"action": "infiltrate_facility",
			"name": "Infiltrate Facility",
			"description": "Break into target location for evidence",
			"skill_required": "tech",
			"base_cost": 200,
			"stealth_required": true,
			"high_risk": true
		})
	
	# Surveillance operations
	actions.append({
		"action": "surveillance",
		"name": "Conduct Surveillance",
		"description": "Monitor target activities for patterns",
		"skill_required": "tech",
		"base_cost": 75,
		"stealth_possible": true
	})
	
	# Data analysis (if evidence exists)
	if evidence_collected.size() > 0:
		actions.append({
			"action": "data_analysis",
			"name": "Analyze Evidence",
			"description": "Cross-reference and analyze collected evidence",
			"skill_required": "tech",
			"base_cost": 25,
			"stealth_possible": true
		})
	
	return actions

## Get mission-specific modifiers for investigation encounters
func get_investigation_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Stealth focus
	if stealth_requirement:
		modifiers["stealth_priority"] = true
		modifiers["avoid_combat"] = true
		modifiers["silent_weapons_preferred"] = true
	
	# Security alertness affects detection
	modifiers["detection_risk"] = security_alertness * 0.15
	
	# Investigation discovery changes tactics
	if investigation_discovered:
		modifiers["active_countermeasures"] = true
		modifiers["increased_security"] = security_alertness + 2
		modifiers["evidence_destruction_risk"] = true
	
	# Time pressure affects actions
	if time_sensitive:
		modifiers["time_pressure"] = true
		modifiers["rushed_actions_penalty"] = 1
	
	return modifiers

## Get enemy deployment context for investigation encounters
func get_enemy_deployment_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Investigation type affects enemy types
	match investigation_type:
		"corporate":
			context["corporate_security"] = true
			context["professional_guards"] = true
			context["advanced_surveillance"] = true
		"criminal":
			context["gang_members"] = true
			context["street_level_security"] = true
			context["improvised_defenses"] = true
		"political":
			context["government_agents"] = true
			context["professional_security"] = true
			context["high_level_clearance"] = true
		"scientific":
			context["research_security"] = true
			context["automated_defenses"] = true
			context["containment_protocols"] = true
	
	# Security alertness affects enemy preparation
	context["alertness_level"] = security_alertness
	context["discovery_status"] = investigation_discovered
	
	# Target organization importance affects resources
	context["organization_resources"] = investigation_complexity
	
	return context

## Private Methods

func _setup_investigation_mission() -> void:
	# Using properties from parent Mission class
	set("mission_name", "Investigation Contract")
	set("description", "Gather intelligence and evidence on the target")
	set("required_crew_size", 2)

func _generate_evidence_requirements() -> void:
	required_evidence_types.clear()
	optional_evidence_types.clear()
	
	# Base evidence types for all investigations
	var base_evidence: Array[String] = [
		"financial_records",
		"communication_logs",
		"witness_testimony",
		"physical_evidence",
		"surveillance_footage"
	]
	
	# Investigation-specific evidence
	var specific_evidence: Dictionary = {
		"corporate": ["insider_information", "meeting_recordings", "contract_documents"],
		"criminal": ["transaction_records", "associate_information", "weapon_caches"],
		"political": ["classified_documents", "voting_records", "corruption_evidence"],
		"scientific": ["research_data", "test_results", "safety_violations"],
		"personal": ["personal_communications", "location_data", "relationship_evidence"]
	}
	
	# Select required evidence
	var available_evidence: Array[String] = base_evidence + specific_evidence.get(investigation_type, [])
	for i in range(required_evidence_count):
		if not available_evidence.is_empty():
			var evidence: String = available_evidence[randi() % available_evidence.size()]
			required_evidence_types.append(evidence)
			available_evidence.erase(evidence)
	
	# Set optional evidence (bonus objectives)
	for i in range(2):
		if not available_evidence.is_empty():
			var evidence: String = available_evidence[randi() % available_evidence.size()]
			optional_evidence_types.append(evidence)
			available_evidence.erase(evidence)

func _generate_information_network() -> void:
	active_contacts.clear()
	
	# Number of contacts based on investigation complexity and budget
	var contact_count: int = (investigation_complexity + information_network_quality) / 2
	contact_count = clampi(contact_count, 1, 4)
	
	var possible_contacts: Array[Dictionary] = [
		{
			"name": "Inside Source",
			"type": "insider",
			"reliability": 0.8,
			"cost": 200,
			"evidence_types": ["insider_information", "communication_logs"]
		},
		{
			"name": "Street Informant",
			"type": "street",
			"reliability": 0.6,
			"cost": 75,
			"evidence_types": ["witness_testimony", "surveillance_footage"]
		},
		{
			"name": "Data Broker",
			"type": "tech",
			"reliability": 0.7,
			"cost": 150,
			"evidence_types": ["financial_records", "communication_logs"]
		},
		{
			"name": "Former Employee",
			"type": "disgruntled",
			"reliability": 0.9,
			"cost": 100,
			"evidence_types": ["insider_information", "physical_evidence"]
		}
	]
	
	# Select contacts
	for i in range(contact_count):
		if not possible_contacts.is_empty():
			var contact: Dictionary = possible_contacts[randi() % possible_contacts.size()]
			active_contacts.append(contact)
			possible_contacts.erase(contact)

func _setup_investigation_objectives() -> void:
	objectives.clear()
	
	# Primary: Gather required evidence
	for evidence_type in required_evidence_types:
		objectives.append({
			"description": "Obtain %s" % evidence_type.replace("_", " "),
			"type": "gather_evidence",
			"evidence_type": evidence_type,
			"is_primary": true,
			"completed": false
		})
	
	# Secondary: Maintain stealth
	if stealth_requirement:
		objectives.append({
			"description": "Complete investigation without detection",
			"type": "maintain_stealth",
			"is_primary": false,
			"completed": false
		})
	
	# Bonus: Gather optional evidence
	for evidence_type in optional_evidence_types:
		objectives.append({
			"description": "Bonus: Obtain %s" % evidence_type.replace("_", " "),
			"type": "bonus_evidence",
			"evidence_type": evidence_type,
			"is_primary": false,
			"completed": false
		})

func _calculate_investigation_rewards() -> void:
	# Base reward based on complexity and target importance
	var base_credits: int = 300 + (investigation_complexity * 200)
	
	# Investigation type modifier
	match investigation_type:
		"corporate", "political":
			base_credits = roundi(base_credits * 1.3) # Higher stakes
		"scientific":
			base_credits = roundi(base_credits * 1.2)
		"criminal":
			base_credits = roundi(base_credits * 1.1)
	
	# Stealth requirement bonus
	if stealth_requirement:
		base_credits = roundi(base_credits * 1.15)
	
	reward_credits = base_credits
	
	# Advanced rules for performance bonuses
	objective_parameters["stealth_bonus"] = 1.3
	objective_parameters["evidence_quality_bonus"] = {
		"excellent": 1.4,
		"good": 1.2,
		"adequate": 1.0,
		"poor": 0.8
	}
	objective_parameters["time_bonus"] = {
		"early": 1.2,
		"on_time": 1.0,
		"late": 0.8
	}

func _process_evidence_gathering(action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "evidence_found": {}, "cost": 50}
	
	var skill_value: int = action_data.get("skill_value", 2)
	var location: String = action_data.get("location", "public")
	var stealth: bool = action_data.get("stealth", true)
	
	# Calculate success chance
	var success_chance: float = 0.4 + (skill_value * 0.1)
	
	# Location modifier
	match location:
		"public": success_chance += 0.2
		"private": success_chance -= 0.1
		"secure": success_chance -= 0.3
	
	# Stealth approach modifier
	if stealth:
		success_chance += 0.1
	
	if randf() < success_chance:
		result.success = true
		result.evidence_found = _generate_evidence()
		evidence_collected[result.evidence_found.type] = result.evidence_found
		evidence_discovered.emit(result.evidence_found)
	
	investigation_budget -= result.cost
	return result

func _process_informant_contact(action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "evidence_found": {}, "cost": 100}
	
	if active_contacts.is_empty():
		result.cost = 0
		return result
	
	var contact: Dictionary = active_contacts[randi() % active_contacts.size()]
	result.cost = contact.cost
	
	if investigation_budget >= contact.cost:
		var reliability_roll: float = randf()
		if reliability_roll < contact.reliability:
			result.success = true
			result.evidence_found = _generate_contact_evidence(contact)
			evidence_collected[result.evidence_found.type] = result.evidence_found
			evidence_discovered.emit(result.evidence_found)
		
		investigation_budget -= result.cost
	else:
		result.cost = 0 # Can't afford
	
	return result

func _process_facility_infiltration(action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "evidence_found": {}, "cost": 200, "high_risk": true}
	
	var tech_skill: int = action_data.get("skill_value", 2)
	var equipment_quality: int = action_data.get("equipment_quality", 2)
	
	# High risk, high reward
	var success_chance: float = 0.3 + (tech_skill * 0.15) + (equipment_quality * 0.1)
	
	if randf() < success_chance:
		result.success = true
		result.evidence_found = _generate_premium_evidence()
		evidence_collected[result.evidence_found.type] = result.evidence_found
		evidence_discovered.emit(result.evidence_found)
	else:
		# Failure may compromise mission
		_increase_security_alertness(2)
		result.complications = ["security_alert", "possible_discovery"]
	
	investigation_budget -= result.cost
	return result

func _process_surveillance_operation(action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "evidence_found": {}, "cost": 75}
	
	var tech_skill: int = action_data.get("skill_value", 2)
	var equipment_quality: int = action_data.get("equipment_quality", 2)
	
	var success_chance: float = 0.6 + (tech_skill * 0.1) + (equipment_quality * 0.05)
	
	if randf() < success_chance:
		result.success = true
		result.evidence_found = _generate_surveillance_evidence()
		evidence_collected[result.evidence_found.type] = result.evidence_found
		evidence_discovered.emit(result.evidence_found)
	
	investigation_budget -= result.cost
	return result

func _process_data_analysis(action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "evidence_found": {}, "cost": 25}
	
	if evidence_collected.size() < 2:
		return result
	
	var tech_skill: int = action_data.get("skill_value", 2)
	var success_chance: float = 0.7 + (tech_skill * 0.1)
	
	if randf() < success_chance:
		result.success = true
		result.evidence_found = _generate_analysis_evidence()
		evidence_collected[result.evidence_found.type] = result.evidence_found
		evidence_discovered.emit(result.evidence_found)
	
	investigation_budget -= result.cost
	return result

func _process_witness_interview(action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "evidence_found": {}, "cost": 0}
	
	var savvy_skill: int = action_data.get("skill_value", 2)
	var approach: String = action_data.get("approach", "friendly")
	
	var success_chance: float = 0.5 + (savvy_skill * 0.15)
	
	# Approach modifiers
	match approach:
		"friendly": success_chance += 0.1
		"intimidating": success_chance += 0.2 # but may raise alerts
		"bribery":
			success_chance += 0.3
			result.cost = 50
	
	if randf() < success_chance:
		result.success = true
		result.evidence_found = _generate_witness_evidence()
		evidence_collected[result.evidence_found.type] = result.evidence_found
		evidence_discovered.emit(result.evidence_found)
	
	if approach == "intimidating" and randf() < 0.3:
		_increase_security_alertness(1)
	
	investigation_budget -= result.cost
	return result

func _generate_evidence() -> Dictionary:
	var evidence_type: String = required_evidence_types[randi() % required_evidence_types.size()]
	return {
		"type": evidence_type,
		"quality": "standard",
		"source": "investigation",
		"reliability": 0.8
	}

func _generate_contact_evidence(contact: Dictionary) -> Dictionary:
	var evidence_types: Array = contact.evidence_types
	var evidence_type: String = evidence_types[randi() % evidence_types.size()]
	return {
		"type": evidence_type,
		"quality": "reliable",
		"source": contact.type,
		"reliability": contact.reliability
	}

func _generate_premium_evidence() -> Dictionary:
	var evidence_type: String = required_evidence_types[randi() % required_evidence_types.size()]
	return {
		"type": evidence_type,
		"quality": "excellent",
		"source": "infiltration",
		"reliability": 0.95
	}

func _generate_surveillance_evidence() -> Dictionary:
	return {
		"type": "surveillance_footage",
		"quality": "good",
		"source": "surveillance",
		"reliability": 0.85
	}

func _generate_analysis_evidence() -> Dictionary:
	return {
		"type": "data_correlation",
		"quality": "analytical",
		"source": "analysis",
		"reliability": 0.9
	}

func _generate_witness_evidence() -> Dictionary:
	return {
		"type": "witness_testimony",
		"quality": "personal",
		"source": "interview",
		"reliability": 0.75
	}

func _check_discovery_risk(action_data: Dictionary, result: Dictionary) -> void:
	var discovery_chance: float = 0.1 + (security_alertness * 0.05)
	
	if not action_data.get("stealth", true):
		discovery_chance += 0.2
	
	if randf() < discovery_chance:
		stealth_maintained = false
		investigation_discovered = true
		_increase_security_alertness(3)
		investigation_compromised.emit("careless_action")

func _increase_security_alertness(amount: int) -> void:
	security_alertness = mini(security_alertness + amount, 5)
	security_alert_raised.emit(security_alertness)

func _check_investigation_completion() -> void:
	var collected_required: int = 0
	for evidence_type in required_evidence_types:
		if evidence_collected.has(evidence_type):
			collected_required += 1
	
	if collected_required >= required_evidence_count:
		_complete_investigation()

func _complete_investigation() -> void:
	# Calculate quality bonus based on evidence
	var quality_bonus: float = _calculate_evidence_quality_bonus()
	var stealth_bonus: float = 1.0
	if stealth_maintained:
		stealth_bonus = objective_parameters.get("stealth_bonus", 1.3)
	
	var final_reward: int = roundi(reward_credits * quality_bonus * stealth_bonus)
	reward_credits = final_reward
	
	var _result: Dictionary = super.complete_mission()

func _complete_investigation_success() -> void:
	var evidence_quality_bonus: float = _calculate_evidence_quality_bonus()
	var stealth_bonus: float = 1.0 if security_alertness == 0 else 0.8
	var final_reward: int = roundi(reward_credits * evidence_quality_bonus * stealth_bonus)
	
	reward_credits = final_reward
	
	var _result: Dictionary = super.complete_mission()

func _calculate_evidence_quality_bonus() -> float:
	if evidence_collected.is_empty():
		return 0.8
	
	var total_quality: float = 0.0
	for evidence in evidence_collected.values():
		match evidence.quality:
			"excellent": total_quality += 1.4
			"good", "reliable": total_quality += 1.2
			"standard": total_quality += 1.0
			_: total_quality += 0.8
	
	var average_quality: float = total_quality / evidence_collected.size()
	return clampf(average_quality, 0.8, 1.4)

func complete_mission() -> Dictionary:
	# Mark mission as completed
	print("Investigation mission completed for: %s" % target_organization)
	return super.complete_mission()

func _complete_mission_internal() -> void:
	# Mark mission as completed
	print("Investigation mission completed for: %s" % target_organization)

func has(property: String) -> bool:
	# Simple property check for objectives
	return property == "objectives"