class_name SaveLoadUI
extends Control

signal save_completed
signal load_completed
signal import_completed
signal ui_closed

@onready var save_name_input: LineEdit = $Panel/VBoxContainer/SaveNameInput
@onready var save_list: ItemList = $Panel/VBoxContainer/SaveList
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var save_button: Button = $Panel/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/ButtonContainer/LoadButton
@onready var delete_button: Button = $Panel/VBoxContainer/ButtonContainer/DeleteButton
@onready var export_button: Button = $Panel/VBoxContainer/ButtonContainer/ExportButton
@onready var import_button: Button = $Panel/VBoxContainer/ButtonContainer/ImportButton
@onready var backup_list_button: Button = $Panel/VBoxContainer/ButtonContainer/BackupListButton
@onready var quick_save_button: Button = $Panel/VBoxContainer/ButtonContainer/QuickSaveButton
@onready var auto_save_toggle: CheckButton = $Panel/VBoxContainer/AutoSaveToggle

# Use Node as a placeholder until SaveManager is properly implemented
var save_manager: Node
var game_state: GameState
var current_save_name: String = ""
var _status_timer: SceneTreeTimer
var _current_dialog: ConfirmationDialog
var _recovery_dialog: Window

func _ready() -> void:
	save_manager = get_node("/root/SaveManager")
	game_state = get_node("/root/GameState")
	
	if not save_manager or not game_state:
		push_error("Required nodes not found")
		return
	
	_connect_signals()
	_refresh_save_list()
	_update_button_states()
	
	# Initialize auto-save toggle
	auto_save_toggle.button_pressed = game_state.auto_save_enabled

func _connect_signals() -> void:
	save_manager.save_completed.connect(_on_save_manager_save_completed)
	save_manager.load_completed.connect(_on_save_manager_load_completed)
	save_manager.backup_created.connect(_on_save_manager_backup_created)
	save_manager.validation_failed.connect(_on_save_manager_validation_failed)
	save_manager.recovery_attempted.connect(_on_save_manager_recovery_attempted)
	
	game_state.save_started.connect(_on_save_started)
	game_state.save_completed.connect(_on_save_completed)
	game_state.load_started.connect(_on_load_started)
	game_state.load_completed.connect(_on_load_completed)
	
	save_name_input.text_changed.connect(_on_save_name_changed)
	save_list.item_selected.connect(_on_save_selected)
	
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	export_button.pressed.connect(_on_export_pressed)
	import_button.pressed.connect(_on_import_pressed)
	backup_list_button.pressed.connect(_on_backup_list_pressed)
	quick_save_button.pressed.connect(_on_quick_save_pressed)
	auto_save_toggle.toggled.connect(_on_auto_save_toggled)

func _refresh_save_list() -> void:
	save_list.clear()
	var saves = save_manager.get_save_list()
	
	for save in saves:
		var display_text = _format_save_display(save)
		var icon = _get_save_icon(save)
		save_list.add_item(display_text, icon)
		save_list.set_item_tooltip(save_list.get_item_count() - 1, _format_save_tooltip(save))
		save_list.set_item_metadata(save_list.get_item_count() - 1, save)

func _format_save_display(save: Dictionary) -> String:
	var type_prefix = ""
	if save.name.begins_with("autosave_"):
		type_prefix = "[Auto] "
	elif save.name.begins_with("quicksave_"):
		type_prefix = "[Quick] "
		
	return "%s%s (Turn %d) - %s" % [
		type_prefix,
		save.name.replace("autosave_", "").replace("quicksave_", ""),
		save.campaign_turn,
		save.date
	]

func _format_save_tooltip(save: Dictionary) -> String:
	var tooltip = """
	Name:%s
	Date:%s
	Game Version:%s
	Save Version:%s
	Campaign Turn:%d
	Credits:%d
	Reputation:%d
	""" % [
		save.name,
		save.date,
		save.version,
		save.save_version,
		save.campaign_turn,
		save.get("credits", 0),
		save.get("reputation", 0)
	]
	
	# Add validation status
	if save.has("validation_status"):
		tooltip += "\nValidation: " + save.validation_status
	
	# Add recovery status if applicable
	if save.has("recovery_status"):
		tooltip += "\nRecovery: " + save.recovery_status
	
	return tooltip.strip_edges()

func _get_save_icon(save: Dictionary) -> Texture2D:
	var icon_path = "res://assets/icons/"
	if save.name.begins_with("autosave_"):
		icon_path += "autosave_icon.png"
	elif save.name.begins_with("quicksave_"):
		icon_path += "quicksave_icon.png"
	else:
		icon_path += "save_icon.png"
	
	var icon = load(icon_path)
	if not icon:
		push_warning("Failed to load icon: " + icon_path)
		return null
	return icon

