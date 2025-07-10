extends "res://src/base/character/character_base.gd"
class_name CoreCharacter

## Core implementation of character for Five Parsecs
##
## Extends BaseCharacter with game-specific functionality for
## the Five Parsecs From Home rule system.

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Five Parsecs specific character properties
var character_class: int = GlobalEnums.CharacterClass.NONE
var origin: int = GlobalEnums.Origin.NONE
var background: int = GlobalEnums.Background.NONE
var motivation: int = GlobalEnums.Motivation.NONE

# Additional Five Parsecs stats
var savvy: int = 0
var luck: int = 0
var training: int = GlobalEnums.Training.NONE

# Equipment specific to Five Parsecs
var weapons: Array[Resource] = [] # Weapon resources
var armor: Array[Resource] = [] # Armor resources
var items: Array[Resource] = [] # Item resources

# Character type flags for Five Parsecs
var is_bot: bool = false
var is_soulless: bool = false
var is_human: bool = false
var is_captain: bool = false  # Captain status for crew management

# Additional traits for Five Parsecs
var traits: Array[String] = []

# Five Parsecs relationships and connections
var patrons: Array = []  # Array[Dictionary] - Patron relationships
var rivals: Array = []   # Array[Dictionary] - Rival relationships
var personal_equipment: Dictionary = {}  # Enhanced equipment system
var character_relationships: Dictionary = {}  # Additional relationships

# Character advancement tracking
var credits_earned: int = 0
var missions_completed: int = 0
var experience_gained: int = 0

func _init() -> void:
	super._init()
	# Set a default character class as the character type
	character_type = GlobalEnums.CharacterClass.SOLDIER

# Override character_name property to provide access
var character_name: String:
	get: return _character_name
	set(_value):
		_character_name = _value

# Maximum values for stats (extending the base stats)
const MAX_STATS = {
	"reaction": 6,
	"combat": 5,
	"speed": 8,
	"savvy": 5,
	"toughness": 6,
	"luck": 1 # Humans can have 3
}

## Five Parsecs specific methods

## Roll for a stat check using appropriate dice
func roll_stat_check(stat_name: String, difficulty: int = 0) -> bool:
	var stat_value: int = 0
	match stat_name.to_lower():
		"reaction": stat_value = reaction
		"combat": stat_value = combat
		"toughness": stat_value = toughness
		"speed": stat_value = speed
		"savvy": stat_value = savvy
		"luck": stat_value = luck

	# Roll dice logic here
	var roll = randi() % 6 + 1 # Simulate d6 roll
	return roll + stat_value >= difficulty

## Apply training benefits
func apply_training_benefits() -> void:
	match training:
		GlobalEnums.Training.PILOT:
			combat += 1
		GlobalEnums.Training.MEDICAL:
			savvy += 1
		GlobalEnums.Training.SPECIALIST:
			reaction += 1
		# Add other training types as needed

## Check if character can use a specific weapon type
func can_use_weapon_type(weapon_type: int) -> bool:
	match weapon_type:
		GlobalEnums.WeaponType.HEAVY:
			return character_class == GlobalEnums.CharacterClass.SOLDIER
		GlobalEnums.WeaponType.SPECIAL:
			return character_class == GlobalEnums.CharacterClass.ENGINEER
		_:
			return true

## Generate a display description for the character
func get_character_description() -> String:
	var desc: String = "%s - %s %s" % [
		character_name,
		GlobalEnums.CharacterClass.keys()[character_class],
		GlobalEnums.Origin.keys()[origin]
	]

	if is_wounded:
		desc += " (Wounded)"
	elif is_dead:
		desc += " (Dead)"

	return desc

## Apply Five Parsecs specific status effects
func apply_campaign_effect(effect_type: int, duration: int = 1) -> void:
	var effect = {
		"id": "campaign_effect_%s" % effect_type,
		"type": effect_type,
		"duration": duration
	}
	apply_status_effect(effect)

## Process character recovery between campaign turns
func process_recovery() -> bool:
	var recovered: bool = false
	if is_wounded and not is_dead:
		# Roll recovery check
		var recovery_roll = randi() % 6 + 1 + toughness
		if recovery_roll >= 6:
			is_wounded = false
			health = maxi(1, max_health / 2.0)
			recovered = true

	# Process status effects
	for i: int in range((safe_call_method(status_effects, "size") as int) - 1, -1, -1):
		var effect = status_effects[i]
		if effect.has("duration"):
			effect.duration -= 1
			if effect.duration <= 0:
				status_effects.remove_at(i)

	return recovered

## Add a trait to the character
func add_trait(trait_name: String) -> void:
	if not trait_name in traits:
		traits.append(trait_name)

## Check if character has a specific trait
func has_trait(trait_name: String) -> bool:
	return trait_name in traits

