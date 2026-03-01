@tool
class_name RivalGang
extends "res://src/core/enemy/base/Enemy.gd"

## Rival Gang Enemy Type for Five Parsecs Campaign Manager
##
## Implements organized criminal gangs with crew dynamics, territory control,
## and personal vendetta mechanics using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Rival gang specific data
@export var gang_reputation: int = 3 # 1-5, affects influence and resources
@export var territory_control: int = 2 # 1-5, area of influence
@export var gang_specialization: String = "general" # general, smuggling, enforcement, tech, combat
@export var rivalry_intensity: int = 2 # 1-5, personal hatred level
@export var gang_size: String = "small" # small, medium, large, syndicate

# Gang resources and capabilities
@export var funding_level: int = 3 # 1-5, affects equipment quality
@export var corruption_network: int = 2 # 1-5, law enforcement influence
@export var black_market_access: int = 3 # 1-5, illegal equipment availability
@export var information_network: int = 2 # 1-5, intelligence gathering

# Crew dynamics
@export var loyalty_cohesion: int = 3 # 1-5, how well gang works together
@export var leadership_quality: int = 2 # 1-5, tactical coordination
@export var discipline_level: int = 2 # 1-5, professional behavior

# Personal vendetta tracking
enum VendettaType {
	NONE = 0,
	BUSINESS_RIVALRY = 1,
	PERSONAL_INSULT = 2,
	TERRITORY_DISPUTE = 3,
	BETRAYAL = 4,
	BLOOD_FEUD = 5
}

var vendetta_type: VendettaType = VendettaType.NONE
var vendetta_escalation: int = 0 # Tracks how personal the conflict has become

func _ready() -> void:
	super._ready()
	_setup_rival_gang()

## Initialize rival gang with specific parameters
func initialize_rival_gang(gang_data: Dictionary) -> void:
	# Set gang-specific properties
	gang_reputation = gang_data.get("gang_reputation", 3)
	territory_control = gang_data.get("territory_control", 2)
	gang_specialization = gang_data.get("gang_specialization", "general")
	rivalry_intensity = gang_data.get("rivalry_intensity", 2)
	gang_size = gang_data.get("gang_size", "small")
	
	# Gang capabilities
	funding_level = gang_data.get("funding_level", 3)
	corruption_network = gang_data.get("corruption_network", 2)
	black_market_access = gang_data.get("black_market_access", 3)
	information_network = gang_data.get("information_network", 2)
	
	# Crew dynamics
	loyalty_cohesion = gang_data.get("loyalty_cohesion", 3)
	leadership_quality = gang_data.get("leadership_quality", 2)
	discipline_level = gang_data.get("discipline_level", 2)
	
	# Set vendetta information
	var vendetta_name: String = gang_data.get("vendetta_type", "none")
	vendetta_type = _parse_vendetta_type(vendetta_name)
	vendetta_escalation = gang_data.get("vendetta_escalation", 0)
	
	# Set AI behavior to TACTICAL (organized criminal approach)
	if behavior != EnemyTacticalAI.AIPersonality.TACTICAL:
		behavior = EnemyTacticalAI.AIPersonality.TACTICAL
	
	# Apply gang modifications
	_apply_gang_modifiers()

