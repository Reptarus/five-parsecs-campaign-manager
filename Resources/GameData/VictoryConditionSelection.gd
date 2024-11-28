# VictoryConditionSelection.gd
class_name VictoryConditionSelection
extends Control

# Define signals
signal victory_selected(condition: int, custom_data: Dictionary)
signal closed

# Properly type all node references
@onready var category_list: ItemList = $CenterContainer/PanelContainer/VBoxContainer/CategoryList
@onready var condition_list: ItemList = $CenterContainer/PanelContainer/VBoxContainer/ConditionList
@onready var description_label: Label = $CenterContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var custom_container: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/CustomContainer
@onready var custom_type_option: OptionButton = $CenterContainer/PanelContainer/VBoxContainer/CustomContainer/CustomTypeOption
@onready var custom_value_spin: SpinBox = $CenterContainer/PanelContainer/VBoxContainer/CustomContainer/CustomValueSpin
@onready var select_button: Button = $CenterContainer/PanelContainer/VBoxContainer/SelectButton
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/HeaderContainer/CloseButton

# Move victory conditions to a const to prevent modification
const VICTORY_CATEGORIES := {
	"Wealth": {
		"WEALTH_5000": {
			"type": GlobalEnums.CampaignVictoryType.WEALTH_5000,
			"name": "Wealthy Crew",
			"description": "Accumulate 5000 credits through jobs, trade, and salvage"
		}
	},
	"Reputation": {
		"REPUTATION_NOTORIOUS": {
			"type": GlobalEnums.CampaignVictoryType.REPUTATION_NOTORIOUS,
			"name": "Notorious Reputation",
			"description": "Become a notorious crew through successful missions and story events"
		}
	},
	"Story": {
		"STORY_COMPLETE": {
			"type": GlobalEnums.CampaignVictoryType.STORY_COMPLETE,
			"name": "Story Campaign",
			"description": "Complete the 7-stage narrative campaign"
		}
	},
	"Combat": {
		"BLACK_ZONE_MASTER": {
			"type": GlobalEnums.CampaignVictoryType.BLACK_ZONE_MASTER,
			"name": "Black Zone Master",
			"description": "Successfully complete 3 super-hard Black Zone jobs"
		},
		"RED_ZONE_VETERAN": {
			"type": GlobalEnums.CampaignVictoryType.RED_ZONE_VETERAN,
			"name": "Red Zone Veteran",
			"description": "Successfully complete 5 high-risk Red Zone jobs"
		}
	},
	"Quests": {
		"QUEST_MASTER": {
			"type": GlobalEnums.CampaignVictoryType.QUEST_MASTER,
			"name": "Quest Master",
			"description": "Complete 10 quests"
		}
	},
	"Faction": {
		"FACTION_DOMINANCE": {
			"type": GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE,
			"name": "Faction Dominance",
			"description": "Become dominant in a faction"
		}
	},
	"Fleet": {
		"FLEET_COMMANDER": {
			"type": GlobalEnums.CampaignVictoryType.FLEET_COMMANDER,
			"name": "Fleet Commander",
			"description": "Build up a significant fleet"
		}
	},
	"Custom": {
		"CUSTOM": {
			"type": GlobalEnums.CampaignVictoryType.CUSTOM,
			"name": "Custom Victory Condition",
			"description": "Set your own victory condition"
		}
	}
}

const CUSTOM_CONDITION_TYPES := {
	"Campaign Turns": {"min": 10, "max": 200, "default": 50},
	"Quest Completions": {"min": 1, "max": 20, "default": 5},
	"Battle Victories": {"min": 5, "max": 150, "default": 25},
	"Credits Earned": {"min": 1000, "max": 50000, "default": 5000},
	"Character Level": {"min": 1, "max": 20, "default": 10},
	"Reputation Level": {"min": 1, "max": 10, "default": 5},
	"Fleet Size": {"min": 2, "max": 20, "default": 5},
	"Black Zone Jobs": {"min": 1, "max": 10, "default": 3},
	"Red Zone Jobs": {"min": 1, "max": 15, "default": 5},
	"Story Missions": {"min": 1, "max": 7, "default": 7},
	"Rival Defeats": {"min": 1, "max": 20, "default": 5},
	"Faction Standing": {"min": 1, "max": 10, "default": 5}
}

