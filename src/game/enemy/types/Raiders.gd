@tool
class_name Raiders
extends "res://src/core/enemy/base/Enemy.gd"

## Raiders Enemy Type for Five Parsecs Campaign Manager
##
## Implements opportunistic bandits and scavengers with hit-and-run tactics,
## survival instincts, and resource desperation using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Raider specific data
@export var desperation_level: int = 3 # 1-5, affects risk-taking and aggression
@export var resource_scarcity: int = 4 # 1-5, how desperate they are for supplies
@export var tribal_affiliation: String = "independent" # independent, wasteland_tribe, scavenger_clan, nomad_band
@export var survival_experience: int = 3 # 1-5, frontier and wasteland survival skills
@export var equipment_condition: String = "poor" # poor, salvaged, functional, modified, jury_rigged

# Raider behavior characteristics
@export var opportunism_factor: float = 1.5 # Multiplier for targeting weak enemies
@export var retreat_threshold: int = 40 # Health % when retreat becomes likely
@export var salvage_priority: int = 4 # 1-5, priority placed on looting
@export var intimidation_tactics: int = 2 # 1-5, use of fear and psychological warfare

# Survival and scavenging
@export var environmental_adaptation: Array[String] = ["wasteland"] # wasteland, desert, arctic, toxic, radioactive
@export var scavenging_expertise: int = 3 # 1-5, ability to find and repurpose equipment
@export var jury_rigging_skill: int = 2 # 1-5, makeshift repair and modification ability
@export var territory_knowledge: int = 2 # 1-5, knowledge of local area

# Group dynamics
enum RaiderFormation {
	LONE_SCAVENGER = 0,
	RAIDING_PAIR = 1,
	SMALL_BAND = 2,
	RAIDING_PARTY = 3,
	CLAN_WARBAND = 4
}

var formation_type: RaiderFormation = RaiderFormation.SMALL_BAND
var pack_loyalty: int = 2 # 1-5, loyalty to group vs self-preservation
var leadership_present: bool = false

func _ready() -> void:
	super._ready()
	_setup_raider()

## Initialize raider with survival and territorial data
func initialize_raider(raider_data: Dictionary) -> void:
	# Set raider-specific properties
	desperation_level = raider_data.get("desperation_level", 3)
	resource_scarcity = raider_data.get("resource_scarcity", 4)
	tribal_affiliation = raider_data.get("tribal_affiliation", "independent")
	survival_experience = raider_data.get("survival_experience", 3)
	equipment_condition = raider_data.get("equipment_condition", "poor")
	
	# Behavioral characteristics
	opportunism_factor = raider_data.get("opportunism_factor", 1.5)
	retreat_threshold = raider_data.get("retreat_threshold", 40)
	salvage_priority = raider_data.get("salvage_priority", 4)
	intimidation_tactics = raider_data.get("intimidation_tactics", 2)
	
	# Survival data
	environmental_adaptation = raider_data.get("environmental_adaptation", ["wasteland"])
	scavenging_expertise = raider_data.get("scavenging_expertise", 3)
	jury_rigging_skill = raider_data.get("jury_rigging_skill", 2)
	territory_knowledge = raider_data.get("territory_knowledge", 2)
	
	# Group dynamics
	var formation_name: String = raider_data.get("formation_type", "small_band")
	formation_type = _parse_formation_type(formation_name)
	pack_loyalty = raider_data.get("pack_loyalty", 2)
	leadership_present = raider_data.get("leadership_present", false)
	
	# Set AI behavior to AGGRESSIVE (opportunistic raiders)
	if behavior != EnemyTacticalAI.AIPersonality.AGGRESSIVE:
		behavior = EnemyTacticalAI.AIPersonality.AGGRESSIVE
	
	# Apply raider modifications
	_apply_raider_modifiers()

