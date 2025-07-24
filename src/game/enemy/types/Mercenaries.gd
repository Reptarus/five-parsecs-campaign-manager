@tool
class_name Mercenaries
extends "res://src/core/enemy/base/Enemy.gd"

## Mercenaries Enemy Type for Five Parsecs Campaign Manager
##
## Implements professional soldiers-for-hire with contract-based motivation,
## varied expertise, and economic pragmatism using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Mercenary specific data
@export var experience_level: String = "regular" # green, regular, veteran, elite, legendary
@export var specialization: String = "infantry" # infantry, heavy_weapons, support, recon, assault
@export var contract_type: String = "standard" # standard, high_value, suicide, personal, revenge
@export var employer_type: String = "corporate" # corporate, government, criminal, independent, unknown
@export var reputation_rating: int = 3 # 1-5, affects contract availability and pay

# Professional characteristics
@export var equipment_quality: String = "standard" # basic, standard, military, prototype, exotic
@export var unit_cohesion: int = 3 # 1-5, how well the unit works together
@export var contract_loyalty: int = 3 # 1-5, dedication to completing the contract
@export var pragmatism_level: int = 4 # 1-5, willingness to retreat when contract becomes unprofitable

# Contract and payment mechanics
@export var base_contract_value: int = 1000
@export var hazard_pay_multiplier: float = 1.0
@export var success_bonus: int = 500
@export var payment_received: int = 0
@export var completion_threshold: float = 0.7 # Contract completion required for payment

# Unit structure and support
enum MercenaryUnit {
	SOLO_OPERATOR = 0,
	FIRE_TEAM = 1,
	SQUAD = 2,
	COMPANY = 3,
	BATTALION = 4
}

var unit_size: MercenaryUnit = MercenaryUnit.FIRE_TEAM
var command_structure: bool = true # Professional command hierarchy
var support_available: bool = false # Medical, technical, or fire support

func _ready() -> void:
	super._ready()
	_setup_mercenary()

## Initialize mercenary with contract and unit data
func initialize_mercenary(mercenary_data: Dictionary) -> void:
	# Set mercenary-specific properties
	experience_level = mercenary_data.get("experience_level", "regular")
	specialization = mercenary_data.get("specialization", "infantry")
	contract_type = mercenary_data.get("contract_type", "standard")
	employer_type = mercenary_data.get("employer_type", "corporate")
	reputation_rating = mercenary_data.get("reputation_rating", 3)
	
	# Professional characteristics
	equipment_quality = mercenary_data.get("equipment_quality", "standard")
	unit_cohesion = mercenary_data.get("unit_cohesion", 3)
	contract_loyalty = mercenary_data.get("contract_loyalty", 3)
	pragmatism_level = mercenary_data.get("pragmatism_level", 4)
	
	# Contract terms
	base_contract_value = mercenary_data.get("contract_value", 1000)
	hazard_pay_multiplier = mercenary_data.get("hazard_pay", 1.0)
	success_bonus = mercenary_data.get("success_bonus", 500)
	completion_threshold = mercenary_data.get("completion_threshold", 0.7)
	
	# Unit information
	var unit_size_name: String = mercenary_data.get("unit_size", "fire_team")
	unit_size = _parse_unit_size(unit_size_name)
	command_structure = mercenary_data.get("command_structure", true)
	support_available = mercenary_data.get("support_available", false)
	
	# Set AI behavior to TACTICAL (professional military approach)
	if behavior != EnemyTacticalAI.AIBehavior.TACTICAL:
		behavior = EnemyTacticalAI.AIBehavior.TACTICAL
	
	# Apply mercenary modifications
	_apply_mercenary_modifiers()