func _update_button_states() -> void:
	var has_selection = not save_list.get_selected_items().is_empty()
	var has_campaign = game_state.has_active_campaign()
	
	load_button.disabled = not has_selection
	delete_button.disabled = not has_selection
	export_button.disabled = not has_selection
	
	save_button.disabled = not has_campaign or save_name_input.text.strip_edges().is_empty()
	quick_save_button.disabled = not has_campaign

func _show_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.modulate = Color.RED if is_error else Color.WHITE
	
	if _status_timer:
		_status_timer.timeout.disconnect(_on_status_timer_timeout)
		_status_timer = null
	
	_status_timer = get_tree().create_timer(5.0)
	_status_timer.timeout.connect(_on_status_timer_timeout)

func _on_status_timer_timeout() -> void:
	status_label.text = "Status: Ready"

func _cleanup_current_dialog() -> void:
	if _current_dialog:
		_current_dialog.queue_free()
		_current_dialog = null

func _on_save_manager_save_completed(success: bool, message: String) -> void:
	if success:
		_refresh_save_list()
		_show_status("Save completed: " + message)
	else:
		_show_status("Save failed: " + message, true)

func _on_save_manager_load_completed(success: bool, message: String) -> void:
	if success:
		_refresh_save_list()
		_show_status("Load completed: " + message)
	else:
		_show_status("Load failed: " + message, true)

func _on_load_confirmation_dialog_confirmed(save_name: String) -> void:
	save_manager.load_save(save_name)
	_cleanup_current_dialog()

func _on_delete_confirmation_dialog_confirmed(save_name: String) -> void:
	if save_manager.delete_save_file(save_name):
		_show_status("Save deleted")
		_refresh_save_list()
	else:
		_show_status("Failed to delete save", true)
	_cleanup_current_dialog()

func _on_save_pressed() -> void:
	if current_save_name.is_empty():
		_show_status("Please enter a save name", true)
		return
	
	var save_data = game_state.get_save_data()
	save_manager.save_game_data(save_data, current_save_name)

func _on_quick_save_pressed() -> void:
	game_state.quick_save()

func _on_auto_save_toggled(enabled: bool) -> void:
	game_state.set_auto_save_enabled(enabled)
	_show_status("Auto-save " + ("enabled" if enabled else "disabled"))

func _show_validation_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Validation Error"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

