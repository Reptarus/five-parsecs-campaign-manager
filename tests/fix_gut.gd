@tool
extends EditorScript

## GUT Auto-Repair Script
##
## Fixes common GUT issues that cause it to break on project reload
## Run this script from the Godot editor when GUT is broken

const GutStabilityHelper = preload("res://tests/fixtures/helpers/gut_stability_helper.gd")

func _run() -> void:
	print("\n=== Starting GUT repair process ===\n")
	
	# Run stability fixes
	GutStabilityHelper.fix_gut_stability()
	
	# Additional fixes for stubborn issues
	_fix_project_settings()
	_check_plugin_status()
	
	print("\n=== GUT repair process complete ===")
	print("If GUT is still not working, try disabling and re-enabling the plugin in Project Settings.")

## Check and fix project settings related to GUT
func _fix_project_settings() -> void:
	# Check if the GUT plugin is enabled
	var enabled = ProjectSettings.get_setting("editor_plugins/enabled", [])
	var gut_enabled = "res://addons/gut/plugin.cfg" in enabled
	
	print("GUT plugin enabled: " + str(gut_enabled))
	
	if not gut_enabled:
		print("Re-enabling GUT plugin...")
		enabled.append("res://addons/gut/plugin.cfg")
		ProjectSettings.set_setting("editor_plugins/enabled", enabled)
		ProjectSettings.save()
		print("GUT plugin re-enabled. You may need to restart Godot.")

## Check plugin status and report issues
func _check_plugin_status() -> void:
	var plugin_config = "res://addons/gut/plugin.cfg"
	
	if not FileAccess.file_exists(plugin_config):
		print("ERROR: GUT plugin.cfg not found! The plugin may be missing or corrupted.")
		print("Try reinstalling GUT from the Asset Library.")
		return
	
	print("GUT plugin.cfg found and looks valid.")
	
	# Check key files
	var key_files = [
		"res://addons/gut/plugin.gd",
		"res://addons/gut/gut.gd",
		"res://addons/gut/gui/GutBottomPanel.gd",
		"res://addons/gut/gui/gut_config_gui.gd",
		"res://addons/gut/utils.gd",
		"res://addons/gut/compatibility.gd"
	]
	
	var all_files_valid = true
	
	for file_path in key_files:
		if not FileAccess.file_exists(file_path):
			print("ERROR: Key file missing: " + file_path)
			all_files_valid = false
	
	if all_files_valid:
		print("All key GUT files are present.")
	else:
		print("Some GUT files are missing. Try reinstalling the plugin.")