## Get mercenary-specific combat modifiers
func get_mercenary_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Experience level affects all combat capabilities
	match experience_level:
		"green":
			modifiers["experience_penalty"] = -1
			modifiers["morale_fragile"] = true
		"regular":
			modifiers["professional_training"] = true
		"veteran":
			modifiers["experience_bonus"] = 1
			modifiers["combat_expertise"] = true
		"elite":
			modifiers["experience_bonus"] = 2
			modifiers["elite_training"] = true
			modifiers["tactical_superiority"] = 1
		"legendary":
			modifiers["experience_bonus"] = 3
			modifiers["legendary_reputation"] = true
			modifiers["fear_inducing"] = 1
			modifiers["tactical_superiority"] = 2
	
	# Specialization provides tactical advantages
	match specialization:
		"infantry":
			modifiers["versatile_combatants"] = true
			modifiers["urban_warfare"] = 1
		"heavy_weapons":
			modifiers["heavy_weapons_specialist"] = true
			modifiers["area_suppression"] = 2
			modifiers["anti_armor"] = true
		"support":
			modifiers["medical_training"] = true
			modifiers["equipment_maintenance"] = true
			modifiers["communication_expert"] = true
		"recon":
			modifiers["stealth_expertise"] = 2
			modifiers["intelligence_gathering"] = true
			modifiers["marksman_training"] = 1
		"assault":
			modifiers["breaching_specialist"] = true
			modifiers["close_quarters_combat"] = 2
			modifiers["aggressive_tactics"] = 1
	
	# Equipment quality affects performance
	match equipment_quality:
		"basic":
			modifiers["equipment_penalty"] = -1
		"military":
			modifiers["military_grade_equipment"] = 1
			modifiers["reliability_bonus"] = true
		"prototype":
			modifiers["prototype_equipment"] = 2
			modifiers["technological_advantage"] = true
		"exotic":
			modifiers["exotic_equipment"] = 3
			modifiers["unique_capabilities"] = true
	
	# Unit cohesion affects coordination
	if unit_cohesion >= 4:
		modifiers["unit_coordination"] = unit_cohesion - 2
		modifiers["mutual_support"] = true
	
	# Command structure provides tactical bonuses
	if command_structure:
		modifiers["professional_command"] = true
		modifiers["tactical_flexibility"] = 1
	
	# Support availability
	if support_available:
		modifiers["support_assets"] = true
		modifiers["force_multiplier"] = 1
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Professional soldier characteristics
	context["professional_military"] = true
	context["contract_based_motivation"] = true
	context["pragmatic_approach"] = pragmatism_level >= 3
	
	# Contract considerations
	context["contract_type"] = contract_type
	context["employer_relationship"] = employer_type
	context["payment_dependent"] = true
	context["completion_threshold"] = completion_threshold
	
	# Unit characteristics
	context["unit_cohesion"] = unit_cohesion
	context["command_structure"] = command_structure
	context["experience_level"] = experience_level
	context["specialization"] = specialization
	
	# Economic factors
	context["contract_value"] = base_contract_value
	context["hazard_pay_active"] = hazard_pay_multiplier > 1.0
	context["success_bonus_available"] = success_bonus > 0
	
	# Professional reputation concerns
	context["reputation_matters"] = reputation_rating >= 3
	context["career_considerations"] = true
	
	return context

## Get mercenary deployment preferences
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Unit size affects deployment strategy
	match unit_size:
		MercenaryUnit.SOLO_OPERATOR:
			preferences["formation"] = "independent_operation"
			preferences["self_reliance"] = true
		MercenaryUnit.FIRE_TEAM:
			preferences["formation"] = "fire_team_tactics"
			preferences["mutual_support"] = true
		MercenaryUnit.SQUAD:
			preferences["formation"] = "squad_tactics"
			preferences["layered_defense"] = true
		MercenaryUnit.COMPANY:
			preferences["formation"] = "combined_arms"
			preferences["overwhelming_force"] = true
		MercenaryUnit.BATTALION:
			preferences["formation"] = "military_operation"
			preferences["strategic_deployment"] = true
	
	# Specialization affects positioning
	match specialization:
		"infantry":
			preferences["flexible_positioning"] = true
			preferences["adaptable_tactics"] = true
		"heavy_weapons":
			preferences["fire_support_positions"] = true
			preferences["area_denial"] = true
		"support":
			preferences["protected_rear_position"] = true
			preferences["support_role"] = true
		"recon":
			preferences["forward_observation"] = true
			preferences["concealed_positions"] = true
		"assault":
			preferences["breach_positions"] = true
			preferences["rapid_assault"] = true
	
	# Experience affects tactical sophistication
	if experience_level in ["veteran", "elite", "legendary"]:
		preferences["advanced_tactics"] = true
		preferences["tactical_coordination"] = true
	
	return preferences

