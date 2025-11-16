# DLC Systems Integration Guide

This document explains how to integrate and use all DLC expansion systems in the Five Parsecs Campaign Manager.

## Table of Contents

1. [System Overview](#system-overview)
2. [Autoload Setup](#autoload-setup)
3. [System Usage](#system-usage)
4. [Integration Examples](#integration-examples)
5. [Cross-System Integration](#cross-system-integration)
6. [Testing DLC Systems](#testing-dlc-systems)

---

## System Overview

The DLC expansion system consists of the following components:

### Core Systems

1. **ExpansionManager** (`src/core/managers/ExpansionManager.gd`)
   - Central hub for all DLC content
   - Manages DLC ownership and licensing
   - Provides content loading and caching
   - Handles bundle support (Complete Compendium)

2. **ContentFilter** (`src/core/utils/ContentFilter.gd`)
   - Utility class for filtering content by DLC ownership
   - Used by all other systems to check availability
   - Provides user-friendly lock messages

### DLC-Specific Systems

3. **PsionicSystem** (`src/core/systems/PsionicSystem.gd`)
   - **DLC**: Trailblazer's Toolkit
   - **Features**: Psionic powers, activation rolls, duration tracking
   - **Powers**: 10 psionic powers (Barrier, Grab, Lift, Push, Sever, Shielding, Step, Stun, Suggestion, Weaken)

4. **DifficultyScalingSystem** (`src/core/systems/DifficultyScalingSystem.gd`)
   - **DLC**: Freelancer's Handbook
   - **Features**: 8 difficulty modifiers, 5 presets, progressive/adaptive scaling
   - **Modifiers**: Brutal Foes, Larger Battles, Veteran Opposition, Elite Foes, Desperate Combat, Scarcity, High Stakes, Lethal Encounters

5. **EliteEnemySystem** (`src/core/systems/EliteEnemySystem.gd`)
   - **DLC**: Freelancer's Handbook
   - **Features**: 10 elite enemy types, special abilities, deployment modes
   - **Modes**: Standard Replacement, Elite-Only, Mixed Squads, Boss Battles

6. **StealthMissionSystem** (`src/core/systems/StealthMissionSystem.gd`)
   - **DLC**: Fixer's Guidebook
   - **Features**: Alarm systems, detection mechanics, stealth objectives
   - **Missions**: Corporate Infiltration, Warehouse Heist

7. **SalvageJobSystem** (`src/core/systems/SalvageJobSystem.gd`)
   - **DLC**: Fixer's Guidebook
   - **Features**: Tension systems, encounter tables, salvage discovery
   - **Missions**: Derelict Ship Salvage, Ancient Ruins Exploration

---

## Autoload Setup

### Manual Setup (project.godot)

Add these lines to your `project.godot` file under `[autoload]`:

```ini
[autoload]

ExpansionManager="*res://src/core/managers/ExpansionManager.gd"
PsionicSystem="*res://src/core/systems/PsionicSystem.gd"
DifficultyScalingSystem="*res://src/core/systems/DifficultyScalingSystem.gd"
EliteEnemySystem="*res://src/core/systems/EliteEnemySystem.gd"
StealthMissionSystem="*res://src/core/systems/StealthMissionSystem.gd"
SalvageJobSystem="*res://src/core/systems/SalvageJobSystem.gd"
```

### Automatic Setup (using setup script)

Run the autoload setup script:

```gdscript
# In your game initialization code
var autoload_setup = preload("res://src/core/utils/DLCAutoloadSetup.gd").new()
autoload_setup.verify_autoloads()
```

---

## System Usage

### 1. ExpansionManager

**Check DLC Availability:**

```gdscript
# Check if a specific DLC is available
if ExpansionManager.is_expansion_available("trailblazers_toolkit"):
    print("Trailblazer's Toolkit is available!")

# Check multiple DLC
var required_dlc := ["trailblazers_toolkit", "freelancers_handbook"]
if ExpansionManager.are_all_expansions_available(required_dlc):
    print("All required DLC are available!")
```

**Load DLC Content:**

```gdscript
# Load specific DLC data file
var psionic_data = ExpansionManager.load_expansion_data("trailblazers_toolkit", "psionic_powers.json")

# Get all available content of a type (core + owned DLC)
var all_species = ExpansionManager.get_available_content("species")
var all_missions = ExpansionManager.get_available_content("missions")
```

**Filter Content:**

```gdscript
# Filter array to only show owned content
var all_enemies = load_all_enemies() # Returns core + DLC enemies
var available_enemies = ExpansionManager.filter_owned_content(all_enemies)
```

### 2. ContentFilter

**Basic Filtering:**

```gdscript
var filter := ContentFilter.new()

# Filter any content array
var available_species = filter.filter_species(all_species)
var available_equipment = filter.filter_equipment(all_equipment)

# Check individual item
if filter.is_content_available(some_item):
    print("Item is available!")
```

**Get Lock Information:**

```gdscript
# Get user-friendly message about why content is locked
var message = filter.get_locked_content_message(locked_item)
# Returns: "Requires DLC: Trailblazer's Toolkit"

# Get statistics
var stats = filter.get_content_stats(all_species)
print("Available: %d, Locked: %d" % [stats.available, stats.locked])
```

### 3. PsionicSystem

**Activate Psionic Powers:**

```gdscript
# Check if character can use psionics
var powers = PsionicSystem.get_available_powers(character)

# Activate a power
var success = PsionicSystem.activate_power(caster, "Barrier", target)
if success:
    print("Barrier activated!")

# Process active powers each round
PsionicSystem.process_active_powers(character)

# Check for active powers
if PsionicSystem.has_active_power(character, "Shielding"):
    print("Character has psionic shield active!")
```

**Signals:**

```gdscript
# Connect to power activation signal
PsionicSystem.power_activated.connect(_on_power_activated)

func _on_power_activated(character, power_name: String, target, success: bool):
    if success:
        print("%s activated %s on %s!" % [character.name, power_name, target.name])
```

### 4. DifficultyScalingSystem

**Set Difficulty:**

```gdscript
# Use a preset
DifficultyScalingSystem.set_difficulty_preset("challenging")
# Available presets: story_mode, standard, challenging, hardcore, iron_man

# Enable specific modifiers
DifficultyScalingSystem.enable_modifier("Brutal Foes")
DifficultyScalingSystem.enable_modifier("Larger Battles")

# Disable modifiers
DifficultyScalingSystem.disable_modifier("Scarcity")
```

**Apply Difficulty to Battles:**

```gdscript
# Modify enemy stats
var base_enemy = {"toughness": 3, "combat_skill": "+0"}
var modified_enemy = DifficultyScalingSystem.apply_to_enemy(base_enemy)
# With "Brutal Foes": toughness becomes 4

# Modify deployment points
var base_points = 10
var modified_points = DifficultyScalingSystem.modify_deployment_points(base_points)
# With "Larger Battles": points become 13 (10 * 1.25, rounded up)

# Modify rewards
var rewards = DifficultyScalingSystem.modify_rewards(20, 2) # 20 credits, 2 loot rolls
# With "Scarcity": returns {credits: 15, loot_rolls: 2}
```

**Progressive and Adaptive Difficulty:**

```gdscript
# Enable progressive difficulty (gets harder over time)
DifficultyScalingSystem.enable_progressive_difficulty(true)

# Process at each campaign turn
DifficultyScalingSystem.process_progressive_difficulty(current_campaign_turn)

# Enable adaptive difficulty (adjusts based on performance)
DifficultyScalingSystem.enable_adaptive_difficulty(true)

# Update after battles
DifficultyScalingSystem.update_campaign_stats("victory", 0, current_credits)
```

### 5. EliteEnemySystem

**Generate Elite Enemies:**

```gdscript
# Set deployment mode
EliteEnemySystem.set_deployment_mode("mixed_squads")
# Modes: standard_replacement, elite_only_battles, mixed_squads, boss_battles

# Generate enemy with possible elite replacement
var enemy = EliteEnemySystem.generate_enemy("Mercenary")
# May return elite version if conditions met

# Generate mixed squad (1 elite per 3 standard)
var squad = EliteEnemySystem.generate_mixed_squad("Raider", 6)
# Returns 2 elite + 4 standard

# Generate boss enemy
var boss = EliteEnemySystem.generate_boss_enemy("Pirate", 20)
# Returns boosted elite with boss stats
```

**Elite Abilities:**

```gdscript
# Get elite special abilities
var abilities = EliteEnemySystem.get_special_abilities(elite_enemy)

# Trigger ability
EliteEnemySystem.trigger_ability(elite_enemy, "Combat Veteran", context)

# Check for ability
if EliteEnemySystem.has_ability(elite_enemy, "Fearless"):
    # Skip morale check
    pass
```

### 6. StealthMissionSystem

**Start Stealth Mission:**

```gdscript
# Start mission
var mission = StealthMissionSystem.start_stealth_mission("Corporate Infiltration")

# Check alarm level
var alarm = StealthMissionSystem.get_alarm_level()

# Trigger alarm escalation
StealthMissionSystem.trigger_alarm_escalation("Gunfire")

# Check detection
var detected = StealthMissionSystem.check_detection(guard, crew_member)
if detected:
    print("Crew member spotted!")
```

**Mission Objectives:**

```gdscript
# Complete objective
StealthMissionSystem.complete_objective(0) # First objective

# Get mission status
var status = StealthMissionSystem.get_mission_status()
print("Alarm: %d/%d" % [status.alarm_level, status.max_alarm])
print("Objectives: %d/%d" % [status.objectives_completed, status.objectives_total])
```

**Signals:**

```gdscript
# Mission events
StealthMissionSystem.alarm_increased.connect(_on_alarm_increased)
StealthMissionSystem.mission_failed.connect(_on_mission_failed)
StealthMissionSystem.mission_completed.connect(_on_mission_completed)

func _on_alarm_increased(trigger: String, new_level: int):
    print("Alarm raised to %d by: %s" % [new_level, trigger])
```

### 7. SalvageJobSystem

**Start Salvage Mission:**

```gdscript
# Start mission
var mission = SalvageJobSystem.start_salvage_mission("Derelict Ship Salvage")

# Check tension level
var tension = SalvageJobSystem.get_tension_level()

# Search location
var discovery = SalvageJobSystem.search_location("compartment_1")
print("Found: %s" % discovery.find)

# Trigger tension
SalvageJobSystem.trigger_tension_increase("Gunfire or loud noise")
```

**Encounters:**

```gdscript
# Roll on encounter table
var encounter = SalvageJobSystem.roll_encounter("minor")
print("Minor encounter: %s" % encounter)

# Major encounter
var major = SalvageJobSystem.roll_encounter("major")
print("Major encounter: %s" % major)
```

**Mission Status:**

```gdscript
var status = SalvageJobSystem.get_mission_status()
print("Tension: %d/%d" % [status.tension_level, status.max_tension])
print("Searched: %d/%d locations" % [status.locations_searched, status.locations_total])

# Get all salvage
var salvage = SalvageJobSystem.get_discovered_salvage()
var total_value = SalvageJobSystem.get_total_salvage_value()
```

---

## Integration Examples

### Example 1: Character Creation with DLC

```gdscript
func create_character():
    var filter := ContentFilter.new()

    # Get all available species (core + DLC)
    var all_species = load_species_data()
    var available_species = filter.filter_species(all_species)

    # Show species selection
    for species in available_species:
        add_species_option(species)

    # Show locked species with purchase prompt
    for species in all_species:
        if not filter.is_content_available(species):
            var message = filter.get_locked_content_message(species)
            add_locked_species_option(species, message)

    # After species selection, check for psionic ability
    if selected_species.has("psionic_ability"):
        if ExpansionManager.is_expansion_available("trailblazers_toolkit"):
            # Grant psionic powers
            var powers = PsionicSystem.get_all_powers()
            character.known_powers = select_random_powers(powers, 1)
        else:
            # Show DLC upsell
            show_dlc_purchase_prompt("trailblazers_toolkit")
```

### Example 2: Battle Setup with Difficulty and Elite Enemies

```gdscript
func setup_battle():
    # Apply difficulty modifiers
    var base_deployment = 10
    var modified_deployment = DifficultyScalingSystem.modify_deployment_points(base_deployment)

    # Set elite deployment mode
    EliteEnemySystem.set_deployment_mode("mixed_squads")

    # Generate enemies
    var enemies = []
    var enemy_count = calculate_enemy_count(modified_deployment)

    # Generate mixed squad with possible elites
    enemies = EliteEnemySystem.generate_mixed_squad("Mercenary", enemy_count)

    # Apply difficulty to each enemy
    for i in range(enemies.size()):
        enemies[i] = DifficultyScalingSystem.apply_to_enemy(enemies[i])

    return enemies
```

### Example 3: Stealth Mission with Psionic Powers

```gdscript
func run_stealth_mission():
    # Start stealth mission
    var mission = StealthMissionSystem.start_stealth_mission("Corporate Infiltration")

    # During mission, crew member uses psionic stealth power
    if character.has_psionic_ability:
        # Use "Suggestion" power to distract guard
        var success = PsionicSystem.activate_power(character, "Suggestion", guard)
        if success:
            print("Guard distracted by psionic suggestion!")
            # Crew can move past without detection check
        else:
            # Normal detection check
            StealthMissionSystem.check_detection(guard, character)
```

### Example 4: Post-Battle Adaptive Difficulty

```gdscript
func post_battle_sequence(battle_result: String):
    # Count crew deaths
    var deaths = count_crew_deaths()

    # Get current credits
    var credits = campaign.credits

    # Update adaptive difficulty
    DifficultyScalingSystem.update_campaign_stats(battle_result, deaths, credits)

    # Apply injury modifiers
    for injury in crew_injuries:
        var roll = roll_injury_table()
        var modified_roll = DifficultyScalingSystem.modify_injury_roll(roll)
        var injury_result = get_injury_result(modified_roll)
        apply_injury(injured_character, injury_result)

    # Calculate rewards with difficulty modifiers
    var base_credits = 20
    var base_loot = 2
    var modified_rewards = DifficultyScalingSystem.modify_rewards(base_credits, base_loot)

    campaign.credits += modified_rewards.credits
    roll_loot(modified_rewards.loot_rolls)
```

---

## Cross-System Integration

### Psionic Elite Enemies (Trailblazer's Toolkit + Freelancer's Handbook)

```gdscript
func generate_psionic_elite():
    # Check both DLC are available
    var has_tt = ExpansionManager.is_expansion_available("trailblazers_toolkit")
    var has_fh = ExpansionManager.is_expansion_available("freelancers_handbook")

    if has_tt and has_fh:
        # Get Psionic Adept elite enemy
        var psionic_elite = EliteEnemySystem.get_elite_enemy("Psionic Adept")

        # Give it random psionic powers
        var powers = PsionicSystem.get_all_powers()
        psionic_elite.known_powers = select_random_powers(powers, 2)

        return psionic_elite
    elif has_fh:
        # Fallback profile (as specified in elite_enemies.json)
        var elite = EliteEnemySystem.get_elite_enemy("Psionic Adept")
        elite.combat_skill = "+1"
        elite.weapons = ["Hand Cannon"]
        return elite
```

### Stealth Salvage Missions

```gdscript
func create_hybrid_mission():
    # Combine stealth and salvage mechanics
    var mission = {
        "type": "stealth_salvage",
        "name": "Silent Scavenge"
    }

    # Use both systems
    StealthMissionSystem.start_stealth_mission("Warehouse Heist")
    SalvageJobSystem.start_salvage_mission("Ancient Ruins Exploration")

    # Searching increases both tension AND alarm
    func search_quietly(location_id: String):
        var discovery = SalvageJobSystem.search_location(location_id)

        # Searching makes noise
        StealthMissionSystem.apply_noise_penalty("searching")

        return discovery
```

---

## Testing DLC Systems

### Development Mode

In the editor, all DLC is automatically unlocked (controlled by ExpansionManager):

```gdscript
# In ExpansionManager
if OS.has_feature("editor") and ProjectSettings.get_setting("dlc/unlock_all_in_editor", true):
    return true # All DLC available
```

### Testing Specific DLC

To test specific DLC combinations:

```gdscript
# Temporarily override DLC ownership for testing
func test_specific_dlc():
    # Backup current state
    var original_dlc = ExpansionManager.owned_dlc.duplicate()

    # Set test DLC
    ExpansionManager.owned_dlc = ["trailblazers_toolkit"]

    # Run tests
    test_psionic_system()

    # Restore original state
    ExpansionManager.owned_dlc = original_dlc
```

### Unit Testing Systems

```gdscript
# Example test for PsionicSystem
func test_psionic_activation():
    var test_character = {
        "name": "Test Psyker",
        "character_type": "Psyker",
        "savvy": 2,
        "known_powers": ["Barrier"]
    }

    var target = {"name": "Test Target"}

    # Test activation
    var success = PsionicSystem.activate_power(test_character, "Barrier", target)

    assert(success == true or success == false, "Activation should return boolean")

    if success:
        assert(PsionicSystem.has_active_power(test_character, "Barrier"),
               "Barrier should be active after successful activation")
```

---

## Best Practices

1. **Always Check DLC Availability**
   ```gdscript
   if ExpansionManager.is_expansion_available("dlc_id"):
       # Use DLC feature
   else:
       # Show fallback or purchase prompt
   ```

2. **Use ContentFilter for UI**
   ```gdscript
   var filter := ContentFilter.new()
   var stats = filter.get_content_stats(all_content)
   update_ui_with_availability(stats)
   ```

3. **Connect to Signals**
   ```gdscript
   # React to DLC ownership changes
   ExpansionManager.dlc_ownership_changed.connect(_on_dlc_changed)

   func _on_dlc_changed(dlc_id: String, owned: bool):
       if owned:
           reload_content() # Refresh available content
   ```

4. **Cache Filtered Content**
   ```gdscript
   # Don't filter repeatedly - cache results
   var _cached_species: Array = []

   func get_available_species() -> Array:
       if _cached_species.is_empty():
           var filter := ContentFilter.new()
           _cached_species = filter.filter_species(load_all_species())
       return _cached_species
   ```

5. **Handle Missing DLC Gracefully**
   ```gdscript
   # Always have fallback behavior
   if not ExpansionManager.is_expansion_available("required_dlc"):
       show_notification("This feature requires the DLC expansion")
       return
   ```

---

## Troubleshooting

### "ExpansionManager not found"

**Solution**: Ensure ExpansionManager is registered as an autoload in project.godot:

```ini
[autoload]
ExpansionManager="*res://src/core/managers/ExpansionManager.gd"
```

### "DLC content not loading"

**Solution**: Check file paths and JSON structure:

```gdscript
# Debug content loading
var data = ExpansionManager.load_expansion_data("dlc_id", "file.json")
if data == null:
    print("Failed to load DLC data - check file path")
```

### "All content showing as locked"

**Solution**: Verify DLC ownership is set correctly:

```gdscript
# Check ownership
print(ExpansionManager.owned_dlc)

# Check development override
print(OS.has_feature("editor"))
```

---

## Summary

The DLC system provides a complete, modular architecture for managing expansion content:

- **ExpansionManager**: Central hub for DLC management
- **ContentFilter**: Easy filtering and availability checking
- **Specialized Systems**: Each DLC has dedicated system classes
- **Seamless Integration**: Systems work together and with core game
- **Developer-Friendly**: Auto-unlock in editor, comprehensive signals

For more information, see:
- `EXPANSION_ADDON_ARCHITECTURE.md` - Overall architecture
- `EXPANSION_CONTENT_MAPPING.md` - Content breakdown by DLC
- `DLC_SYSTEM_ARCHITECTURE_DIAGRAM.md` - Visual diagrams
