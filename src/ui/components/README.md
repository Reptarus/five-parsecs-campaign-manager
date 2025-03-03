# UI Components

This directory contains reusable UI components for the Five Parsecs Campaign Manager.

## Directory Structure

- `base/` - Base UI component classes and abstractions
  - `BaseContainer.gd` - Base container class
  - `ResponsiveContainer.gd` - Responsive container base implementation
  - `CampaignResponsiveLayout.gd` - Campaign-specific responsive layout
- `character/` - Character-related UI components
- `combat/` - Combat UI components
  - `log/` - Combat log components
  - `overrides/` - Manual override components
  - `rules/` - House rules components
  - `state/` - State verification components
- `dialogs/` - Dialog windows and popups
- `difficulty/` - Difficulty selection components
- `gesture/` - Touch gesture components
- `grid/` - Grid layout components
- `logbook/` - Logbook and journal components
- `mission/` - Mission UI components
- `options/` - Options and settings components
- `rewards/` - Reward display components
- `tooltip/` - Tooltip and hint components
- `tutorial/` - Tutorial UI components
- `victory/` - Victory condition components

## Root Files

- `ErrorDisplay.gd/tscn` - Error message display component
- Other utility components

## Usage Guidelines

### Component Design

1. Make components self-contained and reusable
2. Implement proper signal connections for event handling
3. Document public methods and signals
4. Keep styling consistent with the game's theme

### Component Integration

When integrating components into screens:

1. Use proper node references and signals
2. Avoid tight coupling between components
3. Follow the established communication patterns

### Responsive Design

All components should support:

1. Different screen sizes and resolutions
2. Both landscape and portrait orientations (where applicable)
3. Mouse/keyboard and touch inputs

## Best Practices

- Inherit from appropriate base classes
- Use consistent naming patterns
- Document component dependencies
- Implement proper focus management for keyboard navigation
- Use the theme system for styling
- Test components on multiple screen sizes and platforms
- Support both mouse/keyboard and touch inputs 