## Process contract evaluation and motivation
func evaluate_contract_status(situation_context: Dictionary) -> Dictionary:
	var evaluation: Dictionary = {
		"contract_status": "active",
		"motivation_level": contract_loyalty,
		"recommended_action": "continue_mission",
		"payment_concerns": false
	}
	
	var mission_progress: float = situation_context.get("mission_progress", 0.5)
	var casualty_rate: float = situation_context.get("casualty_rate", 0.0)
	var enemy_strength: int = situation_context.get("enemy_strength", 3)
	var contract_complications: int = situation_context.get("complications", 0)
	
	# Calculate contract viability
	var viability_score: float = float(contract_loyalty)
	
	# Mission progress affects motivation
	if mission_progress >= completion_threshold:
		viability_score += 1.0
		evaluation.recommended_action = "complete_contract"
	elif mission_progress < 0.3:
		viability_score -= 1.0
	
	# Casualty rate affects willingness to continue
	if casualty_rate > 0.5:
		viability_score -= 2.0
		evaluation.payment_concerns = true
	elif casualty_rate > 0.25:
		viability_score -= 1.0
	
	# Enemy strength vs expected opposition
	if enemy_strength > (reputation_rating + 2):
		viability_score -= 1.5 # Facing stronger opposition than contracted for
		evaluation.payment_concerns = true
	
	# Contract complications
	viability_score -= contract_complications * 0.5
	
	# Pragmatism overrides loyalty when situation becomes untenable
	if pragmatism_level >= 4 and viability_score <= 1.0:
		evaluation.contract_status = "breach_consideration"
		evaluation.recommended_action = "negotiate_withdrawal"
	elif viability_score <= 0.5:
		evaluation.contract_status = "breach_imminent"
		evaluation.recommended_action = "tactical_withdrawal"
	
	# High-value contracts have different thresholds
	if contract_type == "high_value":
		viability_score += 1.0 # More willing to take risks
	elif contract_type == "suicide":
		viability_score -= 0.5 # Expected to be dangerous
	
	evaluation.motivation_level = clampf(viability_score, 0.0, 5.0)
	
	return evaluation

## Calculate contract payment and bonuses
func calculate_contract_payment(completion_context: Dictionary) -> Dictionary:
	var payment: Dictionary = {
		"base_pay": 0,
		"hazard_pay": 0,
		"success_bonus": 0,
		"reputation_bonus": 0,
		"total_payment": 0
	}
	
	var mission_success: bool = completion_context.get("mission_success", false)
	var completion_percentage: float = completion_context.get("completion_percentage", 0.0)
	var hazards_encountered: int = completion_context.get("hazards_encountered", 0)
	var exceptional_performance: bool = completion_context.get("exceptional_performance", false)
	
	# Base payment (prorated by completion)
	if completion_percentage >= completion_threshold:
		payment.base_pay = base_contract_value
	else:
		payment.base_pay = roundi(base_contract_value * completion_percentage)
	
	# Hazard pay for dangers encountered
	if hazards_encountered > 0:
		payment.hazard_pay = roundi(payment.base_pay * (hazard_pay_multiplier - 1.0))
	
	# Success bonus for mission completion
	if mission_success and completion_percentage >= completion_threshold:
		payment.success_bonus = success_bonus
	
	# Reputation bonus for exceptional performance
	if exceptional_performance:
		payment.reputation_bonus = roundi(payment.base_pay * 0.2)
	
	payment.total_payment = payment.base_pay + payment.hazard_pay + payment.success_bonus + payment.reputation_bonus
	
	return payment

