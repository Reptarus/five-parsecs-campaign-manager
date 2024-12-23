class_name SaveLoadUI
extends Control

signal save_completed
signal load_completed
signal import_completed

@onready var save_name_input: LineEdit = $Panel/VBoxContainer/SaveNameInput
@onready var save_list: ItemList = $Panel/VBoxContainer/SaveList
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var save_button: Button = $Panel/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/ButtonContainer/LoadButton
@onready var delete_button: Button = $Panel/VBoxContainer/ButtonContainer/DeleteButton
@onready var export_button: Button = $Panel/VBoxContainer/ButtonContainer/ExportButton
@onready var import_button: Button = $Panel/VBoxContainer/ButtonContainer/ImportButton
@onready var backup_list_button: Button = $Panel/VBoxContainer/ButtonContainer/BackupListButton

var save_manager: SaveManager
var current_save_name: String = ""

func _ready() -> void:
    save_manager = get_node("/root/SaveManager")
    if not save_manager:
        push_error("SaveManager not found")
        return
    
    _connect_signals()
    _refresh_save_list()
    _update_button_states()

func _connect_signals() -> void:
    save_manager.save_completed.connect(_on_save_manager_save_completed)
    save_manager.load_completed.connect(_on_save_manager_load_completed)
    save_manager.backup_created.connect(_on_save_manager_backup_created)
    save_manager.validation_failed.connect(_on_save_manager_validation_failed)
    
    save_name_input.text_changed.connect(_on_save_name_changed)
    save_list.item_selected.connect(_on_save_selected)
    
    save_button.pressed.connect(_on_save_pressed)
    load_button.pressed.connect(_on_load_pressed)
    delete_button.pressed.connect(_on_delete_pressed)
    export_button.pressed.connect(_on_export_pressed)
    import_button.pressed.connect(_on_import_pressed)
    backup_list_button.pressed.connect(_on_backup_list_pressed)

func _refresh_save_list() -> void:
    save_list.clear()
    var saves = save_manager.get_save_list()
    
    for save in saves:
        var display_text = "%s (Turn %d) - %s" % [save.name, save.campaign_turn, save.date]
        var icon = _get_save_icon(save)
        save_list.add_item(display_text, icon)
        
        # Add tooltip with more details
        var tooltip = """
        Name: %s
        Date: %s
        Game Version: %s
        Save Version: %s
        Campaign Turn: %d
        """.strip_edges() % [save.name, save.date, save.version, save.save_version, save.campaign_turn]
        
        save_list.set_item_tooltip(save_list.get_item_count() - 1, tooltip)
        
        # Add metadata
        save_list.set_item_metadata(save_list.get_item_count() - 1, save)

func _get_save_icon(save: Dictionary) -> Texture2D:
    # Return different icons based on save type (autosave, regular save, etc.)
    # TODO: Replace with proper icons once created
    var icon_name = "autosave_icon" if save.name.begins_with("autosave_") else "save_icon"
    var icon = load("res://icon.svg")  # Use default Godot icon as fallback
    if not icon:
        push_warning("Failed to load icon: " + icon_name)
        return null
    return icon

func _update_button_states() -> void:
    var has_selection = not save_list.get_selected_items().is_empty()
    load_button.disabled = not has_selection
    delete_button.disabled = not has_selection
    export_button.disabled = not has_selection
    
    var has_save_name = not save_name_input.text.strip_edges().is_empty()
    save_button.disabled = not has_save_name

func _show_status(message: String, is_error: bool = false) -> void:
    status_label.text = message
    status_label.modulate = Color.RED if is_error else Color.WHITE
    
    # Create a timer to clear the status after 5 seconds
    var timer = get_tree().create_timer(5.0)
    timer.timeout.connect(func(): status_label.text = "Status: Ready")

func _on_save_manager_save_completed(success: bool, message: String) -> void:
    _show_status(message, not success)
    if success:
        _refresh_save_list()
        save_completed.emit()

func _on_save_manager_load_completed(success: bool, message: String) -> void:
    _show_status(message, not success)
    if success:
        load_completed.emit()

func _on_save_manager_backup_created(success: bool, message: String) -> void:
    if not success:
        _show_status("Backup: " + message, true)

func _on_save_manager_validation_failed(message: String) -> void:
    _show_status("Validation Error: " + message, true)

func _on_save_name_changed(new_text: String) -> void:
    current_save_name = new_text.strip_edges()
    _update_button_states()

func _on_save_selected(index: int) -> void:
    var save_data = save_list.get_item_metadata(index)
    if save_data:
        current_save_name = save_data.name
        save_name_input.text = current_save_name
    _update_button_states()

