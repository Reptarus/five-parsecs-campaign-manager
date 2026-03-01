@tool
class_name Wildlife
extends "res://src/core/enemy/base/Enemy.gd"

## Wildlife Enemy Type for Five Parsecs Campaign Manager
##
## Implements alien creatures and dangerous fauna with instinctual behavior,
## pack tactics, and environmental adaptation using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Wildlife specific data
@export var creature_type: String = "predator" # predator, herbivore, scavenger, hive_mind, apex
@export var intelligence_level: int = 2 # 1-5, affects tactical complexity
@export var pack_size: int = 1 # Natural group size
@export var territorial_range: int = 8 # Defense radius in grid units
@export var aggression_level: int = 3 # 1-5, natural aggressiveness

# Environmental adaptation
@export var climate_adaptation: String = "temperate" # arctic, desert, jungle, swamp, volcanic, void
@export var terrain_specialization: String = "ground" # ground, aerial, aquatic, subterranean, arboreal
@export var size_category: String = "medium" # tiny, small, medium, large, huge, colossal

# Biological traits
@export var natural_weapons: Array[String] = ["claws"] # claws, fangs, stinger, spines, breath_weapon
@export var special_abilities: Array[String] = [] # venom, camouflage, regeneration, pounce, charge
@export var sensory_capabilities: Array[String] = ["sight"] # sight, hearing, smell, echolocation, thermal, psionic

# Pack and territorial behavior
enum WildlifeBehavior {
	SOLITARY = 0,
	MATED_PAIR = 1,
	PACK_HUNTER = 2,
	HERD_ANIMAL = 3,
	TERRITORIAL = 4,
	SWARM = 5
}

var social_behavior: WildlifeBehavior = WildlifeBehavior.SOLITARY
var pack_coordination: int = 0 # Bonus when fighting with pack members
var territorial_bonus: int = 0 # Combat bonus when defending territory

func _ready() -> void:
	super._ready()
	_setup_wildlife()

## Initialize wildlife with specific parameters
func initialize_wildlife(wildlife_data: Dictionary) -> void:
	# Set creature-specific properties
	creature_type = wildlife_data.get("creature_type", "predator")
	intelligence_level = wildlife_data.get("intelligence_level", 2)
	pack_size = wildlife_data.get("pack_size", 1)
	territorial_range = wildlife_data.get("territorial_range", 8)
	aggression_level = wildlife_data.get("aggression_level", 3)
	
	# Environmental data
	climate_adaptation = wildlife_data.get("climate_adaptation", "temperate")
	terrain_specialization = wildlife_data.get("terrain_specialization", "ground")
	size_category = wildlife_data.get("size_category", "medium")
	
	# Biological traits
	natural_weapons = wildlife_data.get("natural_weapons", ["claws"])
	special_abilities = wildlife_data.get("special_abilities", [])
	sensory_capabilities = wildlife_data.get("sensory_capabilities", ["sight"])
	
	# Determine social behavior and AI type
	_determine_social_behavior()
	_set_ai_behavior()
	
	# Apply wildlife modifications
	_apply_wildlife_modifiers()

