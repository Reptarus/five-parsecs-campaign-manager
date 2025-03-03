@tool
extends Node

const Character = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Signals
signal relationship_added(char1: Character, char2: Character, relationship_type: String)
signal relationship_removed(char1: Character, char2: Character)
signal crew_characteristic_updated(new_characteristic: String)
signal crew_meeting_story_updated(new_story: String)

## Relationship constants
var RELATIONSHIP_TYPES: Dictionary = {
	"FRIENDS": "Friends",
	"RIVALS": "Rivals",
	"FAMILY": "Family",
	"PARTNERS": "Partners",
	"MENTOR_STUDENT": "Mentor and Student",
	"COMRADES": "Comrades",
	"UNEASY_ALLIES": "Uneasy Allies",
	"FORMER_ENEMIES": "Former Enemies",
	"BUSINESS_ASSOCIATES": "Business Associates",
	"STRANGERS": "Strangers"
}
var CREW_CHARACTERISTICS: Dictionary = {}

## Crew data
var crew_characteristic: String = ""
var crew_meeting_story: String = ""

## Relationship tracking
var relationships: Dictionary = {}
var event_logs: Array = []

## Initialization
func _init() -> void:
	# Default initialization
	pass

## Generate initial relationships for a crew
func generate_initial_relationships(crew_members: Array, density: float = 0.4) -> void:
	# Get crew characteristics and meeting story
	crew_characteristic = roll_crew_characteristic()
	crew_meeting_story = roll_meeting_story()
	
	# Clear existing relationships
	relationships.clear()
	
	# Generate random relationships
	for i in range(crew_members.size()):
		for j in range(i + 1, crew_members.size()):
			# Skip based on density
			if randf() > density:
				continue
			
			var char1 = crew_members[i]
			var char2 = crew_members[j]
			
			# Pick a random relationship type
			var relationship_types = RELATIONSHIP_TYPES.values()
			var rel_type = relationship_types[randi() % relationship_types.size()]
			
			add_relationship(char1, char2, rel_type)

## Roll for a crew characteristic
func roll_crew_characteristic() -> String:
	var crew_chars = CREW_CHARACTERISTICS.values()
	return crew_chars[randi() % crew_chars.size()]

## Roll for a meeting story
func roll_meeting_story() -> String:
	var stories = [
		"Met during a bar fight on Nexus Prime",
		"Survivors of a colony attack",
		"Former military unit gone rogue",
		"Assembled by a mysterious patron",
		"Escaped prisoners from a labor camp",
		"Crew of a salvage operation gone wrong",
		"Graduates from the same academy",
		"Brought together by a shared enemy",
		"Survivors of a ship crash",
		"Former rivals who joined forces"
	]
	
	return stories[randi() % stories.size()]

## Add a relationship between two characters
func add_relationship(char1: Character, char2: Character, relationship_type: String) -> void:
	if char1 == char2:
		push_warning("Cannot create relationship between the same character")
		return
	
	# Store the relationship in both directions
	if not relationships.has(char1):
		relationships[char1] = {}
	
	if not relationships.has(char2):
		relationships[char2] = {}
	
	relationships[char1][char2] = relationship_type
	relationships[char2][char1] = relationship_type
	
	relationship_added.emit(char1, char2, relationship_type)
	
	# Log the relationship creation
	event_logs.append({
		"type": "relationship_added",
		"timestamp": Time.get_unix_time_from_system(),
		"char1_name": char1.character_name,
		"char2_name": char2.character_name,
		"relationship": relationship_type
	})

## Remove a relationship between two characters
func remove_relationship(char1: Character, char2: Character) -> void:
	if char1 == char2:
		return
	
	# Remove the relationship in both directions
	if relationships.has(char1) and relationships[char1].has(char2):
		relationships[char1].erase(char2)
	
	if relationships.has(char2) and relationships[char2].has(char1):
		relationships[char2].erase(char1)
	
	relationship_removed.emit(char1, char2)
	
	# Log the relationship removal
	event_logs.append({
		"type": "relationship_removed",
		"timestamp": Time.get_unix_time_from_system(),
		"char1_name": char1.character_name,
		"char2_name": char2.character_name
	})

## Get a specific relationship between two characters
func get_relationship(char1: Character, char2: Character) -> String:
	if relationships.has(char1) and relationships[char1].has(char2):
		return relationships[char1][char2]
	
	return ""

## Get all relationships for a character
func get_all_relationships(character: Character) -> Array:
	var result = []
	
	if relationships.has(character):
		for other_char in relationships[character]:
			result.append({
				"character": other_char,
				"relationship": relationships[character][other_char]
			})
	
	return result

## Serialize relationship data for saving
func serialize() -> Dictionary:
	var data = {
		"crew_characteristic": crew_characteristic,
		"crew_meeting_story": crew_meeting_story,
		"relationships": {},
		"event_logs": event_logs
	}
	
	# Convert the character objects to their IDs or names
	for char1 in relationships:
		var char1_id = char1.get_instance_id()
		data.relationships[char1_id] = {}
		
		for char2 in relationships[char1]:
			var char2_id = char2.get_instance_id()
			data.relationships[char1_id][char2_id] = relationships[char1][char2]
	
	return data

## Deserialize relationship data from a save
func deserialize(data: Dictionary, crew_members: Array = []) -> void:
	# Clear existing data
	relationships.clear()
	
	crew_characteristic = data.get("crew_characteristic", "")
	crew_meeting_story = data.get("crew_meeting_story", "")
	event_logs = data.get("event_logs", [])
	
	# The actual relationships will need to be restored by the calling code
	# which has access to the character instances
	
	# Optionally emit signals to update UI
	crew_characteristic_updated.emit(crew_characteristic)
	crew_meeting_story_updated.emit(crew_meeting_story)
	
	# If there are no crew members provided, we can't reconstruct the relationships
	if crew_members.is_empty():
		return
	
	# Create a mapping of character IDs to character objects
	var id_to_character = {}
	for character in crew_members:
		id_to_character[character.character_id] = character
	
	# Reconstruct relationships
	var relationships_data = data.get("relationships", {})
	
	for char1_id in relationships_data:
		if not id_to_character.has(char1_id):
			continue
			
		var char1 = id_to_character[char1_id]
		
		for char2_id in relationships_data[char1_id]:
			if not id_to_character.has(char2_id):
				continue
				
			var char2 = id_to_character[char2_id]
			var relationship_type = relationships_data[char1_id][char2_id]
			
			# Add the relationship (without emitting signals)
			if not relationships.has(char1):
				relationships[char1] = {}
			
			if not relationships.has(char2):
				relationships[char2] = {}
			
			relationships[char1][char2] = relationship_type
			relationships[char2][char1] = relationship_type