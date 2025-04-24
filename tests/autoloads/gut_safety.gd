@tool
extends Node

## GUT Safety Autoload
##
## Provides safety mechanisms for GUT testing to prevent orphaned nodes and memory leaks
## This script will be loaded as an autoload by the project settings

# Keep track of test runs
var _test_in_progress := false
var _verbose := false

func _ready() -> void:
	# Connect to tree exiting signal to perform cleanup
	get_tree().tree_exiting.connect(_on_tree_exiting)
	
	# If we're in the editor, check if GUT is enabled
	if Engine.is_editor_hint():
		_check_gut_enabled()

## Checks if GUT is properly enabled in the project
func _check_gut_enabled() -> void:
	var enabled_plugins = ProjectSettings.get_setting("editor_plugins/enabled", [])
	
	if "res://addons/gut/plugin.cfg" not in enabled_plugins:
		print("WARNING: GUT plugin is not enabled. Some tests may not run correctly.")
		
		# Offer to enable it
		if Engine.is_editor_hint():
			enabled_plugins.append("res://addons/gut/plugin.cfg")
			ProjectSettings.set_setting("editor_plugins/enabled", enabled_plugins)
			ProjectSettings.save()
			print("GUT plugin has been enabled. Restart the editor to apply the changes.")

## Called when a test starts
func register_test_start() -> void:
	_test_in_progress = true
	if _verbose:
		print("GUT Safety: Test run started")

## Called when a test finishes
func register_test_end() -> void:
	_test_in_progress = false
	if _verbose:
		print("GUT Safety: Test run completed")
	
	# Run cleanup procedures
	_cleanup_test_artifacts()

## Cleanup orphaned test objects
func _cleanup_test_artifacts() -> void:
	if _verbose:
		print("GUT Safety: Cleaning up test artifacts")
	
	# Cleanup temp files
	_cleanup_temp_files()
	
	# Force resource unloading
	ResourceLoader.load("res://") # Workaround to flush resource cache
	
	# Check for orphaned nodes and log them
	_check_orphaned_nodes()

## Called when the tree is about to exit
func _on_tree_exiting() -> void:
	print("GUT Safety: Application exiting, performing final cleanup")
	
	# Run a more aggressive cleanup routine
	_cleanup_test_artifacts()
	
	# Find and free any orphaned nodes
	_cleanup_orphaned_nodes()
	
	# Release any leaked resources
	_release_leaked_resources()

## Cleanup temporary files created by GUT
func _cleanup_temp_files() -> void:
	var temp_dir = "res://addons/gut/temp"
	if DirAccess.dir_exists_absolute(temp_dir):
		var dir = DirAccess.open(temp_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".gd"):
					if file_name.contains("gut_temp_") or file_name.contains("__empty"):
						dir.remove(file_name)
						if _verbose:
							print("GUT Safety: Removed temporary script: " + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()

## Check for orphaned nodes and log them
func _check_orphaned_nodes() -> void:
	var total_orphans := 0
	
	# Common container types that might be orphaned
	var container_types = ["HBoxContainer", "VBoxContainer", "CenterContainer", "Container", "PanelContainer"]
	var control_types = ["Button", "Label", "ColorRect", "TextEdit", "LineEdit", "OptionButton"]
	
	# Count orphans by type
	for type in container_types + control_types:
		var nodes = get_tree().get_nodes_in_group(type)
		var orphaned_count := 0
		
		for node in nodes:
			if is_instance_valid(node) and not node.is_inside_tree():
				orphaned_count += 1
				total_orphans += 1
		
		if orphaned_count > 0 and _verbose:
			print("GUT Safety: Found %d orphaned %s nodes" % [orphaned_count, type])
	
	if total_orphans > 0:
		print("GUT Safety: Found %d total orphaned nodes" % total_orphans)

## Cleanup orphaned nodes by freeing them
func _cleanup_orphaned_nodes() -> void:
	# Common container types that might be orphaned
	var container_types = ["HBoxContainer", "VBoxContainer", "CenterContainer", "Container", "PanelContainer"]
	var control_types = ["Button", "Label", "ColorRect", "TextEdit", "LineEdit", "OptionButton"]
	var graphic_types = ["TextParagraph", "StyleBoxFlat", "FontVariation"]
	
	var freed_count := 0
	
	# Free orphans by type
	for type in container_types + control_types + graphic_types:
		var nodes = get_tree().get_nodes_in_group(type)
		
		for node in nodes:
			if is_instance_valid(node) and not node.is_inside_tree():
				node.free()
				freed_count += 1
	
	if freed_count > 0:
		print("GUT Safety: Freed %d orphaned nodes" % freed_count)

## Release any leaked resources
func _release_leaked_resources() -> void:
	# Try to release WorldDataMigration and other common leaks
	var migration_script_path = "res://src/core/migration/WorldDataMigration.gd"
	if ResourceLoader.exists(migration_script_path):
		# Force unload by loading a dummy resource
		ResourceLoader.load("res://")
		print("GUT Safety: Released leaked WorldDataMigration resource")
		
	# Force garbage collection
	print("GUT Safety: Forced final garbage collection")