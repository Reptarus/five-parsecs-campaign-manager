class_name CampaignSetupScreen
extends CampaignResponsiveLayout

# Add class references
const DifficultyOption = preload("res://Resources/UI/DifficultyOption.gd")
const VictoryOption = preload("res://Resources/UI/VictoryOption.gd")
const QuickStartDialog = preload("res://Resources/UI/QuickStartDialog.gd")

# Add missing constants
const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_CONTROLS_HEIGHT_RATIO := 0.3

# Add missing function
func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	for control in get_tree().get_nodes_in_group("touch_controls"):
		control.custom_minimum_size.y = button_height

# Add onready variables
@onready var difficulty_option := $PanelContainer/MarginContainer/VBoxContainer/DifficultyOption as OptionButton
@onready var victory_option := $PanelContainer/MarginContainer/VBoxContainer/VictoryOption as OptionButton
@onready var quick_start_button := $PanelContainer/MarginContainer/VBoxContainer/QuickStartButton as Button

# Add _ready function
func _ready() -> void:
	super._ready()
	_setup_campaign_options()
	_connect_signals()

# Add setup functions
func _setup_campaign_options() -> void:
	_setup_difficulty_options()
	_setup_victory_options()
	_setup_buttons()

func _setup_difficulty_options() -> void:
	if difficulty_option:
		difficulty_option.add_to_group("touch_controls")
		_populate_difficulty_options()

func _setup_victory_options() -> void:
	if victory_option:
		victory_option.add_to_group("touch_controls")
		_populate_victory_options()

func _setup_buttons() -> void:
	if quick_start_button:
		quick_start_button.add_to_group("touch_buttons")
		quick_start_button.custom_minimum_size = Vector2(200, TOUCH_BUTTON_HEIGHT)

# Add populate functions
func _populate_difficulty_options() -> void:
	if difficulty_option:
		difficulty_option.clear()
		for difficulty in GlobalEnums.Difficulty.values():
			difficulty_option.add_item(GlobalEnums.Difficulty.keys()[difficulty])

func _populate_victory_options() -> void:
	if victory_option:
		victory_option.clear()
		for victory in GlobalEnums.VictoryCondition.values():
			victory_option.add_item(GlobalEnums.VictoryCondition.keys()[victory])

# Add signal connection function
func _connect_signals() -> void:
	if quick_start_button:
		quick_start_button.pressed.connect(_on_quick_start_pressed)

# Add signal handler
func _on_quick_start_pressed() -> void:
	var selected_difficulty = GlobalEnums.Difficulty[difficulty_option.get_selected_id()]
	var selected_victory = GlobalEnums.VictoryCondition[victory_option.get_selected_id()]
	emit_signal("quick_start_selected", selected_difficulty, selected_victory)
