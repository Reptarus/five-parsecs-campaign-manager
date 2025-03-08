# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/ui/components/base/ResponsiveContainer.gd")

signal orientation_changed(is_portrait: bool)

@export var portrait_threshold := 1.0 # Width/Height ratio threshold for portrait mode
@export var min_width := 300.0 # Minimum width before switching to portrait mode

var is_portrait := false
var main_container: Container

func _ready() -> void:
    resized.connect(_check_orientation)
    _setup_container()
    _check_orientation()

func _setup_container() -> void:
    main_container = $MainContainer if has_node("MainContainer") else null
    if not main_container:
        push_error("ResponsiveContainer: MainContainer node not found")

func _check_orientation() -> void:
    var size_ratio := size.x / size.y if size.y > 0 else 1.0
    var new_is_portrait := size_ratio < portrait_threshold or size.x < min_width
    
    if new_is_portrait != is_portrait:
        is_portrait = new_is_portrait
        _apply_layout()
        orientation_changed.emit(is_portrait)

func _apply_layout() -> void:
    if not main_container:
        return
        
    if is_portrait:
        _apply_portrait_layout()
    else:
        _apply_landscape_layout()

func _apply_portrait_layout() -> void:
    # Override in child classes
    pass

func _apply_landscape_layout() -> void:
    # Override in child classes
    pass

func is_in_portrait_mode() -> bool:
    return is_portrait