@tool
extends Node

## Helper class to bridge between Resource-based and Node-based character implementations
## This resolves type compatibility issues between the two paradigms
class_name NodeCharacterHelper

# Core dependencies
const BaseCharacterResource = preload("res://src/core/character/Base/Character.gd")
const BattleCharacter = preload("res://src/battle/character/Character.gd")

## Create a node-based character from a resource-based character
## This is useful for testing and for integrating resource-based characters
## into node-based systems like the battle system
static func create_node_from_resource(character_resource: Resource) -> Node2D:
	if not character_resource:
		push_error("Cannot create node from null character resource")
		return null
		
	if not (character_resource is Resource):
		push_error("Character must be a Resource")
		return null
	
	# Verify it's a proper character resource with required methods
	var has_required_properties = true
	var required_methods = ["get_health", "get_max_health"]
	for method in required_methods:
		if not character_resource.has_method(method):
			push_error("Character resource missing required method: " + method)
			has_required_properties = false
	
	if not has_required_properties:
		push_error("Resource does not appear to be a valid character resource")
		return null
		
	# Create a battle character node
	var node = BattleCharacter.new()
	if not node:
		push_error("Failed to create BattleCharacter node")
		return null
		
	# Initialize the node with the resource
	var success = node.initialize(character_resource)
	if not success:
		push_error("Failed to initialize BattleCharacter with resource")
		node.queue_free()
		return null
		
	return node

## Create a resource-based character from a node-based character
## This is useful for saving node-based characters to disk
static func create_resource_from_node(character_node: Node) -> Resource:
	if not character_node:
		push_error("Cannot create resource from null character node")
		return null
		
	if not (character_node is Node):
		push_error("Character must be a Node")
		return null
	
	# Make sure this is a Character node and not just any node
	if not character_node.has_method("get_health") or not character_node.has_method("get_max_health"):
		push_error("Node does not appear to be a valid Character node")
		return null
		
	# Check if the node already has a character resource
	if character_node.has_method("get_character_resource"):
		var existing_resource = character_node.get_character_resource()
		if existing_resource:
			return existing_resource
			
	# Create a new character resource
	var resource = BaseCharacterResource.new()
	if not resource:
		push_error("Failed to create BaseCharacterResource")
		return null
		
	# Copy properties from node to resource
	_copy_node_properties_to_resource(character_node, resource)
		
	return resource

## Copy properties from a node to a resource
static func _copy_node_properties_to_resource(from_node: Node, to_resource: Resource) -> void:
	if not from_node or not to_resource:
		return
		
	# Copy basic properties if they exist on both objects
	var properties_to_copy = [
		"character_name",
		"health",
		"max_health",
		"level",
		"experience",
		"is_dead",
		"is_wounded",
		"combat",
		"reaction",
		"toughness",
		"speed",
		"traits",
		"status_effects"
	]
	
	for prop in properties_to_copy:
		if from_node.has_method("get_" + prop):
			var value = from_node.call("get_" + prop)
			if to_resource.has_method("set_" + prop):
				to_resource.call("set_" + prop, value)
			elif prop in to_resource:
				to_resource.set(prop, value)

## Create a completely standalone test character node
## Useful for testing when you don't want to depend on resources
static func create_test_character_node() -> Node2D:
	var node = BattleCharacter.new()
	if not node:
		push_error("Failed to create BattleCharacter node")
		return null
		
	# Create a test character resource for initialization
	var resource = BaseCharacterResource.new()
	if not resource:
		push_error("Failed to create BaseCharacterResource")
		node.queue_free()
		return null
	
	# Ensure the resource has a valid path to prevent serialization errors
	if resource.resource_path.is_empty():
		resource.resource_path = "res://tests/generated/test_character_%d.tres" % [Time.get_unix_time_from_system()]
		
	# Set up test data
	resource.character_name = "Test Character"
	resource.health = 100
	resource.max_health = 100
	resource.level = 1
	resource.combat = 3
	resource.reaction = 3
	resource.toughness = 3
	resource.speed = 3
	
	# Initialize the node with the resource
	var success = node.initialize(resource)
	if not success:
		push_error("Failed to initialize BattleCharacter with resource")
		node.queue_free()
		return null
		
	return node