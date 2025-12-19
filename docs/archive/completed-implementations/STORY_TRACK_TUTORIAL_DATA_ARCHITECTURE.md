# Story Track Tutorial Mission Data Architecture
**Analysis Date**: 2025-12-16
**Version**: 1.0
**Status**: Architectural Proposal

## Executive Summary

This document provides a complete data architecture for implementing Story Track tutorial missions as a vertical slice, analyzing:

1. **Story Track Data Model** - Pre-configured tutorial missions with fixed parameters
2. **Curated vs Random Differentiation** - Schema to support both tutorial and procedural modes
3. **Save/Load for Tutorials** - Separate tutorial progress tracking with checkpoint/rollback
4. **Migration Path** - Converting tutorial campaign to procedural campaign
5. **JSON Schema Design** - Concrete data structures for `data/story_track_missions.json`

---

## 1. Story Track Data Model

### 1.1 Resource Structure

Based on existing patterns (`Campaign.gd`, `Mission.gd`, `StoryTrackSystem.gd`), the Story Track tutorial should use a dedicated Resource class:

```gdscript
# src/core/story/TutorialMissionData.gd
@tool
extends Resource
class_name TutorialMissionData

## Schema version for save file migration
@export var schema_version: int = 1

## Core Tutorial Properties
@export var tutorial_id: String = ""  # "tutorial_01_first_contact"
@export var sequence_number: int = 0  # Position in tutorial campaign (0-5)
@export var mission_title: String = ""
@export var mission_description: String = ""
@export var tutorial_objectives: Array[String] = []  # Learning goals for player

## Fixed Battle Parameters (No Procedural Generation)
@export var fixed_enemy_types: Array[String] = ["Gangers", "Gang_Lieutenant"]
@export var fixed_enemy_count: int = 6
@export var fixed_deployment_pattern: String = "standard"  # From deployment_conditions.json
@export var fixed_terrain_type: String = "industrial_ruins"
@export var fixed_battlefield_size: Vector2i = Vector2i(24, 24)

## Fixed Starting Conditions
@export var starting_crew_templates: Array[Dictionary] = []  # Pre-configured crew stats
@export var starting_equipment_loadout: Array[Dictionary] = []  # Specific weapons/gear
@export var starting_credits: int = 1000
@export var starting_story_points: int = 2

## Tutorial Progression Gates
@export var completion_requirements: Dictionary = {
    "objectives_completed": [],  # ["move_character", "make_attack", "use_cover"]
    "enemies_defeated": 0,
    "turns_limit": 10,
    "crew_survival_required": true
}

## Tutorial Guidance
@export var tutorial_hints: Array[Dictionary] = []  # In-battle tutorial popups
@export var companion_tools_enabled: Array[String] = []  # ["dice_tracker", "keyword_tooltips"]
@export var restricted_mechanics: Array[String] = []  # Mechanics disabled for this mission

## Milestone Checkpoints
@export var checkpoint_data: Array[Dictionary] = []  # Saved game states at key moments

## Rewards and Unlocks
@export var fixed_rewards: Dictionary = {
    "credits": 500,
    "reputation": 1,
    "story_points": 1,
    "unlocks_mission": "tutorial_02_patrol"
}
```

### 1.2 Story Track Campaign Resource

Tutorial campaigns need separate tracking from procedural campaigns:

```gdscript
# src/core/story/TutorialCampaignData.gd
@tool
extends Resource
class_name TutorialCampaignData

@export var schema_version: int = 1

## Tutorial Campaign Properties
@export var tutorial_campaign_id: String = "story_track_tutorial"
@export var campaign_name: String = "Story Track: First Steps"
@export var total_tutorial_missions: int = 6
@export var current_mission_index: int = 0

## Tutorial Progress Tracking
@export var completed_missions: Array[String] = []  # Mission IDs
@export var mechanics_learned: Array[String] = []  # ["movement", "combat", "cover"]
@export var tutorial_state: String = "active"  # active, paused, completed, abandoned

## Persistent Tutorial Data (Carries Between Missions)
@export var tutorial_crew: Array[Dictionary] = []  # Same crew across all 6 missions
@export var tutorial_ship: Dictionary = {}  # Same ship, persistent damage/upgrades
@export var accumulated_credits: int = 1000
@export var accumulated_reputation: int = 0
@export var accumulated_story_points: int = 2

## Checkpoint System
@export var active_checkpoints: Dictionary = {}  # {mission_id: {turn: int, state: Dictionary}}
@export var last_checkpoint_timestamp: String = ""

## Conversion Readiness
@export var ready_for_procedural: bool = false
@export var conversion_validation: Dictionary = {}
```

