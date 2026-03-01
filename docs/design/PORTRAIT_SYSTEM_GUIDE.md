# Character Portrait System Guide

## Overview

The Five Parsecs Campaign Manager includes a comprehensive portrait system for importing, exporting, and managing character portraits. This system provides:

- **Image Import**: Support for PNG, JPG, JPEG files
- **Automatic Processing**: Resizing, validation, and optimization
- **Persistent Storage**: Portraits saved to `user://portraits/` directory
- **Fallback System**: Default portraits based on character class
- **Error Handling**: Comprehensive validation and error messages

## How to Use

### 1. **Importing Portraits**

#### Via CharacterCreator
1. Open the CharacterCreator screen
2. Click the portrait preview area or "Select Portrait" button
3. Choose a PNG, JPG, or JPEG file (max 10MB)
4. The image will be automatically processed and displayed

#### Via PortraitSelector Component
```gdscript
var portrait_selector = PortraitSelector.new()
portrait_selector.portrait_selected.connect(_on_portrait_selected)
add_child(portrait_selector)
```

### 2. **Exporting Portraits**

Portraits are automatically exported when:
- Creating a new character
- Saving character data
- The portrait is assigned to a character

**Export Location**: `user://portraits/`
**File Naming**: `{character_name}_portrait_{timestamp}.png`

### 3. **Loading Existing Portraits**

```gdscript
var portrait_manager = PortraitManager.new()
var texture = portrait_manager.load_portrait_from_path(character.portrait_path)
if texture:
    portrait_display.texture = texture
```

## Technical Details

### File Requirements

| Requirement | Value |
|-------------|-------|
| **Formats** | PNG, JPG, JPEG |
| **Max Size** | 10MB |
| **Min Dimensions** | 64x64 pixels |
| **Max Dimensions** | 512x512 pixels (auto-resized) |
| **Storage** | `user://portraits/` |

### Image Processing

1. **Validation**: File format, size, and dimensions checked
2. **Resizing**: Large images automatically resized to 512x512
3. **Optimization**: Converted to PNG format for consistency
4. **Storage**: Saved with timestamp and character name

### Error Handling

The system provides clear error messages for:
- Invalid file formats
- Files too large (>10MB)
- Images too small (<64x64)
- Failed loading/saving operations
- Missing files

## Components

### PortraitManager
**Location**: `src/utils/PortraitManager.gd`

Core utility class for portrait operations:
- `import_portrait(file_path)` - Import and process image
- `export_portrait(texture, character_name)` - Export to user directory
- `load_portrait_from_path(path)` - Load existing portrait
- `get_default_portrait(character_class)` - Get class-based default

### PortraitSelector
**Location**: `src/ui/components/PortraitSelector.gd`

Reusable UI component for portrait selection:
- File dialog integration
- Preview display
- Error handling
- Clear functionality

### CharacterCreator Integration
**Location**: `src/ui/screens/character/CharacterCreator.gd`

Enhanced character creation with portrait support:
- Portrait selection during character creation
- Automatic export on character creation
- Preview in character creation UI

## Usage Examples

### Basic Portrait Import
```gdscript
var portrait_manager = PortraitManager.new()
var texture = portrait_manager.import_portrait("path/to/image.png")
if texture:
    character_portrait.texture = texture
```

### Portrait Export
```gdscript
var export_path = portrait_manager.export_portrait(texture, "Captain Smith")
if not export_path.is_empty():
    character.portrait_path = export_path
```

### Using PortraitSelector
```gdscript
var selector = PortraitSelector.new()
selector.portrait_selected.connect(func(path): print("Selected: ", path))
add_child(selector)
```

## File Structure

```
user://portraits/
├── captain_smith_portrait_2024-01-15_14-30-25.png
├── medic_jones_portrait_2024-01-15_14-35-10.png
└── scout_wilson_portrait_2024-01-15_14-40-15.png
```

## Best Practices

1. **Image Quality**: Use high-quality images (512x512 recommended)
2. **File Size**: Keep files under 10MB for performance
3. **Naming**: Use descriptive character names for easy identification
4. **Backup**: Important portraits should be backed up externally
5. **Cleanup**: Old portraits are automatically cleaned up after 30 days

## Troubleshooting

### Common Issues

**"Invalid portrait file"**
- Check file format (PNG, JPG, JPEG only)
- Verify file size is under 10MB
- Ensure image dimensions are at least 64x64

**"Failed to load portrait"**
- Check file path is correct
- Verify file exists and is accessible
- Try a different image file

**"Portrait not displaying"**
- Check character.portrait_path is set
- Verify file exists in user://portraits/
- Use fallback portrait system

### Debug Information

Enable debug logging:
```gdscript
# In PortraitManager
print("PortraitManager: Processing image: ", file_path)
print("PortraitManager: Exporting to: ", export_path)
```

## Integration with Existing Systems

The portrait system integrates with:
- **Character Creation**: Automatic portrait assignment
- **Character Display**: Portrait rendering in UI components
- **Save/Load System**: Portrait persistence with character data
- **Campaign Management**: Portrait display in crew lists

## Future Enhancements

Planned features:
- Portrait editing tools
- Multiple portrait support per character
- Portrait templates and presets
- Cloud storage integration
- Portrait sharing between campaigns 