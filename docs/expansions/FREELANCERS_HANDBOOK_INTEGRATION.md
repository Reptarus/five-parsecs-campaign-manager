# Freelancer's Handbook Integration Guide

## Overview

**Freelancer's Handbook** is the second expansion DLC for Five Parsecs from Home, introducing systems for campaign difficulty customization and elite enemy encounters:

1. **Elite Enemy System** - Enhanced enemy variants with special abilities
2. **Difficulty Scaling System** - Customizable challenge modifiers and adaptive difficulty

This guide explains the architecture, integration patterns, and extensibility of these systems.

---

## Table of Contents

1. [Expansion Contents](#expansion-contents)
2. [EliteEnemySystem Architecture](#elastenemysystem-architecture)
3. [DifficultyScalingSystem Architecture](#difficultyscalingsystem-architecture)
4. [Elite Enemy Mechanics](#elite-enemy-mechanics)
5. [Difficulty Modifier System](#difficulty-modifier-system)
6. [Integration with Core Systems](#integration-with-core-systems)
7. [Adding New Elite Enemies](#adding-new-elite-enemies)
8. [Adding New Difficulty Modifiers](#adding-new-difficulty-modifiers)
9. [Code Examples](#code-examples)
10. [Troubleshooting](#troubleshooting)

---

## Expansion Contents

### Data Files

Located in `/data/dlc/freelancers_handbook/`:

- **`freelancers_handbook_elite_enemies.json`** - Elite enemy variants
- **`freelancers_handbook_difficulty_modifiers.json`** - Difficulty modifiers and presets

### Systems

Located in `/src/core/systems/`:

- **`EliteEnemySystem.gd`** - Elite enemy management
  - Elite enemy generation and deployment
  - Special ability handling
  - Deployment cost calculation
  - Mixed squad generation

- **`DifficultyScalingSystem.gd`** - Difficulty management
  - Modifier application to enemies/battles
  - Preset difficulty configurations
  - Progressive difficulty (ramps up over campaign)
  - Adaptive difficulty (responds to player performance)

### Elite Enemies Included

| Elite Name | Base Type | Combat Skill | Toughness | DP Cost | Special Abilities |
|------------|-----------|--------------|-----------|---------|-------------------|
| **Elite Mercenary** | Mercenary | +2 | 4 | 3 | Combat Veteran, Tactical Positioning |
| **Corporate Enforcer** | Corporate Security | +1 | 5 | 4 | Heavy Armor, Corporate Resources |
| **Veteran Raider** | Raider | +1 | 4 | 2 | Aggressive Tactics, Fearless |
| **Alien Hunter** | Bounty Hunter | +2 | 3 | 4 | Tracking Expert, Trophy Hunter, Quick Draw |
| **Psionic Adept** | Psyker | +0 | 3 | 5 | Psionic Powers (3 powers) |
| **Pack Alpha** | Creature | +1 | 5 | 3 | Pack Leader, Enhanced Senses |

### Difficulty Modifiers Included

| Modifier | Category | Effect | Stackable |
|----------|----------|--------|-----------|
| **Brutal Foes** | Enemy Strength | +1 Toughness to all enemies | Yes |
| **Larger Battles** | Battle Size | +25% deployment points | No |
| **Veteran Opposition** | Enemy Strength | +1 Combat Skill to all enemies | Yes |
| **Elite Foes** | Enemy Strength | 50% elite replacement rate | No |
| **Desperate Combat** | Danger | -2 to injury rolls (more severe) | Yes |
| **Scarcity** | Rewards | -25% to loot and credits | No |
| **High Stakes** | Campaign Pressure | +1 Rival generation, -1 Patron time | No |
| **Lethal Encounters** | Danger | +1 damage on critical hits | Yes |

---

## EliteEnemySystem Architecture

### System Design Philosophy

The `EliteEnemySystem` follows these principles:

1. **Enhancement, Not Replacement** - Elite enemies are upgraded versions of standard enemies
2. **Deployment Flexibility** - Multiple deployment modes for different play styles
3. **Cost-Based Balancing** - Deployment points ensure tactical fairness
4. **Special Abilities** - Each elite has unique tactical considerations
5. **Backward Compatibility** - Works seamlessly with core enemy system

### Class Structure

```gdscript
class_name EliteEnemySystem
extends Node

# ============= PUBLIC API =============

# Elite Enemy Database
func get_all_elite_enemies() -> Array
func get_elite_version(base_enemy_type: String) -> Dictionary
func get_elite_enemy(elite_name: String) -> Dictionary
func get_elites_by_type(enemy_type: String) -> Array
func get_elites_by_cost(min_cost: int, max_cost: int) -> Array

# Enemy Generation
func should_replace_with_elite(enemy_type: String) -> bool
func generate_enemy(base_enemy_type: String) -> Dictionary
func generate_mixed_squad(enemy_type: String, total_count: int) -> Array
func generate_boss_enemy(enemy_type: String, deployment_points: int) -> Dictionary

# Deployment Management
func set_deployment_mode(mode: String) -> void
func set_replacement_rate(rate: float) -> void
func get_deployment_cost(elite_enemy: Dictionary) -> int
func calculate_elite_deployment_points(enemies: Array) -> int
func get_elite_only_multiplier() -> float

# Special Abilities
func get_special_abilities(elite_enemy: Dictionary) -> Array
func trigger_ability(elite_enemy: Dictionary, ability_name: String, context: Dictionary) -> void
func has_ability(elite_enemy: Dictionary, ability_name: String) -> bool

# ============= SIGNALS =============

signal elite_enemy_deployed(elite_enemy: Dictionary)
signal elite_ability_triggered(elite_enemy: Dictionary, ability: Dictionary)
```

### Deployment Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **standard_replacement** | Random chance to replace standard with elite | Vanilla+ difficulty |
| **elite_only_battles** | All enemies are elite variants | High difficulty challenge |
| **mixed_squads** | 1 elite per 3 standard enemies | Balanced tactical variety |
| **boss_battles** | Single elite with boosted stats | Special encounters |

---

## DifficultyScalingSystem Architecture

### System Design Philosophy

The `DifficultyScalingSystem` follows these principles:

1. **Modular Customization** - Each modifier is independent and can be mixed
2. **Preset Configurations** - Quick difficulty settings for common play styles
3. **Dynamic Adaptation** - Can automatically adjust to player performance
4. **Progressive Scaling** - Difficulty can increase over campaign turns
5. **Transparent Impact** - Clear mechanical effects on stats/rewards

### Class Structure

```gdscript
class_name DifficultyScalingSystem
extends Node

# ============= PUBLIC API =============

# Preset Management
func set_difficulty_preset(preset_name: String) -> void

# Modifier Management
func enable_modifier(modifier_name: String) -> void
func disable_modifier(modifier_name: String) -> void
func get_modifier(modifier_name: String) -> Dictionary
func get_active_modifiers() -> Array

# Difficulty Application
func apply_to_enemy(enemy: Dictionary) -> Dictionary
func modify_deployment_points(base_points: int) -> int
func modify_rewards(base_credits: int, base_loot_rolls: int) -> Dictionary
func modify_injury_roll(base_roll: int) -> int
func modify_critical_hit(base_damage: int) -> int
func get_rival_generation_modifier() -> int

# Dynamic Difficulty
func enable_progressive_difficulty(enable: bool) -> void
func enable_adaptive_difficulty(enable: bool) -> void
func process_progressive_difficulty(current_turn: int) -> void
func process_adaptive_difficulty() -> void
func update_campaign_stats(battle_result: String, crew_deaths: int, credits: int) -> void

# Statistics
func get_difficulty_stats() -> Dictionary

# ============= SIGNALS =============

signal difficulty_changed(preset_name: String)
signal modifier_enabled(modifier_name: String)
signal modifier_disabled(modifier_name: String)
signal difficulty_stats_updated(stats: Dictionary)
```

### Difficulty Presets

```gdscript
var difficulty_presets = {
    "easy": {
        "name": "Relaxed",
        "active_modifiers": [],
        "description": "Standard Five Parsecs experience"
    },
    "standard": {
        "name": "Standard",
        "active_modifiers": [],
        "description": "Balanced challenge"
    },
    "challenging": {
        "name": "Challenging",
        "active_modifiers": ["Brutal Foes", "Larger Battles"],
        "description": "Tougher enemies, bigger battles"
    },
    "hard": {
        "name": "Hardcore",
        "active_modifiers": ["Brutal Foes", "Veteran Opposition", "Elite Foes", "Desperate Combat"],
        "description": "Punishing difficulty for veterans"
    },
    "nightmare": {
        "name": "Nightmare",
        "active_modifiers": ["Brutal Foes", "Veteran Opposition", "Elite Foes", "Desperate Combat", "Lethal Encounters", "Larger Battles"],
        "description": "Extreme challenge, high risk of crew death"
    }
}
```

---

## Elite Enemy Mechanics

### Elite Enemy Data Structure

```json
{
  "name": "Elite Mercenary",
  "enemy_type": "Mercenary",
  "combat_skill": "+2",
  "toughness": 4,
  "speed": "5\"",
  "reactions": 2,
  "weapons": ["Auto Rifle", "Blade"],
  "special_abilities": [
    {
      "name": "Combat Veteran",
      "effect": "Re-roll one failed to-hit roll per activation"
    },
    {
      "name": "Tactical Positioning",
      "effect": "May move 2\" after making a ranged attack instead of standard 1\""
    }
  ],
  "dlc_required": "freelancers_handbook",
  "source": "freelancers_handbook",
  "deployment_points": 3
}
```

### Key Fields Explained

- **`enemy_type`**: Base enemy type this elite is based on (e.g., "Mercenary")
- **`combat_skill`**: Enhanced combat ability (usually +1 or +2 from base)
- **`toughness`**: Increased durability (usually +1 from base)
- **`special_abilities`**: Unique tactical abilities
- **`deployment_points`**: Cost for balanced encounter generation (2-5)

### Stat Comparison: Standard vs Elite

**Example: Mercenary → Elite Mercenary**

| Stat | Standard Mercenary | Elite Mercenary | Change |
|------|-------------------|-----------------|--------|
| Combat Skill | +0 | +2 | **+2** |
| Toughness | 3 | 4 | **+1** |
| Speed | 4" | 5" | **+1"** |
| Reactions | 1 | 2 | **+1** |
| Special Abilities | None | 2 abilities | **New** |
| Deployment Cost | 1 | 3 | **3x** |

**Analysis**: Elite Mercenary is significantly more dangerous but costs 3x deployment points, maintaining balance.

### Special Ability Examples

#### Combat Veteran
```gdscript
# During attack resolution:
if elite_enemy.has_ability("Combat Veteran"):
    var hit = roll_to_hit(elite_enemy, target)
    if not hit and not elite_enemy.veteran_reroll_used_this_turn:
        print("Combat Veteran: Re-rolling missed attack")
        hit = roll_to_hit(elite_enemy, target)
        elite_enemy.veteran_reroll_used_this_turn = true
```

#### Tactical Positioning
```gdscript
# After ranged attack:
if elite_enemy.has_ability("Tactical Positioning"):
    var bonus_move = 2  # Instead of standard 1"
    move_enemy(elite_enemy, bonus_move)
    print("Tactical Positioning: Elite moves 2\" after shooting")
```

#### Tracking Expert (Ignores Cover)
```gdscript
# During hit calculation:
func calculate_cover_bonus(attacker, target) -> int:
    var distance = calculate_distance(attacker, target)

    if attacker.has_ability("Tracking Expert") and distance <= 12:
        print("Tracking Expert: Ignoring cover at %d\"" % distance)
        return 0  # No cover bonus

    # Standard cover logic
    return target.cover_value
```

### Deployment Point System

Elite enemies cost more deployment points to balance their power:

```gdscript
# Standard enemy generation (10 deployment points):
var squad = [
    {"type": "Mercenary"},  # 1 DP
    {"type": "Mercenary"},  # 1 DP
    {"type": "Mercenary"},  # 1 DP
    # ... 10 total standard mercenaries
]

# Elite enemy generation (10 deployment points):
var elite_squad = [
    {"type": "Elite Mercenary"},  # 3 DP
    {"type": "Elite Mercenary"},  # 3 DP
    {"type": "Elite Mercenary"},  # 3 DP
    {"type": "Mercenary"}          # 1 DP
]  # Total: 10 DP, but only 4 enemies vs 10
```

**Result**: Elite battles feature fewer but much more dangerous enemies.

---

## Difficulty Modifier System

### Modifier Data Structure

```json
{
  "name": "Brutal Foes",
  "category": "enemy_strength",
  "effect": "Enemy forces are tougher and more resilient than usual",
  "mechanical_changes": {
    "enemy_toughness": 1
  },
  "dlc_required": "freelancers_handbook",
  "source": "freelancers_handbook",
  "stackable": true,
  "description": "All enemies gain +1 Toughness..."
}
```

### Modifier Categories

Modifiers are grouped by category to prevent unbalanced stacking:

| Category | Purpose | Stackable? | Examples |
|----------|---------|------------|----------|
| **enemy_strength** | Improve enemy combat stats | Yes | Brutal Foes, Veteran Opposition |
| **battle_size** | Change number of enemies | No | Larger Battles |
| **danger** | Increase injury/death risk | Yes | Desperate Combat, Lethal Encounters |
| **rewards** | Modify loot and payment | No | Scarcity |
| **campaign_pressure** | Affect campaign events | No | High Stakes |

**Stackable modifiers** can be combined:
```gdscript
# These stack:
enable_modifier("Brutal Foes")         # +1 Toughness
enable_modifier("Veteran Opposition")  # +1 Combat Skill
# Result: Enemies have +1 Tough, +1 Combat

# These don't stack (same category, non-stackable):
enable_modifier("Larger Battles")  # +25% deployment
enable_modifier("Epic Battles")    # Would fail - Larger Battles already active
```

### Mechanical Changes Reference

| Change Key | Effect | Example Value | Result |
|------------|--------|---------------|--------|
| `enemy_toughness` | Add to enemy Toughness | `+1` | Enemy Toughness 3 → 4 |
| `enemy_combat_skill` | Add to enemy Combat Skill | `+1` | Enemy +0 → +1 |
| `deployment_points_multiplier` | Multiply deployment points | `1.25` | 10 DP → 12.5 DP (13) |
| `elite_replacement_rate` | Chance to use elite enemy | `0.5` | 50% of enemies are elite |
| `injury_roll_modifier` | Add to injury table roll | `-2` | Roll 4 → 2 (worse injury) |
| `loot_multiplier` | Multiply credits/loot | `0.75` | 100 credits → 75 credits |
| `critical_hit_modifier` | Add damage on natural 6 | `+1` | Crit for 2 damage → 3 damage |
| `rival_generation_modifier` | Add to Rival generation roll | `+1` | More likely to gain Rivals |

---

## Integration with Core Systems

### Combat System Integration

```gdscript
# Enemy generation with elite replacement:

func generate_battle_enemies(enemy_type: String, deployment_points: int) -> Array:
    # Apply difficulty modifier to deployment points
    deployment_points = DifficultyScalingSystem.modify_deployment_points(deployment_points)

    var enemies := []
    var points_spent := 0

    while points_spent < deployment_points:
        # Check if we should use elite version
        var enemy: Dictionary

        if EliteEnemySystem.should_replace_with_elite(enemy_type):
            enemy = EliteEnemySystem.get_elite_version(enemy_type)
            points_spent += EliteEnemySystem.get_deployment_cost(enemy)
        else:
            enemy = {"enemy_type": enemy_type, "is_elite": false}
            points_spent += 1

        # Apply difficulty modifiers to enemy stats
        enemy = DifficultyScalingSystem.apply_to_enemy(enemy)

        enemies.append(enemy)

    return enemies
```

### Injury System Integration

```gdscript
# Injury resolution with difficulty modifier:

func resolve_injury(character: Dictionary) -> void:
    # Roll on injury table (1D6)
    var roll = randi() % 6 + 1

    # Apply difficulty modifier
    roll = DifficultyScalingSystem.modify_injury_roll(roll)

    # Lookup injury result
    match roll:
        1, 2:
            character.injury = "Dead"  # More likely with Desperate Combat
        3, 4:
            character.injury = "Serious Wound"
        5, 6:
            character.injury = "Light Injury"
```

### Reward System Integration

```gdscript
# Battle rewards with difficulty modifier:

func calculate_battle_rewards(base_credits: int, loot_rolls: int) -> Dictionary:
    # Apply difficulty modifiers
    var rewards = DifficultyScalingSystem.modify_rewards(base_credits, loot_rolls)

    print("Base rewards: %d credits, %d loot rolls" % [base_credits, loot_rolls])
    print("Modified: %d credits, %d loot rolls" % [rewards.credits, rewards.loot_rolls])

    return rewards

# Example with Scarcity modifier (-25%):
# Base: 100 credits, 3 loot rolls
# Modified: 75 credits, 2 loot rolls
```

### Progressive Difficulty Integration

```gdscript
# Campaign turn processing:

func advance_campaign_turn():
    current_turn += 1

    # Check progressive difficulty
    DifficultyScalingSystem.process_progressive_difficulty(current_turn)

    # Example progressive rules:
    # Turn 5: Auto-enable "Brutal Foes"
    # Turn 10: Auto-enable "Elite Foes"
    # Turn 15: Auto-enable "Veteran Opposition"
```

### Adaptive Difficulty Integration

```gdscript
# Post-battle processing:

func process_battle_results(victory: bool):
    var crew_deaths = count_crew_deaths()
    var current_credits = crew.credits

    # Update campaign stats
    var result = "victory" if victory else "defeat"
    DifficultyScalingSystem.update_campaign_stats(result, crew_deaths, current_credits)

    # Adaptive difficulty may auto-enable/disable modifiers based on performance
```

---

## Adding New Elite Enemies

### Step 1: Design the Elite

**Questions to answer**:
1. What base enemy is this based on?
2. What are their enhanced stats? (+1/+2 to Combat, +1 Toughness typical)
3. What makes them tactically unique? (1-3 special abilities)
4. What's their deployment cost? (Balance power vs cost)

**Design Example**: Elite Technician

- **Base Type**: Tech Gang Member
- **Enhanced Stats**: +1 Combat, +1 Savvy, same Toughness
- **Special Abilities**:
  1. **Gadgeteer**: Carries 2 random equipment items
  2. **Repair Drones**: Heals 1 damage to nearby ally each round
  3. **EMP Blast**: Once per battle, stun all enemies within 4"
- **Deployment Cost**: 4 points (high due to support abilities)

### Step 2: Add to Data File

Edit `/data/dlc/freelancers_handbook/freelancers_handbook_elite_enemies.json`:

```json
{
  "elite_enemies": [
    // ... existing elites ...
    {
      "name": "Elite Technician",
      "enemy_type": "Tech Gang",
      "combat_skill": "+1",
      "toughness": 3,
      "speed": "4\"",
      "reactions": 1,
      "savvy": 2,
      "weapons": ["Blast Pistol", "Tech Tools"],
      "special_abilities": [
        {
          "name": "Gadgeteer",
          "effect": "Carries 2 random equipment items that can be looted. Roll 2D6 on equipment table when killed."
        },
        {
          "name": "Repair Drones",
          "effect": "At start of Elite Technician's activation, one allied enemy within 6\" heals 1 damage."
        },
        {
          "name": "EMP Blast",
          "effect": "Once per battle as an action, all enemies within 4\" must pass Savvy test or be stunned for 1 round. Affects robotic enemies only."
        }
      ],
      "dlc_required": "freelancers_handbook",
      "source": "freelancers_handbook",
      "deployment_points": 4
    }
  ]
}
```

### Step 3: Implement Special Abilities (Optional)

If abilities need complex logic, add to `EliteEnemySystem.gd`:

```gdscript
func _apply_ability_effect(elite_enemy: Dictionary, ability: Dictionary, context: Dictionary) -> void:
    var ability_name = ability.get("name", "")

    match ability_name:
        # ... existing abilities ...
        "Repair Drones":
            _apply_repair_drones(elite_enemy, context)
        "EMP Blast":
            _apply_emp_blast(elite_enemy, context)

func _apply_repair_drones(elite_enemy: Dictionary, context: Dictionary) -> void:
    var nearby_allies = context.get("nearby_allies", [])

    if nearby_allies.size() > 0:
        var target_ally = nearby_allies[0]  # Choose first injured ally

        if target_ally.get("damage", 0) > 0:
            target_ally.damage -= 1
            print("Elite Technician: Repair Drones heal %s for 1 damage" % target_ally.name)

func _apply_emp_blast(elite_enemy: Dictionary, context: Dictionary) -> void:
    if elite_enemy.get("emp_blast_used", false):
        print("Elite Technician: EMP Blast already used this battle")
        return

    var nearby_enemies = context.get("nearby_enemies", [])

    for enemy in nearby_enemies:
        var distance = calculate_distance(elite_enemy, enemy)
        if distance <= 4:
            # Savvy test to resist
            var savvy_roll = randi() % 6 + 1 + enemy.get("savvy", 0)
            if savvy_roll < 4:
                enemy.is_stunned = true
                enemy.stun_duration = 1
                print("Elite Technician: EMP Blast stuns %s!" % enemy.name)

    elite_enemy.emp_blast_used = true
```

### Step 4: Balance Testing

**Deployment Point Guidelines**:

- **2 DP**: Slightly better stats, 1 simple ability
  - Example: Veteran Raider (+1 Combat, Fearless, Aggressive)

- **3 DP**: Good stat boost, 2 combat abilities
  - Example: Elite Mercenary (+2 Combat, +1 Tough, Combat Veteran, Tactical Positioning)

- **4 DP**: Strong stats OR powerful abilities
  - Example: Alien Hunter (High Reactions, 3 hunting abilities)
  - Example: Elite Technician (Support abilities)

- **5 DP**: Powerful stats AND powerful abilities
  - Example: Psionic Adept (3 psionic powers, high threat)

**Test Questions**:
1. Can a 3-person crew handle 3 of these elites? (Should be challenging)
2. Is this more dangerous than 3 standard enemies? (Should be yes, but not overwhelming)
3. Does this create interesting tactical decisions? (Abilities should matter)

---

## Adding New Difficulty Modifiers

### Step 1: Design the Modifier

**Questions to answer**:
1. What aspect of the game does it modify? (Enemy stats, battle size, rewards, etc.)
2. What's the mechanical effect? (Specific numbers)
3. Is it stackable with other modifiers?
4. What category does it belong to?

**Design Example**: Ammunition Scarcity

- **Aspect**: Resource management
- **Effect**: Limited shots per weapon
- **Mechanical Changes**: Weapons have 50% normal shots
- **Stackable**: No (too punishing if stacked)
- **Category**: Resource management

### Step 2: Add to Data File

Edit `/data/dlc/freelancers_handbook/freelancers_handbook_difficulty_modifiers.json`:

```json
{
  "difficulty_modifiers": [
    // ... existing modifiers ...
    {
      "name": "Ammunition Scarcity",
      "category": "resources",
      "effect": "Limited ammunition makes every shot count",
      "mechanical_changes": {
        "weapon_shots_multiplier": 0.5,
        "reload_difficulty": 1
      },
      "dlc_required": "freelancers_handbook",
      "source": "freelancers_handbook",
      "stackable": false,
      "description": "All weapons have 50% normal shots. Reloading requires a Savvy check (5+ instead of 4+). Forces tactical ammunition management."
    },
    {
      "name": "Fog of War",
      "category": "visibility",
      "effect": "Limited battlefield visibility",
      "mechanical_changes": {
        "visibility_range": 12,
        "stealth_bonus": 1
      },
      "dlc_required": "freelancers_handbook",
      "source": "freelancers_handbook",
      "stackable": false,
      "description": "Maximum visibility reduced to 12\". Enemies gain +1 to stealth. Encourages close-range combat and cautious movement."
    }
  ]
}
```

### Step 3: Implement Modifier Logic

Add handling in `DifficultyScalingSystem.gd`:

```gdscript
## Modify weapon shots based on active modifiers
func modify_weapon_shots(weapon: Dictionary) -> Dictionary:
    var modified_weapon = weapon.duplicate()

    for modifier_name in active_modifiers:
        var modifier = get_modifier(modifier_name)
        if modifier.is_empty():
            continue

        var changes = modifier.get("mechanical_changes", {})

        if changes.has("weapon_shots_multiplier"):
            var current_shots = modified_weapon.get("shots", 1)
            modified_weapon.shots = max(1, int(current_shots * changes.weapon_shots_multiplier))

    return modified_weapon

## Modify visibility range
func get_visibility_range() -> int:
    var base_range = 999  # Unlimited by default

    for modifier_name in active_modifiers:
        var modifier = get_modifier(modifier_name)
        if modifier.is_empty():
            continue

        var changes = modifier.get("mechanical_changes", {})

        if changes.has("visibility_range"):
            base_range = min(base_range, changes.visibility_range)

    return base_range
```

### Step 4: Integrate with Game Systems

```gdscript
# Weapon system integration:
func get_character_weapon(character: Dictionary, weapon_name: String) -> Dictionary:
    var weapon = load_weapon_data(weapon_name)

    # Apply difficulty modifier
    weapon = DifficultyScalingSystem.modify_weapon_shots(weapon)

    return weapon

# Visibility system integration:
func can_see_target(viewer, target) -> bool:
    var distance = calculate_distance(viewer, target)
    var max_visibility = DifficultyScalingSystem.get_visibility_range()

    return distance <= max_visibility
```

---

## Code Examples

### Example 1: Mixed Squad Generation

```gdscript
# Generate a balanced squad with elites and standard enemies

func generate_balanced_squad(enemy_type: String, deployment_points: int) -> Array:
    EliteEnemySystem.set_deployment_mode("mixed_squads")

    # Determine total enemy count (standard + elite)
    var estimated_count = deployment_points  # Rough estimate

    # Generate mixed squad (1 elite per 3 standard)
    var squad = EliteEnemySystem.generate_mixed_squad(enemy_type, estimated_count)

    print("Generated squad with %d enemies:" % squad.size())
    for enemy in squad:
        if enemy.get("is_elite", false):
            print("  - %s (ELITE, %d DP)" % [enemy.name, EliteEnemySystem.get_deployment_cost(enemy)])
        else:
            print("  - %s (standard, 1 DP)" % enemy.enemy_type)

    # Verify deployment points
    var total_dp = EliteEnemySystem.calculate_elite_deployment_points(squad)
    print("Total deployment points: %d / %d" % [total_dp, deployment_points])

    return squad

# Example output:
# Generated squad with 7 enemies:
#   - Elite Mercenary (ELITE, 3 DP)
#   - Elite Mercenary (ELITE, 3 DP)
#   - Mercenary (standard, 1 DP)
#   - Mercenary (standard, 1 DP)
#   - Mercenary (standard, 1 DP)
#   - Mercenary (standard, 1 DP)
#   - Mercenary (standard, 1 DP)
# Total deployment points: 11 / 12
```

### Example 2: Boss Battle Generation

```gdscript
# Create a single powerful boss enemy

func generate_boss_battle(enemy_type: String, deployment_points: int) -> Dictionary:
    EliteEnemySystem.set_deployment_mode("boss_battles")

    # Generate boss (elite with +50% stats)
    var boss = EliteEnemySystem.generate_boss_enemy(enemy_type, deployment_points)

    print("=== BOSS BATTLE ===")
    print("Boss: %s" % boss.name)
    print("Stats: Combat %s, Toughness %d, Reactions %d" % [
        boss.combat_skill,
        boss.toughness,
        boss.reactions
    ])
    print("Abilities:")
    for ability in boss.special_abilities:
        print("  - %s: %s" % [ability.name, ability.effect])

    return boss

# Example output:
# === BOSS BATTLE ===
# Boss: Elite Mercenary
# Stats: Combat +3, Toughness 6, Reactions 3
# Abilities:
#   - Combat Veteran: Re-roll one failed to-hit roll per activation
#   - Tactical Positioning: May move 2" after making a ranged attack
```

### Example 3: Difficulty Preset Application

```gdscript
# Apply a difficulty preset and show stats

func apply_difficulty_preset(preset_name: String):
    print("\n=== Applying '%s' Difficulty ===" % preset_name)

    DifficultyScalingSystem.set_difficulty_preset(preset_name)

    # Show active modifiers
    var active_mods = DifficultyScalingSystem.get_active_modifiers()
    print("\nActive Modifiers (%d):" % active_mods.size())
    for mod in active_mods:
        print("  [%s] %s" % [mod.category, mod.name])
        print("    Effect: %s" % mod.effect)

    # Test enemy modification
    var base_enemy = {
        "name": "Mercenary",
        "combat_skill": "+0",
        "toughness": 3,
        "speed": 4
    }

    var modified_enemy = DifficultyScalingSystem.apply_to_enemy(base_enemy)

    print("\nEnemy Stat Changes:")
    print("  Combat Skill: +0 → %s" % modified_enemy.combat_skill)
    print("  Toughness: 3 → %d" % modified_enemy.toughness)

    # Test deployment points
    var base_dp = 10
    var modified_dp = DifficultyScalingSystem.modify_deployment_points(base_dp)
    print("\nDeployment Points: %d → %d" % [base_dp, modified_dp])

# Example output for "hard" preset:
# === Applying 'hard' Difficulty ===
#
# Active Modifiers (4):
#   [enemy_strength] Brutal Foes
#     Effect: Enemy forces are tougher and more resilient
#   [enemy_strength] Veteran Opposition
#     Effect: Enemies are more skilled in combat
#   [enemy_strength] Elite Foes
#     Effect: Replace standard enemies with elite variants
#   [danger] Desperate Combat
#     Effect: Injuries are more severe and frequent
#
# Enemy Stat Changes:
#   Combat Skill: +0 → +1
#   Toughness: 3 → 4
#
# Deployment Points: 10 → 10
```

### Example 4: Progressive Difficulty Campaign

```gdscript
# Campaign with auto-scaling difficulty

var campaign_turn = 0

func start_progressive_campaign():
    DifficultyScalingSystem.enable_progressive_difficulty(true)
    print("Progressive difficulty enabled")

func advance_campaign():
    campaign_turn += 1
    print("\n=== Campaign Turn %d ===" % campaign_turn)

    # Process progressive difficulty
    DifficultyScalingSystem.process_progressive_difficulty(campaign_turn)

    # Show current difficulty
    var stats = DifficultyScalingSystem.get_difficulty_stats()
    print("Active modifiers: %s" % ", ".join(stats.active_modifiers))

# Progressive difficulty rules (in JSON):
# {
#   "progressive_difficulty": {
#     "scaling_rules": [
#       {"campaign_turn": 5, "modifier": "Brutal Foes", "auto_enable": true},
#       {"campaign_turn": 10, "modifier": "Elite Foes", "auto_enable": true},
#       {"campaign_turn": 15, "modifier": "Veteran Opposition", "auto_enable": true}
#     ]
#   }
# }

# Example campaign progression:
# Turn 1-4: Standard difficulty
# Turn 5: "Brutal Foes" auto-enabled (+1 Toughness)
# Turn 10: "Elite Foes" auto-enabled (50% elite replacement)
# Turn 15: "Veteran Opposition" auto-enabled (+1 Combat Skill)
```

### Example 5: Adaptive Difficulty

```gdscript
# Difficulty that responds to player performance

func process_battle_outcome(won: bool, crew_deaths: int, credits: int):
    print("\n=== Battle Outcome ===")
    print("Result: %s" % ("Victory" if won else "Defeat"))
    print("Crew deaths: %d" % crew_deaths)
    print("Credits: %d" % credits)

    # Update adaptive difficulty
    var result = "victory" if won else "defeat"
    DifficultyScalingSystem.update_campaign_stats(result, crew_deaths, credits)

    # Check if difficulty changed
    var stats = DifficultyScalingSystem.get_difficulty_stats()
    print("\nAdaptive Stats:")
    print("  Consecutive victories: %d" % stats.campaign_stats.consecutive_victories)
    print("  Consecutive defeats: %d" % stats.campaign_stats.consecutive_defeats)
    print("  Total crew deaths: %d" % stats.campaign_stats.crew_deaths)

# Adaptive difficulty rules:
# - 3 consecutive victories → Enable 1 random modifier
# - 2 consecutive defeats → Disable 1 random modifier
# - Credits > 50 → Enable "Scarcity"
# - Credits < 10 → Disable "Scarcity"

# Example progression:
# Battle 1: Victory (consecutive victories: 1)
# Battle 2: Victory (consecutive victories: 2)
# Battle 3: Victory (consecutive victories: 3) → "Brutal Foes" auto-enabled
# Battle 4: Defeat (consecutive defeats: 1, victories reset to 0)
# Battle 5: Defeat (consecutive defeats: 2) → "Brutal Foes" auto-disabled
```

---

## Troubleshooting

### Problem: "Elite enemies not appearing"

**Symptoms**:
- Only standard enemies spawn
- `should_replace_with_elite()` always returns false

**Solutions**:

1. **Check DLC is enabled**:
```gdscript
var enabled = ExpansionManager.is_expansion_enabled("freelancers_handbook")
print("Freelancer's Handbook enabled: %s" % enabled)
```

2. **Verify deployment mode**:
```gdscript
print("Current deployment mode: %s" % EliteEnemySystem.deployment_mode)

# For guaranteed elites:
EliteEnemySystem.set_deployment_mode("elite_only_battles")

# For probabilistic replacement:
EliteEnemySystem.set_deployment_mode("standard_replacement")
EliteEnemySystem.set_replacement_rate(0.5)  # 50% chance
```

3. **Check if elite version exists**:
```gdscript
var elite = EliteEnemySystem.get_elite_version("Mercenary")
if elite.is_empty():
    print("No elite version for Mercenary!")
else:
    print("Elite version: %s" % elite.name)
```

### Problem: "Difficulty modifiers not affecting enemies"

**Symptoms**:
- Enabled modifiers but enemies unchanged
- Stats don't increase

**Solutions**:

1. **Verify modifiers are active**:
```gdscript
var active = DifficultyScalingSystem.get_active_modifiers()
print("Active modifiers: %d" % active.size())
for mod in active:
    print("  - %s: %s" % [mod.name, mod.mechanical_changes])
```

2. **Ensure apply_to_enemy() is called**:
```gdscript
# BAD - modifier not applied
func spawn_enemy(type: String) -> Dictionary:
    return {"enemy_type": type, "toughness": 3}

# GOOD - modifier applied
func spawn_enemy(type: String) -> Dictionary:
    var enemy = {"enemy_type": type, "toughness": 3}
    enemy = DifficultyScalingSystem.apply_to_enemy(enemy)  # Apply modifiers!
    return enemy
```

3. **Check modifier data loaded**:
```gdscript
print("Total modifiers available: %d" % DifficultyScalingSystem.difficulty_modifiers.size())

var brutal_foes = DifficultyScalingSystem.get_modifier("Brutal Foes")
print("Brutal Foes data: %s" % brutal_foes)
```

### Problem: "Boss battles too easy/hard"

**Symptoms**:
- Boss enemy dies quickly
- OR boss is unkillable

**Solutions**:

1. **Adjust deployment points**:
```gdscript
# More deployment points = stronger boss
var weak_boss = EliteEnemySystem.generate_boss_enemy("Mercenary", 10)
var strong_boss = EliteEnemySystem.generate_boss_enemy("Mercenary", 20)

print("Weak boss Toughness: %d" % weak_boss.toughness)   # Lower
print("Strong boss Toughness: %d" % strong_boss.toughness) # Higher
```

2. **Choose appropriate base enemy**:
```gdscript
# Weak base enemy (fast/fragile)
var scout_boss = EliteEnemySystem.generate_boss_enemy("Scout", 15)
# Toughness: 3 base * 1.5 = 4-5

# Strong base enemy (slow/tough)
var tank_boss = EliteEnemySystem.generate_boss_enemy("Heavy Trooper", 15)
# Toughness: 5 base * 1.5 = 7-8
```

3. **Manual boss customization**:
```gdscript
var boss = EliteEnemySystem.generate_boss_enemy("Mercenary", 15)

# Add custom abilities
boss.special_abilities.append({
    "name": "Regeneration",
    "effect": "Heals 1 damage at start of each round"
})

# Further boost stats
boss.toughness += 2
boss.reactions += 1
```

### Problem: "Adaptive difficulty not changing"

**Symptoms**:
- Win/lose streaks don't affect difficulty
- No auto-enable/disable of modifiers

**Solutions**:

1. **Enable adaptive difficulty**:
```gdscript
# Must be explicitly enabled
DifficultyScalingSystem.enable_adaptive_difficulty(true)

print("Adaptive enabled: %s" % DifficultyScalingSystem.adaptive_difficulty_enabled)
```

2. **Call update_campaign_stats() after battles**:
```gdscript
func complete_battle(won: bool):
    var deaths = count_crew_deaths()
    var credits = crew.credits

    # IMPORTANT: Update campaign stats to trigger adaptive logic
    DifficultyScalingSystem.update_campaign_stats(
        "victory" if won else "defeat",
        deaths,
        credits
    )
```

3. **Check adaptive rules**:
```gdscript
# View adaptive rules
print("Adaptive rules: %s" % DifficultyScalingSystem.adaptive_difficulty_rules)

# Manually trigger adaptive check
DifficultyScalingSystem.process_adaptive_difficulty()
```

---

## Best Practices

### 1. Use Appropriate Deployment Mode

```gdscript
# GOOD - Choose mode based on campaign style
match campaign_type:
    "story":
        # Occasional elite encounters
        EliteEnemySystem.set_deployment_mode("standard_replacement")
        EliteEnemySystem.set_replacement_rate(0.2)  # 20% chance
    "survival":
        # Mixed squads for tactical variety
        EliteEnemySystem.set_deployment_mode("mixed_squads")
    "challenge":
        # Elite-only for maximum difficulty
        EliteEnemySystem.set_deployment_mode("elite_only_battles")
```

### 2. Balance Deployment Points

```gdscript
# GOOD - Adjust deployment for elite battles
func calculate_deployment_points(base_points: int) -> int:
    var points = base_points

    # Apply difficulty modifiers first
    points = DifficultyScalingSystem.modify_deployment_points(points)

    # If using elite-only mode, multiply points
    if EliteEnemySystem.deployment_mode == "elite_only_battles":
        points = int(points * EliteEnemySystem.get_elite_only_multiplier())

    return points
```

### 3. Progressive Difficulty for Long Campaigns

```gdscript
# GOOD - Enable for campaigns 15+ turns
func start_campaign(campaign_length: int):
    if campaign_length >= 15:
        DifficultyScalingSystem.enable_progressive_difficulty(true)
        print("Progressive difficulty enabled for long campaign")
```

### 4. Test Difficulty Combinations

```gdscript
# GOOD - Test before applying to real campaign
func test_difficulty_combination(modifiers: Array):
    # Create test enemy
    var test_enemy = {
        "name": "Test Mercenary",
        "combat_skill": "+0",
        "toughness": 3
    }

    # Apply each modifier
    for mod_name in modifiers:
        DifficultyScalingSystem.enable_modifier(mod_name)

    # Check result
    test_enemy = DifficultyScalingSystem.apply_to_enemy(test_enemy)

    print("Test result with %d modifiers:" % modifiers.size())
    print("  Combat: %s, Toughness: %d" % [test_enemy.combat_skill, test_enemy.toughness])

    # Clean up
    for mod_name in modifiers:
        DifficultyScalingSystem.disable_modifier(mod_name)
```

---

## Summary

**Freelancer's Handbook** adds meaningful depth through:

1. **Elite Enemy System** - Enhanced enemies with special abilities and balanced deployment
2. **Difficulty Scaling** - Modular customization of challenge level
3. **Progressive/Adaptive Difficulty** - Dynamic challenge that responds to campaign/performance
4. **Tactical Variety** - Different deployment modes for different play styles

**Key Integration Points**:
- `EliteEnemySystem.generate_enemy()` - Enemy generation with elite replacement
- `DifficultyScalingSystem.apply_to_enemy()` - Apply difficulty modifiers
- `EliteEnemySystem.trigger_ability()` - Special ability execution
- `DifficultyScalingSystem.update_campaign_stats()` - Adaptive difficulty updates

**Next Steps**:
- See [Elite Enemy Design Guide](./ELITE_ENEMY_DESIGN_GUIDE.md) for creating new elites
- See [Difficulty Modifier Format Specification](./DIFFICULTY_MODIFIER_FORMAT_SPEC.md) for data format details
- See [EliteEnemySystem Deep Dive](./ELITE_ENEMY_SYSTEM_REFERENCE.md) for complete API documentation

---

*For information on other expansions, see [Trailblazer's Toolkit Integration](./TRAILBLAZERS_TOOLKIT_INTEGRATION.md) and [Fixer's Guidebook Integration](./FIXERS_GUIDEBOOK_INTEGRATION.md)*
