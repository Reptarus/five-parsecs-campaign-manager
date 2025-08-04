@tool
extends Node

signal relationship_added(char1, char2, relationship_type: String)
signal relationship_removed(char1, char2)

# These dictionaries should be overridden by game-specific implementations
var RELATIONSHIP_TYPES: Dictionary = {}
var CREW_CHARACTERISTICS: Dictionary = {}

var relationships: Dictionary = {} # Dictionary of Character pairs to relationship type
var crew_characteristic: String = ""
var crew_meeting_story: String = ""

func add_relationship(char1, char2, relationship_type: String) -> void:
	var pair_key = _get_pair_key(char1, char2)
	relationships[pair_key] = relationship_type
	relationship_added.emit(char1, char2, relationship_type)

func remove_relationship(char1, char2: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return

	var pair_key = _get_pair_key(char1, char2)
	if relationships.has(pair_key):
		relationships.erase(pair_key)
		relationship_removed.emit(char1, char2)

func get_relationship(char1: Variant, char2: Variant) -> String:
	var pair_key = _get_pair_key(char1, char2)
	return relationships.get(pair_key, "")

func get_all_relationships(character: Character) -> Array:
	var char_relationships: Array = []
	for pair_key in relationships:
		var typed_pair_key: Variant = pair_key
		var chars = _split_pair_key(pair_key)
		if chars[0] == character or chars[1] == character:
			char_relationships.append({
				"character": chars[0] if chars[1] == character else chars[1],
				"relationship": relationships[pair_key]
			})
	return char_relationships

func roll_crew_characteristic() -> String:
	# Base implementation - should be overridden by game-specific implementations
	if CREW_CHARACTERISTICS.is_empty():
		push_error("CREW_CHARACTERISTICS dictionary is empty. Override this in your derived class.")
		return ""

	var keys = CREW_CHARACTERISTICS.values()
	return keys[randi() % keys.size()]

func roll_meeting_story() -> String:
	# Base implementation - should be overridden by game-specific implementations
	if RELATIONSHIP_TYPES.is_empty():
		push_error("RELATIONSHIP_TYPES dictionary is empty. Override this in your derived class.")
		return ""

	var keys = RELATIONSHIP_TYPES.values()
	return keys[randi() % keys.size()]

func generate_initial_relationships(crew_members: Array) -> void:
	# Roll for overall crew characteristic and meeting story
	crew_characteristic = roll_crew_characteristic()
	crew_meeting_story = roll_meeting_story()

	# Generate relationships between crew _members
	for i: int in range(crew_members.size()):
		for j: int in range(i + 1, crew_members.size()):
			var char1 = crew_members[i]
			var char2 = crew_members[j]

			# Roll for relationship type
			var relationship_types = RELATIONSHIP_TYPES.values()
			if relationship_types.is_empty():
				push_error("RELATIONSHIP_TYPES dictionary is empty. Override this in your derived class.")
				continue

			var random_relationship = relationship_types[randi() % relationship_types.size()]
			add_relationship(char1, char2, random_relationship)
func _get_pair_key(char1: Variant, char2: Variant) -> String:
	# Create a consistent key for a pair of characters
	var id1 = char1.get_instance_id()
	var id2 = char2.get_instance_id()
	return str(min(id1, id2)) + "_" + str(max(id1, id2))

func _split_pair_key(pair_key: String) -> Array:
	var ids = pair_key.split("_")
	if ids.size() != 2:
		push_warning("BaseCrewRelationshipManager: Invalid pair key format: %s" % pair_key)
		return []
	
	var char1 = instance_from_id(int(ids[0]))
	var char2 = instance_from_id(int(ids[1]))
	
	if not is_instance_valid(char1) or not is_instance_valid(char2):
		push_warning("BaseCrewRelationshipManager: Invalid character instances for pair key: %s" % pair_key)
		return []
		
	return [char1, char2]

func serialize() -> Dictionary:
	var serialized_relationships: Dictionary = {}
	for pair_key in relationships:
		var typed_pair_key: Variant = pair_key
		serialized_relationships[pair_key] = relationships[pair_key]

	return {
		"relationships": serialized_relationships,
		"crew_characteristic": crew_characteristic,
		"crew_meeting_story": crew_meeting_story
	}

func deserialize(data: Dictionary) -> void:
	relationships.clear()

	for pair_key in data.get("relationships", {}):
		relationships[pair_key] = data["relationships"][pair_key]

	crew_characteristic = data.get("crew_characteristic", "")

	crew_meeting_story = data.get("crew_meeting_story", "")

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null