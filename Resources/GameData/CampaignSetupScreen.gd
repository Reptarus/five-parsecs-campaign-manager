class_name CampaignSetupScreen
extends Control

# Constants and preloads at the top
const VictoryConditionScene := preload("res://Resources/CampaignManagement/Scenes/VictoryConditionSelection.tscn")
const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")
const VictoryConditionSelection := preload("res://Resources/CampaignManagement/Scenes/VictoryConditionSelection.tscn")

const MIN_CREW_SIZE := 3
const MAX_CREW_SIZE := 8
const DEFAULT_CREW_SIZE := 4

# Add touch-specific constants
const TOUCH_MIN_DRAG_DISTANCE := 10.0
const TOUCH_BUTTON_SIZE := Vector2(120, 60)

# Signal declarations next
signal campaign_setup_completed(config: Dictionary)

# Onready variables grouped together with type hints
@onready var victory_selection: Control = $VictoryConditionSelection
@onready var victory_type_label: Label = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/VictoryTypeLabel
@onready var victory_count_label: Label = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/VictoryCountLabel
@onready var set_victory_button: Button = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/SetVictoryConditionButton
@onready var crew_name_input: LineEdit = $HBoxContainer/LeftPanel/VBoxContainer/CrewNameInput
@onready var difficulty_option: OptionButton = $HBoxContainer/LeftPanel/VBoxContainer/DifficultyOptionButton
@onready var crew_size_slider: HSlider = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/HSlider
@onready var crew_size_label: Label = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/CrewSizeLabel
@onready var start_button: Button = $HBoxContainer/LeftPanel/VBoxContainer/StartCampaignButton

# Campaign configuration with type hints and default values
var campaign_config: Dictionary = {
	"crew_name": "",
	"difficulty": 0,
	"crew_size": DEFAULT_CREW_SIZE,
	"victory_condition": GlobalEnums.CampaignVictoryType.NONE,
	"custom_victory_data": {}
}

# Update victory descriptions to use GlobalEnums
const VICTORY_DESCRIPTIONS = {
	GlobalEnums.CampaignVictoryType.WEALTH_5000: "Accumulate 5000 credits through jobs, trade, and salvage.",
	GlobalEnums.CampaignVictoryType.REPUTATION_NOTORIOUS: "Become a notorious crew through successful missions and story events.",
	GlobalEnums.CampaignVictoryType.STORY_COMPLETE: "Complete the 7-stage narrative campaign.",
	GlobalEnums.CampaignVictoryType.BLACK_ZONE_MASTER: "Successfully complete 3 super-hard Black Zone jobs.",
	GlobalEnums.CampaignVictoryType.RED_ZONE_VETERAN: "Successfully complete 5 high-risk Red Zone jobs.",
	GlobalEnums.CampaignVictoryType.QUEST_MASTER: "Complete 10 quests",
	GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE: "Become dominant in a faction",
	GlobalEnums.CampaignVictoryType.FLEET_COMMANDER: "Build up a significant fleet"
}

func _ready() -> void:
	if not _verify_nodes():
		push_error("CampaignSetupScreen: Required nodes are missing!")
		return
		
	_setup_ui()
	_connect_signals()
	_update_ui_state()
	
	if OS.get_name() == "Android":
		# Increase button sizes for touch
		for button in get_tree().get_nodes_in_group("touch_buttons"):
			button.custom_minimum_size = TOUCH_BUTTON_SIZE
			button.size = TOUCH_BUTTON_SIZE

func _verify_nodes() -> bool:
	return victory_selection != null and \
		   victory_type_label != null and \
		   victory_count_label != null and \
		   set_victory_button != null and \
		   crew_name_input != null and \
		   difficulty_option != null and \
		   crew_size_slider != null and \
		   start_button != null

func _setup_ui() -> void:
	# Setup difficulty options
	for difficulty in GlobalEnums.DifficultyMode.values():
		difficulty_option.add_item(str(difficulty), difficulty)
	
	# Setup crew size slider
	crew_size_slider.min_value = MIN_CREW_SIZE
	crew_size_slider.max_value = MAX_CREW_SIZE
	crew_size_slider.value = DEFAULT_CREW_SIZE
	
	# Update initial labels
	_update_crew_size_label(DEFAULT_CREW_SIZE)
	
	# Initialize victory condition UI
	if victory_selection:
		victory_selection.hide()
		victory_type_label.text = "No victory condition selected"
		victory_count_label.text = ""

func _connect_signals() -> void:
	if not _verify_nodes():
		push_error("Required nodes not found!")
		return
	
	# Basic UI signals - only connect those not in TSCN
	if crew_name_input:
		crew_name_input.text_changed.connect(_on_crew_name_changed)
	if difficulty_option:
		difficulty_option.item_selected.connect(_on_difficulty_selected)
	if crew_size_slider:
		crew_size_slider.value_changed.connect(_on_crew_size_changed)
	if start_button:
		start_button.pressed.connect(_on_start_campaign)
	
	# Victory selection signals
	if victory_selection:
		var victory_selector := victory_selection as VictoryConditionSelection
		if victory_selector:
			victory_selector.victory_selected.connect(_on_victory_condition_selected)
			victory_selector.closed.connect(_on_victory_selection_closed)

func _on_crew_name_changed(new_name: String) -> void:
	campaign_config.crew_name = new_name
	_update_ui_state()

func _on_difficulty_selected(index: int) -> void:
	var difficulty = difficulty_option.get_item_id(index)
	campaign_config.difficulty = difficulty

func _on_crew_size_changed(value: float) -> void:
	campaign_config.crew_size = int(value)
	_update_crew_size_label(value)

func _update_crew_size_label(size: float) -> void:
	crew_size_label.text = "Current Crew Size: %d" % int(size)

func _on_set_victory_pressed() -> void:
	if victory_selection:
		victory_selection.show()

func _on_victory_condition_selected(condition: GlobalEnums.CampaignVictoryType, custom_data: Dictionary = {}) -> void:
	campaign_config.victory_condition = condition
	campaign_config.custom_victory_data = custom_data
	
	var description = "Unknown victory condition"
	if condition == GlobalEnums.CampaignVictoryType.CUSTOM:
		description = "Custom: %s - Target: %d" % [custom_data.type, custom_data.value]
	else:
		description = VICTORY_DESCRIPTIONS.get(condition, "Unknown victory condition")
	
	victory_type_label.text = str(condition)
	victory_count_label.text = description
	_update_ui_state()

func _on_start_campaign() -> void:
	campaign_setup_completed.emit(campaign_config)

func _on_victory_selection_closed() -> void:
	if victory_selection:
		victory_selection.hide()

func _update_ui_state() -> void:
	var has_crew_name = campaign_config.crew_name.length() > 0
	var has_victory_condition = campaign_config.victory_condition != GlobalEnums.CampaignVictoryType.NONE
	if start_button:
		start_button.disabled = !has_crew_name || !has_victory_condition
