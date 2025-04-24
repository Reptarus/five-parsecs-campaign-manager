@tool
# This file is deprecated and will be removed in a future update
# Please use the implementation at res://src/ui/components/base/ResponsiveContainer.gd instead
extends "res://src/ui/components/base/ResponsiveContainer.gd"

# Important: Do NOT define a class_name here to avoid registration conflicts
const DeprecatedResponsiveContainerClass := "res://src/ui/components/ResponsiveContainer.gd" # Class reference as string path

# Use parent's ThisClass for parent class references, use DeprecatedResponsiveContainerClass for self-references

func _init() -> void:
	push_warning("DEPRECATED: Using 'src/ui/components/ResponsiveContainer.gd' is deprecated. Please use 'src/ui/components/base/ResponsiveContainer.gd' instead.")

func _ready() -> void:
	super._ready()
	
	# Display deprecation warning in editor
	if Engine.is_editor_hint():
		print("[DEPRECATED] Using 'src/ui/components/ResponsiveContainer.gd' is deprecated. Please use 'src/ui/components/base/ResponsiveContainer.gd' instead.")
