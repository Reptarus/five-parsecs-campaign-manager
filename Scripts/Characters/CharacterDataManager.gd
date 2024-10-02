class_name CharacterDataManager
extends Node

const SAVE_DIR = "user://saves/"
const CHARACTER_FILE_EXTENSION = ".char.json"
const CREW_FILE_EXTENSION = ".crew.json"

var game_state_manager: GameStateManager

func _init(_game_state_manager: GameStateManager):
    game_state_manager = _game_state_manager

func save_character(character: Character, file_name: String) -> void:
    var dir = DirAccess.open(SAVE_DIR)
    if not dir:
        DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    
    var file = FileAccess.open(SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(character.serialize()))
        file.close()
    else:
        push_error("Failed to open file for writing: " + SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION)

func load_character(file_name: String) -> Character:
    var file = FileAccess.open(SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        if error == OK:
            return Character.deserialize(json.data, game_state_manager)
        else:
            push_error("JSON Parse Error: " + json.get_error_message())
    else:
        push_error("Failed to open file for reading: " + SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION)
    return null

func save_crew(crew: Array[Character], file_name: String) -> void:
    var dir = DirAccess.open(SAVE_DIR)
    if not dir:
        DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    
    var crew_data = crew.map(func(character: Character): return character.serialize())
    var file = FileAccess.open(SAVE_DIR + file_name + CREW_FILE_EXTENSION, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(crew_data))
        file.close()
    else:
        push_error("Failed to open file for writing: " + SAVE_DIR + file_name + CREW_FILE_EXTENSION)

func load_crew(file_name: String) -> Array[Character]:
    var file = FileAccess.open(SAVE_DIR + file_name + CREW_FILE_EXTENSION, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        if error == OK:
            var characters: Array[Character] = []
            for char_data in json.data:
                var character = Character.deserialize(char_data, game_state_manager)
                characters.append(character)
            return characters
        else:
            push_error("JSON Parse Error: " + json.get_error_message())
    else:
        push_error("Failed to open file for reading: " + SAVE_DIR + file_name + CREW_FILE_EXTENSION)
    return []

func get_all_saved_characters() -> Array[String]:
    var dir = DirAccess.open(SAVE_DIR)
    var characters: Array[String] = []
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(CHARACTER_FILE_EXTENSION):
                characters.append(file_name.trim_suffix(CHARACTER_FILE_EXTENSION))
            file_name = dir.get_next()
    else:
        push_error("An error occurred when trying to access the save directory.")
    return characters

func get_all_saved_crews() -> Array[String]:
    var dir = DirAccess.open(SAVE_DIR)
    var crews: Array[String] = []
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(CREW_FILE_EXTENSION):
                crews.append(file_name.trim_suffix(CREW_FILE_EXTENSION))
            file_name = dir.get_next()
    else:
        push_error("An error occurred when trying to access the save directory.")
    return crews