## Get raider-specific combat modifiers
func get_raider_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Desperation affects combat intensity
	modifiers["desperation_bonus"] = desperation_level - 3 # -2 to +2
	modifiers["reckless_abandon"] = desperation_level >= 4
	modifiers["survival_desperation"] = resource_scarcity >= 4
	
	# Opportunistic nature
	modifiers["opportunism_factor"] = opportunism_factor
	modifiers["target_weak_first"] = true
	modifiers["hit_and_run_preference"] = true
	
	# Equipment condition affects reliability
	match equipment_condition:
		"poor":
			modifiers["equipment_unreliable"] = -2
			modifiers["jury_rigged_gear"] = true
		"salvaged":
			modifiers["equipment_unreliable"] = -1
			modifiers["improvised_equipment"] = true
		"functional":
			# Standard reliability
			pass
		"modified":
			modifiers["custom_modifications"] = 1
			modifiers["unpredictable_equipment"] = true
		"jury_rigged":
			modifiers["makeshift_genius"] = 2
			modifiers["explosive_malfunction_risk"] = true
	
	# Survival experience provides tactical advantages
	match survival_experience:
		1, 2:
			modifiers["survival_penalty"] = -1
		4, 5:
			modifiers["survival_bonus"] = survival_experience - 3
			modifiers["environmental_expert"] = true
			modifiers["trap_expertise"] = true
	
	# Tribal affiliation provides specific bonuses
	match tribal_affiliation:
		"wasteland_tribe":
			modifiers["tribal_warfare"] = true
			modifiers["pack_tactics"] = 1
		"scavenger_clan":
			modifiers["salvage_expertise"] = 2
			modifiers["jury_rigging_bonus"] = 1
		"nomad_band":
			modifiers["mobility_bonus"] = 1
			modifiers["terrain_knowledge"] = territory_knowledge
		"independent":
			modifiers["self_reliance"] = true
			modifiers["unpredictable_tactics"] = 1
	
	# Formation type affects coordination
	match formation_type:
		RaiderFormation.LONE_SCAVENGER:
			modifiers["lone_wolf"] = true
			modifiers["stealth_bonus"] = 1
		RaiderFormation.RAIDING_PAIR:
			modifiers["paired_tactics"] = true
		RaiderFormation.SMALL_BAND:
			modifiers["small_group_coordination"] = 1
		RaiderFormation.RAIDING_PARTY:
			modifiers["raiding_tactics"] = 2
		RaiderFormation.CLAN_WARBAND:
			modifiers["tribal_warband"] = true
			modifiers["overwhelming_numbers"] = 1
	
	# Leadership affects group performance
	if leadership_present:
		modifiers["leadership_bonus"] = 1
		modifiers["coordinated_raids"] = true
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Survival-driven behavior
	context["survival_priority"] = true
	context["resource_desperation"] = resource_scarcity
	context["desperation_level"] = desperation_level
	context["opportunistic_hunter"] = true
	
	# Combat preferences
	context["prefer_ambush"] = true
	context["avoid_fair_fights"] = true
	context["hit_and_run_tactics"] = true
	context["retreat_threshold"] = retreat_threshold
	
	# Scavenging and salvage focus
	context["salvage_priority"] = salvage_priority
	context["loot_motivated"] = salvage_priority >= 3
	context["equipment_scavenging"] = scavenging_expertise
	
	# Environmental factors
	context["environmental_adaptation"] = environmental_adaptation
	context["territory_knowledge"] = territory_knowledge
	context["survival_skills"] = survival_experience
	
	# Group dynamics
	context["formation_type"] = formation_type
	context["pack_loyalty"] = pack_loyalty
	context["leadership_structure"] = leadership_present
	
	# Equipment limitations
	context["equipment_condition"] = equipment_condition
	context["jury_rigging_capable"] = jury_rigging_skill >= 3
	context["improvised_tactics"] = true
	
	return context

