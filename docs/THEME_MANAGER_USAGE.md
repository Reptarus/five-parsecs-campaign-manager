# ThemeManager Usage Guide

## Overview
ThemeManager is a global autoload singleton that handles theme switching, color palettes, font scaling, and accessibility features across the Five Parsecs Campaign Manager.

## Features
- **5 Theme Variants**: Dark (Deep Space), Light, High Contrast, Colorblind (Deuteranopia), Colorblind (Protanopia)
- **Dynamic Theme Switching**: Apply themes at runtime with instant UI updates
- **Persistent Settings**: Automatically saves/loads theme preferences to `user://theme_settings.cfg`
- **Font Scaling**: Scale all UI fonts from 0.8x to 2.0x
- **Control Registration**: Automatic theme updates for registered controls
- **Accessibility**: High contrast mode and colorblind-friendly palettes

## Quick Start

### Accessing ThemeManager
ThemeManager is globally available as an autoload singleton:

```gdscript
# Access from any script
var current_theme = ThemeManager.get_current_theme()
var accent_color = ThemeManager.get_color("accent")
```

### Getting Colors

```gdscript
# Get colors from current theme
var base_bg = ThemeManager.get_color("base")              # Background
var elevated_bg = ThemeManager.get_color("elevated")      # Card backgrounds
var accent = ThemeManager.get_color("accent")             # Primary accent
var text_primary = ThemeManager.get_color("text_primary") # Main text
var success = ThemeManager.get_color("success")           # Success states
var warning = ThemeManager.get_color("warning")           # Warning states
var danger = ThemeManager.get_color("danger")             # Error/danger states
```

### Available Colors (All Themes)
- `base` - Darkest background
- `elevated` - Card/panel backgrounds
- `input` - Input field backgrounds
- `border` - Border colors
- `accent` - Primary accent color
- `accent_hover` - Hover state for accent
- `focus` - Focus ring color
- `text_primary` - Main text color
- `text_secondary` - Secondary/muted text
- `text_disabled` - Disabled text
- `success` - Success indicators
- `warning` - Warning indicators
- `danger` - Error/danger indicators

### Getting Font Sizes

```gdscript
# Get scaled font sizes
var caption_size = ThemeManager.get_font_size("xs")    # 11px (captions)
var small_size = ThemeManager.get_font_size("sm")      # 14px (descriptions)
var body_size = ThemeManager.get_font_size("md")       # 16px (body text)
var header_size = ThemeManager.get_font_size("lg")     # 18px (section headers)
var title_size = ThemeManager.get_font_size("xl")      # 24px (panel titles)

# Sizes automatically scale with current scale factor
ThemeManager.set_scale_factor(1.5)
var scaled_body = ThemeManager.get_font_size("md")  # Returns 24px (16 * 1.5)
```

## Applying Themes

### Switch Theme

```gdscript
# Apply a different theme variant
ThemeManager.apply_theme(ThemeManager.ThemeVariant.LIGHT)
ThemeManager.apply_theme(ThemeManager.ThemeVariant.HIGH_CONTRAST)
ThemeManager.apply_theme(ThemeManager.ThemeVariant.COLORBLIND_DEUTERANOPIA)

# All registered controls update automatically
```

### Theme Variants

```gdscript
enum ThemeVariant {
    DARK,                       # Default deep space theme
    LIGHT,                      # Light mode
    HIGH_CONTRAST,              # Accessibility (pure black, white borders)
    COLORBLIND_DEUTERANOPIA,    # Red-green colorblind (most common)
    COLORBLIND_PROTANOPIA       # Red-green colorblind variant
}
```

## Registering Controls for Auto-Updates

### Manual Registration

```gdscript
func _ready() -> void:
    # Register control for automatic theme updates
    ThemeManager.register_control(self)
    
    # Apply initial theme colors
    _apply_current_theme()

func _exit_tree() -> void:
    # Unregister when removed from tree
    ThemeManager.unregister_control(self)

func _apply_current_theme() -> void:
    # Get colors from current theme
    var bg_color = ThemeManager.get_color("elevated")
    var text_color = ThemeManager.get_color("text_primary")
    
    # Apply to UI elements
    $Background.color = bg_color
    $Label.add_theme_color_override("font_color", text_color)
```

### Listen for Theme Changes

```gdscript
func _ready() -> void:
    # Connect to theme changed signal
    ThemeManager.theme_changed.connect(_on_theme_changed)

func _on_theme_changed(theme_name: String) -> void:
    print("Theme changed to: ", theme_name)
    _update_ui_colors()

func _update_ui_colors() -> void:
    # Re-apply colors from new theme
    $Panel.color = ThemeManager.get_color("elevated")
    $AccentButton.modulate = ThemeManager.get_color("accent")
```

## Integration with BaseCampaignPanel

BaseCampaignPanel already defines color constants. You can integrate ThemeManager by replacing hardcoded colors:

```gdscript
# Before (hardcoded)
const COLOR_ACCENT := Color("#3b82f6")
$Button.modulate = COLOR_ACCENT

# After (theme-aware)
$Button.modulate = ThemeManager.get_color("accent")
```

### Example: Theme-Aware Panel

