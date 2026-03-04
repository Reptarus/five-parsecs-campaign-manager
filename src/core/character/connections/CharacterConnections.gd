@tool
class_name CharacterConnections
extends RefCounted

## Five Parsecs character connections and rivals system
## Manages starting contacts, patrons, and rival generation

# Safe imports
const UniversalResourceLoader := preload("res://src/core/systems/UniversalResourceLoader.gd")
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Cached connection data
static var _connections_table: Dictionary = {}
static var _tables_loaded: bool = false

## Generate starting connections for character
static func generate_starting_connections(character: Character) -> Array[Dictionary]:
	_ensure_tables_loaded()

	var connections: Array[Dictionary] = []

	# Background-based connections
	var background_connections: Array[Dictionary] = _get_background_connections(character.background)
	connections.append_array(background_connections)

	# Random connection roll (optional)
	var dice_manager: Node = Engine.get_singleton("DiceManager")

	if dice_manager and dice_manager.has_method("roll_d6"):
		if dice_manager.roll_d6("Random Connection") >= 5:
			var random_connection: Dictionary = _roll_random_connection()
			connections.append(random_connection)

	return connections

## Generate starting rivals/enemies  
static func generate_starting_rivals(character: Character) -> Array[Dictionary]:
	var rivals: Array[Dictionary] = []

	# Check background events for rival generation
	if not character.has_method("has_trait"):
		return rivals

	# Look for rival-generating attributes
	var character_traits: Array = character.traits
	for i: int in range(character_traits.size()):
		var character_attribute: String = character_traits[i]
		if character_attribute is String:
			var attribute_lower: String = character_attribute.to_lower()
			if "rival" in attribute_lower or "enemy" in attribute_lower:
				rivals.append({
					"type": "rival",
					"name": _extract_rival_name_from_attribute(character_attribute),
					"relationship": "hostile",
					"origin": "background_event"
				})

	return rivals

## Generate patron connections (for advanced characters)
static func generate_patron_connections(character: Character) -> Array[Dictionary]:
	var patrons: Array[Dictionary] = []

	# Check if character qualifies for patron connections based on background - now using string comparison
	match character.background:
		"NOBLE":
			patrons.append({
				"type": "patron",
				"name": "Noble House Contact",
				"influence": "major",
				"location": "sector",
				"relationship": "allied"
			})
		"MILITARY":
			patrons.append({
				"type": "patron",
				"name": "Military Command",
				"influence": "moderate",
				"location": "regional",
				"relationship": "friendly"
			})
		"ACADEMIC":
			patrons.append({
				"type": "patron",
				"name": "Research Institution",
				"influence": "major",
				"location": "galactic",
				"relationship": "professional"
			})

	return patrons

## Get background-specific connections
static func _get_background_connections(background: String) -> Array[Dictionary]:
	var bg_connections: Dictionary = _connections_table.get("background_connections", {})
	var bg_name: String = background.to_lower()
	var connections: Array = bg_connections.get(bg_name, [])

	var result: Array[Dictionary] = []
	for connection: Dictionary in connections:
		if connection is Dictionary:
			result.append(connection)

	return result

## Roll random connection from table
static func _roll_random_connection() -> Dictionary:
	var dice_manager: Node = Engine.get_singleton("DiceManager")

	if not dice_manager or not dice_manager.has_method("roll_d6"):
		return {"type": "contact", "name": "Unknown Contact", "influence": "minor"}

	var random_table: Dictionary = _connections_table.get("random_connections", {})

	return random_table.get(str(dice_manager.roll_d6("Random Connection")), {"type": "contact", "name": "Unknown Contact", "influence": "minor"})

## Extract rival name from background event attribute
static func _extract_rival_name_from_attribute(attribute_text: String) -> String:
	# Simple extraction based on common patterns
	if "commanding officer" in attribute_text.to_lower():
		return "Former Commanding Officer"
	elif "criminal associate" in attribute_text.to_lower():
		return "Former Criminal Associate"
	elif "employer" in attribute_text.to_lower():
		return "Former Employer"
	elif "partner" in attribute_text.to_lower():
		return "Former Business Partner"
	elif "syndicate" in attribute_text.to_lower():
		return "Crime Syndicate"
	else:
		return "Unknown Rival"

## Apply connections to character
static func apply_connections_to_character(character: Character, connections: Array) -> void:
	# Store connections as character traits
	for connection: Dictionary in connections:
		var connection_trait: String = _format_connection_as_trait(connection)
		if character and character.has_method("add_trait"):
			character.add_trait(connection_trait)

## Format connection as a trait string
static func _format_connection_as_trait(connection: Dictionary) -> String:
	var conn_type: String = connection.get("type", "contact")
	var node_name: String = connection.get("name", "Unknown")
	var influence: String = connection.get("influence", "minor")

	return "Connection: %s (%s %s)" % [node_name, influence, conn_type]

## Load connections tables safely
static func _ensure_tables_loaded() -> void:
	if _tables_loaded:
		return

	var connections_path := "res://data/character_creation_tables/connections_table.json"
	_connections_table = UniversalResourceLoader.load_json_safe(connections_path, "CharacterConnections connections table")
	_tables_loaded = true

	pass

## Validate connections tables
static func validate_connections_tables() -> bool:
	_ensure_tables_loaded()

	var is_valid := true

	# Check required sections
	var required_sections = ["background_connections", "random_connections"]
	for section: String in required_sections:
		if not _connections_table.has(section):
			push_error("CharacterConnections: Missing required section: " + section)
			is_valid = false
		elif _connections_table[section].is_empty():
			push_error("CharacterConnections: Empty section: " + section)
			is_valid = false

	if is_valid:
		pass

	return is_valid

## Get connection statistics for debugging
static func get_connection_statistics() -> Dictionary:
	_ensure_tables_loaded()

	var stats: Dictionary = {
		"background_connections": {},
		"random_connections": 0
	}

	# Count background connections
	var bg_connections: Dictionary = _connections_table.get("background_connections", {})
	for bg_name: String in bg_connections.keys():
		var bg_data = bg_connections[bg_name]
		if bg_data is Array:
			stats.background_connections[bg_name] = bg_data.size()

	# Count random connections
	var random_connections: Dictionary = _connections_table.get("random_connections", {})
	stats.random_connections = random_connections.size()

	return stats

## Test connection generation for character
static func test_connection_generation(background: String) -> Dictionary:
	var character: Character = Character.new()
	character.background = background

	var connections = generate_starting_connections(character)
	var rivals = generate_starting_rivals(character)
	var patrons = generate_patron_connections(character)

	return {
		"connections": connections,
		"rivals": rivals,
		"patrons": patrons,
		"total_relationships": connections.size() + rivals.size() + patrons.size()
	}