## Get raider deployment preferences
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Formation type affects deployment
	match formation_type:
		RaiderFormation.LONE_SCAVENGER:
			preferences["formation"] = "solo_operation"
			preferences["stealth_approach"] = true
		RaiderFormation.RAIDING_PAIR:
			preferences["formation"] = "paired_hunters"
			preferences["mutual_support"] = true
		RaiderFormation.SMALL_BAND:
			preferences["formation"] = "loose_skirmish"
			preferences["opportunistic_positioning"] = true
		RaiderFormation.RAIDING_PARTY:
			preferences["formation"] = "raiding_assault"
			preferences["overwhelming_attack"] = true
		RaiderFormation.CLAN_WARBAND:
			preferences["formation"] = "tribal_warfare"
			preferences["intimidation_display"] = true
	
	# Environmental adaptation affects positioning
	for environment in environmental_adaptation:
		match environment:
			"wasteland":
				preferences["wasteland_tactics"] = true
				preferences["scrap_cover_usage"] = true
			"desert":
				preferences["desert_warfare"] = true
				preferences["heat_advantage"] = true
			"arctic":
				preferences["cold_weather_ops"] = true
				preferences["winter_camouflage"] = true
			"toxic":
				preferences["hazmat_resistance"] = true
				preferences["chemical_immunity"] = true
			"radioactive":
				preferences["radiation_immunity"] = true
				preferences["contaminated_terrain"] = true
	
	# Survival experience affects tactics
	if survival_experience >= 4:
		preferences["trap_deployment"] = true
		preferences["environmental_usage"] = true
	
	# Equipment condition affects approach
	if equipment_condition in ["poor", "salvaged"]:
		preferences["equipment_conservation"] = true
		preferences["scavenging_opportunity"] = true
	
	return preferences

## Process raider survival and scavenging mechanics
func process_survival_action(action_type: String, action_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "resources_gained": 0}
	
	match action_type:
		"scavenge_battlefield":
			result = _process_battlefield_scavenging(action_data)
		"jury_rig_equipment":
			result = _process_jury_rigging(action_data)
		"environmental_advantage":
			result = _process_environmental_usage(action_data)
		"intimidation_display":
			result = _process_intimidation_tactics(action_data)
		"desperate_gambit":
			result = _process_desperate_action(action_data)
	
	return result

## Check raider morale and retreat conditions
func check_raider_morale(combat_context: Dictionary) -> Dictionary:
	var morale_result: Dictionary = {
		"morale_status": "fighting",
		"retreat_likelihood": 0.0,
		"action_recommendation": "continue_combat"
	}
	
	var current_health_percent: float = float(_current_health) / float(_max_health) * 100.0
	var enemy_strength: int = combat_context.get("enemy_strength", 3)
	var loot_available: bool = combat_context.get("loot_present", false)
	var escape_routes: int = combat_context.get("escape_routes", 2)
	
	# Health-based retreat consideration
	if current_health_percent <= retreat_threshold:
		morale_result.retreat_likelihood += (retreat_threshold - current_health_percent) / 100.0
	
	# Enemy strength vs raider capability
	var strength_ratio: float = float(enemy_strength) / float(survival_experience + 2)
	if strength_ratio > 1.5:
		morale_result.retreat_likelihood += 0.3
	
	# Desperation affects willingness to retreat
	var desperation_modifier: float = (desperation_level - 3) * 0.1
	morale_result.retreat_likelihood -= desperation_modifier
	
	# Resource scarcity affects risk tolerance
	if resource_scarcity >= 4:
		if loot_available:
			morale_result.retreat_likelihood -= 0.2 # More willing to fight for resources
		else:
			morale_result.retreat_likelihood += 0.3 # Less willing to fight without reward
	
	# Pack loyalty affects individual vs group survival
	if formation_type != RaiderFormation.LONE_SCAVENGER:
		var loyalty_modifier: float = (pack_loyalty - 3) * 0.1
		morale_result.retreat_likelihood -= loyalty_modifier
	
	# Leadership affects group cohesion
	if leadership_present and formation_type >= RaiderFormation.SMALL_BAND:
		morale_result.retreat_likelihood -= 0.2
	
	# Escape route availability
	if escape_routes <= 1:
		morale_result.retreat_likelihood -= 0.3 # Cornered animals fight harder
	
	# Determine final morale status
	if morale_result.retreat_likelihood >= 0.7:
		morale_result.morale_status = "breaking"
		morale_result.action_recommendation = "immediate_retreat"
	elif morale_result.retreat_likelihood >= 0.5:
		morale_result.morale_status = "wavering"
		morale_result.action_recommendation = "consider_retreat"
	elif morale_result.retreat_likelihood <= 0.2:
		morale_result.morale_status = "desperate_courage"
		morale_result.action_recommendation = "fight_to_death"
	
	return morale_result

