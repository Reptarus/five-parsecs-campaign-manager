# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/ui/components/options/AppOptions.gd")

signal options_saved
signal options_reset

const DEFAULT_OPTIONS := {
    "graphics": {
        "fullscreen": false,
        "vsync": true,
        "msaa": 0,
        "fxaa": false,
        "shadows": true,
        "shadow_quality": 2,
        "texture_quality": 2
    },
    "audio": {
        "master_volume": 1.0,
        "music_volume": 0.8,
        "sfx_volume": 0.8,
        "ui_volume": 0.8,
        "mute": false
    },
    "gameplay": {
        "difficulty": 1, # 0: Easy, 1: Normal, 2: Hard
        "tutorial_enabled": true,
        "auto_save": true,
        "auto_save_interval": 5, # minutes
        "show_tooltips": true,
        "show_grid": true
    },
    "controls": {
        "mouse_sensitivity": 1.0,
        "invert_y": false,
        "touch_controls": true,
        "vibration": true,
        "gesture_controls": true
    },
    "accessibility": {
        "high_contrast": false,
        "screen_shake": true,
        "text_size": 1.0,
        "color_blind_mode": 0, # 0: Off, 1: Protanopia, 2: Deuteranopia, 3: Tritanopia
        "dyslexic_font": false
    },
    "ui": {
        "show_fps": false,
        "show_minimap": true,
        "ui_scale": 1.0,
        "chat_opacity": 0.8,
        "hud_layout": 0 # 0: Default, 1: Minimal, 2: Custom
    }
}

var current_options: Dictionary
var config_file_path := "user://options.cfg"

func _ready() -> void:
    _load_options()
    _apply_options()

func _load_options() -> void:
    current_options = DEFAULT_OPTIONS.duplicate(true)
    
    if not FileAccess.file_exists(config_file_path):
        return
    
    var config = ConfigFile.new()
    var err = config.load(config_file_path)
    
    if err != OK:
        push_error("Failed to load options file")
        return
    
    for section in current_options.keys():
        if config.has_section(section):
            for key in current_options[section].keys():
                if config.has_section_key(section, key):
                    current_options[section][key] = config.get_value(section, key)

func save_options() -> void:
    var config = ConfigFile.new()
    
    for section in current_options.keys():
        for key in current_options[section].keys():
            config.set_value(section, key, current_options[section][key])
    
    var err = config.save(config_file_path)
    if err != OK:
        push_error("Failed to save options")
        return
    
    _apply_options()
    options_saved.emit()

func reset_options() -> void:
    current_options = DEFAULT_OPTIONS.duplicate(true)
    save_options()
    options_reset.emit()

func get_option(section: String, key: String, default_value = null):
    if not current_options.has(section) or not current_options[section].has(key):
        return default_value
    return current_options[section][key]

func set_option(section: String, key: String, value) -> void:
    if not current_options.has(section):
        push_error("Invalid options section: " + section)
        return
    
    if not current_options[section].has(key):
        push_error("Invalid option key: " + key)
        return
    
    current_options[section][key] = value

func _apply_options() -> void:
    _apply_graphics_options()
    _apply_audio_options()
    _apply_gameplay_options()
    _apply_control_options()
    _apply_accessibility_options()
    _apply_ui_options()

func _apply_graphics_options() -> void:
    if OS.has_feature("pc"): # Only apply on desktop platforms
        DisplayServer.window_set_mode(
            DisplayServer.WINDOW_MODE_FULLSCREEN if current_options.graphics.fullscreen
            else DisplayServer.WINDOW_MODE_WINDOWED
        )
    
    DisplayServer.window_set_vsync_mode(
        DisplayServer.VSYNC_ENABLED if current_options.graphics.vsync
        else DisplayServer.VSYNC_DISABLED
    )
    
    # Apply other graphics options through project settings
    ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa", current_options.graphics.msaa)
    ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", 1 if current_options.graphics.fxaa else 0)

func _apply_audio_options() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(current_options.audio.master_volume))
    AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), current_options.audio.mute)
    
    for bus_name in ["Music", "SFX", "UI"]:
        var bus_idx = AudioServer.get_bus_index(bus_name)
        if bus_idx >= 0:
            var volume_key = bus_name.to_lower() + "_volume"
            AudioServer.set_bus_volume_db(bus_idx, linear_to_db(current_options.audio[volume_key]))

func _apply_gameplay_options() -> void:
    # These would typically be accessed by the gameplay systems
    pass

func _apply_control_options() -> void:
    Input.set_use_accumulated_input(true)
    # Mouse sensitivity is handled through project settings
    ProjectSettings.set_setting("input/mouse_sensitivity", current_options.controls.mouse_sensitivity)
    
    if OS.has_feature("mobile"):
        # Touch emulation is handled through project settings
        ProjectSettings.set_setting("input/touch_emulation", current_options.controls.touch_controls)

func _apply_accessibility_options() -> void:
    if current_options.accessibility.high_contrast:
        # Apply high contrast theme
        pass
    
    if current_options.accessibility.dyslexic_font:
        # Load and apply dyslexic font
        pass
    
    # Apply color blind mode shader if needed
    var color_blind_mode = current_options.accessibility.color_blind_mode
    if color_blind_mode > 0:
        # Apply appropriate color correction shader
        pass

func _apply_ui_options() -> void:
    var canvas_layer = get_tree().root.get_node("UILayer")
    if canvas_layer:
        canvas_layer.scale = Vector2.ONE * current_options.ui.ui_scale