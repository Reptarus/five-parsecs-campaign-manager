@tool
extends Resource
class_name EnemyResource
# Changed from extends "res://src/core/enemy/base/Enemy.gd" to avoid type conflicts

# This file exists to maintain compatibility with existing references
# while using the base Enemy class implementation

# Explicitly load the base enemy implementation
const BaseEnemy = preload("res://src/core/enemy/base/Enemy.gd")
const GameEnums = preload("res://src/core/systems/GameEnums.gd")

# Core properties and delegation
var _base_enemy = null

# Forward signals
signal enemy_initialized
signal health_changed(old_value, new_value)
signal died
signal position_changed(old_pos, new_pos)
signal turn_started
signal turn_ended
signal attack_executed(target)
signal attack_completed
signal touch_handled(position)
signal drag_handled(start_position, end_position)
signal selected

# Core properties and state tracking
var health: float = 100.0
var max_health: float = 100.0
var position: Vector2 = Vector2.ZERO
var is_active_state: bool = false
var can_move_state: bool = false

# Static helper method to determine type compatibility
# This helps GUT tests know this is a Resource
static func is_resource_script() -> bool:
	return true

# Static helper method that returns a node-based enemy
# This is the recommended method for creating a node-based enemy
static func create_node_enemy() -> Node:
	# Check if the base enemy script exists
	if not ResourceLoader.exists("res://src/core/enemy/base/Enemy.gd"):
		push_error("BaseEnemy script not found")
		return null
	
	# Load script and create instance with better error handling
	var script = load("res://src/core/enemy/base/Enemy.gd")
	if not script or not script is GDScript:
		push_error("BaseEnemy is not a valid GDScript")
		return null
		
	# Create instance with correct type check
	var instance = script.new()
	if not instance:
		push_error("Failed to create BaseEnemy instance")
		return null
		
	if not instance is Node:
		push_error("BaseEnemy instance is not a Node")
		instance.free()
		return null
		
	return instance

# Initialize base enemy with data - improved with better null safety
func _init():
	_create_base_enemy()
	_connect_signals()

# Separate method to create base enemy with error handling
func _create_base_enemy() -> void:
	if not ResourceLoader.exists("res://src/core/enemy/base/Enemy.gd"):
		push_warning("BaseEnemy script not found, some functionality will be limited")
		return
		
	var script = load("res://src/core/enemy/base/Enemy.gd")
	if not script or not script is GDScript:
		push_warning("BaseEnemy is not a valid GDScript, some functionality will be limited")
		return
		
	var instance = script.new()
	if not instance:
		push_warning("Failed to create BaseEnemy instance, some functionality will be limited")
		return
		
	_base_enemy = instance

# Connect base signals to this resource's signals
func _connect_signals():
	if not _base_enemy:
		return
		
	if _base_enemy.has_signal("enemy_initialized"):
		if not _base_enemy.enemy_initialized.is_connected(func(): enemy_initialized.emit()):
			_base_enemy.enemy_initialized.connect(func(): enemy_initialized.emit())
	
	if _base_enemy.has_signal("health_changed"):
		if not _base_enemy.health_changed.is_connected(func(old_val, new_val): health_changed.emit(old_val, new_val)):
			_base_enemy.health_changed.connect(func(old_val, new_val): health_changed.emit(old_val, new_val))
	
	if _base_enemy.has_signal("died"):
		if not _base_enemy.died.is_connected(func(): died.emit()):
			_base_enemy.died.connect(func(): died.emit())
		
	if _base_enemy.has_signal("position_changed"):
		if not _base_enemy.position_changed.is_connected(func(old_pos, new_pos): position_changed.emit(old_pos, new_pos)):
			_base_enemy.position_changed.connect(func(old_pos, new_pos): position_changed.emit(old_pos, new_pos))
		
	if _base_enemy.has_signal("turn_started"):
		if not _base_enemy.turn_started.is_connected(func(): turn_started.emit()):
			_base_enemy.turn_started.connect(func(): turn_started.emit())
		
	if _base_enemy.has_signal("turn_ended"):
		if not _base_enemy.turn_ended.is_connected(func(): turn_ended.emit()):
			_base_enemy.turn_ended.connect(func(): turn_ended.emit())
		
	if _base_enemy.has_signal("attack_executed"):
		if not _base_enemy.attack_executed.is_connected(func(target): attack_executed.emit(target)):
			_base_enemy.attack_executed.connect(func(target): attack_executed.emit(target))
		
	if _base_enemy.has_signal("attack_completed"):
		if not _base_enemy.attack_completed.is_connected(func(): attack_completed.emit()):
			_base_enemy.attack_completed.connect(func(): attack_completed.emit())
		
	if _base_enemy.has_signal("touch_handled"):
		if not _base_enemy.touch_handled.is_connected(func(pos): touch_handled.emit(pos)):
			_base_enemy.touch_handled.connect(func(pos): touch_handled.emit(pos))
		
	if _base_enemy.has_signal("drag_handled"):
		if not _base_enemy.drag_handled.is_connected(func(start_pos, end_pos): drag_handled.emit(start_pos, end_pos)):
			_base_enemy.drag_handled.connect(func(start_pos, end_pos): drag_handled.emit(start_pos, end_pos))
		
	if _base_enemy.has_signal("selected"):
		if not _base_enemy.selected.is_connected(func(): selected.emit()):
			_base_enemy.selected.connect(func(): selected.emit())
	
	# Initialize local properties
	if _base_enemy:
		health = _base_enemy.get("health") if _base_enemy.get("health") != null else 100.0
		max_health = _base_enemy.get("max_health") if _base_enemy.get("max_health") != null else 100.0
		position = _base_enemy.get("position") if _base_enemy.get("position") != null else Vector2.ZERO

