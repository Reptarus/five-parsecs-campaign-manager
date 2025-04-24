@tool
extends Resource
# This is a proxy script to avoid breaking changes in test cases
# The actual implementation is in src://core/enemy/EnemyData.gd

# Get the original script
const OriginalScript = preload("res://src/core/enemy/EnemyData.gd")

# Forward all method calls to the original script
func _get(property):
	if property in OriginalScript.new():
		return OriginalScript.new().get(property)
	return null

func _set(property, value):
	if property in OriginalScript.new():
		var instance = OriginalScript.new()
		instance.set(property, value)
		return true
	return false

# Forward all static methods
static func attach_to_node(enemy_data, node, meta_key = "enemy_data"):
	return OriginalScript.attach_to_node(enemy_data, node, meta_key)

static func get_from_node(node, meta_key = "enemy_data"):
	return OriginalScript.get_from_node(node, meta_key)

static func create_basic_enemy(type):
	return OriginalScript.create_basic_enemy(type)
	
static func create_from_template(template_id):
	return OriginalScript.create_from_template(template_id)
	
static func create(data):
	return OriginalScript.create(data)
	
static func create_visual_node(enemy_data):
	return OriginalScript.create_visual_node(enemy_data)

# Create new instance of the original script
func _init():
	push_warning("Using EnemyData proxy. This is for backward compatibility only.")
