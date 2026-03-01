extends Control

## CharacterStatusCard Species Abilities Example
## Demonstrates species ability badges with different species types

@onready var card_container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	_create_example_cards()

func _create_example_cards() -> void:
	## Create example cards for different species
	var example_characters := [
		{
			"character_name": "K'Erin Warrior",
			"species": "kerin",
			"combat": 2,
			"toughness": 5,
			"speed": 4,
			"health": 10,
			"max_health": 10
		},
		{
			"character_name": "Hulker Bruiser",
			"species": "hulker",
			"combat": 1,
			"toughness": 7,
			"speed": 2,
			"health": 12,
			"max_health": 12
		},
		{
			"character_name": "Swift Scout",
			"species": "swift",
			"combat": 0,
			"toughness": 2,
			"speed": 7,
			"health": 6,
			"max_health": 6
		},
		{
			"character_name": "Felinoid Rogue",
			"species": "felinoid",
			"combat": 1,
			"toughness": 4,
			"speed": 5,
			"health": 8,
			"max_health": 8
		}
	]
	
	for char_data in example_characters:
		var card_scene := preload("res://src/ui/components/battle/CharacterStatusCard.tscn")
		var card: FPCM_CharacterStatusCard = card_scene.instantiate()
		card_container.add_child(card)
		card.set_character_data(char_data)