func _on_save_pressed() -> void:
    if current_save_name.is_empty():
        _show_status("Please enter a save name", true)
        return
    
    var game_state = get_node("/root/GameStateManager")
    if not game_state:
        _show_status("Game state not found", true)
        return
    
    save_manager.save_game(game_state, current_save_name)

func _on_load_pressed() -> void:
    var selected = save_list.get_selected_items()
    if selected.is_empty():
        _show_status("Please select a save file", true)
        return
    
    var save_data = save_list.get_item_metadata(selected[0])
    if not save_data:
        _show_status("Invalid save data", true)
        return
    
    save_manager.load_game(save_data.name)

func _on_delete_pressed() -> void:
    var selected = save_list.get_selected_items()
    if selected.is_empty():
        _show_status("Please select a save file", true)
        return
    
    var save_data = save_list.get_item_metadata(selected[0])
    if not save_data:
        _show_status("Invalid save data", true)
        return
    
    # Show confirmation dialog
    var dialog = ConfirmationDialog.new()
    dialog.dialog_text = "Are you sure you want to delete this save?\nA backup will be created before deletion."
    dialog.confirmed.connect(func():
        if save_manager.delete_save(save_data.name):
            _show_status("Save deleted")
            _refresh_save_list()
        else:
            _show_status("Failed to delete save", true)
    )
    add_child(dialog)
    dialog.popup_centered()

func _on_export_pressed() -> void:
    var selected = save_list.get_selected_items()
    if selected.is_empty():
        _show_status("Please select a save file", true)
        return
    
    var save_data = save_list.get_item_metadata(selected[0])
    if not save_data:
        _show_status("Invalid save data", true)
        return
    
    var file_dialog = FileDialog.new()
    file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    file_dialog.add_filter("*.json", "Save Files")
    file_dialog.current_file = save_data.name + ".json"
    
    file_dialog.file_selected.connect(func(path: String):
        var source_path = "user://saves/" + save_data.name + ".json"
        if DirAccess.copy_absolute(source_path, path) == OK:
            _show_status("Save exported successfully")
        else:
            _show_status("Failed to export save", true)
    )
    
    add_child(file_dialog)
    file_dialog.popup_centered(Vector2(800, 600))

func _on_import_pressed() -> void:
    var file_dialog = FileDialog.new()
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    file_dialog.add_filter("*.json", "Save Files")
    
    file_dialog.file_selected.connect(func(path: String):
        var file = FileAccess.open(path, FileAccess.READ)
        if not file:
            _show_status("Failed to open import file", true)
            return
            
        var content = file.get_as_text()
        file.close()
        
        # Validate the imported save
        var json = JSON.new()
        var parse_result = json.parse(content)
        if parse_result != OK:
            _show_status("Invalid save file format", true)
            return
            
        var save_data = json.get_data()
        var import_name = "imported_" + Time.get_datetime_string_from_system()
        var dest_path = "user://saves/" + import_name + ".json"
        
        var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
        if not dest_file:
            _show_status("Failed to create import file", true)
            return
            
        dest_file.store_string(content)
        dest_file.close()
        
        _show_status("Save imported successfully")
        _refresh_save_list()
        import_completed.emit()
    )
    
    add_child(file_dialog)
    file_dialog.popup_centered(Vector2(800, 600))

func _on_backup_list_pressed() -> void:
    # Show backup list dialog
    var dialog = Window.new()
    dialog.title = "Backup List"
    dialog.size = Vector2(600, 400)
    
    var vbox = VBoxContainer.new()
    dialog.add_child(vbox)
    
    var backup_list = ItemList.new()
    backup_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(backup_list)
    
    var backups = save_manager.get_backup_list()
    for backup in backups:
        backup_list.add_item("%s - %s" % [backup.name, backup.date])
        backup_list.set_item_metadata(backup_list.get_item_count() - 1, backup)
    
    var button_container = HBoxContainer.new()
    vbox.add_child(button_container)
    
    var restore_button = Button.new()
    restore_button.text = "Restore Selected"
    restore_button.disabled = true
    button_container.add_child(restore_button)
    
    var close_button = Button.new()
    close_button.text = "Close"
    button_container.add_child(close_button)
    
    backup_list.item_selected.connect(func(_index): restore_button.disabled = false)
    
    restore_button.pressed.connect(func():
        var selected = backup_list.get_selected_items()
        if selected.is_empty():
            return
            
        var backup_data = backup_list.get_item_metadata(selected[0])
        if save_manager.restore_backup(backup_data.name):
            _show_status("Backup restored successfully")
            _refresh_save_list()
            dialog.queue_free()
        else:
            _show_status("Failed to restore backup", true)
    )
    
    close_button.pressed.connect(func(): dialog.queue_free())
    
    add_child(dialog)
    dialog.popup_centered() 