## Get wildlife-specific combat modifiers
func get_wildlife_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Creature type affects combat style
	match creature_type:
		"predator":
			modifiers["predator_instincts"] = true
			modifiers["hunt_tactics"] = true
			modifiers["target_weakest"] = true
		"herbivore":
			modifiers["defensive_stance"] = true
			modifiers["charge_when_cornered"] = true
			modifiers["flee_when_possible"] = true
		"scavenger":
			modifiers["opportunistic"] = true
			modifiers["avoid_fair_fights"] = true
			modifiers["scavenging_focus"] = true
		"hive_mind":
			modifiers["perfect_coordination"] = true
			modifiers["shared_consciousness"] = true
			modifiers["no_morale_loss"] = true
		"apex":
			modifiers["apex_predator"] = true
			modifiers["fear_inducing"] = 2
			modifiers["superior_abilities"] = true
	
	# Size category affects combat capabilities
	match size_category:
		"tiny":
			modifiers["size_penalty"] = -2
			modifiers["hard_to_hit"] = 2
			modifiers["swarm_tactics"] = true
		"small":
			modifiers["size_penalty"] = -1
			modifiers["agile_movement"] = 1
		"medium":
			# No modifier - baseline
			pass
		"large":
			modifiers["size_bonus"] = 1
			modifiers["reach_advantage"] = true
			modifiers["intimidation"] = 1
		"huge":
			modifiers["size_bonus"] = 2
			modifiers["massive_reach"] = true
			modifiers["area_attacks"] = true
		"colossal":
			modifiers["size_bonus"] = 3
			modifiers["devastating_attacks"] = true
			modifiers["terrain_shaping"] = true
	
	# Natural weapons and special abilities
	for weapon in natural_weapons:
		modifiers[weapon + "_attacks"] = true
	
	for ability in special_abilities:
		modifiers[ability + "_ability"] = true
	
	# Pack coordination
	if pack_coordination > 0:
		modifiers["pack_coordination"] = pack_coordination
		modifiers["coordinated_attacks"] = true
	
	# Territorial defense
	if territorial_bonus > 0:
		modifiers["territorial_defense"] = territorial_bonus
		modifiers["home_advantage"] = true
	
	# Environmental advantages
	modifiers.merge(_get_environmental_modifiers())
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Basic instinctual behavior
	context["intelligence_level"] = intelligence_level
	context["instinct_driven"] = intelligence_level <= 2
	context["tactical_planning"] = intelligence_level >= 4
	
	# Behavioral patterns
	context["creature_type"] = creature_type
	context["social_behavior"] = social_behavior
	context["aggression_level"] = aggression_level
	
	# Environmental factors
	context["territorial_defender"] = social_behavior == WildlifeBehavior.TERRITORIAL
	context["pack_hunter"] = social_behavior == WildlifeBehavior.PACK_HUNTER
	context["herd_protection"] = social_behavior == WildlifeBehavior.HERD_ANIMAL
	
	# Sensory capabilities affect awareness
	context["enhanced_senses"] = sensory_capabilities.size() > 2
	context["stealth_detection"] = "smell" in sensory_capabilities or "thermal" in sensory_capabilities
	
	# Special ability context
	context["special_abilities"] = special_abilities
	context["natural_weapons"] = natural_weapons
	
	return context

## Get wildlife deployment preferences
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Social behavior affects formation
	match social_behavior:
		WildlifeBehavior.SOLITARY:
			preferences["formation"] = "independent"
			preferences["spacing"] = "wide"
		WildlifeBehavior.MATED_PAIR:
			preferences["formation"] = "paired"
			preferences["mutual_protection"] = true
		WildlifeBehavior.PACK_HUNTER:
			preferences["formation"] = "pack_formation"
			preferences["coordinated_flanking"] = true
		WildlifeBehavior.HERD_ANIMAL:
			preferences["formation"] = "protective_circle"
			preferences["defend_young"] = true
		WildlifeBehavior.TERRITORIAL:
			preferences["formation"] = "territorial_patrol"
			preferences["area_control"] = true
		WildlifeBehavior.SWARM:
			preferences["formation"] = "swarm_cloud"
			preferences["overwhelming_numbers"] = true
	
	# Terrain specialization affects positioning
	match terrain_specialization:
		"aerial":
			preferences["height_advantage"] = true
			preferences["aerial_mobility"] = true
		"aquatic":
			preferences["water_terrain"] = true
			preferences["amphibious_assault"] = true
		"subterranean":
			preferences["underground_movement"] = true
			preferences["tunnel_networks"] = true
		"arboreal":
			preferences["tree_movement"] = true
			preferences["canopy_advantage"] = true
	
	# Size affects deployment spacing
	if size_category in ["huge", "colossal"]:
		preferences["requires_open_terrain"] = true
		preferences["area_control"] = true
	
	return preferences

## Process wildlife instinctual reactions
func process_instinctual_reaction(stimulus_type: String, stimulus_data: Dictionary) -> Dictionary:
	var reaction: Dictionary = {"reaction_type": "none", "intensity": 0}
	
	match stimulus_type:
		"threat_detected":
			reaction = _process_threat_reaction(stimulus_data)
		"territory_invaded":
			reaction = _process_territorial_reaction(stimulus_data)
		"pack_member_injured":
			reaction = _process_pack_loyalty_reaction(stimulus_data)
		"food_source_found":
			reaction = _process_feeding_reaction(stimulus_data)
		"environmental_change":
			reaction = _process_environmental_reaction(stimulus_data)
		"mating_season":
			reaction = _process_mating_behavior(stimulus_data)
	
	return reaction

## Get wildlife loot table with biological materials
func get_wildlife_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"biological_materials": _get_biological_material_drops(),
		"natural_resources": _get_natural_resource_drops(),
		"genetic_samples": _get_genetic_sample_drops(),
		"exotic_compounds": _get_exotic_compound_drops()
	}
	
	return loot_table

