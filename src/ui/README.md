# Five Parsecs Campaign Manager UI System

This directory contains the UI components and systems for the Five Parsecs Campaign Manager application. The UI system has been enhanced to leverage Godot 4.4's improved theme capabilities, responsive design, and accessibility features.

## Directory Structure

- `components/`: Reusable UI components
- `dialogs/`: Dialog windows and popups
- `screens/`: Main application screens
- `themes/`: Theme resources and theme management

## Key Components

### Theme System

The theme system provides a centralized way to manage application themes, including:

- Multiple theme variants (Default, Dark, Light, High Contrast)
- Dynamic theme switching
- UI scaling
- Accessibility features (high contrast mode, reduced animations)

Key files:
- `themes/ThemeManager.gd`: Central manager for theme handling
- `themes/base_theme.tres`: Base theme resource
- `themes/dark_theme.tres`: Dark theme variant
- `themes/light_theme.tres`: Light theme variant
- `themes/high_contrast_theme.tres`: High contrast theme for accessibility

### UI Manager

The UI Manager coordinates all UI components and screens, handling:

- Screen transitions
- Dialog management
- HUD updates
- Theme application
- Responsive UI adjustments

Key files:
- `screens/UIManager.gd`: Main UI coordination
- `dialogs/SettingsDialog.gd`: Settings dialog for theme and accessibility options

### Responsive Components

The UI system includes components that automatically adapt to different screen sizes and device capabilities:

- `components/base/ResponsiveContainer.gd`: A unified responsive container that adapts to screen size and orientation. It provides both width-based layout switching (horizontal/vertical) and aspect ratio-based orientation detection (portrait/landscape).

### Responsive Layout

The `ResponsiveContainer` provides a unified solution for responsive UI layouts:

```gdscript
var container = ResponsiveContainer.new()
container.min_width_for_horizontal = 800 # Breakpoint width for layout switching
container.portrait_threshold = 1.0 # Width/height ratio threshold for orientation detection

# Monitor layout changes
container.layout_changed.connect(func(is_compact):
    print("Layout changed to: %s" % ("compact" if is_compact else "expanded"))
)

# Monitor orientation changes
container.orientation_changed.connect(func(is_portrait):
    print("Orientation changed to: %s" % ("portrait" if is_portrait else "landscape"))
)
```

The consolidated implementation supports both layout modes and orientation detection in a single component:

1. **Layout Mode** (horizontal vs vertical arrangement of children)
   - Controlled by `min_width_for_horizontal` and `responsive_mode`
   - Triggers `layout_changed` signal
   - Access with `is_compact_layout()` or `is_compact` property

2. **Orientation Detection** (portrait vs landscape screen orientation)
   - Controlled by `portrait_threshold` property 
   - Triggers `orientation_changed` signal
   - Access with `get_current_orientation()` or `is_portrait` property

## Usage Examples

### Applying Themes

```gdscript
# Get the theme manager
var theme_manager = get_node("/root/ThemeManager")

# Change the theme
theme_manager.apply_theme_variant(ThemeManager.ThemeVariant.DARK)

# Adjust scale
theme_manager.set_scale_factor(1.2)

# Enable accessibility features
theme_manager.set_high_contrast_mode(true)
theme_manager.set_reduced_animation_mode(true)
```

### Using Responsive Containers

```gdscript
# Create a responsive container
var container = ResponsiveContainer.new()
container.min_width_for_horizontal = 800
container.register_with_ui_manager()

# Add children
var button1 = Button.new()
var button2 = Button.new()
container.add_child(button1)
container.add_child(button2)

# Listen for layout changes
container.layout_changed.connect(func(is_compact):
    print("Layout changed to: " + ("compact" if is_compact else "expanded"))
)
```

### Opening Settings Dialog

```gdscript
# Get the UI manager
var ui_manager = get_node("/root/UIManager")

# Show settings dialog
ui_manager.show_settings()
```

## Accessibility Features

The UI system includes several accessibility features:

1. **High Contrast Mode**: Enhances visibility with stronger contrast and larger text
2. **UI Scaling**: Allows users to adjust the size of UI elements
3. **Reduced Animation**: Minimizes animations for users sensitive to motion
4. **Keyboard Navigation**: Improved focus handling for keyboard-only navigation

## Godot 4.4 Enhancements

This UI system leverages several Godot 4.4 features:

- Enhanced theme property system
- Improved font handling
- Better control over UI scaling
- More efficient UI updates with batched processing
- Improved signal connections with type annotations 