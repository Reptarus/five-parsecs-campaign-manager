@tool
extends Resource
class_name EnemyData

## Base class for enemy data in Five Parsecs from Home
## Contains the properties and methods needed for enemy units

# Load related scripts - use safer approach to avoid linter errors
var _rivals_enemy_data_script = null
func _get_rivals_data_script():
	if _rivals_enemy_data_script == null:
		if ResourceLoader.exists("res://src/core/rivals/EnemyData.gd"):
			_rivals_enemy_data_script = load("res://src/core/rivals/EnemyData.gd")
	return _rivals_enemy_data_script

## Core Properties
@export var enemy_id: String = ""
@export var name: String = "Unknown Enemy"
@export var faction: String = "Generic"
@export var category: String = "Standard"
@export var description: String = ""
@export var tier: int = 1 # Difficulty tier from 1-5
var enemy_type: int = 0 # Type enum value

## Combat Stats
@export var health: float = 10.0
@export var max_health: float = 10.0
@export var armor: int = 0
@export var movement: int = 5
@export var movement_range: int = 3 # Added missing property
@export var weapon_range: int = 1 # Added missing property
@export var attack_type: String = "melee"
@export var damage: int = 1
@export var attack_range: int = 1
@export var accuracy: int = 0
var level: int = 1

## Behaviors and AI
@export var behaviors: Array[String] = []
@export var special_abilities: Array[String] = []
@export var immunities: Array[String] = []
@export var vulnerabilities: Array[String] = []
@export var ai_tactics: String = "standard"

## Visual Properties
@export var model_path: String = ""
@export var icon_path: String = ""
@export var animation_set: String = "standard"

## Loot Tables
@export var loot_table: Dictionary = {}
@export var experience_value: int = 5
@export var threat_level: int = 1

## Initialization
func _init(p_name: String = "Unknown Enemy") -> void:
	resource_name = "EnemyData"
	name = p_name
	enemy_id = str(Time.get_unix_time_from_system())

## Static method to properly attach enemy data to a node
static func attach_to_node(enemy_data: Resource, node: Node, meta_key: String = "enemy_data") -> bool:
	if not enemy_data or not node:
		push_error("Cannot attach null enemy data or to a null node")
		return false
		
	# Store as metadata on the node
	node.set_meta(meta_key, enemy_data)
	return true

## Static method to retrieve enemy data from a node
static func get_from_node(node: Node, meta_key: String = "enemy_data") -> Resource:
	if not node:
		return null
		
	if not node.has_meta(meta_key):
		return null
		
	var data = node.get_meta(meta_key)
	var script = load("res://src/core/enemy/EnemyData.gd")
	if data and is_instance_valid(data) and data.get_script() == script:
		return data
		
	return null

## Factory method to create enemy data
static func create_basic_enemy(type: String) -> Resource:
	var enemy = load("res://src/core/enemy/EnemyData.gd").new()
	
	match type:
		"minion":
			enemy.name = "Minion"
			enemy.health = 5
			enemy.max_health = 5
			enemy.damage = 1
			enemy.tier = 1
			enemy.behaviors = ["follow_leader", "swarm"]
		"elite":
			enemy.name = "Elite"
			enemy.health = 20
			enemy.max_health = 20
			enemy.armor = 2
			enemy.damage = 3
			enemy.tier = 3
			enemy.special_abilities = ["area_attack"]
		"boss":
			enemy.name = "Boss"
			enemy.health = 50
			enemy.max_health = 50
			enemy.armor = 5
			enemy.damage = 5
			enemy.tier = 5
			enemy.special_abilities = ["area_attack", "regeneration"]
			enemy.immunities = ["stun", "poison"]
		_:
			enemy.name = "Generic Enemy"
			
	return enemy

## Create from a template ID - used in tests
static func create_from_template(template_id: String) -> Resource:
	var enemy = load("res://src/core/enemy/EnemyData.gd").new()
	
	if template_id == "boss":
		enemy.name = "Boss Enemy"
		enemy.health = 50
		enemy.tier = 5
	elif template_id == "elite":
		enemy.name = "Elite Enemy"
		enemy.health = 25
		enemy.tier = 3
	else:
		enemy.name = "Standard Enemy"
		enemy.health = 10
		enemy.tier = 1
		
	return enemy

