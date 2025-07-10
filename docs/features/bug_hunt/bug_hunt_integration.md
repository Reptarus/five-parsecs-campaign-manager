# Bug Hunt Integration (Compendium DLC)

## Overview
This document outlines the strategy for integrating "Bug Hunt," a standalone military-themed variant of Five Parsecs From Home, into our digital campaign manager. The goal is to leverage existing codebase components to optimize development time while providing a distinct gameplay experience. This content is part of a paid DLC and must be gated accordingly.

## Core Concept: Separate Game Mode with Shared Assets
Bug Hunt should be implemented as a distinct game mode accessible from the main menu or a new campaign type. This allows for its unique rules and gameplay loop without heavily modifying the core Five Parsecs campaign structure. Maximum reuse of existing systems is paramount.

## Features to Integrate:
- **Bug Hunt Core Rules**: Implement the specific ruleset for Bug Hunt missions and combat.
- **Character Transfer System**: Allow characters to move between the main Five Parsecs campaign and Bug Hunt.
- **Military Equipment**: Introduce specialized military gear (weapons, armor, items).
- **Squad-Based Mechanics**: Adapt the game to handle larger squad sizes and different command structures.
- **Battlefield Generation**: Implement specific map generation rules for Bug Hunt scenarios.

## Integration Strategy & Reusable Components:

### 1. Game Mode Selection / Entry Point
- **Reuse**: Existing UI elements for campaign selection.
- **Implementation**: Add a new button or option on the main menu or campaign creation screen to launch a "Bug Hunt Campaign." This would trigger a different campaign initialization flow.

### 2. Character System
- **Reuse**: `src/core/character/Base/Character.gd` as the base for all units (both player and enemy).
- **Implementation**: 
    - **Character Transfer**: Implement serialization/deserialization methods in `Character.gd` (if not already robust) to allow saving/loading character data. A dedicated `CharacterTransferManager.gd` could handle the import/export process, ensuring compatibility between game modes.
    - **Bug Hunt Specific Stats/Traits**: Extend `Character.gd` or create a `BugHuntCharacter.gd` (inheriting from `Character`) to add any Bug Hunt-specific attributes or traits. This should be minimal, preferring to use existing `special_abilities` or `characteristics` arrays.

### 3. Equipment System
- **Reuse**: `src/core/systems/WeaponSystem.gd`, `src/core/data/GameDataManager.gd` (for loading JSON data).
- **Implementation**: 
    - **New Data Files**: Create new JSON files for military equipment (e.g., `data/bug_hunt_weapons.json`, `data/bug_hunt_armor.json`).
    - **GameDataManager Integration**: Update `GameDataManager.gd` to load these new data files. 
    - **Weapon/Armor Classes**: Ensure existing `Weapon` and `Armor` resource classes can handle the new military-themed properties. If not, extend them or create `BugHuntWeapon.gd` / `BugHuntArmor.gd`.

### 4. Enemy System (Bugs!)
- **Reuse**: `src/core/enemy/base/Enemy.gd`, `src/core/systems/EnemyGenerator.gd`, `src/core/data/GameDataManager.gd`.
- **Implementation**: 
    - **New Enemy Types**: Create new entries in `data/enemy_types.json` (or a new `data/bug_hunt_enemies.json`) for the "bugs" and other military adversaries.
    - **Enemy Generator**: Adapt `EnemyGenerator.gd` to generate Bug Hunt-specific enemy compositions. This might involve new `EnemyCategory` or `EnemyType` enums in `GlobalEnums.gd`.
    - **AI Variations**: The existing `AIVariationsManager.gd` can be extended to include new AI behaviors specific to bug-like enemies (e.g., swarm tactics, burrowing).

### 5. Mission System
- **Reuse**: `src/core/systems/Mission.gd` as the base class.
- **Implementation**: 
    - **New Mission Types**: Create `BugHuntMission.gd` (inheriting from `Mission`) for the unique mission structures of Bug Hunt.
    - **Mission Generator**: Implement a `BugHuntMissionGenerator.gd` that creates missions based on Bug Hunt rules (e.g., objective types, deployment zones, environmental hazards).
    - **Gameplay Loop**: The core campaign loop (`CampaignPhaseManager.gd`) would need to branch to a `BugHuntCampaignManager.gd` that handles the specific phases and events of a Bug Hunt campaign (e.g., different upkeep, story, battle phases).

### 6. Combat System
- **Reuse**: `src/core/systems/CombatManager.gd`, `src/core/systems/DiceSystem.gd`, `src/core/managers/EnemyAIManager.gd`.
- **Implementation**: 
    - **Squad-Based Mechanics**: This is the most complex part. It might require modifications to `CombatManager.gd` to handle larger numbers of units, different initiative rules for squads, and potentially new UI for squad command.
    - **AI Adaptation**: `EnemyAIManager.gd` would need to be updated to handle the new bug AI behaviors and potentially player squad AI if applicable.
    - **New Combat Rules**: Implement any specific Bug Hunt combat rules (e.g., new damage types, environmental effects) within the `CombatResolver.gd` or as new `BattleEvent` types.

