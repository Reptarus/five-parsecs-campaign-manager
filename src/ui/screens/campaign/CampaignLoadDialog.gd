extends Control

# GlobalEnums available as autoload singleton

@onready var campaign_list: Button = $"VBoxContainer/CampaignList"
@onready var load_button: Button = $"VBoxContainer/LoadButton"
@onready var delete_button: Button = $"VBoxContainer/DeleteButton"
@onready var summary_panel: Button = $"VBoxContainer/SummaryPanel"

signal campaign_selected(campaign_data: Dictionary)
signal campaign_deleted(campaign_name: String)

var selected_campaign: Dictionary

func _ready() -> void:
	_connect_signals()
	_update_ui_state()

func _connect_signals() -> void:
	campaign_list.item_selected.connect(_on_campaign_selected)
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)

func _update_ui_state() -> void:
	var has_selection = not (safe_call_method(selected_campaign, "is_empty") == true)
	load_button.disabled = not has_selection
	delete_button.disabled = not has_selection

func update_campaign_list(campaigns: Array) -> void:
	campaign_list.clear()
	for campaign in campaigns:
		var text: String = "%s (%s)" % [campaign.name, _get_difficulty_name(campaign.difficulty_level)]
		campaign_list.add_item(text)

func _get_difficulty_name(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			return "Story"
		GlobalEnums.DifficultyLevel.STANDARD:
			return "Standard"
		GlobalEnums.DifficultyLevel.CHALLENGING:
			return "Challenging"
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Hardcore"
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return "Nightmare"
		_:
			return "Unknown"

func _on_campaign_selected(index: int) -> void:
	selected_campaign = _get_campaign_data(index)
	summary_panel.update_summary(selected_campaign)
	_update_ui_state()

func _on_load_pressed() -> void:
	if not (safe_call_method(selected_campaign, "is_empty") == true):
		campaign_selected.emit(selected_campaign)

func _on_delete_pressed() -> void:
	if not (safe_call_method(selected_campaign, "is_empty") == true):
		campaign_deleted.emit(selected_campaign.name)
		selected_campaign = {}
		_update_ui_state()

func _get_campaign_data(index: int) -> Dictionary:
	# This would be replaced with actual campaign data retrieval
	return {
		"name": "Test Campaign",
		"difficulty_level": GlobalEnums.DifficultyLevel.STANDARD,
		"enable_permadeath": false,
		"use_story_track": true,
		"missions_completed": 5,
		"credits": 1000
	}
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null