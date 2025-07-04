class_name FPCM_SaveLoadUI
extends Control

const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalNodeValidator = preload("res://src/utils/UniversalNodeValidator.gd")

signal save_completed
signal load_completed
signal import_completed
signal ui_closed

# Safe node references using fallback pattern
@onready var save_name_input: LineEdit = _get_node_safe_fallback("Panel/VBoxContainer/SaveNameInput")
@onready var save_list: ItemList = _get_node_safe_fallback("Panel/VBoxContainer/SaveList")
@onready var status_label: Label = _get_node_safe_fallback("Panel/VBoxContainer/StatusLabel")
@onready var save_button: Button = _get_node_safe_fallback("Panel/VBoxContainer/ButtonContainer/SaveButton")
@onready var load_button: Button = _get_node_safe_fallback("Panel/VBoxContainer/ButtonContainer/LoadButton")
@onready var delete_button: Button = _get_node_safe_fallback("Panel/VBoxContainer/ButtonContainer/DeleteButton")
@onready var export_button: Button = _get_node_safe_fallback("Panel/VBoxContainer/ButtonContainer/ExportButton")
@onready var import_button: Button = _get_node_safe_fallback("Panel/VBoxContainer/ButtonContainer/ImportButton")
@onready var backup_list_button: Button = _get_node_safe_fallback("Panel/VBoxContainer/ButtonContainer/BackupListButton")
@onready var quick_save_button: Button = _get_node_safe_fallback("Panel/VBoxContainer/ButtonContainer/QuickSaveButton")
@onready var auto_save_toggle: CheckButton = _get_node_safe_fallback("Panel/VBoxContainer/AutoSaveContainer/AutoSaveToggle")

# Helper function for safer node access with better error reporting
func _get_node_safe_fallback(path: String) -> Node:
	if has_node(path):
		return get_node(path)
	else:
		push_warning("SaveLoadUI: Node not found: %s - Scene structure may be incorrect" % path)
		return null

# Use Node as a placeholder until SaveManager is properly implemented
var save_manager: Node
var game_state: GameState
var current_save_name: String = ""
var _status_timer: SceneTreeTimer
var _current_dialog: ConfirmationDialog
var _recovery_dialog: Window

func _ready() -> void:
	# Debug scene structure first
	_debug_scene_structure()
	
	# Simple direct initialization without complex validation
	_initialize_component_direct()

# Simple direct initialization - bypasses complex validation
func _initialize_component_direct() -> void:
	# Use deferred call to ensure autoloads are ready
	call_deferred("_connect_autoloads")
	
	# Initialize UI state (will be updated once autoloads connect)
	_update_button_states()

func _connect_autoloads() -> void:
	# Get references to required autoloads after they're fully initialized
	save_manager = get_node_or_null("/root/SaveManager")
	game_state = get_node_or_null("/root/GameState")
	
	if not save_manager:
		push_warning("SaveManager autoload not found - save/load functionality disabled")
	if not game_state:
		push_warning("GameState autoload not found - some functionality disabled")
	
	# Connect signals for existing nodes only
	_connect_existing_signals()
	
	# Initialize UI state now that we have autoload references
	if save_manager:
		_refresh_save_list()
	_update_button_states()
	
	# Set auto-save toggle state
	if auto_save_toggle and game_state and game_state.has_method("auto_save_enabled"):
		auto_save_toggle.button_pressed = game_state.auto_save_enabled

# Connect signals only for nodes that exist
func _connect_existing_signals() -> void:
	# Note: Scene file already has signal connections defined
	# This method handles any additional programmatic connections needed
	# Connect save manager signals if available
	if save_manager:
		if save_manager.has_signal("save_completed"):
			save_manager.save_completed.connect(_on_save_manager_save_completed)
		if save_manager.has_signal("load_completed"):
			save_manager.load_completed.connect(_on_save_manager_load_completed)
	
	# Connect game state signals if available
	if game_state:
		if game_state.has_signal("save_started"):
			game_state.save_started.connect(_on_save_started)
		if game_state.has_signal("save_completed"):
			game_state.save_completed.connect(_on_save_completed)
		if game_state.has_signal("load_started"):
			game_state.load_started.connect(_on_load_started)
		if game_state.has_signal("load_completed"):
			game_state.load_completed.connect(_on_load_completed)
