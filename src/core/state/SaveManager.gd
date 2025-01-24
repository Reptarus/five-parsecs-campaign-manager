class_name SaveManager
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, data: Dictionary)

const SAVE_DIR := "user://saves/"
const SAVE_FILE_EXTENSION := ".save"
const SAVE_VERSION := "1.0.0"
const MAX_BACKUPS := 3
const MAX_SAVE_SLOTS := 10

func _ready() -> void:
    _ensure_save_directory()

func _ensure_save_directory() -> void:
    if not DirAccess.dir_exists_absolute(SAVE_DIR):
        DirAccess.make_dir_absolute(SAVE_DIR)

func save_game(save_data: Dictionary, slot: int = 0) -> void:
    if slot < 0 or slot >= MAX_SAVE_SLOTS:
        save_completed.emit(false, "Invalid save slot")
        return
        
    var save_path := _get_save_path(slot)
    
    # Create backup if file exists
    if FileAccess.file_exists(save_path):
        _create_backup(slot)
    
    # Add metadata
    save_data["save_version"] = SAVE_VERSION
    save_data["save_date"] = Time.get_datetime_string_from_system()
    save_data["game_version"] = ProjectSettings.get_setting("application/config/version")
    
    # Save the file
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        save_completed.emit(false, "Failed to open save file")
        return
    
    file.store_string(JSON.stringify(save_data))
    file.close()
    save_completed.emit(true, "Game saved successfully")

func load_game(slot: int = 0) -> void:
    if slot < 0 or slot >= MAX_SAVE_SLOTS:
        load_completed.emit(false, {})
        return
        
    var save_path := _get_save_path(slot)
    
    if not FileAccess.file_exists(save_path):
        load_completed.emit(false, {})
        return
    
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        load_completed.emit(false, {})
        return
    
    var json_string := file.get_as_text()
    file.close()
    
    var json := JSON.new()
    var parse_result := json.parse(json_string)
    if parse_result != OK:
        # Try to load backup
        if _try_load_backup(slot):
            return
        load_completed.emit(false, {})
        return
    
    var save_data: Dictionary = json.get_data()
    
    # Version check
    if save_data.get("save_version", "0.0.0") != SAVE_VERSION:
        push_warning("Loading save from different version")
    
    load_completed.emit(true, save_data)

func _get_save_path(slot: int) -> String:
    return SAVE_DIR + "save_" + str(slot) + SAVE_FILE_EXTENSION

func _create_backup(slot: int) -> void:
    var save_path := _get_save_path(slot)
    var backup_path := save_path + ".backup"
    
    if FileAccess.file_exists(save_path):
        var file := FileAccess.open(save_path, FileAccess.READ)
        if file == null:
            return
            
        var backup := FileAccess.open(backup_path, FileAccess.WRITE)
        if backup == null:
            file.close()
            return
            
        backup.store_string(file.get_as_text())
        file.close()
        backup.close()

func _try_load_backup(slot: int) -> bool:
    var backup_path := _get_save_path(slot) + ".backup"
    
    if not FileAccess.file_exists(backup_path):
        return false
    
    var file := FileAccess.open(backup_path, FileAccess.READ)
    if file == null:
        return false
    
    var json_string := file.get_as_text()
    file.close()
    
    var json := JSON.new()
    var parse_result := json.parse(json_string)
    if parse_result != OK:
        return false
    
    var save_data: Dictionary = json.get_data()
    load_completed.emit(true, save_data)
    return true

func get_save_slots() -> Array:
    var slots := []
    var dir := DirAccess.open(SAVE_DIR)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(SAVE_FILE_EXTENSION):
                var slot = file_name.trim_suffix(SAVE_FILE_EXTENSION)
                slots.append(slot)
            file_name = dir.get_next()
    return slots

func delete_save(slot: int) -> void:
    if slot < 0 or slot >= MAX_SAVE_SLOTS:
        return
        
    var save_path := _get_save_path(slot)
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
        
    var backup_path := save_path + ".backup"
    if FileAccess.file_exists(backup_path):
        DirAccess.remove_absolute(backup_path)

func has_save(slot: int) -> bool:
    if slot < 0 or slot >= MAX_SAVE_SLOTS:
        return false
    return FileAccess.file_exists(_get_save_path(slot))

func get_save_info(slot: int) -> Dictionary:
    if not has_save(slot):
        return {}
    
    var file := FileAccess.open(_get_save_path(slot), FileAccess.READ)
    if file == null:
        return {}
    
    var json_string := file.get_as_text()
    file.close()
    
    var json := JSON.new()
    var parse_result := json.parse(json_string)
    if parse_result != OK:
        return {}
    
    var save_data: Dictionary = json.get_data()
    return {
        "version": save_data.get("save_version", "unknown"),
        "date": save_data.get("save_date", "unknown"),
        "game_version": save_data.get("game_version", "unknown")
    }