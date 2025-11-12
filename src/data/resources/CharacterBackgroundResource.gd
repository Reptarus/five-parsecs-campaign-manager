class_name CharacterBackgroundResource
extends Resource

## Character Background Resource
## Replaces JSON data with Godot's native resource system
## Optimized for Five Parsecs character creation

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""

# Stat modifications
@export var stat_bonuses: Dictionary = {}
@export var stat_penalties: Dictionary = {}

# Starting equipment and abilities
@export var starting_skills: Array[String] = []
@export var starting_gear: Array[Dictionary] = []
@export var special_abilities: Array[Dictionary] = []

# Background events and flavor
@export var background_events: Array[String] = []
@export var suitable_species: Array[String] = []
@export var tags: Array[String] = []

# Five Parsecs specific data
@export var patrons: Array[String] = []
@export var rivals: Array[String] = []
@export var story_points: int = 0
@export var credits: int = 0
@export var weapons: Array[String] = []
@export var gear: Array[String] = []
@export var gadgets: Array[String] = []
@export var rumors: Array[String] = []

func _init(p_id: String = "", p_name: String = "", p_description: String = "") -> void:
	id = p_id
	name = p_name
	description = p_description

func get_stat_bonus(stat_name: String) -> int:
	"""Get the stat bonus for a specific stat"""
	return stat_bonuses.get(stat_name, 0)

func get_stat_penalty(stat_name: String) -> int:
	"""Get the stat penalty for a specific stat"""
	return stat_penalties.get(stat_name, 0)

func get_total_stat_modifier(stat_name: String) -> int:
	"""Get the total stat modifier (bonus - penalty)"""
	return get_stat_bonus(stat_name) + get_stat_penalty(stat_name)

func has_special_ability(ability_name: String) -> bool:
	"""Check if this background has a specific special ability"""
	for ability in special_abilities:
		if ability.get("name", "") == ability_name:
			return true
	return false

func get_special_ability(ability_name: String) -> Dictionary:
	"""Get a specific special ability"""
	for ability in special_abilities:
		if ability.get("name", "") == ability_name:
			return ability
	return {}

func is_suitable_for_species(species_name: String) -> bool:
	"""Check if this background is suitable for a specific species"""
	return species_name in suitable_species

func has_tag(tag: String) -> bool:
	"""Check if this background has a specific tag"""
	return tag in tags

func get_starting_gear_by_type(gear_type: String) -> Array[String]:
	"""Get starting gear options for a specific type"""
	var options: Array[String] = []
	for gear in starting_gear:
		if gear.get("type", "") == gear_type:
			options.append_array(gear.get("options", []))
	return options

func to_dict() -> Dictionary:
	"""Convert resource to dictionary for serialization"""
	return {
		"id": id,
		"name": name,
		"description": description,
		"stat_bonuses": stat_bonuses,
		"stat_penalties": stat_penalties,
		"starting_skills": starting_skills,
		"starting_gear": starting_gear,
		"special_abilities": special_abilities,
		"background_events": background_events,
		"suitable_species": suitable_species,
		"tags": tags,
		"patrons": patrons,
		"rivals": rivals,
		"story_points": story_points,
		"credits": credits,
		"weapons": weapons,
		"gear": gear,
		"gadgets": gadgets,
		"rumors": rumors
	}

func from_dict(data: Dictionary) -> void:
	"""Load resource from dictionary"""
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	stat_bonuses = data.get("stat_bonuses", {})
	stat_penalties = data.get("stat_penalties", {})
	starting_skills = data.get("starting_skills", [])
	starting_gear = data.get("starting_gear", [])
	special_abilities = data.get("special_abilities", [])
	background_events = data.get("background_events", [])
	suitable_species = data.get("suitable_species", [])
	tags = data.get("tags", [])
	patrons = data.get("patrons", [])
	rivals = data.get("rivals", [])
	story_points = data.get("story_points", 0)
	credits = data.get("credits", 0)
	weapons = data.get("weapons", [])
	gear = data.get("gear", [])
	gadgets = data.get("gadgets", [])
	rumors = data.get("rumors", []) 