var current_category: String
var current_condition: Dictionary

func _ready() -> void:
	# First verify all nodes are present
	if not _verify_nodes():
		push_error("VictoryConditionSelection: Required nodes are missing!")
		return
	
	# Initialize UI state
	custom_container.hide()
	visible = false
	select_button.disabled = true
	
	# Setup initial state
	_setup_custom_options()
	_populate_categories()
	
	# Connect UI signals
	category_list.item_selected.connect(_on_category_selected)
	condition_list.item_selected.connect(_on_condition_selected)
	custom_type_option.item_selected.connect(_on_custom_type_selected)
	select_button.pressed.connect(_on_select_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func _verify_nodes() -> bool:
	return category_list != null and \
		   condition_list != null and \
		   description_label != null and \
		   custom_container != null and \
		   custom_type_option != null and \
		   custom_value_spin != null and \
		   select_button != null and \
		   close_button != null

func _populate_categories() -> void:
	category_list.clear()
	for category in VICTORY_CATEGORIES.keys():
		category_list.add_item(category)

func _setup_custom_options() -> void:
	custom_type_option.clear()
	for type in CUSTOM_CONDITION_TYPES.keys():
		custom_type_option.add_item(type)
	_update_custom_value_range()

func _on_category_selected(index: int) -> void:
	if index < 0 or index >= category_list.item_count:
		return
		
	current_category = category_list.get_item_text(index)
	_populate_conditions(current_category)
	
	if current_category == "Custom":
		custom_container.show()
		custom_type_option.grab_focus()
	else:
		custom_container.hide()
		if condition_list.item_count > 0:
			condition_list.grab_focus()

func _populate_conditions(category: String) -> void:
	condition_list.clear()
	for condition in VICTORY_CATEGORIES[category].values():
		condition_list.add_item(condition.name)

func _on_condition_selected(index: int) -> void:
	if index < 0 or index >= condition_list.item_count:
		return
		
	var condition_name = condition_list.get_item_text(index)
	for condition in VICTORY_CATEGORIES[current_category].values():
		if condition.name == condition_name:
			current_condition = condition
			description_label.text = condition.description
			select_button.disabled = false
			break

func _on_custom_type_selected(index: int) -> void:
	_update_custom_value_range()

func _update_custom_value_range() -> void:
	var type = custom_type_option.get_item_text(custom_type_option.selected)
	var range_data = CUSTOM_CONDITION_TYPES[type]
	custom_value_spin.min_value = range_data.min
	custom_value_spin.max_value = range_data.max
	custom_value_spin.value = range_data.default

func _on_select_pressed() -> void:
	if current_category.is_empty():
		return
		
	if current_category == "Custom":
		if custom_type_option.selected < 0:
			return
			
		var custom_data = {
			"type": custom_type_option.get_item_text(custom_type_option.selected),
			"value": custom_value_spin.value
		}
		victory_selected.emit(GlobalEnums.CampaignVictoryType.CUSTOM, custom_data)
	else:
		if current_condition.is_empty():
			return
			
		victory_selected.emit(current_condition.type, {})
	
	hide()

func _on_close_button_pressed() -> void:
	hide()
	closed.emit()

func get_condition_description(condition_type: GlobalEnums.CampaignVictoryType) -> String:
	for category in VICTORY_CATEGORIES.values():
		for condition in category.values():
			if condition.type == condition_type:
				return condition.description
	return "Unknown condition"

func show_dialog() -> void:
	# Reset UI state
	category_list.deselect_all()
	condition_list.clear()
	description_label.text = "Select a victory condition"
	custom_container.hide()
	select_button.disabled = true
	current_category = ""
	current_condition = {}
	
	# Ensure categories are populated
	if category_list.item_count == 0:
		_populate_categories()
	
	# Show the dialog
	show()
