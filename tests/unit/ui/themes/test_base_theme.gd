@tool
extends "res://addons/gut/test.gd"

## Test suite for base_theme.tres
## Verifies that the base theme has the expected properties and behaviors.

const ThemeManager = preload("res://src/ui/themes/ThemeManager.gd")
const ThemeTestHelper = preload("res://tests/unit/ui/themes/theme_test_helper.gd")

var theme_manager: ThemeManager
var base_theme: Theme
var test_control: Control
var _tracked_nodes: Array[Node] = []

# Helper function for autofree - match parent's signature
func add_child_autofree(node: Variant, call_ready: bool = true) -> Variant:
    add_child(node, call_ready as bool)
    _tracked_nodes.append(node)
    return null

# Custom assert_almost_eq for color comparison
func assert_almost_eq(actual: Color, expected: Color, tolerance: Vector3, text: String = "") -> void:
    var r_diff: float = abs(actual.r - expected.r)
    var g_diff: float = abs(actual.g - expected.g)
    var b_diff: float = abs(actual.b - expected.b)
    
    var is_close: bool = r_diff <= tolerance.x and g_diff <= tolerance.y and b_diff <= tolerance.z
    
    if not is_close:
        push_error("Color values not close enough: %s vs %s (tolerance %s). %s" % [actual, expected, tolerance, text])
    
    assert_true(is_close, text)

func before_all():
    # Load the base theme resource
    base_theme = load("res://src/ui/themes/base_theme.tres")
    assert_not_null(base_theme, "Base theme should be loaded successfully")

func before_each():
    # Create a theme manager instance
    theme_manager = ThemeManager.new()
    add_child_autofree(theme_manager)
    
    # Create a test control to apply themes to
    test_control = Control.new()
    add_child_autofree(test_control)
    test_control.theme = base_theme

func after_each():
    # Clean up tracked nodes
    for node in _tracked_nodes:
        if is_instance_valid(node) and node.is_inside_tree():
            node.queue_free()
    _tracked_nodes.clear()

func test_base_theme_exists():
    # Verify the base theme exists and is a Theme resource
    assert_not_null(base_theme, "Base theme should exist")
    assert_true(base_theme is Theme, "Base theme should be a Theme resource")

func test_base_theme_basic_properties():
    # Verify basic properties using the test helper
    var expected_properties = ThemeTestHelper.get_base_theme_expected_properties()
    
    # If the properties don't match exactly, update the expected values to match the actual theme
    # This test will help catch unintended changes to the theme
    var success = ThemeTestHelper.verify_theme_properties(base_theme, expected_properties, self)
    assert_true(success, "Base theme should have the expected properties")

func test_base_theme_color_properties():
    # Test specific color properties that are important for the base theme
    var expected_colors = {
        "primary": Color(0.2, 0.4, 0.7),
        "background": Color(0.95, 0.95, 0.95),
        "text": Color(0.1, 0.1, 0.1),
        "accent": Color(0.3, 0.6, 0.9),
        "warning": Color(0.9, 0.6, 0.1),
        "error": Color(0.9, 0.2, 0.2),
        "success": Color(0.2, 0.8, 0.2)
    }
    
    # Check if each expected color is defined in the theme
    for color_name in expected_colors:
        var expected_value = expected_colors[color_name]
        
        # Validate that the color exists in the theme
        assert_true(base_theme.has_color(color_name, ""),
            "Base theme should have '%s' color defined" % color_name)
        
        if base_theme.has_color(color_name, ""):
            var actual_value = base_theme.get_color(color_name, "")
            assert_almost_eq(actual_value, expected_value, Vector3(0.05, 0.05, 0.05),
                "Base theme '%s' color should match expected value" % color_name)

func test_base_theme_font_sizes():
    # Test font sizes that should be defined in the base theme
    var expected_font_sizes = {
        "small": 12,
        "normal": 16,
        "large": 24,
        "title": 32,
        "header": 40
    }
    
    # Check if each expected font size is defined in the theme
    for size_name in expected_font_sizes:
        var expected_value = expected_font_sizes[size_name]
        
        # Validate that the font size exists in the theme
        assert_true(base_theme.has_font_size(size_name, ""),
            "Base theme should have '%s' font size defined" % size_name)
        
        if base_theme.has_font_size(size_name, ""):
            var actual_value = base_theme.get_font_size(size_name, "")
            assert_eq(actual_value, expected_value,
                "Base theme '%s' font size should match expected value" % size_name)

func test_base_theme_constants():
    # Test constants that should be defined in the base theme
    var expected_constants = {
        "margin_small": 5,
        "margin": 10,
        "margin_large": 20,
        "padding_small": 2,
        "padding": 5,
        "padding_large": 10,
        "corner_radius": 4,
        "border_width": 1
    }
    
    # Check if each expected constant is defined in the theme
    for constant_name in expected_constants:
        var expected_value = expected_constants[constant_name]
        
        # Validate that the constant exists in the theme
        assert_true(base_theme.has_constant(constant_name, ""),
            "Base theme should have '%s' constant defined" % constant_name)
        
        if base_theme.has_constant(constant_name, ""):
            var actual_value = base_theme.get_constant(constant_name, "")
            assert_eq(actual_value, expected_value,
                "Base theme '%s' constant should match expected value" % constant_name)

func test_theme_manager_applies_base_theme():
    # Verify that the theme manager correctly applies the base theme
    # Set up a fresh control
    var control = Control.new()
    add_child_autofree(control)
    
    # Initial control should not have our base theme
    assert_ne(control.theme, base_theme, "Control should not initially have base theme")
    
    # Connect control to theme manager
    theme_manager.register_themeable(control)
    await get_tree().process_frame
    
    # Control should now have a theme (possibly not base_theme directly but equivalent)
    assert_not_null(control.theme, "Control should have a theme after registration")
    
    # Switch to base theme explicitly
    theme_manager.set_active_theme("base")
    await get_tree().process_frame
    await get_tree().process_frame
    
    # Should now have the base theme or equivalent
    var theme_from_manager = theme_manager.get_theme("base")
    assert_eq(control.theme, theme_from_manager,
        "Control should have the base theme after switching to it")

func test_base_theme_style_box_properties():
    # Test the style boxes in the base theme
    var expected_style_boxes = [
        "panel",
        "button_normal",
        "button_hover",
        "button_pressed",
        "button_disabled",
        "line_edit_normal",
        "line_edit_focus"
    ]
    
    # Check if each expected style box is defined in the theme
    for style_name in expected_style_boxes:
        # Validate that the style box exists in the theme
        assert_true(base_theme.has_stylebox(style_name, ""),
            "Base theme should have '%s' style box defined" % style_name)
        
        if base_theme.has_stylebox(style_name, ""):
            var style_box = base_theme.get_stylebox(style_name, "")
            assert_not_null(style_box, "Style box '%s' should not be null" % style_name)