## Get raider loot table with scavenged materials
func get_raider_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"credits": _calculate_raider_wealth(),
		"scavenged_materials": _get_scavenged_material_drops(),
		"improvised_equipment": _get_improvised_equipment_drops(),
		"survival_gear": _get_survival_gear_drops(),
		"territorial_knowledge": _get_territorial_intelligence()
	}
	
	return loot_table

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
	return _type_data.get("raiders", {})

func _setup_raider() -> void:
	enemy_name = "Raider"
	var cfg: Dictionary = _load_type_data()
	var stats: Dictionary = cfg.get("base_stats", {})

	_max_health = int(stats.get("max_health", 60))
	_current_health = _max_health
	movement_range = int(stats.get("movement_range", 5))
	weapon_range = int(stats.get("weapon_range", 3))

	retreat_threshold = int(stats.get("retreat_threshold", 40))
	salvage_priority = int(stats.get("salvage_priority", 4))
	scavenging_expertise = 3

func _apply_raider_modifiers() -> void:
	# Desperation level affects combat capability
	match desperation_level:
		1, 2: # Low desperation - more cautious
			retreat_threshold += 10
			opportunism_factor -= 0.2
		4, 5: # High desperation - more reckless
			_max_health += desperation_level * 5
			retreat_threshold -= 10
			opportunism_factor += 0.3
	
	# Resource scarcity affects physical condition
	match resource_scarcity:
		1, 2: # Well-supplied
			_max_health += 10
		4, 5: # Starving/desperate
			_max_health -= 10
			movement_range += 1 # Desperate speed
			salvage_priority = 5
	
	# Survival experience affects capabilities
	_max_health += survival_experience * 3
	if survival_experience >= 4:
		movement_range += 1
		territory_knowledge = mini(territory_knowledge + 1, 5)
	
	# Equipment condition affects combat effectiveness
	match equipment_condition:
		"poor":
			weapon_range -= 1
			_max_health -= 5
		"salvaged":
			# No modifier - baseline
			pass
		"functional":
			weapon_range += 1
		"modified":
			weapon_range += 1
			_max_health += 5
		"jury_rigged":
			weapon_range += 2
			# But unreliable
	
	# Tribal affiliation affects group capabilities
	match tribal_affiliation:
		"wasteland_tribe":
			_max_health += 10
			pack_loyalty = mini(pack_loyalty + 1, 5)
		"scavenger_clan":
			scavenging_expertise = mini(scavenging_expertise + 1, 5)
			jury_rigging_skill = mini(jury_rigging_skill + 1, 5)
		"nomad_band":
			movement_range += 1
			territory_knowledge = mini(territory_knowledge + 2, 5)
		"independent":
			# Self-reliant but isolated
			pack_loyalty = maxi(pack_loyalty - 1, 1)
			survival_experience = mini(survival_experience + 1, 5)
	
	# Formation type affects individual vs group stats
	match formation_type:
		RaiderFormation.LONE_SCAVENGER:
			_max_health += 5
			pack_loyalty = 1
		RaiderFormation.CLAN_WARBAND:
			pack_loyalty = mini(pack_loyalty + 2, 5)
			leadership_present = true
	
	_current_health = _max_health

