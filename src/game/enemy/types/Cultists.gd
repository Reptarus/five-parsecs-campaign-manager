@tool
class_name Cultists
extends "res://src/core/enemy/base/Enemy.gd"

## Cultists Enemy Type for Five Parsecs Campaign Manager
##
## Implements fanatical cult members with unpredictable behavior, ritual weapons,
## and supernatural abilities using existing EnemyTacticalAI.

const EnemyTacticalAI = preload("res://src/game/combat/EnemyTacticalAI.gd")

# Cultist specific data
@export var devotion_level: int = 3 # 1-5, affects fanaticism and special abilities
@export var cult_hierarchy: String = "follower" # follower, adept, priest, high_priest
@export var elder_being: String = "unknown" # unknown, void_entity, star_god, machine_intelligence
@export var ritual_focus: String = "combat" # combat, summoning, transformation, sacrifice
@export var mutation_level: int = 0 # 0-3, physical changes from exposure

# Cult behavior modifiers
@export var fanaticism_bonus: int = 2 # Bonus to actions when zealous
@export var fear_immunity: bool = false # Immunity to fear and morale effects
@export var pain_tolerance: int = 1 # Reduction to damage effects
@export var ritual_power: int = 1 # Strength of supernatural abilities

# Supernatural elements
enum ElderInfluence {
	NONE = 0,
	WHISPERS = 1, # Minor psychic effects
	MANIFESTATION = 2, # Visible supernatural phenomena
	POSSESSION = 3, # Direct supernatural control
	AVATAR = 4 # Physical manifestation through cultist
}

var current_influence: ElderInfluence = ElderInfluence.NONE
var ritual_charges: int = 0 # Uses of supernatural abilities
var corruption_level: int = 0 # Accumulated supernatural exposure

func _ready() -> void:
	super._ready()
	_setup_cultist()

## Initialize cultist with specific parameters
func initialize_cultist(cultist_data: Dictionary) -> void:
	# Set cultist-specific properties
	devotion_level = cultist_data.get("devotion_level", 3)
	cult_hierarchy = cultist_data.get("cult_hierarchy", "follower")
	elder_being = cultist_data.get("elder_being", "unknown")
	ritual_focus = cultist_data.get("ritual_focus", "combat")
	mutation_level = cultist_data.get("mutation_level", 0)
	
	# Set AI behavior to DEFENSIVE initially (cultists are defensive until triggered)
	if behavior != EnemyTacticalAI.AIPersonality.DEFENSIVE:
		behavior = EnemyTacticalAI.AIPersonality.DEFENSIVE
	
	# Apply cultist modifications
	_apply_cultist_modifiers()
	
	# Initialize supernatural elements
	_initialize_supernatural_abilities()
	
	# Generate ritual charges
	ritual_charges = devotion_level + (1 if cult_hierarchy in ["priest", "high_priest"] else 0)

## Get cultist-specific combat modifiers
func get_cultist_combat_modifiers() -> Dictionary:
	var modifiers: Dictionary = {}
	
	# Fanaticism provides combat bonuses
	modifiers["fanaticism_bonus"] = fanaticism_bonus
	modifiers["zealous_charge"] = true
	modifiers["sacrificial_tactics"] = true
	
	# Hierarchy affects leadership and abilities
	match cult_hierarchy:
		"follower":
			modifiers["basic_fanaticism"] = true
		"adept":
			modifiers["ritual_knowledge"] = true
			modifiers["minor_powers"] = true
		"priest":
			modifiers["ritual_mastery"] = true
			modifiers["command_lesser"] = true
			modifiers["supernatural_protection"] = 1
		"high_priest":
			modifiers["elder_connection"] = true
			modifiers["command_all"] = true
			modifiers["supernatural_protection"] = 2
			modifiers["avatar_potential"] = true
	
	# Elder being influence affects combat style
	match elder_being:
		"void_entity":
			modifiers["void_powers"] = true
			modifiers["reality_distortion"] = true
		"star_god":
			modifiers["cosmic_awareness"] = true
			modifiers["stellar_energy"] = true
		"machine_intelligence":
			modifiers["technological_fusion"] = true
			modifiers["logic_immunity"] = true
	
	# Current supernatural influence
	match current_influence:
		ElderInfluence.WHISPERS:
			modifiers["psychic_interference"] = 1
		ElderInfluence.MANIFESTATION:
			modifiers["supernatural_manifestation"] = true
			modifiers["fear_aura"] = 2
		ElderInfluence.POSSESSION:
			modifiers["possessed_strength"] = 2
			modifiers["inhuman_resilience"] = true
		ElderInfluence.AVATAR:
			modifiers["avatar_powers"] = true
			modifiers["reality_breaking"] = true
	
	# Mutations provide physical advantages
	if mutation_level > 0:
		modifiers["mutation_bonus"] = mutation_level
		modifiers["inhuman_anatomy"] = true
	
	# Special immunities
	if fear_immunity:
		modifiers["fear_immune"] = true
		modifiers["morale_immune"] = true
	
	return modifiers

