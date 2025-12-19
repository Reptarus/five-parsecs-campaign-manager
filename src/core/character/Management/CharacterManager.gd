class_name CharacterManagerClass
extends Node

## Character manager for Five Parsecs campaign
## Manages character creation, advancement, and crew management

# Dependencies loaded at runtime to avoid circular dependencies
# GlobalEnums available as autoload singleton

signal character_created(character: Character)
signal character_removed(character_id: String)
signal character_updated(character: Character)
signal crew_size_changed(new_size: int)

var crew_roster: Array[Character] = []
var max_crew_size: int = 8
var active_crew: Array[Character] = []

func _ready() -> void:
	_initialize_manager()

func _initialize_manager() -> void:
	crew_roster.clear()
	active_crew.clear()
	_register_with_game_state()

func _register_with_game_state() -> void:
	"""Register this manager with GameStateManager for cross-system communication"""
	# Guard against calling get_node when not in scene tree
	if not is_inside_tree():
		push_warning("CharacterManager: Not in scene tree, skipping GameStateManager registration")
		return
	var game_state = get_node_or_null("/root/GameStateManagerAutoload") as Node
	if game_state and game_state.has_method("register_manager"):
		game_state.register_manager("CharacterManager", self)
		print("CharacterManager: Registered with GameStateManager")
	else:
		push_warning("CharacterManager: GameStateManager not available for registration")

func create_character(character_data: Dictionary = {}) -> Character:
	var character: Character = Character.new()

	# Apply provided data or use defaults
	character.character_name = character_data.get("name", "New Character")
	# character_class expects a String, not int enum - convert if needed
	var class_value: Variant = character_data.get("class", "NONE")
	if class_value is int:
		# Convert enum int to string name
		character.character_class = GlobalEnums.CharacterClass.keys()[class_value] if class_value < GlobalEnums.CharacterClass.size() else "NONE"
	else:
		character.character_class = str(class_value)

	# Add to roster (may fail if roster full or duplicate ID)
	var added = add_character_to_roster(character)

	# Only emit signal if character was successfully added to roster
	if added:
		character_created.emit(character)

	# Return character even if not added (test design expects this)
	return character

func add_character_to_roster(character: Character) -> bool:
	# Guard against null character
	if character == null:
		push_error("Cannot add null character to roster")
		return false
	
	if crew_roster.size() >= max_crew_size:
		return false

	# Prevent duplicate character IDs
	var char_id: String = character.character_id if character.character_id != null else ""
	if not char_id.is_empty() and get_character_by_id(char_id) != null:
		push_error("Character with ID %s already exists in crew roster" % char_id)
		return false

	crew_roster.append(character)
	crew_size_changed.emit(crew_roster.size())
	return true

func remove_character_from_roster(character_id: String) -> bool:
	# Validate character_id (null/empty check)
	if character_id == null or character_id.is_empty():
		push_warning("Cannot remove character: invalid character ID")
		return false

	for i: int in range(crew_roster.size()):
		if crew_roster[i].character_id == character_id:
			# Prevent crew size from dropping below minimum
			if crew_roster.size() <= FiveParsecsConstants.CHARACTER_CREATION.min_crew_size:
				push_error("Cannot remove character: crew size would drop below minimum of 4")
				return false

			crew_roster.remove_at(i)

			# SYNCHRONIZE ACTIVE CREW - Remove character from active crew if present
			for j in range(active_crew.size() - 1, -1, -1):
				if active_crew[j].character_id == character_id:
					active_crew.remove_at(j)
					break

			character_removed.emit(character_id)
			crew_size_changed.emit(crew_roster.size())
			return true
	return false

func get_character_by_id(character_id: String) -> Character:
	for character in crew_roster:
		if character.character_id == character_id:
			return character
	return null

func get_crew_roster() -> Array[Character]:
	return crew_roster.duplicate()

func get_active_crew() -> Array[Character]:
	# Ensure never returns null, always a valid array
	if active_crew == null:
		active_crew = []
	return active_crew.duplicate()

func set_active_crew(characters: Array) -> void:
	active_crew.clear()
	for char in characters:
		if char is Character:
			active_crew.append(char)

func get_crew_size() -> int:
	return crew_roster.size()

func get_max_crew_size() -> int:
	return max_crew_size

func set_max_crew_size(size: int) -> void:
	max_crew_size = maxi(1, size)

func advance_character(character: Character, advancement_type: String) -> bool:
	# Stub for character advancement
	if character in crew_roster:
		character_updated.emit(character)
		return true
	return false

func heal_character(character: Character, amount: int) -> void:
	if character in crew_roster:
		if character and character.has_method("heal"): character.heal(amount)
		character_updated.emit(character)

func assign_equipment(character: Character, equipment: Dictionary) -> bool:
	if character in crew_roster:
		# Stub for equipment assignment
		character_updated.emit(character)
		return true
	return false

func get_crew_statistics() -> Dictionary:
	return {
		"total_crew": crew_roster.size(),
		"active_crew": active_crew.size(),
		"max_crew": max_crew_size,
		"average_level": _calculate_average_level(),
		"total_experience": _calculate_total_experience()
	}

func _calculate_average_level() -> float:
	if crew_roster.is_empty():
		return 0.0

	var total_level: int = 0
	for character in crew_roster:
		total_level += character.level

	return float(total_level) / float(crew_roster.size())

func _calculate_total_experience() -> int:
	var total: int = 0
	for character in crew_roster:
		total += character.experience
	return total

func save_crew_data() -> Dictionary:
	var data: Dictionary = {
		"crew_roster": [],
		"active_crew_ids": [],
		"max_crew_size": max_crew_size
	}

	for character in crew_roster:
		data["crew_roster"].append(character.serialize())

	for character in active_crew:
		data["active_crew_ids"].append(character.character_id)

	return data

func load_crew_data(data: Dictionary) -> bool:
	crew_roster.clear()
	active_crew.clear()

	max_crew_size = data.get("max_crew_size", 8)

	# Load crew roster
	var roster_data = data.get("crew_roster", [])
	for character_data in roster_data:
		var character: Character = Character.new()
		character.deserialize(character_data)
		crew_roster.append(character)

	# Restore active crew
	var active_ids = data.get("active_crew_ids", [])
	for character_id in active_ids:
		var character: Character = get_character_by_id(character_id)
		if character:
			active_crew.append(character)

	crew_size_changed.emit(crew_roster.size())
	return true

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
