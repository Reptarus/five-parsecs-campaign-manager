extends Node

signal character_created(character: Character)
signal character_updated(character: Character)
signal character_deleted(character_id: String)
signal character_loaded(character: Character)
signal character_saved(character: Character)
signal character_error(message: String)
signal character_added(character: Character)
signal character_removed(character: Character)

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterCreator = preload("res://src/core/character/Generation/CharacterCreator.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

const SAVE_DIR = "user://saves/characters/"
const CHARACTER_FILE_EXTENSION = ".char.json"
const PORTRAIT_DIR = "user://portraits/"
const MAX_CHARACTERS = 20

var active_characters: Dictionary = {}  # character_id: Character
var character_creator: Node  # Will be CharacterCreator type
var game_state_manager: Node  # Will be GameStateManager type

func _init(_game_state_manager: Node = null) -> void:
	game_state_manager = _game_state_manager
	_ensure_directories_exist()

func _ready() -> void:
	# Initialize character creator
	character_creator = CharacterCreator.new()
	add_child(character_creator)
	
	# Connect signals
	character_creator.character_created.connect(_on_character_created)
	character_creator.character_edited.connect(_on_character_edited)

func _ensure_directories_exist() -> void:
	var dirs = [SAVE_DIR, PORTRAIT_DIR]
	for dir in dirs:
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

# Character Creation
func create_character(is_captain: bool = false) -> void:
	character_creator.start_creation(is_captain)

func edit_character(character: Character) -> void:
	character_creator.edit_character(character)

# Character Management
func add_character(character: Character) -> bool:
	if active_characters.size() >= MAX_CHARACTERS:
		character_error.emit("Maximum number of characters reached")
		return false
	
	var character_id = _generate_character_id(character)
	if active_characters.has(character_id):
		character_error.emit("Character already exists")
		return false
	
	active_characters[character_id] = character
	character_created.emit(character)
	character_added.emit(character)
	save_character(character)
	return true

func remove_character(character_id: String) -> void:
	if active_characters.has(character_id):
		var character = active_characters[character_id]
		active_characters.erase(character_id)
		character_deleted.emit(character_id)
		character_removed.emit(character)
		_delete_character_file(character_id)

func get_character(character_id: String) -> Character:
	return active_characters.get(character_id)

func get_character_by_index(index: int) -> Character:
	var keys = active_characters.keys()
	if index >= 0 and index < keys.size():
		return active_characters[keys[index]]
	return null

func get_all_characters() -> Array[Character]:
	return active_characters.values()

func get_active_character_count() -> int:
	return active_characters.size()

func update_character(character: Character) -> void:
	var character_id = _generate_character_id(character)
	if active_characters.has(character_id):
		active_characters[character_id] = character
		character_updated.emit(character)
		save_character(character)
	else:
		character_error.emit("Character not found: " + character.character_name)

# Save/Load Operations
func save_character(character: Character) -> void:
	var character_id = _generate_character_id(character)
	var save_path = SAVE_DIR + character_id + CHARACTER_FILE_EXTENSION
	
	# Save portrait if it exists
	if character.portrait_path.length() > 0:
		var portrait_file_name = character_id + "_portrait.png"
		var portrait_path = PORTRAIT_DIR + portrait_file_name
		
		if FileAccess.file_exists(character.portrait_path):
			var image = Image.new()
			var err = image.load(character.portrait_path)
			if err == OK:
				err = image.save_png(portrait_path)
				if err == OK:
					character.portrait_path = portrait_path
	
	# Save character data
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var save_data = character.serialize()
		save_data["character_id"] = character_id
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		character_saved.emit(character)
	else:
		character_error.emit("Failed to save character: " + character.character_name)

func load_character(character_id: String) -> Character:
	var save_path = SAVE_DIR + character_id + CHARACTER_FILE_EXTENSION
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			var character = Character.new()
			character.deserialize(json.data)
			
			# Load portrait if it exists
			if character.portrait_path.length() > 0 and FileAccess.file_exists(character.portrait_path):
				var image = Image.new()
				var err = image.load(character.portrait_path)
				if err != OK:
					push_error("Failed to load portrait: " + character.portrait_path)
					character.portrait_path = ""
			
			active_characters[character_id] = character
			character_loaded.emit(character)
			return character
		else:
			character_error.emit("Failed to parse character data: " + json.get_error_message())
	else:
		character_error.emit("Failed to load character file: " + character_id)
	
	return null

func load_all_characters() -> void:
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(CHARACTER_FILE_EXTENSION):
				var character_id = file_name.get_basename()
				load_character(character_id)
			file_name = dir.get_next()
		dir.list_dir_end()

# Character Status and Updates
func update_character_status(character: Character, new_status: int) -> void:
	character.status = new_status
	character_updated.emit(character)
	save_character(character)

func heal_character(character: Character, amount: int) -> void:
	character.stats.heal(amount)
	character_updated.emit(character)
	save_character(character)

func apply_damage(character: Character, amount: int) -> void:
	character.stats.take_damage(amount)
	if character.stats.current_health <= 0:
		update_character_status(character, GlobalEnums.CharacterStatus.INJURED)
	character_updated.emit(character)
	save_character(character)

func add_experience(character: Character, amount: int) -> void:
	character.stats.add_experience(amount)
	character_updated.emit(character)
	save_character(character)

# Equipment Management
func equip_item(character: Character, item: Resource) -> bool:
	var success = false
	
	if item is GameWeapon:
		character.equip_weapon(item)
		success = true
	elif item is Equipment:
		character.equip_gear(item)
		success = true
	
	if success:
		character_updated.emit(character)
		save_character(character)
	
	return success

func unequip_item(character: Character, item: Resource) -> bool:
	var success = false
	
	if item is GameWeapon:
		character.equipped_weapon = null
		success = true
	elif item is Equipment:
		character.unequip_gear(item)
		success = true
	
	if success:
		character_updated.emit(character)
		save_character(character)
	
	return success

# Internal Methods
func _generate_character_id(character: Character) -> String:
	return character.character_name.to_lower().replace(" ", "_")

func _delete_character_file(character_id: String) -> void:
	var save_path = SAVE_DIR + character_id + CHARACTER_FILE_EXTENSION
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(save_path)
	
	# Delete portrait if it exists
	var portrait_path = PORTRAIT_DIR + character_id + "_portrait.png"
	if FileAccess.file_exists(portrait_path):
		var dir = DirAccess.open(PORTRAIT_DIR)
		if dir:
			dir.remove(portrait_path)

# Signal Handlers
func _on_character_created(character: Character) -> void:
	add_character(character)

func _on_character_edited(character: Character) -> void:
	var character_id = _generate_character_id(character)
	if active_characters.has(character_id):
		active_characters[character_id] = character
		character_updated.emit(character)
		save_character(character)
	else:
		character_error.emit("Character not found: " + character.character_name) 