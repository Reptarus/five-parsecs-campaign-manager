@tool
class_name Enforcers
extends "res://src/core/enemy/base/Enemy.gd"

## Enforcers Enemy Type for Five Parsecs Campaign Manager
##
## Implements law enforcement and security forces with authority-based tactics,
## legal constraints, and escalation protocols using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Enforcer specific data
@export var authority_level: int = 3 # 1-5, legal jurisdiction and power
@export var enforcement_type: String = "police" # police, security, marshal, military_police, special_forces
@export var jurisdiction: String = "local" # local, planetary, system, sector, federal
@export var legal_mandate: String = "arrest" # patrol, arrest, investigate, suppress, eliminate
@export var corruption_level: int = 1 # 0-5, how corrupt the enforcer is

# Equipment and training
@export var training_quality: String = "standard" # basic, standard, advanced, elite, special
@export var equipment_authorization: String = "standard" # limited, standard, enhanced, military, unrestricted
@export var backup_response_time: int = 5 # Turns until reinforcements arrive
@export var surveillance_access: int = 3 # 1-5, information gathering capability

# Legal and procedural constraints
@export var rules_of_engagement: String = "standard" # lenient, standard, strict, martial, no_limits
@export var evidence_requirements: bool = true # Must gather evidence for arrests
@export var civilian_protection: int = 4 # 1-5, priority placed on civilian safety
@export var escalation_authority: int = 2 # 1-5, ability to authorize force escalation

# Operational status
enum EnforcementStatus {
	PATROL = 0,
	INVESTIGATION = 1,
	PURSUIT = 2,
	ARREST_OPERATION = 3,
	RIOT_SUPPRESSION = 4,
	TACTICAL_RESPONSE = 5
}

var current_status: EnforcementStatus = EnforcementStatus.PATROL
var warrant_active: bool = false
var evidence_collected: int = 0
var required_evidence: int = 3

func _ready() -> void:
	super._ready()
	_setup_enforcer()

## Initialize enforcer with jurisdiction and mandate data
func initialize_enforcer(enforcer_data: Dictionary) -> void:
	# Set enforcer-specific properties
	authority_level = enforcer_data.get("authority_level", 3)
	enforcement_type = enforcer_data.get("enforcement_type", "police")
	jurisdiction = enforcer_data.get("jurisdiction", "local")
	legal_mandate = enforcer_data.get("legal_mandate", "arrest")
	corruption_level = enforcer_data.get("corruption_level", 1)
	
	# Equipment and training
	training_quality = enforcer_data.get("training_quality", "standard")
	equipment_authorization = enforcer_data.get("equipment_authorization", "standard")
	backup_response_time = enforcer_data.get("backup_response_time", 5)
	surveillance_access = enforcer_data.get("surveillance_access", 3)
	
	# Legal constraints
	rules_of_engagement = enforcer_data.get("rules_of_engagement", "standard")
	evidence_requirements = enforcer_data.get("evidence_requirements", true)
	civilian_protection = enforcer_data.get("civilian_protection", 4)
	escalation_authority = enforcer_data.get("escalation_authority", 2)
	
	# Operational status
	var status_name: String = enforcer_data.get("current_status", "patrol")
	current_status = _parse_enforcement_status(status_name)
	warrant_active = enforcer_data.get("warrant_active", false)
	
	# Set AI behavior based on enforcement type and mandate
	_set_enforcer_ai_behavior()
	
	# Apply enforcer modifications
	_apply_enforcer_modifiers()

