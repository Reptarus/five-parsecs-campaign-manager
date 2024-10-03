class_name CharacterCreationLogic
extends Resource

var character_creation_data: CharacterCreationData

func _init():
	character_creation_data = CharacterCreationData.new()
	character_creation_data.load_data()

func create_character(species: GlobalEnums.Species, background: GlobalEnums.Background, 
                      motivation: GlobalEnums.Motivation, character_class: GlobalEnums.Class, 
                      _game_state: GameState) -> Character:
	var character = Character.new()
	
	var species_data = character_creation_data.get_species_data(GlobalEnums.Species.keys()[species].to_lower())
	var background_data = character_creation_data.get_background_data(GlobalEnums.Background.keys()[background].to_lower())
	var motivation_data = character_creation_data.get_motivation_data(GlobalEnums.Motivation.keys()[motivation].to_lower())
	var class_data = character_creation_data.get_class_data(GlobalEnums.Class.keys()[character_class].to_lower())
	
	if not species_data or not background_data or not motivation_data or not class_data:
		push_error("Failed to load character creation data")
		return null
	
	character.species = species
	character.background = background
	character.motivation = motivation
	character.character_class = character_class
	
	_apply_species_effects(character, species_data)
	_apply_background_effects(character, background_data)
	_apply_class_abilities(character, class_data)
	
	return character

func create_tutorial_character(_game_state: GameState) -> Character:
	var character = Character.new()
	
	var species_data = character_creation_data.get_tutorial_species_data("human")
	var background_data = character_creation_data.get_tutorial_background_data("rookie")
	var motivation_data = character_creation_data.get_tutorial_motivation_data("adventure")
	var class_data = character_creation_data.get_tutorial_class_data("soldier")
	
	if not species_data or not background_data or not motivation_data or not class_data:
		push_error("Failed to load tutorial character creation data")
		return null
	
	character.species = GlobalEnums.Species.HUMAN
	character.background = GlobalEnums.Background.MILITARY_BRAT
	character.motivation = GlobalEnums.Motivation.ADVENTURE
	character.character_class = GlobalEnums.Class.SOLDIER
	
	# Apply effects and abilities
	for stat in species_data.effects:
		var value = species_data.effects[stat]
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

func _apply_species_effects(character: Character, species_data: Dictionary) -> void:
	for stat in species_data.get("effects", {}):
		var value = species_data["effects"][stat]
		if character.get(stat) != null:
			character.set(stat, character.get(stat) + value)
		else:
			push_warning("Attempted to modify non-existent stat: " + stat)

func _apply_background_effects(character: Character, background_data: Dictionary) -> void:
	for stat in background_data.get("effects", {}):
		var value = background_data["effects"][stat]
		if character.get(stat) != null:
			character.set(stat, character.get(stat) + value)
		else:
			push_warning("Attempted to modify non-existent stat: " + stat)

func _apply_class_abilities(character: Character, class_data: Dictionary) -> void:
	for ability in class_data.get("abilities", []):
		character.traits.append(ability)
