@tool
extends Node
class_name CrewRelationshipManager

## Crew Relationship Manager - Core Rules Implementation
## Manages crew flavor details per Core Rules p.30 (Flavor Details section)
## - "We Met Through" table (d100)
## - "Characterized As" table (d100)
## - Individual character relationships

const Character = preload("res://src/core/character/Character.gd")

# Signals
signal relationship_added(char1: Character, char2: Character, relationship_type: String)
signal relationship_removed(char1: Character, char2: Character)
signal relationship_changed(character_a: String, character_b: String, relationship_type: String)
signal crew_morale_changed(new_morale: int)
signal flavor_generated(meeting_story: String, characteristic: String)

# Core Rules: "We Met Through" Table (d100) - p.30
const MEETING_STORIES: Dictionary = {
	Vector2i(1, 10): "Hired by a random member of the group",
	Vector2i(11, 20): "Pursuit of random group member's motivation",
	Vector2i(21, 30): "Being in trouble with the authorities",
	Vector2i(31, 40): "A common enemy",
	Vector2i(41, 50): "A common cause or belief",
	Vector2i(51, 65): "A random meeting in a bar",
	Vector2i(66, 75): "A previous job",
	Vector2i(76, 90): "Mutual protection in a hostile universe",
	Vector2i(91, 100): "Being old war buddies"
}

# Core Rules: "Characterized As" Table (d100) - p.30
const CREW_CHARACTERISTICS: Dictionary = {
	Vector2i(1, 12): "Lovable rogues",
	Vector2i(13, 21): "Consummate professionals",
	Vector2i(22, 28): "Cut-throat outlaws",
	Vector2i(29, 34): "Defenders of the down-trodden",
	Vector2i(35, 48): "Hardened rebels",
	Vector2i(49, 58): "Starport scum",
	Vector2i(59, 72): "Somewhat honorable bandits",
	Vector2i(73, 87): "In it for the credits",
	Vector2i(88, 100): "Living the dream!"
}

# Individual relationship types between crew members
const RELATIONSHIP_TYPES: Dictionary = {
	"NEUTRAL": "Neutral",
	"FRIENDS": "Friends",
	"RIVALS": "Rivals",
	"ROMANTIC": "Romantic partners",
	"FAMILY": "Family",
	"MENTOR": "Mentor/Protégé",
	"BUSINESS": "Business partners",
	"OLD_COMRADES": "Old comrades",
	"UNEASY_ALLIANCE": "Uneasy alliance"
}

# Crew flavor data
var crew_meeting_story: String = ""
var crew_characteristic: String = ""
var relationships: Dictionary = {}  # Key: "char1_id:char2_id", Value: relationship type string
var crew_morale: int = 50

func _ready() -> void:
	pass

## Generate crew flavor details using Core Rules tables
func generate_crew_flavor() -> void:
	crew_meeting_story = _roll_meeting_story()
	crew_characteristic = _roll_characteristic()
	flavor_generated.emit(crew_meeting_story, crew_characteristic)

## Generate initial relationships for a new crew
func generate_initial_relationships(members: Array) -> void:
	# First, generate crew-wide flavor
	generate_crew_flavor()

	# Then optionally generate some random relationships between crew members
	# Core Rules don't mandate individual relationships, but we support them
	relationships.clear()

	# Optionally seed some starting relationships based on crew characteristic
	if members.size() >= 2:
		# Create one random relationship to add flavor
		var char1 = members[randi() % members.size()]
		var char2 = members[randi() % members.size()]
		# SPRINT 26.21 FIX: Compare by ID to handle mixed Object/Dictionary types
		var id1 = _get_character_id(char1)
		var id2 = _get_character_id(char2)
		if id1 != id2 and not id1.is_empty() and not id2.is_empty():
			var types_array = RELATIONSHIP_TYPES.values()
			var random_type = types_array[randi() % types_array.size()]
			add_relationship(char1, char2, random_type)

## SPRINT 26.21: Extract character ID from Object or Dictionary safely
func _get_character_id(char_data) -> String:
	"""Extract character ID from Object or Dictionary safely to avoid type comparison errors"""
	if char_data == null:
		return ""
	if char_data is Dictionary:
		return str(char_data.get("character_id", char_data.get("character_name", char_data.get("name", ""))))
	elif char_data is Object:
		# For Resource/Object types, use property access
		if "character_id" in char_data and char_data.character_id:
			return str(char_data.character_id)
		elif "character_name" in char_data and char_data.character_name:
			return str(char_data.character_name)
		elif "name" in char_data and char_data.name:
			return str(char_data.name)
	return ""

