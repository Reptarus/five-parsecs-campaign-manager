class_name CharacterStats
extends Resource

signal stats_changed

# Core Rules base stats with proper limits
@export var reactions: int = 1:
	set(value):
		reactions = clampi(value, 0, 6)  # Max 6 for reactions
		stats_changed.emit()
	get:
		return reactions

@export var speed: int = 4:
	set(value):
		speed = clampi(value, 0, 8)  # Max 8 for speed
		stats_changed.emit()
	get:
		return speed

@export var combat_skill: int = 0:
	set(value):
		combat_skill = clampi(value, -3, 3)  # Range -3 to +3 for combat skill
		stats_changed.emit()
	get:
		return combat_skill

@export var toughness: int = 3:
	set(value):
		toughness = clampi(value, 0, 6)  # Max 6 for toughness
		stats_changed.emit()
	get:
		return toughness

@export var savvy: int = 0:
	set(value):
		savvy = clampi(value, -3, 3)  # Range -3 to +3 for savvy
		stats_changed.emit()
	get:
		return savvy

@export var luck: int = 0:
	set(value):
		luck = clampi(value, 0, 6)  # Max 6 for luck
		stats_changed.emit()
	get:
		return luck

# Core Rules derived stats
@export var max_health: int = 10:
	set(value):
		max_health = maxi(value, 1)  # Minimum 1 health
		current_health = mini(current_health, max_health)
		stats_changed.emit()
	get:
		return max_health

@export var current_health: int = 10:
	set(value):
		current_health = clampi(value, 0, max_health)
		stats_changed.emit()
	get:
		return current_health

@export var morale: int = 10:
	set(value):
		morale = clampi(value, 0, 10)  # Range 0-10 for morale
		stats_changed.emit()
	get:
		return morale

@export var experience: int = 0:
	set(value):
		experience = maxi(value, 0)  # Can't have negative XP
		stats_changed.emit()
	get:
		return experience

@export var level: int = 1:
	set(value):
		level = maxi(value, 1)  # Minimum level 1
		stats_changed.emit()
	get:
		return level

# Core Rules advancement tracking
var advances_available: int = 0:
	set(value):
		advances_available = maxi(value, 0)  # Can't have negative advances
		stats_changed.emit()
	get:
		return advances_available

func _init() -> void:
	reset_to_base_stats()

func reset_to_base_stats() -> void:
	reactions = 1
	speed = 4
	combat_skill = 0
	toughness = 3
	savvy = 0
	luck = 0
	
	max_health = 10
	current_health = max_health
	morale = 10
	experience = 0
	level = 1
	advances_available = 0
	
	stats_changed.emit()

func can_improve_stat(stat_name: String) -> bool:
	# Core Rules stat improvement limits
	match stat_name.to_lower():
		"reactions": return reactions < 6
		"speed": return speed < 8
		"combat_skill": return combat_skill < 3
		"toughness": return toughness < 6
		"savvy": return savvy < 3
		"luck": return luck < 6
		_: return false

func improve_stat(stat_name: String) -> bool:
	if not can_improve_stat(stat_name):
		return false
		
	match stat_name:
		"reactions": reactions += 1
		"speed": speed += 1
		"combat_skill": combat_skill += 1
		"toughness": toughness += 1
		"savvy": savvy += 1
		"luck": luck += 1
		_: return false
	
	stats_changed.emit()
	return true

func get_stat_value(stat_name: String) -> int:
	match stat_name:
		"reactions": return reactions
		"speed": return speed
		"combat_skill": return combat_skill
		"toughness": return toughness
		"savvy": return savvy
		"luck": return luck
		_: return 0

func apply_stat_bonus(stat_name: String, bonus: int) -> void:
	match stat_name:
		"REACTIONS": reactions = min(reactions + bonus, 6)
		"SPEED": speed = min(speed + bonus, 8)
		"COMBAT_SKILL": combat_skill = min(combat_skill + bonus, 3)
		"TOUGHNESS": toughness = min(toughness + bonus, 6)
		"SAVVY": savvy = min(savvy + bonus, 3)
		"LUCK": luck = min(luck + bonus, 3)
	stats_changed.emit()

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	stats_changed.emit()

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	stats_changed.emit()

func modify_morale(amount: int) -> void:
	morale = clamp(morale + amount, 0, 10)
	stats_changed.emit()

func add_experience(amount: int) -> void:
	experience += amount
	check_level_up()

func check_level_up() -> void:
	# Core Rules experience thresholds
	var xp_needed = level * 100
	if experience >= xp_needed:
		level_up()

func level_up() -> void:
	level += 1
	advances_available += 1

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
		"morale": morale,
		"experience": experience,
		"level": level,
		"advances_available": advances_available
	}

func deserialize(data: Dictionary) -> void:
	reactions = data.get("reactions", 1)
	speed = data.get("speed", 4)
	combat_skill = data.get("combat_skill", 0)
	toughness = data.get("toughness", 3)
	savvy = data.get("savvy", 0)
	luck = data.get("luck", 0)
	max_health = data.get("max_health", 10)
	current_health = data.get("current_health", max_health)
	morale = data.get("morale", 10)
	experience = data.get("experience", 0)
	level = data.get("level", 1)
	advances_available = data.get("advances_available", 0)
	
	stats_changed.emit()
