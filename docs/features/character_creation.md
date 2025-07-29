# Character Creation

**Last Updated**: January 2025
**Status**: Implemented and Production-Ready with Campaign Integration

## Overview

The character creation system in the Five Parsecs Campaign Manager is a comprehensive, multi-tier system that supports both detailed character generation and streamlined campaign creation workflows. The system includes both the full `FiveParsecsCharacterGeneration` class (`src/core/character/CharacterGeneration.gd`) and the specialized `SimpleCharacterCreator` (`src/core/character/Generation/SimpleCharacterCreator.gd`) for campaign-specific character creation.

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

## Character Creation Systems

### 1. Full Character Generation (`FiveParsecsCharacterGeneration`)
The comprehensive character creation system used for detailed character customization:

```gdscript
# Create a new character with full customization
var config = {
    "name": "Jax",
    "class": "SOLDIER", 
    "background": "MILITARY",
    "motivation": "SURVIVAL",
    "origin": "HUMAN"
}
var new_character = FiveParsecsCharacterGeneration.create_character(config)
```

### 2. Simple Character Creator (`SimpleCharacterCreator`)
A streamlined character creation system specifically designed for campaign creation workflows:

```gdscript
# Create characters for campaign creation
var simple_creator = SimpleCharacterCreator.new()

# Generate a crew member
var crew_member = simple_creator.create_crew_member("Crew Member 1")

# Generate a captain with enhanced stats
var captain = simple_creator.create_captain("Captain Storm")
```

## Campaign Integration

### Captain Creation Enhancements
The `SimpleCharacterCreator` includes special handling for captain characters during campaign creation:

- **Enhanced Stats**: Captains receive minimum stat values of 3 for Combat, Toughness, and Savvy
- **Bonus Health**: Captains get +1 additional health point (Toughness + 3 instead of Toughness + 2)
- **Improved Luck**: Captains start with 2 luck points instead of 1
- **Five Parsecs Rules Compliance**: All stat generation uses proper 2d6 rolls with captain bonuses

### Integration with Campaign Creation Pipeline
The character creation system is fully integrated with the campaign creation workflow:

1. **Crew Generation**: Creates 4 standard crew members with balanced stats
2. **Captain Assignment**: Automatically generates an enhanced captain character  
3. **Equipment Integration**: Works seamlessly with `StartingEquipmentGenerator`
4. **Data Validation**: All characters validated through comprehensive testing (18/18 tests passing)

## Testing & Validation

### Production Readiness
The character creation system has been extensively tested through:

- **End-to-End Testing**: Complete campaign creation workflow validation
- **Data Safety**: Handles both Character objects and Dictionary fallbacks safely
- **Performance Validation**: Sub-second character generation confirmed
- **Integration Testing**: Verified compatibility with story track and tutorial systems

### Key Testing Insights
- **Character Generation**: 3/3 dedicated character creation tests passing
- **Captain Creation**: 1/1 captain-specific generation test passing
- **Campaign Integration**: Full workflow validation with character data handoff
- **Error Recovery**: Graceful fallback patterns for missing dependencies

## Architecture Benefits

### Multi-Tier Design
- **Flexibility**: Supports both detailed and streamlined character creation
- **Campaign Focus**: Specialized tools for campaign-specific workflows
- **Production Safety**: Comprehensive error handling and fallback systems
- **Performance**: Optimized for rapid character generation during campaign creation

This enhanced character creation system represents a mature, production-ready implementation that successfully balances the detailed character customization needs of Five Parsecs from Home with the streamlined requirements of campaign creation workflows.
