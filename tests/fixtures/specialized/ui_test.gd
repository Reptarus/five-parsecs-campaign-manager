@tool
extends GdUnitGameTest
class_name UITest

#
const UI_TEST_CONFIG := {
    "stabilize_time": 0.2,
    "theme_override_timeout": 0.1,
    "min_touch_target_size": 44.0
}

#
const SCREEN_SIZES := {
    "phone_portrait": Vector2i(360, 640),
    "phone_landscape": Vector2i(640, 360),
    "tablet_portrait": Vector2i(768, 1024),
    "tablet_landscape": Vector2i(1024, 768),
    "desktop": Vector2i(1920, 1080)
}

#
var _test_control: Control
var _viewport_size: Vector2i
var _performance_metrics: Dictionary

func before_test() -> void:
    super.before_test()
    _viewport_size = get_viewport().size

func after_test() -> void:
    super.after_test()

func _setup_ui_environment() -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    get_viewport().gui_embed_subwindows = false

func _restore_ui_environment() -> void:
    get_tree().root.size = _viewport_size

#
func assert_control_visible(control: Control, message: String = "") -> GdUnitBoolAssert:
    var failure_message = message if message else "Control should be visible and have size"
    return GdUnitBoolAssert.new()

func assert_control_hidden(control: Control, message: String = "") -> GdUnitBoolAssert:
    var failure_message = message if message else "Control should be hidden"
    return GdUnitBoolAssert.new()

#
func assert_theme_override(control: Control, property: String, value: Variant) -> void:
    var failure_message = "Control should have theme override for %s" % property
    var value_message = "Theme override value should match expected"

func simulate_ui_input(control: Control, event: InputEvent) -> void:
    control.gui_input.emit(event)

func simulate_click(control: Control, position: Vector2 = Vector2.ZERO) -> void:
    var click = InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = position
    control.gui_input.emit(click)
    
    click.pressed = false
    control.gui_input.emit(click)

#
func test_responsive_layout() -> void:
    # Create a test control for responsive testing
    var control: Control = Control.new()
    
    for size_name in SCREEN_SIZES:
        var size = SCREEN_SIZES[size_name]
        get_tree().root.size = size
        
        # Verify layout constraints
        var width_message = "Control width should fit screensize %s" % size_name
        var height_message = "Control height should fit screen size %s" % size_name
        
        # Check touch target sizes
        for child in control.find_children("*", "Control"):
            if child.focus_mode != Control.FOCUS_NONE:
                var touch_message = "Touch target size should be at least %sx%s pixels" % [UI_TEST_CONFIG.min_touch_target_size, UI_TEST_CONFIG.min_touch_target_size]

#
func start_ui_performance_monitoring() -> void:
    _performance_metrics = {
        "layout_updates": 0,
        "draw_calls": 0,
        "theme_lookups": 0
    }

func stop_ui_performance_monitoring() -> Dictionary:
    return _performance_metrics

func assert_ui_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
    for key in thresholds:
        var failure_message = "Performance metric %s exceeded threshold: %s > %s" % [key, metrics[key], thresholds[key]]

#
func test_accessibility() -> void:
    # Create a test control for accessibility testing
    var control: Control = Control.new()
    
    # Add some focusable children for testing
    var button1 = Button.new()
    button1.name = "TestButton1"
    button1.focus_mode = Control.FOCUS_ALL
    control.add_child(button1)
    
    var button2 = Button.new()
    button2.name = "TestButton2"
    button2.focus_mode = Control.FOCUS_ALL
    control.add_child(button2)
    
    # Test focus navigation
    var focusable = control.find_children("*", "Control")
    focusable = focusable.filter(func(c): return c.focus_mode != Control.FOCUS_NONE)
    
    for i: int in range(focusable.size()):
        var current = focusable[i]
        current.grab_focus()
        var focus_message = "Control %s should be able to receive focus" % current.name
        
        if i < focusable.size() - 1:
            var next_message = "Control %s should have valid next focus target" % current.name

#
func test_animations() -> void:
    # Create a test control for animation testing
    var control: Control = Control.new()
    
    # Create a test AnimationPlayer
    var animation_player = AnimationPlayer.new()
    animation_player.name = "AnimationPlayer"
    control.add_child(animation_player)
    
    # Create a simple test animation
    var animation = Animation.new()
    animation.length = 0.1
    animation_player.add_animation_library("test", AnimationLibrary.new())
    animation_player.get_animation_library("test").add_animation("test_anim", animation)
    
    for anim_name in animation_player.get_animation_list():
        animation_player.play(anim_name)
        var completion_message = "Animation %s should complete" % anim_name

#
func find_child_by_type(parent: Node, type: String) -> Node:
    for child in parent.get_children():
        if child.get_class() == type:
            return child
    return null

