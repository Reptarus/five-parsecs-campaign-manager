@tool
class_name CorporateSecurity
extends "res://src/core/enemy/base/Enemy.gd"

## Corporate Security Enemy Type for Five Parsecs Campaign Manager
##
## Implements professional corporate security forces with coordinated tactics,
## standard equipment, and disciplined behavior using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Corporate Security specific data
@export var security_clearance: String = "standard" # standard, high, executive
@export var corporate_affiliation: String = "generic" # generic, mining, tech, pharma, military
@export var equipment_quality: String = "standard" # basic, standard, advanced, prototype
@export var backup_available: bool = true
@export var communication_link: bool = true

# Tactical behavior modifiers
@export var coordination_bonus: int = 1 # Bonus when working with other corporate units
@export var discipline_level: int = 3 # 1-5, affects morale and tactical decisions
@export var threat_assessment_skill: int = 2 # How well they evaluate threats

# Load corporate equipment data from JSON
static var _equipment_cache: Dictionary = {}
static var _equipment_loaded: bool = false

# Corporate security behavior patterns
enum SecurityProtocol {
	PERIMETER_PATROL = 0,
	FACILITY_DEFENSE = 1,
	VIP_PROTECTION = 2,
	ASSET_RECOVERY = 3,
	THREAT_ELIMINATION = 4
}

var current_protocol: SecurityProtocol = SecurityProtocol.FACILITY_DEFENSE

func _ready() -> void:
	super._ready()
	_setup_corporate_security()

## Initialize corporate security with specific parameters
func initialize_corporate_security(security_data: Dictionary) -> void:
	# Set corporate-specific properties
	security_clearance = security_data.get("security_clearance", "standard")
	corporate_affiliation = security_data.get("corporate_affiliation", "generic")
	equipment_quality = security_data.get("equipment_quality", "standard")
	backup_available = security_data.get("backup_available", true)
	communication_link = security_data.get("communication_link", true)
	
	# Load corporate equipment
	_load_corporate_equipment()
	
	# Set AI behavior to TACTICAL (coordinated professional approach)
	if behavior != EnemyTacticalAI.AIPersonality.TACTICAL:
		behavior = EnemyTacticalAI.AIPersonality.TACTICAL
	
	# Apply corporate modifications
	_apply_corporate_modifiers()
	
	# Set current protocol based on mission context
	_determine_security_protocol(security_data)

## Get corporate security specific combat modifiers
func get_corporate_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Coordination bonus with other corporate units
	modifiers["coordination_bonus"] = coordination_bonus
	modifiers["professional_training"] = true
	
	# Equipment quality affects performance
	match equipment_quality:
		"basic":
			modifiers["equipment_penalty"] = -1
		"standard":
			modifiers["equipment_modifier"] = 0
		"advanced":
			modifiers["equipment_bonus"] = 1
			modifiers["targeting_systems"] = true
		"prototype":
			modifiers["equipment_bonus"] = 2
			modifiers["advanced_systems"] = true
			modifiers["shield_technology"] = true
	
	# Communication link provides tactical advantages
	if communication_link:
		modifiers["tactical_network"] = true
		modifiers["shared_intelligence"] = true
		modifiers["call_for_backup"] = backup_available
	
	# Security clearance affects access and equipment
	match security_clearance:
		"high":
			modifiers["clearance_bonus"] = 1
			modifiers["advanced_protocols"] = true
		"executive":
			modifiers["clearance_bonus"] = 2
			modifiers["executive_protection"] = true
			modifiers["unlimited_resources"] = true
	
	# Corporate affiliation provides specialized bonuses
	modifiers.merge(_get_affiliation_modifiers())
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Current security protocol affects behavior
	context["current_protocol"] = current_protocol
	context["discipline_level"] = discipline_level
	context["threat_assessment"] = threat_assessment_skill
	
	# Professional equipment and training
	context["professional_grade"] = true
	context["equipment_reliability"] = _get_equipment_reliability()
	
	# Communication and backup
	context["networked"] = communication_link
	context["backup_eta"] = 3 if backup_available else 0 # Turns until backup arrives
	
	# Corporate priorities
	context["asset_protection_priority"] = true
	context["minimize_collateral_damage"] = true
	context["follow_engagement_protocols"] = true
	
	return context

## Get enemy deployment preferences for corporate security
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Preferred formation based on protocol
	match current_protocol:
		SecurityProtocol.PERIMETER_PATROL:
			preferences["formation"] = "patrol_line"
			preferences["movement_pattern"] = "systematic_sweep"
		SecurityProtocol.FACILITY_DEFENSE:
			preferences["formation"] = "defensive_positions"
			preferences["movement_pattern"] = "hold_ground"
		SecurityProtocol.VIP_PROTECTION:
			preferences["formation"] = "protective_circle"
			preferences["movement_pattern"] = "escort_formation"
		SecurityProtocol.ASSET_RECOVERY:
			preferences["formation"] = "assault_teams"
			preferences["movement_pattern"] = "coordinated_advance"
		SecurityProtocol.THREAT_ELIMINATION:
			preferences["formation"] = "combat_squads"
			preferences["movement_pattern"] = "search_and_destroy"
	
	# Equipment deployment preferences
	preferences["cover_utilization"] = "high"
	preferences["technology_usage"] = "maximum"
	preferences["coordination_level"] = "professional"
	
	return preferences