---

## 2. Curated vs Random Differentiation

### 2.1 Mission Source Discrimination

Add a `mission_source` enum to distinguish mission generation method:

```gdscript
# In Mission.gd (extend existing enum)
enum MissionSource {
    TUTORIAL_CURATED,      # Fixed tutorial mission from story_track_missions.json
    STORY_TRACK_SCRIPTED,  # Scripted story event (existing StoryTrackSystem)
    PROCEDURAL_PATRON,     # Generated patron job
    PROCEDURAL_OPPORTUNITY, # Generated opportunity mission
    PROCEDURAL_QUEST       # Generated quest mission
}

@export var mission_source: MissionSource = MissionSource.PROCEDURAL_PATRON
```

### 2.2 Data Schema for Both Modes

**Tutorial Mode (Fixed)**:
```json
{
  "mission_id": "tutorial_01_first_contact",
  "mission_source": "TUTORIAL_CURATED",
  "procedural_override": {
    "disable_random_generation": true,
    "use_fixed_parameters": true
  },
  "fixed_data": {
    "enemies": ["Gangers", "Gang_Lieutenant"],
    "terrain": "industrial_ruins",
    "deployment": "standard"
  }
}
```

**Procedural Mode (Random)**:
```json
{
  "mission_id": "patrol_job_12345",
  "mission_source": "PROCEDURAL_PATRON",
  "procedural_generation": {
    "enemy_table": "core_enemies",
    "terrain_table": "frontier_worlds",
    "deployment_table": "deployment_conditions"
  }
}
```

### 2.3 Conditional Generation Logic

```gdscript
# In BattlefieldGenerator.gd
func generate_battlefield(mission: Mission) -> BattlefieldData:
    if mission.mission_source == Mission.MissionSource.TUTORIAL_CURATED:
        return _generate_fixed_battlefield(mission.fixed_data)
    else:
        return _generate_procedural_battlefield(mission.procedural_generation)
```

---

## 3. Save/Load for Tutorials

### 3.1 Separate Save File Strategy

**Rationale**: Tutorial progress should not corrupt main campaign saves, and tutorials need frequent checkpoint/rollback functionality.

**File Structure**:
```
user://saves/
  ├── campaigns/
  │   ├── main_campaign_001.json      # Procedural campaigns
  │   └── mercenary_campaign_002.json
  ├── tutorials/
  │   ├── story_track_active.json     # Active tutorial progress
  │   ├── story_track_checkpoints.json # Tutorial checkpoints
  │   └── story_track_completed.json  # Completed tutorial (for reference)
```

### 3.2 Tutorial Save Schema

```json
{
  "save_type": "tutorial_campaign",
  "schema_version": 1,
  "tutorial_data": {
    "tutorial_campaign_id": "story_track_tutorial",
    "campaign_name": "Story Track: First Steps",
    "current_mission_index": 2,
    "completed_missions": [
      "tutorial_01_first_contact",
      "tutorial_02_patrol"
    ],
    "mechanics_learned": [
      "movement",
      "combat",
      "cover",
      "reactions"
    ],
    "tutorial_state": "active"
  },
  "persistent_campaign_state": {
    "crew": [
      {
        "character_id": "tutorial_captain_001",
        "character_name": "Captain Ryder",
        "background": "MILITARY",
        "combat": 2,
        "reactions": 1,
        "current_health": 5,
        "max_health": 5,
        "equipment": ["Infantry Laser", "Frag Grenade"]
      }
    ],
    "ship": {
      "ship_name": "Tutorial Freighter",
      "hull_points": 8,
      "fuel_units": 6
    },
    "resources": {
      "credits": 1500,
      "reputation": 2,
      "story_points": 3
    }
  },
  "checkpoint_system": {
    "checkpoints": [
      {
        "checkpoint_id": "tutorial_02_turn_3",
        "mission_id": "tutorial_02_patrol",
        "turn_number": 3,
        "timestamp": "2025-12-16T10:30:00Z",
        "battlefield_state": {
          "crew_positions": [...],
          "enemy_positions": [...],
          "terrain_state": [...]
        }
      }
    ],
    "autosave_enabled": true,
    "last_autosave": "2025-12-16T10:35:00Z"
  },
  "metadata": {
    "created_at": "2025-12-16T10:00:00Z",
    "last_saved": "2025-12-16T10:35:00Z",
    "play_time_minutes": 45,
    "tutorial_version": "1.0"
  }
}
```