## Get enforcer-specific combat modifiers
func get_enforcer_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Authority level affects intimidation and resources
	modifiers["authority_bonus"] = authority_level - 3 # -2 to +2
	modifiers["legal_authority"] = authority_level
	modifiers["intimidation_legal"] = authority_level
	
	# Enforcement type provides specialized capabilities
	match enforcement_type:
		"police":
			modifiers["crowd_control"] = true
			modifiers["arrest_procedures"] = true
			modifiers["community_knowledge"] = 1
		"security":
			modifiers["facility_knowledge"] = true
			modifiers["access_control"] = true
			modifiers["surveillance_systems"] = 1
		"marshal":
			modifiers["frontier_experience"] = true
			modifiers["independent_operation"] = true
			modifiers["tracking_expertise"] = 2
		"military_police":
			modifiers["military_training"] = 2
			modifiers["discipline_enforcement"] = true
			modifiers["combat_procedures"] = 1
		"special_forces":
			modifiers["elite_training"] = 3
			modifiers["tactical_superiority"] = 2
			modifiers["special_equipment"] = true
	
	# Training quality affects combat effectiveness
	match training_quality:
		"basic":
			modifiers["training_penalty"] = -1
		"advanced":
			modifiers["training_bonus"] = 1
			modifiers["tactical_training"] = true
		"elite":
			modifiers["training_bonus"] = 2
			modifiers["elite_procedures"] = true
		"special":
			modifiers["training_bonus"] = 3
			modifiers["special_operations"] = true
	
	# Equipment authorization affects available gear
	match equipment_authorization:
		"limited":
			modifiers["equipment_restriction"] = -1
		"enhanced":
			modifiers["enhanced_equipment"] = 1
		"military":
			modifiers["military_equipment"] = 2
		"unrestricted":
			modifiers["unrestricted_arsenal"] = 3
	
	# Current operational status affects tactics
	match current_status:
		EnforcementStatus.PATROL:
			modifiers["patrol_awareness"] = 1
		EnforcementStatus.INVESTIGATION:
			modifiers["evidence_focus"] = true
			modifiers["non_lethal_preference"] = 1
		EnforcementStatus.PURSUIT:
			modifiers["pursuit_tactics"] = true
			modifiers["capture_priority"] = 2
		EnforcementStatus.ARREST_OPERATION:
			modifiers["arrest_procedures"] = true
			modifiers["minimum_force"] = true
		EnforcementStatus.RIOT_SUPPRESSION:
			modifiers["crowd_control"] = 2
			modifiers["area_denial"] = true
		EnforcementStatus.TACTICAL_RESPONSE:
			modifiers["tactical_response"] = 2
			modifiers["force_authorized"] = true
	
	# Legal constraints affect behavior
	if evidence_requirements:
		modifiers["evidence_preservation"] = true
		modifiers["witness_protection"] = true
	
	if civilian_protection >= 4:
		modifiers["civilian_safety_priority"] = civilian_protection - 2
		modifiers["collateral_damage_concern"] = true
	
	# Corruption affects rule adherence
	if corruption_level >= 3:
		modifiers["rule_flexibility"] = corruption_level - 2
		modifiers["bribery_susceptible"] = true
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Legal and procedural framework
	context["legal_authority"] = authority_level
	context["jurisdiction_active"] = true
	context["warrant_status"] = warrant_active
	context["evidence_required"] = evidence_requirements
	
	# Operational parameters
	context["current_mandate"] = legal_mandate
	context["rules_of_engagement"] = rules_of_engagement
	context["civilian_protection_priority"] = civilian_protection
	context["escalation_authorized"] = escalation_authority >= 3
	
	# Support and resources
	context["backup_available"] = backup_response_time <= 10
	context["surveillance_network"] = surveillance_access >= 3
	context["equipment_restrictions"] = equipment_authorization in ["limited", "standard"]
	
	# Behavioral constraints
	context["corruption_influence"] = corruption_level
	context["procedure_adherence"] = 5 - corruption_level
	context["public_accountability"] = enforcement_type != "special_forces"
	
	# Mission-specific context
	context["enforcement_status"] = current_status
	context["evidence_gathering"] = current_status == EnforcementStatus.INVESTIGATION
	context["arrest_priority"] = current_status == EnforcementStatus.ARREST_OPERATION
	
	return context

## Get enforcer deployment preferences
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Enforcement type affects deployment strategy
	match enforcement_type:
		"police":
			preferences["formation"] = "patrol_units"
			preferences["community_integration"] = true
		"security":
			preferences["formation"] = "checkpoint_control"
			preferences["facility_defense"] = true
		"marshal":
			preferences["formation"] = "independent_operation"
			preferences["frontier_tactics"] = true
		"military_police":
			preferences["formation"] = "military_formation"
			preferences["disciplined_approach"] = true
		"special_forces":
			preferences["formation"] = "tactical_teams"
			preferences["special_operations"] = true
	
	# Current status affects positioning
	match current_status:
		EnforcementStatus.PATROL:
			preferences["visibility"] = "high"
			preferences["mobility"] = "standard"
		EnforcementStatus.INVESTIGATION:
			preferences["visibility"] = "low"
			preferences["evidence_preservation"] = true
		EnforcementStatus.PURSUIT:
			preferences["mobility"] = "high"
			preferences["containment_focus"] = true
		EnforcementStatus.ARREST_OPERATION:
			preferences["containment"] = "priority"
			preferences["escape_prevention"] = true
		EnforcementStatus.RIOT_SUPPRESSION:
			preferences["formation"] = "crowd_control_line"
			preferences["area_control"] = true
		EnforcementStatus.TACTICAL_RESPONSE:
			preferences["formation"] = "assault_teams"
			preferences["overwhelming_force"] = true
	
	# Authority level affects approach
	if authority_level >= 4:
		preferences["command_presence"] = true
		preferences["resource_priority"] = true
	
	return preferences