## Get tactical decision context for AI system
func get_tactical_context() -> Dictionary:
	var context: Dictionary = {}
	
	# Cultist behavioral patterns
	context["devotion_level"] = devotion_level
	context["fanaticism_active"] = devotion_level >= 3
	context["self_sacrifice_acceptable"] = devotion_level >= 4
	
	# Supernatural elements
	context["ritual_charges"] = ritual_charges
	context["elder_influence"] = current_influence
	context["supernatural_abilities"] = ritual_power
	
	# Tactical preferences
	context["prefer_melee"] = ritual_focus == "combat"
	context["group_rituals"] = ritual_focus == "summoning"
	context["transformation_focus"] = ritual_focus == "transformation"
	context["sacrificial_priority"] = ritual_focus == "sacrifice"
	
	# Hierarchy-based command structure
	context["can_command_others"] = cult_hierarchy in ["priest", "high_priest"]
	context["follows_commands"] = cult_hierarchy in ["follower", "adept"]
	
	return context

## Get cultist deployment preferences
func get_deployment_preferences() -> Dictionary:
	var preferences: Dictionary = {}
	
	# Deployment based on ritual focus
	match ritual_focus:
		"combat":
			preferences["formation"] = "zealot_charge"
			preferences["movement_pattern"] = "aggressive_advance"
		"summoning":
			preferences["formation"] = "ritual_circle"
			preferences["movement_pattern"] = "protective_positioning"
		"transformation":
			preferences["formation"] = "mutation_pods"
			preferences["movement_pattern"] = "adaptive_spacing"
		"sacrifice":
			preferences["formation"] = "sacrificial_altar"
			preferences["movement_pattern"] = "capture_focus"
	
	# Hierarchy affects positioning
	match cult_hierarchy:
		"follower":
			preferences["positioning"] = "expendable_front_line"
		"adept":
			preferences["positioning"] = "support_formation"
		"priest", "high_priest":
			preferences["positioning"] = "protected_rear"
			preferences["bodyguard_priority"] = true
	
	# Supernatural influence affects deployment
	if current_influence >= ElderInfluence.MANIFESTATION:
		preferences["supernatural_terrain"] = true
		preferences["reality_anchor_points"] = true
	
	return preferences

## Process ritual actions and supernatural abilities
func activate_ritual_ability(ability_type: String, target_data: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "effect": "none", "cost": 1}
	
	if ritual_charges <= 0:
		return result
	
	match ability_type:
		"mind_blast":
			result = _process_mind_blast(target_data)
		"eldritch_protection":
			result = _process_eldritch_protection(target_data)
		"summon_manifestation":
			result = _process_summoning(target_data)
		"reality_distortion":
			result = _process_reality_distortion(target_data)
		"painful_transformation":
			result = _process_transformation(target_data)
		"sacrificial_empowerment":
			result = _process_sacrifice_ritual(target_data)
	
	if result.success:
		ritual_charges -= result.cost
		corruption_level += 1
		_check_elder_influence_increase()
	
	return result

## Process cultist fanaticism and devotion mechanics
func check_fanaticism_trigger(trigger_context: Dictionary) -> Dictionary:
	var fanaticism_result: Dictionary = {
		"triggered": false,
		"intensity": 0,
		"behavior_change": "none",
		"duration": 0
	}
	
	var trigger_type: String = trigger_context.get("trigger", "none")
	var allies_killed: int = trigger_context.get("allies_killed", 0)
	var elder_manifestation: bool = trigger_context.get("elder_present", false)
	var ritual_interrupted: bool = trigger_context.get("ritual_disrupted", false)
	
	# Calculate fanaticism trigger chance
	var trigger_chance: float = devotion_level * 0.15
	
	# Specific triggers increase chance
	match trigger_type:
		"ally_death":
			trigger_chance += allies_killed * 0.2
		"ritual_disruption":
			if ritual_interrupted:
				trigger_chance += 0.4
		"elder_manifestation":
			if elder_manifestation:
				trigger_chance += 0.6
		"blasphemy":
			trigger_chance += 0.5
	
	if randf() < trigger_chance:
		fanaticism_result.triggered = true
		fanaticism_result.intensity = mini(devotion_level + allies_killed, 5)
		fanaticism_result.duration = fanaticism_result.intensity * 2
		
		# Change AI behavior to aggressive when fanatical
		behavior = EnemyTacticalAI.AIPersonality.AGGRESSIVE
		fanaticism_result.behavior_change = "aggressive"
		
		# Temporary stat boosts
		_apply_fanaticism_boost(fanaticism_result.intensity)
	
	return fanaticism_result

