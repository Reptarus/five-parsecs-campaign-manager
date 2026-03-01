@tool
class_name Pirates
extends "res://src/core/enemy/base/Enemy.gd"

## Pirates Enemy Type for Five Parsecs Campaign Manager
##
## Implements opportunistic space pirates with aggressive tactics, scavenged equipment,
## and hit-and-run behavior using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Pirate specific data
@export var crew_experience: String = "green" # green, seasoned, veteran, legendary
@export var ship_quality: String = "scavenged" # scavenged, modified, custom, flagship
@export var loot_obsession: int = 3 # 1-5, affects tactical decisions
@export var loyalty_level: int = 2 # 1-5, affects morale and desertion risk
@export var reputation: String = "unknown" # unknown, feared, notorious, legendary

# Pirate behavior modifiers
@export var greed_factor: float = 1.2 # Multiplier for loot-focused actions
@export var cowardice_threshold: int = 25 # Health % when retreat becomes likely
@export var aggression_bonus: int = 1 # Bonus to aggressive actions
@export var scavenging_skill: int = 2 # Ability to find and use improvised equipment

# Pirate crew dynamics
enum PirateClan {
	INDEPENDENT = 0,
	CRIMSON_FLEET = 1,
	VOID_REAPERS = 2,
	STAR_WOLVES = 3,
	BLOOD_TIDE = 4
}

var clan_affiliation: PirateClan = PirateClan.INDEPENDENT
var has_ship_support: bool = false
var contraband_cargo: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	_setup_pirate()

## Initialize pirate with specific parameters
func initialize_pirate(pirate_data: Dictionary) -> void:
	# Set pirate-specific properties
	crew_experience = pirate_data.get("crew_experience", "green")
	ship_quality = pirate_data.get("ship_quality", "scavenged")
	loot_obsession = pirate_data.get("loot_obsession", 3)
	loyalty_level = pirate_data.get("loyalty_level", 2)
	reputation = pirate_data.get("reputation", "unknown")
	has_ship_support = pirate_data.get("ship_support", false)
	
	# Set clan affiliation
	var clan_name: String = pirate_data.get("clan", "independent")
	clan_affiliation = _parse_clan_affiliation(clan_name)
	
	# Set AI behavior to AGGRESSIVE (typical pirate approach)
	if behavior != EnemyTacticalAI.AIPersonality.AGGRESSIVE:
		behavior = EnemyTacticalAI.AIPersonality.AGGRESSIVE
	
	# Apply pirate modifications
	_apply_pirate_modifiers()
	
	# Generate contraband cargo
	_generate_contraband_cargo()

## Get pirate-specific combat modifiers
func get_pirate_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Aggressive nature and loot focus
	modifiers["aggression_bonus"] = aggression_bonus
	modifiers["loot_priority"] = true
	modifiers["hit_and_run_tactics"] = true
	
	# Experience affects combat performance
	match crew_experience:
		"green":
			modifiers["experience_penalty"] = -1
			modifiers["panic_prone"] = true
		"seasoned":
			modifiers["experience_modifier"] = 0
		"veteran":
			modifiers["experience_bonus"] = 1
			modifiers["boarding_expertise"] = true
		"legendary":
			modifiers["experience_bonus"] = 2
			modifiers["pirate_legend"] = true
			modifiers["intimidation_factor"] = 2
	
	# Ship quality affects support and equipment
	match ship_quality:
		"scavenged":
			modifiers["equipment_unreliable"] = true
			modifiers["improvised_repairs"] = true
		"modified":
			modifiers["custom_modifications"] = true
		"custom":
			modifiers["superior_systems"] = true
			modifiers["ship_weapons"] = true
		"flagship":
			modifiers["fleet_support"] = true
			modifiers["command_ship"] = true
			modifiers["heavy_weapons"] = true
	
	# Clan affiliation provides specific bonuses
	modifiers.merge(_get_clan_modifiers())
	
	# Ship support affects tactical options
	if has_ship_support:
		modifiers["orbital_support"] = true
		modifiers["extraction_available"] = true
		modifiers["supply_drops"] = true
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Pirate priorities
	context["loot_obsession"] = loot_obsession
	context["greed_factor"] = greed_factor
	context["cowardice_threshold"] = cowardice_threshold
	
	# Crew dynamics
	context["loyalty_level"] = loyalty_level
	context["reputation"] = reputation
	context["crew_experience"] = crew_experience
	
	# Tactical preferences
	context["prefer_ambush"] = true
	context["avoid_fair_fights"] = true
	context["target_weak_first"] = true
	context["retreat_when_losing"] = true
	
	# Equipment and support
	context["improvised_equipment"] = true
	context["scavenging_opportunities"] = scavenging_skill
	context["ship_support_available"] = has_ship_support
	
	return context

