@tool
extends Node2D
# This script is a visual representation of EnemyData Resources
# It provides a bridge between EnemyData (Resource) and Node2D

# Preload required scripts
const EnemyDataClass = preload("res://src/core/enemy/EnemyData.gd")

# Visual appearance properties
var _health_bar_color: Color = Color.GREEN
var _health_bar_background: Color = Color.DARK_RED
var _display_name: bool = true

# Current visual state
var _current_health: float = 100.0
var _max_health: float = 100.0

func _ready() -> void:
    # Ensure we have required child nodes
    _ensure_visual_components()
    
    # Initialize from attached enemy data if available
    var enemy_data = EnemyDataClass.get_from_node(self)
    if enemy_data:
        _initialize_from_data(enemy_data)

# Make sure we have all necessary visual components
func _ensure_visual_components() -> void:
    # Check for a sprite
    if not has_node("Sprite"):
        var sprite = Sprite2D.new()
        sprite.name = "Sprite"
        add_child(sprite)
        sprite.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
    
    # Check for a health bar
    if not has_node("HealthBar"):
        var health_bar = ProgressBar.new()
        health_bar.name = "HealthBar"
        health_bar.position = Vector2(0, -20)
        health_bar.size = Vector2(40, 6)
        health_bar.custom_minimum_size = Vector2(40, 6)
        health_bar.show_percentage = false
        health_bar.value = 100.0
        
        if health_bar.has_method("set_theme_type_variation"):
            health_bar.call("set_theme_type_variation", "EnemyHealthBar")
            
        if health_bar.has_method("set_modulate"):
            health_bar.call("set_modulate", Color.GREEN)
            
        add_child(health_bar)
        health_bar.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

# Initialize visual representation from enemy data
func _initialize_from_data(enemy_data: Resource) -> void:
    if not enemy_data:
        return
    
    # Set name
    if enemy_data.has_method("get_name"):
        name = "EnemyVisual_" + enemy_data.get_name().replace(" ", "_")
    elif "enemy_name" in enemy_data:
        name = "EnemyVisual_" + enemy_data.enemy_name.replace(" ", "_")
    
    # Set health
    if enemy_data.has_method("get_health") and enemy_data.has_method("get_max_health"):
        _current_health = enemy_data.get_health()
        _max_health = enemy_data.get_max_health()
    elif "health" in enemy_data and "max_health" in enemy_data:
        _current_health = enemy_data.health
        _max_health = enemy_data.max_health
    
    # Update visual state
    _update_health_bar()

# Set health values and update visuals
func set_health(current: float, maximum: float = 0.0) -> void:
    _current_health = current
    if maximum > 0:
        _max_health = maximum
    
    # Update the visual representation
    _update_health_bar()
    
    # Update the attached enemy data if available
    var enemy_data = EnemyDataClass.get_from_node(self)
    if enemy_data:
        if enemy_data.has_method("set_health"):
            enemy_data.set_health(current)
        else:
            enemy_data.health = current
            
        if maximum > 0:
            if "max_health" in enemy_data:
                enemy_data.max_health = maximum

# Update the health bar display
func _update_health_bar() -> void:
    var health_percentage = (_current_health / _max_health) * 100.0
    
    var health_bar = get_node_or_null("HealthBar")
    if health_bar and health_bar is ProgressBar:
        health_bar.value = health_percentage
        
        # Update colors based on health
        if health_percentage < 25:
            health_bar.modulate = Color.RED
        elif health_percentage < 50:
            health_bar.modulate = Color.ORANGE
        else:
            health_bar.modulate = Color.GREEN
            
# Get current health
func get_health() -> float:
    return _current_health
    
# Get maximum health
func get_max_health() -> float:
    return _max_health
    
# Check if enemy is dead
func is_dead() -> bool:
    return _current_health <= 0.0