## Get loot table specific to corporate security
func get_corporate_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"credits": _calculate_corporate_pay(),
		"equipment": _get_corporate_equipment_drops(),
		"information": _get_corporate_data_drops(),
		"special_items": _get_corporate_special_drops()
	}
	
	return loot_table

## Handle corporate security communication protocols
func process_communication_event(event_type: String, data: Dictionary) -> Dictionary:
	var response: Dictionary = {"acknowledged": false, "action_taken": "none"}
	
	if not communication_link:
		return response
	
	match event_type:
		"backup_request":
			if backup_available:
				response.acknowledged = true
				response.action_taken = "backup_dispatched"
				response.eta = 3
		"threat_alert":
			response.acknowledged = true
			response.action_taken = "threat_assessment"
			threat_assessment_skill += 1 # Improved awareness
		"protocol_change":
			var new_protocol: String = data.get("protocol", "facility_defense")
			_change_security_protocol(new_protocol)
			response.acknowledged = true
			response.action_taken = "protocol_updated"
		"status_report":
			response.acknowledged = true
			response.action_taken = "status_transmitted"
			response.data = _compile_status_report()
	
	return response

## Private Methods

## Enemy type data loaded from res://data/enemy_type_details.json
static var _type_data: Dictionary = {}
static var _type_loaded: bool = false

