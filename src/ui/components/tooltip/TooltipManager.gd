class_name FPCM_TooltipManager
extends CanvasLayer

const TOOLTIP_OFFSET := Vector2(10, 10)
const TOOLTIP_MARGIN := Vector2(5, 5)
const TOOLTIP_FADE_TIME := 0.2

@onready var tooltip_panel := PanelContainer.new()
@onready var tooltip_label := Label.new()

var current_control: Control
var fade_tween: Tween

func _ready() -> void:
    _setup_tooltip()
    set_process(false)
    
    # Connect to tree change signals to handle control removal
    get_tree().node_removed.connect(_on_node_removed)

func _setup_tooltip() -> void:
    tooltip_panel.visible = false
    tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tooltip_panel.add_child(tooltip_label)
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

func register_tooltip(control: Control, tooltip_text: String) -> void:
    if control.has_meta("tooltip_text"):
        return
        
    control.mouse_entered.connect(_on_control_mouse_entered.bind(control))
    control.mouse_exited.connect(_on_control_mouse_exited.bind(control))
    control.set_meta("tooltip_text", tooltip_text)

func unregister_tooltip(control: Control) -> void:
    if not control.has_meta("tooltip_text"):
        return
        
    if control.mouse_entered.is_connected(_on_control_mouse_entered):
        control.mouse_entered.disconnect(_on_control_mouse_entered)
    if control.mouse_exited.is_connected(_on_control_mouse_exited):
        control.mouse_exited.disconnect(_on_control_mouse_exited)
        
    control.remove_meta("tooltip_text")

func _process(_delta: float) -> void:
    if current_control and tooltip_panel.visible:
        var mouse_pos = get_viewport().get_mouse_position()
        var tooltip_size = tooltip_panel.size
        var viewport_size = get_viewport().get_visible_rect().size
        
        var pos = mouse_pos + TOOLTIP_OFFSET
        
        # Adjust position if tooltip would go off screen
        if pos.x + tooltip_size.x > viewport_size.x:
            pos.x = viewport_size.x - tooltip_size.x - TOOLTIP_MARGIN.x
        if pos.y + tooltip_size.y > viewport_size.y:
            pos.y = viewport_size.y - tooltip_size.y - TOOLTIP_MARGIN.y
        
        tooltip_panel.position = pos

func _on_control_mouse_entered(control: Control) -> void:
    current_control = control
    tooltip_label.text = control.get_meta("tooltip_text")
    
    if fade_tween:
        fade_tween.kill()
    
    fade_tween = create_tween()
    fade_tween.tween_property(tooltip_panel, "modulate:a", 1.0, TOOLTIP_FADE_TIME)
    tooltip_panel.visible = true
    set_process(true)

func _on_control_mouse_exited(control: Control) -> void:
    if current_control == control:
        current_control = null
        
        if fade_tween:
            fade_tween.kill()
        
        fade_tween = create_tween()
        fade_tween.tween_property(tooltip_panel, "modulate:a", 0.0, TOOLTIP_FADE_TIME)
        fade_tween.tween_callback(func(): tooltip_panel.visible = false)
        set_process(false)

func _on_node_removed(node: Node) -> void:
    if node == current_control:
        current_control = null
        tooltip_panel.visible = false
        set_process(false)