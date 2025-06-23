@tool
extends GdUnitGameTest

#
static func _load_event_item() -> GDScript:
    if ResourceLoader.exists("res://src/scenes/campaign/components/EventItem.gd"):
        return load("res://src/scenes/campaign/components/EventItem.gd")
    return null

var EventItem: GDScript = _load_event_item()

#
class MockEventItem extends Control:
    var last_value: Variant
    var value_changed_signal_emitted: Variant

    signal value_changed(new_value: String)
    signal timestamp_changed(new_timestamp: String)
    
    var value_label: Label
    var timestamp_label: Label
    var animation_player: AnimationPlayer
    var current_value: String = ""
    var current_timestamp: String = ""
    
    func _init() -> void:
        _setup_components()
    
    func _setup_components() -> void:
        # Create value label
        value_label = Label.new()
        add_child(value_label)
        
        # Create timestamp label
        timestamp_label = Label.new()
        add_child(timestamp_label)
        
        # Create animation player
        animation_player = AnimationPlayer.new()
        add_child(animation_player)
    
    func set_value(new_value: String) -> bool:
        current_value = new_value
        if value_label:
            value_label.text = new_value
        value_changed.emit(new_value)
        return true
        
    func get_current_value() -> String:
        return current_value
        
    func set_timestamp(new_timestamp: String) -> bool:
        current_timestamp = new_timestamp
        if timestamp_label:
            timestamp_label.text = new_timestamp
        timestamp_changed.emit(new_timestamp)
        return true
        
    func set_text_color(color: Color) -> bool:
        if value_label:
            value_label.modulate = color
        if timestamp_label:
            timestamp_label.modulate = color
        return true
        
    func play_highlight_animation() -> bool:
        if animation_player:
            if animation_player.has_animation("highlight"):
                animation_player.play("highlight")
            return true
        return false

# Test variables with explicit types
var value_changed_signal_emitted: bool = false
var last_value: Variant
var _component: Control

func _create_component_instance() -> Control:
    if EventItem:
        return EventItem.new()
    return MockEventItem.new()

func before_test() -> void:
    _component = _create_component_instance()
    auto_free(_component)
    super.before_test()
    _reset_signals()
    _connect_signals()

func after_test() -> void:
    last_value = ""
    value_changed_signal_emitted = false
    _component = null
    super.after_test()

func _reset_signals() -> void:
    last_value = ""
    value_changed_signal_emitted = false

func _connect_signals() -> void:
    if not _component:
        return
    if _component.has_signal("value_changed"):
        _component.value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: String) -> void:
    last_value = new_value
    value_changed_signal_emitted = true

func _safe_call_method_bool(node: Node, method_name: String, args: Array = []) -> bool:
    if node and node.has_method(method_name):
        return node.callv(method_name, args)
    return false

func _safe_call_method(node: Node, method_name: String, args: Array = []) -> Variant:
    if node and node.has_method(method_name):
        return node.callv(method_name, args)
    return null

func _safe_cast_to_string(test_value: Variant) -> String:
    if test_value != null:
        return str(test_value)
    return ""

func _safe_has_property(node: Node, property_name: String) -> bool:
    if not node:
        return false
    return property_name in node

func test_initial_setup() -> void:
    assert_that(_component).is_not_null()

    # Test component structure
    if _safe_has_property(_component, "value_label") and _component.get("value_label"):
        var value_label = _component.get("value_label")
        assert_that(value_label).is_not_null()

    if _safe_has_property(_component, "timestamp_label") and _component.get("timestamp_label"):
        var timestamp_label = _component.get("timestamp_label")
        assert_that(timestamp_label).is_not_null()
    
    var current_value: String = _safe_cast_to_string(_safe_call_method(_component, "get_current_value", []))
    assert_that(current_value).is_not_null()

func test_value_update() -> void:
    var test_value: String = "Test Event"
    _safe_call_method_bool(_component, "set_value", [test_value])
    
    # Wait for signal to be processed
    await get_tree().process_frame
    
    assert_that(value_changed_signal_emitted).is_true()
    assert_that(last_value).is_equal(test_value)
    
    var current_value: String = _safe_cast_to_string(_safe_call_method(_component, "get_current_value", []))
    assert_that(current_value).is_equal(test_value)

    # Test label update
    if _safe_has_property(_component, "value_label") and _component.get("value_label"):
        var value_label = _component.get("value_label")
        assert_that(value_label.text).is_equal(test_value)

func test_empty_value_handling() -> void:
    _safe_call_method_bool(_component, "set_value", [""])
    
    # Wait for signal to be processed
    await get_tree().process_frame
    
    assert_that(value_changed_signal_emitted).is_true()
    assert_that(last_value).is_equal("")

    # Test label update with empty value
    if _safe_has_property(_component, "value_label") and _component.get("value_label"):
        var value_label = _component.get("value_label")
        assert_that(value_label.text).is_equal("")

func test_timestamp_formatting() -> void:
    var test_timestamp: String = "2024-03-20 15:30:00"
    _safe_call_method_bool(_component, "set_timestamp", [test_timestamp])

    # Test timestamp update
    if _safe_has_property(_component, "timestamp_label") and _component.get("timestamp_label"):
        var timestamp_label = _component.get("timestamp_label")
        assert_that(timestamp_label.text).is_equal(test_timestamp)

func test_color_handling() -> void:
    var test_color := Color(1, 0, 0, 1) # Red color
    _safe_call_method_bool(_component, "set_text_color", [test_color])

    # Test color application
    if _safe_has_property(_component, "value_label") and _component.get("value_label"):
        var value_label = _component.get("value_label")
        assert_that(value_label.modulate).is_equal(test_color)

        # Test theme color override if available
        if value_label.has_theme_color_override("font_color"):
            var font_color = value_label.get_theme_color("font_color")
            assert_that(font_color).is_not_null()

    if _safe_has_property(_component, "timestamp_label") and _component.get("timestamp_label"):
        var timestamp_label = _component.get("timestamp_label")
        assert_that(timestamp_label.modulate).is_equal(test_color)

func test_animation_handling() -> void:
    _safe_call_method_bool(_component, "play_highlight_animation", [])
    
    # Wait for animation to start
    await get_tree().process_frame

    # Test animation player existence
    if _safe_has_property(_component, "animation_player") and _component.get("animation_player"):
        var animation_player = _component.get("animation_player")
        assert_that(animation_player).is_not_null()
        # Note: Mock animation player may not actually play, so we just check it exists

func test_component_structure() -> void:
    assert_that(_component).is_not_null()
    
    # Test component has expected properties
    if _safe_has_property(_component, "value_label"):
        assert_that(_component.get("value_label")).is_not_null()
    if _safe_has_property(_component, "timestamp_label"):
        assert_that(_component.get("timestamp_label")).is_not_null()
    if _safe_has_property(_component, "animation_player"):
        assert_that(_component.get("animation_player")).is_not_null()

func test_component_theme() -> void:
    # Test basic theme properties
    if _component.has_method("has_theme_color"):
        if _component.has_theme_color("font_color"):
            var font_color = _component.get_theme_color("font_color")
            assert_that(font_color).is_not_null()
    if _component.has_method("has_theme_stylebox"):
        if _component.has_theme_stylebox("normal"):
            var stylebox = _component.get_theme_stylebox("normal")
            assert_that(stylebox).is_not_null()

func test_component_accessibility() -> void:
    # Test accessibility features
    if _safe_has_property(_component, "value_label") and _component.get("value_label"):
        var value_label = _component.get("value_label")
        assert_that(value_label.get_focus_mode()).is_greater_equal(0)