## Roll on the "We Met Through" table (d100)
func _roll_meeting_story() -> String:
	var roll = (randi() % 100) + 1
	for range_key in MEETING_STORIES:
		if roll >= range_key.x and roll <= range_key.y:
			return MEETING_STORIES[range_key]
	return "A random meeting in a bar"  # Default fallback

## Roll on the "Characterized As" table (d100)
func _roll_characteristic() -> String:
	var roll = (randi() % 100) + 1
	for range_key in CREW_CHARACTERISTICS:
		if roll >= range_key.x and roll <= range_key.y:
			return CREW_CHARACTERISTICS[range_key]
	return "Lovable rogues"  # Default fallback

## Add a relationship between two characters
func add_relationship(char1, char2, relationship_type: String) -> void:
	if char1 == null or char2 == null:
		return

	var key = _get_relationship_key(char1, char2)
	relationships[key] = relationship_type

	# Emit signal with Character objects if possible
	if char1 is Character and char2 is Character:
		relationship_added.emit(char1, char2, relationship_type)

	# Also emit the string-based signal for compatibility
	var name1 = _get_character_name(char1)
	var name2 = _get_character_name(char2)
	relationship_changed.emit(name1, name2, relationship_type)

## Remove a relationship between two characters
func remove_relationship(char1, char2) -> void:
	if char1 == null or char2 == null:
		return

	var key = _get_relationship_key(char1, char2)
	if relationships.has(key):
		relationships.erase(key)
		if char1 is Character and char2 is Character:
			relationship_removed.emit(char1, char2)

## Get all relationships for a specific character
func get_all_relationships(character) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var char_name = _get_character_name(character)

	for key in relationships:
		var parts = key.split(":")
		if parts.size() == 2:
			if parts[0] == char_name or parts[1] == char_name:
				var other_name = parts[0] if parts[1] == char_name else parts[1]
				result.append({
					"character": _find_character_by_name(other_name),
					"character_name": other_name,
					"relationship": relationships[key]
				})

	return result

## Get the relationship between two specific characters
func get_relationship(character_a, character_b) -> String:
	var key = _get_relationship_key(character_a, character_b)
	return relationships.get(key, "Neutral")

## Update crew morale
func update_crew_morale(change: int) -> void:
	crew_morale = clamp(crew_morale + change, 0, 100)
	crew_morale_changed.emit(crew_morale)

func get_crew_morale() -> int:
	return crew_morale

## Generate consistent relationship key regardless of character order
func _get_relationship_key(char1, char2) -> String:
	var name1 = _get_character_name(char1)
	var name2 = _get_character_name(char2)
	var sorted_names = [name1, name2]
	sorted_names.sort()
	return sorted_names[0] + ":" + sorted_names[1]

## Get character name from various input types
func _get_character_name(character) -> String:
	if character == null:
		return ""
	if character is String:
		return character
	if character is Character:
		return character.character_name
	if character is Dictionary and character.has("character_name"):
		return character["character_name"]
	if character is Dictionary and character.has("name"):
		return character["name"]
	return str(character)

## Find character by name (placeholder - needs crew reference)
func _find_character_by_name(_name: String):
	# This would need a reference to the crew members array
	# For now, return null - the panel handles this via its own crew_members array
	return null

## Serialize for save/load
func serialize() -> Dictionary:
	return {
		"meeting_story": crew_meeting_story,
		"characteristic": crew_characteristic,
		"relationships": relationships.duplicate(),
		"morale": crew_morale
	}

## Deserialize from saved data
func deserialize(data: Dictionary) -> void:
	crew_meeting_story = data.get("meeting_story", "")
	crew_characteristic = data.get("characteristic", "")
	relationships = data.get("relationships", {}).duplicate()
	crew_morale = data.get("morale", 50)

## Set specific meeting story (for manual/custom selection)
func set_meeting_story(story: String) -> void:
	crew_meeting_story = story

## Set specific characteristic (for manual/custom selection)
func set_characteristic(characteristic: String) -> void:
	crew_characteristic = characteristic

## Get all possible meeting stories for UI dropdown
static func get_all_meeting_stories() -> Array[String]:
	var stories: Array[String] = []
	for story in MEETING_STORIES.values():
		stories.append(story)
	return stories

## Get all possible characteristics for UI dropdown
static func get_all_characteristics() -> Array[String]:
	var chars: Array[String] = []
	for char_type in CREW_CHARACTERISTICS.values():
		chars.append(char_type)
	return chars
