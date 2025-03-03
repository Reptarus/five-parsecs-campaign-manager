# UI Tutorial Components

This directory contains UI components used for the tutorial system in the Five Parsecs Campaign Manager.

## Component Overview

- `TutorialContent.tscn` - Displays tutorial content panels
- `TutorialMain.tscn` - Main tutorial controller scene
- `TutorialOverlay.gd/tscn` - Overlay that highlights UI elements during tutorials
- `TutorialUI.gd/tscn` - Main tutorial UI controller

## Usage

These components should be used when implementing tutorial experiences for new users of the Five Parsecs Campaign Manager. The tutorial system follows a step-by-step approach to guide users through complex game mechanics.

## Integration

To integrate a tutorial in a new screen:

1. Instance the `TutorialUI` scene
2. Create tutorial content using `TutorialContent`
3. Use the `TutorialOverlay` to highlight important UI elements

## Best Practices

- Keep tutorial steps concise and focused
- Use consistent styling across all tutorial content
- Follow the Five Parsecs aesthetic for tutorial visuals
- Ensure tutorials are accessible on all supported platforms 