@tool
extends "res://addons/gut/test.gd"

## Test suite for dark_theme.tres
## Verifies that the dark theme has the expected properties and behaviors.

const ThemeManager = preload("res://src/ui/themes/ThemeManager.gd")
const ThemeTestHelper = preload("res://tests/unit/ui/themes/theme_test_helper.gd")

var theme_manager: ThemeManager
var dark_theme: Theme
var test_control: Control
var _tracked_nodes: Array[Node] = []

# Helper function for autofree
func add_child_autofree(node: Node) -> void:
    add_child(node)
    _tracked_nodes.append(node)

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
    # Load the dark theme resource
    dark_theme = load("res://src/ui/themes/dark_theme.tres")
    assert_not_null(dark_theme, "Dark theme should be loaded successfully")

func before_each():
    # Create a theme manager instance
    theme_manager = ThemeManager.new()
    add_child_autofree(theme_manager)
    
    # Create a test control to apply themes to
    test_control = Control.new()
    add_child_autofree(test_control)
    test_control.theme = dark_theme

func after_each():
    # Clean up tracked nodes
    for node in _tracked_nodes:
        if is_instance_valid(node) and node.is_inside_tree():
            node.queue_free()
    _tracked_nodes.clear()

func test_dark_theme_exists():
    # Verify the dark theme exists and is a Theme resource
    assert_not_null(dark_theme, "Dark theme should exist")
    assert_true(dark_theme is Theme, "Dark theme should be a Theme resource")

func test_dark_theme_basic_properties():
    # Verify basic properties using the test helper
    var expected_properties = ThemeTestHelper.get_dark_theme_expected_properties()
    
    # Test will help catch unintended changes to the theme
    var success = ThemeTestHelper.verify_theme_properties(dark_theme, expected_properties, self)
    assert_true(success, "Dark theme should have the expected properties")

func test_dark_theme_color_properties():
    # Test specific color properties that are important for the dark theme
    var expected_colors = {
        "background": Color(0.15, 0.15, 0.15),
        "text": Color(0.9, 0.9, 0.9),
        "primary": Color(0.3, 0.5, 0.8),
        "secondary": Color(0.8, 0.4, 0.3),
        "accent": Color(0.4, 0.7, 1.0),
        "warning": Color(1.0, 0.7, 0.2),
        "error": Color(1.0, 0.3, 0.3),
        "success": Color(0.3, 0.9, 0.3)
    }
    
    # Check if each expected color is defined in the theme
    for color_name in expected_colors:
        var expected_value = expected_colors[color_name]
        
        # Validate that the color exists in the theme
        assert_true(dark_theme.has_color(color_name, ""),
            "Dark theme should have '%s' color defined" % color_name)
        
        if dark_theme.has_color(color_name, ""):
            var actual_value = dark_theme.get_color(color_name, "")
            assert_almost_eq(actual_value, expected_value, Vector3(0.05, 0.05, 0.05),
                "Dark theme '%s' color should match expected value" % color_name)

func test_dark_theme_contrast_ratio():
    # Test that the dark theme has sufficient contrast for accessibility
    # WCAG 2.0 level AA requires a contrast ratio of at least 4.5:1 for normal text
    # Test the contrast between background and text colors
    if dark_theme.has_color("background", "") and dark_theme.has_color("text", ""):
        var background_color = dark_theme.get_color("background", "")
        var text_color = dark_theme.get_color("text", "")
        
        var contrast_ratio = _calculate_contrast_ratio(background_color, text_color)
        assert_gt(contrast_ratio, 4.5,
            "Dark theme should have sufficient contrast between background and text (WCAG 2.0 AA)")
    
    # Test the contrast between background and primary/accent colors
    if dark_theme.has_color("background", "") and dark_theme.has_color("primary", ""):
        var background_color = dark_theme.get_color("background", "")
        var primary_color = dark_theme.get_color("primary", "")
        
        var contrast_ratio = _calculate_contrast_ratio(background_color, primary_color)
        assert_gt(contrast_ratio, 3.0,
            "Dark theme should have good contrast between background and primary colors")

func test_theme_manager_applies_dark_theme():
    # Verify that the theme manager correctly applies the dark theme
    # Set up a fresh control
    var control = Control.new()
    add_child_autofree(control)
    
    # Initial control should not have our dark theme
    assert_ne(control.theme, dark_theme, "Control should not initially have dark theme")
    
    # Connect control to theme manager
    theme_manager.register_themeable(control)
    await get_tree().process_frame
    
    # Switch to dark theme explicitly
    theme_manager.set_active_theme("dark")
    await get_tree().process_frame
    await get_tree().process_frame
    
    # Should now have the dark theme or equivalent
    var theme_from_manager = theme_manager.get_theme("dark")
    assert_eq(control.theme, theme_from_manager,
        "Control should have the dark theme after switching to it")

func test_dark_theme_style_box_properties():
    # Test the style boxes in the dark theme
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
        assert_true(dark_theme.has_stylebox(style_name, ""),
            "Dark theme should have '%s' style box defined" % style_name)
        
        if dark_theme.has_stylebox(style_name, ""):
            var style_box = dark_theme.get_stylebox(style_name, "")
            assert_not_null(style_box, "Style box '%s' should not be null" % style_name)

# Helper method to calculate contrast ratio between two colors
# Based on WCAG 2.0 formula: https://www.w3.org/TR/WCAG20-TECHS/G17.html
func _calculate_contrast_ratio(color1: Color, color2: Color) -> float:
    # Calculate relative luminance for each color
    var luminance1 = _get_relative_luminance(color1)
    var luminance2 = _get_relative_luminance(color2)
    
    # Determine which is lighter
    var lighter = max(luminance1, luminance2)
    var darker = min(luminance1, luminance2)
    
    # Calculate contrast ratio
    return (lighter + 0.05) / (darker + 0.05)

# Helper method to calculate relative luminance of a color
# Based on WCAG 2.0 formula: https://www.w3.org/TR/WCAG20-TECHS/G17.html
func _get_relative_luminance(color: Color) -> float:
    # Convert sRGB components to linear values
    var r = _convert_to_linear(color.r)
    var g = _convert_to_linear(color.g)
    var b = _convert_to_linear(color.b)
    
    # Calculate luminance using WCAG 2.0 formula
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

# Helper method to convert sRGB component to linear value
func _convert_to_linear(component: float) -> float:
    if component <= 0.03928:
        return component / 12.92
    else:
        return pow((component + 0.055) / 1.055, 2.4)