## Get mercenary loot table with professional equipment
func get_mercenary_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"credits": _calculate_mercenary_wealth(),
		"military_equipment": _get_military_equipment_drops(),
		"contract_information": _get_contract_intelligence(),
		"professional_gear": _get_professional_gear_drops(),
		"reputation_items": _get_reputation_items()
	}
	
	return loot_table

## Private Methods

func _setup_mercenary() -> void:
	enemy_name = "Mercenary"
	
	# Mercenaries are professional soldiers with good equipment
	_max_health = 80
	_current_health = _max_health
	movement_range = 4
	weapon_range = 6 # Professional military weapons
	
	# Professional characteristics
	unit_cohesion = 3
	contract_loyalty = 3
	pragmatism_level = 4

func _apply_mercenary_modifiers() -> void:
	# Experience level dramatically affects capabilities
	match experience_level:
		"green":
			_max_health = roundi(_max_health * 0.8)
			weapon_range -= 1
			unit_cohesion = maxi(unit_cohesion - 1, 1)
		"regular":
			# Baseline - no modifier
			pass
		"veteran":
			_max_health = roundi(_max_health * 1.2)
			weapon_range += 1
			unit_cohesion = mini(unit_cohesion + 1, 5)
		"elite":
			_max_health = roundi(_max_health * 1.4)
			weapon_range += 2
			movement_range += 1
			unit_cohesion = mini(unit_cohesion + 2, 5)
		"legendary":
			_max_health = roundi(_max_health * 1.6)
			weapon_range += 3
			movement_range += 2
			unit_cohesion = 5
			contract_loyalty = mini(contract_loyalty + 1, 5)
	
	# Specialization affects stats
	match specialization:
		"infantry":
			# Balanced - no specific modifier
			pass
		"heavy_weapons":
			_max_health += 10
			weapon_range += 2
			movement_range -= 1
		"support":
			_max_health -= 10
			# Support specialists are less combat-focused
		"recon":
			movement_range += 2
			weapon_range += 1
			_max_health -= 5
		"assault":
			_max_health += 15
			movement_range += 1
	
	# Equipment quality affects base capabilities
	match equipment_quality:
		"basic":
			_max_health = roundi(_max_health * 0.9)
			weapon_range -= 1
		"military":
			_max_health = roundi(_max_health * 1.1)
			weapon_range += 1
		"prototype":
			_max_health = roundi(_max_health * 1.2)
			weapon_range += 2
			movement_range += 1
		"exotic":
			_max_health = roundi(_max_health * 1.3)
			weapon_range += 3
			movement_range += 1
	
	# Unit size affects individual capability
	match unit_size:
		MercenaryUnit.SOLO_OPERATOR:
			# Solo operators are more self-reliant
			_max_health += 10
			pragmatism_level = mini(pragmatism_level + 1, 5)
		MercenaryUnit.BATTALION:
			# Large units have better support
			unit_cohesion = mini(unit_cohesion + 1, 5)
			support_available = true
	
	# Contract type affects motivation and equipment
	match contract_type:
		"high_value":
			contract_loyalty = mini(contract_loyalty + 1, 5)
			equipment_quality = "military" if equipment_quality == "standard" else equipment_quality
		"suicide":
			# Suicide missions pay well but are dangerous
			pragmatism_level = maxi(pragmatism_level - 1, 1)
		"personal":
			contract_loyalty = mini(contract_loyalty + 2, 5)
		"revenge":
			contract_loyalty = 5 # Personal vengeance overrides pragmatism
			pragmatism_level = maxi(pragmatism_level - 2, 1)
	
	_current_health = _max_health

func _parse_unit_size(size_name: String) -> MercenaryUnit:
	match size_name.to_lower():
		"solo_operator": return MercenaryUnit.SOLO_OPERATOR
		"fire_team": return MercenaryUnit.FIRE_TEAM
		"squad": return MercenaryUnit.SQUAD
		"company": return MercenaryUnit.COMPANY
		"battalion": return MercenaryUnit.BATTALION
		_: return MercenaryUnit.FIRE_TEAM