## Get rival gang specific combat modifiers
func get_gang_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Gang reputation affects intimidation and resources
	modifiers["reputation_bonus"] = gang_reputation - 3 # -2 to +2
	modifiers["intimidation_factor"] = gang_reputation
	
	# Specialization provides combat bonuses
	match gang_specialization:
		"general":
			modifiers["versatile_tactics"] = true
		"smuggling":
			modifiers["escape_routes"] = true
			modifiers["contraband_equipment"] = true
		"enforcement":
			modifiers["combat_expertise"] = 2
			modifiers["intimidation_specialists"] = true
		"tech":
			modifiers["hacking_support"] = true
			modifiers["electronic_warfare"] = true
			modifiers["advanced_equipment"] = 1
		"combat":
			modifiers["weapon_specialists"] = true
			modifiers["tactical_training"] = 2
			modifiers["veteran_fighters"] = true
	
	# Gang size affects numbers and coordination
	match gang_size:
		"small":
			modifiers["tight_coordination"] = 1
			modifiers["personal_loyalty"] = true
		"medium":
			modifiers["balanced_operations"] = true
		"large":
			modifiers["overwhelming_numbers"] = true
			modifiers["resource_abundance"] = 1
		"syndicate":
			modifiers["criminal_empire"] = true
			modifiers["unlimited_resources"] = true
			modifiers["professional_operations"] = 2
	
	# Funding affects equipment quality
	match funding_level:
		1, 2:
			modifiers["budget_equipment"] = -1
		4, 5:
			modifiers["premium_equipment"] = funding_level - 3
	
	# Leadership quality affects coordination
	if leadership_quality >= 4:
		modifiers["tactical_coordination"] = leadership_quality - 2
		modifiers["strategic_planning"] = true
	
	# Vendetta intensity affects motivation
	if vendetta_type != VendettaType.NONE:
		modifiers["vendetta_motivation"] = rivalry_intensity
		modifiers["personal_stakes"] = true
		if rivalry_intensity >= 4:
			modifiers["ruthless_tactics"] = true
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Gang organizational structure
	context["gang_discipline"] = discipline_level
	context["leadership_quality"] = leadership_quality
	context["loyalty_cohesion"] = loyalty_cohesion
	
	# Operational capabilities
	context["funding_level"] = funding_level
	context["black_market_access"] = black_market_access
	context["information_network"] = information_network
	
	# Territorial and reputational concerns
	context["reputation_at_stake"] = gang_reputation >= 3
	context["territorial_defenders"] = territory_control >= 3
	context["corruption_protection"] = corruption_network >= 3
	
	# Vendetta dynamics
	context["personal_vendetta"] = vendetta_type != VendettaType.NONE
	context["vendetta_intensity"] = rivalry_intensity
	context["escalation_level"] = vendetta_escalation
	
	# Specialization tactics
	context["gang_specialization"] = gang_specialization
	context["professional_criminals"] = discipline_level >= 3
	
	return context

## Get rival gang deployment preferences
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Gang size affects deployment strategy
	match gang_size:
		"small":
			preferences["formation"] = "tight_unit"
			preferences["hit_and_run"] = true
		"medium":
			preferences["formation"] = "flexible_squads"
			preferences["adaptable_tactics"] = true
		"large":
			preferences["formation"] = "overwhelming_force"
			preferences["numerical_superiority"] = true
		"syndicate":
			preferences["formation"] = "professional_operation"
			preferences["multi_layered_approach"] = true
	
	# Specialization affects deployment
	match gang_specialization:
		"smuggling":
			preferences["escape_routes"] = "multiple"
			preferences["concealment_priority"] = true
		"enforcement":
			preferences["intimidation_deployment"] = true
			preferences["visible_presence"] = true
		"tech":
			preferences["electronic_support"] = true
			preferences["surveillance_network"] = true
		"combat":
			preferences["combat_formations"] = true
			preferences["weapon_focus"] = true
	
	# Leadership quality affects coordination
	if leadership_quality >= 4:
		preferences["coordinated_assault"] = true
		preferences["tactical_flexibility"] = true
	
	return preferences

