class_name CharacterDataManager
extends Node

const SAVE_DIR = "user://saves/"
const CHARACTER_FILE_EXTENSION = ".char.json"
const CREW_FILE_EXTENSION = ".crew.json"

func save_character(character, file_name: String) -> void:
    var dir = DirAccess.open(SAVE_DIR)
    if not dir:
        DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    
    var file = FileAccess.open(SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(character.serialize()))
        file.close()

func load_character(file_name: String):
    var file = FileAccess.open(SAVE_DIR + file_name + CHARACTER_FILE_EXTENSION, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        if error == OK:
            var character = Character.new()
            Character.deserialize(json.data)
            return character
    return null

func save_crew(crew: Array, file_name: String) -> void:
    var dir = DirAccess.open(SAVE_DIR)
    if not dir:
        DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    
    var crew_data = crew.map(func(character): return character.serialize())
    var file = FileAccess.open(SAVE_DIR + file_name + CREW_FILE_EXTENSION, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(crew_data))
        file.close()

func load_crew(file_name: String) -> Array:
    var file = FileAccess.open(SAVE_DIR + file_name + CREW_FILE_EXTENSION, FileAccess.READ)
    if file:
        var json = JSON.new()
        var error = json.parse(file.get_as_text())
        file.close()
        if error == OK:
            var characters = []
            for char_data in json.data:
                var character = Character.new()
                Character.deserialize(char_data)
                characters.append(character)
            return characters
    return []
