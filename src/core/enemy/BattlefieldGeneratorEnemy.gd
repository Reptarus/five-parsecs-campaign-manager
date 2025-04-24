@tool
extends Node2D

# Dependencies
const EnemyData := preload("res://src/core/enemy/EnemyData.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Signals
signal enemy_generated(enemy_node)
signal health_changed(old_value, new_value)
signal enemy_died()

# Properties
var enemy_sprite: Sprite2D
var health_bar: ProgressBar
var collision_shape: CollisionShape2D

# Store enemy data as a resource, not by inheritance
var _enemy_data: Resource = null

func _ready() -> void:
	# Find components
	collision_shape = get_node_or_null("Collision")
	if collision_shape and collision_shape.has_node("Enemy"):
		enemy_sprite = collision_shape.get_node("Enemy")
	
	health_bar = get_node_or_null("HealthBar")
	
	# Create default enemy data if none exists
	if not has_enemy_data():
		_enemy_data = EnemyData.new("Default Enemy")
		# Store it properly as metadata
		EnemyData.attach_to_node(_enemy_data, self)

# Check if this node has enemy data attached
func has_enemy_data() -> bool:
	return EnemyData.get_from_node(self) != null

# Get the enemy data resource
func get_enemy_data() -> Resource:
	if not _enemy_data:
		_enemy_data = EnemyData.get_from_node(self)
	return _enemy_data

# Update health bar based on current health
func update_health_display() -> void:
	if not health_bar or not has_enemy_data():
		return
		
	var enemy_data = get_enemy_data()
	var health_percent = (enemy_data.health / enemy_data.max_health) * 100.0
	health_bar.value = health_percent

# Set health value
func set_health(new_health: float, max_health: float = 0.0) -> void:
	if not has_enemy_data():
		return
		
	var enemy_data = get_enemy_data()
	var old_health = enemy_data.health
	enemy_data.health = new_health
	
	if max_health > 0:
		enemy_data.max_health = max_health
	
	update_health_display()
	
	# Emit signal
	health_changed.emit(old_health, new_health)
	
	# Check for death
	if new_health <= 0 and old_health > 0:
		enemy_died.emit()

# Generate an enemy in the provided scene
static func generate_enemy(parent_scene: Node, position: Vector2, enemy_type: String, level: int = 1) -> Node:
	if not ResourceLoader.exists("res://src/data/resources/Deployment/Units/BattlefieldGeneratorEnemy.tscn"):
		push_error("BattlefieldGeneratorEnemy scene not found")
		return null
	
	# Instantiate the scene
	var packed_scene = load("res://src/data/resources/Deployment/Units/BattlefieldGeneratorEnemy.tscn")
	var enemy_instance = packed_scene.instantiate()
	
	# Set position
	enemy_instance.position = position
	
	# Create enemy data
	var enemy_data = EnemyData.new(enemy_type)
	enemy_data.enemy_type = GameEnums.EnemyType.get(enemy_type.to_upper(), GameEnums.EnemyType.GANGERS)
	enemy_data.level = level
	enemy_data.health = 10.0 * level
	enemy_data.max_health = 10.0 * level
	
	# Attach enemy data to node properly
	EnemyData.attach_to_node(enemy_data, enemy_instance)
	
	# Add to parent scene
	parent_scene.add_child(enemy_instance)
	
	# Configure visuals
	enemy_instance.name = "Enemy_" + enemy_type + "_" + str(randi() % 1000)
	
	# Update health display
	enemy_instance.update_health_display()
	
	# Emit signal
	if enemy_instance.has_signal("enemy_generated"):
		enemy_instance.enemy_generated.emit(enemy_instance)
	
	return enemy_instance