### 3.3 Checkpoint/Rollback System

```gdscript
# src/core/story/TutorialCheckpointManager.gd
class_name TutorialCheckpointManager
extends RefCounted

## Maximum checkpoints per tutorial mission
const MAX_CHECKPOINTS_PER_MISSION: int = 5

## Checkpoint triggers
enum CheckpointTrigger {
    TURN_START,        # Every N turns (configurable)
    OBJECTIVE_COMPLETE, # When tutorial objective completed
    MANUAL,            # Player-initiated checkpoint
    PRE_CRITICAL       # Before risky action (enemy reinforcements, etc.)
}

func create_checkpoint(mission_id: String, trigger: CheckpointTrigger) -> Dictionary:
    var checkpoint := {
        "checkpoint_id": _generate_checkpoint_id(mission_id),
        "mission_id": mission_id,
        "trigger": CheckpointTrigger.keys()[trigger],
        "timestamp": Time.get_datetime_string_from_system(),
        "campaign_state": _serialize_campaign_state(),
        "battlefield_state": _serialize_battlefield_state()
    }

    _save_checkpoint(checkpoint)
    return checkpoint

func rollback_to_checkpoint(checkpoint_id: String) -> bool:
    var checkpoint: Dictionary = _load_checkpoint(checkpoint_id)
    if checkpoint.is_empty():
        return false

    _restore_campaign_state(checkpoint.campaign_state)
    _restore_battlefield_state(checkpoint.battlefield_state)
    return true
```

### 3.4 "Restart Tutorial" Functionality

```gdscript
func restart_tutorial_mission(mission_id: String) -> void:
    # Load mission template from data/story_track_missions.json
    var mission_template: Dictionary = _load_tutorial_mission_template(mission_id)

    # Reset campaign state to mission start conditions
    tutorial_campaign.accumulated_credits = mission_template.starting_credits
    tutorial_campaign.tutorial_crew = mission_template.starting_crew_templates.duplicate(true)

    # Clear in-mission checkpoints
    _clear_mission_checkpoints(mission_id)

    # Restart battle with fixed parameters
    _start_fixed_battle(mission_template)
```

---

## 4. Migration Path: Tutorial → Procedural Campaign

### 4.1 Migration Requirements

When player completes Story Track tutorial and wants to continue into procedural campaign:

**Data Validation Checks**:
1. Tutorial campaign state = "completed"
2. All 6 tutorial missions completed
3. Crew has valid stats (no tutorial-only buffs)
4. Equipment is legal for procedural campaign
5. Credits/reputation within normal ranges

### 4.2 Migration Schema