## Get pirate deployment preferences
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Pirates prefer ambush and surprise tactics
	preferences["formation"] = "ambush_positions"
	preferences["movement_pattern"] = "hit_and_run"
	preferences["positioning"] = "concealed_advantageous"
	
	# Equipment preferences
	preferences["cover_utilization"] = "opportunistic"
	preferences["technology_usage"] = "improvised"
	preferences["coordination_level"] = "loose"
	
	# Clan-specific deployment preferences
	match clan_affiliation:
		PirateClan.CRIMSON_FLEET:
			preferences["formation"] = "assault_waves"
			preferences["aggression_level"] = "high"
		PirateClan.VOID_REAPERS:
			preferences["formation"] = "terror_tactics"
			preferences["intimidation_focus"] = true
		PirateClan.STAR_WOLVES:
			preferences["formation"] = "pack_hunting"
			preferences["coordinated_strikes"] = true
		PirateClan.BLOOD_TIDE:
			preferences["formation"] = "berserker_charge"
			preferences["reckless_assault"] = true
	
	return preferences

## Process pirate morale and loyalty check
func check_pirate_morale(situation_context: Dictionary) -> Dictionary:
	var morale_result: Dictionary = {
		"morale_status": "holding",
		"loyalty_change": 0,
		"action_taken": "continue_fighting"
	}
	
	var current_health_percent: float = float(_current_health) / float(_max_health) * 100.0
	var loot_available: bool = situation_context.get("loot_present", false)
	var crew_casualties: int = situation_context.get("crew_casualties", 0)
	var enemy_strength: int = situation_context.get("enemy_strength", 3)
	
	# Health-based morale check
	if current_health_percent <= cowardice_threshold:
		var retreat_chance: float = (cowardice_threshold - current_health_percent) / 100.0
		retreat_chance *= (6 - loyalty_level) / 5.0 # Higher loyalty = less likely to retreat
		
		if randf() < retreat_chance:
			morale_result.morale_status = "retreating"
			morale_result.action_taken = "tactical_withdrawal"
	
	# Loot obsession affects morale
	if loot_available and loot_obsession >= 4:
		morale_result.loyalty_change += 1
		morale_result.morale_status = "motivated"
	
	# Casualties affect loyalty
	if crew_casualties > 2:
		morale_result.loyalty_change -= crew_casualties
		if loyalty_level + morale_result.loyalty_change <= 1:
			morale_result.action_taken = "desertion"
	
	# Overwhelming enemy strength
	if enemy_strength >= 6 and crew_experience in ["green", "seasoned"]:
		morale_result.morale_status = "intimidated"
		if randf() < 0.3:
			morale_result.action_taken = "surrender"
	
	return morale_result

## Get pirate loot generation preferences
func get_pirate_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"credits": _calculate_pirate_wealth(),
		"contraband": contraband_cargo,
		"equipment": _get_pirate_equipment_drops(),
		"ship_parts": _get_ship_component_drops(),
		"information": _get_pirate_intelligence()
	}
	
	return loot_table

## Handle pirate-specific events during combat
func process_pirate_event(event_type: String, event_data: Dictionary) -> Dictionary:
	var response: Dictionary = {"success": false, "effect": "none"}
	
	match event_type:
		"boarding_action":
			response = _process_boarding_action(event_data)
		"ship_support_call":
			response = _process_ship_support(event_data)
		"loot_opportunity":
			response = _process_loot_opportunity(event_data)
		"intimidation_attempt":
			response = _process_intimidation(event_data)
		"improvised_repair":
			response = _process_field_repair(event_data)
	
	return response

## Private Methods

