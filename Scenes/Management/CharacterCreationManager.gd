extends Node

class_name CharacterCreationManager

@export var character_creation: CharacterCreation

func _ready():
	if not character_creation:
		character_creation = CharacterCreation.new()

func create_character(species, background, motivation, character_class, game_state):
	return character_creation.character_creation_logic.create_character(species, background, motivation, character_class, game_state)

func create_tutorial_character(game_state):
	return character_creation.character_creation_logic.create_tutorial_character(game_state)

func get_random_options() -> Dictionary:
	return character_creation.get_random_options()

func get_all_species() -> Array[Dictionary]:
	return character_creation.get_all_species()

func get_all_backgrounds() -> Array[Dictionary]:
	return character_creation.get_all_backgrounds()

func get_all_motivations() -> Array[Dictionary]:
	return character_creation.get_all_motivations()

func get_all_classes() -> Array[Dictionary]:
	return character_creation.get_all_classes()