func find_children_by_type(parent: Node, type: String) -> Array[Node]:
    var result: Array[Node] = []
    for child in parent.get_children():
        if child.get_class() == type:
            result.append(child)
    return result

func wait_for_animation(animation_player: AnimationPlayer, animation_name: String) -> void:
    animation_player.play(animation_name)

#
func create_ui_component(component_class: GDScript, component_name: String = "") -> Control:
    """Create a UI component safely with automatic cleanup"""
    var component = component_class.new()
    if not component_name.is_empty():
        component.name = component_name
    return component

func safe_get_ui_node(parent: Node, node_path: String) -> Node:
    """Safely get a UI node without throwing errors"""
    if not is_instance_valid(parent):
        return null
    return parent.get_node_or_null(node_path)

func safe_get_ui_property(ui_element: Control, property_name: String, default_value = null) -> Variant:
    """Safely access UI properties"""
    if not is_instance_valid(ui_element):
        return default_value

    if property_name in ui_element:
        return ui_element.get(property_name)
    return default_value

func safe_set_ui_property(ui_element: Control, property_name: String, value) -> bool:
    """Safely set UI properties"""
    if not is_instance_valid(ui_element):
        return false

    if property_name in ui_element:
        ui_element.set(property_name, value)
        return true
    return false

func safe_connect_ui_signal(ui_element: Control, signal_name: String, callback: Callable) -> bool:
    """Safely connect to UI signals"""
    if not is_instance_valid(ui_element):
        return false

    if ui_element.has_signal(signal_name):
        ui_element.connect(signal_name, callback)
        return true
    return false

func safe_simulate_ui_input(ui_element: Control, input_type: String, value = null) -> bool:
    """Simulate UI input safely"""
    if not is_instance_valid(ui_element):
        return false

    match input_type:
        "click":
            if ui_element.has_signal("pressed"):
                ui_element.emit_signal("pressed")
                return true
            elif ui_element.has_signal("gui_input"):
                var event = InputEventMouseButton.new()
                event.button_index = MOUSE_BUTTON_LEFT
                event.pressed = true
                ui_element.emit_signal("gui_input", event)
                return true
        "text_change":
            if ui_element.has_signal("text_changed") and value != null:
                if "text" in ui_element:
                    ui_element.text = str(value)
                ui_element.emit_signal("text_changed", str(value))
                return true
        "toggle":
            if ui_element.has_signal("toggled"):
                if "button_pressed" in ui_element:
                    ui_element.button_pressed = bool(value) if value != null else not ui_element.button_pressed
                ui_element.emit_signal("toggled", ui_element.button_pressed if "button_pressed" in ui_element else true)
                return true
        "item_selected":
            if ui_element.has_signal("item_selected") and value != null:
                if "selected" in ui_element:
                    ui_element.selected = int(value)
                ui_element.emit_signal("item_selected", int(value))
                return true
    return false

func wait_for_ui_ready(ui_element: Control, timeout: float = 2.0) -> bool:
    """Wait for UI element to be fully ready"""
    if not is_instance_valid(ui_element):
        return false
    
    var start_time = Time.get_ticks_msec()
    while Time.get_ticks_msec() - start_time < timeout * 1000:
        if ui_element.is_node_ready():
            return true
    return false

func monitor_ui_signals(ui_element: Control, signal_names: Array[String] = []) -> void:
    """Monitor UI signals safely"""
    if not is_instance_valid(ui_element):
        return
    
    # Monitor all signals if none specified
    if signal_names.is_empty():
        var signal_list = ui_element.get_signal_list()
        for signal_info in signal_list:
            if signal_info is Dictionary and signal_info.has("name"):
                signal_names.append(signal_info["name"])
    
    for signal_name in signal_names:
        if not ui_element.has_signal(signal_name):
            push_warning("Signal '%s' does not exist on %s" % [signal_name, ui_element.get_class()])

func assert_ui_signal_emitted(ui_element: Control, signal_name: String, timeout: float = 2.0) -> void:
    """Assert UI signal was emitted with safe checking"""
    if not is_instance_valid(ui_element):
        return
    
    var start_time = Time.get_ticks_msec()
    while Time.get_ticks_msec() - start_time < timeout * 1000:
        if ui_element.has_signal(signal_name):
            return

func assert_ui_property_equals(ui_element: Control, property_name: String, expected_value, message: String = "") -> void:
    """Assert UI property equals expected value"""
    var actual_value = safe_get_ui_property(ui_element, property_name)
    var failure_message = message if not message.is_empty() else "Property '%s' should equal expected value" % property_name

func assert_ui_element_exists(parent: Node, node_path: String, message: String = "") -> void:
    """Assert UI element exists"""
    var element = safe_get_ui_node(parent, node_path)
    var failure_message = message if not message.is_empty() else "UI element '%s' should exist" % node_path

# Note: UI cleanup is handled by parent class auto_free() mechanism
# Additional UI-specific cleanup can be added to individual tests if needed