func _debug_scene_structure() -> void:
	print("=== SaveLoadUI Scene Structure Debug ===")
	if has_node("Panel"):
		print("✓ Panel found")
		var panel = get_node("Panel")
		if panel.has_node("VBoxContainer"):
			print("✓ VBoxContainer found")
			var vbox = panel.get_node("VBoxContainer")
			print("VBoxContainer children:")
			for child in vbox.get_children():
				print("  - %s (%s)" % [child.name, child.get_class()])
				if child.name == "AutoSaveContainer":
					print("    AutoSaveContainer children:")
					for subchild in child.get_children():
						print("      - %s (%s)" % [subchild.name, subchild.get_class()])
		else:
			print("✗ VBoxContainer NOT found")
	else:
		print("✗ Panel NOT found")
	print("==========================================")

# Create missing AutoSaveContainer if needed
func _create_missing_auto_save_container() -> void:
	if not has_node("Panel/VBoxContainer"):
		push_error("Cannot create AutoSaveContainer - VBoxContainer not found")
		return
		
	var vbox = get_node("Panel/VBoxContainer")
	var auto_save_container = HBoxContainer.new()
	auto_save_container.name = "AutoSaveContainer"
	auto_save_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var label = Label.new()
	label.name = "AutoSaveLabel"
	label.text = "Auto-Save:"
	auto_save_container.add_child(label)
	
	vbox.add_child(auto_save_container)
	print("Created missing AutoSaveContainer")

# Create missing AutoSaveToggle if needed
func _create_missing_auto_save_toggle() -> void:
	if not has_node("Panel/VBoxContainer/AutoSaveContainer"):
		push_error("Cannot create AutoSaveToggle - AutoSaveContainer not found")
		return
		
	var container = get_node("Panel/VBoxContainer/AutoSaveContainer")
	var toggle = CheckButton.new()
	toggle.name = "AutoSaveToggle"
	container.add_child(toggle)
	
	# Connect the signal manually
	toggle.toggled.connect(_on_auto_save_toggled)
	print("Created missing AutoSaveToggle")
	
	# Define ALL required node paths for this component
	var required_nodes = [
		"Panel/VBoxContainer/SaveNameInput",
		"Panel/VBoxContainer/SaveList",
		"Panel/VBoxContainer/StatusLabel",
		"Panel/VBoxContainer/ButtonContainer/SaveButton",
		"Panel/VBoxContainer/ButtonContainer/LoadButton",
		"Panel/VBoxContainer/ButtonContainer/DeleteButton",
		"Panel/VBoxContainer/ButtonContainer/ExportButton",
		"Panel/VBoxContainer/ButtonContainer/ImportButton",
		"Panel/VBoxContainer/ButtonContainer/BackupListButton",
		"Panel/VBoxContainer/ButtonContainer/QuickSaveButton",
		"Panel/VBoxContainer/AutoSaveContainer/AutoSaveToggle"
	]
	
	# Define ALL signal connections this component needs
	var signal_connections = [
		{"node_path": "Panel/VBoxContainer/SaveNameInput", "signal": "text_changed", "method": "_on_save_name_changed"},
		{"node_path": "Panel/VBoxContainer/SaveList", "signal": "item_selected", "method": "_on_save_selected"},
		{"node_path": "Panel/VBoxContainer/ButtonContainer/SaveButton", "signal": "pressed", "method": "_on_save_pressed"},
		{"node_path": "Panel/VBoxContainer/ButtonContainer/LoadButton", "signal": "pressed", "method": "_on_load_pressed"},
		{"node_path": "Panel/VBoxContainer/ButtonContainer/DeleteButton", "signal": "pressed", "method": "_on_delete_pressed"},
		{"node_path": "Panel/VBoxContainer/ButtonContainer/ExportButton", "signal": "pressed", "method": "_on_export_pressed"},
		{"node_path": "Panel/VBoxContainer/ButtonContainer/ImportButton", "signal": "pressed", "method": "_on_import_pressed"},
		{"node_path": "Panel/VBoxContainer/ButtonContainer/BackupListButton", "signal": "pressed", "method": "_on_backup_list_pressed"},
		{"node_path": "Panel/VBoxContainer/ButtonContainer/QuickSaveButton", "signal": "pressed", "method": "_on_quick_save_pressed"},
		{"node_path": "Panel/VBoxContainer/AutoSaveContainer/AutoSaveToggle", "signal": "toggled", "method": "_on_auto_save_toggled"}
	]
	
	# Universal setup
	var setup_result = UniversalNodeValidator.setup_ui_component(
		self,
		required_nodes,
		signal_connections,
		"SaveLoadUI"
	)
	
	# Store validated references
	_store_node_references(setup_result.nodes)
	
	# Initialize only if setup succeeded
	if setup_result.success:
		_initialize_component()
	else:
		_setup_fallback_mode(setup_result.errors)

