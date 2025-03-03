@tool
class_name CharacterUnit
extends Node2D

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Character Properties
var character_id: String = ""
var character_name: String = ""
var faction: int = 0 # Player faction
var unit_type: int = 0 # Soldier type

## Combat Stats
var health: int = 10
var max_health: int = 10
var armor: int = 0
var speed: int = 3
var attack_range: float = 10.0
var attack_power: int = 3
var accuracy: int = 65 # Percentage
var defense: int = 3
var evasion: int = 10 # Percentage

## Battle State
var action_points: int = 2
var max_action_points: int = 2
var is_stunned: bool = false
var is_wounded: bool = false
var is_defeated: bool = false
var has_moved: bool = false
var has_attacked: bool = false
var current_cover: int = 0

## Signals
signal unit_moved(unit: CharacterUnit, new_position: Vector2)
signal unit_attacked(unit: CharacterUnit, target: CharacterUnit, damage: int)
signal unit_damaged(unit: CharacterUnit, damage: int, source: CharacterUnit)
signal unit_defeated(unit: CharacterUnit)
signal unit_healed(unit: CharacterUnit, amount: int)
signal unit_restored(unit: CharacterUnit)
signal action_points_changed(unit: CharacterUnit, new_points: int)

## Initialization
func _init() -> void:
	pass

func _ready() -> void:
	# Initialize the character unit
	pass

## Unit status functions
func is_active() -> bool:
	return not is_defeated and not is_stunned and action_points > 0

func check_if_defeated() -> bool:
	return is_defeated

func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(health) / float(max_health)

## Movement functions
func get_movement_range() -> int:
	if is_wounded:
		return max(1, speed - 1)
	return speed

func move_to(position: Vector2) -> void:
	if action_points <= 0 or has_moved:
		return
	
	# Set new position
	global_position = position
	
	# Consume action point
	spend_action_point()
	has_moved = true
	
	# Emit signal
	unit_moved.emit(self, position)

## Combat functions
func get_attack_range() -> float:
	return attack_range

func calculate_hit_chance(target: CharacterUnit) -> float:
	var base_chance = float(accuracy) / 100.0
	
	# Apply modifiers
	if target.current_cover > 0:
		# Cover reduces hit chance
		base_chance -= float(target.current_cover) * 0.1
	
	if target.evasion > 0:
		# Evasion reduces hit chance
		base_chance -= float(target.evasion) / 100.0
	
	# Clamp the value
	return clampf(base_chance, 0.1, 0.95)

func calculate_damage(target: CharacterUnit) -> int:
	var base_damage = attack_power
	
	# Apply armor reduction
	var damage_after_armor = max(1, base_damage - target.armor)
	
	# Apply any other modifiers here
	
	return damage_after_armor

func attack(target: CharacterUnit) -> bool:
	if action_points <= 0 or has_attacked:
		return false
	
	# Check if hit
	var hit_chance = calculate_hit_chance(target)
	var hit_roll = randf()
	
	if hit_roll <= hit_chance:
		# Hit successful
		var damage = calculate_damage(target)
		target.take_damage(damage, self)
		
		# Emit signal
		unit_attacked.emit(self, target, damage)
		
		# Consume action point
		spend_action_point()
		has_attacked = true
		
		return true
	else:
		# Miss
		unit_attacked.emit(self, target, 0)
		
		# Consume action point
		spend_action_point()
		has_attacked = true
		
		return false

func take_damage(amount: int, source: CharacterUnit = null) -> void:
	var actual_damage = clampi(amount, 0, health)
	
	# Apply damage
	health -= actual_damage
	
	# Check if defeated
	if health <= 0:
		health = 0
		is_defeated = true
		unit_defeated.emit(self)
	elif health <= max_health / 3 and not is_wounded:
		# Become wounded at 1/3 health
		is_wounded = true
	
	# Emit signal
	unit_damaged.emit(self, actual_damage, source)

func heal(amount: int) -> void:
	var old_health = health
	health = clampi(health + amount, 0, max_health)
	
	# Check if no longer wounded
	if is_wounded and health > max_health / 3:
		is_wounded = false
	
	# Emit signal if healing occurred
	if health > old_health:
		unit_healed.emit(self, health - old_health)

## Action point management
func spend_action_point() -> void:
	if action_points > 0:
		action_points -= 1
		action_points_changed.emit(self, action_points)

func reset_action_points() -> void:
	action_points = max_action_points
	has_moved = false
	has_attacked = false
	action_points_changed.emit(self, action_points)

## Other functions
func reset_for_new_turn() -> void:
	reset_action_points()
	
	# Remove stun
	if is_stunned:
		is_stunned = false

func restore() -> void:
	health = max_health
	is_defeated = false
	is_wounded = false
	is_stunned = false
	reset_action_points()
	unit_restored.emit(self)

## Utility functions
func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"character_name": character_name,
		"faction": faction,
		"unit_type": unit_type,
		"health": health,
		"max_health": max_health,
		"armor": armor,
		"speed": speed,
		"attack_range": attack_range,
		"attack_power": attack_power,
		"accuracy": accuracy,
		"defense": defense,
		"evasion": evasion,
		"position": {
			"x": global_position.x,
			"y": global_position.y
		}
	}

func from_dict(data: Dictionary) -> void:
	if data.has("character_id"):
		character_id = data.character_id
	
	if data.has("character_name"):
		character_name = data.character_name
	
	if data.has("faction"):
		faction = data.faction
	
	if data.has("unit_type"):
		unit_type = data.unit_type
	
	if data.has("health"):
		health = data.health
	
	if data.has("max_health"):
		max_health = data.max_health
	
	if data.has("armor"):
		armor = data.armor
	
	if data.has("speed"):
		speed = data.speed
	
	if data.has("attack_range"):
		attack_range = data.attack_range
	
	if data.has("attack_power"):
		attack_power = data.attack_power
	
	if data.has("accuracy"):
		accuracy = data.accuracy
	
	if data.has("defense"):
		defense = data.defense
	
	if data.has("evasion"):
		evasion = data.evasion
	
	if data.has("position"):
		global_position = Vector2(data.position.x, data.position.y)
	
	# Update status based on health
	if health <= 0:
		is_defeated = true
	elif health <= max_health / 3:
		is_wounded = true