# Additional method that isn't in the base class
func heal(amount: int) -> int:
	var old_health = health
	
	if _base_enemy and _base_enemy.has_method("heal"):
		return _base_enemy.heal(amount)
	else:
		health = min(health + amount, max_health)
		
	health_changed.emit(old_health, health)
	return int(health - old_health)

# Delegate methods to the base enemy with better null safety
func get_health() -> int:
	if _base_enemy and _base_enemy.has_method("get_health"):
		return _base_enemy.get_health()
	return int(health)
	
func set_health(value) -> void:
	if _base_enemy and _base_enemy.has_method("set_health"):
		_base_enemy.set_health(value)
	else:
		var old_health = health
		health = float(value)
		health_changed.emit(old_health, health)

# Add other delegate methods as needed to maintain compatibility
func initialize(data) -> bool:
	if not data:
		push_warning("Trying to initialize enemy with null data")
		return false
		
	if _base_enemy and _base_enemy.has_method("initialize"):
		var result = _base_enemy.initialize(data)
		# Sync critical properties after initialization
		health = _base_enemy.get("health") if _base_enemy.get("health") != null else health
		max_health = _base_enemy.get("max_health") if _base_enemy.get("max_health") != null else max_health
		position = _base_enemy.get("position") if _base_enemy.get("position") != null else position
		return result
	
	# Fallback implementation if base enemy doesn't exist
	if data is Dictionary:
		if "health" in data:
			health = float(data.health)
		if "max_health" in data:
			max_health = float(data.max_health)
			
	# Always emit initialized signal
	enemy_initialized.emit()
	return true
	
func take_damage(amount: int) -> int:
	if amount <= 0:
		# No negative damage
		return 0
		
	if _base_enemy and _base_enemy.has_method("take_damage"):
		return _base_enemy.take_damage(amount)
	
	# Fallback implementation
	var old_health = health
	health = max(0, health - amount)
	
	# Emit signals
	health_changed.emit(old_health, health)
	if health <= 0:
		died.emit()
		
	return int(old_health - health)
	
func is_dead() -> bool:
	if _base_enemy and _base_enemy.has_method("is_dead"):
		return _base_enemy.is_dead()
	return health <= 0
	
func get_abilities() -> Array:
	if _base_enemy and _base_enemy.has_method("get_abilities"):
		return _base_enemy.get_abilities()
	return []
	
func get_loot() -> Dictionary:
	if _base_enemy and _base_enemy.has_method("get_loot"):
		return _base_enemy.get_loot()
	return {"credits": 0, "items": []}
	
# Movement and range methods
func get_movement_range() -> float:
	if _base_enemy and _base_enemy.has_method("get_movement_range"):
		return _base_enemy.get_movement_range()
	return 5.0
	
func set_movement_range(value: float) -> void:
	if _base_enemy and _base_enemy.has_method("set_movement_range"):
		_base_enemy.set_movement_range(value)
	
func get_weapon_range() -> float:
	if _base_enemy and _base_enemy.has_method("get_weapon_range"):
		return _base_enemy.get_weapon_range()
	return 2.0
	
func set_weapon_range(value: float) -> void:
	if _base_enemy and _base_enemy.has_method("set_weapon_range"):
		_base_enemy.set_weapon_range(value)
		
func get_behavior() -> int:
	if _base_enemy and _base_enemy.has_method("get_behavior"):
		return _base_enemy.get_behavior()
	return 0
	
func set_behavior(value) -> bool:
	if _base_enemy and _base_enemy.has_method("set_behavior"):
		return _base_enemy.set_behavior(value)
	return false
	
# Position methods for testing
func get_position() -> Vector2:
	if _base_enemy:
		if _base_enemy.has_method("get_position"):
			return _base_enemy.get_position()
		elif _base_enemy.get("position") != null:
			return _base_enemy.position
	return position
	
func set_position(value: Vector2) -> void:
	var old_position = position
	position = value
	if _base_enemy:
		if _base_enemy.has_method("set_position"):
			_base_enemy.set_position(value)
		elif _base_enemy.get("position") != null:
			_base_enemy.position = value
	
	position_changed.emit(old_position, position)
		
