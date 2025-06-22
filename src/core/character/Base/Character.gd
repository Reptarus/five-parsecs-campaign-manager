@tool
extends "res://src/base/character/character_base.gd"
class_name CoreCharacter

## Core implementation of character for Five Parsecs
##
## Extends BaseCharacter with game-specific functionality for
## the Five Parsecs From Home rule system.

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Five Parsecs specific character properties
var character_class: int = GameEnums.CharacterClass.NONE
var origin: int = GameEnums.Origin.NONE
var background: int = GameEnums.Background.NONE
var motivation: int = GameEnums.Motivation.NONE

# Additional Five Parsecs stats
var savvy: int = 0
var luck: int = 0
var training: int = GameEnums.Training.NONE

# Equipment specific to Five Parsecs
var weapons: Array[Resource] = [] # Weapon resources
var armor: Array[Resource] = [] # Armor resources
var items: Array[Resource] = [] # Item resources

# Character type flags for Five Parsecs
var is_bot: bool = false
var is_soulless: bool = false
var is_human: bool = false

# Additional traits for Five Parsecs
var traits: Array[String] = []

func _init() -> void:
	super._init()
	# Set a default character class as the character type
	character_type = GameEnums.CharacterClass.SOLDIER

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
		GameEnums.Training.PILOT:
			combat += 1
		GameEnums.Training.MEDICAL:
			savvy += 1
		GameEnums.Training.SPECIALIST:
			reaction += 1
		# Add other training types as needed

## Check if character can use a specific weapon type
func can_use_weapon_type(weapon_type: int) -> bool:
	match weapon_type:
		GameEnums.WeaponType.HEAVY:
			return character_class == GameEnums.CharacterClass.SOLDIER
		GameEnums.WeaponType.SPECIAL:
			return character_class == GameEnums.CharacterClass.ENGINEER
		_:
			return true

## Generate a display description for the character
func get_character_description() -> String:
	var desc: String = "%s - %s %s" % [
		character_name,
		GameEnums.CharacterClass.keys()[character_class],
		GameEnums.Origin.keys()[origin]
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
			health = maxi(1, max_health / 2)
			recovered = true
	
	# Process status effects
	for i in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		if effect.has("duration"):
			effect.duration -= 1
			if effect.duration <= 0:
				status_effects.remove_at(i)
	
	return recovered

## Add a trait to the character
func add_trait(trait_name: String) -> void:
	if not trait_name in traits:
		traits.append(trait_name) # warning: return value discarded (intentional)

## Check if character has a specific trait
func has_trait(trait_name: String) -> bool:
	return trait_name in traits

## Serialize character data
func serialize() -> Dictionary:
	var data = {
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
	character_class = data.get("character_class", GameEnums.CharacterClass.NONE)
	origin = data.get("origin", GameEnums.Origin.NONE)
	background = data.get("background", GameEnums.Background.NONE)
	motivation = data.get("motivation", GameEnums.Motivation.NONE)
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
	training = data.get("training", GameEnums.Training.NONE)
	is_bot = data.get("is_bot", false)
	is_soulless = data.get("is_soulless", false)
	is_human = data.get("is_human", false)
	traits = data.get("traits", [])
	is_wounded = data.get("is_wounded", false)
	is_dead = data.get("is_dead", false)
	status_effects = data.get("status_effects", [])
