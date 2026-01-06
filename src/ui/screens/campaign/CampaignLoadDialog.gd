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
	var has_selection = not selected_campaign.is_empty()
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
	if not selected_campaign.is_empty():
		campaign_selected.emit(selected_campaign)

func _on_delete_pressed() -> void:
	if not selected_campaign.is_empty():
		# Sprint D: Show confirmation dialog before deleting
		var campaign_name = selected_campaign.get("name", "Unknown Campaign")
		var confirmed = await _show_confirmation_dialog(
			"Delete Campaign",
			"Are you sure you want to delete '%s'?\n\nAll progress will be permanently lost. This action cannot be undone." % campaign_name,
			"Delete",
			true  # destructive
		)

		if not confirmed:
			print("CampaignLoadDialog: Campaign deletion cancelled for: %s" % campaign_name)
			return

		campaign_deleted.emit(selected_campaign.name)
		selected_campaign = {}
		_update_ui_state()

## Sprint D: Show confirmation dialog and await response
func _show_confirmation_dialog(dialog_title: String, message: String, confirm_text: String = "Confirm", destructive: bool = false) -> bool:
	"""Show confirmation dialog and return true if confirmed"""
	var ConfirmationDialogScene = load("res://src/ui/components/common/ConfirmationDialog.tscn")
	if not ConfirmationDialogScene:
		push_warning("CampaignLoadDialog: ConfirmationDialog scene not found - proceeding without confirmation")
		return true

	var dialog = ConfirmationDialogScene.instantiate()
	add_child(dialog)

	var result = await dialog.await_confirmation(dialog_title, message, confirm_text, destructive)
	dialog.queue_free()

	return result

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
