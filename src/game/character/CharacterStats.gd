class_name FiveParsecsCharacterStats
extends Resource

# Base Stats
@export var reactions: int = 3
@export var speed: int = 3
@export var combat_skill: int = 3
@export var toughness: int = 3
@export var savvy: int = 3
@export var luck: int = 3

# Derived Stats
@export var max_health: int = 10
@export var current_health: int = 10
@export var level: int = 1

# Temporary Modifiers
var stat_modifiers: Dictionary = {
	"reactions": 0,
	"speed": 0,
	"combat_skill": 0,
	"toughness": 0,
	"savvy": 0,
	"luck": 0
}

func _init() -> void:
	reset_to_base_stats()

func reset_to_base_stats() -> void:
	reactions = 3
	speed = 3
	combat_skill = 3
	toughness = 3
	savvy = 3
	luck = 3
	level = 1
	
	_recalculate_max_health()
	current_health = max_health
	
	stat_modifiers.clear()
	stat_modifiers = {
		"reactions": 0,
		"speed": 0,
		"combat_skill": 0,
		"toughness": 0,
		"savvy": 0,
		"luck": 0
	}

func _recalculate_max_health() -> void:
	max_health = 8 + (toughness * 2)
	if current_health > max_health:
		current_health = max_health

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)

func apply_stat_bonus(stat_name: String, bonus: int) -> void:
	match stat_name:
		"REACTIONS":
			reactions += bonus
		"SPEED":
			speed += bonus
		"COMBAT_SKILL":
			combat_skill += bonus
		"TOUGHNESS":
			toughness += bonus
			_recalculate_max_health()
		"SAVVY":
			savvy += bonus
		"LUCK":
			luck += bonus

func apply_temporary_modifier(stat_name: String, modifier: int) -> void:
	if stat_modifiers.has(stat_name.to_lower()):
		stat_modifiers[stat_name.to_lower()] += modifier

func remove_temporary_modifier(stat_name: String, modifier: int) -> void:
	if stat_modifiers.has(stat_name.to_lower()):
		stat_modifiers[stat_name.to_lower()] -= modifier

func get_effective_stat(stat_name: String) -> int:
	var base_value = 0
	match stat_name.to_upper():
		"REACTIONS":
			base_value = reactions
		"SPEED":
			base_value = speed
		"COMBAT_SKILL":
			base_value = combat_skill
		"TOUGHNESS":
			base_value = toughness
		"SAVVY":
			base_value = savvy
		"LUCK":
			base_value = luck
	
	return base_value + stat_modifiers.get(stat_name.to_lower(), 0)

func serialize() -> Dictionary:
	return {
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"luck": luck,
		"max_health": max_health,
		"current_health": current_health,
		"level": level,
		"stat_modifiers": stat_modifiers
	}

func deserialize(data: Dictionary) -> void:
	reactions = data.get("reactions", 3)
	speed = data.get("speed", 3)
	combat_skill = data.get("combat_skill", 3)
	toughness = data.get("toughness", 3)
	savvy = data.get("savvy", 3)
	luck = data.get("luck", 3)
	level = data.get("level", 1)
	
	max_health = data.get("max_health", 10)
	current_health = data.get("current_health", max_health)
	
	stat_modifiers.clear()
	for key in data.get("stat_modifiers", {}).keys():
		stat_modifiers[key] = data.stat_modifiers[key]
