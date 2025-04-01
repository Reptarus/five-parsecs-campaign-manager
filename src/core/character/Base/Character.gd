@tool
extends "res://src/base/character/character_base.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/character/Base/Character.gd")

## Core implementation of character for Five Parsecs
##
## Extends BaseCharacter with game-specific functionality for
## the Five Parsecs From Home rule system.

const GameEnums = preload("res://src/core/enums/GameEnums.gd")

# Five Parsecs specific character properties
var character_class: int = GameEnums.CharacterClass.NONE
var origin: int = GameEnums.Origin.NONE
var background: int = GameEnums.Background.NONE
var motivation: int = GameEnums.Motivation.NONE

# Additional Five Parsecs stats
var _savvy: int = 0
var _luck: int = 0
var _training: int = GameEnums.Training.NONE

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

# Additional property getters/setters for Five Parsecs stats
var savvy: int:
	get: return _savvy
	set(value):
		_savvy = clampi(value, 0, MAX_STATS.savvy)

var luck: int:
	get: return _luck
	set(value):
		var max_luck = MAX_STATS.luck
		if is_human:
			max_luck = 3 # Humans can have more luck
		_luck = clampi(value, 0, max_luck)

var training: int:
	get: return _training
	set(value):
		if value in GameEnums.Training.values():
			_training = value

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
	var stat_value = 0
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
	var desc = "%s - %s %s" % [
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
	var recovered = false
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
		traits.append(trait_name)

## Check if character has a specific trait
func has_trait(trait_name: String) -> bool:
	return trait_name in traits

func initialize_from_data(character_data: Dictionary) -> void:
	# Set basic properties from data
	if character_data.has("name"):
		character_name = character_data.name
	
	if character_data.has("health"):
		health = character_data.health
	
	if character_data.has("max_health"):
		max_health = character_data.max_health
	
	if character_data.has("character_class"):
		character_class = character_data.character_class
	
	if character_data.has("origin"):
		origin = character_data.origin
	
	if character_data.has("background"):
		background = character_data.background
	
	if character_data.has("motivation"):
		motivation = character_data.motivation
	
	# Set Five Parsecs stats
	if character_data.has("savvy"):
		savvy = character_data.savvy
	
	if character_data.has("luck"):
		luck = character_data.luck
	
	if character_data.has("training"):
		_training = character_data.training
	
	# Set character type flags
	if character_data.has("is_bot"):
		is_bot = character_data.is_bot
	
	if character_data.has("is_soulless"):
		is_soulless = character_data.is_soulless
	
	if character_data.has("is_human"):
		is_human = character_data.is_human
	
	# Set traits
	if character_data.has("traits") and character_data.traits is Array:
		traits = character_data.traits.duplicate()
	
	# Handle equipment arrays
	if character_data.has("weapons") and character_data.weapons is Array:
		weapons.clear()
		for weapon_data in character_data.weapons:
			if typeof(weapon_data) == TYPE_DICTIONARY:
				var weapon_resource = load("res://src/core/systems/items/GameWeapon.gd").new()
				if weapon_resource.has_method("initialize_from_data"):
					weapon_resource.initialize_from_data(weapon_data)
				weapons.append(weapon_resource)
	
	if character_data.has("armor") and character_data.armor is Array:
		armor.clear()
		for armor_data in character_data.armor:
			if typeof(armor_data) == TYPE_DICTIONARY:
				var armor_resource = load("res://src/core/systems/items/GameArmor.gd").new()
				if armor_resource.has_method("initialize_from_data"):
					armor_resource.initialize_from_data(armor_data)
				armor.append(armor_resource)
	
	if character_data.has("items") and character_data.items is Array:
		items.clear()
		for item_data in character_data.items:
			if typeof(item_data) == TYPE_DICTIONARY:
				var item_resource = load("res://src/core/systems/items/GameItem.gd").new()
				if item_resource.has_method("initialize_from_data"):
					item_resource.initialize_from_data(item_data)
				items.append(item_resource)
