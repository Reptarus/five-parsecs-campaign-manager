# World Generation System Migration Guide

This document explains the transition from the old `WorldGen` system to the new world generation implementation in the Five Parsecs campaign manager.

## Why the Change?

The original `WorldGen` system was designed as a standalone hex-grid based world generator, which didn't align well with the game rules of Five Parsecs From Home. The new implementation:

1. More closely follows the tabletop game rules (pages 80-86)
2. Integrates better with the campaign management systems
3. Focuses on gameplay mechanics rather than visual representation
4. Provides a cleaner, more maintainable API
5. Is easier to extend with new content

## Key Differences

| Feature | Old WorldGen | New World Generator |
|---------|-------------|---------------------|
| Implementation | Standalone scripts in `/WorldGen/` | Core system in `/src/core/campaign/WorldGenerator.gd` |
| World Representation | Hex grid with tiles | Dictionary-based data structure |
| Location System | Tile resources | Location entries with properties |
| Generation Method | Grid-based procedural generation | Rulebook-based procedural generation |
| Integration | Minimal integration with game systems | Fully integrated with campaign manager |
| Data Source | Hardcoded values | JSON data files |

## Migrating Your Code

If you were using the old `WorldGen` system, here's how to update your code:

### 1. Replace Script References

```gdscript
# Old
const World = preload("res://WorldGen/World.gd")
const Generator = preload("res://WorldGen/Generator.gd")
const Grid = preload("res://WorldGen/Grid.gd")
const Tile = preload("res://WorldGen/Tile.gd")
const Region = preload("res://WorldGen/Region.gd")

# New
const WorldGenerator = preload("res://src/core/campaign/WorldGenerator.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")
const GameWorldTrait = preload("res://src/game/world/GameWorldTrait.gd")
```

### 2. Update Node Setup

```gdscript
# Old
var world = World.new()
var generator = world.generator
var grid = generator.grid

# New
var world_generator = WorldGenerator.new()
add_child(world_generator)
```

### 3. Update World Generation Code

```gdscript
# Old
var region = generator.generate_region(5, 5)
var tiles = region.get_tiles()

# New
var world_data = world_generator.generate_world(campaign_turn)
var locations = world_data.locations
```

### 4. Update Location Access

```gdscript
# Old
for tile in tiles:
    print("Tile at " + str(tile.position) + ": " + tile.tile_name)
    
# New
for location in world_data.locations:
    print("Location: " + location.name + " - " + location.description)
```

### 5. Connect Signals

```gdscript
# Old
generator.connect("region_generated", _on_region_generated)
world.connect("tile_selected", _on_tile_selected)

# New
world_generator.connect("world_generated", _on_world_generated)
world_generator.connect("location_discovered", _on_location_discovered)
```

## WorldGenerator API

The new `WorldGenerator` class provides the following key methods:

```gdscript
# Generate a new world
var world_data = world_generator.generate_world(campaign_turn)

# Discover a location (when exploring)
var location = world_generator.discover_location(world_data, location_index)

# Get available planet types
var planet_types = world_generator.get_planet_types()

# Set specific generation parameters
world_generator.set_danger_level_modifier(1)
world_generator.set_specific_planet_type("JUNGLE_WORLD", true)
```

## Data Structure

The new world data structure is a Dictionary with the following format:

```gdscript
{
    "id": "world_123456789",
    "name": "Alpha Prime",
    "type": "JUNGLE_WORLD",
    "type_name": "Jungle World",
    "danger_level": 3,
    "traits": ["dense_vegetation", "exotic_flora"],
    "locations": [
        {
            "id": "loc_123456_789",
            "type": "outpost",
            "name": "Fort Haven",
            "description": "A small outpost nestled in the jungle.",
            "danger_mod": 1,
            "resources": 30,
            "explored": false,
            "special_features": ["hidden_cache"]
        },
        # More locations...
    ],
    "special_features": ["high_biodiversity"],
    "discovered_on_turn": 5,
    "visited_locations": [],
    "resources_extracted": 0,
    "mission_count": 0,
    "has_patron": false
}
```

## Example Implementation

See the example in `Example/world.tscn` for a working demonstration of the new world generation system, including:

1. The WorldGenerator node setup
2. UI for displaying world information
3. Usage of the API for generating worlds and exploring locations
4. Signal handling for world events

## JSON Data Files

The world generator uses the following data files:

- `data/planet_types.json` - Planet types and their properties
- `data/location_types.json` - Location types and their features
- `data/world_traits.json` - Special traits for planets

You can extend the system by adding new entries to these files.

## Getting Help

If you have questions about migrating from the old system or implementing the new one, please refer to:

1. The examples in `Example/`
2. The code documentation in `src/core/campaign/WorldGenerator.gd`
3. The Five Parsecs rulebook for the underlying game mechanics 