## Process legal procedures and evidence gathering
func process_legal_procedure(procedure_type: String, procedure_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "legal_status": "pending"}
	
	match procedure_type:
		"evidence_collection":
			result = _process_evidence_collection(procedure_data)
		"witness_interview":
			result = _process_witness_interview(procedure_data)
		"warrant_execution":
			result = _process_warrant_execution(procedure_data)
		"arrest_attempt":
			result = _process_arrest_attempt(procedure_data)
		"rights_violation":
			result = _process_rights_violation(procedure_data)
	
	return result

## Process backup and reinforcement calls
func call_for_backup(backup_type: String, urgency: int) -> Dictionary:
	var backup_response: Dictionary = {
		"backup_dispatched": false,
		"estimated_arrival": backup_response_time,
		"backup_type": "none",
		"authority_escalation": false
	}
	
	# Authority level affects backup availability
	var authority_modifier: int = authority_level - 3
	var adjusted_response_time: int = maxi(backup_response_time + authority_modifier, 1)
	
	match backup_type:
		"patrol_support":
			if authority_level >= 2:
				backup_response.backup_dispatched = true
				backup_response.backup_type = "patrol_units"
				backup_response.estimated_arrival = adjusted_response_time
		
		"tactical_team":
			if authority_level >= 3 and escalation_authority >= 3:
				backup_response.backup_dispatched = true
				backup_response.backup_type = "tactical_response"
				backup_response.estimated_arrival = adjusted_response_time + 2
				backup_response.authority_escalation = true
		
		"special_forces":
			if authority_level >= 4 and escalation_authority >= 4:
				backup_response.backup_dispatched = true
				backup_response.backup_type = "special_operations"
				backup_response.estimated_arrival = adjusted_response_time + 5
				backup_response.authority_escalation = true
		
		"federal_support":
			if jurisdiction in ["sector", "federal"] and authority_level >= 4:
				backup_response.backup_dispatched = true
				backup_response.backup_type = "federal_agents"
				backup_response.estimated_arrival = adjusted_response_time + 10
				backup_response.authority_escalation = true
	
	# Urgency affects response time
	if urgency >= 4:
		backup_response.estimated_arrival = maxi(backup_response.estimated_arrival - 2, 1)
	
	return backup_response

## Get enforcer loot table with official equipment
func get_enforcer_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"credits": _calculate_enforcer_resources(),
		"official_equipment": _get_official_equipment_drops(),
		"evidence_data": _get_evidence_drops(),
		"authority_items": _get_authority_items(),
		"surveillance_data": _get_surveillance_intelligence()
	}
	
	return loot_table

## Private Methods

func _setup_enforcer() -> void:
	enemy_name = "Enforcer"
	
	# Enforcers have good training and equipment
	_max_health = 75
	_current_health = _max_health
	movement_range = 4
	weapon_range = 5 # Professional law enforcement weapons
	
	# Professional law enforcement characteristics
	backup_response_time = 5
	surveillance_access = 3
	civilian_protection = 4

func _set_enforcer_ai_behavior() -> void:
	# Set AI behavior based on current mandate and status
	match legal_mandate:
		"patrol", "investigate":
			behavior = EnemyTacticalAI.AIBehavior.CAUTIOUS
		"arrest":
			behavior = EnemyTacticalAI.AIBehavior.TACTICAL
		"suppress":
			behavior = EnemyTacticalAI.AIBehavior.DEFENSIVE
		"eliminate":
			behavior = EnemyTacticalAI.AIBehavior.AGGRESSIVE
	
	# Special forces always use tactical approach
	if enforcement_type == "special_forces":
		behavior = EnemyTacticalAI.AIBehavior.TACTICAL