static func _load_type_data() -> Dictionary:
	if not _type_loaded:
		_type_loaded = true
		var file := FileAccess.open("res://data/enemy_type_details.json", FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				_type_data = json.data
			file.close()
	return _type_data.get("corporate_security", {})

func _setup_corporate_security() -> void:
	enemy_name = "Corporate Security"
	var cfg: Dictionary = _load_type_data()
	var stats: Dictionary = cfg.get("base_stats", {})

	_max_health = int(stats.get("max_health", 80))
	_current_health = _max_health
	movement_range = int(stats.get("movement_range", 4))
	weapon_range = int(stats.get("weapon_range", 6))

	discipline_level = int(stats.get("discipline_level", 3))
	threat_assessment_skill = int(stats.get("threat_assessment_skill", 2))
	coordination_bonus = int(stats.get("coordination_bonus", 1))

func _load_corporate_equipment() -> void:
	if _equipment_loaded:
		return
	
	# Load from existing enemy data
	var enemy_data_file = load("res://data/enemy_types.json")
	if enemy_data_file:
		var enemy_data = enemy_data_file.data if enemy_data_file.has_method("get_data") else enemy_data_file
		
		# Extract corporate security equipment
		for category in enemy_data.get("enemy_categories", []):
			if category.id == "corporate_security":
				for enemy in category.get("enemies", []):
					_equipment_cache[enemy.id] = enemy.equipment
	
	_equipment_loaded = true

func _apply_corporate_modifiers() -> void:
	# Equipment quality affects base stats
	match equipment_quality:
		"basic":
			_max_health = roundi(_max_health * 0.8)
			weapon_range -= 1
		"advanced":
			_max_health = roundi(_max_health * 1.2)
			weapon_range += 1
			discipline_level += 1
		"prototype":
			_max_health = roundi(_max_health * 1.4)
			weapon_range += 2
			discipline_level += 2
			threat_assessment_skill += 1
	
	# Security clearance affects capabilities
	match security_clearance:
		"high":
			coordination_bonus += 1
			threat_assessment_skill += 1
		"executive":
			coordination_bonus += 2
			threat_assessment_skill += 2
			discipline_level += 1
	
	# Corporate affiliation bonuses
	match corporate_affiliation:
		"military":
			discipline_level += 2
			_max_health = roundi(_max_health * 1.3)
		"tech":
			threat_assessment_skill += 2
			weapon_range += 1
		"pharma":
			# Access to combat drugs and medical support
			coordination_bonus += 1
		"mining":
			# Rugged equipment and tough personnel
			_max_health = roundi(_max_health * 1.1)
			discipline_level += 1
	
	_current_health = _max_health

func _determine_security_protocol(context: Dictionary) -> void:
	var mission_type: String = context.get("mission_type", "facility_defense")
	var threat_level: int = context.get("threat_level", 2)
	var asset_priority: String = context.get("asset_priority", "standard")
	
	match mission_type:
		"perimeter_sweep": current_protocol = SecurityProtocol.PERIMETER_PATROL
		"facility_defense": current_protocol = SecurityProtocol.FACILITY_DEFENSE
		"vip_escort": current_protocol = SecurityProtocol.VIP_PROTECTION
		"asset_recovery": current_protocol = SecurityProtocol.ASSET_RECOVERY
		"threat_elimination": current_protocol = SecurityProtocol.THREAT_ELIMINATION
		_: current_protocol = SecurityProtocol.FACILITY_DEFENSE
	
	# High threat levels may override standard protocols
	if threat_level >= 4:
		current_protocol = SecurityProtocol.THREAT_ELIMINATION

func _get_affiliation_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	match corporate_affiliation:
		"military":
			modifiers["military_training"] = true
			modifiers["advanced_tactics"] = true
			modifiers["weapon_proficiency"] = 2
		"tech":
			modifiers["sensor_systems"] = true
			modifiers["electronic_warfare"] = true
			modifiers["hacking_resistance"] = 2
		"pharma":
			modifiers["bio_enhancement"] = true
			modifiers["combat_stims"] = true
			modifiers["toxin_resistance"] = 1
		"mining":
			modifiers["heavy_equipment"] = true
			modifiers["environmental_protection"] = true
			modifiers["demolitions_access"] = true
		"generic":
			modifiers["standard_procedures"] = true
	
	return modifiers

func _get_equipment_reliability() -> float:
	match equipment_quality:
		"basic": return 0.7
		"standard": return 0.85
		"advanced": return 0.95
		"prototype": return 0.9 # High performance but occasionally unreliable
		_: return 0.85

func _change_security_protocol(protocol_name: String) -> void:
	match protocol_name:
		"perimeter_patrol": current_protocol = SecurityProtocol.PERIMETER_PATROL
		"facility_defense": current_protocol = SecurityProtocol.FACILITY_DEFENSE
		"vip_protection": current_protocol = SecurityProtocol.VIP_PROTECTION
		"asset_recovery": current_protocol = SecurityProtocol.ASSET_RECOVERY
		"threat_elimination": current_protocol = SecurityProtocol.THREAT_ELIMINATION

func _calculate_corporate_pay() -> int:
	var base_pay: int = 150
	
	# Security clearance affects pay grade
	match security_clearance:
		"standard": base_pay = 150
		"high": base_pay = 300
		"executive": base_pay = 500
	
	# Corporate affiliation modifier
	match corporate_affiliation:
		"military", "tech": base_pay = roundi(base_pay * 1.3)
		"pharma": base_pay = roundi(base_pay * 1.2)
		"mining": base_pay = roundi(base_pay * 1.1)
	
	return base_pay

func _get_corporate_equipment_drops() -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	
	# Standard corporate equipment
	drops.append({
		"type": "weapon",
		"name": "Corporate Combat Rifle",
		"quality": equipment_quality,
		"chance": 0.6
	})
	
	drops.append({
		"type": "armor",
		"name": "Corporate Security Armor",
		"quality": equipment_quality,
		"chance": 0.4
	})
	
	# Communication equipment
	if communication_link:
		drops.append({
			"type": "tech",
			"name": "Corporate Comm Device",
			"quality": equipment_quality,
			"chance": 0.3
		})
	
	# Clearance-specific drops
	if security_clearance in ["high", "executive"]:
		drops.append({
			"type": "access",
			"name": "Security Clearance Card",
			"quality": security_clearance,
			"chance": 0.2
		})
	
	return drops

func _get_corporate_data_drops() -> Array[Dictionary]:
	var data_drops: Array[Dictionary] = []
	
	# Corporate intelligence based on clearance
	match security_clearance:
		"standard":
			data_drops.append({
				"type": "data",
				"name": "Patrol Schedules",
				"value": 100,
				"chance": 0.3
			})
		"high":
			data_drops.append({
				"type": "data",
				"name": "Security Protocols",
				"value": 300,
				"chance": 0.4
			})
		"executive":
			data_drops.append({
				"type": "data",
				"name": "Corporate Secrets",
				"value": 800,
				"chance": 0.2
			})
	
	return data_drops

func _get_corporate_special_drops() -> Array[Dictionary]:
	var special_drops: Array[Dictionary] = []
	
	# Affiliation-specific special items
	match corporate_affiliation:
		"tech":
			special_drops.append({
				"type": "prototype",
				"name": "Experimental Tech Module",
				"value": 1000,
				"chance": 0.1
			})
		"pharma":
			special_drops.append({
				"type": "enhancement",
				"name": "Combat Stimulant",
				"value": 500,
				"chance": 0.15
			})
		"military":
			special_drops.append({
				"type": "weapon",
				"name": "Military-Grade Equipment",
				"value": 1200,
				"chance": 0.08
			})
	
	return special_drops

func _compile_status_report() -> Dictionary:
	return {
		"health_status": float(_current_health) / float(_max_health),
		"equipment_status": _get_equipment_reliability(),
		"threat_assessment": threat_assessment_skill,
		"protocol": current_protocol,
		"communication_status": communication_link,
		"backup_availability": backup_available
	}