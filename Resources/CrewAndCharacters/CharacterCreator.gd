class_name CharacterCreator
extends Resource

var character_data: CharacterCreationData

func _init() -> void:
    character_data = CharacterCreationData.new()

func edit_character(character: Character) -> void:
    # Implement character editing
    pass