func _parse_formation_type(formation_name: String) -> RaiderFormation:
	match formation_name.to_lower():
		"lone_scavenger": return RaiderFormation.LONE_SCAVENGER
		"raiding_pair": return RaiderFormation.RAIDING_PAIR
		"small_band": return RaiderFormation.SMALL_BAND
		"raiding_party": return RaiderFormation.RAIDING_PARTY
		"clan_warband": return RaiderFormation.CLAN_WARBAND
		_: return RaiderFormation.SMALL_BAND

func _process_battlefield_scavenging(action_data: Dictionary) -> Dictionary:
	var battlefield_richness: int = action_data.get("battlefield_richness", 2)
	var scavenging_time: int = action_data.get("time_available", 3)
	
	var success_chance: float = (scavenging_expertise + battlefield_richness + scavenging_time) / 15.0
	success_chance = clampf(success_chance, 0.1, 0.9)
	
	if randf() < success_chance:
		var resources_found: int = scavenging_expertise + randi() % 3
		return {"success": true, "resources_gained": resources_found, "type": "battlefield_salvage"}
	else:
		return {"success": false, "resources_gained": 0}

func _process_jury_rigging(action_data: Dictionary) -> Dictionary:
	var equipment_complexity: int = action_data.get("complexity", 3)
	var materials_available: int = action_data.get("materials", 2)
	
	var success_chance: float = (jury_rigging_skill + materials_available - equipment_complexity) / 10.0
	success_chance = clampf(success_chance, 0.1, 0.8)
	
	if randf() < success_chance:
		var improvement: int = jury_rigging_skill
		return {"success": true, "improvement": improvement, "type": "jury_rigged_upgrade"}
	else:
		return {"success": false, "type": "jury_rigging_failure"}

func _process_environmental_usage(action_data: Dictionary) -> Dictionary:
	var environment_type: String = action_data.get("environment", "wasteland")
	var adaptation_bonus: int = 1 if environment_type in environmental_adaptation else 0
	
	var usage_effectiveness: int = survival_experience + territory_knowledge + adaptation_bonus
	
	if usage_effectiveness >= 6:
		return {"success": true, "advantage_gained": 2, "type": "environmental_mastery"}
	elif usage_effectiveness >= 4:
		return {"success": true, "advantage_gained": 1, "type": "environmental_usage"}
	else:
		return {"success": false, "type": "environmental_unfamiliarity"}

func _process_intimidation_tactics(action_data: Dictionary) -> Dictionary:
	var target_morale: int = action_data.get("target_morale", 3)
	var group_size_bonus: int = 0
	
	match formation_type:
		RaiderFormation.RAIDING_PARTY: group_size_bonus = 1
		RaiderFormation.CLAN_WARBAND: group_size_bonus = 2
	
	var intimidation_strength: int = intimidation_tactics + desperation_level + group_size_bonus
	
	if intimidation_strength > target_morale:
		return {"success": true, "effect": "intimidation_successful", "morale_damage": intimidation_strength - target_morale}
	else:
		return {"success": false, "effect": "intimidation_failed"}

func _process_desperate_action(action_data: Dictionary) -> Dictionary:
	var risk_level: int = action_data.get("risk_level", 3)
	var potential_reward: int = action_data.get("potential_reward", 2)
	
	# Desperation makes risky actions more appealing
	var desperation_modifier: float = desperation_level / 5.0
	var success_chance: float = (potential_reward - risk_level + desperation_modifier) / 10.0
	success_chance = clampf(success_chance, 0.05, 0.95)
	
	if randf() < success_chance:
		return {"success": true, "reward": potential_reward * 2, "type": "desperate_success"}
	else:
		var damage: int = risk_level * 5
		take_damage(damage)
		return {"success": false, "damage_taken": damage, "type": "desperate_failure"}