```gdscript
# src/core/story/TutorialMigrationService.gd
class_name TutorialMigrationService
extends RefCounted

## Migration validation result
class MigrationValidation:
    var is_valid: bool = false
    var errors: Array[String] = []
    var warnings: Array[String] = []
    var converted_data: Dictionary = {}

func validate_tutorial_for_migration(tutorial_campaign: TutorialCampaignData) -> MigrationValidation:
    var validation := MigrationValidation.new()

    # Check 1: Tutorial completion
    if tutorial_campaign.tutorial_state != "completed":
        validation.errors.append("Tutorial campaign not completed")
        return validation

    # Check 2: Crew validation
    for crew_member in tutorial_campaign.tutorial_crew:
        if not _is_valid_procedural_character(crew_member):
            validation.errors.append("Invalid crew member: %s" % crew_member.character_name)

    # Check 3: Equipment validation
    for crew_member in tutorial_campaign.tutorial_crew:
        for equipment_id in crew_member.get("equipment", []):
            if not _is_legal_equipment(equipment_id):
                validation.errors.append("Illegal equipment: %s" % equipment_id)

    # Check 4: Resources validation
    if tutorial_campaign.accumulated_credits < 0:
        validation.errors.append("Negative credits")

    validation.is_valid = validation.errors.is_empty()
    return validation

func convert_tutorial_to_procedural(tutorial_campaign: TutorialCampaignData) -> FiveParsecsCampaign:
    # Validate first
    var validation := validate_tutorial_for_migration(tutorial_campaign)
    if not validation.is_valid:
        push_error("Cannot migrate tutorial: %s" % str(validation.errors))
        return null

    # Create new procedural campaign
    var procedural_campaign := FiveParsecsCampaign.new()

    # Transfer basic properties
    procedural_campaign.campaign_name = tutorial_campaign.campaign_name + " (Continued)"
    procedural_campaign.use_story_track = false  # Disable tutorial mode

    # Transfer crew (with deep copy to prevent reference issues)
    for crew_data in tutorial_campaign.tutorial_crew:
        var character := Character.new()
        character.from_dictionary(crew_data)
        procedural_campaign.crew_members.append(character)

    # Transfer ship (with tutorial-specific modifications removed)
    var ship_data := _sanitize_tutorial_ship(tutorial_campaign.tutorial_ship)
    procedural_campaign.settings["ship"] = ship_data

    # Transfer resources
    procedural_campaign.credits = tutorial_campaign.accumulated_credits
    procedural_campaign.starting_reputation = tutorial_campaign.accumulated_reputation
    procedural_campaign.story_points = tutorial_campaign.accumulated_story_points

    # Set campaign phase to World Phase (start of normal turn loop)
    procedural_campaign.current_phase = GlobalEnums.CampaignPhase.WORLD
    procedural_campaign.campaign_turn = 1  # Reset turn counter

    return procedural_campaign
```

### 4.3 Data Transformations During Migration

**Crew Data**:
- Remove tutorial-only stat buffs (e.g., "tutorial_invincibility")
- Normalize XP to valid range (0-100 per advancement tier)
- Validate equipment against equipment_database.json

**Ship Data**:
- Remove tutorial-specific hull damage immunity
- Reset fuel/supplies to standard starting amounts
- Validate ship upgrades against ship_components.json

**Resources**:
- Cap credits at 5000 (prevent tutorial credit exploit)
- Normalize reputation to 0-5 range (tutorial may grant inflated reputation)
- Convert tutorial story points to standard story points

---

## 5. JSON Schema Design: `data/story_track_missions.json`

### 5.1 Complete Tutorial Mission Definition

