class_name CharacterCreator
extends Resource

const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

class CreationData extends RefCounted:
    var character_name: String
    var origin: int  # GlobalEnums.Species
    var background: int  # GlobalEnums.Background
    var class_type: int  # GlobalEnums.Class
    var motivation: int  # GlobalEnums.Motivation
    var stats: Dictionary
    
    func _init() -> void:
        stats = {
            GlobalEnums.CharacterStats.LUCK: 0,
            GlobalEnums.CharacterStats.TECHNICAL: 0,
            GlobalEnums.CharacterStats.AGILITY: 0,
            GlobalEnums.CharacterStats.STRENGTH: 0,
            GlobalEnums.CharacterStats.INTELLIGENCE: 0,
            GlobalEnums.CharacterStats.COMBAT_SKILL: 0,
            GlobalEnums.CharacterStats.SURVIVAL: 0,
            GlobalEnums.CharacterStats.STEALTH: 0,
            GlobalEnums.CharacterStats.PILOTING: 0
        }

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
    creation_data.stats = character.stats.duplicate()

func apply_changes_to_character(character: Character) -> void:
    if not character:
        push_error("Attempting to apply changes to null character")
        return
        
    character.character_name = creation_data.character_name
    character.origin = creation_data.origin
    character.background = creation_data.background
    character.class_type = creation_data.class_type
    character.motivation = creation_data.motivation
    character.stats = creation_data.stats.duplicate()

func validate_character_data() -> bool:
    return (
        not creation_data.character_name.is_empty() and
        creation_data.origin >= 0 and
        creation_data.background >= 0 and
        creation_data.class_type >= 0 and
        creation_data.motivation >= 0 and
        not creation_data.stats.is_empty()
    )