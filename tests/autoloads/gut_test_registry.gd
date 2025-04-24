@tool
extends Node

## GUT Test Registry
##
## This autoload ensures GUT can find and run tests properly.
## It needs to be added as an autoload in project.godot

func _ready() -> void:
	register_test_classes()
	Engine.register_singleton("TestClassRegistry", self)
	
	if Engine.is_editor_hint():
		print("GUT Test Registry initialized in editor")
	else:
		print("GUT Test Registry initialized in game")

func register_test_classes() -> void:
	# Make sure GUT is properly configured
	fix_gut_config()

func fix_gut_config() -> void:
	var gut_config = ProjectSettings.get_setting("gut", {})
	
	# Update the gut configuration if needed
	var needs_update = false
	
	# Check directories
	var dirs = []
	if gut_config.has("directory"):
		var current_dirs = gut_config.directory
		if current_dirs is String:
			dirs = [current_dirs]
		elif current_dirs is Array:
			dirs = current_dirs
		else:
			needs_update = true
	else:
		needs_update = true
	
	# Set correct directories
	if needs_update:
		dirs = [
			"res://tests/unit",
			"res://tests/integration",
			"res://tests/battle",
			"res://tests/performance",
			"res://tests/mobile",
			"res://tests/diagnostic"
		]
		gut_config.directory = PackedStringArray(dirs)
		
	# Check subdirectories
	if !gut_config.has("include_subdirectories") or !gut_config.include_subdirectories:
		gut_config.include_subdirectories = true
		needs_update = true
		
	# Apply changes if needed
	if needs_update:
		ProjectSettings.set_setting("gut", gut_config)
		ProjectSettings.save()
		print("Updated GUT configuration")
	else:
		print("GUT configuration is up to date")