```json
{
  "version": "1.0",
  "description": "Story Track Tutorial Missions - Fixed, balanced encounters for learning game mechanics",
  "tutorial_campaign": {
    "campaign_id": "story_track_tutorial",
    "campaign_name": "Story Track: First Steps",
    "description": "A 6-mission tutorial campaign introducing core Five Parsecs mechanics",
    "total_missions": 6,
    "estimated_playtime_minutes": 90,
    "completion_unlocks": ["procedural_campaign_mode", "achievement_tutorial_complete"]
  },
  "missions": [
    {
      "tutorial_id": "tutorial_01_first_contact",
      "sequence_number": 0,
      "mission_title": "First Contact",
      "mission_description": "Your crew's first encounter with hostile forces. Learn basic movement and combat.",
      "tutorial_objectives": [
        "Move all crew members using tactical movement",
        "Use cover to protect crew from enemy fire",
        "Defeat at least 3 enemies",
        "Complete battle with all crew surviving"
      ],

      "fixed_battle_parameters": {
        "battlefield": {
          "size": {"x": 24, "y": 24},
          "terrain_type": "industrial_ruins",
          "terrain_density": 0.3,
          "cover_positions": [
            {"position": {"x": 8, "y": 12}, "type": "full_cover"},
            {"position": {"x": 16, "y": 12}, "type": "partial_cover"},
            {"position": {"x": 12, "y": 8}, "type": "full_cover"}
          ]
        },
        "enemies": [
          {
            "enemy_type": "Gangers",
            "count": 5,
            "deployment_pattern": "scattered",
            "deployment_positions": [
              {"x": 20, "y": 18},
              {"x": 22, "y": 16},
              {"x": 18, "y": 20},
              {"x": 21, "y": 14},
              {"x": 19, "y": 17}
            ],
            "fixed_stats": {
              "combat": 0,
              "reactions": 1,
              "speed": 4,
              "toughness": 3,
              "ai_type": "aggressive"
            }
          },
          {
            "enemy_type": "Gang_Lieutenant",
            "count": 1,
            "deployment_positions": [{"x": 21, "y": 19}],
            "fixed_stats": {
              "combat": 1,
              "reactions": 1,
              "speed": 4,
              "toughness": 4,
              "ai_type": "tactical"
            }
          }
        ],
        "deployment_condition": "standard",
        "notable_sights": [],
        "battle_events": []
      },

      "starting_conditions": {
        "crew_templates": [
          {
            "character_id": "tutorial_captain_001",
            "character_name": "Captain Ryder",
            "background": "MILITARY",
            "motivation": "SURVIVAL",
            "origin": "HUMAN",
            "stats": {
              "combat": 2,
              "reactions": 1,
              "speed": 4,
              "toughness": 3,
              "savvy": 1,
              "luck": 0
            },
            "equipment": ["Infantry Laser", "Frag Grenade"],
            "special_abilities": [],
            "xp": 0
          },
          {
            "character_id": "tutorial_crew_002",
            "character_name": "Doc Martinez",
            "background": "COLONIST",
            "motivation": "WEALTH",
            "origin": "HUMAN",
            "stats": {
              "combat": 0,
              "reactions": 1,
              "speed": 4,
              "toughness": 3,
              "savvy": 2,
              "luck": 0
            },
            "equipment": ["Auto Rifle", "Medkit"],
            "special_abilities": ["field_medic"],
            "xp": 0
          },
          {
            "character_id": "tutorial_crew_003",
            "character_name": "Crash",
            "background": "ENGINEER",
            "motivation": "CURIOSITY",
            "origin": "HUMAN",
            "stats": {
              "combat": 1,
              "reactions": 1,
              "speed": 4,
              "toughness": 3,
              "savvy": 1,
              "luck": 0
            },
            "equipment": ["Hand Cannon", "Repair Kit"],
            "special_abilities": ["tech_savvy"],
            "xp": 0
          }
        ],
        "starting_credits": 1000,
        "starting_story_points": 2,
        "starting_reputation": 0,
        "ship_template": {
          "ship_name": "Tutorial Freighter",
          "ship_class": "BASIC_SHIP",
          "hull_points": 8,
          "max_hull_points": 8,
          "fuel_units": 6,
          "cargo_capacity": 12,
          "crew_quarters": 4
        }
      },

      "tutorial_guidance": {
        "pre_battle_briefing": "Welcome to your first battle! In this mission, you'll learn the basics of movement and combat. Pay attention to cover positions and use them to protect your crew.",
        "tutorial_hints": [
          {
            "trigger": "turn_start",
            "turn_number": 1,
            "hint_text": "Click a crew member to select them, then click a valid position to move. Movement is measured in inches (tabletop scale).",
            "highlight_ui": ["crew_panel", "battlefield_grid"]
          },
          {
            "trigger": "enemy_shoots",
            "hint_text": "Enemies are shooting at you! Use cover to reduce incoming damage. Full cover (solid objects) is better than partial cover.",
            "highlight_ui": ["cover_indicators"]
          },
          {
            "trigger": "first_attack",
            "hint_text": "Great! To attack, select your weapon and click an enemy in range. Combat skill affects your chance to hit.",
            "highlight_ui": ["weapon_panel", "attack_button"]
          }
        ],
        "companion_tools_enabled": [
          "dice_tracker",
          "keyword_tooltips",
          "tactical_overlay"
        ],
        "restricted_mechanics": [
          "story_point_spending",
          "advanced_reactions",
          "psionic_powers"
        ]
      },

      "completion_requirements": {
        "objectives_completed": [
          "move_all_crew",
          "use_cover",
          "defeat_3_enemies"
        ],
        "enemies_defeated_min": 3,
        "turns_limit": 15,
        "crew_survival_required": true,
        "optional_objectives": [
          "defeat_all_enemies",
          "complete_in_10_turns",
          "no_crew_injuries"
        ]
      },

      "fixed_rewards": {
        "credits": 500,
        "reputation": 1,
        "story_points": 1,
        "xp_per_crew": 1,
        "loot_rolls": 0,
        "unlocks_mission": "tutorial_02_patrol"
      },

      "checkpoint_triggers": [
        {"trigger_type": "turn_start", "turn_number": 3},
        {"trigger_type": "objective_complete", "objective": "use_cover"},
        {"trigger_type": "enemy_count", "count": 3}
      ],

      "failure_conditions": {
        "crew_deaths_allowed": 0,
        "turns_exceeded": 15,
        "retreat_available": true
      },

      "post_battle_summary": {
        "narrative_text": "Your crew handled their first hostile encounter well. The gang scattered after losing their lieutenant, but this won't be the last time you cross paths with such threats.",
        "mechanics_learned": ["movement", "combat", "cover"],
        "next_mission_preview": "Next mission: Patrol - Learn about holding objectives and tactical positioning."
      }
    }
  ]
}
```

