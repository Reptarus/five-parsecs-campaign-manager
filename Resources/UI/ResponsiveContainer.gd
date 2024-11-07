class_name ResponsiveContainer
extends BaseContainer

enum LayoutMode {
    PORTRAIT,
    LANDSCAPE
}

@export var min_width: float = 600.0
@export var portrait_margins: Vector2 = Vector2(10, 10)
@export var landscape_margins: Vector2 = Vector2(20, 20)

var current_mode: LayoutMode = LayoutMode.LANDSCAPE

signal layout_changed(new_mode: LayoutMode)

func _ready() -> void:
    get_tree().root.size_changed.connect(_on_window_resized)
    _update_layout()

func _on_window_resized() -> void:
    _update_layout()

func _update_layout() -> void:
    var window_size = get_viewport_rect().size
    var new_mode = LayoutMode.PORTRAIT if window_size.x < min_width else LayoutMode.LANDSCAPE
    
    if new_mode != current_mode:
        current_mode = new_mode
        layout_changed.emit(current_mode)
        _apply_layout()

func _apply_layout() -> void:
    match current_mode:
        LayoutMode.PORTRAIT:
            _apply_portrait_layout()
        LayoutMode.LANDSCAPE:
            _apply_landscape_layout()

func _apply_portrait_layout() -> void:
    # Override in child classes
    pass

func _apply_landscape_layout() -> void:
    # Override in child classes
    pass 