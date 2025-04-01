# UIManager

The UIManager is a central component for managing UI screens, dialogs, and themes in the Five Parsecs Campaign Manager.

## Purpose

The UIManager provides a unified way to:
- Navigate between screens
- Show and hide dialogs
- Manage screen transitions
- Control theme settings
- Handle UI accessibility options

## Usage

### Setup

The UIManager is designed to be used as a node in your scene hierarchy. Typically, it should be added at a high level in your scene tree.

```gdscript
var ui_manager = UIManager.new()
add_child(ui_manager)
```

Alternatively, you can access it through the UIManagerRegistry singleton:

```gdscript
# In your main scene initialization
UIManagerRegistry.register_ui_manager(ui_manager)

# Later, in any script
if UIManagerRegistry.has_ui_manager():
    var ui_manager = UIManagerRegistry.get_ui_manager()
    ui_manager.show_screen("main_menu")
```

### Screen Navigation

```gdscript
# Show a screen
ui_manager.show_screen("main_menu")

# Hide the current screen and return to the previous one
ui_manager.hide_screen()

# Show a screen with a transition effect
ui_manager.show_screen_with_transition("options", 0.3)

# Show a modal screen (previous screen will return when modal is closed)
ui_manager.show_modal("confirmation")

# Hide the modal and return to previous screen
ui_manager.hide_modal()
```

### Dialog Management

```gdscript
# Show a dialog with optional data
ui_manager.show_dialog("save_game", {"filename": "save_01.dat"})

# Hide a specific dialog
ui_manager.hide_dialog("save_game")
```

### Theme Management

First, connect a theme manager:

```gdscript
var theme_manager = ThemeManager.new()
add_child(theme_manager)
ui_manager.connect_theme_manager(theme_manager)
```

Then use the theme functionality:

```gdscript
# Apply a theme
ui_manager.apply_theme("dark")

# Get current theme
var current_theme = ui_manager.get_current_theme()

# Set UI scale
ui_manager.set_ui_scale(1.2)

# Set high contrast mode
ui_manager.set_high_contrast(true)

# Toggle animations
ui_manager.toggle_animations(false)

# Set text size
ui_manager.set_text_size("large")
```

### Settings Persistence

```gdscript
# Save UI settings
ui_manager.save_ui_settings()

# Load UI settings
ui_manager.load_ui_settings()
```

### Cleanup

```gdscript
# Reset all UI manager state
ui_manager.cleanup()
```

## Signals

The UIManager emits these signals:

- `screen_changed(screen_name)` - When a screen changes
- `dialog_opened(dialog_name, dialog_data)` - When a dialog opens
- `dialog_closed(dialog_name)` - When a dialog closes
- `theme_applied(theme_name)` - When a theme is applied

## Integration with Game State

The UIManager is designed to work closely with your game state system. It maintains a history of screens to enable proper back navigation.

## Best Practices

1. Keep screen transitions consistent
2. Use dialogs for temporary information or confirmations
3. Connect to signals for proper UI state updates
4. Use the UIManagerRegistry for global access
5. Implement screen-specific controllers that communicate with the UIManager 