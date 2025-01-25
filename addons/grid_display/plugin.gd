@tool
extends EditorPlugin

func _enter_tree() -> void:
    add_custom_type("GridDisplay", "Node2D", preload("grid_display.gd"), null)

func _exit_tree() -> void:
    remove_custom_type("GridDisplay") 