func _apply_enforcer_modifiers() -> void:
	# Authority level affects base capabilities
	_max_health += authority_level * 5
	weapon_range += (authority_level - 3) # Higher authority = better weapons
	
	# Enforcement type affects specialization
	match enforcement_type:
		"police":
			# Balanced approach
			civilian_protection = mini(civilian_protection + 1, 5)
		"security":
			# Facility-focused
			surveillance_access = mini(surveillance_access + 1, 5)
		"marshal":
			# Independent frontier operations
			_max_health += 10
			backup_response_time += 3 # Longer backup times on frontier
		"military_police":
			# Military training
			_max_health += 15
			weapon_range += 1
			civilian_protection = maxi(civilian_protection - 1, 1)
		"special_forces":
			# Elite capabilities
			_max_health += 25
			weapon_range += 2
			movement_range += 1
			escalation_authority = mini(escalation_authority + 2, 5)
	
	# Training quality affects stats
	match training_quality:
		"basic":
			_max_health = roundi(_max_health * 0.9)
		"advanced":
			_max_health = roundi(_max_health * 1.1)
			backup_response_time = maxi(backup_response_time - 1, 1)
		"elite":
			_max_health = roundi(_max_health * 1.2)
			weapon_range += 1
			backup_response_time = maxi(backup_response_time - 2, 1)
		"special":
			_max_health = roundi(_max_health * 1.3)
			weapon_range += 2
			movement_range += 1
			backup_response_time = maxi(backup_response_time - 3, 1)
	
	# Equipment authorization affects capabilities
	match equipment_authorization:
		"limited":
			weapon_range = maxi(weapon_range - 1, 2)
		"enhanced":
			weapon_range += 1
		"military":
			_max_health += 10
			weapon_range += 2
		"unrestricted":
			_max_health += 20
			weapon_range += 3
			movement_range += 1
	
	# Jurisdiction affects resources and backup
	match jurisdiction:
		"local":
			# Limited resources
			backup_response_time += 2
		"planetary":
			# Standard resources
			pass
		"system":
			# Enhanced resources
			backup_response_time = maxi(backup_response_time - 1, 1)
			surveillance_access = mini(surveillance_access + 1, 5)
		"sector", "federal":
			# Maximum resources
			backup_response_time = maxi(backup_response_time - 2, 1)
			surveillance_access = mini(surveillance_access + 2, 5)
			authority_level = mini(authority_level + 1, 5)
	
	_current_health = _max_health

func _parse_enforcement_status(status_name: String) -> EnforcementStatus:
	match status_name.to_lower():
		"patrol": return EnforcementStatus.PATROL
		"investigation": return EnforcementStatus.INVESTIGATION
		"pursuit": return EnforcementStatus.PURSUIT
		"arrest_operation": return EnforcementStatus.ARREST_OPERATION
		"riot_suppression": return EnforcementStatus.RIOT_SUPPRESSION
		"tactical_response": return EnforcementStatus.TACTICAL_RESPONSE
		_: return EnforcementStatus.PATROL

func _process_evidence_collection(procedure_data: Dictionary) -> Dictionary:
	var evidence_quality: int = procedure_data.get("evidence_quality", 2)
	var collection_skill: int = surveillance_access + training_quality_to_int()
	
	if collection_skill >= evidence_quality:
		evidence_collected += 1
		return {"success": true, "legal_status": "evidence_secured"}
	else:
		return {"success": false, "legal_status": "insufficient_evidence"}

func _process_witness_interview(procedure_data: Dictionary) -> Dictionary:
	var witness_cooperation: int = procedure_data.get("cooperation", 3)
	var authority_modifier: int = authority_level + (5 - corruption_level)
	
	if authority_modifier >= witness_cooperation:
		return {"success": true, "legal_status": "testimony_obtained"}
	else:
		return {"success": false, "legal_status": "witness_uncooperative"}

func _process_warrant_execution(procedure_data: Dictionary) -> Dictionary:
	if not warrant_active:
		return {"success": false, "legal_status": "no_warrant"}
	
	var execution_difficulty: int = procedure_data.get("difficulty", 3)
	var execution_capability: int = authority_level + escalation_authority
	
	if execution_capability >= execution_difficulty:
		return {"success": true, "legal_status": "warrant_executed"}
	else:
		return {"success": false, "legal_status": "warrant_execution_failed"}

func _process_arrest_attempt(procedure_data: Dictionary) -> Dictionary:
	var target_resistance: int = procedure_data.get("resistance", 3)
	var arrest_capability: int = authority_level + training_quality_to_int()
	
	# Evidence requirements affect arrest legality
	if evidence_requirements and evidence_collected < required_evidence:
		return {"success": false, "legal_status": "insufficient_evidence_for_arrest"}
	
	if arrest_capability >= target_resistance:
		return {"success": true, "legal_status": "arrest_successful"}
	else:
		return {"success": false, "legal_status": "arrest_resisted"}

