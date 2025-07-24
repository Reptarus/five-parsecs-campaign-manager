# Data Architecture

**Last Updated**: July 2025
**Status**: Implemented and Production-Ready

## Overview

The Five Parsecs Campaign Manager employs a robust, hybrid data architecture that combines the performance and type-safety of Godot's built-in enums with the flexibility and richness of JSON-based data files. This system is managed by the `DataManager` autoload script, which serves as the single source of truth for all game data.

## Data Manager

The `DataManager` (`src/core/data/DataManager.gd`) is a globally accessible autoload script responsible for:

-   **Loading Data:** It loads all game data from JSON files at startup.
-   **Caching:** It caches all data in memory for high-performance access.
-   **Validation:** It validates the integrity of the data and checks for consistency.
-   **Hot-Reloading:** It supports hot-reloading of data in development builds for rapid iteration.
-   **API:** It provides a simple, consistent API for accessing all game data.

## Data Files

All game data is stored in JSON files located in the `data` directory. The `DataManager` loads data from the following files:

-   `data/character_creation_data.json`
-   `data/character_backgrounds.json`
-   `data/weapons.json`
-   `data/armor.json`
-   `data/gear_database.json`
-   `data/mission_templates.json`
-   `data/event_tables.json`
-   `data/campaign_tables/crew_tasks/crew_task_resolution.json`
-   `data/campaign_tables/crew_tasks/trade_results.json`
-   `data/campaign_tables/crew_tasks/exploration_events.json`
-   `data/campaign_tables/crew_tasks/recruitment_opportunities.json`
-   `data/campaign_tables/crew_tasks/training_outcomes.json`

## Data Access

All game data should be accessed through the `DataManager` API. This ensures that data is always accessed in a safe and consistent manner. The API provides methods for retrieving data related to characters, equipment, missions, and more.

## Example Usage

```gdscript
# Get character origin data
var origin_data = DataManager.get_origin_data("HUMAN")

# Get weapon data
var weapon_data = DataManager.get_weapon_data("LASER_PISTOL")

# Get all character backgrounds
var all_backgrounds = DataManager.get_all_backgrounds()
```