## Get character customization completeness level (0.0 - 1.0)
func get_customization_completeness() -> float:
	var completeness_score = 0.0
	var total_criteria = 8.0  # Total customization criteria
	
	# Basic info completeness (3 criteria)
	if character_name and not character_name.is_empty():
		completeness_score += 1.0
	if background > 0:
		completeness_score += 1.0
	if motivation > 0:
		completeness_score += 1.0
	
	# Attributes completeness (2 criteria)
	if combat >= 0 and toughness >= 3:  # Valid attribute ranges
		completeness_score += 1.0
	if max_health == toughness + 2:  # Proper health calculation
		completeness_score += 1.0
	
	# Relationships completeness (2 criteria)
	if patrons.size() > 0 or rivals.size() > 0:
		completeness_score += 1.0
	if traits.size() > 0:
		completeness_score += 1.0
	
	# Equipment completeness (1 criterion)
	if personal_equipment.size() > 0 or credits_earned > 0:
		completeness_score += 1.0
	
	return completeness_score / total_criteria

## Get character summary for display
func get_character_summary() -> Dictionary:
	return {
		"name": character_name,
		"background": GlobalEnums.Background.keys()[background] if background > 0 else "None",
		"motivation": GlobalEnums.Motivation.keys()[motivation] if motivation > 0 else "None",
		"class": GlobalEnums.CharacterClass.keys()[character_class] if character_class > 0 else "None",
		"stats": {
			"combat": combat,
			"reaction": reaction,
			"toughness": toughness,
			"savvy": savvy,
			"speed": speed,
			"health": max_health
		},
		"relationships": {
			"patrons": patrons.size(),
			"rivals": rivals.size(),
			"traits": traits.size()
		},
		"is_captain": is_captain,
		"completeness": get_customization_completeness()
	}

## Enhanced serialization for campaign save/load
func serialize_enhanced() -> Dictionary:
	var base_data = serialize()
	
	# Add new relationship and equipment data
	base_data["patrons"] = patrons.duplicate()
	base_data["rivals"] = rivals.duplicate()
	base_data["personal_equipment"] = personal_equipment.duplicate()
	base_data["character_relationships"] = character_relationships.duplicate()
	base_data["credits_earned"] = credits_earned
	base_data["missions_completed"] = missions_completed
	base_data["experience_gained"] = experience_gained
	base_data["is_captain"] = is_captain
	
	return base_data

## Enhanced deserialization for campaign load
func deserialize_enhanced(data: Dictionary) -> void:
	deserialize(data)  # Call base deserialization
	
	# Load new relationship and equipment data
	patrons = data.get("patrons", [])
	rivals = data.get("rivals", [])
	personal_equipment = data.get("personal_equipment", {})
	character_relationships = data.get("character_relationships", {})
	credits_earned = data.get("credits_earned", 0)
	missions_completed = data.get("missions_completed", 0)
	experience_gained = data.get("experience_gained", 0)
	is_captain = data.get("is_captain", false)

## Serialize character data
func serialize() -> Dictionary:
	var data: Dictionary = {
		"character_id": character_id,
		"character_name": character_name,
		"character_class": character_class,
		"origin": origin,
		"background": background,
		"motivation": motivation,
		"level": level,
		"experience": experience,
		"health": health,
		"max_health": max_health,
		"reaction": reaction,
		"combat": combat,
		"toughness": toughness,
		"speed": speed,
		"savvy": savvy,
		"luck": luck,
		"training": training,
		"is_bot": is_bot,
		"is_soulless": is_soulless,
		"is_human": is_human,
		"traits": traits,
		"is_wounded": is_wounded,
		"is_dead": is_dead,
		"status_effects": status_effects
	}
	return data

## Deserialize character data
func deserialize(data: Dictionary) -> void:
	character_id = data.get("character_id", "")
	character_name = data.get("character_name", "")
	character_class = data.get("character_class", GlobalEnums.CharacterClass.NONE)
	origin = data.get("origin", GlobalEnums.Origin.NONE)
	background = data.get("background", GlobalEnums.Background.NONE)
	motivation = data.get("motivation", GlobalEnums.Motivation.NONE)
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	health = data.get("health", 10)
	max_health = data.get("max_health", 10)
	_reaction = data.get("reaction", 0)
	_combat = data.get("combat", 0)
	_toughness = data.get("toughness", 3)
	_speed = data.get("speed", 4)
	savvy = data.get("savvy", 0)
	luck = data.get("luck", 0)
	training = data.get("training", GlobalEnums.Training.NONE)
	is_bot = data.get("is_bot", false)
	is_soulless = data.get("is_soulless", false)
	is_human = data.get("is_human", false)
	traits = data.get("traits", [])
	is_wounded = data.get("is_wounded", false)
	is_dead = data.get("is_dead", false)
	status_effects = data.get("status_effects", [])

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null