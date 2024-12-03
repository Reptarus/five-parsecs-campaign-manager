class_name CharacterCreator
extends Resource

const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const CharacterStats = preload("res://Resources/CrewAndCharacters/CharacterStats.gd")

class CreationData extends RefCounted:
    var character_name: String
    var origin: int  # GlobalEnums.Origin
    var background: int  # GlobalEnums.WorldTrait
    var class_type: int  # GlobalEnums.CrewRole
    var motivation: int  # GlobalEnums.FactionType
    var stats: CharacterStats
    
    func _init() -> void:
        stats = CharacterStats.new()

var creation_data: CreationData

func _init() -> void:
    creation_data = CreationData.new()

func edit_character(character: Character) -> void:
    if not character:
        push_error("Attempting to edit null character")
        return
        
    creation_data.character_name = character.character_name
    creation_data.origin = character.origin
    creation_data.background = character.background
    creation_data.class_type = character.class_type
    creation_data.motivation = character.motivation
    creation_data.stats.deserialize(character.stats.serialize())

func apply_changes_to_character(character: Character) -> void:
    if not character:
        push_error("Attempting to apply changes to null character")
        return
        
    character.character_name = creation_data.character_name
    character.origin = creation_data.origin
    character.background = creation_data.background
    character.class_type = creation_data.class_type
    character.motivation = creation_data.motivation
    character.stats.deserialize(creation_data.stats.serialize())

func validate_character_data() -> bool:
    return (
        not creation_data.character_name.is_empty() and
        creation_data.origin >= 0 and
        creation_data.background >= 0 and
        creation_data.class_type >= 0 and
        creation_data.motivation >= 0 and
        creation_data.stats != null
    )