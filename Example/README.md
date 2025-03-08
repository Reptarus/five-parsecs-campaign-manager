# Five Parsecs From Home - World Generation System

This folder contains examples of how to use the new world generation system in the Five Parsecs From Home campaign manager.

## Overview

The world generation system follows the rules from the Five Parsecs From Home rulebook (pages 80-86) and creates procedurally generated worlds with the following features:

- Random planet types with appropriate names and descriptions
- Danger levels that scale with campaign progress
- World traits that affect gameplay and resources
- Multiple locations to explore within each world
- Special features that can be discovered during exploration

## How to Use

The main implementation is in `src/core/campaign/WorldGenerator.gd`, which provides a clean API for generating worlds and discovering locations.

### Basic Usage

```gdscript
# Get a reference to the WorldGenerator
var world_generator = $WorldGenerator

# Generate a new world (passing the current campaign turn)
var world_data = world_generator.generate_world(campaign_turn)

# Access world information
print("Planet: " + world_data.name)
print("Type: " + world_data.type_name)
print("Danger Level: " + str(world_data.danger_level))

# Access locations
for i in range(world_data.locations.size()):
    var location = world_data.locations[i]
    print("Location " + str(i) + ": " + location.name)
    
# Discover a location (when players explore it)
var location_index = 0 # First location
var discovered_location = world_generator.discover_location(world_data, location_index)
```

### Integration with Game Systems

The world generator is designed to work with the wider campaign management systems:

1. When starting a new campaign turn, generate a new world
2. Present the world information to the player
3. Let the player choose which locations to explore
4. Use the discovered locations as the basis for missions
5. Track which locations have been explored using the `explored` flag

## JSON Data Files

The world generator uses the following JSON files for data:

- `data/planet_types.json` - Defines the types of planets and their properties
- `data/location_types.json` - Defines the types of locations found on planets
- `data/world_traits.json` - Defines the special traits planets can have

## Example Scene

This directory contains an example scene (`world.tscn`) that demonstrates how to use the world generator. It shows:

1. Basic setup of the WorldGenerator node
2. A simple UI for displaying world information
3. How to generate new worlds and explore locations
4. Signal connections to respond to world generation and exploration events

## Migrating from the Legacy World Generator

If you were using the old WorldGen system, here's how to migrate to the new implementation:

1. Replace references to `WorldGen/World.gd` with `src/core/campaign/WorldGenerator.gd`
2. Instead of using the Grid and Generator nodes, use the WorldGenerator's API directly
3. Replace Tile resources with the new location system
4. Update any code that was assuming the old hex-based grid system

The new system is more focused on the gameplay aspects of world generation rather than visual representation, making it easier to integrate with the campaign management systems.

## Extending the System

You can extend the world generation system in several ways:

1. Add new planet types in the planet_types.json file
2. Create new location types in the location_types.json file
3. Add new world traits in the world_traits.json file
4. Modify the WorldGenerator.gd script to add new generation methods

For more complex extensions, consider subclassing WorldGenerator or creating a wrapper class that adds your specific functionality. 