## Check for environmental adaptation bonuses
func get_environmental_adaptation(environment_type: String) -> Dictionary:
	var adaptation: Dictionary = {"adapted": false, "bonus": 0, "penalty": 0}
	
	if environment_type == climate_adaptation:
		adaptation.adapted = true
		adaptation.bonus = 2
	elif _is_compatible_environment(environment_type):
		adaptation.bonus = 1
	else:
		adaptation.penalty = 1
	
	return adaptation

## Private Methods

func _setup_wildlife() -> void:
	enemy_name = "Wildlife"
	
	# Wildlife varies dramatically in capability
	_max_health = 50 # Will be modified by size and type
	_current_health = _max_health
	movement_range = 4
	weapon_range = 1 # Most wildlife uses natural weapons (melee)
	
	# Basic wildlife characteristics
	pack_coordination = 0
	territorial_bonus = 0

func _determine_social_behavior() -> void:
	# Determine social behavior based on pack size and creature type
	if pack_size == 1:
		social_behavior = WildlifeBehavior.SOLITARY
	elif pack_size == 2:
		social_behavior = WildlifeBehavior.MATED_PAIR
	elif creature_type == "predator" and pack_size <= 6:
		social_behavior = WildlifeBehavior.PACK_HUNTER
	elif creature_type == "herbivore":
		social_behavior = WildlifeBehavior.HERD_ANIMAL
	elif aggression_level >= 4:
		social_behavior = WildlifeBehavior.TERRITORIAL
	elif pack_size > 10:
		social_behavior = WildlifeBehavior.SWARM

func _set_ai_behavior() -> void:
	# Set AI behavior based on creature characteristics
	match creature_type:
		"predator":
			behavior = EnemyTacticalAI.AIPersonality.AGGRESSIVE
		"herbivore":
			behavior = EnemyTacticalAI.AIPersonality.DEFENSIVE
		"scavenger":
			behavior = EnemyTacticalAI.AIPersonality.CAUTIOUS
		"hive_mind":
			behavior = EnemyTacticalAI.AIPersonality.TACTICAL
		"apex":
			behavior = EnemyTacticalAI.AIPersonality.AGGRESSIVE

func _apply_wildlife_modifiers() -> void:
	# Size category dramatically affects stats
	match size_category:
		"tiny":
			_max_health = 10
			movement_range = 6
		"small":
			_max_health = 25
			movement_range = 5
		"medium":
			_max_health = 50
			movement_range = 4
		"large":
			_max_health = 100
			movement_range = 3
			weapon_range = 2
		"huge":
			_max_health = 200
			movement_range = 2
			weapon_range = 3
		"colossal":
			_max_health = 400
			movement_range = 1
			weapon_range = 4
	
	# Creature type affects base stats
	match creature_type:
		"predator":
			_max_health = roundi(_max_health * 1.2)
			aggression_level += 1
		"herbivore":
			_max_health = roundi(_max_health * 1.4)
			aggression_level = maxi(aggression_level - 2, 1)
		"scavenger":
			_max_health = roundi(_max_health * 0.8)
			movement_range += 1
		"hive_mind":
			intelligence_level = mini(intelligence_level + 2, 5)
		"apex":
			_max_health = roundi(_max_health * 1.6)
			aggression_level = 5
			intelligence_level = mini(intelligence_level + 1, 5)
	
	# Intelligence affects tactical capabilities
	if intelligence_level >= 4:
		# High intelligence creatures can use more complex tactics
		territorial_range += 2
	
	# Social behavior affects cooperation
	match social_behavior:
		WildlifeBehavior.PACK_HUNTER:
			pack_coordination = intelligence_level
		WildlifeBehavior.HERD_ANIMAL:
			pack_coordination = maxi(intelligence_level - 1, 1)
		WildlifeBehavior.TERRITORIAL:
			territorial_bonus = aggression_level
		WildlifeBehavior.SWARM:
			pack_coordination = 2 # Simple coordination
	
	# Special abilities modify stats
	_apply_special_ability_modifiers()
	
	_current_health = _max_health

func _apply_special_ability_modifiers() -> void:
	for ability in special_abilities:
		match ability:
			"regeneration":
				_max_health = roundi(_max_health * 1.3)
			"venom":
				weapon_range = mini(weapon_range + 1, 6)
			"camouflage":
				movement_range += 1
			"pounce":
				movement_range += 2
			"charge":
				_max_health = roundi(_max_health * 1.1)
			"breath_weapon":
				weapon_range += 3

