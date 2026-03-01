class_name CharacterMotivationResource
extends Resource

## Character Motivation Resource
## Replaces JSON data with Godot's native resource system
## Optimized for Five Parsecs character creation

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""

# Stat modifications
@export var stat_bonuses: Dictionary = {}
@export var stat_penalties: Dictionary = {}

# Five Parsecs specific data
@export var patrons: Array[String] = []
@export var rivals: Array[String] = []
@export var story_points: int = 0
@export var credits: int = 0
@export var weapons: Array[String] = []
@export var gear: Array[String] = []
@export var gadgets: Array[String] = []
@export var rumors: Array[String] = []
@export var xp_bonus: int = 0

# Special effects
@export var special_effects: Array[Dictionary] = []
@export var tags: Array[String] = []

func _init(p_id: String = "", p_name: String = "", p_description: String = "") -> void:
	id = p_id
	name = p_name
	description = p_description

func get_stat_bonus(stat_name: String) -> int:
	## Get the stat bonus for a specific stat
	return stat_bonuses.get(stat_name, 0)

func get_stat_penalty(stat_name: String) -> int:
	## Get the stat penalty for a specific stat
	return stat_penalties.get(stat_name, 0)

func get_total_stat_modifier(stat_name: String) -> int:
	## Get the total stat modifier (bonus - penalty)
	return get_stat_bonus(stat_name) + get_stat_penalty(stat_name)

func has_special_effect(effect_name: String) -> bool:
	## Check if this motivation has a specific special effect
	for effect in special_effects:
		if effect.get("name", "") == effect_name:
			return true
	return false

func get_special_effect(effect_name: String) -> Dictionary:
	## Get a specific special effect
	for effect in special_effects:
		if effect.get("name", "") == effect_name:
			return effect
	return {}

func has_tag(tag: String) -> bool:
	## Check if this motivation has a specific tag
	return tag in tags

func to_dict() -> Dictionary:
	## Convert resource to dictionary for serialization
	return {
		"id": id,
		"name": name,
		"description": description,
		"stat_bonuses": stat_bonuses,
		"stat_penalties": stat_penalties,
		"patrons": patrons,
		"rivals": rivals,
		"story_points": story_points,
		"credits": credits,
		"weapons": weapons,
		"gear": gear,
		"gadgets": gadgets,
		"rumors": rumors,
		"xp_bonus": xp_bonus,
		"special_effects": special_effects,
		"tags": tags
	}

func from_dict(data: Dictionary) -> void:
	## Load resource from dictionary
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	stat_bonuses = data.get("stat_bonuses", {})
	stat_penalties = data.get("stat_penalties", {})
	patrons = data.get("patrons", [])
	rivals = data.get("rivals", [])
	story_points = data.get("story_points", 0)
	credits = data.get("credits", 0)
	weapons = data.get("weapons", [])
	gear = data.get("gear", [])
	gadgets = data.get("gadgets", [])
	rumors = data.get("rumors", [])
	xp_bonus = data.get("xp_bonus", 0)
	special_effects = data.get("special_effects", [])
	tags = data.get("tags", []) 