### 7. Battlefield Generation & Setup
- **Reuse**: Existing `TerrainGeneration.gd` (if available) or `BattlefieldSetupAssistant.gd`.
- **Implementation**: 
    - **Bug Hunt Specific Tables**: Create new terrain tables (e.g., `data/bug_hunt_terrain_tables.json`) for generating Bug Hunt environments (e.g., alien hives, derelict ships, military bunkers).
    - **Terrain Generation Logic**: Adapt or extend the existing `TerrainGeneration.gd` (or create a `BugHuntTerrainGenerator.gd`) to use these new tables. This would involve rules for placing obstacles, cover, and unique Bug Hunt features (e.g., bug nests, chokepoints).
    - **Deployment Zones**: Define specific deployment zones for both player squads and enemy bugs, potentially different from standard Five Parsecs missions.
    - **Points of Interest**: Implement Bug Hunt-specific points of interest (e.g., resource caches, communication relays, bug tunnels) and their associated interactions.
    - **Grid-Based Movement**: If Bug Hunt utilizes a more strict grid-based movement, ensure the battlefield setup and unit movement systems (`CombatManager.gd`, `Character.gd`) are compatible or adapted.

## DLC Gating:
Bug Hunt is a Compendium DLC feature. Access to this game mode and its content must be gated.

### Recommended Gating Mechanism:
1.  **Feature Flag**: Use the `DLCManager.is_dlc_owned("compendium")` check.
2.  **Main Menu/Campaign Selection**: The option to start a "Bug Hunt Campaign" should be disabled or hidden if the Compendium DLC is not owned. A clear message indicating the DLC requirement should be displayed.
3.  **Content Loading**: Ensure that Bug Hunt-specific data files (equipment, enemies, missions, terrain) are only loaded if the DLC is active.
4.  **Character Transfer**: The character transfer functionality should only be available if the DLC is owned.

### Example (Conceptual GDScript in MainMenu.gd):
```gdscript
func _on_start_bug_hunt_button_pressed():
    if DLCManager.is_dlc_owned("compendium"):
        # Transition to Bug Hunt campaign creation/selection screen
        get_tree().change_scene_to_file("res://scenes/bug_hunt_campaign_setup.tscn")
    else:
        display_dlc_locked_message("Bug Hunt requires the Compendium DLC. Purchase it to unlock this game mode!")
        # Optionally, show a link to the store page
```

## Development Optimization & Reuse Checklist:
- [ ] **Character**: Can `Character.gd` be extended, or is a new `BugHuntCharacter.gd` necessary? Prioritize extension.
- [ ] **Weapons/Armor**: Can existing `Weapon` and `Armor` resources handle new military types, or are new classes needed? Prioritize existing.
- [ ] **Enemy Data**: Can new bug types be added to `enemy_types.json` or is a separate `bug_hunt_enemies.json` better for modularity?
- [ ] **AI**: Can `EnemyAIManager.gd` be extended with new behaviors, or does Bug Hunt need a completely separate AI system? Prioritize extension.
- [ ] **Missions**: Can `Mission.gd` be extended, or is a new `BugHuntMission.gd` necessary? Prioritize extension.
- [ ] **Managers**: Can existing managers (`CombatManager`, `CampaignPhaseManager`) be extended with conditional logic, or are new `BugHuntCombatManager`/`BugHuntCampaignManager` needed? Prioritize extension with conditional logic where possible.
- [ ] **Terrain**: Can `TerrainGeneration.gd` be extended to use new Bug Hunt tables, or is a new `BugHuntTerrainGenerator.gd` necessary? Prioritize extension.

## Testing:
- **Unit Tests**: For all new Bug Hunt-specific classes and methods.
- **Integration Tests**: Verify the full Bug Hunt gameplay loop, from character transfer to mission completion and rewards. Test interactions between new military gear and combat rules. Ensure proper enemy generation and AI behavior.
- **Battlefield Generation Tests**: Verify that Bug Hunt maps are generated correctly with appropriate terrain, deployment zones, and points of interest.
- **DLC Gating Tests**: Crucially, verify that the Bug Hunt game mode is inaccessible when the DLC is not owned.

## Dependencies:
- `src/core/data/GameDataManager.gd`
- `src/core/systems/GlobalEnums.gd`
- `src/core/character/Base/Character.gd`
- `src/core/systems/DiceSystem.gd`
- `src/core/systems/WeaponSystem.gd`
- `src/core/systems/Mission.gd`
- `src/core/systems/CombatManager.gd`
- `src/core/managers/EnemyAIManager.gd`
- `src/core/campaign/CampaignPhaseManager.gd`
- `src/core/systems/DLCManager.gd` (for DLC gating)
- `src/core/world/TerrainGeneration.gd` (if exists)