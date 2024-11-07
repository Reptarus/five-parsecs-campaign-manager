class_name AppOptions
extends Node

signal settings_changed

const SETTINGS_PATH := "user://app_settings.json"

# Audio Settings
@export var master_volume: float = 1.0
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var ui_volume: float = 1.0

# Haptic Feedback
@export var haptic_enabled: bool = true
@export var haptic_strength: float = 1.0

# UI Settings
@export var font_size: float = 1.0
@export var high_contrast_mode: bool = false
@export var color_blind_mode: String = "none"  # none, protanopia, deuteranopia, tritanopia
@export var show_tooltips: bool = true
@export var touch_deadzone: float = 0.5

# Performance Settings
@export var enable_particles: bool = true
@export var enable_animations: bool = true
@export var target_fps: int = 60
@export var vsync_enabled: bool = true

# Accessibility Settings
@export var screen_reader_enabled: bool = false
@export var text_to_speech_rate: float = 1.0
@export var auto_pause_on_unfocus: bool = true
@export var reduce_motion: bool = false

# Game Settings
@export var auto_save_frequency: int = 5  # minutes
@export var battle_animation_speed: float = 1.0
@export var show_hit_chances: bool = true
@export var confirm_critical_actions: bool = true
@export var auto_rotate_camera: bool = true

# Tutorial Settings
@export var show_tutorial_prompts: bool = true
@export var show_advanced_tips: bool = false

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var settings = {
		"audio": {
			"master": master_volume,
			"music": music_volume,
			"sfx": sfx_volume,
			"ui": ui_volume
		},
		"haptic": {
			"enabled": haptic_enabled,
			"strength": haptic_strength
		},
		"ui": {
			"font_size": font_size,
			"high_contrast": high_contrast_mode,
			"color_blind_mode": color_blind_mode,
			"show_tooltips": show_tooltips,
			"touch_deadzone": touch_deadzone
		},
		"performance": {
			"particles": enable_particles,
			"animations": enable_animations,
			"target_fps": target_fps,
			"vsync": vsync_enabled
		},
		"accessibility": {
			"screen_reader": screen_reader_enabled,
			"tts_rate": text_to_speech_rate,
			"auto_pause": auto_pause_on_unfocus,
			"reduce_motion": reduce_motion
		},
		"game": {
			"auto_save_frequency": auto_save_frequency,
			"battle_animation_speed": battle_animation_speed,
			"show_hit_chances": show_hit_chances,
			"confirm_critical_actions": confirm_critical_actions,
			"auto_rotate_camera": auto_rotate_camera
		},
		"tutorial": {
			"show_prompts": show_tutorial_prompts,
			"show_advanced_tips": show_advanced_tips
		}
	}
	
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings))
	file.close()
	settings_changed.emit()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
		
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	if json.error == OK:
		var settings = json.result
		_apply_settings(settings)

func _apply_settings(settings: Dictionary) -> void:
	if "audio" in settings:
		master_volume = settings["audio"]["master"]
		music_volume = settings["audio"]["music"]
		sfx_volume = settings["audio"]["sfx"]
		ui_volume = settings["audio"]["ui"]
	
	if "haptic" in settings:
		haptic_enabled = settings["haptic"]["enabled"]
		haptic_strength = settings["haptic"]["strength"]
	
	if "mobile" in settings:
		for key in settings["mobile"]:
			if key in mobile_settings:
				mobile_settings[key] = settings["mobile"][key]
	
	settings_changed.emit()

func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	ui_volume = 1.0
	haptic_enabled = true
	haptic_strength = 1.0
	# Reset other settings...
	settings_changed.emit() 

# Mobile-specific settings
var mobile_settings = {
	# Touch Controls
	"touch_sensitivity": 1.0,
	"swipe_threshold": 50.0,  # Minimum distance for swipe detection
	"double_tap_time": 0.3,   # Time window for double tap
	"long_press_time": 0.5,   # Time for long press detection
	
	# Gesture Controls
	"enable_pinch_zoom": true,
	"enable_two_finger_rotate": true,
	"enable_swipe_navigation": true,
	"enable_edge_swipe": true,  # For side menu access
	
	# UI Scaling
	"ui_scale_factor": 1.0,
	"minimum_touch_target": 44.0,  # Minimum size in pixels for touch targets
	"button_spacing": 10.0,        # Space between interactive elements
	
	# Battery/Performance
	"power_save_mode": false,
	"background_processing": true,
	"offline_mode": false,
	
	# Network
	"auto_sync": true,
	"wifi_only_sync": false,
	"compress_data": true,
	
	# Device-specific
	"use_native_share": true,
	"use_haptic_feedback": true,
	"use_system_orientation": true,
	"lock_orientation": "dynamic",  # dynamic, portrait, landscape
	
	# Accessibility
	"screen_reader_focus_mode": false,  # Extra focus indicators for screen readers
	"large_touch_areas": false,         # Increased touch target sizes
	"vibration_intensity": 1.0,        # For haptic feedback
	
	# Data Management
	"auto_backup": true,
	"backup_frequency": 24,  # Hours
	"max_backup_size": 100,  # MB
	"clear_cache_on_exit": false,
	
	# Quick Start Experience
	"quick_start_gestures": true,
	"template_preview_on_hold": true,
	"swipe_navigation_enabled": true,
	"haptic_feedback_on_select": true
}