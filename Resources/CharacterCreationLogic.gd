extends Node

var character_creation_data: CharacterCreationData

func _ready():
    character_creation_data = CharacterCreationData.new()
    character_creation_data.load_data()

func create_character(species_id: String, background_id: String, motivation_id: String, class_id: String) -> Character:
    var character = Character.new()
    
    var species_data = character_creation_data.get_race_data(species_id)
    var background_data = character_creation_data.get_background_data(background_id)
    var motivation_data = character_creation_data.get_motivation_data(motivation_id)
    var class_data = character_creation_data.get_class_data(class_id)
    
    character.species = species_data["name"]
    character.background = background_data["name"]
    character.motivation = motivation_data["name"]
    character.character_class = class_data["name"]
    
    _apply_species_effects(character, species_data)
    _apply_background_effects(character, background_data)
    _apply_class_abilities(character, class_data)
    
    return character

func create_tutorial_character() -> Character:
    var character = Character.new()
    var creation_data = CharacterCreationData.new()
    creation_data.load_data()
    
    var race_data = creation_data.get_tutorial_race_data("human")
    var background_data = creation_data.get_tutorial_background_data("rookie")
    var motivation_data = creation_data.get_tutorial_motivation_data("adventure")
    var class_data = creation_data.get_tutorial_class_data("soldier")
    
    character.species = race_data.name
    character.background = background_data.name
    character.motivation = motivation_data.name
    character.character_class = class_data.name
    
    # Apply effects and abilities
    for stat in race_data.effects:
        var value = race_data.effects[stat]
        character.set(stat, character.get(stat) + value)
    
    # Add class abilities
    character.traits.append_array(class_data.abilities)
    
    # Set default stats for tutorial character
    character.reactions = 2
    character.speed = 2
    character.combat_skill = 2
    character.toughness = 2
    character.savvy = 2
    character.luck = 1
    
    # Add basic equipment
    var basic_pistol = load("res://Resources/Weapons/BasicPistol.tres")
    character.equip_weapon(basic_pistol)
    
    var medkit = load("res://Resources/Items/Medkit.tres")
    character.equip_item(medkit)
    return character

func _apply_species_effects(character, species_data: Dictionary) -> void:
    for stat in species_data["effects"]:
        var value = species_data["effects"][stat]
        character.set(stat, character.get(stat) + value)

func _apply_background_effects(character, background_data: Dictionary) -> void:
    for stat in background_data["effects"]:
        var value = background_data["effects"][stat]
        character.set(stat, character.get(stat) + value)

func _apply_class_abilities(character, class_data: Dictionary) -> void:
    for ability in class_data["abilities"]:
        character.traits.append(ability)