func _calculate_mercenary_wealth() -> int:
	var base_credits: int = 300 # Professional soldiers are well-paid
	
	# Experience affects personal wealth
	match experience_level:
		"green": base_credits = 150
		"regular": base_credits = 300
		"veteran": base_credits = 500
		"elite": base_credits = 800
		"legendary": base_credits = 1200
	
	# Contract type affects current payment
	match contract_type:
		"high_value": base_credits = roundi(base_credits * 1.5)
		"suicide": base_credits = roundi(base_credits * 2.0)
		"personal": base_credits = roundi(base_credits * 1.2)
	
	# Add partial contract payment
	base_credits += payment_received
	
	return base_credits

func _get_military_equipment_drops() -> Array[Dictionary]:
	var equipment: Array[Dictionary] = []
	
	# Professional weapons
	equipment.append({
		"type": "weapon",
		"name": "Military Weapon",
		"quality": equipment_quality,
		"condition": "excellent",
		"chance": 0.8
	})
	
	# Military armor
	equipment.append({
		"type": "armor",
		"name": "Combat Armor",
		"quality": equipment_quality,
		"condition": "good",
		"chance": 0.6
	})
	
	# Specialization-specific equipment
	match specialization:
		"heavy_weapons":
			equipment.append({
				"type": "weapon",
				"name": "Heavy Weapon System",
				"quality": "military",
				"value": 2000,
				"chance": 0.3
			})
		"recon":
			equipment.append({
				"type": "equipment",
				"name": "Reconnaissance Gear",
				"quality": "military",
				"value": 800,
				"chance": 0.4
			})
		"support":
			equipment.append({
				"type": "equipment",
				"name": "Medical Kit",
				"quality": "military",
				"value": 600,
				"chance": 0.5
			})
	
	return equipment

func _get_contract_intelligence() -> Array[Dictionary]:
	var intel: Array[Dictionary] = []
	
	# Contract details
	intel.append({
		"type": "contract",
		"name": "Mercenary Contract",
		"employer": employer_type,
		"value": 200,
		"chance": 0.4
	})
	
	# Employer information
	if employer_type != "unknown":
		intel.append({
			"type": "intelligence",
			"name": employer_type.capitalize() + " Intelligence",
			"value": 400,
			"chance": 0.3
		})
	
	# High-reputation mercenaries have valuable contacts
	if reputation_rating >= 4:
		intel.append({
			"type": "contacts",
			"name": "Professional Network",
			"value": reputation_rating * 200,
			"chance": 0.2
		})
	
	return intel

func _get_professional_gear_drops() -> Array[Dictionary]:
	var gear: Array[Dictionary] = []
	
	# Communication equipment
	if unit_size >= MercenaryUnit.SQUAD:
		gear.append({
			"type": "communication",
			"name": "Military Comm System",
			"quality": "professional",
			"value": 500,
			"chance": 0.3
		})
	
	# Support equipment
	if support_available:
		gear.append({
			"type": "support",
			"name": "Support Equipment Cache",
			"variety": "mixed",
			"value": 700,
			"chance": 0.2
		})
	
	return gear

func _get_reputation_items() -> Array[Dictionary]:
	var reputation_items: Array[Dictionary] = []
	
	# High-reputation mercenaries carry valuable items
	if reputation_rating >= 4:
		reputation_items.append({
			"type": "trophy",
			"name": "Combat Trophy",
			"reputation_value": reputation_rating * 100,
			"chance": 0.3
		})
	
	# Elite and legendary mercenaries have unique items
	if experience_level in ["elite", "legendary"]:
		reputation_items.append({
			"type": "unique",
			"name": "Personal Equipment",
			"quality": "unique",
			"value": 1500,
			"chance": 0.15
		})
	
	return reputation_items