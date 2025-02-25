@tool
extends CharacterBody2D

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Core properties
@export var enemy_data: Resource # Will be cast to FiveParsecsEnemyData
@export var behavior: GameEnums.AIBehavior = GameEnums.AIBehavior.CAUTIOUS

# Movement
@export var movement_range: int = 4
@export var movement_points: int = 4

# Combat
@export var weapon_range: int = 1
@export var attack_points: int = 1

# Signals
signal state_changed(new_state: Dictionary)
signal action_completed(action_type: String)
signal movement_completed
signal attack_completed
signal health_changed(new_health: int, old_health: int)
signal died

# Internal state
var _current_health: int = 100
var _max_health: int = 100
var _current_state: Dictionary = {
	"action_points": 2,
	"movement_points": 4,
	"can_attack": true,
	"can_move": true,
	"is_active": false
}

func _ready() -> void:
	if not enemy_data:
		push_warning("Enemy initialized without enemy data")
		return
		
	_initialize_from_data()

func _initialize_from_data() -> void:
	if not enemy_data:
		return
		
	# Initialize stats from enemy data
	if enemy_data.has_method("get_health"):
		_max_health = enemy_data.get_health()
		movement_range = enemy_data.get_movement_range()
		weapon_range = enemy_data.get_weapon_range()
		behavior = enemy_data.get_behavior()
	else:
		# Default values if methods not available
		_max_health = 100
		movement_range = 4
		weapon_range = 1
		behavior = GameEnums.AIBehavior.CAUTIOUS
	
	_current_health = _max_health

# Movement methods
func get_movement_range() -> int:
	return movement_range

func get_movement_points() -> int:
	return _current_state.movement_points

func can_move() -> bool:
	return _current_state.can_move and _current_state.movement_points > 0

func move_to(target_position: Vector2) -> void:
	if not can_move():
		return
		
	# Implement actual movement logic here
	position = target_position
	_current_state.movement_points -= 1
	if _current_state.movement_points <= 0:
		_current_state.can_move = false
	
	movement_completed.emit()
	state_changed.emit(_current_state)

# Combat methods
func get_weapon() -> Resource:
	return enemy_data.get_weapon() if enemy_data and enemy_data.has_method("get_weapon") else null

func can_attack() -> bool:
	return _current_state.can_attack and get_weapon() != null

func attack(target: Node2D) -> void:
	if not can_attack():
		return
		
	# Implement attack logic here
	_current_state.can_attack = false
	attack_completed.emit()
	state_changed.emit(_current_state)

# Health methods
func get_health() -> int:
	return _current_health

func get_max_health() -> int:
	return _max_health

func take_damage(amount: int) -> void:
	var old_health = _current_health
	_current_health = maxi(0, _current_health - amount)
	health_changed.emit(_current_health, old_health)
	
	if _current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	var old_health = _current_health
	_current_health = mini(_max_health, _current_health + amount)
	health_changed.emit(_current_health, old_health)

# State management
func start_turn() -> void:
	_current_state.action_points = 2
	_current_state.movement_points = movement_points
	_current_state.can_attack = true
	_current_state.can_move = true
	_current_state.is_active = true
	state_changed.emit(_current_state)

func end_turn() -> void:
	_current_state.action_points = 0
	_current_state.movement_points = 0
	_current_state.can_attack = false
	_current_state.can_move = false
	_current_state.is_active = false
	state_changed.emit(_current_state)

func get_state() -> Dictionary:
	return _current_state.duplicate()

func get_combat_rating() -> float:
	if not enemy_data:
		return 1.0
	
	var weapon_rating = 1.0 if not get_weapon() else get_weapon().get_rating()
	var health_ratio = float(_current_health) / float(_max_health)
	
	return weapon_rating * health_ratio