## Get cultist loot table with ritual items
func get_cultist_loot_table() -> Dictionary:
	var loot_table: Dictionary = {
		"credits": _calculate_cultist_wealth(),
		"ritual_items": _get_ritual_item_drops(),
		"forbidden_knowledge": _get_knowledge_drops(),
		"mutations": _get_mutation_samples(),
		"artifacts": _get_elder_artifacts()
	}
	
	return loot_table

## Private Methods

func _setup_cultist() -> void:
	enemy_name = "Cultist"
	
	# Cultists vary widely in physical capability
	_max_health = 60 # Generally weaker physically but with supernatural resilience
	_current_health = _max_health
	movement_range = 4
	weapon_range = 3 # Ritual weapons tend to be short-range
	
	# Supernatural characteristics
	fanaticism_bonus = 2
	fear_immunity = false
	pain_tolerance = 1
	ritual_power = 1

func _apply_cultist_modifiers() -> void:
	# Devotion level affects basic capabilities
	_max_health += devotion_level * 5
	fanaticism_bonus += (devotion_level - 3) # Higher devotion = more fanatical
	
	# Hierarchy affects stats and abilities
	match cult_hierarchy:
		"follower":
			# Baseline cultist
			pass
		"adept":
			_max_health += 10
			ritual_power += 1
			weapon_range += 1
		"priest":
			_max_health += 25
			ritual_power += 2
			fear_immunity = true
			pain_tolerance += 1
		"high_priest":
			_max_health += 50
			ritual_power += 3
			fear_immunity = true
			pain_tolerance += 2
			fanaticism_bonus += 2
	
	# Elder being influence affects base attributes
	match elder_being:
		"void_entity":
			pain_tolerance += 1
			corruption_level += 1
		"star_god":
			ritual_power += 1
			_max_health += 15
		"machine_intelligence":
			fear_immunity = true
			movement_range += 1
	
	# Mutations provide physical changes
	_apply_mutation_effects()
	
	_current_health = _max_health

func _apply_mutation_effects() -> void:
	match mutation_level:
		1: # Minor mutations
			_max_health += 10
			pain_tolerance += 1
		2: # Moderate mutations
			_max_health += 20
			movement_range += 1
			weapon_range += 1
		3: # Major mutations
			_max_health += 35
			movement_range += 2
			ritual_power += 1
			pain_tolerance += 2

func _initialize_supernatural_abilities() -> void:
	# Set initial elder influence based on hierarchy and devotion
	if cult_hierarchy == "high_priest" and devotion_level >= 4:
		current_influence = ElderInfluence.MANIFESTATION
	elif cult_hierarchy == "priest" and devotion_level >= 3:
		current_influence = ElderInfluence.WHISPERS
	elif devotion_level >= 4:
		current_influence = ElderInfluence.WHISPERS
	else:
		current_influence = ElderInfluence.NONE

func _check_elder_influence_increase() -> void:
	# Corruption can increase elder influence
	if corruption_level >= 5 and current_influence < ElderInfluence.POSSESSION:
		current_influence = int(current_influence) + 1
		corruption_level = 0 # Reset corruption counter

func _process_mind_blast(target_data: Dictionary) -> Dictionary:
	var success_chance: float = 0.4 + (ritual_power * 0.15)
	if randf() < success_chance:
		return {"success": true, "effect": "mind_blast", "cost": 1, "duration": 3}
	return {"success": false, "effect": "none", "cost": 1}

func _process_eldritch_protection(target_data: Dictionary) -> Dictionary:
	var protection_strength: int = ritual_power + devotion_level
	return {"success": true, "effect": "eldritch_ward", "cost": 1, "strength": protection_strength}

