# VictoryConditionSelection.gd
class_name VictoryConditionSelection
extends Control

signal condition_selected(condition: Dictionary)

@onready var condition_list: ItemList = $VBoxContainer/ConditionList
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var select_button: Button = $VBoxContainer/SelectButton

var victory_conditions: Dictionary = {
	"20 Turns": {"type": GlobalEnums.VictoryConditionType.TURNS, "value": 20, "description": "Complete 20 campaign turns to achieve victory."},
	"50 Turns": {"type": GlobalEnums.VictoryConditionType.TURNS, "value": 50, "description": "Complete 50 campaign turns to achieve victory."},
	"100 Turns": {"type": GlobalEnums.VictoryConditionType.TURNS, "value": 100, "description": "Complete 100 campaign turns to achieve victory."},
	"3 Quests": {"type": GlobalEnums.VictoryConditionType.QUESTS, "value": 3, "description": "Successfully complete 3 Quests to achieve victory."},
	"5 Quests": {"type": GlobalEnums.VictoryConditionType.QUESTS, "value": 5, "description": "Successfully complete 5 Quests to achieve victory."},
	"10 Quests": {"type": GlobalEnums.VictoryConditionType.QUESTS, "value": 10, "description": "Successfully complete 10 Quests to achieve victory."},
	"20 Battles": {"type": GlobalEnums.VictoryConditionType.BATTLES, "value": 20, "description": "Win 20 tabletop battles to achieve victory."},
	"50 Battles": {"type": GlobalEnums.VictoryConditionType.BATTLES, "value": 50, "description": "Win 50 tabletop battles to achieve victory."},
	"100 Battles": {"type": GlobalEnums.VictoryConditionType.BATTLES, "value": 100, "description": "Win 100 tabletop battles to achieve victory."},
	"10 Unique Kills": {"type": GlobalEnums.VictoryConditionType.UNIQUE_KILLS, "value": 10, "description": "Defeat 10 Unique Individuals in battle to achieve victory."},
	"25 Unique Kills": {"type": GlobalEnums.VictoryConditionType.UNIQUE_KILLS, "value": 25, "description": "Defeat 25 Unique Individuals in battle to achieve victory."},
	"1 Character 10 Upgrades": {"type": GlobalEnums.VictoryConditionType.CHARACTER_UPGRADES, "value": 10, "description": "Upgrade any single character 10 times to achieve victory."},
	"3 Characters 10 Upgrades": {"type": GlobalEnums.VictoryConditionType.MULTI_CHARACTER_UPGRADES, "value": {"characters": 3, "upgrades": 10}, "description": "Upgrade 3 different characters 10 times each to achieve victory."},
	"5 Characters 10 Upgrades": {"type": GlobalEnums.VictoryConditionType.MULTI_CHARACTER_UPGRADES, "value": {"characters": 5, "upgrades": 10}, "description": "Upgrade 5 different characters 10 times each to achieve victory."}
}

func _ready() -> void:
	print("VictoryConditionSelection _ready() called")
	for condition in victory_conditions.keys():
		condition_list.add_item(condition)
	
	if not condition_list.item_selected.is_connected(_on_condition_selected):
		condition_list.item_selected.connect(_on_condition_selected)
	if not select_button.pressed.is_connected(_on_select_pressed):
		select_button.pressed.connect(_on_select_pressed)

func _on_condition_selected(index: int) -> void:
	print("Condition selected: ", index)
	var condition_name: String = condition_list.get_item_text(index)
	description_label.text = victory_conditions[condition_name]["description"]

func _on_select_pressed() -> void:
	print("Select button pressed")
	var selected_index: int = condition_list.get_selected_items()[0]
	var condition_name: String = condition_list.get_item_text(selected_index)
	condition_selected.emit(victory_conditions[condition_name])
	queue_free()

func get_victory_conditions() -> Dictionary:
	return victory_conditions
