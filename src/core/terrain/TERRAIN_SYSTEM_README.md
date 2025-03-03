# Terrain System

## Overview
This directory contains the terrain system classes for the Five Parsecs Campaign Manager. These components handle terrain generation, effects, and interactions for the battle system.

## Core Components

- `TerrainSystem.gd` - Basic terrain system with grid-based terrain features
- `UnifiedTerrainSystem.gd` - Advanced terrain system with integrated effects
- `TerrainTypes.gd` - Terrain type definitions
- `TerrainRules.gd` - Rules for terrain interactions
- `TerrainEffects.gd` - Effects that terrain can apply to units
- `TerrainLayoutGenerator.gd` - Procedural terrain layout generation

## Usage Guidelines

1. **Loading TerrainSystem**
   ```gdscript
   # Correct way to load terrain systems
   const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")
   const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")
   ```

2. **Instantiating Systems**
   ```gdscript
   # Create a terrain system
   var terrain_system = TerrainSystem.new()
   
   # Create the advanced unified system
   var unified_terrain_system = UnifiedTerrainSystem.new()
   ```

3. **Using Terrain Features**
   ```gdscript
   # Using TerrainFeatureType enum
   terrain_system.set_terrain_feature(position, TerrainSystem.TerrainFeatureType.COVER_HIGH)
   ```

## Which System to Use

1. For simple terrain grid functionality, use the base `TerrainSystem.gd`.
2. For advanced terrain with effects and interactions, use `UnifiedTerrainSystem.gd`.

## Notes on Terrain System Design

1. The terrain system uses a grid-based approach to track terrain features
2. Features can include cover, hazards, and other battlefield elements
3. The unified system adds more advanced features like effects application

## Development History

Previously, duplicate terrain system files existed in:
- `src/game/world/TerrainSystem.gd`
- `src/game/terrain/TerrainSystem.gd`

These were consolidated on March 3, 2024 to avoid confusion and maintain a single source of truth for terrain system code. 