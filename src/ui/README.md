# Five Parsecs Campaign Manager UI

This directory contains all user interface components for the Five Parsecs Campaign Manager.

## Directory Structure

- `components/` - Reusable UI components used across multiple screens
  - `base/` - Base UI component classes
  - `character/` - Character-related UI components
  - `combat/` - Combat UI components
  - `mission/` - Mission UI components
  - `tutorial/` - Tutorial UI components 
  - and others...
- `screens/` - Full application screens
  - `campaign/` - Campaign screens and panels
  - `battle/` - Battle screens
  - `mainmenu/` - Main menu screens
  - and others...
- `resource/` - Resource display and UI resource components
- `themes/` - UI themes and styling resources

## Root TSCN Files

The `.tscn` files in the root directory are being migrated to their proper locations in the subdirectories. 
**DO NOT ADD NEW FILES TO THIS DIRECTORY**.

## Organization Guidelines

1. **File Placement**:
   - Place all new UI components in the appropriate subdirectory
   - Follow the established directory structure

2. **Component Reuse**:
   - Utilize components from the `components/` directory when building screens
   - Avoid duplicating functionality

3. **Naming Conventions**:
   - Use PascalCase for scene files (.tscn) and GDScript class files (.gd)
   - Use snake_case for resource files (.tres, .res)

4. **Documentation**:
   - Document public methods, signals, and important functionality
   - Add README files to document complex components or subsystems

## UI Manager

The UI system uses the `UIManager` class (found in `screens/UIManager.gd`) to manage screen transitions and UI state. All screens should register with and be managed by this class.

## Responsive Design

The UI is designed to be responsive and work on multiple platforms and screen sizes. Use the responsive container components in `components/base/` to ensure your UI adapts correctly.

## Theme Customization

Use the theme resources in the `themes/` directory for consistent styling. Custom controls should follow the established visual style. 