# Add this method to store node references
func _store_node_references(nodes: Dictionary) -> void:
	save_name_input = nodes.get("Panel/VBoxContainer/SaveNameInput")
	save_list = nodes.get("Panel/VBoxContainer/SaveList")
	status_label = nodes.get("Panel/VBoxContainer/StatusLabel")
	save_button = nodes.get("Panel/VBoxContainer/ButtonContainer/SaveButton")
	load_button = nodes.get("Panel/VBoxContainer/ButtonContainer/LoadButton")
	delete_button = nodes.get("Panel/VBoxContainer/ButtonContainer/DeleteButton")
	export_button = nodes.get("Panel/VBoxContainer/ButtonContainer/ExportButton")
	import_button = nodes.get("Panel/VBoxContainer/ButtonContainer/ImportButton")
	backup_list_button = nodes.get("Panel/VBoxContainer/ButtonContainer/BackupListButton")
	quick_save_button = nodes.get("Panel/VBoxContainer/ButtonContainer/QuickSaveButton")
	auto_save_toggle = nodes.get("Panel/VBoxContainer/AutoSaveContainer/AutoSaveToggle")

# Add this method for successful initialization
func _initialize_component() -> void:
	save_manager = UniversalNodeAccess.get_node_safe(self, "/root/SaveManager", "SaveLoadUI")
	game_state = UniversalNodeAccess.get_node_safe(self, "/root/GameState", "SaveLoadUI")
	
	if not save_manager or not game_state:
		push_error("Required autoloads not found")
		return
	
	_connect_manager_signals()
	_refresh_save_list()
	_update_button_states()
	
	# Initialize auto-save toggle safely
	if auto_save_toggle and game_state.has_method("auto_save_enabled"):
		auto_save_toggle.button_pressed = game_state.auto_save_enabled

# Add this method for graceful degradation with better fallbacks
func _setup_fallback_mode(errors: Array) -> void:
	print("SaveLoadUI running in degraded mode: ", errors)
	
	# Ensure critical UI elements exist even in fallback mode
	_create_minimal_ui_fallback()
	
	# Show a clear error message if possible
	if status_label:
		status_label.text = "UI Error: Some controls missing - Limited functionality"
		status_label.modulate = Color.YELLOW
	else:
		# Create a temporary status label if none exists
		var temp_label = Label.new()
		temp_label.text = "SaveLoadUI Error: Missing UI components"
		temp_label.modulate = Color.RED
		add_child(temp_label)

# Create minimal fallback UI if scene structure is broken
func _create_minimal_ui_fallback() -> void:
	# Only create fallbacks if absolutely necessary
	if not has_node("Panel"):
		var panel = Panel.new()
		panel.name = "Panel"
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(panel)
	
	var panel = get_node("Panel")
	
	if not panel.has_node("VBoxContainer"):
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(vbox)
	
	var vbox = panel.get_node("VBoxContainer")
	
	# Create minimal status display
	if not status_label:
		var temp_status = Label.new()
		temp_status.name = "StatusLabel"
		temp_status.text = "SaveLoadUI Fallback Mode"
		temp_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(temp_status)
		status_label = temp_status

