# VictoryConditionSelection.gd
extends Control

signal condition_selected(condition)

@onready var condition_list = $VBoxContainer/ConditionList
@onready var description_label = $VBoxContainer/DescriptionLabel
@onready var select_button = $VBoxContainer/SelectButton

var victory_conditions = {
	"20 Turns": {"type": "turns", "value": 20, "description": "Complete 20 campaign turns to achieve victory."},
	"50 Turns": {"type": "turns", "value": 50, "description": "Complete 50 campaign turns to achieve victory."},
	"100 Turns": {"type": "turns", "value": 100, "description": "Complete 100 campaign turns to achieve victory."},
	"3 Quests": {"type": "quests", "value": 3, "description": "Successfully complete 3 Quests to achieve victory."},
	"5 Quests": {"type": "quests", "value": 5, "description": "Successfully complete 5 Quests to achieve victory."},
	"10 Quests": {"type": "quests", "value": 10, "description": "Successfully complete 10 Quests to achieve victory."},
	"20 Battles": {"type": "battles", "value": 20, "description": "Win 20 tabletop battles to achieve victory."},
	"50 Battles": {"type": "battles", "value": 50, "description": "Win 50 tabletop battles to achieve victory."},
	"100 Battles": {"type": "battles", "value": 100, "description": "Win 100 tabletop battles to achieve victory."},
	"10 Unique Kills": {"type": "unique_kills", "value": 10, "description": "Defeat 10 Unique Individuals in battle to achieve victory."},
	"25 Unique Kills": {"type": "unique_kills", "value": 25, "description": "Defeat 25 Unique Individuals in battle to achieve victory."},
	"1 Character 10 Upgrades": {"type": "character_upgrades", "value": 10, "description": "Upgrade any single character 10 times to achieve victory."},
	"3 Characters 10 Upgrades": {"type": "multi_character_upgrades", "value": {"characters": 3, "upgrades": 10}, "description": "Upgrade 3 different characters 10 times each to achieve victory."},
	"5 Characters 10 Upgrades": {"type": "multi_character_upgrades", "value": {"characters": 5, "upgrades": 10}, "description": "Upgrade 5 different characters 10 times each to achieve victory."}
}

func _ready():
	for condition in victory_conditions.keys():
		condition_list.add_item(condition)
	
	condition_list.connect("item_selected", Callable(self, "_on_condition_selected"))
	select_button.connect("pressed", Callable(self, "_on_select_pressed"))

func _on_condition_selected(index):
	var condition_name = condition_list.get_item_text(index)
	description_label.text = victory_conditions[condition_name]["description"]

func _on_select_pressed():
	var selected_index = condition_list.get_selected_items()[0]
	var condition_name = condition_list.get_item_text(selected_index)
	emit_signal("condition_selected", victory_conditions[condition_name])
	queue_free()