## Create from a dictionary - used in tests
static func create(data: Dictionary) -> Resource:
	var enemy = load("res://src/core/enemy/EnemyData.gd").new()
	
	# Set properties from dictionary
	for key in data:
		if enemy.get(key) != null: # Property exists
			enemy.set(key, data[key])
	
	return enemy

## Calculates total enemy threat value based on stats and abilities
func calculate_threat_value() -> int:
	var threat = tier * 5
	threat += health / 5
	threat += armor * 3
	threat += damage * 2
	threat += special_abilities.size() * 5
	
	return threat

## Serializes the enemy data to a dictionary
func serialize() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"name": name,
		"faction": faction,
		"category": category,
		"description": description,
		"tier": tier,
		"enemy_type": enemy_type,
		"level": level,
		"health": health,
		"max_health": max_health,
		"armor": armor,
		"movement": movement,
		"attack_type": attack_type,
		"damage": damage,
		"attack_range": attack_range,
		"accuracy": accuracy,
		"behaviors": behaviors,
		"special_abilities": special_abilities,
		"immunities": immunities,
		"vulnerabilities": vulnerabilities,
		"ai_tactics": ai_tactics,
		"loot_table": loot_table,
		"experience_value": experience_value,
		"threat_level": threat_level
	}

## Creates a clone of this enemy data
func clone() -> Resource:
	var new_enemy = load("res://src/core/enemy/EnemyData.gd").new()
	var data = serialize()
	
	for key in data:
		if new_enemy.get(key) != null: # Property exists
			var value = data[key]
			# Deep copy arrays and dictionaries
			if value is Array:
				new_enemy.set(key, value.duplicate())
			elif value is Dictionary:
				new_enemy.set(key, value.duplicate())
			else:
				new_enemy.set(key, value)
	
	return new_enemy

## Scales enemy stats according to level
func scale_to_level(level: int) -> void:
	var scale_factor = max(1.0, level * 0.2)
	
	health = int(health * scale_factor)
	damage = int(damage * scale_factor)
	armor = int(armor + (level / 3))
	experience_value = int(experience_value * scale_factor)
	
	# Update threat level
	threat_level = calculate_threat_value()

## Deserializes from a dictionary
func deserialize(data: Dictionary) -> void:
	if data.size() == 0:
		push_warning("Empty data provided to deserialize EnemyData")
		return
		
	for key in data:
		if has_method("set_" + key):
			call("set_" + key, data[key])
		elif get(key) != null: # Property exists
			set(key, data[key])
	
	# Update calculated values
	threat_level = calculate_threat_value()

## Create a node representation of this enemy data (for visualization purposes)
static func create_visual_node(enemy_data: Resource) -> Node2D:
	if not enemy_data:
		return null
		
	var node = Node2D.new()
	node.name = "EnemyVisual_" + enemy_data.name.replace(" ", "_")
	
	# Create a simple sprite representation
	var collision = CollisionShape2D.new()
	collision.name = "Collision"
	node.add_child(collision)
	
	var sprite = Sprite2D.new()
	sprite.name = "Enemy"
	collision.add_child(sprite)
	
	# Add health bar
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.value = (enemy_data.health / enemy_data.max_health) * 100.0
	health_bar.position = Vector2(0, -20)
	health_bar.size = Vector2(40, 6)
	health_bar.custom_minimum_size = Vector2(40, 6) # Ensure minimum size is set
	health_bar.show_percentage = false
	node.add_child(health_bar)
	
	# Safely attach the enemy data to the node
	attach_to_node(enemy_data, node)
	
	return node

## Static method to create a node wrapper for enemy data, properly separating Resource and Node
static func create_node_wrapper(enemy_data: Resource) -> Node:
	if not enemy_data:
		push_error("Cannot create wrapper for null enemy data")
		return null
		
	var wrapper = Node.new()
	wrapper.name = "EnemyData_Wrapper"
	
	# Store as metadata on the wrapper
	attach_to_node(enemy_data, wrapper)
	
	# For now, just create a basic Node
	# In a real implementation, you would add a script that forwards methods to the resource
	
	return wrapper