```gdscript
extends FiveParsecsCampaignPanel

func _ready() -> void:
    super._ready()
    ThemeManager.register_control(self)
    ThemeManager.theme_changed.connect(_on_theme_changed)
    _apply_theme_colors()

func _exit_tree() -> void:
    ThemeManager.unregister_control(self)
    super._exit_tree()

func _on_theme_changed(_theme_name: String) -> void:
    _apply_theme_colors()

func _apply_theme_colors() -> void:
    # Update all UI elements with current theme
    $Background.color = ThemeManager.get_color("base")
    $CardPanel.get_theme_stylebox("panel").bg_color = ThemeManager.get_color("elevated")
    
    for label in get_tree().get_nodes_in_group("labels"):
        label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
```

## Font Scaling

```gdscript
# Set global font scale
ThemeManager.set_scale_factor(1.25)  # 125% scaling

# Listen for scale changes
ThemeManager.scale_changed.connect(_on_scale_changed)

func _on_scale_changed(scale_factor: float) -> void:
    print("Font scale changed to: ", scale_factor)
    _update_font_sizes()
```

## Persistence

Theme settings are automatically saved to `user://theme_settings.cfg` when changed.

```gdscript
# Save current settings manually
var settings = ThemeManager.save_settings()
# Returns: { "theme_variant": 0, "scale_factor": 1.0, "high_contrast": false, "reduced_animation": false }

# Load settings manually
ThemeManager.load_settings(settings)
```

Settings are automatically loaded on startup (`_ready()`).

## Accessibility Features

```gdscript
# Enable high contrast mode
ThemeManager.set_high_contrast(true)

# Enable reduced animation mode
ThemeManager.set_reduced_animation(true)

# Listen for accessibility changes
ThemeManager.accessibility_changed.connect(_on_accessibility_changed)

func _on_accessibility_changed(settings: Dictionary) -> void:
    if settings.high_contrast:
        # Increase border thickness, use stronger shadows, etc.
        pass
    
    if settings.reduced_animation:
        # Disable or speed up animations
        pass
```

## Theme Color Palettes

### Dark Theme (Default - Deep Space)
Matches `BaseCampaignPanel` constants for backward compatibility.

```
Background: #0a0d14 (very dark blue-black)
Elevated:   #111827 (dark gray)
Accent:     #3b82f6 (bright blue)
Text:       #f3f4f6 (white)
Success:    #10b981 (emerald green)
Warning:    #f59e0b (amber orange)
Danger:     #ef4444 (red)
```

### Light Theme
```
Background: #f5f5f5 (light gray)
Elevated:   #ffffff (white)
Accent:     #2563eb (darker blue for contrast)
Text:       #1f2937 (dark gray)
Success:    #059669 (darker green)
Warning:    #d97706 (darker orange)
Danger:     #dc2626 (darker red)
```

### High Contrast Theme
```
Background: #000000 (pure black)
Elevated:   #1a1a1a (very dark gray)
Border:     #ffffff (white borders for max contrast)
Accent:     #00ffff (cyan)
Focus:      #ffff00 (yellow)
Text:       #ffffff (pure white)
Success:    #00ff00 (bright green)
Warning:    #ffff00 (bright yellow)
Danger:     #ff0000 (bright red)
```

### Colorblind Themes
Both deuteranopia and protanopia themes replace red/green with blue/pink/cyan variants:
- Success: Sky blue or cyan (instead of green)
- Danger: Pink (instead of red)
- Warning: Orange (distinguishable from other colors)

## Creating a Theme Selector UI

```gdscript
# Example: Dropdown menu for theme selection
extends OptionButton

func _ready() -> void:
    add_item("Dark (Deep Space)", ThemeManager.ThemeVariant.DARK)
    add_item("Light", ThemeManager.ThemeVariant.LIGHT)
    add_item("High Contrast", ThemeManager.ThemeVariant.HIGH_CONTRAST)
    add_item("Colorblind (Deuteranopia)", ThemeManager.ThemeVariant.COLORBLIND_DEUTERANOPIA)
    add_item("Colorblind (Protanopia)", ThemeManager.ThemeVariant.COLORBLIND_PROTANOPIA)
    
    # Set current selection
    selected = ThemeManager.get_current_theme()
    
    # Connect selection change
    item_selected.connect(_on_theme_selected)

func _on_theme_selected(index: int) -> void:
    ThemeManager.apply_theme(index as ThemeManager.ThemeVariant)
```

## Best Practices

1. **Always use `ThemeManager.get_color()`** instead of hardcoded colors
2. **Register controls** that need automatic theme updates
3. **Unregister in `_exit_tree()`** to prevent memory leaks
4. **Use semantic color names** ("accent", "success") instead of generic names
5. **Test with all themes** to ensure readability and accessibility
6. **Provide theme selector** in settings menu for user preference

## Migration from Hardcoded Colors

### Before
```gdscript
const COLOR_ACCENT := Color("#3b82f6")
const COLOR_TEXT := Color("#f3f4f6")

func _create_button() -> Button:
    var btn = Button.new()
    btn.modulate = COLOR_ACCENT
    btn.add_theme_color_override("font_color", COLOR_TEXT)
    return btn
```

### After
```gdscript
func _create_button() -> Button:
    var btn = Button.new()
    btn.modulate = ThemeManager.get_color("accent")
    btn.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
    
    # Optional: Register for automatic updates
    ThemeManager.register_control(btn)
    
    return btn
```

## File Locations

- **ThemeManager Script**: `src/ui/themes/ThemeManager.gd`
- **Autoload Registration**: `project.godot` (autoload section)
- **Settings File**: `user://theme_settings.cfg` (auto-generated)
- **Tests**: `tests/unit/test_theme_manager.gd`
- **Documentation**: `docs/THEME_MANAGER_USAGE.md` (this file)
