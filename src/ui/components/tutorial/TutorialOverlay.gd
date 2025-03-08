# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends CanvasLayer

const Self = preload("res://src/ui/components/tutorial/TutorialOverlay.gd")

signal tutorial_completed
signal tutorial_skipped

const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.2)
const DIMMED_COLOR := Color(0, 0, 0, 0.7)
const ANIMATION_TIME := 0.3

@onready var highlight_rect := ColorRect.new()
@onready var dimmed_rect := ColorRect.new()
@onready var tooltip_panel := PanelContainer.new()
@onready var tooltip_label := Label.new()
@onready var next_button := Button.new()
@onready var skip_button := Button.new()

var current_step := 0
var tutorial_steps: Array[Dictionary]
var current_tween: Tween

func _ready() -> void:
    _setup_overlay()
    _connect_signals()
    set_process_input(true)

func _setup_overlay() -> void:
    # Setup dimmed background
    dimmed_rect.color = DIMMED_COLOR
    dimmed_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dimmed_rect)
    
    # Setup highlight rectangle
    highlight_rect.color = HIGHLIGHT_COLOR
    highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(highlight_rect)
    
    # Setup tooltip
    tooltip_panel.add_child(tooltip_label)
    tooltip_panel.add_child(next_button)
    tooltip_panel.add_child(skip_button)
    add_child(tooltip_panel)
    
    # Apply theme overrides
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
    style.corner_radius_top_left = 3
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_left = 3
    style.corner_radius_bottom_right = 3
    tooltip_panel.add_theme_stylebox_override("panel", style)
    
    tooltip_label.add_theme_color_override("font_color", Color.WHITE)
    tooltip_label.add_theme_font_size_override("font_size", 14)
    
    next_button.text = "Next"
    skip_button.text = "Skip Tutorial"
    
    # Initially hide everything
    hide_overlay()

func _connect_signals() -> void:
    next_button.pressed.connect(_on_next_pressed)
    skip_button.pressed.connect(_on_skip_pressed)

func start_tutorial(steps: Array[Dictionary]) -> void:
    tutorial_steps = steps
    current_step = 0
    show_current_step()

func show_current_step() -> void:
    if current_step >= tutorial_steps.size():
        complete_tutorial()
        return
    
    var step = tutorial_steps[current_step]
    var target = get_node_or_null(step.target_path) if step.has("target_path") else null
    
    if target:
        var target_rect = _get_global_rect(target)
        _animate_highlight(target_rect)
        _position_tooltip(target_rect, step.tooltip_position)
    
    tooltip_label.text = step.text
    tooltip_panel.visible = true
    dimmed_rect.visible = true

func _get_global_rect(node: Node) -> Rect2:
    if node is Control:
        return node.get_global_rect()
    elif node is Node2D:
        var transform = node.get_global_transform()
        var size = Vector2(50, 50) # Default size for Node2D
        return Rect2(transform.origin - size / 2, size)
    return Rect2()

func _animate_highlight(target_rect: Rect2) -> void:
    if current_tween:
        current_tween.kill()
    
    current_tween = create_tween()
    current_tween.tween_property(highlight_rect, "position", target_rect.position, ANIMATION_TIME)
    current_tween.parallel().tween_property(highlight_rect, "size", target_rect.size, ANIMATION_TIME)
    highlight_rect.visible = true

func _position_tooltip(target_rect: Rect2, position: String = "bottom") -> void:
    var tooltip_size = tooltip_panel.size
    var viewport_size = get_viewport().get_visible_rect().size
    var pos := Vector2.ZERO
    
    match position:
        "top":
            pos = Vector2(target_rect.position.x, target_rect.position.y - tooltip_size.y - 10)
        "bottom":
            pos = Vector2(target_rect.position.x, target_rect.end.y + 10)
        "left":
            pos = Vector2(target_rect.position.x - tooltip_size.x - 10, target_rect.position.y)
        "right":
            pos = Vector2(target_rect.end.x + 10, target_rect.position.y)
    
    # Ensure tooltip stays within viewport
    pos.x = clamp(pos.x, 0, viewport_size.x - tooltip_size.x)
    pos.y = clamp(pos.y, 0, viewport_size.y - tooltip_size.y)
    
    tooltip_panel.position = pos

func _on_next_pressed() -> void:
    current_step += 1
    show_current_step()

func _on_skip_pressed() -> void:
    hide_overlay()
    tutorial_skipped.emit()

func complete_tutorial() -> void:
    hide_overlay()
    tutorial_completed.emit()

func hide_overlay() -> void:
    highlight_rect.visible = false
    dimmed_rect.visible = false
    tooltip_panel.visible = false