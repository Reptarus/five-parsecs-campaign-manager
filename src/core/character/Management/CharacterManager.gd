@tool
extends Node
class_name FPCM_CoreCharacterManager

## Character manager for Five Parsecs campaign
## Manages character creation, advancement, and crew management

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

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

func create_character(character_data: Dictionary = {}) -> Character:
	var character = Character.new()
	
	# Apply provided data or use defaults
	character.character_name = character_data.get("name", "New Character")
	character.character_class = character_data.get("class", "Freelancer")
	
	# Add to roster
	add_character_to_roster(character)
	
	character_created.emit(character)
	return character

func add_character_to_roster(character: Character) -> bool:
	if crew_roster.size() >= max_crew_size:
		return false
	
	crew_roster.append(character)
	crew_size_changed.emit(crew_roster.size())
	return true

func remove_character_from_roster(character_id: String) -> bool:
	for i in range(crew_roster.size()):
		if crew_roster[i].character_id == character_id:
			crew_roster.remove_at(i)
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
	return active_crew.duplicate()

func set_active_crew(characters: Array[Character]) -> void:
	active_crew = characters.duplicate()

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
		character.heal(amount)
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
	
	var total_level = 0
	for character in crew_roster:
		total_level += character.level
	
	return float(total_level) / float(crew_roster.size())

func _calculate_total_experience() -> int:
	var total = 0
	for character in crew_roster:
		total += character.experience
	return total

func save_crew_data() -> Dictionary:
	var data = {
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
		var character = Character.new()
		character.deserialize(character_data)
		crew_roster.append(character)
	
	# Restore active crew
	var active_ids = data.get("active_crew_ids", [])
	for character_id in active_ids:
		var character = get_character_by_id(character_id)
		if character:
			active_crew.append(character)
	
	crew_size_changed.emit(crew_roster.size())
	return true