func _show_recovery_result(success: bool, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Recovery " + ("Success" if success else "Failed")
	dialog.dialog_text = message
	
	if not success:
		var manual_button = Button.new()
		manual_button.text = "Manual Recovery"
		dialog.add_child(manual_button)
		manual_button.pressed.connect(_on_manual_recovery_pressed.bind(dialog))
	
	add_child(dialog)
	dialog.popup_centered()

func _on_manual_recovery_pressed(dialog: ConfirmationDialog) -> void:
	_show_manual_recovery_dialog()
	dialog.queue_free()

func _show_manual_recovery_dialog() -> void:
	_recovery_dialog = Window.new()
	_recovery_dialog.title = "Manual Save Recovery"
	_recovery_dialog.size = Vector2(800, 600)
	
	var vbox = VBoxContainer.new()
	_recovery_dialog.add_child(vbox)
	
	# Add explanation label
	var explanation = Label.new()
	explanation.text = """
	Manual recovery allows you to:
	1. View the raw save data
	2. Edit specific fields
	3. Attempt to repair the save
	4. Import a backup
	
	Please be careful when editing save data.
	"""
	vbox.add_child(explanation)
	
	# Add save data viewer/editor
	var save_data_edit = TextEdit.new()
	save_data_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(save_data_edit)
	
	# Add buttons
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	var load_button = Button.new()
	load_button.text = "Load Save Data"
	button_container.add_child(load_button)
	
	var validate_button = Button.new()
	validate_button.text = "Validate"
	button_container.add_child(validate_button)
	
	var repair_button = Button.new()
	repair_button.text = "Auto-Repair"
	button_container.add_child(repair_button)
	
	var save_button = Button.new()
	save_button.text = "Save Changes"
	button_container.add_child(save_button)
	
	var close_button = Button.new()
	close_button.text = "Close"
	button_container.add_child(close_button)
	
	# Connect button signals
	load_button.pressed.connect(_on_recovery_load_pressed.bind(save_data_edit))
	validate_button.pressed.connect(_on_recovery_validate_pressed.bind(save_data_edit))
	repair_button.pressed.connect(_on_recovery_repair_pressed.bind(save_data_edit))
	save_button.pressed.connect(_on_recovery_save_pressed.bind(save_data_edit))
	close_button.pressed.connect(_on_recovery_close_pressed)
	
	add_child(_recovery_dialog)
	_recovery_dialog.popup_centered()

func _on_recovery_load_pressed(save_data_edit: TextEdit) -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		return
		
	var save_data = save_list.get_item_metadata(selected[0])
	var save_path = "user://saves/" + save_data.name + ".json"
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		save_data_edit.text = file.get_as_text()
		file.close()

func _on_recovery_validate_pressed(save_data_edit: TextEdit) -> void:
	var json = JSON.new()
	var parse_result = json.parse(save_data_edit.text)
	if parse_result != OK:
		_show_status("Invalid JSON format", true)
		return
		
	var data = json.get_data()
	if save_manager._validate_save_data(data):
		_show_status("Save data is valid")
	else:
		_show_status("Save data validation failed", true)

func _on_recovery_repair_pressed(save_data_edit: TextEdit) -> void:
	var json = JSON.new()
	var parse_result = json.parse(save_data_edit.text)
	if parse_result != OK:
		_show_status("Invalid JSON format", true)
		return
		
	var data = json.get_data()
	var repaired_data = save_manager._repair_save_data(data)
	save_data_edit.text = JSON.stringify(repaired_data, "\t")
	_show_status("Auto-repair complete")

func _on_recovery_save_pressed(save_data_edit: TextEdit) -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		return
		
	var save_data = save_list.get_item_metadata(selected[0])
	var save_path = "user://saves/" + save_data.name + ".json"
	
	# Create backup before saving changes
	save_manager._create_backup(save_data.name)
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(save_data_edit.text)
		file.close()
		_show_status("Changes saved successfully")
		_refresh_save_list()
	else:
		_show_status("Failed to save changes", true)

func _on_recovery_close_pressed() -> void:
	if _recovery_dialog:
		_recovery_dialog.queue_free()
		_recovery_dialog = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		ui_closed.emit()
		queue_free()

func _on_save_started() -> void:
	_show_status("Saving game...")
	_update_button_states()

func _on_save_completed(success: bool, message: String) -> void:
	_show_status(message, not success)
	if success:
		_refresh_save_list()
	_update_button_states()
	save_completed.emit()

func _on_load_started() -> void:
	_show_status("Loading game...")
	_update_button_states()

func _on_load_completed(success: bool, message: String) -> void:
	_show_status(message, not success)
	_update_button_states()
	if success:
		load_completed.emit()

func _on_save_manager_backup_created(success: bool, message: String) -> void:
	if not success:
		_show_status("Backup: " + message, true)

func _on_save_manager_validation_failed(message: String) -> void:
	_show_validation_error(message)

func _on_save_manager_recovery_attempted(success: bool, message: String) -> void:
	_show_recovery_result(success, message)
	if success:
		_refresh_save_list()

func _on_save_name_changed(new_text: String) -> void:
	current_save_name = new_text.strip_edges()
	_update_button_states()

func _on_save_selected(index: int) -> void:
	var save_data = save_list.get_item_metadata(index)
	if save_data:
		current_save_name = save_data.name
		save_name_input.text = current_save_name
	_update_button_states()

func _on_export_pressed() -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		_show_status("Please select a save file", true)
		return
	
	var save_data = save_list.get_item_metadata(selected[0])
	save_manager.export_save(save_data.name)

func _on_import_pressed() -> void:
	save_manager.import_save()

func _on_backup_list_pressed() -> void:
	save_manager.show_backup_list()

func _on_load_pressed() -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		_show_status("Please select a save file", true)
		return
	
	var save_data = save_list.get_item_metadata(selected[0])
	if not save_data:
		_show_status("Invalid save data", true)
		return
	
	# Show confirmation if there's an active campaign
	if game_state.has_active_campaign():
		_current_dialog = ConfirmationDialog.new()
		_current_dialog.dialog_text = "Loading a save will end your current campaign. Continue?"
		_current_dialog.confirmed.connect(_on_load_confirmation_dialog_confirmed.bind(save_data.name))
		add_child(_current_dialog)
		_current_dialog.popup_centered()
	else:
		save_manager.load_save(save_data.name)

func _on_delete_pressed() -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		_show_status("Please select a save file", true)
		return
	
	var save_data = save_list.get_item_metadata(selected[0])
	if not save_data:
		_show_status("Invalid save data", true)
		return
	
	_current_dialog = ConfirmationDialog.new()
	_current_dialog.dialog_text = "Are you sure you want to delete this save?\nA backup will be created before deletion."
	_current_dialog.confirmed.connect(_on_delete_confirmation_dialog_confirmed.bind(save_data.name))
	add_child(_current_dialog)
	_current_dialog.popup_centered()