func _calculate_raider_wealth() -> int:
	var base_credits: int = 50 # Raiders are typically poor
	
	# Scavenging expertise affects accumulated wealth
	base_credits += scavenging_expertise * 20
	
	# Resource scarcity inversely affects wealth
	base_credits -= (resource_scarcity - 1) * 15
	
	# Tribal affiliation affects resources
	match tribal_affiliation:
		"scavenger_clan": base_credits += 30
		"nomad_band": base_credits += 20
		"wasteland_tribe": base_credits += 25
		"independent": base_credits -= 10
	
	return maxi(base_credits, 10) # Minimum subsistence level

func _get_scavenged_material_drops() -> Array[Dictionary]:
	var materials: Array[Dictionary] = []
	
	# Basic scavenged materials
	materials.append({
		"type": "scrap",
		"name": "Metal Scrap",
		"quality": "salvaged",
		"value": 25,
		"chance": 0.8
	})
	
	materials.append({
		"type": "components",
		"name": "Electronic Components",
		"quality": "salvaged",
		"value": 40,
		"chance": 0.5
	})
	
	# Scavenging expertise affects quality
	if scavenging_expertise >= 4:
		materials.append({
			"type": "rare_materials",
			"name": "Rare Salvage",
			"quality": "functional",
			"value": 100,
			"chance": 0.3
		})
	
	return materials

func _get_improvised_equipment_drops() -> Array[Dictionary]:
	var equipment: Array[Dictionary] = []
	
	# Jury-rigged weapons
	equipment.append({
		"type": "weapon",
		"name": "Improvised Weapon",
		"quality": equipment_condition,
		"condition": "jury_rigged",
		"chance": 0.6
	})
	
	# Makeshift armor
	equipment.append({
		"type": "armor",
		"name": "Scrap Armor",
		"quality": "improvised",
		"condition": equipment_condition,
		"chance": 0.4
	})
	
	# Jury-rigging skill affects availability
	if jury_rigging_skill >= 3:
		equipment.append({
			"type": "tool",
			"name": "Jury-Rigging Kit",
			"quality": "functional",
			"value": jury_rigging_skill * 50,
			"chance": 0.3
		})
	
	return equipment

func _get_survival_gear_drops() -> Array[Dictionary]:
	var survival_gear: Array[Dictionary] = []
	
	# Basic survival equipment
	survival_gear.append({
		"type": "survival",
		"name": "Survival Kit",
		"quality": "basic",
		"environmental_type": environmental_adaptation[0] if not environmental_adaptation.is_empty() else "wasteland",
		"chance": 0.5
	})
	
	# Environmental adaptation gear
	for environment in environmental_adaptation:
		survival_gear.append({
			"type": "environmental",
			"name": environment.capitalize() + " Adaptation Gear",
			"environment": environment,
			"value": 75,
			"chance": 0.3
		})
	
	return survival_gear

func _get_territorial_intelligence() -> Array[Dictionary]:
	var intelligence: Array[Dictionary] = []
	
	# Local area knowledge
	if territory_knowledge >= 3:
		intelligence.append({
			"type": "map_data",
			"name": "Territory Maps",
			"coverage": territory_knowledge,
			"value": territory_knowledge * 100,
			"chance": 0.4
		})
	
	# Resource location data
	if scavenging_expertise >= 4:
		intelligence.append({
			"type": "resource_locations",
			"name": "Scavenging Sites",
			"quality": scavenging_expertise,
			"value": 200,
			"chance": 0.3
		})
	
	# Tribal information
	if tribal_affiliation != "independent":
		intelligence.append({
			"type": "tribal_intelligence",
			"name": tribal_affiliation.replace("_", " ").capitalize() + " Information",
			"value": 150,
			"chance": 0.25
		})
	
	return intelligence