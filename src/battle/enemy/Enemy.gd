@tool
extends CharacterBody2D
class_name BattleEnemy
# Changed from extending the base Enemy class to avoid type conflicts

# This file exists to maintain compatibility with existing references
# while using the base Enemy class implementation

# Import the base enemy implementation to use via composition
const BaseEnemy = preload("res://src/core/enemy/base/Enemy.gd")
const GameEnums = preload("res://src/core/systems/GameEnums.gd")

# Core properties and delegation 
var _base_enemy = null

# Core properties with type annotations
var health: float = 100.0
var max_health: float = 100.0
var damage: float = 10.0
var armor: float = 5.0
var movement_range: float = 4.0
var weapon_range: float = 1.0
var behavior: int = 0

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

func _init() -> void:
    _create_base_enemy()
    
func _ready() -> void:
    # Connect signals after ready to ensure proper initialization
    _connect_signals()

func _create_base_enemy() -> void:
    # Create base enemy with error handling
    if not ResourceLoader.exists("res://src/core/enemy/base/Enemy.gd"):
        push_warning("BaseEnemy script not found, falling back to local implementation")
        return
        
    var script = load("res://src/core/enemy/base/Enemy.gd")
    if not script or not script is GDScript:
        push_warning("BaseEnemy is not a valid GDScript")
        return
        
    var instance = script.new()
    if not instance:
        push_warning("Failed to create BaseEnemy instance")
        return
        
    _base_enemy = instance

# Connect signals with proper checks
func _connect_signals() -> void:
    if not _base_enemy:
        return
        
    # Connect all signals with proper checks for duplicates
    var signals_to_connect = [
        {"signal_name": "enemy_initialized", "method": "_on_base_enemy_initialized"},
        {"signal_name": "health_changed", "method": "_on_base_health_changed"},
        {"signal_name": "died", "method": "_on_base_died"},
        {"signal_name": "position_changed", "method": "_on_base_position_changed"},
        {"signal_name": "turn_started", "method": "_on_base_turn_started"},
        {"signal_name": "turn_ended", "method": "_on_base_turn_ended"},
        {"signal_name": "attack_executed", "method": "_on_base_attack_executed"},
        {"signal_name": "attack_completed", "method": "_on_base_attack_completed"},
        {"signal_name": "touch_handled", "method": "_on_base_touch_handled"},
        {"signal_name": "drag_handled", "method": "_on_base_drag_handled"},
        {"signal_name": "selected", "method": "_on_base_selected"}
    ]
    
    for sig_data in signals_to_connect:
        if _base_enemy.has_signal(sig_data.signal_name):
            # Check if already connected to avoid duplicate connections
            if not _base_enemy.is_connected(sig_data.signal_name, Callable(self, sig_data.method)):
                _base_enemy.connect(sig_data.signal_name, Callable(self, sig_data.method))
    
    # Initialize properties from base enemy
    if _base_enemy:
        health = _base_enemy.get("health") if _base_enemy.get("health") != null else health
        max_health = _base_enemy.get("max_health") if _base_enemy.get("max_health") != null else max_health
        damage = _base_enemy.get("damage") if _base_enemy.get("damage") != null else damage
        armor = _base_enemy.get("armor") if _base_enemy.get("armor") != null else armor
        movement_range = _base_enemy.get("movement_range") if _base_enemy.get("movement_range") != null else movement_range
        weapon_range = _base_enemy.get("weapon_range") if _base_enemy.get("weapon_range") != null else weapon_range

# Signal forwarders with proper handling
func _on_base_enemy_initialized() -> void:
    enemy_initialized.emit()
    
func _on_base_health_changed(old_value, new_value) -> void:
    health = float(new_value) if new_value != null else 0.0
    health_changed.emit(old_value, new_value)
    
func _on_base_died() -> void:
    died.emit()
    
func _on_base_position_changed(old_pos, new_pos) -> void:
    # Ensure position is updated when base enemy position changes
    position = new_pos
    position_changed.emit(old_pos, new_pos)
    
func _on_base_turn_started() -> void:
    turn_started.emit()
    
func _on_base_turn_ended() -> void:
    turn_ended.emit()
    
func _on_base_attack_executed(target) -> void:
    attack_executed.emit(target)
    
func _on_base_attack_completed() -> void:
    attack_completed.emit()
    
func _on_base_touch_handled(pos) -> void:
    touch_handled.emit(pos)
    
func _on_base_drag_handled(start_pos, end_pos) -> void:
    drag_handled.emit(start_pos, end_pos)
    
func _on_base_selected() -> void:
    selected.emit()

# Delegate methods with improved error handling
func initialize(data) -> bool:
    # Local initialization
    if data is Dictionary:
        if data.get("health") != null:
            health = float(data.health)
        if data.get("max_health") != null:
            max_health = float(data.max_health)
        if data.get("damage") != null:
            damage = float(data.damage)
        if data.get("armor") != null:
            armor = float(data.armor)
    
    # Initialize base enemy
    if _base_enemy and _base_enemy.has_method("initialize"):
        return _base_enemy.initialize(data)
    
    # Fallback if base enemy not available
    enemy_initialized.emit()
    return true
    
func get_health() -> int:
    if _base_enemy and _base_enemy.has_method("get_health"):
        return _base_enemy.get_health()
    return int(health)
    
