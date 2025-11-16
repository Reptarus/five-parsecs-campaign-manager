# Five Parsecs Campaign Manager - Data Format Specifications

**Version**: 1.0
**Last Updated**: 2024-11-16
**Audience**: Content creators, developers, modders

---

## Table of Contents

1. [Overview](#overview)
2. [General JSON Conventions](#general-json-conventions)
3. [Core Content Types](#core-content-types)
   - [Species Format](#species-format)
   - [Psionic Powers Format](#psionic-powers-format)
   - [Elite Enemies Format](#elite-enemies-format)
   - [Difficulty Modifiers Format](#difficulty-modifiers-format)
   - [Equipment & Weapons Format](#equipment--weapons-format)
4. [Mission Content Types](#mission-content-types)
   - [Stealth Missions Format](#stealth-missions-format)
   - [Salvage Jobs Format](#salvage-jobs-format)
   - [General Missions Format](#general-missions-format)
5. [Validation Rules](#validation-rules)
6. [Common Patterns](#common-patterns)
7. [Field Reference](#field-reference)
8. [Version History](#version-history)

---

## Overview

This document provides complete JSON format specifications for all content types in the Five Parsecs Campaign Manager. All expansion content uses data-driven design with JSON files loaded at runtime.

### Purpose

- **Standardization**: Consistent format across all expansions
- **Validation**: Clear rules for content validation
- **Documentation**: Single source of truth for data formats
- **Tooling**: Enable automated validation and content creation tools

### File Organization

```
data/
├── dlc/
│   ├── trailblazers_toolkit/
│   │   ├── trailblazers_toolkit_species.json
│   │   └── trailblazers_toolkit_psionic_powers.json
│   ├── freelancers_handbook/
│   │   ├── freelancers_handbook_elite_enemies.json
│   │   └── freelancers_handbook_difficulty_modifiers.json
│   ├── fixers_guidebook/
│   │   └── fixers_guidebook_missions.json
│   └── bug_hunt/
│       ├── bug_enemies.json
│       ├── military_equipment.json
│       └── bug_hunt_missions.json
```

---

## General JSON Conventions

### Formatting Standards

- **Encoding**: UTF-8
- **Line Endings**: LF (Unix-style)
- **Indentation**: 2 spaces (no tabs)
- **String Quotes**: Double quotes only
- **Trailing Commas**: Not allowed (invalid JSON)
- **Comments**: Not supported in JSON (use description fields)

### Naming Conventions

- **Field Names**: `snake_case` (lowercase with underscores)
- **String Values**: Sentence case for descriptions, Title Case for names
- **Booleans**: Always lowercase `true` or `false`
- **Numbers**: No quotes (numeric types only)

### Required vs Optional Fields

- **Required**: Field must be present (validation will fail if missing)
- **Optional**: Field can be omitted (defaults will be used)
- **Conditional**: Field required based on other field values

### Common Field Types

```json
{
  "name": "String",                    // Display name (required)
  "description": "String",             // Flavor text (required)
  "dlc_required": "expansion_name",    // DLC identifier (required for DLC content)
  "source": "expansion_name",          // Source expansion (required for DLC content)
  "enabled": true,                     // Feature toggle (optional, default: true)
  "version": "1.0.0"                   // Content version (optional)
}
```

---

## Core Content Types

## Species Format

### Schema

```json
{
  "name": "String",
  "playable": Boolean,
  "description": "String",
  "homeworld": "String",
  "traits": ["String"],
  "starting_bonus": "String",
  "dlc_required": "String",
  "source": "String",
  "base_profile": {
    "reactions": Integer (0-3),
    "speed": "String (3\"-6\")",
    "combat_skill": "String (+/-0-3)",
    "toughness": Integer (2-6),
    "savvy": "String (+/-0-3)"
  },
  "special_rules": [
    {
      "name": "String",
      "description": "String",
      "mechanical_effect": "String"
    }
  ]
}
```

### Field Specifications

#### Root Fields

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `name` | String | Yes | Species name | `"Krag"` |
| `playable` | Boolean | Yes | Can be used by player crew | `true` |
| `description` | String | Yes | Flavor text (2-3 sentences) | `"Towering reptilian warriors..."` |
| `homeworld` | String | Yes | Planet/system of origin | `"K'Erin Prime"` |
| `traits` | Array[String] | Yes | Cultural/physical traits | `["Durable", "Slow"]` |
| `starting_bonus` | String | Yes | Initial advantage for new characters | `"Start with +1 XP"` |
| `dlc_required` | String | Yes | DLC identifier | `"trailblazers_toolkit"` |
| `source` | String | Yes | Source expansion name | `"Trailblazer's Toolkit"` |

#### base_profile Fields

| Field | Type | Required | Range | Default (Human) |
|-------|------|----------|-------|-----------------|
| `reactions` | Integer | Yes | 0-3 | 1 |
| `speed` | String | Yes | 3"-6" | 4" |
| `combat_skill` | String | Yes | +/-0-3 | +0 |
| `toughness` | Integer | Yes | 2-6 | 3 |
| `savvy` | String | Yes | +/-0-3 | +0 |

**Speed Format**: Always include inch mark (e.g., `"4\""`, `"5\""`)
**Skill Format**: Always include sign for positive values (e.g., `"+1"`, `"+2"`, `"-1"`)

#### special_rules Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Rule name (2-4 words) |
| `description` | String | Yes | Flavor text explaining the rule |
| `mechanical_effect` | String | Yes | Exact game mechanics (detailed) |

### Balance Guidelines

**Net-Zero Principle**: Total stat modifications should sum to approximately 0.

**Calculation**:
- Reactions: ±1 = ±1 point
- Speed: ±1" = ±1 point
- Combat Skill: ±1 = ±1 point
- Toughness: ±1 = ±1 point
- Savvy: ±1 = ±1 point
- Special Rules: ±0.5 to ±2 points (based on power)

**Example (Krag)**:
- Toughness +1 = +1 point
- Speed -1" = -1 point
- Total = 0 points ✓

### Complete Example

```json
{
  "name": "Krag",
  "playable": true,
  "description": "Towering reptilian warriors from K'Erin Prime, Krag are known for their exceptional resilience and warrior culture. Despite their imposing size, they move slower than most species but can endure incredible punishment.",
  "homeworld": "K'Erin Prime",
  "traits": ["Durable", "Slow", "Honorable"],
  "starting_bonus": "Start with +1 XP due to warrior training",
  "dlc_required": "trailblazers_toolkit",
  "source": "Trailblazer's Toolkit",
  "base_profile": {
    "reactions": 1,
    "speed": "3\"",
    "combat_skill": "+0",
    "toughness": 4,
    "savvy": "+0"
  },
  "special_rules": [
    {
      "name": "Thick Hide",
      "description": "Krag possess naturally armored skin that deflects blows.",
      "mechanical_effect": "Natural armor save of 6+ against all attacks. Does not stack with worn armor (use better save)."
    },
    {
      "name": "Slow and Steady",
      "description": "Krag are methodical and hard to panic.",
      "mechanical_effect": "+1 to all Morale tests. Cannot use the Dash action."
    }
  ]
}
```

### Validation Rules

1. **Required Fields**: All root fields and base_profile fields must be present
2. **Stat Ranges**: All stats must be within specified ranges
3. **Speed Format**: Must match pattern `\d+"` (e.g., "4\"")
4. **Combat Skill Format**: Must match pattern `[+\-]\d+` (e.g., "+1", "-1")
5. **Savvy Format**: Must match pattern `[+\-]\d+`
6. **Special Rules**: At least 1 special rule required
7. **Balance**: Net stat modification should be -2 to +2 (recommended 0)
8. **DLC Identifier**: Must match directory name in `/data/dlc/`

---

## Psionic Powers Format

### Schema

```json
{
  "name": "String",
  "description": "String",
  "target_type": "self|enemy|any",
  "range": "self|6\"|12\"|line_of_sight",
  "persists": Boolean,
  "affects_robotic": Boolean,
  "dlc_required": "String",
  "source": "String",
  "cost": Integer (3-7),
  "difficulty": "basic|intermediate|advanced",
  "activation": {
    "type": "combat_action|movement_action",
    "activation_roll": "4+|5+|6+|7+",
    "duration": "String"
  },
  "effects": [
    {
      "name": "String",
      "description": "String"
    }
  ]
}
```

### Field Specifications

#### Root Fields

| Field | Type | Required | Valid Values | Description |
|-------|------|----------|--------------|-------------|
| `name` | String | Yes | Any | Power name (1-3 words) |
| `description` | String | Yes | Any | Flavor text (2-3 sentences) |
| `target_type` | String | Yes | `self`, `enemy`, `any` | Who can be targeted |
| `range` | String | Yes | `self`, `6"`, `12"`, `line_of_sight` | Maximum range |
| `persists` | Boolean | Yes | `true`, `false` | Does effect last beyond instant? |
| `affects_robotic` | Boolean | Yes | `true`, `false` | Can target robots/machines? |
| `dlc_required` | String | Yes | Any | DLC identifier |
| `source` | String | Yes | Any | Source expansion name |
| `cost` | Integer | Yes | 3-7 | XP cost to learn |
| `difficulty` | String | Yes | `basic`, `intermediate`, `advanced` | Power tier |

#### activation Fields

| Field | Type | Required | Valid Values | Description |
|-------|------|----------|--------------|-------------|
| `type` | String | Yes | `combat_action`, `movement_action` | Action type required |
| `activation_roll` | String | Yes | `4+`, `5+`, `6+`, `7+` | Target number (1D6+Savvy) |
| `duration` | String | Yes | Any | How long effect lasts |

**Duration Formats**:
- `"Instant"` - Single moment
- `"1D3 rounds"` - Dice-based duration
- `"Until caster's next activation"` - Lasts until specific event
- `"Concentration"` - While caster focuses (no other actions)

#### effects Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Effect name (2-4 words) |
| `description` | String | Yes | Detailed mechanical effect |

### Difficulty Tiers

| Difficulty | Activation Roll | XP Cost | Complexity |
|------------|----------------|---------|------------|
| Basic | 4+ | 3-4 XP | Single simple effect |
| Intermediate | 5+ | 4-5 XP | Multiple effects or complex targeting |
| Advanced | 6+ or 7+ | 5-7 XP | Powerful effects or unique mechanics |

### Complete Example

```json
{
  "name": "Barrier",
  "description": "The psyker creates a shimmering energy field that deflects incoming attacks. The barrier shimmers with psychic energy, providing protection to the target.",
  "target_type": "any",
  "range": "line_of_sight",
  "persists": true,
  "affects_robotic": true,
  "dlc_required": "trailblazers_toolkit",
  "source": "Trailblazer's Toolkit",
  "cost": 4,
  "difficulty": "basic",
  "activation": {
    "type": "combat_action",
    "activation_roll": "4+",
    "duration": "Until caster's next activation"
  },
  "effects": [
    {
      "name": "Energy Shield",
      "description": "Target gains a 4+ armor save against all attacks. If target already has armor, they may re-roll failed armor saves instead."
    }
  ]
}
```

### Validation Rules

1. **Required Fields**: All fields must be present
2. **Target Type**: Must be one of: `self`, `enemy`, `any`
3. **Range**: Must be one of: `self`, `6"`, `12"`, `line_of_sight`
4. **Cost Range**: Must be 3-7 XP
5. **Difficulty**: Must be one of: `basic`, `intermediate`, `advanced`
6. **Activation Roll**: Must be one of: `4+`, `5+`, `6+`, `7+`
7. **Action Type**: Must be one of: `combat_action`, `movement_action`
8. **Effects**: At least 1 effect required
9. **Cost-Difficulty Correlation**: Cost should match difficulty tier guidelines
10. **Robotic Restriction**: Mind-affecting powers should have `affects_robotic: false`

---

## Elite Enemies Format

### Schema

```json
{
  "name": "String",
  "enemy_type": "String",
  "combat_skill": "String (+0 to +3)",
  "toughness": Integer (3-6),
  "speed": "String (4\"-6\")",
  "reactions": Integer (1-3),
  "weapons": ["String"],
  "special_abilities": [
    {
      "name": "String",
      "effect": "String"
    }
  ],
  "dlc_required": "String",
  "source": "String",
  "deployment_points": Integer (2-5)
}
```

### Field Specifications

#### Root Fields

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `name` | String | Yes | Elite enemy name | `"Elite Mercenary"` |
| `enemy_type` | String | Yes | Base enemy type | `"Mercenary"` |
| `combat_skill` | String | Yes | Bonus to hit (+0 to +3) | `"+2"` |
| `toughness` | Integer | Yes | Damage threshold (3-6) | `4` |
| `speed` | String | Yes | Movement distance (4"-6") | `"5\""` |
| `reactions` | Integer | Yes | Initiative bonus (1-3) | `2` |
| `weapons` | Array[String] | Yes | Equipped weapons | `["Military Rifle", "Frag Grenade"]` |
| `dlc_required` | String | Yes | DLC identifier | `"freelancers_handbook"` |
| `source` | String | Yes | Source expansion | `"Freelancer's Handbook"` |
| `deployment_points` | Integer | Yes | Point cost (2-5) | `3` |

#### special_abilities Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Ability name (2-4 words) |
| `effect` | String | Yes | Detailed mechanical effect |

### Stat Comparison Table

| Stat | Standard | Elite Typical | Elite Max |
|------|----------|---------------|-----------|
| Combat Skill | +0 | +1 to +2 | +3 |
| Toughness | 3 | 4 | 6 |
| Speed | 4" | 5" | 6" |
| Reactions | 1 | 2 | 3 |
| Abilities | 0-1 | 2-3 | 4 |

### Deployment Point Formula

```
Base: 1 DP (standard enemy)

Modifiers:
+ Combat Skill increase: ×1 DP per +1
+ Toughness increase: ×1 DP per +1
+ Speed increase: ×0.5 DP per +1"
+ Reactions increase: ×0.5 DP per +1
+ Special Abilities: ×0.5-1 DP per ability

Result: Round to nearest integer (minimum 2, maximum 5)
```

**Example (Elite Mercenary)**:
- Combat Skill +2 (vs +0): +2 DP
- Toughness 4 (vs 3): +1 DP
- Reactions 2 (vs 1): +0.5 DP
- 2 abilities: +1.5 DP
- Total: 1 + 2 + 1 + 0.5 + 1.5 = 6 → **3 DP** (rounded)

### Complete Example

```json
{
  "name": "Elite Mercenary",
  "enemy_type": "Mercenary",
  "combat_skill": "+2",
  "toughness": 4,
  "speed": "5\"",
  "reactions": 2,
  "weapons": [
    "Military Rifle",
    "Frag Grenade"
  ],
  "special_abilities": [
    {
      "name": "Combat Veteran",
      "effect": "May re-roll one missed attack per round. Represents years of combat experience and tactical training."
    },
    {
      "name": "Tactical Positioning",
      "effect": "After making a ranged attack, may move up to 2\" without triggering reactions. Represents advanced battlefield movement techniques."
    }
  ],
  "dlc_required": "freelancers_handbook",
  "source": "Freelancer's Handbook",
  "deployment_points": 3
}
```

### Validation Rules

1. **Required Fields**: All fields must be present
2. **Combat Skill Format**: Must match pattern `\+\d+` and be 0-3
3. **Toughness Range**: Must be 3-6
4. **Speed Format**: Must match pattern `\d+"` and be 4"-6"
5. **Reactions Range**: Must be 1-3
6. **Weapons**: At least 1 weapon required
7. **Abilities**: At least 1 special ability required (2-3 recommended)
8. **Deployment Points**: Must be 2-5
9. **Point Calculation**: Calculated DP should match formula (±1 acceptable)
10. **Base Enemy**: enemy_type should reference a valid base enemy

---

## Difficulty Modifiers Format

### Schema

```json
{
  "name": "String",
  "description": "String",
  "category": "enemy_enhancement|battle_conditions|resource_scarcity|stakes",
  "mechanical_changes": {
    "enemy_toughness": Integer (optional),
    "enemy_combat_skill": Integer (optional),
    "enemy_count": Float (optional),
    "deployment_points": Float (optional),
    "injury_severity": Integer (optional),
    "credits_modifier": Float (optional),
    "loot_modifier": Float (optional),
    "morale_penalty": Integer (optional)
  },
  "flavor_effects": ["String"],
  "dlc_required": "String",
  "source": "String",
  "stacks_with": ["String"]
}
```

### Field Specifications

#### Root Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Modifier name (2-5 words) |
| `description` | String | Yes | Effect explanation (2-3 sentences) |
| `category` | String | Yes | Modifier category (see categories below) |
| `dlc_required` | String | Yes | DLC identifier |
| `source` | String | Yes | Source expansion |
| `stacks_with` | Array[String] | Yes | Compatible modifiers (can be empty) |

#### Categories

| Category | Description | Examples |
|----------|-------------|----------|
| `enemy_enhancement` | Makes enemies stronger | Brutal Foes, Elite Foes |
| `battle_conditions` | Changes combat environment | Larger Battles, Veteran Opposition |
| `resource_scarcity` | Reduces rewards/resources | Scarcity |
| `stakes` | Increases risks | High Stakes, Lethal Encounters, Desperate Combat |

#### mechanical_changes Fields

All fields are **optional** - include only those that apply.

| Field | Type | Effect | Range |
|-------|------|--------|-------|
| `enemy_toughness` | Integer | Increase enemy Toughness | +1 to +2 |
| `enemy_combat_skill` | Integer | Increase enemy Combat Skill | +1 to +2 |
| `enemy_count` | Float | Multiply enemy count | 1.25 to 2.0 |
| `deployment_points` | Float | Multiply deployment points | 1.25 to 2.0 |
| `injury_severity` | Integer | Increase injury roll | +1 to +2 |
| `credits_modifier` | Float | Multiply credit rewards | 0.5 to 2.0 |
| `loot_modifier` | Float | Multiply loot chance | 0.5 to 1.5 |
| `morale_penalty` | Integer | Penalty to morale tests | -1 to -2 |

### Stacking Rules

**Same Category**: Most modifiers in the same category do NOT stack.

**Exception**: `Brutal Foes` + `Elite Foes` can stack (additive).

**Cross-Category**: Modifiers from different categories generally stack (multiplicative for percentages, additive for flat bonuses).

**Example**:
```
Brutal Foes (+1 Toughness) + Larger Battles (+50% enemies) = Both apply
Brutal Foes + Elite Foes = +2 Toughness total
Brutal Foes + Veteran Opposition = Do NOT stack (both enemy_enhancement)
```

### Complete Example

```json
{
  "name": "Brutal Foes",
  "description": "Enemies are tougher and more resilient than usual. They can withstand more punishment and keep fighting. This represents facing elite troops, heavily armored opponents, or naturally durable alien species.",
  "category": "enemy_enhancement",
  "mechanical_changes": {
    "enemy_toughness": 1
  },
  "flavor_effects": [
    "Enemies appear more heavily armored",
    "Combat lasts longer",
    "Crew may need to focus fire to bring down targets"
  ],
  "dlc_required": "freelancers_handbook",
  "source": "Freelancer's Handbook",
  "stacks_with": [
    "Elite Foes",
    "Larger Battles",
    "High Stakes"
  ]
}
```

### Validation Rules

1. **Required Fields**: name, description, category, dlc_required, source, stacks_with
2. **Category**: Must be one of the four defined categories
3. **Mechanical Changes**: At least 1 mechanical change required
4. **Stat Ranges**: All mechanical changes must be within specified ranges
5. **Multipliers**: Must be greater than 0.0 and less than 5.0
6. **Stacks With**: Can be empty array, but field must be present
7. **Flavor Effects**: Optional but recommended (1-3 items)

---

## Equipment & Weapons Format

### Weapon Schema

```json
{
  "name": "String",
  "type": "melee|pistol|rifle|heavy|special",
  "range": "String (melee|6\"|12\"|18\"|24\")",
  "shots": Integer (1-6),
  "damage": Integer (1-3),
  "traits": ["String"],
  "cost": Integer,
  "rarity": "common|uncommon|rare|very_rare",
  "dlc_required": "String (optional)",
  "source": "String (optional)",
  "description": "String"
}
```

### Equipment Schema

```json
{
  "name": "String",
  "type": "armor|gear|consumable|cybernetic",
  "effect": "String",
  "mechanical_effect": "String",
  "cost": Integer,
  "rarity": "common|uncommon|rare|very_rare",
  "dlc_required": "String (optional)",
  "source": "String (optional)",
  "description": "String"
}
```

### Weapon Field Specifications

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `name` | String | Yes | Weapon name | `"Plasma Rifle"` |
| `type` | String | Yes | Weapon category | `"rifle"` |
| `range` | String | Yes | Maximum range | `"18\""` or `"melee"` |
| `shots` | Integer | Yes | Attacks per activation | `2` |
| `damage` | Integer | Yes | Damage value | `2` |
| `traits` | Array[String] | Yes | Special rules (can be empty) | `["Piercing", "Energy"]` |
| `cost` | Integer | Yes | Price in credits | `800` |
| `rarity` | String | Yes | Availability tier | `"rare"` |
| `description` | String | Yes | Flavor text | `"High-tech energy weapon..."` |

### Equipment Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | Equipment name |
| `type` | String | Yes | Equipment category |
| `effect` | String | Yes | Flavor description |
| `mechanical_effect` | String | Yes | Exact game mechanics |
| `cost` | Integer | Yes | Price in credits |
| `rarity` | String | Yes | Availability tier |
| `description` | String | Yes | Flavor text |

### Weapon Traits

Common weapon traits:

| Trait | Effect |
|-------|--------|
| `Piercing` | Ignores 1 point of armor |
| `Energy` | Counts as energy weapon (special interactions) |
| `Blast` | Affects 3" radius |
| `Single Shot` | Can only fire once per battle |
| `Melee` | Close combat weapon |
| `Heavy` | Requires both hands, -1" movement |
| `Snap Fire` | Can shoot after moving |
| `Auto` | +1 shot at close range |

### Complete Weapon Example

```json
{
  "name": "Plasma Cutter",
  "type": "pistol",
  "range": "6\"",
  "shots": 1,
  "damage": 2,
  "traits": [
    "Piercing",
    "Energy"
  ],
  "cost": 450,
  "rarity": "uncommon",
  "dlc_required": "custom_expansion",
  "source": "Custom Expansion",
  "description": "An industrial plasma torch modified for combat use. The superheated plasma stream can cut through armor plating with ease, though its range is limited."
}
```

### Complete Equipment Example

```json
{
  "name": "Reflective Cloak",
  "type": "gear",
  "effect": "A shimmering cloak that bends light and energy around the wearer.",
  "mechanical_effect": "Gain a 5+ save against energy weapons. When save is successful, reflect the attack back at the attacker (they must make a saving throw).",
  "cost": 600,
  "rarity": "rare",
  "dlc_required": "custom_expansion",
  "source": "Custom Expansion",
  "description": "Woven with reflective fibers, this cloak provides protection against energy-based attacks while turning the enemy's firepower against them."
}
```

### Validation Rules

#### Weapons
1. **Type**: Must be one of: `melee`, `pistol`, `rifle`, `heavy`, `special`
2. **Range**: Must be `melee` or match pattern `\d+"`
3. **Shots**: Must be 1-6
4. **Damage**: Must be 1-3
5. **Cost**: Must be positive integer
6. **Rarity**: Must be one of: `common`, `uncommon`, `rare`, `very_rare`
7. **Traits**: Can be empty array

#### Equipment
1. **Type**: Must be one of: `armor`, `gear`, `consumable`, `cybernetic`
2. **Both effect and mechanical_effect required**: One for flavor, one for mechanics
3. **Cost**: Must be positive integer
4. **Rarity**: Must be one of: `common`, `uncommon`, `rare`, `very_rare`

---

## Mission Content Types

## Stealth Missions Format

### Schema

```json
{
  "name": "String",
  "type": "stealth",
  "description": "String",
  "objectives": [
    {
      "type": "String",
      "description": "String",
      "success_condition": "String"
    }
  ],
  "stealth_mechanics": {
    "alarm_system": {
      "initial_level": Integer (0-5),
      "maximum_level": Integer (3-5),
      "escalation_triggers": [
        {
          "trigger": "String",
          "alarm_increase": "Integer or String (dice notation)"
        }
      ],
      "alarm_effects": [
        {
          "level": Integer,
          "effect": "String"
        }
      ]
    },
    "detection_rules": {
      "base_detection": "String (formula)",
      "cover_modifiers": {
        "full_cover": "String",
        "partial_cover": "String"
      },
      "special_conditions": ["String"]
    }
  },
  "deployment_conditions": {
    "enemy_count": "String or Integer",
    "enemy_types": ["String"],
    "special_terrain": ["String"],
    "special_rules": ["String"]
  },
  "rewards": {
    "credits": "String (range)",
    "loot_rolls": Integer,
    "special_rewards": ["String"]
  },
  "dlc_required": "String",
  "source": "String"
}
```

### Field Specifications

#### alarm_system Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `initial_level` | Integer | Starting alarm (0-5) | `0` |
| `maximum_level` | Integer | Max before failure (3-5) | `5` |
| `escalation_triggers` | Array | Events that raise alarm | See below |
| `alarm_effects` | Array | Effects at each level | See below |

#### Escalation Trigger Format

```json
{
  "trigger": "Crew member spotted by guard",
  "alarm_increase": 1
}
```

or with dice:

```json
{
  "trigger": "Gunfire",
  "alarm_increase": "1D3"
}
```

#### Alarm Effect Format

```json
{
  "level": 2,
  "effect": "Additional patrol spawns. Add 1 guard to the battlefield."
}
```

#### detection_rules Fields

| Field | Type | Description |
|-------|------|-------------|
| `base_detection` | String | Detection formula |
| `cover_modifiers` | Object | Cover bonuses/penalties |
| `special_conditions` | Array | Additional rules |

**Base Detection Formula**: `"1D6 + Guard Savvy + Cover Modifier vs Crew Savvy"`

### Complete Example

```json
{
  "name": "Corporate Infiltration",
  "type": "stealth",
  "description": "Infiltrate a secure corporate facility to steal sensitive data. Guards patrol the corridors, and security systems monitor for intruders. Getting caught will trigger lockdown procedures.",
  "objectives": [
    {
      "type": "Data Theft",
      "description": "Access the central terminal and download encrypted files",
      "success_condition": "Crew member in base contact with terminal for 1 full round, then pass Savvy+1 test"
    },
    {
      "type": "Escape",
      "description": "Exit through the designated extraction point",
      "success_condition": "All surviving crew members exit battlefield through extraction zone"
    }
  ],
  "stealth_mechanics": {
    "alarm_system": {
      "initial_level": 0,
      "maximum_level": 5,
      "escalation_triggers": [
        {
          "trigger": "Crew member spotted by guard",
          "alarm_increase": 1
        },
        {
          "trigger": "Gunfire",
          "alarm_increase": "1D3"
        },
        {
          "trigger": "Guard knocked out but not killed",
          "alarm_increase": 1
        },
        {
          "trigger": "Security camera triggered",
          "alarm_increase": 1
        }
      ],
      "alarm_effects": [
        {
          "level": 1,
          "effect": "Guards become more alert. All detection rolls at +1."
        },
        {
          "level": 2,
          "effect": "Additional patrol spawns. Add 1 guard to the battlefield."
        },
        {
          "level": 3,
          "effect": "Guards move faster. All guards gain +2\" movement."
        },
        {
          "level": 4,
          "effect": "Reinforcements called. Add 3 deployment points of enemies."
        },
        {
          "level": 5,
          "effect": "Full lockdown initiated. Mission fails in 3 rounds if not completed."
        }
      ]
    },
    "detection_rules": {
      "base_detection": "1D6 + Guard Savvy + Cover Modifier vs Crew Savvy",
      "cover_modifiers": {
        "full_cover": "Crew member is invisible (cannot be detected)",
        "partial_cover": "Guard rolls at -2"
      },
      "special_conditions": [
        "Running adds +1 to guard detection rolls",
        "Firing weapons causes automatic detection by all guards within 12\"",
        "Darkness provides -1 to all guard detection rolls"
      ]
    }
  },
  "deployment_conditions": {
    "enemy_count": "6+1D3",
    "enemy_types": [
      "Corporate Security Guard",
      "Security Drone"
    ],
    "special_terrain": [
      "Security Cameras (detect crew within 6\" arc)",
      "Server Racks (full cover)",
      "Workstations (partial cover)"
    ],
    "special_rules": [
      "Guards patrol in pairs",
      "Interior lighting (no darkness penalties unless crew disables power)",
      "Crew can attempt to hack cameras (Savvy test)"
    ]
  },
  "rewards": {
    "credits": "2D6+4 (×100)",
    "loot_rolls": 2,
    "special_rewards": [
      "Stolen corporate data (can sell for 1D6×100 credits)",
      "Access codes (reduce difficulty of future corporate missions)"
    ]
  },
  "dlc_required": "fixers_guidebook",
  "source": "Fixer's Guidebook"
}
```

### Validation Rules

1. **Type**: Must be `"stealth"`
2. **Objectives**: At least 1 required
3. **Alarm Levels**: initial_level ≤ maximum_level, both 0-5
4. **Escalation Triggers**: At least 2 required
5. **Alarm Effects**: Must have effect for each level 1 through maximum_level
6. **Detection Formula**: Must include base detection rule
7. **Enemy Count**: Can be integer or dice notation
8. **Rewards**: At least credits or loot_rolls required

---

## Salvage Jobs Format

### Schema

```json
{
  "name": "String",
  "type": "salvage",
  "description": "String",
  "objectives": [
    {
      "type": "String",
      "description": "String",
      "success_condition": "String"
    }
  ],
  "salvage_mechanics": {
    "tension_system": {
      "initial_tension": Integer (0-10),
      "maximum_tension": Integer (8-10),
      "tension_triggers": [
        {
          "trigger": "String",
          "tension_increase": Integer
        }
      ]
    },
    "discovery_table": [
      {
        "roll_range": "String (e.g., '1-3')",
        "result": "String"
      }
    ],
    "encounter_tables": [
      {
        "tension_threshold": Integer,
        "encounters": [
          {
            "roll": "String (e.g., '1-2')",
            "encounter": "String"
          }
        ]
      }
    ]
  },
  "deployment_conditions": {
    "enemy_presence": "String",
    "environmental_hazards": ["String"],
    "special_terrain": ["String"],
    "special_rules": ["String"]
  },
  "rewards": {
    "salvage_value": "String (range)",
    "discovery_rolls": Integer,
    "special_rewards": ["String"]
  },
  "dlc_required": "String",
  "source": "String"
}
```

### Field Specifications

#### tension_system Fields

| Field | Type | Description | Range |
|-------|------|-------------|-------|
| `initial_tension` | Integer | Starting tension | 0-10 |
| `maximum_tension` | Integer | Max tension level | 8-10 |
| `tension_triggers` | Array | Events that raise tension | See below |

#### Tension Trigger Format

```json
{
  "trigger": "Each round that passes",
  "tension_increase": 1
}
```

#### discovery_table Format

Standard 1D10 table:

```json
{
  "roll_range": "1-3",
  "result": "Nothing of value. Scrap metal and debris only."
}
```

#### encounter_tables Format

```json
{
  "tension_threshold": 5,
  "encounters": [
    {
      "roll": "1-2",
      "encounter": "Automated defense system activates. Add 1 Security Drone."
    }
  ]
}
```

### Complete Example

```json
{
  "name": "Derelict Ship",
  "type": "salvage",
  "description": "A derelict spacecraft drifts in orbit, its crew long gone. Valuable salvage awaits inside, but the ship's automated systems may still be active, and who knows what else lurks in the dark corridors.",
  "objectives": [
    {
      "type": "Salvage Recovery",
      "description": "Search the ship for valuable salvage",
      "success_condition": "Make at least 3 salvage discovery rolls (one per crew member per action)"
    },
    {
      "type": "Survival",
      "description": "Escape before the ship becomes too dangerous",
      "success_condition": "All surviving crew members exit the ship before tension reaches maximum"
    }
  ],
  "salvage_mechanics": {
    "tension_system": {
      "initial_tension": 2,
      "maximum_tension": 10,
      "tension_triggers": [
        {
          "trigger": "Each round that passes",
          "tension_increase": 1
        },
        {
          "trigger": "Loud noise (gunfire, explosion)",
          "tension_increase": 2
        },
        {
          "trigger": "Opening sealed doors",
          "tension_increase": 1
        },
        {
          "trigger": "Activating ship systems",
          "tension_increase": 1
        }
      ]
    },
    "discovery_table": [
      {
        "roll_range": "1-3",
        "result": "Nothing of value. Scrap metal and debris only."
      },
      {
        "roll_range": "4-5",
        "result": "Scrap parts. Worth 1D6×10 credits."
      },
      {
        "roll_range": "6-7",
        "result": "Ship components. Worth 1D6×25 credits."
      },
      {
        "roll_range": "8-9",
        "result": "Intact equipment. Roll on standard loot table."
      },
      {
        "roll_range": "10",
        "result": "Rare find. Roll on rare loot table or find special item (GM choice)."
      }
    ],
    "encounter_tables": [
      {
        "tension_threshold": 5,
        "encounters": [
          {
            "roll": "1-2",
            "encounter": "Automated defense system activates. Add 1 Security Drone."
          },
          {
            "roll": "3-4",
            "encounter": "Hull breach! All crew must pass Savvy test or take 1 hit from debris."
          },
          {
            "roll": "5-6",
            "encounter": "Life signs detected. Add 1D3 Converted (former crew)."
          }
        ]
      },
      {
        "tension_threshold": 8,
        "encounters": [
          {
            "roll": "1-2",
            "encounter": "Ship systems failing. Add environmental hazard: Radiation (1 hit per round, ignores armor)."
          },
          {
            "roll": "3-4",
            "encounter": "Swarm! Add 2D3 Converted."
          },
          {
            "roll": "5-6",
            "encounter": "Critical system failure. Ship will explode in 1D3+1 rounds. All crew must evacuate."
          }
        ]
      }
    ]
  },
  "deployment_conditions": {
    "enemy_presence": "None initially. Enemies appear through encounter tables.",
    "environmental_hazards": [
      "Zero gravity (halve all movement, special rules apply)",
      "Darkness (all ranged attacks at -1 beyond 6\")",
      "Unstable atmosphere (pressure suit required or suffer 1 hit per round)"
    ],
    "special_terrain": [
      "Sealed doors (require Savvy test to open)",
      "Cargo containers (can be searched for salvage)",
      "Control panels (can attempt to reduce tension by 1D3, Savvy+1 test)",
      "Airlocks (exit points)"
    ],
    "special_rules": [
      "Crew can search once per activation (roll on discovery table)",
      "At the start of each round, check for encounters if tension ≥ threshold",
      "Tension can be reduced by crew actions (repairing systems, etc.)",
      "Mission ends when all crew exit or tension reaches maximum"
    ]
  },
  "rewards": {
    "salvage_value": "Base: 1D6×50 credits + discovery rolls",
    "discovery_rolls": 3,
    "special_rewards": [
      "Ship schematics (bonus to ship combat or can sell for 2D6×100 credits)",
      "Intact ship AI core (valuable tech, 1D6×200 credits or use for ship upgrade)"
    ]
  },
  "dlc_required": "fixers_guidebook",
  "source": "Fixer's Guidebook"
}
```

### Validation Rules

1. **Type**: Must be `"salvage"`
2. **Objectives**: At least 1 required
3. **Tension Levels**: initial_tension ≤ maximum_tension, both 0-10
4. **Tension Triggers**: At least 2 required
5. **Discovery Table**: Must have 10 entries (1D10 table)
6. **Encounter Tables**: At least 1 threshold required
7. **Each Encounter Table**: Must have 3-6 encounters
8. **Rewards**: Must specify salvage_value or discovery_rolls

---

## General Missions Format

### Schema

```json
{
  "name": "String",
  "type": "String",
  "description": "String",
  "objectives": [
    {
      "type": "String",
      "description": "String",
      "success_condition": "String"
    }
  ],
  "deployment_conditions": {
    "enemy_count": "String or Integer",
    "enemy_types": ["String"],
    "battlefield_size": "String",
    "terrain_requirements": ["String"],
    "special_rules": ["String"]
  },
  "special_mechanics": {
    "custom_system_name": {
      "field1": "value",
      "field2": "value"
    }
  },
  "rewards": {
    "credits": "String (range)",
    "loot_rolls": Integer,
    "xp_bonus": Integer,
    "special_rewards": ["String"]
  },
  "dlc_required": "String (optional)",
  "source": "String (optional)"
}
```

### Mission Types

| Type | Description | Example |
|------|-------------|---------|
| `bounty_hunt` | Track and capture/eliminate target | Bounty Hunter mission |
| `defense` | Hold position against waves | Defend Settlement |
| `escort` | Protect target moving across map | VIP Escort |
| `retrieval` | Recover item/person | Data Recovery |
| `patrol` | Search area, encounter enemies | Security Patrol |
| `assassination` | Eliminate specific target | Contract Kill |
| `sabotage` | Destroy enemy assets | Sabotage Facility |
| `custom` | Custom mission type | Any unique mission |

### Complete Example

```json
{
  "name": "Asteroid Mining Raid",
  "type": "custom",
  "description": "Raid a remote asteroid mining operation to steal valuable ore. The facility operates in a low-oxygen environment, requiring crew to manage oxygen levels while fighting off security forces.",
  "objectives": [
    {
      "type": "Theft",
      "description": "Steal at least 3 units of processed ore from the refinery",
      "success_condition": "Crew members carry 3 ore crates to extraction point"
    },
    {
      "type": "Survival",
      "description": "Escape with the ore before oxygen runs out",
      "success_condition": "All surviving crew exit battlefield with oxygen remaining"
    }
  ],
  "deployment_conditions": {
    "enemy_count": "8",
    "enemy_types": [
      "Mining Security",
      "Security Drone"
    ],
    "battlefield_size": "36\" × 36\"",
    "terrain_requirements": [
      "Mining equipment (partial cover)",
      "Ore refinery (objective location)",
      "Oxygen stations (special terrain)",
      "Extraction point (exit zone)"
    ],
    "special_rules": [
      "Low gravity: All movement +2\", jumping distances doubled",
      "Oxygen depletion: See special mechanics",
      "Ore crates: Heavy (reduce carrier speed by 2\")"
    ]
  },
  "special_mechanics": {
    "oxygen_system": {
      "initial_oxygen": 10,
      "depletion_rate": 1,
      "oxygen_stations": "Crew can refill at oxygen stations (costs 1 activation)",
      "oxygen_effects": [
        {
          "level": 3,
          "effect": "Crew becomes fatigued. All actions at -1."
        },
        {
          "level": 0,
          "effect": "Crew member incapacitated. Removed from battle."
        }
      ]
    }
  },
  "rewards": {
    "credits": "3D6×100",
    "loot_rolls": 1,
    "xp_bonus": 2,
    "special_rewards": [
      "Stolen ore (bonus 1D6×50 credits if sold quickly)",
      "Mining equipment (can use or sell for 1D6×25 credits)"
    ]
  },
  "dlc_required": "custom_expansion",
  "source": "Custom Expansion"
}
```

### Validation Rules

1. **Type**: Must be valid mission type (see table)
2. **Objectives**: At least 1 required
3. **Enemy Count**: Can be integer or dice notation
4. **Enemy Types**: At least 1 required
5. **Special Mechanics**: Optional, but if present must have at least 1 field
6. **Rewards**: At least one of: credits, loot_rolls, xp_bonus, or special_rewards

---

## Validation Rules

### File-Level Validation

#### JSON Structure
1. **Valid JSON**: File must parse as valid JSON (no syntax errors)
2. **UTF-8 Encoding**: File must be UTF-8 encoded
3. **Root Object**: Top-level structure varies by content type:
   - Single content: `{ "field1": "value", ... }`
   - Multiple content: `{ "content_type": [ {...}, {...} ] }`

#### Required Fields
Every content type must have:
- `name` (String)
- `description` (String)
- `dlc_required` (String) - for DLC content
- `source` (String) - for DLC content

### Content-Specific Validation

See individual format sections for detailed validation rules.

### Cross-Reference Validation

#### DLC Identifiers
- `dlc_required` must match a directory in `/data/dlc/`
- Valid identifiers: `trailblazers_toolkit`, `freelancers_handbook`, `fixers_guidebook`, `bug_hunt`, or custom expansion names

#### Enemy Types (Elite Enemies)
- `enemy_type` should reference a valid base enemy
- Recommended: Mercenary, Raider, Pirate, Alien, Guard, Enforcer

#### Weapons (Elite Enemies, Equipment)
- Weapon names in `weapons` array should match entries in weapon data files
- Common weapons: Military Rifle, Hand Cannon, Blade, Frag Grenade, etc.

### Balance Validation

#### Species
- Net stat modification: -2 to +2 (recommended: 0)
- At least 1 special rule required
- No stat outside normal ranges (Reactions 0-3, Toughness 2-6, etc.)

#### Psionic Powers
- Cost matches difficulty tier:
  - Basic: 3-4 XP
  - Intermediate: 4-5 XP
  - Advanced: 5-7 XP
- Activation roll matches difficulty:
  - Basic: 4+
  - Intermediate: 5+
  - Advanced: 6+ or 7+

#### Elite Enemies
- Deployment points calculation within ±1 of formula
- At least 1 special ability
- All stats superior to base enemy type

#### Difficulty Modifiers
- All mechanical changes within specified ranges
- At least 1 mechanical change
- Stacks_with list contains only valid modifier names

### Testing Validation

Content should be tested for:
1. **Load Test**: File loads without errors in ExpansionManager
2. **Display Test**: Content displays correctly in UI
3. **Functional Test**: Content works in gameplay
4. **Balance Test**: Content provides appropriate challenge/reward

See **Testing & Validation Guide** (separate document) for detailed methodology.

---

## Common Patterns

### Dice Notation

Used throughout data files for random values.

**Format**: `[count]D[size][+/-modifier]`

**Examples**:
- `1D6` - Roll 1 six-sided die (1-6)
- `2D6` - Roll 2 six-sided dice, sum them (2-12)
- `1D3` - Roll 1 three-sided die (1-3)
- `1D6+2` - Roll 1D6 and add 2 (3-8)
- `2D6-1` - Roll 2D6 and subtract 1 (1-11)

**Parsing in Code**:
```gdscript
func _roll_dice_notation(notation: String) -> int:
    var parts := notation.split("D")
    var num_dice := int(parts[0])
    var die_size := int(parts[1])

    var total := 0
    for i in range(num_dice):
        total += randi() % die_size + 1

    return total
```

### Range Notation

Used for distances in the game.

**Format**: `[number]\"`

**Examples**:
- `6"` - 6 inches
- `12"` - 12 inches
- `melee` - Touch distance
- `line_of_sight` - Any visible target

### Value Ranges

Used in rewards, costs, etc.

**Format**: `[min]-[max]` or `[dice] (×multiplier)`

**Examples**:
- `100-500` - Value between 100 and 500
- `2D6×100` - Roll 2D6, multiply by 100 (200-1200)
- `1D6+4 (×100)` - Roll 1D6+4, multiply by 100 (500-1000)

### Stat Modifiers

Used for skill bonuses/penalties.

**Format**: `[+/-][number]`

**Examples**:
- `+0` - No modifier
- `+1` - Bonus of 1
- `+2` - Bonus of 2
- `-1` - Penalty of 1

**Always include sign**: Even for +0, use `"+0"` not `"0"`

### Target Numbers

Used for success rolls.

**Format**: `[number]+`

**Examples**:
- `4+` - Need 4 or higher to succeed
- `5+` - Need 5 or higher to succeed
- `6+` - Need 6 or higher to succeed

**Rolling**: Usually `1D6 + modifier ≥ target number`

### Duration Formats

Used for power duration, effect duration, etc.

**Formats**:
- `Instant` - Immediate, no duration
- `1D3 rounds` - Lasts for dice-rolled rounds
- `Until [event]` - Lasts until specific event
- `Concentration` - Lasts while character concentrates
- `Permanent` - Does not expire

**Examples**:
- `"Until caster's next activation"`
- `"Until end of battle"`
- `"1D3 rounds"`
- `"Concentration (caster cannot take other actions)"`

### Effect Stacking

How multiple effects combine.

**Additive**: Effects add together
- Example: +1 Toughness + +1 Toughness = +2 Toughness

**Multiplicative**: Effects multiply together
- Example: ×1.5 enemies × ×1.25 enemies = ×1.875 enemies

**Best-Of**: Use best effect, ignore others
- Example: 4+ armor save and 5+ armor save = use 4+ save

**Non-Stacking**: Effects do not combine
- Example: Difficulty modifiers from same category

---

## Field Reference

### Alphabetical Field Index

| Field | Type | Used In | Description |
|-------|------|---------|-------------|
| `activation` | Object | Psionic Powers | Activation rules (type, roll, duration) |
| `activation_roll` | String | Psionic Powers | Target number (4+, 5+, etc.) |
| `affects_robotic` | Boolean | Psionic Powers | Can target robots? |
| `alarm_effects` | Array | Stealth Missions | Effects at alarm levels |
| `alarm_system` | Object | Stealth Missions | Alarm mechanics |
| `base_detection` | String | Stealth Missions | Detection formula |
| `base_profile` | Object | Species | Stat block |
| `battlefield_size` | String | Missions | Map dimensions |
| `category` | String | Difficulty Modifiers | Modifier category |
| `combat_skill` | String | Species, Elite Enemies | Combat bonus |
| `cost` | Integer | Powers, Equipment | XP or credit cost |
| `cover_modifiers` | Object | Stealth Missions | Cover effects |
| `credits` | String | Missions | Credit reward |
| `credits_modifier` | Float | Difficulty Modifiers | Credit multiplier |
| `damage` | Integer | Weapons | Damage value |
| `deployment_conditions` | Object | Missions | Battle setup |
| `deployment_points` | Integer | Elite Enemies | Point cost |
| `description` | String | All | Flavor text |
| `difficulty` | String | Psionic Powers | Power tier |
| `discovery_rolls` | Integer | Salvage Jobs | Number of discovery rolls |
| `discovery_table` | Array | Salvage Jobs | Salvage discovery results |
| `dlc_required` | String | All DLC | DLC identifier |
| `duration` | String | Psionic Powers | Effect duration |
| `effect` | String | Equipment, Abilities | Effect description |
| `effects` | Array | Psionic Powers | Power effects |
| `enabled` | Boolean | Various | Feature toggle |
| `encounter_tables` | Array | Salvage Jobs | Random encounters |
| `enemy_combat_skill` | Integer | Difficulty Modifiers | Combat skill increase |
| `enemy_count` | String/Integer | Missions, Modifiers | Number of enemies |
| `enemy_presence` | String | Salvage Jobs | Enemy deployment |
| `enemy_toughness` | Integer | Difficulty Modifiers | Toughness increase |
| `enemy_type` | String | Elite Enemies | Base enemy reference |
| `enemy_types` | Array | Missions | Enemy list |
| `environmental_hazards` | Array | Missions | Hazards on battlefield |
| `escalation_triggers` | Array | Stealth Missions | Alarm triggers |
| `flavor_effects` | Array | Difficulty Modifiers | Narrative effects |
| `homeworld` | String | Species | Planet of origin |
| `initial_level` | Integer | Stealth Missions | Starting alarm |
| `initial_tension` | Integer | Salvage Jobs | Starting tension |
| `injury_severity` | Integer | Difficulty Modifiers | Injury increase |
| `loot_modifier` | Float | Difficulty Modifiers | Loot multiplier |
| `loot_rolls` | Integer | Missions | Number of loot rolls |
| `maximum_level` | Integer | Stealth/Salvage | Maximum level |
| `mechanical_changes` | Object | Difficulty Modifiers | Stat modifications |
| `mechanical_effect` | String | Species, Equipment | Exact mechanics |
| `morale_penalty` | Integer | Difficulty Modifiers | Morale modifier |
| `name` | String | All | Display name |
| `objectives` | Array | Missions | Mission goals |
| `persists` | Boolean | Psionic Powers | Duration > instant? |
| `playable` | Boolean | Species | Player accessible? |
| `range` | String | Powers, Weapons | Maximum range |
| `rarity` | String | Equipment, Weapons | Availability tier |
| `reactions` | Integer | Species, Elite Enemies | Initiative bonus |
| `rewards` | Object | Missions | Mission rewards |
| `salvage_mechanics` | Object | Salvage Jobs | Salvage system |
| `salvage_value` | String | Salvage Jobs | Value of salvage |
| `savvy` | String | Species | Savvy modifier |
| `shots` | Integer | Weapons | Attacks per action |
| `source` | String | All DLC | Source expansion |
| `special_abilities` | Array | Elite Enemies | Elite abilities |
| `special_conditions` | Array | Stealth Missions | Additional rules |
| `special_mechanics` | Object | Missions | Custom systems |
| `special_rewards` | Array | Missions | Unique rewards |
| `special_rules` | Array | Species, Missions | Special rules |
| `special_terrain` | Array | Missions | Terrain features |
| `speed` | String | Species, Elite Enemies | Movement distance |
| `stacks_with` | Array | Difficulty Modifiers | Compatible modifiers |
| `starting_bonus` | String | Species | Initial advantage |
| `success_condition` | String | Objectives | Win condition |
| `target_type` | String | Psionic Powers | Targeting rules |
| `tension_system` | Object | Salvage Jobs | Tension mechanics |
| `tension_threshold` | Integer | Salvage Jobs | Encounter trigger |
| `tension_triggers` | Array | Salvage Jobs | Tension increases |
| `terrain_requirements` | Array | Missions | Required terrain |
| `toughness` | Integer | Species, Elite Enemies | Damage threshold |
| `traits` | Array | Species, Weapons | Characteristics |
| `type` | String | All | Content type |
| `version` | String | Various | Content version |
| `weapons` | Array | Elite Enemies | Equipped weapons |
| `xp_bonus` | Integer | Missions | XP reward |

---

## Version History

### Version 1.0 (2024-11-16)

**Initial Release**

**Contents**:
- Complete schema specifications for 8 content types
- Validation rules for all formats
- Common patterns documentation
- Field reference index
- Complete examples for each type

**Coverage**:
- Species Format
- Psionic Powers Format
- Elite Enemies Format
- Difficulty Modifiers Format
- Equipment & Weapons Format
- Stealth Missions Format
- Salvage Jobs Format
- General Missions Format

**Statistics**:
- 8 complete schemas
- 90+ field definitions
- 15+ complete examples
- 50+ validation rules

---

## Support & Contributing

### Using This Document

**For Content Creators**:
1. Choose the content type you want to create
2. Copy the schema for that type
3. Fill in all required fields
4. Follow validation rules
5. Test your content

**For Developers**:
1. Use schemas for validation code
2. Reference field types for parsing
3. Follow common patterns for consistency
4. Implement validation rules in code

**For Modders**:
1. Study complete examples
2. Understand balance guidelines
3. Follow naming conventions
4. Test thoroughly before publishing

### Reporting Issues

If you find errors or inconsistencies in this specification:

1. **GitHub Issues**: Submit issue to repository
2. **Include**: Which content type, which field, what's wrong
3. **Provide**: Example of correct vs incorrect usage
4. **Suggest**: Improvement or clarification

### Contributing

To contribute to this specification:

1. **Propose Changes**: Via pull request
2. **Match Format**: Follow existing structure
3. **Add Examples**: For new content types
4. **Update Index**: Add fields to reference table
5. **Test**: Validate against existing content

---

## License

Documentation licensed under **CC-BY-4.0** (Creative Commons Attribution 4.0 International).

You are free to:
- **Share**: Copy and redistribute
- **Adapt**: Remix and build upon
- **Use Commercially**: For commercial projects

Under these terms:
- **Attribution**: Give appropriate credit
- **No Additional Restrictions**: Don't restrict others

---

**Document Version**: 1.0
**Last Updated**: 2024-11-16
**Maintained By**: Five Parsecs Campaign Manager Development Team

**Related Documentation**:
- [Expansion Documentation Index](./EXPANSION_DOCUMENTATION_INDEX.md)
- [Content Creation Guide](./CONTENT_CREATION_GUIDE.md)
- [Trailblazer's Toolkit Integration](./expansions/TRAILBLAZERS_TOOLKIT_INTEGRATION.md)
- [Freelancer's Handbook Integration](./expansions/FREELANCERS_HANDBOOK_INTEGRATION.md)
- [Fixer's Guidebook Integration](./expansions/FIXERS_GUIDEBOOK_INTEGRATION.md)
