## Base character class for all game characters
class_name Character
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Basic Info
var character_name: String
var character_class: int # GameEnums.CharacterClass
var origin: int # GameEnums.Origin
var background: int # GameEnums.Background
var motivation: int # GameEnums.Motivation

# Stats with property setters for enforcing limits
var level: int = 1
var experience: int = 0
var health: int = 10
var max_health: int = 10

var _reaction: int = 0
var _combat: int = 0
var _toughness: int = 0
var _savvy: int = 0
var _luck: int = 0
var _training: int = GameEnums.Training.NONE

# Maximum values for stats
const MAX_STATS = {
	"reaction": 6,
	"combat": 5,
	"speed": 8,
	"savvy": 5,
	"toughness": 6,
	"luck": 1 # Humans can have 3
}

# Equipment
var weapons: Array = []
var armor: Array = []
var items: Array = []

# Skills and Abilities
var skills: Array = []
var abilities: Array = []
var traits: Array = []

# Status
var is_active: bool = true
var is_wounded: bool = false
var is_dead: bool = false
var status_effects: Array = []

# Character Type Flags
var is_bot: bool = false
var is_soulless: bool = false
var is_human: bool = false

# Property getters/setters for stats
var reaction: int:
	get: return _reaction
	set(value):
		_reaction = mini(value, MAX_STATS.reaction)

var combat: int:
	get: return _combat
	set(value):
		_combat = mini(value, MAX_STATS.combat)

var toughness: int:
	get: return _toughness
	set(value):
		var max_toughness = 4 if character_class == GameEnums.CharacterClass.ENGINEER else MAX_STATS.toughness
		_toughness = mini(value, max_toughness)

var savvy: int:
	get: return _savvy
	set(value):
		_savvy = mini(value, MAX_STATS.savvy)

var luck: int:
	get: return _luck
	set(value):
		var max_luck = 3 if is_human else MAX_STATS.luck
		_luck = mini(value, max_luck)

var training: int:
	get: return _training
	set(value):
		if is_soulless:
			return
		if _training == GameEnums.Training.NONE:
			_training = value

func _init() -> void:
	pass

func apply_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	is_wounded = health < max_health / 2
	is_dead = health <= 0

func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	is_wounded = health < max_health / 2

func add_experience(amount: int) -> bool:
	# Bots don't gain XP
	if is_bot:
		return false
		
	var leveled_up = false
	experience += amount
	
	# Check for level up
	while experience >= get_experience_for_next_level():
		level_up()
		leveled_up = true
	
	return leveled_up

func level_up() -> void:
	level += 1
	max_health += 2
	health = max_health

func get_experience_for_next_level() -> int:
	return level * 1000

func add_skill(skill_id: int) -> void:
	if not skill_id in skills:
		skills.append(skill_id)

func has_skill(skill_id: int) -> bool:
	return skill_id in skills

func add_ability(ability_id: int) -> void:
	if not ability_id in abilities:
		abilities.append(ability_id)

func has_ability(ability_id: int) -> bool:
	return ability_id in abilities

func add_trait(trait_id: int) -> void:
	if not trait_id in traits:
		traits.append(trait_id)

func has_trait(trait_id: int) -> bool:
	return trait_id in traits

func add_status_effect(effect: Dictionary) -> void:
	status_effects.append(effect)

func remove_status_effect(effect_id: String) -> void:
	for effect in status_effects:
		if effect.id == effect_id:
			status_effects.erase(effect)
			break

func has_status_effect(effect_id: String) -> bool:
	for effect in status_effects:
		if effect.id == effect_id:
			return true
	return false

func add_item(item: Dictionary) -> void:
	match item.type:
		"weapon":
			weapons.append(item)
		"armor":
			armor.append(item)
		_:
			items.append(item)

func remove_item(item: Dictionary) -> void:
	match item.type:
		"weapon":
			weapons.erase(item)
		"armor":
			armor.erase(item)
		_:
			items.erase(item)

func has_item(item: Dictionary) -> bool:
	match item.type:
		"weapon":
			return item in weapons
		"armor":
			return item in armor
		_:
			return item in items

# Serialization
func to_dictionary() -> Dictionary:
	return {
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
		"savvy": savvy,
		"luck": luck,
		"weapons": weapons.duplicate(),
		"armor": armor.duplicate(),
		"items": items.duplicate(),
		"skills": skills.duplicate(),
		"abilities": abilities.duplicate(),
		"traits": traits.duplicate(),
		"training": training,
		"is_active": is_active,
		"is_wounded": is_wounded,
		"is_dead": is_dead,
		"status_effects": status_effects.duplicate(),
		"is_bot": is_bot,
		"is_soulless": is_soulless,
		"is_human": is_human
	}

func from_dictionary(data: Dictionary) -> void:
	character_name = data.get("character_name", "")
	character_class = data.get("character_class", 0)
	origin = data.get("origin", 0)
	background = data.get("background", 0)
	motivation = data.get("motivation", 0)
	
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	health = data.get("health", 10)
	max_health = data.get("max_health", 10)
	reaction = data.get("reaction", 0)
	combat = data.get("combat", 0)
	toughness = data.get("toughness", 0)
	savvy = data.get("savvy", 0)
	luck = data.get("luck", 0)
	
	weapons = data.get("weapons", []).duplicate()
	armor = data.get("armor", []).duplicate()
	items = data.get("items", []).duplicate()
	
	skills = data.get("skills", []).duplicate()
	abilities = data.get("abilities", []).duplicate()
	traits = data.get("traits", []).duplicate()
	training = data.get("training", GameEnums.Training.NONE)
	
	is_active = data.get("is_active", true)
	is_wounded = data.get("is_wounded", false)
	is_dead = data.get("is_dead", false)
	status_effects = data.get("status_effects", []).duplicate()
	
	is_bot = data.get("is_bot", false)
	is_soulless = data.get("is_soulless", false)
	is_human = data.get("is_human", false)
