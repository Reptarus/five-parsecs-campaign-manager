class_name SaveLoadUI
extends CampaignResponsiveLayout

signal save_selected(save_name: String)
signal save_completed
signal load_completed
signal import_completed

@onready var save_name_input := $Panel/VBoxContainer/SaveNameInput as LineEdit
@onready var save_list := $Panel/VBoxContainer/SaveList as ItemList
@onready var status_label := $Panel/VBoxContainer/StatusLabel as Label
@onready var button_container := $Panel/VBoxContainer as VBoxContainer

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_LIST_HEIGHT_RATIO := 0.6  # List takes 60% in portrait mode

var save_manager: SaveManager

func _ready() -> void:
	super._ready()
	save_manager = SaveManager.new()
	_setup_save_load_ui()
	_connect_signals()
	_refresh_save_list()

func _setup_save_load_ui() -> void:
	_setup_buttons()
	save_list.add_to_group("touch_lists")

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()
	
	# Stack elements vertically with adjusted spacing
	button_container.add_theme_constant_override("separation", 20)
	
	# Adjust save list size for portrait mode
	var viewport_height = get_viewport_rect().size.y
	save_list.custom_minimum_size.y = viewport_height * PORTRAIT_LIST_HEIGHT_RATIO
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)
	
	# Adjust margins for mobile
	$Panel.add_theme_constant_override("margin_left", 10)
	$Panel.add_theme_constant_override("margin_right", 10)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()
	
	# Reset to default layout
	button_container.add_theme_constant_override("separation", 10)
	
	# Reset save list size
	save_list.custom_minimum_size = Vector2(0, 300)
	
	# Reset control sizes
	_adjust_touch_sizes(false)
	
	# Reset margins
	$Panel.add_theme_constant_override("margin_left", 20)
	$Panel.add_theme_constant_override("margin_right", 20)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	# Adjust all buttons
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height
	
	# Adjust input field
	save_name_input.custom_minimum_size.y = button_height
	
	# Adjust list item height
	save_list.fixed_item_height = button_height

func _setup_buttons() -> void:
	for button in button_container.get_children():
		if button is Button:
			button.add_to_group("touch_buttons")
			button.custom_minimum_size.x = 200

func _connect_signals() -> void:
	save_list.item_selected.connect(_on_save_selected)
	
	var save_button = $Panel/VBoxContainer/SaveButton
	var load_button = $Panel/VBoxContainer/LoadButton
	var delete_button = $Panel/VBoxContainer/DeleteButton
	var export_button = $Panel/VBoxContainer/ExportButton
	var import_button = $Panel/VBoxContainer/ImportButton
	
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	export_button.pressed.connect(_on_export_pressed)
	import_button.pressed.connect(_on_import_pressed)

func _refresh_save_list() -> void:
	save_list.clear()
	var saves = save_manager.get_save_list()
	for save in saves:
		save_list.add_item(save)

func _on_save_selected(index: int) -> void:
	var save_name = save_list.get_item_text(index)
	save_selected.emit(save_name)
	save_name_input.text = save_name

func _on_save_pressed() -> void:
	var save_name = save_name_input.text
	if save_name.is_empty():
		_show_status("Please enter a save name")
		return
	
	var game_state = get_node("/root/GameStateManager")
	if save_manager.save_game(save_name, game_state):
		_show_status("Game saved successfully")
		_refresh_save_list()
		save_completed.emit()
	else:
		_show_status("Failed to save game")

func _on_load_pressed() -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		_show_status("Please select a save file")
		return
	
	var save_name = save_list.get_item_text(selected[0])
	if save_manager.load_game(save_name):
		_show_status("Game loaded successfully")
		load_completed.emit()
	else:
		_show_status("Failed to load game")

func _on_delete_pressed() -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		_show_status("Please select a save file")
		return
	
	var save_name = save_list.get_item_text(selected[0])
	if save_manager.delete_save(save_name):
		_show_status("Save deleted")
		_refresh_save_list()
	else:
		_show_status("Failed to delete save")

func _on_export_pressed() -> void:
	var selected = save_list.get_selected_items()
	if selected.is_empty():
		_show_status("Please select a save file")
		return
	
	var save_name = save_list.get_item_text(selected[0])
	var game_state = get_node("/root/GameStateManager")
	if save_manager.export_save(save_name, game_state):
		_show_status("Save exported successfully")
	else:
		_show_status("Failed to export save")

func _on_import_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.json", "Save Files")
	file_dialog.file_selected.connect(_on_import_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered()

func _on_import_file_selected(path: String) -> void:
	var game_state = get_node("/root/GameStateManager")
	if save_manager.import_save(path, game_state):
		_show_status("Save imported successfully")
		_refresh_save_list()
		import_completed.emit()
	else:
		_show_status("Failed to import save")

func _show_status(message: String) -> void:
	status_label.text = "Status: " + message
