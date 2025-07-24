# Character Creation

**Last Updated**: July 2025
**Status**: Implemented and Production-Ready

## Overview

The character creation system in the Five Parsecs Campaign Manager is a hybrid system that combines the flexibility of JSON-based data files with the type-safety of Godot's enums. The `FiveParsecsCharacterGeneration` class (`src/core/character/CharacterGeneration.gd`) is the heart of this system.

## Process

The character creation process follows these steps:

1.  **Configuration:** The process starts with a configuration dictionary that specifies the character's name, class, background, motivation, and origin.
2.  **Attribute Generation:** The character's attributes (Reaction, Speed, Combat, Toughness, and Savvy) are generated using the official Five Parsecs formula: 2d6 divided by 3, rounded up.
3.  **Bonuses:** Bonuses from the character's background and class are applied. These bonuses are sourced from the JSON data files, with fallbacks to hardcoded values if the data is unavailable.
4.  **Equipment:** Starting equipment is generated based on the character's origin and background. This data is also sourced from the JSON files.
5.  **Flags:** Character flags are set based on their origin (e.g., `is_human`, `is_bot`).
6.  **Validation:** The final character is validated to ensure it meets the constraints of the Five Parsecs rules.

## Data-Driven Approach

The character creation system is highly data-driven. The `DataManager` loads all character-related data from the following JSON files:

-   `data/character_creation_data.json`
-   `data/character_backgrounds.json`
-   `data/character_skills.json`

This approach allows for easy modification and expansion of character options without requiring changes to the game's code.

## Example Usage

```gdscript
# Create a new character
var config = {
    "name": "Jax",
    "class": "SOLDIER",
    "background": "MILITARY",
    "motivation": "SURVIVAL",
    "origin": "HUMAN"
}
var new_character = FiveParsecsCharacterGeneration.create_character(config)
```