func _get_environmental_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Climate adaptation bonuses
	match climate_adaptation:
		"arctic":
			modifiers["cold_immunity"] = true
			modifiers["ice_movement"] = true
		"desert":
			modifiers["heat_immunity"] = true
			modifiers["water_conservation"] = true
		"jungle":
			modifiers["dense_vegetation_movement"] = true
			modifiers["toxin_resistance"] = 1
		"swamp":
			modifiers["amphibious"] = true
			modifiers["disease_resistance"] = 1
		"volcanic":
			modifiers["heat_immunity"] = true
			modifiers["lava_walking"] = true
		"void":
			modifiers["vacuum_survival"] = true
			modifiers["radiation_immunity"] = true
	
	# Terrain specialization bonuses
	match terrain_specialization:
		"aerial":
			modifiers["flight"] = true
			modifiers["dive_attacks"] = true
		"aquatic":
			modifiers["swimming"] = true
			modifiers["underwater_combat"] = true
		"subterranean":
			modifiers["tunneling"] = true
			modifiers["tremor_sense"] = true
		"arboreal":
			modifiers["climbing"] = true
			modifiers["branch_swinging"] = true
	
	return modifiers

func _process_threat_reaction(stimulus_data: Dictionary) -> Dictionary:
	var threat_level: int = stimulus_data.get("threat_level", 3)
	var threat_type: String = stimulus_data.get("threat_type", "unknown")
	
	match creature_type:
		"predator":
			if threat_level <= aggression_level:
				return {"reaction_type": "attack", "intensity": aggression_level}
			else:
				return {"reaction_type": "stalk", "intensity": 2}
		"herbivore":
			if threat_level >= 3:
				return {"reaction_type": "flee", "intensity": threat_level}
			else:
				return {"reaction_type": "defensive_posture", "intensity": 1}
		"scavenger":
			return {"reaction_type": "avoid", "intensity": 1}
		_:
			return {"reaction_type": "assess", "intensity": intelligence_level}

func _process_territorial_reaction(stimulus_data: Dictionary) -> Dictionary:
	if social_behavior != WildlifeBehavior.TERRITORIAL:
		return {"reaction_type": "ignore", "intensity": 0}
	
	var intruder_distance: int = stimulus_data.get("distance", 10)
	var intruder_threat: int = stimulus_data.get("threat_level", 2)
	
	if intruder_distance <= territorial_range:
		var reaction_intensity: int = territorial_bonus + aggression_level
		return {"reaction_type": "territorial_challenge", "intensity": reaction_intensity}
	
	return {"reaction_type": "warning_display", "intensity": 1}

func _process_pack_loyalty_reaction(stimulus_data: Dictionary) -> Dictionary:
	if social_behavior not in [WildlifeBehavior.PACK_HUNTER, WildlifeBehavior.HERD_ANIMAL]:
		return {"reaction_type": "ignore", "intensity": 0}
	
	var injured_pack_member: bool = stimulus_data.get("pack_member_injured", false)
	var pack_size_remaining: int = stimulus_data.get("pack_size", pack_size)
	
	if injured_pack_member:
		var loyalty_intensity: int = pack_coordination + aggression_level
		return {"reaction_type": "defend_pack", "intensity": loyalty_intensity}
	
	if pack_size_remaining <= pack_size / 2:
		return {"reaction_type": "retreat_with_pack", "intensity": 3}
	
	return {"reaction_type": "regroup", "intensity": 1}

func _process_feeding_reaction(stimulus_data: Dictionary) -> Dictionary:
	var food_quality: int = stimulus_data.get("food_quality", 2)
	var competition_present: bool = stimulus_data.get("competition", false)
	
	match creature_type:
		"predator":
			if competition_present:
				return {"reaction_type": "aggressive_feeding", "intensity": aggression_level}
			else:
				return {"reaction_type": "opportunistic_feeding", "intensity": 2}
		"herbivore":
			return {"reaction_type": "peaceful_feeding", "intensity": 1}
		"scavenger":
			return {"reaction_type": "cautious_feeding", "intensity": 1}
		_:
			return {"reaction_type": "investigate_food", "intensity": intelligence_level}

