class_name FPCM_CampaignSetupScreen
extends Control

# GlobalEnums available as autoload singleton

@onready var campaign_name_input: LineEdit = $"VBoxContainer/CampaignNameInput"
@onready var difficulty_option: OptionButton = $"VBoxContainer/DifficultyOption"
@onready var permadeath_toggle: CheckBox = $"VBoxContainer/PermadeathToggle"
@onready var story_track_toggle: CheckBox = $"VBoxContainer/StoryTrackToggle"
@onready var start_button: Button = $VBoxContainer/StartButton

signal campaign_started(config: Dictionary)

var campaign_config = {
	"name": "",
	"difficulty_level": GlobalEnums.DifficultyLevel.STANDARD,
	"enable_permadeath": false,
	"use_story_track": true
}

func _ready() -> void:
	_setup_difficulty_options()
	_connect_signals()
	_update_ui_state()

func _setup_difficulty_options() -> void:
	if not difficulty_option:
		push_error("CampaignSetupScreen: difficulty_option not found")
		return

	difficulty_option.clear()
	difficulty_option.add_item("Story", GlobalEnums.DifficultyLevel.STORY)
	difficulty_option.add_item("Standard", GlobalEnums.DifficultyLevel.STANDARD)
	difficulty_option.add_item("Challenging", GlobalEnums.DifficultyLevel.CHALLENGING)
	difficulty_option.add_item("Hardcore", GlobalEnums.DifficultyLevel.HARDCORE)
	difficulty_option.add_item("Nightmare", GlobalEnums.DifficultyLevel.NIGHTMARE)
	difficulty_option.select(GlobalEnums.DifficultyLevel.STANDARD)

func _connect_signals() -> void:
	if campaign_name_input and campaign_name_input.has_signal("text_changed"):
		campaign_name_input.text_changed.connect(_on_campaign_name_changed)
	if difficulty_option and difficulty_option.has_signal("item_selected"):
		difficulty_option.item_selected.connect(_on_difficulty_changed)
	if permadeath_toggle and permadeath_toggle.has_signal("toggled"):
		permadeath_toggle.toggled.connect(_on_permadeath_toggled)
	if story_track_toggle and story_track_toggle.has_signal("toggled"):
		story_track_toggle.toggled.connect(_on_story_track_toggled)
	if start_button and start_button.has_signal("pressed"):
		start_button.pressed.connect(_on_start_pressed)

func _update_ui_state() -> void:
	if start_button:
		start_button.disabled = campaign_config.name.is_empty()

	if permadeath_toggle:
		if campaign_config.difficulty_level == GlobalEnums.DifficultyLevel.STORY:
			permadeath_toggle.disabled = true
			permadeath_toggle.button_pressed = false
		else:
			permadeath_toggle.disabled = false

		if campaign_config.difficulty_level in [GlobalEnums.DifficultyLevel.HARDCORE, GlobalEnums.DifficultyLevel.NIGHTMARE]:
			permadeath_toggle.disabled = true
			permadeath_toggle.button_pressed = true

func _get_difficulty_description(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			return "Casual play with reduced difficulty for learning."
		GlobalEnums.DifficultyLevel.STANDARD:
			return "Standard difficulty with balanced challenges."
		GlobalEnums.DifficultyLevel.STANDARD:
			return "Core rules as written - the classic experience."
		GlobalEnums.DifficultyLevel.CHALLENGING:
			return "Increased enemy strength and tougher encounters."
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Maximum difficulty with elite enemies. Permadeath enabled."
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return "Custom ultra-hard mode. The ultimate challenge with permadeath."
		_:
			return "Unknown difficulty level"

func _on_campaign_name_changed(new_text: String) -> void:
	campaign_config.name = new_text
	_update_ui_state()

func _on_difficulty_changed(index: int) -> void:
	campaign_config.difficulty_level = index
	if difficulty_option:
		difficulty_option.tooltip_text = _get_difficulty_description(index)
	_update_ui_state()

func _on_permadeath_toggled(enabled: bool) -> void:
	campaign_config.enable_permadeath = enabled

func _on_story_track_toggled(enabled: bool) -> void:
	campaign_config.use_story_track = enabled

func _on_start_pressed() -> void:
	if campaign_config.difficulty_level in [GlobalEnums.DifficultyLevel.HARDCORE, GlobalEnums.DifficultyLevel.NIGHTMARE] and not campaign_config.enable_permadeath:
		campaign_config.enable_permadeath = true

	campaign_started.emit(campaign_config)
	queue_free()
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null