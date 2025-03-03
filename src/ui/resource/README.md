# UI Resource Components

This directory contains UI components for displaying and managing in-game resources in the Five Parsecs Campaign Manager.

## Components

- `ResourceDisplay.gd/tscn` - Main resource display component for showing multiple resources
- `ResourceItem.gd/tscn` - Individual resource item display

## Usage

The resource components are used to display various types of in-game resources, including:

- Credits
- Story points
- Equipment resources
- Crafting materials
- Special resources

## Integration

To integrate these components into a screen:

1. Instance the `ResourceDisplay` scene
2. Connect it to the appropriate data source
3. Configure it for the specific resource types needed

## Resource Types

Resources are defined in the core data system and include:

- Basic resources (credits, story points)
- Advanced resources (salvage, tech components)
- Special resources (faction tokens, quest items)

## Styling

All resource displays follow the Five Parsecs visual style, with:

- Appropriate icons for each resource type
- Color coding for different resource categories
- Animations for resource changes
- Tooltips for additional information

## Best Practices

- Update resource displays efficiently to avoid performance issues
- Provide visual feedback for resource changes
- Group related resources together
- Use consistent styling across all resource displays
- Ensure resources are clearly visible on all screen sizes and platforms 