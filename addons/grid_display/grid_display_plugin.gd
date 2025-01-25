@tool
extends EditorPlugin

var grid_display_script: Script
var grid_display_scene: PackedScene

func _enter_tree() -> void:
	grid_display_script = preload("res://addons/grid_display/grid_display.gd")
	grid_display_scene = preload("res://addons/grid_display/grid_display_scene.tscn")
	
	if not grid_display_script:
		push_error("GridDisplayPlugin: Failed to load script resource")
		return
	
	# Use default icon if custom one not found
	var icon: Texture2D = load("res://addons/grid_display/grid_display.svg") if FileAccess.file_exists("res://addons/grid_display/grid_display.svg") else get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
	
	add_custom_type("GridDisplay", "Node2D", grid_display_script, icon)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		remove_custom_type("GridDisplay")

func _has_main_screen() -> bool:
	return false

func _get_plugin_name() -> String:
	return "Grid Display"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
