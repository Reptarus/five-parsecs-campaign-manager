# VictoryConditionSelection.gd
extends Control
class_name VictoryConditionSelection

signal victory_condition_selected(condition)

@onready var condition_option_button = $ConditionOptionButton
@onready var confirm_button = $ConfirmButton
@onready var description_label = $DescriptionLabel

var victory_conditions = {
	"Play 20 campaign turns": {
		"type": "turns",
		"value": 20,
		"description": "Complete 20 campaign turns to achieve victory."
	},
	"Play 50 campaign turns": {
		"type": "turns",
		"value": 50,
		"description": "Complete 50 campaign turns to achieve victory."
	},
	"Play 100 campaign turns": {
		"type": "turns",
		"value": 100,
		"description": "Complete 100 campaign turns to achieve victory."
	},
	"Complete 3 Quests": {
		"type": "quests",
		"value": 3,
		"description": "Successfully complete 3 Quests to achieve victory."
	},
	"Complete 5 Quests": {
		"type": "quests",
		"value": 5,
		"description": "Successfully complete 5 Quests to achieve victory."
	},
	"Complete 10 Quests": {
		"type": "quests",
		"value": 10,
		"description": "Successfully complete 10 Quests to achieve victory."
	},
	"Win 20 tabletop battles": {
		"type": "battles",
		"value": 20,
		"description": "Win 20 tabletop battles to achieve victory."
	},
	"Win 50 tabletop battles": {
		"type": "battles",
		"value": 50,
		"description": "Win 50 tabletop battles to achieve victory."
	},
	"Win 100 tabletop battles": {
		"type": "battles",
		"value": 100,
		"description": "Win 100 tabletop battles to achieve victory."
	},
	"Kill 10 Unique Individuals": {
		"type": "unique_kills",
		"value": 10,
		"description": "Defeat 10 Unique Individuals in battle to achieve victory."
	},
	"Kill 25 Unique Individuals": {
		"type": "unique_kills",
		"value": 25,
		"description": "Defeat 25 Unique Individuals in battle to achieve victory."
	},
	"Upgrade a single character 10 times": {
		"type": "character_upgrades",
		"value": 10,
		"description": "Upgrade any single character 10 times to achieve victory."
	},
	"Upgrade 3 characters 10 times": {
		"type": "multi_character_upgrades",
		"value": {"characters": 3, "upgrades": 10},
		"description": "Upgrade 3 different characters 10 times each to achieve victory."
	},
	"Upgrade 5 characters 10 times": {
		"type": "multi_character_upgrades",
		"value": {"characters": 5, "upgrades": 10},
		"description": "Upgrade 5 different characters 10 times each to achieve victory."
	}
}

func _ready():
	populate_conditions()
	condition_option_button.connect("item_selected", Callable(self, "_on_condition_selected"))
	confirm_button.connect("pressed", Callable(self, "_on_confirm_pressed"))
	_on_condition_selected(0)  # Set initial description

func populate_conditions():
	for condition in victory_conditions.keys():
		condition_option_button.add_item(condition)

func _on_condition_selected(index: int):
	var selected_condition = condition_option_button.get_item_text(index)
	description_label.text = victory_conditions[selected_condition]["description"]

func _on_confirm_pressed():
	var selected_condition = condition_option_button.get_item_text(condition_option_button.selected)
	emit_signal("victory_condition_selected", victory_conditions[selected_condition])

# Note: Connect this signal in the parent scene or script
# Example: victory_condition_selector.connect("victory_condition_selected", Callable(self, "_on_victory_condition_selected"))