func set_health(value) -> void:
    # Store health locally as well for consistency
    var old_health = health
    
    if _base_enemy and _base_enemy.has_method("set_health"):
        _base_enemy.set_health(value)
    else:
        health = float(value) if value != null else 0.0
        health_changed.emit(old_health, health)
        if old_health > 0 and health <= 0:
            died.emit()
            
# Move with proper validation
func move_to(target_position: Vector2) -> bool:
    # Update position for CharacterBody2D
    position = target_position
    
    if _base_enemy and _base_enemy.has_method("move_to"):
        return _base_enemy.move_to(target_position)
        
    return true
    
# Delegate all other methods with proper type handling
func take_damage(amount) -> int:
    var actual_damage = 0
    
    if _base_enemy and _base_enemy.has_method("take_damage"):
        actual_damage = _base_enemy.take_damage(amount)
    else:
        if amount <= 0:
            return 0
            
        var old_health = health
        actual_damage = int(max(0, float(amount) - armor))
        health = max(0, health - actual_damage)
        
        health_changed.emit(old_health, health)
        if old_health > 0 and health <= 0:
            died.emit()
    
    return actual_damage
    
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
    
# Getter/setter methods
func get_movement_range() -> float:
    if _base_enemy and _base_enemy.has_method("get_movement_range"):
        return _base_enemy.get_movement_range()
    return movement_range
    
func set_movement_range(value: float) -> void:
    movement_range = value
    if _base_enemy and _base_enemy.has_method("set_movement_range"):
        _base_enemy.set_movement_range(value)
    
func get_weapon_range() -> float:
    if _base_enemy and _base_enemy.has_method("get_weapon_range"):
        return _base_enemy.get_weapon_range()
    return weapon_range
    
func set_weapon_range(value: float) -> void:
    weapon_range = value
    if _base_enemy and _base_enemy.has_method("set_weapon_range"):
        _base_enemy.set_weapon_range(value)
        
func get_behavior() -> int:
    if _base_enemy and _base_enemy.has_method("get_behavior"):
        return _base_enemy.get_behavior()
    return behavior
    
func set_behavior(value) -> bool:
    behavior = int(value)
    if _base_enemy and _base_enemy.has_method("set_behavior"):
        return _base_enemy.set_behavior(value)
    return true
    
# Turn management with proper delegation
func start_turn() -> bool:
    if _base_enemy and _base_enemy.has_method("start_turn"):
        return _base_enemy.start_turn()
    
    turn_started.emit()
    return true
    
func end_turn() -> bool:
    if _base_enemy and _base_enemy.has_method("end_turn"):
        return _base_enemy.end_turn()
    
    turn_ended.emit()
    return true
    
func is_active() -> bool:
    if _base_enemy and _base_enemy.has_method("is_active"):
        return _base_enemy.is_active()
    return false
    
func can_move() -> bool:
    if _base_enemy and _base_enemy.has_method("can_move"):
        return _base_enemy.can_move()
    return true
    
# Handle test-specific methods
func is_valid() -> bool:
    if _base_enemy and _base_enemy.has_method("is_valid"):
        return _base_enemy.is_valid()
    return is_instance_valid(self)
    
func get_combat_rating() -> float:
    if _base_enemy and _base_enemy.has_method("get_combat_rating"):
        return _base_enemy.get_combat_rating()
        
    var health_percent = health / max_health if max_health > 0 else 0
    return health_percent * 10.0
    
# Touch handling with proper delegation and signals
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
    
# Combat methods with proper parameter validation
func attack(target_node) -> bool:
    if not target_node:
        return false
        
    if _base_enemy and _base_enemy.has_method("attack"):
        return _base_enemy.attack(target_node)
        
    attack_executed.emit(target_node)
    
    # Safely create timer with fallback
    var scene_tree = get_tree()
    if scene_tree and is_instance_valid(scene_tree):
        await scene_tree.create_timer(0.5).timeout
    else:
        # Fallback for when not in scene tree or during testing
        await Engine.get_main_loop().process_frame
        await Engine.get_main_loop().process_frame
        await Engine.get_main_loop().process_frame
        # Simulate ~0.5 seconds with multiple frames
        
    attack_completed.emit()
    return true
    
func is_target_in_range(target_node) -> bool:
    if not target_node:
        return false
        
    if _base_enemy and _base_enemy.has_method("is_target_in_range"):
        return _base_enemy.is_target_in_range(target_node)
        
    return position.distance_to(target_node.position) <= weapon_range * 30.0
    
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
    
# Status effect methods
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
    
# Healing method
func heal(amount: int) -> int:
    if amount <= 0:
        return 0
        
    if _base_enemy and _base_enemy.has_method("heal"):
        return _base_enemy.heal(amount)
        
    var old_health = health
    health = min(health + amount, max_health)
    var actual_healing = health - old_health
    
    health_changed.emit(old_health, health)
    return int(actual_healing)
    
# Clean up resources when removed from scene
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        # Clean up the base enemy instance if it's a separate object
        if _base_enemy and is_instance_valid(_base_enemy) and _base_enemy != self:
            # Only free if it's not part of scene tree
            if not _base_enemy.is_inside_tree():
                _base_enemy.free()

# Static helper method to determine type compatibility
# This helps GUT tests know this is a CharacterBody2D
static func is_node_script() -> bool:
    return true