### 5.2 Mission Template Structure (Abbreviated for Missions 2-6)

```json
{
  "missions": [
    {
      "tutorial_id": "tutorial_02_patrol",
      "mission_title": "Patrol Duty",
      "tutorial_objectives": ["Hold center objective for 3 turns", "Use Brawling in close combat"],
      "mechanics_focus": ["objective_holding", "close_combat"]
    },
    {
      "tutorial_id": "tutorial_03_rescue",
      "mission_title": "Rescue Operation",
      "tutorial_objectives": ["Extract civilian from battlefield", "Use suppressive fire"],
      "mechanics_focus": ["escort_missions", "suppression"]
    },
    {
      "tutorial_id": "tutorial_04_defend",
      "mission_title": "Defensive Stand",
      "tutorial_objectives": ["Defend position against waves", "Use grenades effectively"],
      "mechanics_focus": ["defensive_tactics", "explosives"]
    },
    {
      "tutorial_id": "tutorial_05_stealth",
      "mission_title": "Covert Operation",
      "tutorial_objectives": ["Complete mission without being detected", "Use stealth mechanics"],
      "mechanics_focus": ["stealth", "detection"]
    },
    {
      "tutorial_id": "tutorial_06_boss",
      "mission_title": "Final Confrontation",
      "tutorial_objectives": ["Defeat boss enemy", "Use advanced tactics"],
      "mechanics_focus": ["boss_fights", "all_mechanics_combined"]
    }
  ]
}
```

---

## 6. Integration with Existing Systems

### 6.1 Campaign Creation Flow

```gdscript
# In CampaignCreationStateManager.gd
func select_campaign_mode(mode: String) -> void:
    match mode:
        "tutorial":
            campaign_data.config.campaign_type = "story_track_tutorial"
            campaign_data.config.story_track = "tutorial_campaign"
            campaign_data.config.tutorial_mode = "guided"
            _load_tutorial_campaign_template()
        "procedural":
            campaign_data.config.campaign_type = "standard"
            campaign_data.config.story_track = ""
            campaign_data.config.tutorial_mode = "none"
```

### 6.2 Battle System Integration

```gdscript
# In BattlePhase.gd
func start_battle(mission: Mission) -> void:
    if mission.mission_source == Mission.MissionSource.TUTORIAL_CURATED:
        _start_tutorial_battle(mission)
    else:
        _start_procedural_battle(mission)

func _start_tutorial_battle(mission: Mission) -> void:
    # Load fixed tutorial mission data
    var tutorial_data: TutorialMissionData = _load_tutorial_mission(mission.mission_id)

    # Generate battlefield with fixed parameters
    var battlefield := BattlefieldGenerator.generate_fixed_battlefield(tutorial_data)

    # Deploy crew at fixed positions
    _deploy_fixed_crew(tutorial_data.starting_crew_templates)

    # Deploy enemies at fixed positions
    _deploy_fixed_enemies(tutorial_data.fixed_enemy_types, tutorial_data.fixed_deployment_pattern)

    # Enable tutorial UI overlays
    _enable_tutorial_hints(tutorial_data.tutorial_hints)

    # Start battle loop with tutorial checkpoints enabled
    _start_battle_loop(tutorial_data)
```

### 6.3 Save/Load Integration

```gdscript
# In GameStateManager.gd
func save_campaign(campaign: FiveParsecsCampaign, file_name: String) -> bool:
    var save_path: String

    # Determine save location based on campaign type
    if campaign.use_story_track and campaign.settings.get("tutorial_mode") == "guided":
        save_path = "user://saves/tutorials/" + file_name
    else:
        save_path = "user://saves/campaigns/" + file_name

    # Serialize with appropriate schema
    var save_data: Dictionary = campaign.serialize()
    save_data["save_type"] = "tutorial_campaign" if campaign.use_story_track else "procedural_campaign"

    return _write_save_file(save_path, save_data)
```

