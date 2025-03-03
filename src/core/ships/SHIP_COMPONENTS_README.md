# Ship Components System

## Overview
This directory contains all ship component classes for the Five Parsecs Campaign Manager. These components represent various systems that can be installed on ships in the game.

## Core Components

- `ShipComponent.gd` - Base class for all ship components
- `MedicalBayComponent.gd` - Medical facilities for treating crew members
- `WeaponsComponent.gd` - Weapons systems for combat
- `EngineComponent.gd` - Engines for ship propulsion
- `HullComponent.gd` - Hull reinforcement and protection

## Usage Guidelines

1. **Loading Components**
   ```gdscript
   # Correct way to load ship components
   const ShipComponentScript = preload("res://src/core/ships/components/ShipComponent.gd")
   const MedicalBayScript = preload("res://src/core/ships/components/MedicalBayComponent.gd")
   ```

2. **Instantiating Components**
   ```gdscript
   # Create a ship component
   var component = load("res://src/core/ships/components/ShipComponent.gd").new()
   
   # Or use an already preloaded constant
   var medical_bay = MedicalBayScript.new()
   ```

3. **Serialization**
   Always use the deserialize method from the same component class:
   ```gdscript
   # Correct way to deserialize
   var ship_component = load("res://src/core/ships/components/ShipComponent.gd")
   var component_data = ship_component.deserialize(data)
   ```

## Notes on Component Design

1. The ship component system implements Five Parsecs from Home mechanics including:
   - Component quality levels
   - Wear and tear
   - Tech levels
   - Scavenged parts

2. **Maintenance System**: Components track wear level (0-5) which affects efficiency. Regular maintenance can reset wear.

3. **Upgrade System**: Components can be upgraded up to their max_level, improving efficiency and capabilities.

## Development History

Previously, duplicate component files existed in `src/game/ships/components/` which were consolidated on March 3, 2024 to avoid confusion and maintain a single source of truth for ship components.

### Consolidation Details

1. **Files Removed**:
   - `src/game/ships/components/ShipComponent.gd`
   - `src/game/ships/components/MedicalBayComponent.gd`
   - `src/game/ships/components/WeaponsComponent.gd`

2. **Reasons for Consolidation**:
   - The core components had more feature-rich implementations
   - The core components were already referenced in tests and other code
   - Having duplicate component sets caused confusion and maintenance overhead
   - Core components better aligned with Five Parsecs from Home mechanics

3. **Class Name Resolution**:
   - Removed `class_name` declarations from component files to prevent global conflicts
   - Updated serialization and deserialization to use path loading instead of class names

These changes were made as part of the Phase 3: Code Architecture Refinement initiative in the project action plan. 