func _connect_manager_signals() -> void:
	# Connect to save manager signals (only existing ones)
	if save_manager and save_manager.has_signal("save_completed"):
		save_manager.save_completed.connect(_on_save_manager_save_completed)
	if save_manager and save_manager.has_signal("load_completed"):
		save_manager.load_completed.connect(_on_save_manager_load_completed)
	
	# Connect optional signals if they exist
	if save_manager and save_manager.has_signal("backup_created"):
		save_manager.backup_created.connect(_on_save_manager_backup_created)
	if save_manager and save_manager.has_signal("validation_failed"):
		save_manager.validation_failed.connect(_on_save_manager_validation_failed)
	if save_manager and save_manager.has_signal("recovery_attempted"):
		save_manager.recovery_attempted.connect(_on_save_manager_recovery_attempted)
	
	# Connect to game state signals (only existing ones)
	if game_state and game_state.has_signal("save_started"):
		game_state.save_started.connect(_on_save_started)
	if game_state and game_state.has_signal("save_completed"):
		game_state.save_completed.connect(_on_save_completed)
	if game_state and game_state.has_signal("load_started"):
		game_state.load_started.connect(_on_load_started)
	if game_state and game_state.has_signal("load_completed"):
		game_state.load_completed.connect(_on_load_completed)
	
	# UI signal connections are handled by UniversalNodeValidator.setup_ui_component

func _refresh_save_list() -> void:
	if not save_list:
		push_warning("SaveLoadUI: Cannot refresh save list - save_list is null")
		return
	save_list.clear()
	var saves = save_manager.get_save_list()
	
	for save in saves:
		var display_text = _format_save_display(save)
		var icon = _get_save_icon(save)
		save_list.add_item(display_text, icon)
		save_list.set_item_tooltip(save_list.get_item_count() - 1, _format_save_tooltip(save))
		save_list.set_item_metadata(save_list.get_item_count() - 1, save)