func _process_summoning(target_data: Dictionary) -> Dictionary:
	if ritual_focus != "summoning":
		return {"success": false, "effect": "none", "cost": 2}
	
	var summon_chance: float = 0.2 + (ritual_power * 0.1) + (devotion_level * 0.05)
	if randf() < summon_chance:
		return {"success": true, "effect": "manifestation_summoned", "cost": 2}
	return {"success": false, "effect": "summoning_failed", "cost": 2}

func _process_reality_distortion(target_data: Dictionary) -> Dictionary:
	if current_influence < ElderInfluence.MANIFESTATION:
		return {"success": false, "effect": "insufficient_influence", "cost": 3}
	
	return {"success": true, "effect": "reality_distorted", "cost": 3, "radius": ritual_power * 2}

func _process_transformation(target_data: Dictionary) -> Dictionary:
	if ritual_focus != "transformation":
		return {"success": false, "effect": "none", "cost": 2}
	
	var transformation_bonus: int = mutation_level + ritual_power
	return {"success": true, "effect": "temporary_mutation", "cost": 2, "bonus": transformation_bonus}

func _process_sacrifice_ritual(target_data: Dictionary) -> Dictionary:
	if ritual_focus != "sacrifice":
		return {"success": false, "effect": "none", "cost": 1}
	
	var sacrifice_target: String = target_data.get("target", "none")
	if sacrifice_target != "none":
		var empowerment: int = 2 + ritual_power
		return {"success": true, "effect": "sacrifice_empowerment", "cost": 1, "power": empowerment}
	
	return {"success": false, "effect": "no_sacrifice_target", "cost": 1}

func _apply_fanaticism_boost(intensity: int) -> void:
	# Temporary stat increases during fanaticism
	var temp_health: int = intensity * 10
	_max_health += temp_health
	_current_health += temp_health
	
	movement_range += intensity
	fanaticism_bonus += intensity

func _calculate_cultist_wealth() -> int:
	# Cultists typically have little personal wealth
	var base_credits: int = 25
	
	match cult_hierarchy:
		"follower": base_credits = 25
		"adept": base_credits = 75
		"priest": base_credits = 150
		"high_priest": base_credits = 300
	
	# Some elder beings provide material wealth
	if elder_being == "machine_intelligence":
		base_credits = roundi(base_credits * 1.5)
	
	return base_credits

func _get_ritual_item_drops() -> Array[Dictionary]:
	var ritual_drops: Array[Dictionary] = []
	
	# Basic ritual items for all cultists
	ritual_drops.append({
		"type": "ritual_component",
		"name": "Cult Symbol",
		"value": 50,
		"chance": 0.8
	})
	
	# Hierarchy-specific items
	match cult_hierarchy:
		"adept":
			ritual_drops.append({
				"type": "tome",
				"name": "Forbidden Scroll",
				"value": 200,
				"chance": 0.4
			})
		"priest":
			ritual_drops.append({
				"type": "artifact",
				"name": "Ritual Focus",
				"value": 500,
				"chance": 0.3
			})
		"high_priest":
			ritual_drops.append({
				"type": "major_artifact",
				"name": "Elder Relic",
				"value": 1500,
				"chance": 0.2
			})
	
	return ritual_drops

func _get_knowledge_drops() -> Array[Dictionary]:
	var knowledge: Array[Dictionary] = []
	
	# Cult secrets based on devotion level
	if devotion_level >= 3:
		knowledge.append({
			"type": "information",
			"name": "Cult Secrets",
			"value": devotion_level * 100,
			"chance": 0.3
		})
	
	# Elder being knowledge
	knowledge.append({
		"type": "forbidden_lore",
		"name": elder_being.capitalize() + " Lore",
		"value": 300,
		"chance": 0.2
	})
	
	return knowledge

func _get_mutation_samples() -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	
	if mutation_level > 0:
		samples.append({
			"type": "biological",
			"name": "Mutation Sample",
			"quality": mutation_level,
			"value": mutation_level * 150,
			"chance": 0.25
		})
	
	return samples

func _get_elder_artifacts() -> Array[Dictionary]:
	var artifacts: Array[Dictionary] = []
	
	# High-level cultists may carry elder artifacts
	if cult_hierarchy in ["priest", "high_priest"] and current_influence >= ElderInfluence.MANIFESTATION:
		artifacts.append({
			"type": "elder_artifact",
			"name": "Otherworldly Relic",
			"power": current_influence,
			"value": 2000,
			"chance": 0.1
		})
	
	return artifacts