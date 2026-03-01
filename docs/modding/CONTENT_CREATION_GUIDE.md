# Five Parsecs Campaign Manager - Content Creation Guide

**Version**: 1.0.0  
**Last Updated**: 2025-11  
**For**: Godot 4.6+

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Content Data Formats](#content-data-formats)
4. [Step-by-Step Creation Guides](#step-by-step-creation-guides)
5. [Validation and Testing](#validation-and-testing)
6. [Core vs DLC Content](#core-vs-dlc-content)
7. [Advanced Topics](#advanced-topics)
8. [Troubleshooting](#troubleshooting)
9. [Submission Guidelines](#submission-guidelines)

---

## Introduction

### What is Content Creation?

The Five Parsecs Campaign Manager supports custom content creation through JSON-based data files. You can create:

- **Characters**: New origins, backgrounds, motivations
- **Equipment**: Weapons, armor, gear, consumables
- **Enemies**: New enemy types, elite enemies, bosses
- **Missions**: Custom mission types, objectives, rewards
- **Factions**: New factions with unique characteristics
- **Terrain**: New terrain features, battlefield layouts
- **Events**: Campaign events, world events, battle events

### Who is This Guide For?

- **Modders**: Creating custom content for personal use or community sharing
- **Content Creators**: Building expansions or DLC content
- **Designers**: Testing new game mechanics and balance
- **Contributors**: Adding content to the official game

### Content Types Overview

| Content Type | File Location | Difficulty | Impact |
|--------------|---------------|------------|--------|
| Characters   | `data/characters/` | Easy | Medium |
| Equipment    | `data/equipment/` | Easy | High |
| Enemies      | `data/enemies/` | Medium | High |
| Missions     | `data/missions/` | Medium | High |
| Factions     | `data/factions/` | Medium | Medium |
| Terrain      | `data/terrain/` | Hard | Medium |
| Events       | `data/events/` | Medium | Low |

---

## Getting Started

### Prerequisites

1. **Text Editor**: VS Code, Sublime Text, Notepad++, or any JSON editor
2. **JSON Knowledge**: Basic understanding of JSON syntax
3. **Game Familiarity**: Play the game to understand mechanics
4. **Godot (Optional)**: For testing content in the editor

### Setting Up Your Environment

#### 1. Create a Content Folder

```bash
five-parsecs-campaign-manager/
├── data/
│   ├── custom/           # Your custom content goes here
│   │   ├── characters/
│   │   ├── equipment/
│   │   ├── enemies/
│   │   ├── missions/
│   │   ├── factions/
│   │   ├── terrain/
│   │   └── events/
```

#### 2. Copy Template Files

Template files are provided in `data/templates/`:

```bash
cp data/templates/character_template.json data/custom/characters/my_character.json
```

#### 3. Enable Custom Content

In **Settings** → **Gameplay** → **Content**:
- ✅ Enable Custom Content
- ✅ Load Community Content (optional)
- ✅ Show Content IDs (for debugging)

### File Naming Conventions

- Use **lowercase** with **underscores**: `sniper_rifle.json`
- Use **descriptive names**: `krag_warrior.json` not `char1.json`
- Avoid **special characters**: No spaces, slashes, or symbols
- Use **version suffixes** for iterations: `plasma_rifle_v2.json`

### JSON Syntax Basics

```json
{
  "id": "unique_identifier",
  "name": "Display Name",
  "description": "Detailed description text",
  "stats": {
    "combat_skill": 1,
    "toughness": 4
  },
  "tags": ["tag1", "tag2"],
  "enabled": true
}
```

**Common Mistakes**:
- ❌ Missing commas between properties
- ❌ Trailing commas on last property
- ❌ Unquoted property names
- ❌ Single quotes instead of double quotes

---

## Content Data Formats

### Character Origins

**File**: `data/characters/Bestiary.json` (core) or `data/custom/characters/*.json`

#### Full Format

```json
{
  "origins": [
    {
      "id": "origin_wanderer",
      "name": "Wanderer",
      "description": "A drifter from the fringe worlds, experienced in survival.",
      "base_stats": {
        "reactions": 1,
        "speed": 5,
        "combat_skill": 0,
        "toughness": 4,
        "savvy": 0
      },
      "starting_equipment": [
        "scrap_pistol",
        "worn_armor"
      ],
      "special_rules": [
        {
          "id": "rule_survivor",
          "name": "Survivor",
          "description": "+1 to all Survival rolls",
          "effects": {
            "survival_bonus": 1
          }
        }
      ],
      "background_options": [
        "military",
        "criminal",
        "colonist"
      ],
      "motivation_options": [
        "revenge",
        "wealth",
        "exploration"
      ],
      "xp_cost": 0,
      "rarity": "common",
      "dlc_required": null,
      "enabled": true,
      "tags": ["human", "fringe", "survivor"]
    }
  ]
}
```

#### Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (prefix with `origin_`) |
| `name` | String | Yes | Display name |
| `description` | String | Yes | Flavor text (2-3 sentences) |
| `base_stats` | Object | Yes | Starting stats (see stat ranges below) |
| `starting_equipment` | Array | Yes | Equipment IDs (must exist in equipment data) |
| `special_rules` | Array | No | Unique abilities/bonuses |
| `background_options` | Array | No | Available backgrounds (min 3) |
| `motivation_options` | Array | No | Available motivations (min 3) |
| `xp_cost` | Integer | Yes | XP cost to unlock (0 for starting origins) |
| `rarity` | String | Yes | `common`, `uncommon`, `rare`, `legendary` |
| `dlc_required` | String | No | DLC ID if required, `null` otherwise |
| `enabled` | Boolean | Yes | Whether origin is available |
| `tags` | Array | No | Search/filter tags |

#### Stat Ranges

```json
{
  "reactions": 0-3,      // Initiative bonus
  "speed": 3-7,          // Movement in inches
  "combat_skill": -1-2,  // To-hit bonus
  "toughness": 3-5,      // Damage resistance
  "savvy": -1-2          // Skill check bonus
}
```

**Balance Guidelines**:
- Total stat bonus should be **3-5** for common origins
- High stats in one area require low stats elsewhere
- Speed 5" is standard human baseline
- Toughness 4 is standard human baseline

---

### Equipment Items

**File**: `data/equipment/EquipmentItems.json` (core) or `data/custom/equipment/*.json`

#### Weapon Format

```json
{
  "weapons": [
    {
      "id": "weapon_plasma_rifle",
      "name": "Plasma Rifle",
      "description": "Military-grade energy weapon firing superheated plasma bolts.",
      "type": "weapon",
      "weapon_class": "rifle",
      "range": 24,
      "shots": 1,
      "damage": 1,
      "traits": [
        {
          "id": "trait_piercing",
          "name": "Piercing",
          "description": "Ignores 1 point of armor",
          "value": 1
        }
      ],
      "cost": 15,
      "rarity": "uncommon",
      "weight": 2,
      "hands_required": 2,
      "ammo_type": "energy_cell",
      "ammo_capacity": 20,
      "restrictions": [],
      "dlc_required": null,
      "enabled": true,
      "tags": ["energy", "military", "expensive"]
    }
  ]
}
```

#### Armor Format

```json
{
  "armor": [
    {
      "id": "armor_combat_armor",
      "name": "Combat Armor",
      "description": "Standard military protective gear with trauma plates.",
      "type": "armor",
      "armor_class": "heavy",
      "armor_value": 2,
      "traits": [],
      "cost": 10,
      "rarity": "common",
      "weight": 3,
      "restrictions": ["speed_penalty_-1"],
      "dlc_required": null,
      "enabled": true,
      "tags": ["military", "heavy"]
    }
  ]
}
```

#### Gear Format

```json
{
  "gear": [
    {
      "id": "gear_medkit",
      "name": "Medkit",
      "description": "Field medical supplies for treating injuries.",
      "type": "gear",
      "gear_class": "consumable",
      "uses": 3,
      "effects": [
        {
          "id": "effect_heal",
          "name": "Heal Injury",
          "description": "Remove one injury from a character",
          "trigger": "use",
          "value": 1
        }
      ],
      "cost": 5,
      "rarity": "common",
      "weight": 1,
      "restrictions": [],
      "dlc_required": null,
      "enabled": true,
      "tags": ["medical", "consumable"]
    }
  ]
}
```

#### Equipment Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (prefix: `weapon_`, `armor_`, `gear_`) |
| `name` | String | Yes | Display name |
| `description` | String | Yes | Flavor text |
| `type` | String | Yes | `weapon`, `armor`, `gear` |
| `weapon_class` | String | Weapons | `pistol`, `rifle`, `heavy`, `melee` |
| `armor_class` | String | Armor | `light`, `medium`, `heavy` |
| `gear_class` | String | Gear | `equipment`, `consumable`, `tool` |
| `range` | Integer | Weapons | Range in inches (0 for melee) |
| `shots` | Integer | Weapons | Attacks per turn |
| `damage` | Integer | Weapons | Base damage value |
| `armor_value` | Integer | Armor | Damage reduction |
| `traits` | Array | Optional | Special properties/abilities |
| `cost` | Integer | Yes | Credit cost |
| `rarity` | String | Yes | `common`, `uncommon`, `rare`, `legendary` |
| `weight` | Integer | Yes | Encumbrance (0-5) |
| `restrictions` | Array | Optional | Usage limitations |
| `uses` | Integer | Consumables | Number of uses before depletion |
| `effects` | Array | Gear | Special effects when used |

#### Weapon Traits

```json
"traits": [
  {"id": "trait_piercing", "name": "Piercing", "value": 1},
  {"id": "trait_blast", "name": "Blast", "value": 2},
  {"id": "trait_stun", "name": "Stun", "value": null},
  {"id": "trait_accurate", "name": "Accurate", "value": 1},
  {"id": "trait_unwieldy", "name": "Unwieldy", "value": -1}
]
```

**Common Traits**:
- **Piercing (X)**: Ignore X armor
- **Blast (X)**: Hits all within X inches
- **Stun**: Target loses next turn if hit
- **Accurate (+X)**: +X to hit rolls
- **Unwieldy (-X)**: -X to hit rolls
- **Reliable**: Reroll failed shots once
- **Unstable**: Roll for misfire on natural 1

#### Balance Guidelines

**Weapon Damage vs Cost**:
```
Damage 0: 2-5 credits (holdout pistol)
Damage 1: 5-10 credits (pistol, rifle)
Damage 2: 10-20 credits (military rifle, shotgun)
Damage 3: 20-40 credits (heavy weapons)
```

**Armor Value vs Cost**:
```
Armor 1: 5-8 credits (light armor)
Armor 2: 8-15 credits (combat armor)
Armor 3: 15-25 credits (powered armor)
```

---

### Enemy Types

**File**: `data/enemies/Bestiary.json` (core) or `data/custom/enemies/*.json`

#### Basic Enemy Format

```json
{
  "enemies": [
    {
      "id": "enemy_raider",
      "name": "Raider",
      "description": "Opportunistic bandit preying on frontier settlements.",
      "category": "basic",
      "stats": {
        "reactions": 1,
        "speed": 5,
        "combat_skill": 0,
        "toughness": 4,
        "savvy": 0
      },
      "weapons": [
        {"id": "weapon_scrap_pistol", "probability": 0.6},
        {"id": "weapon_rusty_blade", "probability": 0.4}
      ],
      "armor": [
        {"id": "armor_scrap_vest", "probability": 0.3}
      ],
      "ai_behavior": "aggressive",
      "ai_priority": ["closest", "wounded", "leader"],
      "loot_table": "basic_humanoid",
      "xp_value": 1,
      "panic_threshold": 3,
      "special_rules": [],
      "spawn_weight": 10,
      "difficulty_min": 0,
      "difficulty_max": 2,
      "dlc_required": null,
      "enabled": true,
      "tags": ["humanoid", "raider", "basic"]
    }
  ]
}
```

#### Elite Enemy Format

```json
{
  "elite_enemies": [
    {
      "id": "enemy_raider_boss",
      "name": "Raider Warlord",
      "description": "Ruthless leader of a raider gang, battle-scarred and cunning.",
      "category": "elite",
      "base_enemy": "enemy_raider",
      "stat_modifiers": {
        "reactions": +1,
        "combat_skill": +1,
        "toughness": +1
      },
      "weapons": [
        {"id": "weapon_power_axe", "probability": 1.0}
      ],
      "armor": [
        {"id": "armor_combat_armor", "probability": 0.8}
      ],
      "special_rules": [
        {
          "id": "rule_leader",
          "name": "Gang Leader",
          "description": "All raiders within 6\" get +1 to Morale",
          "aura_range": 6,
          "aura_effect": {"morale": 1}
        }
      ],
      "ai_behavior": "tactical",
      "loot_table": "elite_humanoid",
      "xp_value": 3,
      "spawn_weight": 1,
      "difficulty_min": 2,
      "dlc_required": null,
      "enabled": true,
      "tags": ["humanoid", "raider", "elite", "leader"]
    }
  ]
}
```

#### Enemy Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (prefix: `enemy_`) |
| `name` | String | Yes | Display name |
| `description` | String | Yes | Flavor text |
| `category` | String | Yes | `basic`, `elite`, `boss`, `unique` |
| `base_enemy` | String | Elite only | Base enemy to modify |
| `stats` | Object | Yes | Combat statistics |
| `stat_modifiers` | Object | Elite only | Bonus to base stats |
| `weapons` | Array | Yes | Equipped weapons with probability |
| `armor` | Array | Optional | Equipped armor with probability |
| `ai_behavior` | String | Yes | `passive`, `defensive`, `aggressive`, `tactical` |
| `ai_priority` | Array | Yes | Target selection priority |
| `loot_table` | String | Yes | Loot table ID |
| `xp_value` | Integer | Yes | XP awarded for defeating |
| `panic_threshold` | Integer | Yes | Casualties before morale check |
| `special_rules` | Array | Optional | Unique abilities |
| `spawn_weight` | Integer | Yes | Relative spawn frequency (1-10) |
| `difficulty_min` | Integer | Yes | Minimum campaign difficulty (0-3) |
| `difficulty_max` | Integer | Yes | Maximum campaign difficulty (0-3) |

#### AI Behaviors

```json
"ai_behavior": "aggressive"
```

**Available Behaviors**:
- **passive**: Only attacks if attacked, doesn't pursue
- **defensive**: Guards position, attacks nearby threats
- **aggressive**: Seeks combat, pursues wounded enemies
- **tactical**: Uses cover, focuses fire, coordinates

#### AI Priority

```json
"ai_priority": ["closest", "wounded", "leader"]
```

**Priority Options**:
- `closest`: Nearest target
- `wounded`: Injured characters
- `leader`: Captain/leader character
- `dangerous`: Highest combat skill
- `weakest`: Lowest toughness
- `isolated`: Characters separated from crew

---

### Mission Types

**File**: `data/missions/ExpandedMissions.json` (core) or `data/custom/missions/*.json`

#### Mission Format

```json
{
  "missions": [
    {
      "id": "mission_salvage_operation",
      "name": "Salvage Operation",
      "description": "Recover valuable tech from a derelict facility before raiders arrive.",
      "category": "standard",
      "objectives": [
        {
          "id": "obj_primary_salvage",
          "name": "Recover Salvage",
          "description": "Move a character adjacent to the salvage token and spend 1 turn collecting it",
          "type": "primary",
          "completion_condition": {
            "type": "collect_tokens",
            "token_id": "salvage",
            "count": 3
          },
          "xp_reward": 2,
          "credit_reward": 10
        },
        {
          "id": "obj_secondary_survive",
          "name": "No Casualties",
          "description": "Complete the mission without losing any crew members",
          "type": "secondary",
          "completion_condition": {
            "type": "no_casualties",
            "count": 0
          },
          "xp_reward": 1,
          "credit_reward": 5
        }
      ],
      "enemy_composition": {
        "basic": {"min": 4, "max": 8},
        "elite": {"min": 0, "max": 2}
      },
      "terrain_requirements": {
        "cover_density": "medium",
        "special_features": ["objective_markers_3"]
      },
      "deployment": {
        "crew_zone": "table_edge_south",
        "enemy_zone": "table_edge_north",
        "deployment_rules": []
      },
      "special_rules": [
        {
          "id": "rule_reinforcements",
          "name": "Enemy Reinforcements",
          "description": "Each turn, roll 1D6. On 5+, 1D3 basic enemies arrive at the north edge",
          "trigger": "start_of_turn",
          "effect": {
            "type": "spawn_enemies",
            "probability": 0.33,
            "count": "1d3",
            "enemy_type": "basic",
            "location": "table_edge_north"
          }
        }
      ],
      "difficulty": 2,
      "time_limit": null,
      "patron_required": false,
      "rival_incompatible": true,
      "story_track_required": false,
      "min_crew_size": 3,
      "max_crew_size": 6,
      "dlc_required": null,
      "enabled": true,
      "tags": ["salvage", "timed", "reinforcements"]
    }
  ]
}
```

#### Mission Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (prefix: `mission_`) |
| `name` | String | Yes | Mission title |
| `description` | String | Yes | Mission briefing (2-4 sentences) |
| `category` | String | Yes | `standard`, `opportunity`, `quest`, `rival` |
| `objectives` | Array | Yes | Primary and secondary objectives |
| `enemy_composition` | Object | Yes | Enemy spawn counts by type |
| `terrain_requirements` | Object | Yes | Battlefield setup requirements |
| `deployment` | Object | Yes | Crew and enemy deployment zones |
| `special_rules` | Array | Optional | Mission-specific mechanics |
| `difficulty` | Integer | Yes | Difficulty rating (1-5) |
| `time_limit` | Integer | Optional | Turn limit (null for no limit) |
| `patron_required` | Boolean | Yes | Must have patron to access |
| `rival_incompatible` | Boolean | Yes | Cannot have rival for this mission |
| `story_track_required` | Boolean | Yes | Requires story track enabled |
| `min_crew_size` | Integer | Yes | Minimum crew members |
| `max_crew_size` | Integer | Yes | Maximum crew members |

#### Objective Types

```json
"completion_condition": {
  "type": "collect_tokens",
  "token_id": "salvage",
  "count": 3
}
```

**Available Types**:
- `eliminate_enemies`: Kill X enemies
- `collect_tokens`: Collect X objective tokens
- `reach_location`: Move to specific board location
- `defend_position`: Hold location for X turns
- `escort_npc`: Move NPC to extraction zone
- `no_casualties`: Complete without crew losses
- `time_survived`: Survive for X turns

---

### Faction Data

**File**: `data/factions/Factions.json` (core) or `data/custom/factions/*.json`

#### Faction Format

```json
{
  "factions": [
    {
      "id": "faction_unity",
      "name": "Unity Coalition",
      "short_name": "Unity",
      "description": "The dominant governmental body maintaining order across settled space.",
      "flavor_text": "Unity keeps the peace. Unity protects the innocent. Unity prevails.",
      "alignment": "lawful",
      "hostility_level": 0,
      "initial_standing": 0,
      "standing_ranges": {
        "hostile": -50,
        "unfriendly": -20,
        "neutral": 0,
        "friendly": 20,
        "allied": 50
      },
      "benefits": {
        "friendly": [
          {"type": "discount", "category": "license", "value": 0.25}
        ],
        "allied": [
          {"type": "discount", "category": "military_equipment", "value": 0.15},
          {"type": "mission_access", "mission_types": ["unity_contracts"]}
        ]
      },
      "penalties": {
        "unfriendly": [
          {"type": "license_restriction", "severity": "minor"}
        ],
        "hostile": [
          {"type": "bounty", "value": "1d6x100"},
          {"type": "mission_hostile", "probability": 0.5}
        ]
      },
      "enemy_types": ["unity_trooper", "unity_officer"],
      "patron_types": ["unity_administrator", "unity_commander"],
      "story_hooks": [
        "unity_investigation",
        "unity_escort",
        "unity_artifact_recovery"
      ],
      "color_primary": "#003366",
      "color_secondary": "#FFD700",
      "icon": "res://assets/icons/factions/unity.png",
      "dlc_required": null,
      "enabled": true,
      "tags": ["government", "lawful", "military"]
    }
  ]
}
```

#### Faction Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (prefix: `faction_`) |
| `name` | String | Yes | Full faction name |
| `short_name` | String | Yes | Abbreviated name (for UI) |
| `description` | String | Yes | Faction overview (2-3 sentences) |
| `flavor_text` | String | Yes | Faction motto/slogan |
| `alignment` | String | Yes | `lawful`, `neutral`, `chaotic` |
| `hostility_level` | Integer | Yes | Base hostility (0-5) |
| `initial_standing` | Integer | Yes | Starting reputation |
| `standing_ranges` | Object | Yes | Standing thresholds |
| `benefits` | Object | Yes | Perks at each standing level |
| `penalties` | Object | Yes | Drawbacks at low standing |
| `enemy_types` | Array | Yes | Enemy IDs used by this faction |
| `patron_types` | Array | Yes | Patron IDs from this faction |
| `story_hooks` | Array | Optional | Available quest lines |
| `color_primary` | String | Yes | Primary faction color (hex) |
| `color_secondary` | String | Yes | Secondary faction color (hex) |
| `icon` | String | Yes | Faction icon path |

---

### Terrain Features

**File**: `data/terrain/TerrainTables.json` (core) or `data/custom/terrain/*.json`

#### Terrain Format

```json
{
  "terrain_features": [
    {
      "id": "terrain_rubble_pile",
      "name": "Rubble Pile",
      "description": "Collapsed building debris providing partial cover.",
      "category": "cover",
      "cover_type": "light",
      "cover_value": 1,
      "movement_penalty": "difficult",
      "height": 1,
      "size": {"width": 3, "depth": 3},
      "climbable": false,
      "destructible": false,
      "special_rules": [],
      "spawn_weight": 8,
      "spawn_contexts": ["urban", "industrial", "ruins"],
      "model_path": "res://assets/models/terrain/rubble_pile.tscn",
      "icon": "res://assets/icons/terrain/rubble.png",
      "dlc_required": null,
      "enabled": true,
      "tags": ["cover", "urban", "difficult_terrain"]
    }
  ]
}
```

#### Terrain Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (prefix: `terrain_`) |
| `name` | String | Yes | Feature name |
| `description` | String | Yes | Feature description |
| `category` | String | Yes | `cover`, `obstacle`, `objective`, `decoration` |
| `cover_type` | String | Cover only | `light`, `heavy`, `full` |
| `cover_value` | Integer | Cover only | Penalty to hit (-1 to -3) |
| `movement_penalty` | String | Yes | `none`, `difficult`, `impassable` |
| `height` | Integer | Yes | Height in inches |
| `size` | Object | Yes | Width and depth in inches |
| `climbable` | Boolean | Yes | Can characters climb it? |
| `destructible` | Boolean | Yes | Can it be destroyed in combat? |
| `special_rules` | Array | Optional | Unique terrain effects |
| `spawn_weight` | Integer | Yes | Relative spawn frequency |
| `spawn_contexts` | Array | Yes | Battlefield types where it appears |
| `model_path` | String | Yes | 3D model path (if available) |
| `icon` | String | Yes | 2D icon for tactical view |

#### Cover Values

```json
"cover_value": -2
```

**Cover Types**:
- **Light Cover (-1)**: Low walls, rubble, thin trees
- **Heavy Cover (-2)**: Thick walls, vehicles, dense vegetation  
- **Full Cover (-3)**: Bunkers, buildings, massive objects

#### Movement Types

```json
"movement_penalty": "difficult"
```

**Movement Options**:
- **none**: No penalty
- **difficult**: Costs 2" of movement per 1" traveled
- **impassable**: Cannot cross

---

### Campaign Events

**File**: `data/events/CampaignEvents.json` (core) or `data/custom/events/*.json`

#### Event Format

```json
{
  "events": [
    {
      "id": "event_patron_offer",
      "name": "Patron Contact",
      "description": "A well-connected patron offers you work.",
      "category": "opportunity",
      "trigger": {
        "type": "random",
        "phase": "world",
        "probability": 0.15,
        "conditions": [
          {"type": "no_active_patron", "value": true},
          {"type": "reputation_min", "value": 5}
        ]
      },
      "effects": [
        {
          "type": "add_patron",
          "patron_type": "random",
          "duration": 5
        }
      ],
      "choices": [
        {
          "id": "choice_accept",
          "text": "Accept the patron's offer",
          "consequences": [
            {"type": "add_patron", "value": "random"}
          ],
          "requirements": []
        },
        {
          "id": "choice_decline",
          "text": "Politely decline",
          "consequences": [
            {"type": "modify_reputation", "value": -1}
          ],
          "requirements": []
        }
      ],
      "repeatable": true,
      "cooldown_turns": 10,
      "story_track_integration": false,
      "dlc_required": null,
      "enabled": true,
      "tags": ["patron", "opportunity", "world_step"]
    }
  ]
}
```

#### Event Property Reference

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | Yes | Unique identifier (prefix: `event_`) |
| `name` | String | Yes | Event title |
| `description` | String | Yes | Event narrative text |
| `category` | String | Yes | `opportunity`, `challenge`, `story`, `random` |
| `trigger` | Object | Yes | When/how event fires |
| `effects` | Array | Yes | Immediate effects when triggered |
| `choices` | Array | Optional | Player decision options |
| `repeatable` | Boolean | Yes | Can fire multiple times |
| `cooldown_turns` | Integer | If repeatable | Turns between repeats |
| `story_track_integration` | Boolean | Yes | Affects story track |

---

## Step-by-Step Creation Guides

### Creating a New Character Origin

#### Step 1: Concept and Theme

**Questions to Answer**:
- What makes this origin unique?
- What's the character's background story?
- Which stats should be emphasized?
- What equipment fits the theme?

**Example**: "Tech Scavenger" - A wasteland survivor who salvages and repairs technology

#### Step 2: Define Base Stats

```json
"base_stats": {
  "reactions": 1,      // Average initiative
  "speed": 5,          // Standard human
  "combat_skill": -1,  // Not a fighter
  "toughness": 4,      // Standard
  "savvy": 2           // High technical skill
}
```

**Stat Budget**: Total bonus should be +2 to +4 for balanced origins.

#### Step 3: Choose Starting Equipment

```json
"starting_equipment": [
  "weapon_holdout_pistol",    // Low-tier weapon (fits scavenger theme)
  "gear_toolkit",             // Thematic gear
  "armor_scrap_vest"          // Light protection
]
```

**Equipment Guidelines**:
- 1 weapon (usually low-tier)
- 1-2 gear items (thematic)
- 0-1 armor pieces (light armor typical)
- Total value: 10-20 credits

#### Step 4: Design Special Rules

```json
"special_rules": [
  {
    "id": "rule_tech_affinity",
    "name": "Tech Affinity",
    "description": "+2 to all repair and technology-related skill checks",
    "effects": {
      "skill_bonus_repair": 2,
      "skill_bonus_tech": 2
    }
  }
]
```

#### Step 5: Add Background/Motivation Options

```json
"background_options": [
  "engineer",
  "scavenger",
  "drifter"
],
"motivation_options": [
  "survival",
  "knowledge",
  "wealth"
]
```

**Requirements**: Minimum 3 options each.

#### Step 6: Set Metadata

```json
"xp_cost": 2,                 // Low-tier unlock
"rarity": "uncommon",
"dlc_required": null,
"enabled": true,
"tags": ["tech", "scavenger", "wasteland"]
```

#### Step 7: Testing Checklist

- [ ] All required fields present
- [ ] Stats within valid ranges
- [ ] Equipment IDs exist in equipment data
- [ ] Stat total is balanced
- [ ] Special rules have clear mechanics
- [ ] Unique ID with `origin_` prefix
- [ ] JSON syntax valid (no trailing commas, quotes correct)

---

### Creating a New Weapon

#### Step 1: Weapon Concept

**Questions**:
- What role does this weapon fill? (close combat, long range, area effect)
- What's the power level? (starting gear, mid-tier, end-game)
- What's unique about it?
- What's the cost vs benefit?

**Example**: "Arc Pistol" - Short-range energy weapon with stun capability

#### Step 2: Define Core Stats

```json
{
  "id": "weapon_arc_pistol",
  "name": "Arc Pistol",
  "type": "weapon",
  "weapon_class": "pistol",
  "range": 12,        // Short range
  "shots": 1,
  "damage": 1
}
```

**Range Guidelines**:
```
Melee: 0"
Pistol: 12"
Rifle: 24"
Sniper: 36"
Heavy: 18" (blast weapons)
```

#### Step 3: Add Weapon Traits

```json
"traits": [
  {
    "id": "trait_stun",
    "name": "Stun",
    "description": "Target hit must pass Toughness check or lose next activation",
    "value": null
  }
]
```

**Trait Selection**:
- 0-2 traits for balanced weapons
- Positive traits increase cost
- Negative traits decrease cost

#### Step 4: Set Cost and Rarity

```json
"cost": 8,              // Mid-range for pistol + stun trait
"rarity": "uncommon",
"weight": 1
```

**Cost Calculation**:
```
Base cost (pistol): 5 credits
+ Stun trait: +3 credits
= 8 credits total
```

#### Step 5: Add Requirements/Restrictions

```json
"hands_required": 1,
"ammo_type": "energy_cell",
"ammo_capacity": 12,
"restrictions": []
```

#### Step 6: Complete Metadata

```json
"dlc_required": null,
"enabled": true,
"tags": ["energy", "stun", "pistol"]
```

#### Step 7: Balance Testing

**Balance Checklist**:
- [ ] Damage appropriate for range
- [ ] Cost matches power level
- [ ] Traits balanced (not overpowered)
- [ ] Ammo capacity reasonable
- [ ] Weight appropriate
- [ ] Comparable to similar weapons

**Comparison Matrix**:
| Weapon | Range | Damage | Traits | Cost |
|--------|-------|--------|--------|------|
| Scrap Pistol | 12" | 0 | - | 3 |
| **Arc Pistol** | **12"** | **1** | **Stun** | **8** |
| Plasma Pistol | 12" | 1 | Piercing 1 | 10 |

---

### Creating a New Enemy

#### Step 1: Enemy Concept

**Questions**:
- What faction/group do they belong to?
- What's their combat role? (melee, ranged, support)
- What difficulty tier? (basic cannon fodder, elite threat, boss)
- What makes them memorable?

**Example**: "Waste Mutant" - Aggressive melee enemy, basic tier

#### Step 2: Define Stats

```json
"stats": {
  "reactions": 0,      // Slow
  "speed": 6,          // Fast movement
  "combat_skill": 0,   // Average fighter
  "toughness": 5,      // Very tough
  "savvy": -1          // Not smart
}
```

**Difficulty Guidelines**:
```
Basic: Total stat bonus -2 to +2
Elite: Total stat bonus +3 to +6
Boss: Total stat bonus +7 to +12
```

#### Step 3: Assign Equipment

```json
"weapons": [
  {"id": "weapon_rusty_blade", "probability": 0.7},
  {"id": "weapon_makeshift_club", "probability": 0.3}
],
"armor": []
```

**Equipment Probability**:
- 1.0 = Always equipped
- 0.5 = 50% chance
- 0.0 = Never equipped

#### Step 4: Configure AI

```json
"ai_behavior": "aggressive",
"ai_priority": ["closest", "wounded"]
```

**Behavior Selection**:
- **Melee enemies**: aggressive, closest priority
- **Ranged enemies**: defensive, dangerous priority  
- **Support enemies**: tactical, weakest priority
- **Elite enemies**: tactical, leader priority

#### Step 5: Set Spawn Rules

```json
"spawn_weight": 8,
"difficulty_min": 0,
"difficulty_max": 2
```

**Spawn Weight**:
```
10: Very common
5-8: Common
2-4: Uncommon
1: Rare
```

#### Step 6: Add Special Rules (Optional)

```json
"special_rules": [
  {
    "id": "rule_regeneration",
    "name": "Regeneration",
    "description": "Recovers 1 wound at start of each turn",
    "trigger": "start_of_turn",
    "effect": {"heal": 1}
  }
]
```

#### Step 7: Set Rewards

```json
"loot_table": "basic_melee",
"xp_value": 1,
"panic_threshold": 2
```

---

### Creating a New Mission

#### Step 1: Mission Concept

**Questions**:
- What's the core objective? (combat, rescue, retrieval, defense)
- What's the narrative hook?
- What makes it interesting/challenging?
- What's the expected difficulty?

**Example**: "Reactor Meltdown" - Disable reactor before it explodes, fighting through defending enemies

#### Step 2: Define Primary Objective

```json
"objectives": [
  {
    "id": "obj_primary_disable_reactor",
    "name": "Disable the Reactor",
    "description": "Reach the reactor core and spend 2 turns disabling it",
    "type": "primary",
    "completion_condition": {
      "type": "interact_object",
      "object_id": "reactor_core",
      "interaction_time": 2
    },
    "xp_reward": 3,
    "credit_reward": 15
  }
]
```

#### Step 3: Add Secondary Objectives

```json
{
  "id": "obj_secondary_rescue",
  "name": "Rescue Engineers",
  "description": "Escort trapped engineers to the extraction zone",
  "type": "secondary",
  "completion_condition": {
    "type": "escort_npc",
    "npc_count": 2,
    "destination": "extraction_zone"
  },
  "xp_reward": 1,
  "credit_reward": 8
}
```

**Objective Balance**:
- Primary: High reward, mandatory
- Secondary: Medium reward, optional bonus
- Total rewards should match difficulty

#### Step 4: Configure Enemy Composition

```json
"enemy_composition": {
  "basic": {"min": 6, "max": 10},
  "elite": {"min": 1, "max": 2}
}
```

**Enemy Count Guidelines**:
```
Easy: 4-6 basic, 0-1 elite
Medium: 6-8 basic, 1-2 elite
Hard: 8-12 basic, 2-3 elite
Very Hard: 10-15 basic, 3-4 elite
```

#### Step 5: Define Terrain and Deployment

```json
"terrain_requirements": {
  "cover_density": "high",
  "special_features": ["reactor_core", "barricades"]
},
"deployment": {
  "crew_zone": "table_edge_south",
  "enemy_zone": "scattered",
  "deployment_rules": ["enemies_guard_objective"]
}
```

#### Step 6: Add Special Rules

```json
"special_rules": [
  {
    "id": "rule_meltdown_timer",
    "name": "Reactor Meltdown",
    "description": "Mission fails if not completed in 8 turns",
    "trigger": "turn_8",
    "effect": {
      "type": "mission_failure",
      "narrative": "The reactor explodes!"
    }
  }
]
```

#### Step 7: Set Requirements and Metadata

```json
"difficulty": 3,
"time_limit": 8,
"min_crew_size": 4,
"max_crew_size": 6,
"patron_required": false,
"story_track_required": false
```

---

## Validation and Testing

### JSON Validation

#### Online Validators

**Recommended Tools**:
1. **JSONLint** (https://jsonlint.com/) - Copy/paste validator
2. **VS Code** - Built-in JSON validation
3. **JSONFormatter** (https://jsonformatter.curiousconcept.com/) - Format + validate

#### Common JSON Errors

```json
// ❌ WRONG: Trailing comma
{
  "id": "weapon_pistol",
  "name": "Pistol",
}

// ✅ CORRECT: No trailing comma
{
  "id": "weapon_pistol",
  "name": "Pistol"
}
```

```json
// ❌ WRONG: Single quotes
{
  'id': 'weapon_pistol'
}

// ✅ CORRECT: Double quotes
{
  "id": "weapon_pistol"
}
```

```json
// ❌ WRONG: Missing comma
{
  "id": "weapon_pistol"
  "name": "Pistol"
}

// ✅ CORRECT: Comma between properties
{
  "id": "weapon_pistol",
  "name": "Pistol"
}
```

### Schema Validation

The game includes JSON schemas for all content types in `data/schemas/`.

#### Running Schema Validation

```bash
# Validate a custom character file
godot --script validate_content.gd --content-type character --file data/custom/characters/my_character.json

# Validate all custom equipment
godot --script validate_content.gd --content-type equipment --directory data/custom/equipment/

# Validate everything
godot --script validate_content.gd --directory data/custom/
```

#### Schema Error Examples

```
ERROR: Character 'origin_wanderer' failed validation:
  - Missing required property: 'base_stats'
  - Property 'rarity' has invalid value 'super_rare' (expected: common, uncommon, rare, legendary)
  - Property 'reactions' value 5 exceeds maximum 3
```

### In-Game Testing

#### Test Mode Setup

1. **Enable Test Mode**:
   - Settings → Developer → Enable Test Mode
   - Settings → Developer → Enable Content Logging

2. **Load Custom Content**:
   - Settings → Content → Enable Custom Content
   - Settings → Content → Reload Content Files

#### Testing New Characters

```
Test Checklist:
☐ Character appears in creation screen
☐ Stats display correctly
☐ Starting equipment granted properly
☐ Special rules work as described
☐ Background/motivation options selectable
☐ XP cost correct (if unlock required)
☐ No console errors on character creation
```

#### Testing New Equipment

```
Test Checklist:
☐ Item appears in shops/loot
☐ Cost matches specification
☐ Equip animation plays correctly
☐ Weapon: Damage and traits function
☐ Armor: Damage reduction works
☐ Gear: Effects trigger properly
☐ Weight/encumbrance applied
☐ Restrictions enforced
```

#### Testing New Enemies

```
Test Checklist:
☐ Enemy spawns in missions
☐ AI behavior matches specification
☐ Weapons/armor equipped correctly
☐ Special rules function
☐ Loot drops appropriate items
☐ XP awarded on defeat
☐ Morale/panic works correctly
```

#### Testing New Missions

```
Test Checklist:
☐ Mission appears in available missions
☐ Objectives clear and trackable
☐ Enemy composition correct
☐ Terrain spawns properly
☐ Deployment zones work
☐ Special rules trigger correctly
☐ Completion rewards granted
☐ Mission ends properly (win/loss)
```

### Debug Console Commands

Enable the debug console: **Settings → Developer → Enable Debug Console**

**Useful Commands**:
```
# Spawn custom character for testing
/spawn_character origin_wanderer

# Give custom weapon
/give_item weapon_arc_pistol

# Start custom mission
/start_mission mission_salvage_operation

# Add credits for shopping tests
/add_credits 1000

# Set faction standing
/set_faction_standing faction_unity 50

# Force event
/trigger_event event_patron_offer

# Reload content without restarting
/reload_content
```

### Performance Testing

#### Spawn Limit Test

**Issue**: Too many enemies causing lag.

**Test**:
```bash
# Spawn 20 of your custom enemy
/spawn_enemy enemy_raider 20

# Monitor FPS (shown in debug overlay)
# Target: 60 FPS on medium-spec hardware
```

**Fix**: Reduce `spawn_weight` or increase `difficulty_min`.

#### Memory Leak Test

**Issue**: Loading custom content repeatedly causes memory buildup.

**Test**:
1. Start game, note memory usage (F3 overlay)
2. Load campaign, note memory
3. Return to menu
4. Repeat steps 2-3 ten times
5. Memory should stabilize, not continuously increase

---

## Core vs DLC Content

### Content Tiers

**CORE CONTENT** (Included with base game):
- Basic characters, weapons, enemies
- Standard missions
- Core factions
- Basic terrain

**DLC CONTENT** (Requires expansion purchase):
- Expansion species (Krag, Skulker, etc.)
- Advanced equipment
- Elite enemy types
- Special missions
- New factions

**COMMUNITY CONTENT** (User-created):
- Custom characters
- Modded equipment
- Fan-made missions
- Total conversions

### Marking Content as DLC

```json
{
  "id": "origin_krag_warrior",
  "name": "Krag Warrior",
  "dlc_required": "dlc_krag_species",
  "enabled": true
}
```

**DLC IDs**:
- `dlc_krag_species`: Krag playable species
- `dlc_skulker_species`: Skulker playable species
- `dlc_psionics`: Psionic powers system
- `dlc_expanded_missions`: Expanded mission pack
- `dlc_factions`: Additional factions pack

### DLC Check Logic

```gdscript
func is_content_available(content_item: Dictionary) -> bool:
    # Core content always available
    if content_item.dlc_required == null:
        return true
    
    # Check if player owns DLC
    return DLCManager.has_dlc(content_item.dlc_required)
```

### Creating DLC-Compatible Content

#### Extending Core Content

```json
// Krag variant of existing weapon
{
  "id": "weapon_krag_hand_cannon",
  "name": "Krag Hand Cannon",
  "base_weapon": "weapon_hand_cannon",  // Extends core weapon
  "stat_modifiers": {
    "damage": +1,
    "weight": +1
  },
  "restrictions": ["krag_only"],
  "dlc_required": "dlc_krag_species"
}
```

#### DLC-Exclusive Content

```json
// Psionic power (requires Psionics DLC)
{
  "id": "ability_mind_blast",
  "name": "Mind Blast",
  "category": "psionic_power",
  "dlc_required": "dlc_psionics",
  "enabled": true
}
```

### Compatibility Guidelines

**DO**:
- ✅ Reference core content freely
- ✅ Create variants of core content
- ✅ Add new content that works alongside core
- ✅ Clearly mark DLC requirements

**DON'T**:
- ❌ Replace core content with DLC versions
- ❌ Make core content require DLC
- ❌ Break core gameplay with DLC additions
- ❌ Create DLC dependencies between community mods

---

## Advanced Topics

### Conditional Content Loading

#### Time-Based Unlocks

```json
{
  "id": "event_halloween_special",
  "name": "Spooky Salvage",
  "availability": {
    "date_start": "10-20",
    "date_end": "11-05"
  }
}
```

#### Achievement Unlocks

```json
{
  "id": "weapon_legendary_blade",
  "name": "Hero's Blade",
  "unlock_requirement": {
    "type": "achievement",
    "achievement_id": "defeat_100_enemies"
  }
}
```

### Procedural Content Generation

#### Template-Based Generation

```json
{
  "id": "mission_template_ambush",
  "name": "Ambush {location_type}",
  "variables": {
    "location_type": ["Convoy", "Settlement", "Outpost"],
    "enemy_faction": "random",
    "objective_count": {"min": 2, "max": 4}
  }
}
```

### Localization

#### Multi-Language Support

```json
{
  "id": "weapon_plasma_rifle",
  "name": "Plasma Rifle",
  "name_localized": {
    "en": "Plasma Rifle",
    "es": "Rifle de Plasma",
    "fr": "Fusil à Plasma",
    "de": "Plasmagewehr"
  },
  "description_localized": {
    "en": "Military-grade energy weapon...",
    "es": "Arma de energía de grado militar...",
    "fr": "Arme énergétique de qualité militaire..."
  }
}
```

### Content Packs

#### Pack Manifest

**File**: `data/packs/my_pack/manifest.json`

```json
{
  "pack_id": "pack_wasteland_expansion",
  "pack_name": "Wasteland Expansion",
  "version": "1.0.0",
  "author": "ContentCreator",
  "description": "Adds wasteland-themed content",
  "content_files": [
    "characters/wasteland_origins.json",
    "equipment/wasteland_gear.json",
    "enemies/mutants.json",
    "missions/wasteland_missions.json"
  ],
  "dependencies": [],
  "conflicts": [],
  "load_order": 100
}
```

#### Installing Content Packs

```
1. Extract pack to: data/packs/pack_name/
2. Enable in Settings → Content → Content Packs
3. Reload content or restart game
```

### Scripting and Events

#### Advanced Event Scripting

```json
{
  "id": "event_complex_choice",
  "name": "Moral Dilemma",
  "choices": [
    {
      "id": "choice_save_crew",
      "text": "Save your crew member",
      "requirements": [
        {"type": "crew_size_min", "value": 2}
      ],
      "consequences": [
        {"type": "remove_crew_member", "random": true},
        {"type": "modify_morale", "value": -5}
      ],
      "skill_check": {
        "stat": "savvy",
        "target": 6,
        "on_success": [
          {"type": "add_item", "item_id": "rare_artifact"}
        ],
        "on_failure": [
          {"type": "lose_credits", "amount": 10}
        ]
      }
    }
  ]
}
```

---

## Troubleshooting

### Common Issues

#### Content Not Appearing

**Symptom**: Custom content doesn't show in-game.

**Checklist**:
- [ ] File in correct directory (`data/custom/`)
- [ ] `"enabled": true` in content file
- [ ] No JSON syntax errors
- [ ] Custom content enabled in settings
- [ ] Content reloaded/game restarted
- [ ] Check debug console for errors

**Debug Steps**:
```
1. Open debug console (`)
2. Type: /list_content weapon
3. Look for your weapon ID
4. If missing: check console for load errors
```

#### Validation Errors

**Symptom**: "Content failed validation" error.

**Common Causes**:
```json
// Missing required field
{
  "id": "weapon_test",
  // ❌ Missing "name" field
  "cost": 10
}

// Invalid value
{
  "id": "weapon_test",
  "rarity": "super_duper_rare"  // ❌ Not a valid rarity
}

// Type mismatch
{
  "id": "weapon_test",
  "cost": "ten credits"  // ❌ Should be integer
}
```

**Fix**: Run schema validator and fix reported errors.

#### Balance Issues

**Symptom**: Content too powerful or too weak.

**Weapon Too Powerful**:
- Reduce damage
- Increase cost
- Add negative traits
- Reduce range/shots

**Enemy Too Weak**:
- Increase stats
- Add armor
- Give better weapons
- Add special rules

**Mission Too Hard**:
- Reduce enemy count
- Increase time limit
- Add secondary objectives with helpful rewards
- Reduce difficulty rating

#### Performance Problems

**Symptom**: Lag when custom content loads.

**Causes**:
- Too many high-poly 3D models
- Excessive particle effects
- Too many enemies spawning
- Large texture files

**Solutions**:
- Optimize 3D models (reduce poly count)
- Use texture compression
- Limit maximum enemy spawns
- Use LOD (Level of Detail) for models

---

## Submission Guidelines

### Community Content Submission

#### Preparing Your Content

**Checklist**:
- [ ] All JSON files validated
- [ ] Content tested in-game
- [ ] No console errors
- [ ] Balanced compared to core content
- [ ] Localization provided (at least English)
- [ ] Screenshot/preview images included
- [ ] README.md with installation instructions
- [ ] Credits/attribution included
- [ ] License specified (if applicable)

#### Package Structure

```
my_content_pack/
├── manifest.json          # Pack metadata
├── README.md              # Installation and description
├── LICENSE.txt            # Content license
├── preview.png            # Pack preview image
├── characters/
│   └── *.json
├── equipment/
│   └── *.json
├── enemies/
│   └── *.json
├── missions/
│   └── *.json
└── assets/               # Optional: custom images/models
    ├── icons/
    └── models/
```

#### Manifest Template

```json
{
  "pack_id": "pack_my_content",
  "pack_name": "My Content Pack",
  "version": "1.0.0",
  "author": "YourName",
  "author_contact": "your@email.com",
  "description": "Adds X new characters, Y weapons, and Z missions themed around [theme]",
  "content_summary": {
    "characters": 5,
    "weapons": 10,
    "enemies": 8,
    "missions": 6
  },
  "dependencies": [],
  "requires_dlc": [],
  "compatible_game_version": "1.0.0+",
  "tags": ["theme", "category", "difficulty"]
}
```

### Submission Process

#### Step 1: Test Thoroughly

- Install fresh copy of game
- Copy only your content pack
- Create new campaign
- Test all custom content
- Fix any issues

#### Step 2: Create Submission Package

```bash
# Create archive
zip -r my_content_pack_v1.0.zip my_content_pack/

# Or use tar
tar -czf my_content_pack_v1.0.tar.gz my_content_pack/
```

#### Step 3: Submit to Community Hub

**Official Community Hub**: https://five-parsecs.com/mods

1. Create account
2. Click "Upload Content"
3. Fill out submission form:
   - Pack name
   - Version
   - Description
   - Category
   - Tags
   - Screenshots (3-5 images)
4. Upload archive file
5. Submit for review

#### Step 4: Review Process

**Review Criteria**:
- ✅ Technical validity (no errors)
- ✅ Balance (not game-breaking)
- ✅ Quality (functional, polished)
- ✅ Originality (not plagiarized)
- ✅ Appropriateness (no offensive content)

**Review Timeline**: 3-7 days

### Official Content Submission

For inclusion in official DLC or expansions:

**Contact**: content@five-parsecs.com

**Requirements**:
- High quality and polish
- Original work (you own all rights)
- Extensive playtesting
- Professional presentation
- Balanced gameplay
- Fits game's tone and setting

**Process**:
1. Submit proposal with concept
2. If approved, create content
3. Submit for internal testing
4. Revisions as needed
5. Contract and payment negotiation
6. Release as official content

---

## Appendix

### Content ID Naming Conventions

| Content Type | Prefix | Example |
|--------------|--------|---------|
| Character Origin | `origin_` | `origin_wanderer` |
| Weapon | `weapon_` | `weapon_plasma_rifle` |
| Armor | `armor_` | `armor_combat_armor` |
| Gear | `gear_` | `gear_medkit` |
| Enemy | `enemy_` | `enemy_raider` |
| Mission | `mission_` | `mission_salvage_op` |
| Faction | `faction_` | `faction_unity` |
| Terrain | `terrain_` | `terrain_rubble` |
| Event | `event_` | `event_patron_offer` |
| Ability | `ability_` | `ability_mind_blast` |
| Trait | `trait_` | `trait_piercing` |
| Rule | `rule_` | `rule_survivor` |

### Stat Ranges Reference

```gdscript
# Character Stats
Reactions: 0-3
Speed: 3-7 (inches)
Combat Skill: -1 to +2
Toughness: 3-5
Savvy: -1 to +2

# Weapon Stats
Range: 0-48 (inches)
Damage: 0-3
Shots: 1-6

# Armor Stats
Armor Value: 0-3
Weight: 0-5

# Enemy Stats
XP Value: 1-10
Spawn Weight: 1-10
Panic Threshold: 1-5
```

### JSON Schema Locations

```
data/schemas/
├── character_schema.json
├── equipment_schema.json
├── enemy_schema.json
├── mission_schema.json
├── faction_schema.json
├── terrain_schema.json
└── event_schema.json
```

### Template File Locations

```
data/templates/
├── character_template.json
├── weapon_template.json
├── armor_template.json
├── gear_template.json
├── enemy_template.json
├── elite_enemy_template.json
├── mission_template.json
├── faction_template.json
├── terrain_template.json
└── event_template.json
```

### Content File Size Limits

| Content Type | Max File Size | Max Items Per File |
|--------------|---------------|-------------------|
| Characters | 100 KB | 50 origins |
| Equipment | 500 KB | 200 items |
| Enemies | 200 KB | 100 enemies |
| Missions | 500 KB | 50 missions |
| Factions | 100 KB | 20 factions |
| Terrain | 200 KB | 100 features |
| Events | 300 KB | 100 events |

### Common Rarity Values

```
common: 60-70% spawn/availability
uncommon: 20-30% spawn/availability
rare: 5-15% spawn/availability
legendary: 1-5% spawn/availability
```

### Difficulty Ratings

```
0: Tutorial/Very Easy
1: Easy
2: Normal
3: Hard
4: Very Hard
5: Brutal
```

---

## Related Documentation

- **[Player's Guide](../player/PLAYERS_GUIDE.md)** - Learn the game mechanics
- **[Rules Implementation Guide](../gameplay/RULES_IMPLEMENTATION_GUIDE.md)** - Understand rule translations
- **[Compendium Implementation](../gameplay/COMPENDIUM_IMPLEMENTATION.md)** - Reference expansion content
- **[System Architecture Deep Dive](../technical/SYSTEM_ARCHITECTURE_DEEP_DIVE.md)** - Technical implementation details
- **[Data Model & Save System](../technical/DATA_MODEL_AND_SAVE_SYSTEM.md)** - Save file formats

---

**Document Complete** - 2,071 lines  
**Status**: ✅ Complete content creation guide for modding and custom content

For questions or support:
- **Community Forums**: https://five-parsecs.com/forums
- **Discord**: https://discord.gg/five-parsecs
- **Documentation Issues**: https://github.com/five-parsecs/docs/issues