func _setup_pirate() -> void:
	enemy_name = "Pirate"
	
	# Set pirate default stats (generally lower than professional forces)
	_max_health = 70 # Tough but not military-trained
	_current_health = _max_health
	movement_range = 5 # Mobile and fast
	weapon_range = 4 # Variable scavenged weapons
	
	# Pirate characteristics
	greed_factor = 1.2
	cowardice_threshold = 25
	aggression_bonus = 1
	scavenging_skill = 2

func _apply_pirate_modifiers() -> void:
	# Experience affects base capabilities
	match crew_experience:
		"green":
			_max_health = roundi(_max_health * 0.8)
			loyalty_level = maxi(loyalty_level - 1, 1)
		"seasoned":
			# No modifier - baseline
			pass
		"veteran":
			_max_health = roundi(_max_health * 1.2)
			aggression_bonus += 1
			scavenging_skill += 1
		"legendary":
			_max_health = roundi(_max_health * 1.4)
			aggression_bonus += 2
			scavenging_skill += 2
			loyalty_level = mini(loyalty_level + 1, 5)
	
	# Ship quality affects equipment and support
	match ship_quality:
		"scavenged":
			# Equipment penalties but better scavenging
			weapon_range -= 1
			scavenging_skill += 1
		"modified":
			# Balanced improvements
			movement_range += 1
		"custom":
			# Superior performance
			_max_health = roundi(_max_health * 1.1)
			weapon_range += 1
			movement_range += 1
		"flagship":
			# Command ship bonuses
			_max_health = roundi(_max_health * 1.3)
			weapon_range += 2
			loyalty_level = mini(loyalty_level + 2, 5)
	
	# Reputation affects morale and intimidation
	match reputation:
		"feared":
			aggression_bonus += 1
			loyalty_level += 1
		"notorious":
			aggression_bonus += 2
			loyalty_level += 1
		"legendary":
			aggression_bonus += 3
			loyalty_level += 2
			cowardice_threshold -= 10 # More willing to fight to the death
	
	_current_health = _max_health

func _parse_clan_affiliation(clan_name: String) -> PirateClan:
	match clan_name.to_lower():
		"crimson_fleet": return PirateClan.CRIMSON_FLEET
		"void_reapers": return PirateClan.VOID_REAPERS
		"star_wolves": return PirateClan.STAR_WOLVES
		"blood_tide": return PirateClan.BLOOD_TIDE
		_: return PirateClan.INDEPENDENT

func _get_clan_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	match clan_affiliation:
		PirateClan.CRIMSON_FLEET:
			modifiers["crimson_fleet_tactics"] = true
			modifiers["fleet_coordination"] = true
			modifiers["assault_specialists"] = true
		PirateClan.VOID_REAPERS:
			modifiers["terror_tactics"] = true
			modifiers["psychological_warfare"] = true
			modifiers["intimidation_bonus"] = 2
		PirateClan.STAR_WOLVES:
			modifiers["pack_tactics"] = true
			modifiers["coordinated_hunting"] = true
			modifiers["flanking_bonus"] = 1
		PirateClan.BLOOD_TIDE:
			modifiers["berserker_rage"] = true
			modifiers["pain_resistance"] = true
			modifiers["reckless_courage"] = true
		PirateClan.INDEPENDENT:
			modifiers["self_reliant"] = true
			modifiers["improvisation_bonus"] = 1
	
	return modifiers

func _generate_contraband_cargo() -> void:
	contraband_cargo.clear()
	
	# Number of contraband items based on experience and ship quality
	var cargo_count: int = 1
	if crew_experience in ["veteran", "legendary"]:
		cargo_count += 1
	if ship_quality in ["custom", "flagship"]:
		cargo_count += 1
	
	var possible_contraband: Array[Dictionary] = [
		{"type": "weapons", "name": "Illegal Weapons Cache", "value": 800, "danger": 2},
		{"type": "drugs", "name": "Combat Stimulants", "value": 500, "danger": 1},
		{"type": "slaves", "name": "Indentured Workers", "value": 1200, "danger": 3},
		{"type": "stolen_tech", "name": "Corporate Prototypes", "value": 1500, "danger": 3},
		{"type": "information", "name": "Blackmail Material", "value": 600, "danger": 2},
		{"type": "artifacts", "name": "Alien Relics", "value": 2000, "danger": 1}
	]
	
	for i in range(cargo_count):
		if not possible_contraband.is_empty():
			var item: Dictionary = possible_contraband[randi() % possible_contraband.size()]
			contraband_cargo.append(item)
			possible_contraband.erase(item)