func _process_environmental_reaction(stimulus_data: Dictionary) -> Dictionary:
	var change_type: String = stimulus_data.get("change_type", "unknown")
	var severity: int = stimulus_data.get("severity", 2)
	
	match change_type:
		"weather":
			return {"reaction_type": "seek_shelter", "intensity": severity}
		"terrain":
			return {"reaction_type": "adapt_movement", "intensity": 1}
		"temperature":
			if climate_adaptation in ["arctic", "desert"]:
				return {"reaction_type": "no_reaction", "intensity": 0}
			else:
				return {"reaction_type": "environmental_stress", "intensity": severity}
		_:
			return {"reaction_type": "cautious_observation", "intensity": intelligence_level}

func _process_mating_behavior(stimulus_data: Dictionary) -> Dictionary:
	var season_intensity: int = stimulus_data.get("season_intensity", 2)
	
	match social_behavior:
		WildlifeBehavior.MATED_PAIR:
			return {"reaction_type": "protective_mate", "intensity": aggression_level + 1}
		WildlifeBehavior.TERRITORIAL:
			return {"reaction_type": "expand_territory", "intensity": territorial_bonus + 1}
		_:
			return {"reaction_type": "seek_mate", "intensity": season_intensity}

func _get_biological_material_drops() -> Array[Dictionary]:
	var materials: Array[Dictionary] = []
	
	# Natural weapons provide materials
	for weapon in natural_weapons:
		materials.append({
			"type": "biological",
			"name": weapon.capitalize(),
			"quality": size_category,
			"value": _calculate_material_value(weapon),
			"chance": 0.6
		})
	
	# Size affects available materials
	if size_category in ["large", "huge", "colossal"]:
		materials.append({
			"type": "biological",
			"name": "Hide",
			"quality": size_category,
			"value": _calculate_material_value("hide"),
			"chance": 0.8
		})
	
	return materials

func _get_natural_resource_drops() -> Array[Dictionary]:
	var resources: Array[Dictionary] = []
	
	# Climate-specific resources
	match climate_adaptation:
		"arctic":
			resources.append({
				"type": "resource",
				"name": "Insulating Fur",
				"value": 100,
				"chance": 0.4
			})
		"desert":
			resources.append({
				"type": "resource",
				"name": "Water Storage Organ",
				"value": 150,
				"chance": 0.3
			})
		"volcanic":
			resources.append({
				"type": "resource",
				"name": "Heat-Resistant Scales",
				"value": 200,
				"chance": 0.3
			})
	
	return resources

func _get_genetic_sample_drops() -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	
	# Special abilities provide genetic value
	for ability in special_abilities:
		samples.append({
			"type": "genetic",
			"name": ability.capitalize() + " Gene Sample",
			"value": 300,
			"chance": 0.2
		})
	
	# Apex creatures have valuable genetics
	if creature_type == "apex":
		samples.append({
			"type": "genetic",
			"name": "Apex Predator Genome",
			"value": 1000,
			"chance": 0.1
		})
	
	return samples

func _get_exotic_compound_drops() -> Array[Dictionary]:
	var compounds: Array[Dictionary] = []
	
	# Venom-based compounds
	if "venom" in special_abilities:
		compounds.append({
			"type": "compound",
			"name": "Bioactive Venom",
			"value": 500,
			"chance": 0.4
		})
	
	# Size-dependent exotic materials
	if size_category in ["huge", "colossal"]:
		compounds.append({
			"type": "compound",
			"name": "Exotic Biochemicals",
			"value": 800,
			"chance": 0.2
		})
	
	return compounds

func _calculate_material_value(material_type: String) -> int:
	var base_value: int = 50
	
	match material_type:
		"claws": base_value = 75
		"fangs": base_value = 100
		"stinger": base_value = 125
		"spines": base_value = 60
		"hide": base_value = 40
	
	# Size multiplier
	match size_category:
		"tiny": base_value = roundi(base_value * 0.3)
		"small": base_value = roundi(base_value * 0.6)
		"medium": base_value = roundi(base_value * 1.0)
		"large": base_value = roundi(base_value * 1.5)
		"huge": base_value = roundi(base_value * 2.5)
		"colossal": base_value = roundi(base_value * 4.0)
	
	return base_value

func _is_compatible_environment(environment: String) -> bool:
	# Define environment compatibility
	var compatibility_map: Dictionary = {
		"arctic": ["temperate"],
		"desert": ["temperate", "volcanic"],
		"jungle": ["temperate", "swamp"],
		"swamp": ["jungle", "temperate"],
		"volcanic": ["desert"],
		"void": [], # Void adaptation is very specific
		"temperate": ["arctic", "desert", "jungle"] # Temperate is most adaptable
	}
	
	var compatible_environments: Array = compatibility_map.get(climate_adaptation, [])
	return environment in compatible_environments