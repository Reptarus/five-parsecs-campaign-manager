class_name CharacterCreationLogic
extends Resource

var character_creation_data: CharacterCreationData

func _init():
	character_creation_data = CharacterCreationData.new()
	character_creation_data.load_data()

func create_character(species_id: String, background_id: String, motivation_id: String, class_id: String, _game_state_manager: GameStateManagerNode) -> Character:
	var character = Character.new()
	
	var species_data = character_creation_data.get_species_data(species_id)
	var background_data = character_creation_data.get_background_data(background_id)
	var motivation_data = character_creation_data.get_motivation_data(motivation_id)
	var class_data = character_creation_data.get_class_data(class_id)
	
	character.species = GlobalEnums.Species.get(species_data["name"].to_upper())
	character.background = GlobalEnums.Background.get(background_data["name"].to_upper())
	character.motivation = GlobalEnums.Motivation.get(motivation_data["name"].to_upper())
	character.character_class = GlobalEnums.Class.get(class_data["name"].to_upper())
	
	_apply_species_effects(character, species_data)
	_apply_background_effects(character, background_data)
	_apply_class_abilities(character, class_data)
	
	return character

func create_tutorial_character(_game_state_manager: GameState) -> Character:
	var character = Character.new()
	
	var species_data = character_creation_data.get_tutorial_species_data("human")
	var _background_data = character_creation_data.get_tutorial_background_data("rookie")
	var _motivation_data = character_creation_data.get_tutorial_motivation_data("adventure")
	var class_data = character_creation_data.get_tutorial_class_data("soldier")
	
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
	for stat in species_data["effects"]:
		var value = species_data["effects"][stat]
		character.set(stat, character.get(stat) + value)

func _apply_background_effects(character: Character, background_data: Dictionary) -> void:
	for stat in background_data["effects"]:
		var value = background_data["effects"][stat]
		character.set(stat, character.get(stat) + value)

func _apply_class_abilities(character: Character, class_data: Dictionary) -> void:
	for ability in class_data["abilities"]:
		character.traits.append(ability)