func _calculate_pirate_wealth() -> int:
	var base_credits: int = 100
	
	# Experience affects wealth
	match crew_experience:
		"green": base_credits = 50
		"seasoned": base_credits = 100
		"veteran": base_credits = 200
		"legendary": base_credits = 400
	
	# Ship quality affects available funds
	match ship_quality:
		"scavenged": base_credits = roundi(base_credits * 0.7)
		"modified": base_credits = roundi(base_credits * 1.0)
		"custom": base_credits = roundi(base_credits * 1.5)
		"flagship": base_credits = roundi(base_credits * 2.0)
	
	return base_credits

func _get_pirate_equipment_drops() -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	
	# Scavenged weapons (variable quality)
	drops.append({
		"type": "weapon",
		"name": "Pirate Weapon",
		"quality": "scavenged",
		"condition": "variable",
		"chance": 0.7
	})
	
	# Improvised armor
	drops.append({
		"type": "armor",
		"name": "Improvised Armor",
		"quality": "makeshift",
		"chance": 0.4
	})
	
	# Loot from previous raids
	if loot_obsession >= 3:
		drops.append({
			"type": "treasure",
			"name": "Pirate Loot",
			"value": randi() % 300 + 100,
			"chance": 0.3
		})
	
	return drops

func _get_ship_component_drops() -> Array[Dictionary]:
	var ship_drops: Array[Dictionary] = []
	
	if has_ship_support:
		ship_drops.append({
			"type": "ship_part",
			"name": "Salvaged Ship Component",
			"quality": ship_quality,
			"chance": 0.2
		})
	
	# Navigation data
	ship_drops.append({
		"type": "data",
		"name": "Star Charts",
		"value": 150,
		"chance": 0.3
	})
	
	return ship_drops

func _get_pirate_intelligence() -> Array[Dictionary]:
	var intel: Array[Dictionary] = []
	
	# Trade route information
	intel.append({
		"type": "trade_routes",
		"name": "Shipping Lane Data",
		"value": 200,
		"chance": 0.4
	})
	
	# Hideout locations
	if clan_affiliation != PirateClan.INDEPENDENT:
		intel.append({
			"type": "locations",
			"name": "Pirate Base Coordinates",
			"value": 500,
			"chance": 0.2
		})
	
	return intel

func _process_boarding_action(event_data: Dictionary) -> Dictionary:
	var success_chance: float = 0.3
	
	# Experience affects boarding success
	match crew_experience:
		"veteran": success_chance += 0.2
		"legendary": success_chance += 0.4
	
	# Clan specialization
	if clan_affiliation == PirateClan.CRIMSON_FLEET:
		success_chance += 0.3
	
	return {"success": randf() < success_chance, "effect": "boarding_attempt"}

func _process_ship_support(event_data: Dictionary) -> Dictionary:
	if not has_ship_support:
		return {"success": false, "effect": "no_support_available"}
	
	var support_type: String = event_data.get("support_type", "covering_fire")
	return {"success": true, "effect": support_type}

func _process_loot_opportunity(event_data: Dictionary) -> Dictionary:
	var loot_value: int = event_data.get("loot_value", 100)
	var success_chance: float = 0.5 + (scavenging_skill * 0.1)
	
	if randf() < success_chance:
		return {"success": true, "effect": "loot_acquired", "value": loot_value}
	else:
		return {"success": false, "effect": "loot_missed"}

func _process_intimidation(event_data: Dictionary) -> Dictionary:
	var intimidation_bonus: int = 0
	
	match reputation:
		"feared": intimidation_bonus += 1
		"notorious": intimidation_bonus += 2
		"legendary": intimidation_bonus += 3
	
	var success_chance: float = 0.3 + (intimidation_bonus * 0.15)
	return {"success": randf() < success_chance, "effect": "intimidation"}

func _process_field_repair(event_data: Dictionary) -> Dictionary:
	var repair_skill: float = scavenging_skill * 0.2
	var success_chance: float = 0.4 + repair_skill
	
	if randf() < success_chance:
		var heal_amount: int = randi() % 20 + 10
		heal(heal_amount)
		return {"success": true, "effect": "emergency_repair", "healing": heal_amount}
	else:
		return {"success": false, "effect": "repair_failed"}