## Process gang loyalty and morale mechanics
func check_gang_loyalty(situation_context: Dictionary) -> Dictionary:
	var loyalty_result: Dictionary = {
		"loyalty_status": "holding",
		"morale_change": 0,
		"defection_risk": 0.0,
		"action_taken": "continue_mission"
	}
	
	var casualties: int = situation_context.get("gang_casualties", 0)
	var mission_success: bool = situation_context.get("mission_going_well", true)
	var leadership_alive: bool = situation_context.get("leadership_alive", true)
	var pay_promised: int = situation_context.get("promised_pay", 500)
	
	# Base loyalty check
	var loyalty_score: float = loyalty_cohesion
	
	# Leadership affects loyalty
	if not leadership_alive:
		loyalty_score -= 2.0
		loyalty_result.morale_change -= 2
	elif leadership_quality >= 4:
		loyalty_score += 1.0
	
	# Mission success affects morale
	if not mission_success:
		loyalty_score -= 1.0
		loyalty_result.morale_change -= 1
	
	# Casualties affect loyalty
	if casualties > 0:
		var casualty_impact: float = casualties * 0.5
		loyalty_score -= casualty_impact
		loyalty_result.morale_change -= casualties
	
	# Funding affects loyalty (gang members expect to be paid)
	if funding_level <= 2:
		loyalty_score -= 1.0
		loyalty_result.defection_risk += 0.2
	
	# Vendetta can override normal loyalty concerns
	if vendetta_type != VendettaType.NONE and rivalry_intensity >= 4:
		loyalty_score += 1.0 # Personal stakes increase loyalty
		loyalty_result.morale_change += 1
	
	# Determine final loyalty status
	if loyalty_score <= 1.0:
		loyalty_result.loyalty_status = "breaking"
		loyalty_result.defection_risk = 0.6
		loyalty_result.action_taken = "consider_desertion"
	elif loyalty_score <= 2.0:
		loyalty_result.loyalty_status = "shaky"
		loyalty_result.defection_risk = 0.3
		loyalty_result.action_taken = "demand_better_terms"
	elif loyalty_score >= 5.0:
		loyalty_result.loyalty_status = "fanatical"
		loyalty_result.action_taken = "fight_to_death"
	
	return loyalty_result

## Process vendetta escalation mechanics
func escalate_vendetta(escalation_trigger: String, trigger_data: Dictionary) -> Dictionary:
	var escalation_result: Dictionary = {
		"escalated": false,
		"new_vendetta_level": vendetta_escalation,
		"consequences": []
	}
	
	if vendetta_type == VendettaType.NONE:
		# Create new vendetta
		vendetta_type = _determine_new_vendetta_type(escalation_trigger)
		vendetta_escalation = 1
		escalation_result.escalated = true
		escalation_result.new_vendetta_level = 1
		escalation_result.consequences.append("vendetta_initiated")
	else:
		# Escalate existing vendetta
		var escalation_chance: float = 0.3
		
		match escalation_trigger:
			"crew_member_killed":
				escalation_chance += 0.4
			"reputation_damaged":
				escalation_chance += 0.2
			"territory_violated":
				escalation_chance += 0.3
			"personal_insult":
				escalation_chance += 0.5
			"betrayal":
				escalation_chance += 0.7
		
		# Rivalry intensity affects escalation chance
		escalation_chance += rivalry_intensity * 0.1
		
		if randf() < escalation_chance:
			vendetta_escalation = mini(vendetta_escalation + 1, 5)
			rivalry_intensity = mini(rivalry_intensity + 1, 5)
			escalation_result.escalated = true
			escalation_result.new_vendetta_level = vendetta_escalation
			
			# Escalation consequences
			match vendetta_escalation:
				2:
					escalation_result.consequences.append("increased_aggression")
				3:
					escalation_result.consequences.append("reputation_war")
				4:
					escalation_result.consequences.append("territory_conflict")
				5:
					escalation_result.consequences.append("blood_feud")
	
	return escalation_result

## Get rival gang loot table with criminal resources
func get_gang_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"credits": _calculate_gang_wealth(),
		"criminal_equipment": _get_criminal_equipment_drops(),
		"contraband": _get_contraband_drops(),
		"information": _get_criminal_intelligence(),
		"territory_assets": _get_territory_assets()
	}
	
	return loot_table

## Handle gang-specific events and interactions
func process_gang_event(event_type: String, event_data: Dictionary) -> Dictionary:
	var response: Dictionary = {"success": false, "effect": "none"}
	
	match event_type:
		"corruption_attempt":
			response = _process_corruption_attempt(event_data)
		"information_trade":
			response = _process_information_exchange(event_data)
		"territory_negotiation":
			response = _process_territory_negotiation(event_data)
		"gang_alliance":
			response = _process_alliance_offer(event_data)
		"protection_racket":
			response = _process_protection_scheme(event_data)
	
	return response

## Private Methods

func _setup_rival_gang() -> void:
	enemy_name = "Rival Gang Member"
	
	# Gang members are typically better equipped than common criminals
	_max_health = 70
	_current_health = _max_health
	movement_range = 4
	weapon_range = 5 # Access to better weapons through black market
	
	# Criminal characteristics
	loyalty_cohesion = 3
	leadership_quality = 2
	discipline_level = 2

