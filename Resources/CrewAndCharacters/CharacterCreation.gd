# Resources/CharacterCreation.gd
class_name CharacterCreation
extends Resource

var character_creation_data: CharacterCreationData
@export var character_creation_logic: CharacterCreationLogic

func _init() -> void:
	character_creation_data = CharacterCreationData.new()
	character_creation_data.load_data()
	character_creation_logic = load("res://Resources/CharacterCreationLogic.gd").new()

func get_random_options() -> Dictionary:
	return {
		"species": _get_random_element(get_all_species()).id,
		"background": _get_random_element(get_all_backgrounds()).id,
		"motivation": _get_random_element(get_all_motivations()).id,
		"character_class": _get_random_element(get_all_classes()).id
	}

func _get_random_element(array: Array) -> Variant:
	return array[randi() % array.size()]

func create_random_character(game_state_manager: GameStateManager) -> Character:
	var options = get_random_options()
	return character_creation_logic.create_character(
		GlobalEnums.Species[options.species.to_upper()],
		GlobalEnums.Background[options.background.to_upper()],
		GlobalEnums.Motivation[options.motivation.to_upper()],
		GlobalEnums.Class[options.character_class.to_upper()],
		game_state_manager.game_state
	)

func get_background_data(background_id: String) -> Dictionary:
	return character_creation_data.get_background_data(background_id)

func get_class_data(class_id: String) -> Dictionary:
	return character_creation_data.get_class_data(class_id)

func get_all_species() -> Array[Dictionary]:
	return character_creation_data.get_all_species()

func get_all_backgrounds() -> Array[Dictionary]:
	return character_creation_data.get_all_backgrounds()

func get_all_motivations() -> Array[Dictionary]:
	return character_creation_data.get_all_motivations()

func get_all_classes() -> Array[Dictionary]:
	return character_creation_data.get_all_classes()