# Movement methods
func move_to(target_position: Vector2) -> bool:
	if not target_position:
		return false
		
	if _base_enemy and _base_enemy.has_method("move_to"):
		var result = _base_enemy.move_to(target_position)
		if result:
			var old_position = position
			position = target_position
			position_changed.emit(old_position, position)
		return result
	
	# Direct implementation
	var old_position = position
	position = target_position
	position_changed.emit(old_position, position)
	return true
	
# Add missing methods for testing with improved null safety
func start_turn() -> bool:
	is_active_state = true
	can_move_state = true
	turn_started.emit()
	if _base_enemy and _base_enemy.has_method("start_turn"):
		return _base_enemy.start_turn()
	return true
	
func end_turn() -> bool:
	is_active_state = false
	can_move_state = false
	turn_ended.emit()
	if _base_enemy and _base_enemy.has_method("end_turn"):
		return _base_enemy.end_turn()
	return true
	
func is_active() -> bool:
	if _base_enemy and _base_enemy.has_method("is_active"):
		return _base_enemy.is_active()
	return is_active_state
	
func can_move() -> bool:
	if _base_enemy and _base_enemy.has_method("can_move"):
		return _base_enemy.can_move()
	return can_move_state
	
func is_valid() -> bool:
	if _base_enemy and _base_enemy.has_method("is_valid"):
		return _base_enemy.is_valid()
	return health > 0
	
func get_combat_rating() -> float:
	if _base_enemy and _base_enemy.has_method("get_combat_rating"):
		return _base_enemy.get_combat_rating()
	# Simple implementation
	var health_percent = float(health) / float(max_health) if max_health > 0 else 0
	return health_percent * 10.0
	
func handle_touch(pos: Vector2) -> bool:
	if _base_enemy and _base_enemy.has_method("handle_touch"):
		return _base_enemy.handle_touch(pos)
	touch_handled.emit(pos)
	return true
	
func handle_drag(start_pos: Vector2, end_pos: Vector2) -> bool:
	if _base_enemy and _base_enemy.has_method("handle_drag"):
		return _base_enemy.handle_drag(start_pos, end_pos)
	drag_handled.emit(start_pos, end_pos)
	return true
	
func handle_selection() -> bool:
	if _base_enemy and _base_enemy.has_method("handle_selection"):
		return _base_enemy.handle_selection()
	selected.emit()
	return true
	
func attack(target_node) -> bool:
	if not target_node:
		return false
		
	if _base_enemy and _base_enemy.has_method("attack"):
		return _base_enemy.attack(target_node)
	
	attack_executed.emit(target_node)
	
	# Use the main loop directly since resources don't have get_tree() access
	# We'll simulate a delay with multiple process frames
	var main_loop = Engine.get_main_loop()
	for i in range(3): # About 0.05s per frame * 3 = ~0.15s delay
		if main_loop:
			await main_loop.process_frame
	
	attack_completed.emit()
	return true
	
func is_target_in_range(target_node) -> bool:
	if not target_node:
		return false
		
	if _base_enemy and _base_enemy.has_method("is_target_in_range"):
		return _base_enemy.is_target_in_range(target_node)
		
	if target_node and target_node.get("position") != null:
		var distance = position.distance_to(target_node.position)
		return distance <= get_weapon_range() * 30.0
	return false
	
func can_hit_target(target_node) -> bool:
	if not target_node:
		return false
		
	if _base_enemy and _base_enemy.has_method("can_hit_target"):
		return _base_enemy.can_hit_target(target_node)
		
	return is_target_in_range(target_node)
	
func set_target(new_target) -> bool:
	if _base_enemy and _base_enemy.has_method("set_target"):
		return _base_enemy.set_target(new_target)
	return new_target != null
	
func has_status_effect(effect_name: String) -> bool:
	if not effect_name or effect_name.is_empty():
		return false
		
	if _base_enemy and _base_enemy.has_method("has_status_effect"):
		return _base_enemy.has_status_effect(effect_name)
	return false
	
func apply_status_effect(effect_name: String, duration: int = 3) -> bool:
	if not effect_name or effect_name.is_empty():
		return false
		
	if _base_enemy and _base_enemy.has_method("apply_status_effect"):
		return _base_enemy.apply_status_effect(effect_name, duration)
	return true

# Ensure the resource has a valid path to allow serialization
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Clean up the base enemy instance when this resource is freed
		if _base_enemy and _base_enemy is Node and is_instance_valid(_base_enemy):
			_base_enemy.queue_free()
	
	# Add serialization safety
	if what == NOTIFICATION_POSTINITIALIZE:
		# Add a resource path if one doesn't exist (needed for proper serialization)
		if resource_path.is_empty():
			# Use a temporary path that's unique for this session
			resource_path = "res://tests/generated/enemy_resource_%d.tres" % [Time.get_unix_time_from_system()]