func _apply_gang_modifiers() -> void:
	# Gang size affects individual member quality
	match gang_size:
		"small":
			# Small gangs have tighter bonds but fewer resources
			loyalty_cohesion += 1
			funding_level = maxi(funding_level - 1, 1)
		"medium":
			# Balanced gang - no modifier
			pass
		"large":
			# Large gangs have more resources but looser bonds
			funding_level += 1
			loyalty_cohesion = maxi(loyalty_cohesion - 1, 1)
		"syndicate":
			# Criminal empire - high quality everything
			funding_level = mini(funding_level + 2, 5)
			discipline_level = mini(discipline_level + 2, 5)
			leadership_quality = mini(leadership_quality + 1, 5)
	
	# Gang reputation affects base capabilities
	_max_health += gang_reputation * 5
	weapon_range += (gang_reputation - 3) # Higher rep = better weapons
	
	# Specialization affects stats
	match gang_specialization:
		"enforcement":
			_max_health += 20
			discipline_level += 1
		"tech":
			movement_range += 1
			weapon_range += 1
		"combat":
			_max_health += 15
			weapon_range += 2
		"smuggling":
			movement_range += 2
	
	# Funding level affects equipment quality
	if funding_level >= 4:
		_max_health += 10
		weapon_range += 1
	elif funding_level <= 2:
		_max_health -= 10
		weapon_range = maxi(weapon_range - 1, 2)
	
	# Leadership quality affects tactical capabilities
	if leadership_quality >= 4:
		discipline_level = mini(discipline_level + 1, 5)
	
	_current_health = _max_health

func _parse_vendetta_type(vendetta_name: String) -> VendettaType:
	match vendetta_name.to_lower():
		"business_rivalry": return VendettaType.BUSINESS_RIVALRY
		"personal_insult": return VendettaType.PERSONAL_INSULT
		"territory_dispute": return VendettaType.TERRITORY_DISPUTE
		"betrayal": return VendettaType.BETRAYAL
		"blood_feud": return VendettaType.BLOOD_FEUD
		_: return VendettaType.NONE

func _determine_new_vendetta_type(trigger: String) -> VendettaType:
	match trigger:
		"crew_member_killed": return VendettaType.BLOOD_FEUD
		"reputation_damaged": return VendettaType.PERSONAL_INSULT
		"territory_violated": return VendettaType.TERRITORY_DISPUTE
		"business_interference": return VendettaType.BUSINESS_RIVALRY
		"trust_broken": return VendettaType.BETRAYAL
		_: return VendettaType.BUSINESS_RIVALRY

func _calculate_gang_wealth() -> int:
	var base_credits: int = 200
	
	# Gang size affects available funds
	match gang_size:
		"small": base_credits = 150
		"medium": base_credits = 300
		"large": base_credits = 500
		"syndicate": base_credits = 1000
	
	# Funding level modifier
	base_credits = roundi(base_credits * (funding_level / 3.0))
	
	# Specialization affects wealth
	match gang_specialization:
		"smuggling": base_credits = roundi(base_credits * 1.3)
		"tech": base_credits = roundi(base_credits * 1.2)
		"enforcement": base_credits = roundi(base_credits * 1.1)
	
	return base_credits

func _get_criminal_equipment_drops() -> Array[Dictionary]:
	var equipment: Array[Dictionary] = []
	
	# Black market weapons
	equipment.append({
		"type": "weapon",
		"name": "Black Market Weapon",
		"quality": _get_equipment_quality(),
		"illegal": true,
		"chance": 0.6
	})
	
	# Gang colors/identification
	equipment.append({
		"type": "clothing",
		"name": "Gang Colors",
		"reputation_value": gang_reputation * 50,
		"chance": 0.8
	})
	
	# Professional equipment for specialized gangs
	if gang_specialization == "tech":
		equipment.append({
			"type": "tech",
			"name": "Hacking Gear",
			"quality": "military",
			"chance": 0.4
		})
	
	return equipment

