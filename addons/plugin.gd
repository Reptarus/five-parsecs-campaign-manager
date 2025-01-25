@tool
extends EditorPlugin

const GeometricShape = preload("res://addons/2d_shapes/shapes/GeometricShape.gd")
const Handle = preload("res://addons/2d_shapes/handles/Handle.gd")
const GridDisplay = preload("res://addons/grid_display/grid_display.gd")

var selected_shape: GeometricShape
var dragged_handle: Handle = null
var handles: Array[Handle] = []
var is_holding_shift := false
var grid_display_instance = null

func _enter_tree() -> void:
    if not _verify_resources():
        push_error("Plugin: Failed to load required resources")
        return
        
    # Initialize 2D Shapes
    _add_shape_types()
    
    # Initialize Grid Display
    add_custom_type("GridDisplay", "Node2D", GridDisplay, null)
    
    # Add undo/redo callback
    add_undo_redo_inspector_hook_callback(undo_redo_callback)

func _exit_tree() -> void:
    # Cleanup 2D Shapes
    _remove_shape_types()
    
    # Cleanup Grid Display
    remove_custom_type("GridDisplay")
    
    # Remove undo/redo callback
    remove_undo_redo_inspector_hook_callback(undo_redo_callback)

func _verify_resources() -> bool:
    var required_resources := {
        "GeometricShape": preload("res://addons/2d_shapes/shapes/GeometricShape.gd"),
        "Handle": preload("res://addons/2d_shapes/handles/Handle.gd"),
        "GridDisplay": preload("res://addons/grid_display/grid_display.gd"),
        "Rectangle": preload("res://addons/2d_shapes/shapes/Rectangle.gd"),
        "Ellipse": preload("res://addons/2d_shapes/shapes/Ellipse.gd"),
        "Arrow": preload("res://addons/2d_shapes/shapes/Arrow.gd"),
        "Triangle": preload("res://addons/2d_shapes/shapes/Triangle.gd"),
        "Polygon": preload("res://addons/2d_shapes/shapes/Polygon.gd"),
        "Star": preload("res://addons/2d_shapes/shapes/Star.gd")
    }
    
    for resource_name in required_resources:
        if not required_resources[resource_name]:
            push_error("Plugin: Failed to load %s" % resource_name)
            return false
    return true

func _add_shape_types() -> void:
    var shape_types := {
        "Rectangle": ["./2d_shapes/shapes/Rectangle.gd", "./2d_shapes/Rectangle.svg"],
        "Ellipse": ["./2d_shapes/shapes/Ellipse.gd", "./2d_shapes/Ellipse.svg"],
        "Arrow": ["./2d_shapes/shapes/Arrow.gd", "./2d_shapes/Arrow.svg"],
        "Triangle": ["./2d_shapes/shapes/Triangle.gd", "./2d_shapes/Triangle.svg"],
        "Polygon": ["./2d_shapes/shapes/Polygon.gd", "./2d_shapes/Polygon.svg"],
        "Star": ["./2d_shapes/shapes/Star.gd", "./2d_shapes/Star.svg"]
    }
    
    for shape_name in shape_types:
        add_custom_type(
            shape_name,
            "Node2D",
            load(shape_types[shape_name][0]),
            load(shape_types[shape_name][1])
        )

func _remove_shape_types() -> void:
    var shape_names := ["Rectangle", "Ellipse", "Arrow", "Triangle", "Polygon", "Star"]
    for shape_name in shape_names:
        remove_custom_type(shape_name)

# Plugin handling for 2D Shapes
var undo_redo_callback = func(undo_redo: Object, modified_object: Object, property: String, new_value: Variant) -> void:
    if modified_object is GeometricShape:
        update_overlays()

func _handles(object: Object) -> bool:
    return object is GeometricShape

func _edit(object: Object) -> void:
    if object is GeometricShape:
        selected_shape = object
        update_overlays()

func _make_visible(visible: bool) -> void:
    if not selected_shape:
        return
    if not visible:
        selected_shape = null
    update_overlays()

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
    if selected_shape and selected_shape.is_inside_tree():
        handles = selected_shape.draw_handles(overlay)

func _forward_canvas_gui_input(event: InputEvent) -> bool:
    if not selected_shape or not selected_shape.visible:
        return false
    
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.is_pressed():
            for handle in handles:
                if not handle.transform.origin.distance_to(event.position) < 10:
                    continue
                handle.start_drag(event)
                dragged_handle = handle
                dragged_handle.on_shift_pressed(is_holding_shift)
                return true
        elif dragged_handle:
            dragged_handle.drag(event)
            dragged_handle.end_drag(get_undo_redo())
            dragged_handle = null
            return true
    
    if event is InputEventMouseMotion and dragged_handle:
        dragged_handle.drag(event)
        update_overlays()
        return true
    
    if event is InputEventKey and event.keycode == KEY_SHIFT:
        is_holding_shift = event.is_pressed()
        if dragged_handle:
            dragged_handle.on_shift_pressed(event.is_pressed())
        return true
    
    return false 