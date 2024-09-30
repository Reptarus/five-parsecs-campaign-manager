extends Control

@onready var save_name_input: LineEdit = $Panel/VBoxContainer/SaveNameInput
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/LoadButton
@onready var delete_button: Button = $Panel/VBoxContainer/DeleteButton
@onready var export_button: Button = $Panel/VBoxContainer/ExportButton
@onready var import_button: Button = $Panel/VBoxContainer/ImportButton
@onready var save_list: ItemList = $Panel/VBoxContainer/SaveList
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel

signal save_requested(save_name: String)
signal load_requested(save_name: String)

func _ready() -> void:
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	export_button.pressed.connect(_on_export_button_pressed)
	import_button.pressed.connect(_on_import_button_pressed)
	save_list.item_selected.connect(_on_save_selected)
	
	SaveGame.save_completed.connect(_on_save_completed)
	SaveGame.load_completed.connect(_on_load_completed)
	
	refresh_save_list()

func refresh_save_list() -> void:
	save_list.clear()
	var saves = SaveGame.get_save_list()
	for save in saves:
		save_list.add_item("%s (%s)" % [save["name"], save["date"]])

func _on_save_button_pressed() -> void:
	var save_name = save_name_input.text.strip_edges()
	if save_name.is_empty():
		status_label.text = "Please enter a save name."
		return
	emit_signal("save_requested", save_name)

func _on_load_button_pressed() -> void:
	var selected_items = save_list.get_selected_items()
	if selected_items.is_empty():
		status_label.text = "Please select a save to load."
		return
	var save_name = SaveGame.get_save_list()[selected_items[0]]["name"]
	emit_signal("load_requested", save_name)

func _on_delete_button_pressed() -> void:
	var selected_items = save_list.get_selected_items()
	if selected_items.is_empty():
		status_label.text = "Please select a save to delete."
		return
	var save_name = SaveGame.get_save_list()[selected_items[0]]["name"]
	var error = SaveGame.delete_save(save_name)
	if error == OK:
		status_label.text = "Save deleted successfully."
		refresh_save_list()
	else:
		status_label.text = "Failed to delete save."

func _on_export_button_pressed() -> void:
	var selected_items = save_list.get_selected_items()
	if selected_items.is_empty():
		status_label.text = "Please select a save to export."
		return
	var save_name = SaveGame.get_save_list()[selected_items[0]]["name"]
	var export_path = "user://exported_save_%s.json" % Time.get_unix_time_from_system()
	var error = SaveGame.export_save(save_name, export_path)
	if error == OK:
		status_label.text = "Save exported successfully to: %s" % export_path
	else:
		status_label.text = "Failed to export save."

func _on_import_button_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.json ; JSON Files"]
	file_dialog.file_selected.connect(_on_import_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

func _on_import_file_selected(path: String) -> void:
	var new_save_name = "imported_save_%s" % Time.get_unix_time_from_system()
	var error = SaveGame.import_save(path, new_save_name)
	if error == OK:
		status_label.text = "Save imported successfully."
		refresh_save_list()
	else:
		status_label.text = "Failed to import save."

func _on_save_selected(index: int) -> void:
	save_name_input.text = SaveGame.get_save_list()[index]["name"]

func _on_save_completed(success: bool, message: String) -> void:
	status_label.text = message
	if success:
		refresh_save_list()

func _on_load_completed(success: bool, message: String) -> void:
	status_label.text = message
	if success:
		var game_manager = get_node("/root/GameManager")
		if game_manager:
			game_manager.start_campaign_turn()
		else:
			push_error("GameManager not found in the scene tree.")
