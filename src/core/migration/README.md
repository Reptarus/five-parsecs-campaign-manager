# World Data Migration Guide

This document explains the migration process from the old enum-based world data system to the new JSON-based system.

## Overview

The Five Parsecs Campaign Manager is transitioning from an enum-based data system to a more flexible JSON-based system. This migration affects several key components:

1. **Planet Classes**:
   - Old: `FiveParsecsPlanet` (src/core/world/Planet.gd)
   - New: `GamePlanet` (src/game/world/GamePlanet.gd)

2. **Location Classes**:
   - Old: `FiveParsecsLocation` (src/core/world/Location.gd)
   - New: `GameLocation` (src/game/world/GameLocation.gd)

3. **World Traits**:
   - Old: Enum-based world features in `GameEnums.WorldTrait`
   - New: JSON-defined traits in `data/world_traits.json`

4. **Resources**:
   - Old: Enum-based resource types
   - New: JSON-defined resources in `data/resources.json`

## Compatibility Approach

To ensure a smooth transition, we've implemented a compatibility layer:

1. **Wrapper Pattern**: The old classes (`FiveParsecsPlanet` and `FiveParsecsLocation`) now internally use instances of the new classes (`GamePlanet` and `GameLocation`).

2. **Two-Way Synchronization**: Changes to either the old or new class instances are synchronized to maintain consistency.

3. **Migration Utilities**: The `WorldDataMigration` class provides tools to convert between old and new formats.

## Using the Migration Utilities

The `WorldDataMigration` class provides several methods to help with migration:

```gdscript
# Create a migration utility
var migration = WorldDataMigration.new()

# Check if data needs migration
if migration.needs_migration(saved_data):
    # Migrate the data
    var migrated_data = migration.migrate_world_data(saved_data)
    # Use the migrated data
    load_world(migrated_data)
else:
    # Data is already in the new format
    load_world(saved_data)
```

## Accessing New Functionality

If you need to access new functionality that's only available in the new classes:

```gdscript
# For planets
var old_planet = get_planet() # Returns a FiveParsecsPlanet
var new_planet = old_planet.get_game_planet() # Get the wrapped GamePlanet

# For locations
var old_location = get_location() # Returns a FiveParsecsLocation
var new_location = old_location.get_game_location() # Get the wrapped GameLocation
```

## Data Format Changes

### Planet Types

Old format (enum-based):
```gdscript
planet_type = GameEnums.PlanetType.TEMPERATE
```

New format (string ID-based):
```gdscript
planet_type = "temperate" # References data/planet_types.json
```

### World Traits/Features

Old format (enum-based):
```gdscript
world_features = [GameEnums.WorldTrait.INDUSTRIAL_HUB, GameEnums.WorldTrait.TRADE_CENTER]
```

New format (object-based):
```gdscript
world_traits = [trait1, trait2] # GameWorldTrait objects loaded from data/world_traits.json
```

### Resources

Old format (enum-based):
```gdscript
resources = {
    FiveParsecsLocation.RESOURCE_FUEL: 10,
    FiveParsecsLocation.RESOURCE_SUPPLIES: 5
}
```

New format (string ID-based):
```gdscript
resources = {
    "fuel": 10,
    "supplies": 5
}
```

## Timeline for Full Migration

1. **Phase 1**: Implement compatibility layers (completed)
2. **Phase 2**: Update existing code to use the new classes directly
3. **Phase 3**: Deprecate the old classes
4. **Phase 4**: Remove the old classes and compatibility code

During phases 1-3, both old and new code will work together seamlessly. 