---

## 7. Production Implementation Checklist

### Phase 1: Data Layer (Week 1)
- [ ] Create `TutorialMissionData.gd` Resource class
- [ ] Create `TutorialCampaignData.gd` Resource class
- [ ] Create `data/story_track_missions.json` with 6 tutorial missions
- [ ] Extend `Mission.gd` with `MissionSource` enum
- [ ] Add `mission_source` discrimination to `BattlefieldGenerator.gd`

### Phase 2: Save/Load System (Week 2)
- [ ] Create `TutorialCheckpointManager.gd`
- [ ] Implement separate tutorial save file path logic
- [ ] Add checkpoint creation/rollback functionality
- [ ] Implement "restart tutorial mission" feature
- [ ] Add tutorial save file validation

### Phase 3: Migration System (Week 3)
- [ ] Create `TutorialMigrationService.gd`
- [ ] Implement tutorial completion validation
- [ ] Implement tutorial → procedural conversion
- [ ] Add data sanitization for migrated crew/ship
- [ ] Create migration UI (confirmation dialog)

### Phase 4: Integration & Testing (Week 4)
- [ ] Integrate tutorial mode into `CampaignCreationUI.gd`
- [ ] Add tutorial battle flow to `BattlePhase.gd`
- [ ] Implement tutorial hints/overlays in `TacticalBattleUI.gd`
- [ ] Write unit tests for tutorial data loading
- [ ] Write integration tests for tutorial → procedural migration
- [ ] Playtesting: 6-mission tutorial campaign end-to-end

---

## 8. Data Integrity Safeguards

### 8.1 Schema Versioning

All tutorial Resources must include `schema_version: int` for future migrations:

```gdscript
# Migration example: v1 → v2
func migrate_tutorial_save_v1_to_v2(save_data: Dictionary) -> Dictionary:
    if save_data.get("schema_version", 0) < 2:
        # Add new fields introduced in v2
        save_data["checkpoint_system"] = {
            "checkpoints": [],
            "autosave_enabled": true
        }
        save_data["schema_version"] = 2
    return save_data
```

### 8.2 Validation Layers

**Load-Time Validation**:
- Required fields present (mission_id, crew, equipment)
- Crew stats within valid ranges
- Equipment IDs exist in equipment_database.json

**Runtime Validation**:
- Tutorial objectives achievable (no impossible win conditions)
- Checkpoint data not corrupted
- Conversion validation before migration

---

## 9. Performance Considerations

### 9.1 Tutorial Data Caching

```gdscript
# Cache tutorial mission templates at startup
var _tutorial_mission_cache: Dictionary = {}

func _load_tutorial_mission_template(mission_id: String) -> TutorialMissionData:
    if _tutorial_mission_cache.has(mission_id):
        return _tutorial_mission_cache[mission_id]

    var data: TutorialMissionData = _load_from_json(mission_id)
    _tutorial_mission_cache[mission_id] = data
    return data
```

### 9.2 Checkpoint Compression

For large battlefield states, compress checkpoint data:

```gdscript
func _serialize_battlefield_state() -> PackedByteArray:
    var state_dict: Dictionary = _capture_battlefield_state()
    var json_string: String = JSON.stringify(state_dict)
    return json_string.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
```

---

## 10. Conclusion

This data architecture provides:

1. **Clear Separation**: Tutorial missions distinct from procedural missions via `MissionSource` enum
2. **Robust Persistence**: Separate tutorial save files with checkpoint/rollback
3. **Smooth Migration**: Validated conversion from tutorial → procedural campaign
4. **Extensibility**: Schema versioning for future tutorial content additions
5. **Data Integrity**: Multiple validation layers prevent save corruption

**Next Steps**: Implement Phase 1 (Data Layer) and validate JSON schema with actual tutorial mission content.

**Files to Create**:
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/story/TutorialMissionData.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/story/TutorialCampaignData.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/story/TutorialCheckpointManager.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/story/TutorialMigrationService.gd`
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/data/story_track_missions.json`

**Files to Modify**:
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/systems/Mission.gd` (add `MissionSource` enum)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/battle/BattlefieldGenerator.gd` (add fixed battlefield generation)
- `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/managers/GameStateManager.gd` (add tutorial save paths)