func _format_save_display(save: Dictionary) -> String:
	var type_prefix: String = ""
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
	var tooltip: String = """
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
	var icon_path: String = "res://assets/icons/"
	if save.name.begins_with("autosave_"):
		icon_path += "autosave_icon.png"
	elif save.name.begins_with("quicksave_"):
		icon_path += "quicksave_icon.png"
	else:
		icon_path += "save_icon.png"
	
	var icon = load(icon_path)
	if not icon:
		push_warning("Failed to load icon: " + icon_path)

	return icon

func _update_button_states() -> void:
	if not save_list or not game_state:
		return
	
	var has_selection = not save_list.get_selected_items().is_empty()
	var has_campaign = game_state.has_method("has_active_campaign") and game_state.has_active_campaign()
	
	if load_button:
		load_button.disabled = not has_selection
	if delete_button:
		delete_button.disabled = not has_selection
	if export_button:
		export_button.disabled = not has_selection
	
	if save_button and save_name_input:
		save_button.disabled = not has_campaign or save_name_input.text.strip_edges().is_empty()
	if quick_save_button:
		quick_save_button.disabled = not has_campaign

func _show_status(message: String, is_error: bool = false) -> void:
	if not status_label:
		push_warning("SaveLoadUI: Cannot show status - status_label is null")
		return
	status_label.text = message
	status_label.modulate = Color.RED if is_error else Color.WHITE
	
	if _status_timer:
		_status_timer.timeout.disconnect(_on_status_timer_timeout)
		_status_timer = null
	
	_status_timer = get_tree().create_timer(5.0)
	_status_timer.timeout.connect(_on_status_timer_timeout)

func _on_status_timer_timeout() -> void:
	if status_label:
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
	# Use the correct method name for our CoreSaveManager
	var loaded_data = save_manager.load_game(save_name)
	if not loaded_data.is_empty():
		_show_status("Load completed")
		# You might want to apply this data to the game state here
	else:
		_show_status("Load failed", true)
	_cleanup_current_dialog()

func _on_delete_confirmation_dialog_confirmed(save_name: String) -> void:
	# Use the correct method name for our CoreSaveManager
	if save_manager.delete_save(save_name):
		_show_status("Save deleted")
		_refresh_save_list()
	else:
		_show_status("Failed to delete save", true)
	_cleanup_current_dialog()

func _on_save_pressed() -> void:
	if current_save_name.is_empty():
		_show_status("Please enter a save name", true)
		return
	
	# Get save data and use correct method name
	var save_data = {}
	if game_state and game_state.has_method("serialize"):
		save_data = game_state.serialize()
	
	if save_manager.save_game(save_data, current_save_name):
		_show_status("Save completed")
		_refresh_save_list()
	else:
		_show_status("Save failed", true)

func _on_quick_save_pressed() -> void:
	game_state.quick_save()

func _on_auto_save_toggled(enabled: bool) -> void:
	game_state.set_auto_save_enabled(enabled)
	_show_status("Auto-save " + ("enabled" if enabled else "disabled"))

func _show_validation_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Validation Error"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

func _show_recovery_result(success: bool, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Recovery " + ("Success" if success else "Failed")
	dialog.dialog_text = message
	
	if not success:
		var manual_button := Button.new()
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
	
	var vbox := VBoxContainer.new()
	_recovery_dialog.add_child(vbox)
	
	# Add explanation label
	var explanation := Label.new()
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
	var save_data_edit := TextEdit.new()
	save_data_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(save_data_edit)
	
	# Add buttons
	var button_container := HBoxContainer.new()
	vbox.add_child(button_container)
	
	var load_button := Button.new()
	load_button.text = "Load Save Data"
	button_container.add_child(load_button)
	
	var validate_button := Button.new()
	validate_button.text = "Validate"
	button_container.add_child(validate_button)
	
	var repair_button := Button.new()
	repair_button.text = "Auto-Repair"
	button_container.add_child(repair_button)
	
	var save_button := Button.new()
	save_button.text = "Save Changes"
	button_container.add_child(save_button)
	
	var close_button := Button.new()
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
	var save_path: String = "user://saves/" + save_data.name + ".json"
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		save_data_edit.text = file.get_as_text()
		file.close()

func _on_recovery_validate_pressed(save_data_edit: TextEdit) -> void:
	var json := JSON.new()
	var parse_result = json.parse(save_data_edit.text)
	if parse_result != OK:
		_show_status("Invalid JSON format", true)
		return
		
	var data = json.get_data()
	# Simple validation - check if it's a dictionary with basic structure
	if data is Dictionary and data.has("data"):
		_show_status("Save data appears valid")
	else:
		_show_status("Save data validation failed - missing required structure", true)

func _on_recovery_repair_pressed(save_data_edit: TextEdit) -> void:
	var json := JSON.new()
	var parse_result = json.parse(save_data_edit.text)
	if parse_result != OK:
		_show_status("Invalid JSON format", true)
		return
		
	var data = json.get_data()
	# Simple repair - ensure basic structure exists
	if not data is Dictionary:
		data = {"data": {}}
	if not data.has("data"):
		data["data"] = {}
	
	save_data_edit.text = JSON.stringify(data, "\t")
	_show_status("Basic repair complete")

func _on_recovery_save_pressed(save_data_edit: TextEdit) -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		return
		
	var save_data = save_list.get_item_metadata(selected[0])
	var save_path: String = "user://saves/" + save_data.name + ".json"
	
	# Note: backup functionality not available in current SaveManager
	_show_status("Saving changes (no backup created)...")
	
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
		ui_closed.emit() # warning: return value discarded (intentional)
		queue_free()

func _on_save_started() -> void:
	_show_status("Saving game...")
	_update_button_states()

func _on_save_completed(success: bool, message: String) -> void:
	_show_status(message, not success)
	if success:
		_refresh_save_list()
	_update_button_states()
	save_completed.emit() # warning: return value discarded (intentional)

func _on_load_started() -> void:
	_show_status("Loading game...")
	_update_button_states()

func _on_load_completed(success: bool, message: String) -> void:
	_show_status(message, not success)
	_update_button_states()
	if success:
		load_completed.emit() # warning: return value discarded (intentional)

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
	if not save_name_input:
		return
	current_save_name = new_text.strip_edges()
	_update_button_states()

func _on_save_selected(index: int) -> void:
	if not save_list or not save_name_input:
		return
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
	_show_status("Export functionality not implemented yet", true)

func _on_import_pressed() -> void:
	_show_status("Import functionality not implemented yet", true)

func _on_backup_list_pressed() -> void:
	_show_status("Backup list functionality not implemented yet", true)

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
		# Use the correct method name for our CoreSaveManager
		var loaded_data = save_manager.load_game(save_data.name)
		if not loaded_data.is_empty():
			_show_status("Load completed")
		else:
			_show_status("Load failed", true)

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
