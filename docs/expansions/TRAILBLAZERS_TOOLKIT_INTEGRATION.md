# Trailblazer's Toolkit Integration Guide

## Overview

**Trailblazer's Toolkit** is the first expansion DLC for Five Parsecs from Home, introducing two major gameplay systems:

1. **Psionic Powers** - Mental abilities and telekinetic powers for characters
2. **Expanded Species** - Additional playable alien races with unique traits

This guide explains the architecture, integration patterns, and extensibility of these systems.

---

## Table of Contents

1. [Expansion Contents](#expansion-contents)
2. [PsionicSystem Architecture](#psionicsystem-architecture)
3. [Psionic Power Mechanics](#psionic-power-mechanics)
4. [Species System](#species-system)
5. [Integration with Core Systems](#integration-with-core-systems)
6. [Adding New Psionic Powers](#adding-new-psionic-powers)
7. [Adding New Species](#adding-new-species)
8. [Code Examples](#code-examples)
9. [Troubleshooting](#troubleshooting)

---

## Expansion Contents

### Data Files

Located in `/data/dlc/trailblazers_toolkit/`:

- **`trailblazers_toolkit_psionic_powers.json`** - 10 psionic powers
- **`trailblazers_toolkit_species.json`** - 2 playable alien species

### Systems

Located in `/src/core/systems/`:

- **`PsionicSystem.gd`** - Manages all psionic power mechanics
  - Power activation and targeting
  - Effect application
  - Duration tracking
  - Active power management

### Psionic Powers Included

| Power | Difficulty | Target Type | Effect Summary |
|-------|-----------|-------------|----------------|
| Barrier | Basic | Any | Deflect ranged attacks (4+ save) |
| Grab | Intermediate | Enemy | Immobilize target |
| Lift | Intermediate | Any | Levitate and move objects/creatures |
| Push | Basic | Enemy | Knockback + potential stun |
| Sever | Advanced | Enemy | Psionic damage ignoring armor |
| Shielding | Intermediate | Self | Grant/improve armor save |
| Step | Advanced | Self | Teleport to visible location |
| Stun | Intermediate | Enemy | Incapacitate for 1D3 rounds |
| Suggestion | Advanced | Enemy | Mind control (1 simple command) |
| Weaken | Intermediate | Enemy | Reduce Toughness and Combat Skill |

### Species Included

| Species | Movement | Toughness | Special Traits |
|---------|----------|-----------|----------------|
| **Krag** | 3" | 4 | Belligerent, Tough, Combat Readiness |
| **Skulker** | 5" | 3 | Agile, Keen Senses, Biological Resistance |

---

## PsionicSystem Architecture

### System Design Philosophy

The `PsionicSystem` follows these core principles:

1. **Autoload Singleton** - Globally accessible via `PsionicSystem`
2. **Signal-Based Communication** - Events notify other systems
3. **Data-Driven** - Powers loaded from JSON, not hardcoded
4. **DLC Gating** - Powers only available with Trailblazer's Toolkit enabled
5. **Character-Agnostic** - Works with Dictionary or Resource-based characters

### Class Structure

```gdscript
class_name PsionicSystem
extends Node

# ============= PUBLIC API =============

# Power Database
func get_all_powers() -> Array
func get_power(power_name: String) -> Dictionary
func get_available_powers(character) -> Array

# Power Activation
func activate_power(caster, power_name: String, target = null) -> bool
func can_target(power: Dictionary, caster, target) -> bool

# Active Power Management
func process_active_powers(character) -> void
func get_active_powers(character) -> Array
func has_active_power(character, power_name: String) -> bool
func end_power(character, power_name: String) -> void
func clear_all_powers(character) -> void

# Utility
func get_power_difficulty_value(power: Dictionary) -> int
func get_activation_target(power: Dictionary) -> int

# ============= SIGNALS =============

signal power_activated(character, power_name: String, target, success: bool)
signal power_expired(character, power_name: String)
signal power_effect_applied(target, effect_name: String, power_name: String)
```

### Data Flow

```
1. Character Activation
   ↓
2. Player selects psionic power
   ↓
3. PsionicSystem.activate_power(caster, "PowerName", target)
   ↓
4. System validates:
   - DLC enabled?
   - Character is psyker?
   - Power exists?
   - Target valid?
   ↓
5. Roll activation (1D6 + Savvy vs Target Number)
   ↓
6. If successful:
   - Apply power effects
   - Track if persists
   - Emit power_activated signal
   ↓
7. Each round: process_active_powers(character)
   - Decrement duration
   - Expire finished powers
   - Emit power_expired signal
```

### Power Data Structure

```json
{
  "name": "Barrier",
  "description": "Create a protective energy field...",
  "target_type": "any",           // "self" | "enemy" | "any"
  "range": "line_of_sight",       // "self" | "6\"" | "12\"" | "line_of_sight"
  "persists": true,               // Does power have duration?
  "affects_robotic": true,        // Can target robots?
  "dlc_required": "trailblazers_toolkit",
  "source": "trailblazers_toolkit",
  "cost": 3,                      // XP cost to learn
  "difficulty": "basic",          // "basic" | "intermediate" | "advanced"
  "activation": {
    "type": "combat_action",      // Action type required
    "activation_roll": "4+",      // Target number (1D6 + Savvy)
    "duration": "Until caster's next activation"
  },
  "effects": [
    {
      "name": "Deflection",
      "description": "Each ranged hit on protected target must roll 4+ or is negated"
    }
  ]
}
```

---

## Psionic Power Mechanics

### Character Requirements

A character can use psionic powers if they meet **any** of these criteria:

```gdscript
# Method 1: Character type
character.character_type == "Psyker"

# Method 2: Has psionic ability
character.abilities contains "psionic" (case-insensitive)

# Method 3: Has known powers
character.known_powers.size() > 0

# Method 4: Resource with is_psyker flag
character.is_psyker == true
```

### Power Activation Flow

#### Step 1: Validation

```gdscript
# Character can use psionics?
if not _is_psyker(character):
    return false

# Power exists?
var power = get_power("Barrier")
if power.is_empty():
    return false

# Target is valid?
if not _validate_target(power, caster, target):
    return false
```

#### Step 2: Activation Roll

```gdscript
# Formula: 1D6 + Savvy vs Target Number
var roll = randi() % 6 + 1
var savvy = character.savvy
var total = roll + savvy
var target_number = get_activation_target(power)  # e.g., "5+" → 5

var success = (total >= target_number)
```

**Example**:
- Power: "Grab" (requires 5+)
- Character Savvy: +2
- Roll: 4
- Total: 4 + 2 = 6
- Result: **SUCCESS** (6 ≥ 5)

#### Step 3: Effect Application

```gdscript
# Apply immediate effects
for effect in power.effects:
    _apply_single_effect(caster, power, target, effect)
    power_effect_applied.emit(target, effect.name, power.name)

# Example: Barrier grants deflection
target.active_effects.append({
    "type": "barrier",
    "deflection_chance": 4  # 4+ to deflect
})
```

#### Step 4: Duration Tracking

```gdscript
# If power persists, track it
if power.persists:
    active_powers[character_id].append({
        "power": power,
        "target": target,
        "rounds_remaining": _parse_duration(power.activation.duration),
        "activated_on_turn": current_turn
    })
```

### Duration Parsing

| Duration String | Rounds | Notes |
|----------------|--------|-------|
| `"Instant"` | 0 | Immediate effect, no tracking |
| `"Until caster's next activation"` | 1 | Lasts 1 round |
| `"1D3 rounds"` | 1-3 | Random duration |
| `"Concentration"` | 999 | Until broken or released |

### Target Types

| Type | Valid Targets | Example Power |
|------|--------------|---------------|
| `"self"` | Only caster (target can be null or caster) | Shielding, Step |
| `"enemy"` | Any target except caster | Grab, Stun, Weaken |
| `"any"` | Any valid target including caster | Barrier, Lift |

### Power Difficulty Levels

| Difficulty | Typical Roll | XP Cost | Power Examples |
|-----------|-------------|---------|----------------|
| **Basic** | 4+ | 3-4 | Barrier, Push |
| **Intermediate** | 5+ | 4-5 | Grab, Shielding, Weaken |
| **Advanced** | 5-7+ | 5-7 | Sever, Step, Suggestion |

**Note**: Savvy bonus makes higher difficulties achievable:
- Savvy +2 character has ~83% success on 4+
- Savvy +3 character has ~100% success on 4+, ~83% on 5+

---

## Species System

### Species Data Structure

```json
{
  "name": "Krag",
  "playable": true,
  "description": "Stocky, belligerent humanoids...",
  "homeworld": "Krag diaspora (no unified homeworld)",
  "traits": [
    "Belligerent: Prone to aggression and conflict",
    "Tough: Enhanced physical durability",
    "Short-legged: Reduced movement speed"
  ],
  "starting_bonus": "+1 Toughness, -1\" Movement",
  "dlc_required": "trailblazers_toolkit",
  "source": "trailblazers_toolkit",
  "base_profile": {
    "reactions": 1,
    "speed": "3\"",
    "combat_skill": "+0",
    "toughness": 4,
    "savvy": "+0"
  },
  "special_rules": [
    {
      "name": "Famous Belligerence",
      "description": "Krag characters are prone to conflict",
      "mechanical_effect": "When rolling for Rivals, may reroll a natural 1..."
    }
  ]
}
```

### Species Comparison

#### Krag - The Bruiser

**Strengths**:
- **+1 Toughness** (4 instead of 3) - Survives more hits
- Combat-focused abilities
- Can reroll Rival generation (but might gain more)

**Weaknesses**:
- **-1" Movement** (3" instead of 4") - Slower
- Prone to getting in fights (narrative drawback)
- Krag-specific armor (equipment lock-in)

**Playstyle**: Frontline tank, melee combat, absorb damage

**Best For**:
- Brawler characters
- Defensive positions
- Close-quarters combat
- Players who want durability over mobility

#### Skulker - The Scout

**Strengths**:
- **+1" Movement** (5" instead of 4") - Fastest species
- **Biological Resistance** - Immune to toxins/disease
- **+1 Detection** - Better at spotting threats
- Re-roll failed initiative once per battle

**Weaknesses**:
- **-1 to morale checks** (skittish)
- Standard 3 Toughness (fragile)
- Narrative cowardice

**Playstyle**: Scout, flanker, hit-and-run tactics

**Best For**:
- Reconnaissance missions
- Stealth operations
- Ranged combat specialists
- Players who value mobility and detection

### Species Mechanical Integration

Species modify the core character profile:

```gdscript
# Example: Creating a Krag character

# Start with base Five Parsecs character
var character = {
    "reactions": 1,
    "speed": 4,
    "combat_skill": 0,
    "toughness": 3,
    "savvy": 0
}

# Apply Krag species modifiers
character.species = "Krag"
character.toughness = 4        # +1 from Krag
character.speed = 3            # -1" from Krag
character.special_rules.append("Famous Belligerence")
character.special_rules.append("Combat Readiness")
character.special_rules.append("Movement Limitation")
```

---

## Integration with Core Systems

### Combat System Integration

Psionic powers integrate seamlessly with core combat:

```gdscript
# During combat round:

# 1. Character activates psionic power (counts as combat action)
var success = PsionicSystem.activate_power(character, "Barrier", ally)

# 2. Core combat continues normally
combat_system.resolve_attacks()

# 3. Psionic effects modify combat resolution
if target.has_active_effect("barrier"):
    # Roll 4+ to deflect ranged hit
    var deflect_roll = randi() % 6 + 1
    if deflect_roll >= 4:
        print("Attack deflected by Barrier!")
        return  # Negate hit

# 4. At end of round, process power durations
PsionicSystem.process_active_powers(character)
```

### Character Creation Integration

```gdscript
# Character creation flow:

func create_character() -> Dictionary:
    var character = {
        "reactions": 1,
        "speed": 4,
        "combat_skill": 0,
        "toughness": 3,
        "savvy": 0
    }

    # Allow species selection if DLC enabled
    if ExpansionManager.is_expansion_enabled("trailblazers_toolkit"):
        var species_choice = _prompt_species_selection()
        _apply_species_modifiers(character, species_choice)

    # Check if character is psyker
    if character.background == "Psyker" or _roll_psionic_talent():
        character.known_powers = _select_starting_powers()

    return character
```

### Save Game Integration

```gdscript
# Active powers must be saved/loaded:

func save_character(character: Dictionary) -> Dictionary:
    var save_data = {
        # ... core character data
        "species": character.species,
        "known_powers": character.known_powers,
        "active_powers": PsionicSystem.get_active_powers(character)
    }
    return save_data

func load_character(save_data: Dictionary) -> Dictionary:
    var character = _load_core_stats(save_data)

    # Restore known powers
    character.known_powers = save_data.get("known_powers", [])

    # Re-activate persistent powers
    for active_power in save_data.get("active_powers", []):
        PsionicSystem._track_active_power(
            character,
            active_power.power,
            active_power.target
        )

    return character
```

---

## Adding New Psionic Powers

### Step 1: Design the Power

Consider these questions:

1. **What does it do?** - Clear mechanical effect
2. **Who can it target?** - Self, enemy, or any?
3. **How long does it last?** - Instant or persistent?
4. **How difficult is it?** - Basic (4+), Intermediate (5+), Advanced (6-7+)?
5. **Does it affect robots?** - Physical or mental effect?
6. **What's the cost?** - XP investment (3-7)

### Step 2: Add to Data File

Edit `/data/dlc/trailblazers_toolkit/trailblazers_toolkit_psionic_powers.json`:

```json
{
  "psionic_powers": [
    // ... existing powers ...
    {
      "name": "Mind Shield",
      "description": "Create a mental barrier that protects against psionic attacks.",
      "target_type": "self",
      "range": "self",
      "persists": true,
      "affects_robotic": false,
      "dlc_required": "trailblazers_toolkit",
      "source": "trailblazers_toolkit",
      "cost": 4,
      "difficulty": "intermediate",
      "activation": {
        "type": "combat_action",
        "activation_roll": "5+",
        "duration": "Until caster's next activation"
      },
      "effects": [
        {
          "name": "Psionic Immunity",
          "description": "Immune to enemy psionic powers while active. Hostile psykers targeting you must roll 6+ instead of their normal target."
        }
      ]
    }
  ]
}
```

### Step 3: Implement Effect (Optional)

If the power has complex mechanics, add implementation to `PsionicSystem.gd`:

```gdscript
func _apply_single_effect(caster, power: Dictionary, target, effect: Dictionary) -> void:
    match power.name:
        # ... existing powers ...
        "Mind Shield":
            _apply_mind_shield_effect(target)

func _apply_mind_shield_effect(target) -> void:
    if target is Dictionary:
        if not target.has("active_effects"):
            target.active_effects = []
        target.active_effects.append({
            "type": "mind_shield",
            "psionic_resistance": 6  # Enemies need 6+ to target
        })
```

### Step 4: Test the Power

```gdscript
# Test script:
func test_new_power():
    var psyker = {
        "id": "test_psyker",
        "savvy": 2,
        "character_type": "Psyker",
        "known_powers": ["Mind Shield"]
    }

    # Activate power
    var success = PsionicSystem.activate_power(psyker, "Mind Shield", psyker)
    assert(success, "Power activation should succeed")

    # Verify effect applied
    assert(psyker.active_effects.size() > 0, "Effect should be active")
    assert(psyker.active_effects[0].type == "mind_shield", "Correct effect type")

    # Process duration
    PsionicSystem.process_active_powers(psyker)

    print("✓ Mind Shield power test passed")
```

---

## Adding New Species

### Step 1: Design Species Identity

**Concept Questions**:
1. What is their culture/personality?
2. What are they good at?
3. What are they bad at?
4. What makes them unique mechanically?

**Balance Guidelines**:
- Total stat modifiers should sum to ~0
  - Example: +1 Toughness, -1" Speed = balanced
  - Example: +1" Speed, -1 morale = balanced
- Special abilities should have tradeoffs
- Aim for distinctiveness, not power

### Step 2: Create Species Profile

Edit `/data/dlc/trailblazers_toolkit/trailblazers_toolkit_species.json`:

```json
{
  "species": [
    // ... existing species ...
    {
      "name": "Satori",
      "playable": true,
      "description": "Telepathic humanoids with enhanced mental faculties but fragile bodies. Satori are natural psykers with an affinity for mental disciplines.",
      "homeworld": "Mindspire Colonies",
      "traits": [
        "Telepathic: Natural psionic abilities",
        "Fragile: Reduced physical durability",
        "Mindlinked: Enhanced coordination"
      ],
      "starting_bonus": "+2 Savvy, -1 Toughness, Start with 1 random psionic power",
      "dlc_required": "trailblazers_toolkit",
      "source": "trailblazers_toolkit",
      "base_profile": {
        "reactions": 1,
        "speed": "4\"",
        "combat_skill": "+0",
        "toughness": 2,
        "savvy": "+2"
      },
      "special_rules": [
        {
          "name": "Natural Psyker",
          "description": "Born with psionic talent",
          "mechanical_effect": "All Satori characters start with 1 random psionic power. Learning additional powers costs -1 XP (minimum 2)."
        },
        {
          "name": "Mindlink",
          "description": "Telepathic coordination with allies",
          "mechanical_effect": "Once per battle, may grant +1 to any ally's roll within 12\" as a free action."
        },
        {
          "name": "Fragile Frame",
          "description": "Physically weak constitution",
          "mechanical_effect": "Toughness reduced to 2. When rolling for injuries, reroll any natural 6 (must accept second result)."
        }
      ]
    }
  ]
}
```

### Step 3: Balance Validation

**Satori Species Balance Analysis**:

**Bonuses**:
- +2 Savvy (very strong - better psionic activation, better skill checks)
- Start with free psionic power (value ~3-7 XP)
- Mindlink ability (tactical bonus)
- Cheaper power learning (-1 XP per power)

**Penalties**:
- -1 Toughness (major weakness - dies much easier)
- Injury reroll on 6 (narrative penalty)

**Verdict**: Balanced for psionic-focused playstyle. High risk (fragile), high reward (powerful psionics).

### Step 4: Integration Code

```gdscript
# Character creation integration:

func apply_species_modifiers(character: Dictionary, species_name: String) -> void:
    var species_data = _load_species_data(species_name)

    # Apply base profile
    character.reactions = species_data.base_profile.reactions
    character.speed = _parse_speed(species_data.base_profile.speed)
    character.combat_skill = _parse_modifier(species_data.base_profile.combat_skill)
    character.toughness = species_data.base_profile.toughness
    character.savvy = _parse_modifier(species_data.base_profile.savvy)

    # Apply special rules
    character.species = species_name
    character.special_rules = []
    for rule in species_data.special_rules:
        character.special_rules.append(rule.name)

    # Species-specific initialization
    match species_name:
        "Satori":
            # Grant starting psionic power
            var random_power = _get_random_basic_power()
            character.known_powers = [random_power]
        "Krag":
            # Flag for Krag-armor compatibility
            character.krag_armor_compatible = true
        "Skulker":
            # Grant biological resistance
            character.resistances.append("biological")
```

---

## Code Examples

### Example 1: Psyker Character Creation

```gdscript
func create_psyker_character() -> Dictionary:
    var character = {
        "id": generate_id(),
        "name": "Zara Mindweaver",
        "species": "Human",
        "character_type": "Psyker",

        # Core stats
        "reactions": 1,
        "speed": 4,
        "combat_skill": 0,
        "toughness": 3,
        "savvy": 2,  # Higher Savvy for psykers

        # Psionic setup
        "known_powers": ["Barrier", "Push", "Shielding"],
        "max_powers": 5,

        # Standard character data
        "xp": 0,
        "level": 1,
        "equipment": ["Hand Cannon", "Flak Screen"],
        "credits": 15
    }

    return character
```

### Example 2: Combat with Psionic Powers

```gdscript
func example_combat_round(psyker: Dictionary, ally: Dictionary, enemy: Dictionary):
    print("=== Psyker's Turn ===")

    # 1. Psyker activates Barrier on ally
    print("Psyker casts Barrier on ally...")
    var barrier_success = PsionicSystem.activate_power(psyker, "Barrier", ally)

    if barrier_success:
        print("✓ Barrier active! Ally gains deflection (4+)")
    else:
        print("✗ Barrier failed to activate")

    print("\n=== Enemy's Turn ===")

    # 2. Enemy shoots at protected ally
    print("Enemy fires at ally...")
    var hit_roll = randi() % 6 + 1 + enemy.combat_skill
    var target_number = 10 - ally.reactions

    if hit_roll >= target_number:
        print("Hit! But ally has Barrier...")

        # Check for deflection
        var deflect_roll = randi() % 6 + 1
        if deflect_roll >= 4:
            print("✓ Attack deflected by Barrier!")
            return  # No damage
        else:
            print("✗ Barrier failed to deflect")

    # 3. Resolve damage normally
    var damage = 1
    var armor_save = randi() % 6 + 1
    # ... continue combat resolution

    print("\n=== End of Round ===")

    # 4. Process active powers
    PsionicSystem.process_active_powers(psyker)
    print("Barrier expires (lasted 1 round)")
```

### Example 3: Satori Species Character

```gdscript
func create_satori_character() -> Dictionary:
    var character = {
        "id": generate_id(),
        "name": "Vel'kara",
        "species": "Satori",

        # Satori base profile
        "reactions": 1,
        "speed": 4,
        "combat_skill": 0,
        "toughness": 2,  # Fragile!
        "savvy": 2,       # Enhanced mental stats

        # Natural psyker
        "character_type": "Psyker",
        "known_powers": [_get_random_basic_power()],  # Free starting power

        # Special rules
        "special_rules": ["Natural Psyker", "Mindlink", "Fragile Frame"],

        # Metadata
        "xp": 0,
        "level": 1,
        "mindlink_used_this_battle": false
    }

    return character

func use_mindlink_ability(satori: Dictionary, ally: Dictionary):
    # Can only use once per battle
    if satori.mindlink_used_this_battle:
        print("Mindlink already used this battle")
        return false

    # Check range
    var distance = calculate_distance(satori, ally)
    if distance > 12:
        print("Ally too far for Mindlink (>12\")")
        return false

    # Grant +1 bonus to ally's next roll
    ally.next_roll_bonus = ally.get("next_roll_bonus", 0) + 1
    satori.mindlink_used_this_battle = true

    print("✓ Mindlink activated! %s gets +1 to next roll" % ally.name)
    return true
```

### Example 4: Learning New Powers

```gdscript
func learn_psionic_power(character: Dictionary, power_name: String) -> bool:
    # Check if character can learn powers
    if not PsionicSystem._is_psyker(character):
        print("Character is not a psyker")
        return false

    # Get power data
    var power = PsionicSystem.get_power(power_name)
    if power.is_empty():
        print("Power not found: %s" % power_name)
        return false

    # Check if already known
    if character.known_powers.has(power_name):
        print("Power already known")
        return false

    # Calculate XP cost
    var base_cost = power.cost
    var cost = base_cost

    # Satori species discount
    if character.species == "Satori":
        cost = max(2, cost - 1)

    # Check XP availability
    if character.xp < cost:
        print("Not enough XP. Need %d, have %d" % [cost, character.xp])
        return false

    # Learn power
    character.xp -= cost
    character.known_powers.append(power_name)

    print("✓ Learned %s for %d XP" % [power_name, cost])
    return true
```

---

## Troubleshooting

### Problem: "Psionic powers not loading"

**Symptoms**:
- `PsionicSystem: Failed to load psionic powers data`
- Powers array is empty

**Solutions**:

1. **Check DLC is enabled**:
```gdscript
# Verify expansion is active
var enabled = ExpansionManager.is_expansion_enabled("trailblazers_toolkit")
print("Trailblazer's Toolkit enabled: %s" % enabled)

# If false, enable it
ExpansionManager.enable_expansion("trailblazers_toolkit")
```

2. **Verify file path**:
```gdscript
# Check file exists
var file_path = "res://data/dlc/trailblazers_toolkit/trailblazers_toolkit_psionic_powers.json"
var file_exists = FileAccess.file_exists(file_path)
print("Powers file exists: %s" % file_exists)
```

3. **Validate JSON format**:
```bash
# Use JSON validator
cat trailblazers_toolkit_psionic_powers.json | jq .
# Should show formatted JSON without errors
```

### Problem: "Character cannot activate powers"

**Symptoms**:
- `activate_power()` returns false
- "Character cannot use psionics" warning

**Solutions**:

1. **Verify character is psyker**:
```gdscript
# Check all psyker conditions
print("Character type: %s" % character.get("character_type", "none"))
print("Has abilities: %s" % character.has("abilities"))
print("Known powers: %s" % character.get("known_powers", []))

# Manually mark as psyker
character.character_type = "Psyker"
# OR
character.known_powers = ["Barrier"]  # Any power makes them a psyker
```

2. **Check ContentFilter**:
```gdscript
# Verify content filtering allows psionics
var allowed = PsionicSystem.content_filter.is_content_type_available("psionic_powers")
print("Psionic powers allowed: %s" % allowed)
```

### Problem: "Power activation always fails"

**Symptoms**:
- Activation roll never succeeds
- Character has low Savvy

**Solutions**:

1. **Increase character Savvy**:
```gdscript
# Psykers should have at least +1 Savvy
character.savvy = max(1, character.savvy)

# For reliability, +2 or +3 recommended
character.savvy = 2  # 83% success on 4+, 66% on 5+
```

2. **Use easier powers first**:
```gdscript
# Start with Basic difficulty (4+)
var easy_powers = ["Barrier", "Push"]

# Avoid Advanced (6-7+) until Savvy +3
var hard_powers = ["Step", "Suggestion"]  # Requires high Savvy
```

3. **Add activation bonuses**:
```gdscript
# Modify activation roll in PsionicSystem
func _roll_activation(caster, power: Dictionary) -> bool:
    var target_number = get_activation_target(power)
    var roll = randi() % 6 + 1
    var savvy = _get_character_savvy(caster)

    # Add situational bonuses
    var bonus = 0
    if caster.get("psionic_amplifier_equipped", false):
        bonus += 1
    if caster.get("meditation_bonus", false):
        bonus += 1

    var total = roll + savvy + bonus
    return total >= target_number
```

### Problem: "Active powers not expiring"

**Symptoms**:
- Powers last forever
- `process_active_powers()` not being called

**Solutions**:

1. **Call process_active_powers() each round**:
```gdscript
# In your combat/round loop:
func process_round():
    # ... combat actions ...

    # IMPORTANT: Process active powers for all characters
    for character in all_characters:
        PsionicSystem.process_active_powers(character)

    round_number += 1
```

2. **Verify duration tracking**:
```gdscript
# Check active powers
var active = PsionicSystem.get_active_powers(character)
for power_data in active:
    print("Power: %s, Rounds left: %d" % [
        power_data.power.name,
        power_data.rounds_remaining
    ])
```

### Problem: "Species modifiers not applying"

**Symptoms**:
- Krag doesn't have 4 Toughness
- Skulker doesn't have 5" movement

**Solutions**:

1. **Apply species modifiers during character creation**:
```gdscript
func create_character(species_name: String) -> Dictionary:
    # Start with human baseline
    var character = create_base_character()

    # IMPORTANT: Apply species modifiers
    if species_name != "Human":
        apply_species_modifiers(character, species_name)

    return character
```

2. **Load species data correctly**:
```gdscript
func apply_species_modifiers(character: Dictionary, species_name: String):
    var species_data = ExpansionManager.load_expansion_data(
        "trailblazers_toolkit",
        "trailblazers_toolkit_species.json"
    )

    var species = null
    for s in species_data.species:
        if s.name == species_name:
            species = s
            break

    if not species:
        push_error("Species not found: %s" % species_name)
        return

    # Apply base profile
    character.toughness = species.base_profile.toughness
    character.speed = int(species.base_profile.speed.replace("\"", ""))
    # ... etc
```

---

## Advanced Topics

### Custom Power Effect Hooks

To allow mods to add custom power effects without modifying `PsionicSystem.gd`:

```gdscript
# In PsionicSystem.gd, add signal for custom effects
signal custom_power_effect_requested(power: Dictionary, caster, target)

func _apply_single_effect(caster, power: Dictionary, target, effect: Dictionary) -> void:
    # Try built-in effects first
    match power.name:
        "Barrier": _apply_barrier_effect(target)
        "Grab": _apply_grab_effect(target)
        # ... etc
        _:
            # Emit signal for custom handling
            custom_power_effect_requested.emit(power, caster, target)

# Then in a custom mod:
func _ready():
    PsionicSystem.custom_power_effect_requested.connect(_handle_custom_power)

func _handle_custom_power(power: Dictionary, caster, target):
    match power.name:
        "Mind Blast":  # Custom power
            _apply_mind_blast(caster, target)
        "Teleport Ally":
            _apply_teleport_ally(caster, target)
```

### Psionic Items and Amplifiers

```gdscript
# Equipment that enhances psionics
var psionic_amplifier = {
    "name": "Psionic Amplifier",
    "type": "accessory",
    "cost": 20,
    "effects": {
        "psionic_activation_bonus": +1,  # +1 to activation rolls
        "power_range_bonus": 4            # +4" to power range
    }
}

# Modify activation with equipment bonuses
func _roll_activation(caster, power: Dictionary) -> bool:
    var bonus = 0

    # Check for psionic amplifier
    for item in caster.get("equipment", []):
        if item.get("psionic_activation_bonus", 0) > 0:
            bonus += item.psionic_activation_bonus

    var total = roll + savvy + bonus
    return total >= target_number
```

---

## Best Practices

### 1. Always Check DLC Availability

```gdscript
# GOOD
if ExpansionManager.is_expansion_enabled("trailblazers_toolkit"):
    var powers = PsionicSystem.get_all_powers()
    # ... use powers

# BAD - will crash if DLC not enabled
var powers = PsionicSystem.get_all_powers()  # Might be empty!
```

### 2. Process Active Powers Every Round

```gdscript
# GOOD - in main game loop
func process_battle_round():
    for character in all_characters:
        PsionicSystem.process_active_powers(character)

# BAD - forgetting to process
func process_battle_round():
    # ... combat logic ...
    # Missing: PsionicSystem.process_active_powers()
    # Powers will never expire!
```

### 3. Use Signals for Integration

```gdscript
# GOOD - respond to psionic events
func _ready():
    PsionicSystem.power_activated.connect(_on_power_activated)

func _on_power_activated(character, power_name, target, success):
    if success:
        show_visual_effect(power_name, target)
        play_sound("psionic_activation")

# BAD - polling
func _process(delta):
    # Don't do this - inefficient
    if PsionicSystem.has_active_power(character, "Barrier"):
        # ...
```

### 4. Balance Psionic Characters

```gdscript
# Psykers should have tradeoffs:

# GOOD - specialized psyker
var psyker = {
    "savvy": 3,           # High mental stats
    "combat_skill": -1,   # Poor combat
    "toughness": 3,       # Standard durability
    "known_powers": ["Barrier", "Push", "Weaken"]
}

# BAD - overpowered
var op_psyker = {
    "savvy": 3,
    "combat_skill": 2,   # Also great at combat
    "toughness": 5,      # Very durable
    "known_powers": [...] # All powers
}
```

---

## Summary

**Trailblazer's Toolkit** adds meaningful depth to Five Parsecs through:

1. **Psionic Powers** - 10 balanced abilities with clear activation mechanics
2. **Expanded Species** - 2 distinct races with unique playstyles
3. **Modular Integration** - Systems that enhance without replacing core gameplay
4. **Extensibility** - Easy to add new powers and species

**Key Integration Points**:
- `PsionicSystem.activate_power()` - Power activation
- `PsionicSystem.process_active_powers()` - Duration management
- Species modifiers during character creation
- Signal-based effect application

**Next Steps**:
- See [Psionic Powers Format Specification](./PSIONIC_POWERS_FORMAT_SPEC.md) for detailed data format
- See [Species Creation Guide](./SPECIES_CREATION_GUIDE.md) for creating new alien races
- See [PsionicSystem Deep Dive](./PSIONIC_SYSTEM_REFERENCE.md) for complete API documentation

---

*For information on other expansions, see [Freelancer's Handbook Integration](./FREELANCERS_HANDBOOK_INTEGRATION.md) and [Fixer's Guidebook Integration](./FIXERS_GUIDEBOOK_INTEGRATION.md)*
