# Content Creation Guide

## Overview

This guide teaches you how to create new content for the Five Parsecs Campaign Manager. Whether you want to add new species, psionic powers, enemies, equipment, or mission types, this guide provides step-by-step instructions with complete examples.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Creating Species](#creating-species)
3. [Creating Psionic Powers](#creating-psionic-powers)
4. [Creating Elite Enemies](#creating-elite-enemies)
5. [Creating Equipment & Weapons](#creating-equipment--weapons)
6. [Creating Mission Types](#creating-mission-types)
7. [Testing Your Content](#testing-your-content)
8. [Publishing Content](#publishing-content)

---

## Prerequisites

### Required Knowledge

- **JSON Format**: All content is defined in JSON files
- **GDScript Basics** (optional): For implementing complex behaviors
- **Five Parsecs Rules**: Understanding of core game mechanics

### Required Tools

- Text editor (VS Code, Sublime, Notepad++ recommended)
- JSON validator (built into most modern editors)
- Godot Engine 4.4+ (for testing)

### File Locations

```
data/
├── dlc/
│   ├── trailblazers_toolkit/      # Species & psionic powers
│   ├── freelancers_handbook/      # Elite enemies & difficulty
│   ├── fixers_guidebook/          # Missions
│   └── custom/                    # Your custom content
│       ├── species.json
│       ├── powers.json
│       ├── enemies.json
│       ├── equipment.json
│       └── missions.json
```

---

## Creating Species

### Step 1: Design the Species

**Template Questions**:
1. **What is their culture/personality?**
2. **What are they good at?** (Pick 1-2 strengths)
3. **What are they bad at?** (Pick 1-2 weaknesses)
4. **What makes them unique?** (Special ability or trait)

**Example Design: Crystalline**

- **Culture**: Silicon-based lifeforms from high-gravity worlds
- **Strengths**: Extremely tough, natural armor
- **Weaknesses**: Slow movement, brittle (injuries more severe)
- **Unique**: Crystalline Structure - reflect energy attacks

### Step 2: Create Stat Profile

**Balance Guidelines**:
- Total stat modifiers should sum to **~0**
- Example: +2 Toughness, -1 Speed, -1 Reactions = 0 total

**Crystalline Stats**:
```
Base Stats (Human = baseline):
- Reactions: 1 → 0 (-1)
- Speed: 4" → 3" (-1")
- Combat Skill: +0 → +0 (no change)
- Toughness: 3 → 5 (+2)
- Savvy: +0 → +0 (no change)

Total Modifiers: -1 Reactions, -1" Speed, +2 Toughness = 0 balance
```

### Step 3: Design Special Rules

**Rule Design Principles**:
- **Clear mechanics**: Specific numbers, not vague bonuses
- **Balanced trade-offs**: Powerful abilities have drawbacks
- **Interesting decisions**: Create tactical choices

**Crystalline Special Rules**:

1. **Crystalline Structure**
   - Mechanic: Reflect 50% of energy weapon damage back to attacker
   - Trade-off: Brittle - critical hits do +1 damage
   - Tactical: Choose positioning to maximize reflections

2. **Heavy Frame**
   - Mechanic: Natural Armor 6+ save
   - Trade-off: -1" Speed (already applied to base stats)
   - Tactical: Tank role in combat

3. **Silicon Metabolism**
   - Mechanic: Immune to biological weapons and disease
   - Trade-off: Cannot use bio-augments or stims
   - Tactical: Reliable but limited upgrade paths

### Step 4: Write JSON Data

Create `data/dlc/custom/custom_species.json`:

```json
{
  "species": [
    {
      "name": "Crystalline",
      "playable": true,
      "description": "Silicon-based lifeforms from high-gravity worlds. Their crystalline bodies are incredibly durable but also brittle when damaged.",
      "homeworld": "Gravitas Prime (high-gravity crystal world)",
      "traits": [
        "Crystalline Structure: Reflect energy damage",
        "Heavy Frame: Natural armor but slow",
        "Silicon Metabolism: Immune to biologicals"
      ],
      "starting_bonus": "+2 Toughness, -1\" Movement, -1 Reactions, Natural Armor 6+",
      "dlc_required": "custom",
      "source": "custom",
      "base_profile": {
        "reactions": 0,
        "speed": "3\"",
        "combat_skill": "+0",
        "toughness": 5,
        "savvy": "+0"
      },
      "special_rules": [
        {
          "name": "Crystalline Structure",
          "description": "Reflect energy weapon damage",
          "mechanical_effect": "When hit by energy weapon, attacker takes 50% of damage dealt (rounded down). However, on natural 6 to hit (critical), Crystalline takes +1 damage due to brittleness."
        },
        {
          "name": "Heavy Frame",
          "description": "Natural armor plating from dense crystal structure",
          "mechanical_effect": "Innate 6+ armor save that stacks with worn armor. Speed reduced by 1\" (already applied to base profile)."
        },
        {
          "name": "Silicon Metabolism",
          "description": "Non-organic physiology grants immunity but limits upgrades",
          "mechanical_effect": "Immune to biological weapons, disease, toxins. Cannot use bio-augments, stims, or consumables that require organic metabolism."
        }
      ]
    }
  ]
}
```

### Step 5: Implement Special Mechanics (Optional)

If species has complex mechanics, add to code:

`src/core/systems/SpeciesSystem.gd`:

```gdscript
## Apply species-specific combat effects
func apply_species_combat_effects(character: Dictionary, attacker, damage: int, weapon: Dictionary) -> int:
    match character.species:
        "Crystalline":
            return _apply_crystalline_effects(character, attacker, damage, weapon)

    return damage  # No modification

func _apply_crystalline_effects(character: Dictionary, attacker, damage: int, weapon: Dictionary) -> int:
    # Check if weapon is energy type
    if weapon.get("type", "") == "energy":
        # Reflect 50% damage back
        var reflected = int(damage * 0.5)
        if attacker is Dictionary:
            attacker.damage = attacker.get("damage", 0) + reflected
            print("Crystalline reflects %d damage back to attacker!" % reflected)

    # Check for critical hit (brittleness)
    if weapon.get("was_critical", false):
        damage += 1
        print("Critical hit! Crystalline takes +1 damage (brittle)")

    return damage
```

---

## Creating Psionic Powers

### Step 1: Design the Power

**Template Questions**:
1. **What does the power do?** (Simple, clear effect)
2. **Who can it target?** (Self, enemy, any, area)
3. **How long does it last?** (Instant, rounds, concentration)
4. **How difficult is it?** (Basic 4+, Intermediate 5+, Advanced 6-7+)

**Example Design: Crystal Armor**

- **Effect**: Create protective crystal shards that orbit caster
- **Target**: Self
- **Duration**: Until caster's next activation
- **Difficulty**: Intermediate (5+)

### Step 2: Determine Balance

**Power Costing Guidelines**:

| Difficulty | Activation | XP Cost | Power Examples |
|-----------|------------|---------|----------------|
| Basic | 4+ | 3-4 XP | Damage mitigation, simple buffs |
| Intermediate | 5+ | 4-5 XP | Strong buffs, moderate control |
| Advanced | 6-7+ | 5-7 XP | Powerful attacks, mind control |

**Crystal Armor Balance**:
- Grants armor save: Strong defensive effect
- Self-target only: Limited scope
- Short duration: Balanced with power
- **Decision**: Intermediate difficulty (5+), 4 XP cost

### Step 3: Write Effects

**Effect Design Principles**:
- **Specific numbers**: "Grants 5+ armor save" not "improved defense"
- **Clear duration**: "Until next activation" not "for a while"
- **Stacking rules**: Specify if it combines with worn armor

**Crystal Armor Effects**:
```json
"effects": [
  {
    "name": "Crystal Shards",
    "description": "Orbiting crystal shards grant 5+ armor save. Stacks with worn armor (5+ becomes 4+, etc.). Shards shatter when they save vs an attack."
  },
  {
    "name": "Brittle Defense",
    "description": "After successful save, roll 1D6. On 1-2, crystal armor shatters and power ends immediately."
  }
]
```

### Step 4: Write JSON Data

Create `data/dlc/custom/custom_powers.json`:

```json
{
  "psionic_powers": [
    {
      "name": "Crystal Armor",
      "description": "Manifest protective crystal shards that orbit your body, deflecting attacks.",
      "target_type": "self",
      "range": "self",
      "persists": true,
      "affects_robotic": false,
      "dlc_required": "custom",
      "source": "custom",
      "cost": 4,
      "difficulty": "intermediate",
      "activation": {
        "type": "combat_action",
        "activation_roll": "5+",
        "duration": "Until caster's next activation"
      },
      "effects": [
        {
          "name": "Crystal Shards",
          "description": "Grants 5+ armor save. Stacks with worn armor (improve save by 1). Shards shatter when they successfully save."
        },
        {
          "name": "Brittle Defense",
          "description": "After successful armor save from crystal shards, roll 1D6. On 1-2, shards shatter and power ends."
        }
      ],
      "advanced_mechanics": {
        "save_bonus": 5,
        "stackable": true,
        "shatter_chance": 0.33,
        "visual_effect": "floating_crystal_shards"
      }
    }
  ]
}
```

### Step 5: Implement Effects (Optional)

Add to `src/core/systems/PsionicSystem.gd`:

```gdscript
func _apply_single_effect(caster, power: Dictionary, target, effect: Dictionary) -> void:
    match power.name:
        # ... existing powers ...
        "Crystal Armor":
            _apply_crystal_armor_effect(target)

func _apply_crystal_armor_effect(target) -> void:
    if target is Dictionary:
        if not target.has("active_effects"):
            target.active_effects = []

        # Grant armor save
        var crystal_armor = {
            "type": "crystal_armor",
            "armor_save": 5,
            "shatter_on_save": true,
            "shatter_chance": 0.33
        }

        target.active_effects.append(crystal_armor)

        # If already has armor, improve it
        if target.has("armor_save"):
            target.armor_save = max(4, target.armor_save - 1)  # Improve by 1, min 4+
        else:
            target.armor_save = 5

        print("Crystal Armor active: %d+ save" % target.armor_save)

## Check for armor shattering (call during damage resolution)
func check_crystal_armor_shatter(target: Dictionary, saved: bool) -> void:
    if not saved:
        return

    # Find crystal armor effect
    for effect in target.get("active_effects", []):
        if effect.get("type") == "crystal_armor" and effect.get("shatter_on_save", false):
            # Roll for shatter
            var roll = randi() % 6 + 1
            if roll <= 2:  # 1-2 = shatter (33% chance)
                print("Crystal armor shatters!")
                target.active_effects.erase(effect)
                # Remove armor bonus
                target.armor_save = target.get("base_armor_save", 7)
                PsionicSystem.end_power(target, "Crystal Armor")
            else:
                print("Crystal armor holds (rolled %d)" % roll)
```

---

## Creating Elite Enemies

### Step 1: Choose Base Enemy

Select a standard enemy to enhance:
- Mercenary → Elite Mercenary
- Raider → Veteran Raider
- Tech Gang → Elite Technician
- Bounty Hunter → Alien Hunter

**Example: Raider → Void Raider (space pirate specialist)**

### Step 2: Enhance Stats

**Enhancement Guidelines**:

| Stat | Standard | Elite Increase | Example |
|------|----------|----------------|---------|
| Combat Skill | +0 | +1 to +2 | +0 → +2 |
| Toughness | 3 | +1 | 3 → 4 |
| Speed | 4" | +0 to +1" | 4" → 5" |
| Reactions | 1 | +1 | 1 → 2 |

**Void Raider Stats**:
```
Base Raider → Void Raider:
- Combat Skill: +0 → +2 (+2)
- Toughness: 3 → 4 (+1)
- Speed: 4" → 5" (+1")
- Reactions: 1 → 2 (+1)
```

### Step 3: Design Special Abilities

**Ability Design Principles**:
- **2-3 abilities** for elite enemies
- Mix of **offensive** and **tactical** abilities
- Abilities that create **interesting decisions** for players

**Void Raider Abilities**:

1. **Zero-G Combat Training**
   - Effect: Ignores movement penalties in zero-gravity or difficult terrain
   - Tactical: Highly mobile on ships/stations

2. **Boarding Action Specialist**
   - Effect: +1 to hit when within 6" of enemy (close quarters)
   - Tactical: Dangerous in tight spaces

3. **Void-Hardened**
   - Effect: Re-roll failed Toughness saves once per battle
   - Tactical: Unexpectedly survives hits

### Step 4: Calculate Deployment Cost

**Deployment Point Formula**:
```
Base Cost: 1 DP (standard enemy)
+ Combat Skill increase (×1 DP per +1)
+ Toughness increase (×1 DP per +1)
+ Speed increase (×0.5 DP per +1")
+ Reactions increase (×0.5 DP per +1)
+ Abilities (×0.5-1 DP per ability)

Void Raider:
1 (base) + 2 (Combat) + 1 (Tough) + 0.5 (Speed) + 0.5 (Reactions) + 1.5 (3 abilities × 0.5)
= 6.5 DP → Round to 7 DP (but that's too expensive)

Adjust: Actually costs 4 DP (less than formula to keep usable)
```

**Deployment Cost Guidelines**:
- **2 DP**: Minor elite (1 stat boost, 1 ability)
- **3 DP**: Standard elite (2 stat boosts, 2 abilities)
- **4 DP**: Strong elite (good stats, 3 abilities)
- **5 DP**: Powerful elite (high stats, powerful abilities)

### Step 5: Write JSON Data

Create `data/dlc/custom/custom_elite_enemies.json`:

```json
{
  "elite_enemies": [
    {
      "name": "Void Raider",
      "enemy_type": "Raider",
      "combat_skill": "+2",
      "toughness": 4,
      "speed": "5\"",
      "reactions": 2,
      "weapons": ["Boarding Gun", "Mono Blade"],
      "special_abilities": [
        {
          "name": "Zero-G Combat Training",
          "effect": "Ignores movement penalties from zero-gravity or difficult terrain. Moves at full speed in any environment."
        },
        {
          "name": "Boarding Action Specialist",
          "effect": "+1 to hit when within 6\" of enemy target. Trained for close-quarters ship boarding combat."
        },
        {
          "name": "Void-Hardened",
          "effect": "Once per battle, may re-roll a failed Toughness save. Years in the void have toughened them."
        }
      ],
      "dlc_required": "custom",
      "source": "custom",
      "deployment_points": 4,
      "lore": "Void Raiders are elite space pirates who specialize in boarding actions and zero-G combat. They are feared across the frontier for their ruthless efficiency."
    }
  ]
}
```

---

## Creating Equipment & Weapons

### Step 1: Design the Item

**Item Design Questions**:
1. **What role does it serve?** (Weapon, armor, utility)
2. **What's unique about it?** (Special ability or stat)
3. **How does it compare to existing gear?** (Better/worse/different)

**Example: Plasma Cutter**
- **Role**: Close-range energy weapon
- **Unique**: Cuts through armor, can breach doors
- **Comparison**: Higher damage than Ripper Blade, shorter range than Blast Pistol

### Step 2: Balance Stats

**Weapon Stat Guidelines**:

| Weapon Type | Range | Shots | Damage | Special | Credit Cost |
|-------------|-------|-------|--------|---------|-------------|
| Pistol | 12" | 1 | 0-1 | Sidearm | 5-10 |
| Rifle | 24" | 1-3 | 1 | Accurate | 12-20 |
| Heavy | 18-30" | 1-2 | 2-3 | Heavy | 25-40 |
| Melee | Melee | - | 0-2 | Brawling | 3-15 |

**Plasma Cutter Balance**:
```
Range: 6" (very short - cutting tool, not gun)
Shots: 1
Damage: 2 (high - cuts through anything)
Special: Ignores armor, can breach doors
Cost: 18 credits (expensive specialist tool)
```

### Step 3: Write Special Rules

**Special Rules Examples**:
- **Armor Piercing**: Ignores X points of armor
- **Blast**: Hits multiple targets in area
- **Stun**: Target may be incapacitated
- **Unreliable**: May jam or malfunction

**Plasma Cutter Special Rules**:
```
1. "Armor Bypass: Ignores all armor saves (cutting torch effect)"
2. "Breaching Tool: Can cut through locked doors as 1 action"
3. "Short Range: Only 6\" range, must be very close"
4. "Industrial Tool: Can salvage extra scrap from wrecks (+1D3 credits)"
```

### Step 4: Write JSON Data

Create `data/dlc/custom/custom_equipment.json`:

```json
{
  "weapons": [
    {
      "name": "Plasma Cutter",
      "type": "energy_weapon",
      "category": "specialist",
      "range": "6\"",
      "shots": 1,
      "damage": 2,
      "traits": [
        "Armor Bypass",
        "Breaching Tool",
        "Short Range",
        "Industrial"
      ],
      "cost": 18,
      "dlc_required": "custom",
      "source": "custom",
      "description": "Industrial plasma cutting torch repurposed as a devastating close-range weapon. The superheated plasma cuts through armor like butter, but the limited fuel cell restricts its range.",
      "special_rules": [
        {
          "name": "Armor Bypass",
          "description": "Ignore all armor saves when hitting target. Plasma cuts through anything."
        },
        {
          "name": "Breaching Tool",
          "description": "Can cut through locked doors, bulkheads, or barriers as 1 action. Roll 1D6, on 4+ successfully breached."
        },
        {
          "name": "Industrial Salvage",
          "description": "When used to salvage wrecks or equipment, gain +1D3 additional credits from superior cutting precision."
        }
      ],
      "availability": "rare"
    }
  ],

  "armor": [
    {
      "name": "Reflective Cloak",
      "type": "light_armor",
      "armor_save": 6,
      "cost": 15,
      "dlc_required": "custom",
      "source": "custom",
      "description": "Cloak woven with reflective fibers that deflect energy weapons.",
      "special_rules": [
        {
          "name": "Energy Reflection",
          "description": "When saving against energy weapons, improve armor save by 1 (6+ becomes 5+)."
        },
        {
          "name": "Stealth Bonus",
          "description": "+1 to stealth checks when avoiding detection (cloak blends with environment)."
        }
      ]
    }
  ],

  "equipment": [
    {
      "name": "Grav Boots",
      "type": "equipment",
      "cost": 12,
      "dlc_required": "custom",
      "source": "custom",
      "description": "Magnetic boots that allow walking on any metallic surface, including walls and ceilings.",
      "special_rules": [
        {
          "name": "Magnetic Grip",
          "description": "Can walk on metallic walls and ceilings at normal speed. Ignore zero-gravity penalties on ships/stations."
        },
        {
          "name": "Sudden Stop",
          "description": "Once per battle as free action, instantly halt all movement (even falling). Useful for dodging or positioning."
        }
      ]
    }
  ]
}
```

---

## Creating Mission Types

### Step 1: Define Mission Concept

**Mission Design Questions**:
1. **What's the objective?** (Extract, eliminate, retrieve, defend)
2. **What's the core mechanic?** (Time limit, alarm, tension, waves)
3. **What makes it unique?** (Special rules, terrain, enemies)
4. **What's the failure condition?** (Time runs out, all crew dead, objective lost)

**Example: Asteroid Mining Raid**
- **Objective**: Steal valuable ore from mining operation
- **Core Mechanic**: Oxygen depletion timer (limited air supply)
- **Unique**: Vacuum combat, explosive mining charges
- **Failure**: Oxygen runs out or all crew eliminated

### Step 2: Design Core Mechanics

**Oxygen Depletion System**:
```
- Start with Oxygen Level: 10
- Each round: -1 Oxygen
- Each explosive/breach: -1 Oxygen
- Each search action: -1 Oxygen
- At Oxygen 0: Crew starts taking damage (1/round)
```

**Ore Extraction**:
```
- 1D6 ore deposits on map
- Requires 2 actions to extract
- Each deposit worth 2D6 credits
- Carrying ore: -2" Speed penalty
```

### Step 3: Design Objectives

**Multi-Part Objectives**:
```json
"objectives": [
  {
    "type": "extract_ore",
    "target": "Mining Deposits (1D6 locations)",
    "success_condition": "Extract ore from at least 3 deposits",
    "failure_condition": "Oxygen depleted or all crew eliminated"
  },
  {
    "type": "escape",
    "target": "Extraction Point",
    "success_condition": "At least one crew reaches ship with ore",
    "failure_condition": "All crew eliminated"
  }
]
```

### Step 4: Write JSON Data

Create `data/dlc/custom/custom_missions.json`:

```json
{
  "custom_missions": [
    {
      "mission_type": "heist",
      "name": "Asteroid Mining Raid",
      "description": "Raid a corporate mining operation on a low-gravity asteroid. Extract valuable ore before your oxygen runs out.",
      "objectives": [
        {
          "type": "extract_ore",
          "target": "Mining Deposits (1D6 locations)",
          "success_condition": "Extract ore from at least 3 deposits and escape",
          "failure_condition": "Oxygen depleted to 0 for 3 rounds, or all crew eliminated"
        }
      ],
      "enemy_types": ["Corporate Security", "Mining Bots"],
      "deployment_conditions": {
        "deployment_points_modifier": "Standard -1 (light security initially)",
        "special_terrain": [
          "Ore Deposits (1D6 locations)",
          "Mining Equipment",
          "Asteroid Surface (low gravity)",
          "Explosive Mining Charges"
        ],
        "special_rules": [
          "Oxygen Depletion: Starts at 10, -1 per round",
          "Vacuum Combat: No sound, can't hear alarms",
          "Low Gravity: +2\" movement, -1 to ranged attacks",
          "Explosive Charges: Can detonate for 2D6 damage, -1 Oxygen"
        ]
      },
      "dlc_required": "custom",
      "source": "custom",
      "rewards": {
        "base_credits": "Variable (ore value)",
        "bonus_loot_rolls": 0,
        "experience_modifier": 2,
        "story_points": 1
      },
      "oxygen_mechanics": {
        "initial_oxygen": 10,
        "oxygen_depletion": [
          { "trigger": "End of each round", "oxygen_loss": 1 },
          { "trigger": "Explosive detonation", "oxygen_loss": 1 },
          { "trigger": "Hull breach", "oxygen_loss": 2 },
          { "trigger": "Search action", "oxygen_loss": 1 }
        ],
        "oxygen_effects": [
          { "level": 5, "effect": "Warning: Oxygen running low" },
          { "level": 3, "effect": "Critical: -1 to all actions (hypoxia)" },
          { "level": 0, "effect": "Asphyxiation: All crew take 1 damage per round until oxygen restored" }
        ]
      },
      "ore_extraction": {
        "deposits_count": "1D6",
        "extraction_time": "2 actions",
        "ore_value": "2D6 credits per deposit",
        "carrying_penalty": "-2\" Speed when carrying ore"
      }
    }
  ]
}
```

### Step 5: Implement Custom System (If Needed)

If mission needs new mechanics, create a system:

`src/core/systems/OxygenSystem.gd`:

```gdscript
class_name OxygenSystem
extends Node

signal oxygen_depleted(remaining: int)
signal oxygen_critical()
signal crew_suffocating()

var current_oxygen: int = 10
var max_oxygen: int = 10

func start_mission(initial_oxygen: int):
    current_oxygen = initial_oxygen
    max_oxygen = initial_oxygen
    print("Oxygen System: Started with %d oxygen" % current_oxygen)

func deplete_oxygen(amount: int, reason: String):
    current_oxygen = max(0, current_oxygen - amount)
    print("Oxygen: -%d (%s). Remaining: %d" % [amount, reason, current_oxygen])

    oxygen_depleted.emit(current_oxygen)

    if current_oxygen <= 3:
        oxygen_critical.emit()

    if current_oxygen <= 0:
        crew_suffocating.emit()

func process_round():
    deplete_oxygen(1, "Round elapsed")

func get_oxygen_penalty() -> int:
    if current_oxygen <= 3:
        return -1  # Hypoxia penalty
    return 0

func is_suffocating() -> bool:
    return current_oxygen <= 0
```

---

## Testing Your Content

### Balance Testing

**Checklist**:
- [ ] Can standard 3-person crew complete it?
- [ ] Does difficulty match rewards?
- [ ] Are mechanics clear and unambiguous?
- [ ] No degenerate strategies or exploits?
- [ ] Fun and engaging to play?

### Test Script Template

```gdscript
# test_content.gd

func test_crystalline_species():
    var crystalline = {
        "name": "Test Crystalline",
        "species": "Crystalline",
        "reactions": 0,
        "speed": 3,
        "combat_skill": 0,
        "toughness": 5,
        "savvy": 0
    }

    # Test reflection mechanic
    var attacker = {"damage": 0}
    var weapon = {"type": "energy"}
    var damage_taken = apply_species_combat_effects(crystalline, attacker, 4, weapon)

    assert(attacker.damage == 2, "Should reflect 2 damage (50% of 4)")
    assert(damage_taken == 4, "Should still take full damage")

    print("✓ Crystalline species test passed")

func test_crystal_armor_power():
    var psyker = {
        "id": "test_psyker",
        "savvy": 2,
        "known_powers": ["Crystal Armor"]
    }

    var success = PsionicSystem.activate_power(psyker, "Crystal Armor", psyker)
    assert(success, "Power should activate with Savvy +2")

    assert(psyker.has("armor_save"), "Should have armor save")
    assert(psyker.armor_save == 5, "Should have 5+ armor save")

    print("✓ Crystal Armor power test passed")

func test_void_raider_balance():
    var void_raider = EliteEnemySystem.get_elite_enemy("Void Raider")
    assert(not void_raider.is_empty(), "Void Raider should exist")

    var cost = EliteEnemySystem.get_deployment_cost(void_raider)
    assert(cost == 4, "Should cost 4 DP")

    # Test vs standard crew
    var test_result = simulate_combat(create_test_crew(), [void_raider])
    assert(test_result.crew_wins > 0.4, "Crew should win at least 40% of time")

    print("✓ Void Raider balance test passed")
```

---

## Publishing Content

### Package Your Content

Create a content pack structure:

```
my_content_pack/
├── README.md              # Description and credits
├── data/
│   ├── species.json
│   ├── powers.json
│   ├── enemies.json
│   ├── equipment.json
│   └── missions.json
└── (optional) src/
    └── systems/
        └── CustomSystem.gd
```

### Write Documentation

**README.md Template**:

```markdown
# My Content Pack Name

## Description
Brief description of what your content adds to Five Parsecs.

## Contents
- 2 new species (Crystalline, Voidborn)
- 3 new psionic powers (Crystal Armor, etc.)
- 5 new elite enemies
- 10 new equipment items
- 3 new mission types

## Installation
1. Copy `data/` folder to `res://data/dlc/my_content_pack/`
2. (If applicable) Copy `src/` folder to `res://src/`
3. Enable in ExpansionManager

## Balance Notes
- Crystalline species: Tank role, slower but very tough
- Crystal Armor power: Strong defense with risk of shattering
- Void Raider: 4 DP elite, good for ship combat

## Credits
Created by: Your Name
Version: 1.0
License: CC-BY-4.0 (or your choice)

## Changelog
### v1.0 (2024-01-01)
- Initial release
```

### Share Your Content

**Platforms**:
- GitHub repository
- Game forums
- Itch.io (as mod/expansion)
- Community Discord

**Best Practices**:
- Include screenshots/examples
- Provide balance rationale
- Credit inspirations
- Accept feedback gracefully
- Version your releases

---

## Summary

**Content Creation Workflow**:
1. **Design** - Plan concept with balance in mind
2. **Write JSON** - Create data files following format
3. **Implement** (optional) - Add GDScript for complex mechanics
4. **Test** - Verify balance and fun
5. **Document** - Write clear usage instructions
6. **Share** - Publish for community

**Key Principles**:
- **Balance**: Net-zero stat modifications, fair deployment costs
- **Clarity**: Specific numbers and mechanics, no ambiguity
- **Compatibility**: Works with core systems, doesn't break them
- **Fun**: Creates interesting decisions and tactical variety

**Resources**:
- [Trailblazer's Toolkit Integration](./expansions/TRAILBLAZERS_TOOLKIT_INTEGRATION.md) - Species & Powers
- [Freelancer's Handbook Integration](./expansions/FREELANCERS_HANDBOOK_INTEGRATION.md) - Elite Enemies
- [Fixer's Guidebook Integration](./expansions/FIXERS_GUIDEBOOK_INTEGRATION.md) - Mission Types
- [Data Format Specifications](./DATA_FORMAT_SPECIFICATIONS.md) - JSON schemas
- [Testing Guide](./EXPANSION_TESTING_GUIDE.md) - Balance testing methodology

---

Happy creating! 🎨