func _get_contraband_drops() -> Array[Dictionary]:
	var contraband: Array[Dictionary] = []
	
	# Basic contraband based on black market access
	if black_market_access >= 3:
		contraband.append({
			"type": "contraband",
			"name": "Illegal Substances",
			"value": black_market_access * 100,
			"danger_level": 2,
			"chance": 0.4
		})
	
	# Specialization-specific contraband
	match gang_specialization:
		"smuggling":
			contraband.append({
				"type": "contraband",
				"name": "Smuggled Goods",
				"value": 500,
				"danger_level": 1,
				"chance": 0.6
			})
		"tech":
			contraband.append({
				"type": "contraband",
				"name": "Stolen Prototypes",
				"value": 800,
				"danger_level": 3,
				"chance": 0.3
			})
	
	return contraband

func _get_criminal_intelligence() -> Array[Dictionary]:
	var intel: Array[Dictionary] = []
	
	# Information network provides intelligence
	if information_network >= 3:
		intel.append({
			"type": "intelligence",
			"name": "Criminal Network Data",
			"value": information_network * 150,
			"chance": 0.3
		})
	
	# Corruption network information
	if corruption_network >= 3:
		intel.append({
			"type": "intelligence",
			"name": "Corruption Evidence",
			"value": 600,
			"danger_level": 3,
			"chance": 0.2
		})
	
	return intel

func _get_territory_assets() -> Array[Dictionary]:
	var assets: Array[Dictionary] = []
	
	# Territory control provides asset access
	if territory_control >= 3:
		assets.append({
			"type": "property",
			"name": "Territory Claim",
			"value": territory_control * 200,
			"ongoing_income": territory_control * 50,
			"chance": 0.2
		})
	
	# Large gangs have safe houses
	if gang_size in ["large", "syndicate"]:
		assets.append({
			"type": "property",
			"name": "Safe House Access",
			"value": 400,
			"utility": "hideout",
			"chance": 0.15
		})
	
	return assets

func _get_equipment_quality() -> String:
	match funding_level:
		1, 2: return "poor"
		3: return "standard"
		4: return "good"
		5: return "excellent"
		_: return "standard"

func _process_corruption_attempt(event_data: Dictionary) -> Dictionary:
	var corruption_check: int = corruption_network + gang_reputation
	var target_resistance: int = event_data.get("target_resistance", 3)
	
	if corruption_check >= target_resistance:
		return {"success": true, "effect": "corruption_successful"}
	else:
		return {"success": false, "effect": "corruption_failed"}

func _process_information_exchange(event_data: Dictionary) -> Dictionary:
	var info_quality: int = information_network + leadership_quality
	var payment_offered: int = event_data.get("payment", 0)
	
	if payment_offered >= info_quality * 100:
		return {"success": true, "effect": "information_provided", "quality": info_quality}
	else:
		return {"success": false, "effect": "insufficient_payment"}

func _process_territory_negotiation(event_data: Dictionary) -> Dictionary:
	var negotiation_strength: int = gang_reputation + territory_control
	var opponent_strength: int = event_data.get("opponent_strength", 3)
	
	if negotiation_strength > opponent_strength:
		return {"success": true, "effect": "territory_gained"}
	elif negotiation_strength == opponent_strength:
		return {"success": true, "effect": "territory_maintained"}
	else:
		return {"success": false, "effect": "territory_lost"}

func _process_alliance_offer(event_data: Dictionary) -> Dictionary:
	var alliance_value: int = event_data.get("alliance_value", 2)
	var mutual_benefit: bool = event_data.get("mutual_benefit", false)
	
	# Gang reputation affects willingness to ally
	if gang_reputation >= 4 and not mutual_benefit:
		return {"success": false, "effect": "too_proud_to_ally"}
	
	if alliance_value >= 3 or mutual_benefit:
		return {"success": true, "effect": "alliance_accepted"}
	else:
		return {"success": false, "effect": "alliance_rejected"}

func _process_protection_scheme(event_data: Dictionary) -> Dictionary:
	var target_wealth: int = event_data.get("target_wealth", 3)
	var protection_fee: int = gang_reputation * 100
	
	if target_wealth >= protection_fee / 100:
		return {"success": true, "effect": "protection_established", "income": protection_fee}
	else:
		return {"success": false, "effect": "target_too_poor"}