func _process_rights_violation(procedure_data: Dictionary) -> Dictionary:
	var violation_severity: int = procedure_data.get("severity", 2)
	var accountability_level: int = 5 - corruption_level
	
	if accountability_level >= violation_severity:
		return {"success": false, "legal_status": "procedure_violation"}
	else:
		# Corruption allows rights violations
		return {"success": true, "legal_status": "violation_overlooked"}

func training_quality_to_int() -> int:
	match training_quality:
		"basic": return 1
		"standard": return 2
		"advanced": return 3
		"elite": return 4
		"special": return 5
		_: return 2

func _calculate_enforcer_resources() -> int:
	var base_credits: int = 200
	
	# Authority level affects available resources
	base_credits += authority_level * 100
	
	# Jurisdiction affects funding
	match jurisdiction:
		"local": base_credits = roundi(base_credits * 0.8)
		"planetary": base_credits = roundi(base_credits * 1.0)
		"system": base_credits = roundi(base_credits * 1.3)
		"sector": base_credits = roundi(base_credits * 1.6)
		"federal": base_credits = roundi(base_credits * 2.0)
	
	# Enforcement type affects resources
	match enforcement_type:
		"special_forces": base_credits = roundi(base_credits * 1.5)
		"military_police": base_credits = roundi(base_credits * 1.2)
		"marshal": base_credits = roundi(base_credits * 1.1)
	
	return base_credits

func _get_official_equipment_drops() -> Array[Dictionary]:
	var equipment: Array[Dictionary] = []
	
	# Standard law enforcement equipment
	equipment.append({
		"type": "weapon",
		"name": "Service Weapon",
		"quality": equipment_authorization,
		"official": true,
		"chance": 0.8
	})
	
	equipment.append({
		"type": "armor",
		"name": "Body Armor",
		"quality": equipment_authorization,
		"official": true,
		"chance": 0.6
	})
	
	# Communication equipment
	equipment.append({
		"type": "communication",
		"name": "Official Comm Device",
		"access_level": authority_level,
		"chance": 0.5
	})
	
	# Special equipment for enhanced authorization
	if equipment_authorization in ["enhanced", "military", "unrestricted"]:
		equipment.append({
			"type": "special",
			"name": "Advanced Equipment",
			"authorization": equipment_authorization,
			"value": 800,
			"chance": 0.3
		})
	
	return equipment

func _get_evidence_drops() -> Array[Dictionary]:
	var evidence: Array[Dictionary] = []
	
	# Collected evidence
	if evidence_collected > 0:
		evidence.append({
			"type": "evidence",
			"name": "Case Evidence",
			"quantity": evidence_collected,
			"legal_value": evidence_collected * 100,
			"chance": 1.0
		})
	
	# Surveillance data
	if surveillance_access >= 3:
		evidence.append({
			"type": "surveillance",
			"name": "Surveillance Records",
			"access_level": surveillance_access,
			"value": 300,
			"chance": 0.4
		})
	
	return evidence

func _get_authority_items() -> Array[Dictionary]:
	var authority_items: Array[Dictionary] = []
	
	# Badge/ID
	authority_items.append({
		"type": "identification",
		"name": "Official Badge",
		"authority_level": authority_level,
		"jurisdiction": jurisdiction,
		"value": authority_level * 150,
		"chance": 0.9
	})
	
	# Warrants and legal documents
	if warrant_active:
		authority_items.append({
			"type": "legal_document",
			"name": "Active Warrant",
			"legal_authority": authority_level,
			"value": 200,
			"chance": 0.7
		})
	
	return authority_items

func _get_surveillance_intelligence() -> Array[Dictionary]:
	var intel: Array[Dictionary] = []
	
	# Access to surveillance networks
	if surveillance_access >= 4:
		intel.append({
			"type": "network_access",
			"name": "Surveillance Network Codes",
			"access_level": surveillance_access,
			"value": 600,
			"chance": 0.3
		})
	
	# Federal/sector level intelligence
	if jurisdiction in ["sector", "federal"]:
		intel.append({
			"type": "classified_intel",
			"name": "Official Intelligence",
			"classification": jurisdiction,
			"value": 1000,
			"chance": 0.2
		})
	
	return intel