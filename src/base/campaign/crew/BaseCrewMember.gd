@tool
extends Node

signal stats_changed
signal health_changed(new_health: int)

const MAX_STAT_VALUE: int = 6

# Basic Character Info
@export var character_name: String = "":
	set(value):
		if value == null or value.strip_edges().is_empty():
			push_error("Character name cannot be empty")
			return
		character_name = value.strip_edges()
		if character:
			notify_property_list_changed()

# Core base stats
@export var reactions: int = 1:
	set(value):
		reactions = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var speed: int = 4:
	set(value):
		speed = clampi(value, 0, 8) # Speed has a max of 8
		stats_changed.emit()

@export var combat_skill: int = 0:
	set(value):
		combat_skill = clampi(value, 0, 3) # Combat skill has a max of 3
		stats_changed.emit()

@export var toughness: int = 3:
	set(value):
		toughness = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var savvy: int = 0:
	set(value):
		savvy = clampi(value, 0, 3) # Savvy has a max of 3
		stats_changed.emit()

@export var luck: int = 0:
	set(value):
		luck = clampi(value, 0, 3) # Luck has a max of 3
		stats_changed.emit()

# Derived stats
@export var health: int = 10:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health)

@export var max_health: int = 10
@export var morale: int = 10
@export var experience: int = 0
@export var level: int = 1

# Character data
var character = null
var special_ability: String = ""
var advances_available: int = 0
var specialization: String = ""
var traits: Array[String] = []
var relationships: Dictionary = {}
var inventory = null
var active_weapon = null
var status: int = 0 # Will be defined by game-specific enums

@export var items: Array[Dictionary] = []
@export var character_class: int = 0 # Will be defined by game-specific enums
@export var weapon_proficiencies: Array[int] = []
@export var starting_items: Array[int] = []
@export var starting_gadgets: Array[int] = []

func _ready() -> void:
	_initialize_character()
	set_default_stats()
	equip_default_gear()

func _initialize_character() -> void:
	# To be implemented by derived classes
	push_error("_initialize_character must be implemented by derived classes")

func _init() -> void:
	# Basic initialization - detailed setup happens in _ready
	_initialize_character()
	_apply_class_bonuses()

func _apply_class_bonuses() -> void:
	# To be implemented by derived classes
	push_error("_apply_class_bonuses must be implemented by derived classes")

func set_default_stats() -> void:
	# To be implemented by derived classes
	push_error("set_default_stats must be implemented by derived classes")

func equip_default_gear() -> void:
	# To be implemented by derived classes
	push_error("equip_default_gear must be implemented by derived classes")

func add_experience(amount: int) -> void:
	experience += amount
	check_level_up()

func check_level_up() -> void:
	# Base implementation - can be overridden by derived classes
	var next_level_threshold = level * 5
	if experience >= next_level_threshold:
		level_up()

func level_up() -> void:
	level += 1
	advances_available += 1
	
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		handle_incapacitation()

func heal(amount: int) -> void:
	health = clampi(health + amount, 0, max_health)

func handle_incapacitation() -> void:
	# To be implemented by derived classes
	push_error("handle_incapacitation must be implemented by derived classes")

func apply_status_effect(effect_data: Dictionary) -> void:
	# Base implementation for applying status effects
	# effect_data should contain at minimum:
	# - "effect": String (the effect name)
	# - "duration": int (how many turns/rounds the effect lasts)
	# To be implemented by derived classes
	push_error("apply_status_effect must be implemented by derived classes")

func remove_status_effect(effect_name: String) -> void:
	# To be implemented by derived classes
	push_error("remove_status_effect must be implemented by derived classes")

func get_stat_modifier(stat_name: String) -> int:
	# Base implementation for getting stat modifiers
	# To be implemented by derived classes
	push_error("get_stat_modifier must be implemented by derived classes")
	return 0

func to_dict() -> Dictionary:
	# Base implementation for serialization
	var data = {
		"character_name": character_name,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"luck": luck,
		"health": health,
		"max_health": max_health,
		"morale": morale,
		"experience": experience,
		"level": level,
		"character_class": character_class,
		"special_ability": special_ability,
		"advances_available": advances_available,
		"specialization": specialization,
		"traits": traits,
		"relationships": relationships,
		"items": items,
		"weapon_proficiencies": weapon_proficiencies,
		"status": status
	}
	return data

func from_dict(data: Dictionary) -> void:
	# Base implementation for deserialization
	if data.has("character_name"): character_name = data.character_name
	if data.has("reactions"): reactions = data.reactions
	if data.has("speed"): speed = data.speed
	if data.has("combat_skill"): combat_skill = data.combat_skill
	if data.has("toughness"): toughness = data.toughness
	if data.has("savvy"): savvy = data.savvy
	if data.has("luck"): luck = data.luck
	if data.has("health"): health = data.health
	if data.has("max_health"): max_health = data.max_health
	if data.has("morale"): morale = data.morale
	if data.has("experience"): experience = data.experience
	if data.has("level"): level = data.level
	if data.has("character_class"): character_class = data.character_class
	if data.has("special_ability"): special_ability = data.special_ability
	if data.has("advances_available"): advances_available = data.advances_available
	if data.has("specialization"): specialization = data.specialization
	if data.has("traits"): traits = data.traits
	if data.has("relationships"): relationships = data.relationships
	if data.has("items"): items = data.items
	if data.has("weapon_proficiencies"): weapon_proficiencies = data.weapon_proficiencies
	if data.has("status"): status = data.status