# Fixer's Guidebook Integration Guide

## Overview

**Fixer's Guidebook** is the third expansion DLC for Five Parsecs from Home, introducing specialized mission types that add tactical variety and alternative objectives to campaigns:

1. **Stealth Missions** - Infiltration and covert operations with alarm systems
2. **Salvage Jobs** - Exploration and scavenging with tension mechanics
3. **Street Fights** - Urban brawls with civilian presence
4. **Expanded Opportunities** - Additional mission variety and quest types

This guide explains the architecture, integration patterns, and extensibility of these mission systems.

---

## Table of Contents

1. [Expansion Contents](#expansion-contents)
2. [StealthMissionSystem Architecture](#stealthmissionsystem-architecture)
3. [SalvageJobSystem Architecture](#salvagejobsystem-architecture)
4. [Stealth Mission Mechanics](#stealth-mission-mechanics)
5. [Salvage Mission Mechanics](#salvage-mission-mechanics)
6. [Other Mission Types](#other-mission-types)
7. [Integration with Core Systems](#integration-with-core-systems)
8. [Adding New Mission Types](#adding-new-mission-types)
9. [Code Examples](#code-examples)
10. [Troubleshooting](#troubleshooting)

---

## Expansion Contents

### Data Files

Located in `/data/dlc/fixers_guidebook/`:

- **`fixers_guidebook_missions.json`** - All mission types in one file
  - Stealth missions
  - Salvage jobs
  - Street fights
  - Expanded opportunities

### Systems

Located in `/src/core/systems/`:

- **`StealthMissionSystem.gd`** - Stealth mission management (~350 lines)
  - Alarm level tracking
  - Detection mechanics
  - Objective completion
  - Special terrain and rules

- **`SalvageJobSystem.gd`** - Salvage mission management (~370 lines)
  - Tension level tracking
  - Encounter tables
  - Salvage discovery system
  - Location search mechanics

### Mission Types Included

| Type | Count | Key Mechanic | Failure Condition |
|------|-------|--------------|-------------------|
| **Stealth Missions** | 2+ | Alarm System (0-5) | Alarm maxed or all detected |
| **Salvage Jobs** | 2+ | Tension System (0-10) | Tension maxed or crew eliminated |
| **Street Fights** | 3+ | Civilian Presence | Standard combat |
| **Expanded Opportunities** | 5+ | Various | Varies by mission |

### Stealth Missions Included

| Mission | Objective | Alarm Max | Special Features |
|---------|-----------|-----------|------------------|
| **Corporate Infiltration** | Steal data from server room | 5 | Security cameras, patrol routes, locked doors |
| **Warehouse Heist** | Steal cargo containers | 4 | Multiple entry points, guard dogs, cargo weight |

### Salvage Jobs Included

| Mission | Objective | Tension Max | Special Features |
|---------|-----------|-------------|------------------|
| **Derelict Ship** | Search 3+ compartments | 10 | Random encounters, salvage discovery, exposed wiring |
| **Abandoned Colony** | Explore buildings | 10 | Environmental hazards, creature nests, automated defenses |

---

## StealthMissionSystem Architecture

### System Design Philosophy

The `StealthMissionSystem` follows these principles:

1. **Alarm as Central Mechanic** - Escalating alarm drives mission tension
2. **Detection vs Combat** - Encourages stealth over fighting
3. **Objective-Focused** - Win conditions beyond "kill all enemies"
4. **Progressive Consequences** - Alarm effects get worse as level increases
5. **Tactical Decision-Making** - Risk vs reward for every action

### Class Structure

```gdscript
class_name StealthMissionSystem
extends Node

# ============= PUBLIC API =============

# Mission Management
func get_available_missions() -> Array
func get_mission(mission_name: String) -> Dictionary
func start_stealth_mission(mission_name: String) -> Dictionary
func end_mission() -> void
func get_mission_status() -> Dictionary

# Alarm System
func get_alarm_level() -> int
func increase_alarm(trigger: String, amount: int = 1) -> void
func trigger_alarm_escalation(trigger_name: String) -> void

# Detection System
func check_detection(guard, crew_member) -> bool
func check_all_detected(total_crew: int) -> bool
func apply_noise_penalty(action: String) -> int

# Objectives
func complete_objective(objective_index: int) -> void

# Terrain & Rules
func get_special_terrain() -> Array
func get_special_rules() -> Array

# ============= SIGNALS =============

signal alarm_increased(trigger: String, new_level: int)
signal alarm_effect_triggered(level: int, effect: String)
signal detection_check(guard, crew_member, detected: bool)
signal mission_objective_updated(objective: Dictionary, completed: bool)
signal mission_failed(reason: String)
signal mission_completed()
```

### Alarm System Flow

```
Mission Start (Alarm = 0)
    ↓
Crew takes actions
    ↓
Alarm Trigger? (detected, gunfire, etc.)
    ↓ Yes
Increase Alarm (+1 to +3)
    ↓
Check Alarm Effects (level 2, 3, 4, 5)
    ↓ Effect triggered
Apply Effect (patrols, reinforcements, lockdown)
    ↓
Alarm = Max? → Mission Fails
    ↓ No
Continue mission
    ↓
Objective Complete? → Mission Succeeds
    ↓ No
Loop back to crew actions
```

---

## SalvageJobSystem Architecture

### System Design Philosophy

The `SalvageJobSystem` follows these principles:

1. **Tension as Resource** - Actions cost tension, building pressure
2. **Risk-Reward Exploration** - More searching = more loot + more danger
3. **Random Encounters** - Unpredictable threats keep players alert
4. **Discovery-Driven** - Find valuable salvage to offset tension cost
5. **Extraction Planning** - Know when to leave before it's too late

### Class Structure

```gdscript
class_name SalvageJobSystem
extends Node

# ============= PUBLIC API =============

# Mission Management
func get_available_missions() -> Array
func get_mission(mission_name: String) -> Dictionary
func start_salvage_mission(mission_name: String) -> Dictionary
func end_mission() -> void
func get_mission_status() -> Dictionary

# Tension System
func get_tension_level() -> int
func increase_tension(trigger: String, amount: int = 1) -> void
func trigger_tension_increase(trigger_name: String) -> void

# Salvage & Encounters
func roll_salvage_discovery() -> Dictionary
func roll_encounter(encounter_type: String = "minor") -> String
func search_location(location_id: String) -> Dictionary
func get_discovered_salvage() -> Array
func get_total_salvage_value() -> int

# Terrain & Rules
func get_special_terrain() -> Array
func get_special_rules() -> Array

# ============= SIGNALS =============

signal tension_increased(trigger: String, new_level: int)
signal tension_effect_triggered(level: int, effect: String)
signal encounter_rolled(encounter_type: String, encounter: String)
signal salvage_discovered(discovery: Dictionary)
signal mission_objective_updated(objective: Dictionary, completed: bool)
signal mission_failed(reason: String)
signal mission_completed()
```

### Tension System Flow

```
Mission Start (Tension = 0)
    ↓
Crew searches location
    ↓
Increase Tension (+1 per search)
    ↓
Check Tension Effects (level 3, 5, 7, 10)
    ↓ Effect triggered
Roll Encounter OR Environmental Hazard
    ↓
Resolve encounter/hazard
    ↓
Roll Salvage Discovery (1D10 table)
    ↓
Add to discovered salvage
    ↓
Tension = Max? → Mission Fails (must extract)
    ↓ No
Searched enough? → Mission Succeeds
    ↓ No
Continue searching (loop back)
```

---

## Stealth Mission Mechanics

### Alarm System

The alarm system is the core mechanic of stealth missions:

```json
"alarm_system": {
  "initial_level": 0,
  "maximum_level": 5,
  "escalation_triggers": [
    { "trigger": "Crew member spotted by guard", "alarm_increase": 1 },
    { "trigger": "Gunfire", "alarm_increase": 2 },
    { "trigger": "Guard fails to report in", "alarm_increase": 1 },
    { "trigger": "Alarm panel activated", "alarm_increase": 3 }
  ],
  "alarm_effects": [
    { "level": 2, "effect": "Additional patrol deployed" },
    { "level": 3, "effect": "Guards move faster (+2\" movement)" },
    { "level": 4, "effect": "Reinforcements called (add +3 deployment points)" },
    { "level": 5, "effect": "Full lockdown - mission fails if not complete in 3 rounds" }
  ]
}
```

### Alarm Escalation Triggers

| Trigger | Alarm Increase | When It Happens |
|---------|----------------|-----------------|
| **Crew spotted by guard** | +1 | Failed detection check |
| **Gunfire** | +2 | Any weapon fired |
| **Guard fails to report** | +1 | Guard knocked out/killed |
| **Alarm panel activated** | +3 | Guard reaches alarm |
| **Security camera** | +1 | Crew in camera view |

### Alarm Effects by Level

**Level 0-1: No Alert**
- Normal security
- Standard patrol patterns
- Guards not alert

**Level 2: Heightened Alert**
- **Effect**: Additional patrol deployed
- **Impact**: +1D3 guards added to board
- **Tactics**: Patrols overlap, harder to avoid

**Level 3: Active Search**
- **Effect**: Guards move faster (+2" movement)
- **Impact**: Harder to evade, closes gaps faster
- **Tactics**: Need to use cover more aggressively

**Level 4: Reinforcements**
- **Effect**: Reinforcements called (+3 deployment points)
- **Impact**: Significant enemy increase
- **Tactics**: Mission becomes combat-focused

**Level 5: Full Lockdown**
- **Effect**: Mission fails in 3 rounds if not complete
- **Impact**: Absolute time pressure
- **Tactics**: Rush objectives or abort

### Detection Mechanics

Detection uses opposed rolls:

```gdscript
# Detection Check Formula
Guard Roll: 1D6 + Guard Savvy + Cover Modifier
vs
Crew Member Savvy

If Guard Roll > Crew Savvy → DETECTED
```

**Cover Modifiers**:
- **Full Cover**: -999 (effectively invisible, auto-pass)
- **Partial Cover**: -2 to guard roll
- **No Cover**: +0
- **Running**: Additional -1 penalty (noise)
- **Shooting**: Automatic detection (no roll)

**Example Detection Check**:
```
Guard (Savvy +1) spots crew member (Savvy +2) in partial cover:
- Guard rolls: 1D6 = 4, +1 Savvy, -2 cover = 3
- Crew Savvy: 2
- Result: 3 > 2 → DETECTED!
```

### Stealth Objectives

Stealth missions have multi-part objectives:

**Objective Type: Infiltrate**
```json
{
  "type": "infiltrate",
  "target": "Corporate Server Room",
  "success_condition": "Reach server room and spend 1 action downloading data",
  "failure_condition": "Alarm level reaches 5 or all crew detected"
}
```

**Objective Type: Extract**
```json
{
  "type": "extract",
  "target": "Extraction Point",
  "success_condition": "At least one crew member with data reaches extraction",
  "failure_condition": "All crew members eliminated or captured"
}
```

**Objective Type: Acquire**
```json
{
  "type": "acquire",
  "target": "Cargo Containers (1D3 locations)",
  "success_condition": "Secure cargo from at least 2 locations",
  "failure_condition": "Alarm reaches maximum before securing cargo"
}
```

### Special Stealth Terrain

Stealth missions feature unique terrain:

1. **Security Cameras**
   - Crew in camera view: +1 alarm per round
   - Can be disabled (Savvy check, 1 action)
   - 90° cone of vision, 12" range

2. **Locked Doors**
   - Requires Savvy check to bypass (5+)
   - Failed check: +1 alarm
   - Alternative: Find key card

3. **Ventilation Shafts**
   - Provides alternative routes
   - Bypass guards and cameras
   - Requires 2 actions to traverse

4. **Patrol Routes**
   - Guards move predictably
   - Can be memorized and avoided
   - Changes after alarm level 2

---

## Salvage Mission Mechanics

### Tension System

Tension builds as crew explores:

```json
"tension_system": {
  "initial_tension": 0,
  "maximum_tension": 10,
  "tension_triggers": [
    { "trigger": "Spend action searching compartment", "tension_increase": 1 },
    { "trigger": "Gunfire or loud noise", "tension_increase": 2 },
    { "trigger": "Move through damaged section", "tension_increase": 1 },
    { "trigger": "Activate machinery", "tension_increase": "1D3" }
  ],
  "tension_effects": [
    { "level": 3, "effect": "Roll on minor encounter table" },
    { "level": 5, "effect": "Environmental hazard activates" },
    { "level": 7, "effect": "Roll on major encounter table" },
    { "level": 10, "effect": "Hostile force arrives - must extract within 3 rounds" }
  ]
}
```

### Tension Triggers

| Action | Tension Increase | Frequency |
|--------|------------------|-----------|
| **Search compartment** | +1 | Every search |
| **Gunfire/loud noise** | +2 | Each time |
| **Move through damaged area** | +1 | Per movement |
| **Activate machinery** | 1D3 | Unpredictable |
| **Force open door** | +1 | Each door |
| **Use explosives** | +3 | Loud! |

### Tension Effects

**Level 0-2: Quiet**
- No encounters
- Safe exploration
- Standard searching

**Level 3: Signs of Life**
- **Effect**: Roll on minor encounter table
- **Examples**: Scavenger rats, automated sentry, loose debris
- **Impact**: Small threats, manageable

**Level 5: Environmental Hazard**
- **Effect**: Hazard activates
- **Examples**: Hull breach, fire, electrical surge
- **Impact**: Ongoing damage or movement penalty

**Level 7: Major Encounter**
- **Effect**: Roll on major encounter table
- **Examples**: Creature pack, hostile scavengers, malfunctioning combat bot
- **Impact**: Serious combat threat

**Level 10: Evacuation**
- **Effect**: Hostile force arrives, must extract in 3 rounds
- **Impact**: Mission becomes about escape
- **Consequence**: Failure to extract = crew lost

### Salvage Discovery Table

Roll 1D10 when searching:

| Roll | Find | Value |
|------|------|-------|
| 1-3 | **Nothing** | 0 credits |
| 4-5 | **Scrap Metal** | 1D6 credits |
| 6-7 | **Functional Parts** | 2D6 credits |
| 8-9 | **Equipment** | Random weapon or gear |
| 10 | **Rare Find** | 2D6+6 credits OR rare item |

**Discovery Examples**:
```json
[
  { "roll": "1-3", "find": "Nothing of value" },
  { "roll": "4-5", "find": "Scrap metal and components (1D6 credits)" },
  { "roll": "6-7", "find": "Functional ship parts (2D6 credits)" },
  { "roll": "8-9", "find": "Intact equipment (roll on equipment table)" },
  { "roll": "10", "find": "Rare salvage: Ship weapon, advanced tech, or 2D6+6 credits" }
]
```

### Encounter Tables

**Minor Encounters (Tension 3)**:
- Scavenger Rats (small creature swarm, 1 HP each)
- Automated Sentry (low-threat bot, 3 HP)
- Loose Debris (environmental hazard, 1D3 damage if hit)
- Unstable Floor (movement penalty, -2" speed)
- Toxic Gas Leak (atmospheric hazard, Toughness save or 1 damage)

**Major Encounters (Tension 7)**:
- Creature Pack (3D6 Worker Bugs OR 2D3 larger creatures)
- Hostile Scavenger Crew (4-6 armed scavengers)
- Malfunctioning Combat Bot (elite enemy, aggressive AI)
- Automated Defense System (turrets activate, continuous fire)
- Space Pirates (organized enemy force, 6+ enemies)

### Salvage Job Objectives

**Objective: Investigate**
```json
{
  "type": "investigate",
  "target": "Ship Compartments (1D6 locations)",
  "success_condition": "Search at least 3 compartments and extract",
  "failure_condition": "Tension reaches 10 or all crew eliminated"
}
```

**Key Mechanics**:
- Roll 1D6 to determine total compartments
- Must search minimum (usually 3) to succeed
- Can search more for bonus loot (but increases tension)
- Each search: +1 tension + salvage discovery roll

---

## Other Mission Types

### Street Fights

Urban brawls with civilian complications:

**Key Features**:
- **Civilian Presence**: 2D6 civilians on board
- **Collateral Damage**: Hitting civilians = reputation loss
- **Reinforcements**: Enemies may call for backup
- **Escape Routes**: Multiple exit points

**Example: Gang Turf War**
```json
{
  "mission_type": "street_fight",
  "name": "Gang Turf War",
  "objectives": [
    {
      "type": "eliminate",
      "target": "Rival gang members (standard combat)",
      "success_condition": "Defeat majority of enemy gang"
    }
  ],
  "special_rules": [
    "2D6 civilians flee each round (reduce board clutter)",
    "Hitting civilian: -1 reputation, possible Quest complication",
    "Police may arrive after round 5 (1D6, on 5-6)"
  ]
}
```

### Expanded Opportunities

Additional mission variety:

**Quest-Based Missions**:
- **Bounty Hunting**: Track specific target, special capture mechanics
- **Escort**: Protect NPC through dangerous zone
- **Sabotage**: Destroy specific objectives, stealth optional

**Economic Missions**:
- **Trade Run**: Transport goods, risk vs reward
- **Smuggling**: Avoid authorities while moving contraband
- **Information Brokering**: Gather intel, minimal combat

**Exploration Missions**:
- **Xenoarcheology**: Discover ancient sites, artifact collection
- **Survey**: Map unknown territory, encounter diverse threats
- **First Contact**: Meet new species, diplomacy and combat options

---

## Integration with Core Systems

### Mission Selection Integration

```gdscript
# Campaign mission generation with Fixer's Guidebook content

func generate_available_missions() -> Array:
    var missions := []

    # Core missions
    missions.append_array(core_mission_system.get_standard_missions())

    # Add Fixer's Guidebook missions if DLC enabled
    if ExpansionManager.is_expansion_enabled("fixers_guidebook"):
        # Stealth missions (20% chance)
        if randf() < 0.2:
            var stealth = StealthMissionSystem.get_available_missions()
            if stealth.size() > 0:
                missions.append(stealth[randi() % stealth.size()])

        # Salvage jobs (15% chance)
        if randf() < 0.15:
            var salvage = SalvageJobSystem.get_available_missions()
            if salvage.size() > 0:
                missions.append(salvage[randi() % salvage.size()])

        # Street fights (10% chance)
        if randf() < 0.1:
            missions.append(load_street_fight_mission())

    return missions
```

### Combat System Integration

Stealth and salvage missions modify standard combat:

```gdscript
# Stealth mission combat integration

func process_crew_action(crew_member: Dictionary, action: String):
    # Check if action triggers alarm
    match action:
        "shoot":
            if StealthMissionSystem.active_mission:
                StealthMissionSystem.trigger_alarm_escalation("Gunfire")
        "run":
            if StealthMissionSystem.active_mission:
                var noise_penalty = StealthMissionSystem.apply_noise_penalty("running")
                crew_member.detection_modifier += noise_penalty

    # Execute normal combat action
    execute_action(crew_member, action)

# Salvage mission combat integration

func process_salvage_action(crew_member: Dictionary, location: String):
    # Searching increases tension
    if SalvageJobSystem.active_mission:
        var discovery = SalvageJobSystem.search_location(location)

        if not discovery.is_empty():
            crew_member.inventory.append(discovery)
            print("Found: %s" % discovery.find)

        # Check if tension triggered encounter
        var tension = SalvageJobSystem.get_tension_level()
        if tension >= 7:
            # Spawn major encounter
            spawn_encounter("major")
```

### Rewards Integration

Special missions have unique reward structures:

```gdscript
func calculate_mission_rewards(mission: Dictionary) -> Dictionary:
    var rewards = {
        "credits": 0,
        "loot_rolls": 0,
        "xp": 0,
        "story_points": 0
    }

    match mission.mission_type:
        "stealth":
            # Stealth missions: bonus for low alarm
            var alarm = StealthMissionSystem.get_alarm_level()
            rewards.credits = roll_credits(mission.rewards.base_credits)

            if alarm <= 1:
                rewards.story_points += 1
                print("Stealth bonus: +1 Story Point (alarm stayed low)")

        "salvage":
            # Salvage missions: credits from discoveries
            var salvage_value = SalvageJobSystem.get_total_salvage_value()
            rewards.credits += salvage_value
            rewards.loot_rolls = SalvageJobSystem.get_discovered_salvage().size()
            print("Salvage value: %d credits" % salvage_value)

        "street_fight":
            # Standard combat rewards
            rewards.credits = roll_credits(mission.rewards.base_credits)
            rewards.loot_rolls = mission.rewards.bonus_loot_rolls

    return rewards
```

---

## Adding New Mission Types

### Step 1: Design the Mission

**Questions to Answer**:
1. What's the core mechanic? (Alarm, Tension, or new system?)
2. What are the objectives? (Multi-part or single goal?)
3. What's the failure condition? (Time limit, detection, death?)
4. What makes it unique? (Special rules, terrain, rewards?)

**Design Example**: Data Heist Mission

- **Core Mechanic**: ICE System (Intrusion Countermeasures)
- **Objectives**: Hack 3 data terminals, download files, extract
- **Failure Condition**: ICE level 5 or all crew flatlined (hacking damage)
- **Unique Features**: Cyber combat, hacking minigame, trace timer

### Step 2: Choose System Type

**If using existing systems**:

```gdscript
# Use StealthMissionSystem for missions with alarm/detection
# Use SalvageJobSystem for missions with tension/exploration
# Create custom system for entirely new mechanics
```

**Data Heist fits StealthMissionSystem** (alarm = ICE level):
- ICE system works like alarm
- Detection = trace programs
- Objectives = terminal hacking

### Step 3: Add to Data File

Edit `/data/dlc/fixers_guidebook/fixers_guidebook_missions.json`:

```json
{
  "stealth_missions": [
    // ... existing missions ...
    {
      "mission_type": "stealth",
      "name": "Corporate Data Heist",
      "description": "Hack into corporate network and steal classified data before ICE traces your location.",
      "objectives": [
        {
          "type": "hack",
          "target": "Data Terminals (3 locations)",
          "success_condition": "Hack all 3 terminals and download data",
          "failure_condition": "ICE level reaches 5 or crew traced"
        },
        {
          "type": "extract",
          "target": "Extraction Point",
          "success_condition": "Escape with data files",
          "failure_condition": "Crew eliminated"
        }
      ],
      "enemy_types": ["Corporate Security", "ICE Programs", "Sysadmin"],
      "deployment_conditions": {
        "deployment_points_modifier": "Standard",
        "special_terrain": ["Server Racks", "Data Terminals", "Firewalls"],
        "special_rules": [
          "ICE System: Hacking increases ICE level (like alarm)",
          "Trace Programs: Failed hacks trigger trace (detection)",
          "Cyber Combat: Hackers can fight ICE programs virtually"
        ]
      },
      "dlc_required": "fixers_guidebook",
      "source": "fixers_guidebook",
      "rewards": {
        "base_credits": "3D6",
        "bonus_loot_rolls": 2,
        "experience_modifier": 2,
        "story_points": 2
      },
      "stealth_mechanics": {
        "alarm_system": {
          "initial_level": 0,
          "maximum_level": 5,
          "escalation_triggers": [
            { "trigger": "Failed hack attempt", "alarm_increase": 1 },
            { "trigger": "Trace program activated", "alarm_increase": 2 },
            { "trigger": "Firewall breach", "alarm_increase": 1 },
            { "trigger": "Sysadmin alerted", "alarm_increase": 3 }
          ],
          "alarm_effects": [
            { "level": 2, "effect": "ICE programs activate (add 1D3 ICE enemies)" },
            { "level": 3, "effect": "Active trace (crew locations revealed)" },
            { "level": 4, "effect": "Black ICE deployed (lethal programs, 2D6 damage)" },
            { "level": 5, "effect": "System lockdown - terminals freeze, mission fails in 2 rounds" }
          ]
        },
        "detection_rules": {
          "hack_attempts": "Roll Savvy vs ICE rating (5+). Fail = trace",
          "firewall_bonuses": "Secured terminals give -2 to hack rolls",
          "trace_mechanics": "Traced crew can't hack until they move 6\" and break trace"
        }
      }
    }
  ]
}
```

### Step 4: Implement Custom Mechanics (If Needed)

If mission needs mechanics beyond existing systems:

```gdscript
# Add to StealthMissionSystem.gd

## Hack a data terminal
func attempt_terminal_hack(hacker: Dictionary, terminal: Dictionary) -> bool:
    var savvy = hacker.get("savvy", 0)
    var ice_rating = terminal.get("ice_rating", 5)

    # Hacking roll: 1D6 + Savvy vs ICE Rating
    var roll = randi() % 6 + 1
    var total = roll + savvy

    var success = total >= ice_rating

    if not success:
        # Failed hack triggers trace
        trigger_alarm_escalation("Failed hack attempt")
        hacker.is_traced = true
        print("Hack failed - crew member traced!")
    else:
        terminal.hacked = true
        print("Terminal successfully hacked")

    return success

## Break trace (move and reset)
func attempt_break_trace(hacker: Dictionary) -> bool:
    if not hacker.get("is_traced", false):
        return true

    # Requires movement + Savvy check
    var savvy = hacker.get("savvy", 0)
    var roll = randi() % 6 + 1

    if roll + savvy >= 4:
        hacker.is_traced = false
        print("Trace broken!")
        return true

    print("Still traced...")
    return false
```

### Step 5: Test Mission Balance

**Testing Checklist**:
- [ ] Can a standard 3-person crew complete it?
- [ ] Is the failure condition achievable but not trivial?
- [ ] Do rewards match difficulty?
- [ ] Are special mechanics clear and fun?
- [ ] Does it integrate smoothly with core combat?

---

## Code Examples

### Example 1: Running a Stealth Mission

```gdscript
# Complete stealth mission flow

func run_stealth_mission(crew: Array):
    # Start mission
    var mission = StealthMissionSystem.start_stealth_mission("Corporate Infiltration")
    print("Mission: %s" % mission.name)
    print("Objective: %s" % mission.objectives[0].success_condition)
    print("Alarm: %d/%d" % [
        StealthMissionSystem.get_alarm_level(),
        mission.stealth_mechanics.alarm_system.maximum_level
    ])

    # Setup battlefield
    var guards = deploy_enemies(mission.enemy_types)
    var terrain = StealthMissionSystem.get_special_terrain()
    setup_battlefield(terrain)

    var round = 1
    var mission_complete = false

    while not mission_complete:
        print("\n=== Round %d ===" % round)

        # Crew activations
        for crew_member in crew:
            # Try to move stealthily
            move_character(crew_member, "toward_objective")

            # Check if guard can detect
            for guard in guards:
                var detected = StealthMissionSystem.check_detection(guard, crew_member)
                if detected:
                    print("!!! %s detected by guard!" % crew_member.name)
                    # Alarm increases automatically in check_detection

        # Check alarm level
        var alarm = StealthMissionSystem.get_alarm_level()
        print("Current alarm: %d" % alarm)

        if alarm >= mission.stealth_mechanics.alarm_system.maximum_level:
            print("MISSION FAILED - Alarm maxed out!")
            break

        # Check objectives
        if check_objectives_complete(crew, mission):
            print("MISSION COMPLETE!")
            mission_complete = true
            StealthMissionSystem.complete_objective(0)

        round += 1

    # Mission cleanup
    StealthMissionSystem.end_mission()

    # Calculate rewards
    var rewards = calculate_mission_rewards(mission)
    print("\nRewards:")
    print("  Credits: %d" % rewards.credits)
    if alarm <= 1:
        print("  Bonus: +1 Story Point (low alarm)")
```

### Example 2: Running a Salvage Job

```gdscript
# Complete salvage mission flow

func run_salvage_mission(crew: Array):
    # Start mission
    var mission = SalvageJobSystem.start_salvage_mission("Derelict Ship Salvage")
    print("Mission: %s" % mission.name)
    print("Objective: Search %d compartments" % mission.objectives[0].target)
    print("Tension: %d/%d" % [
        SalvageJobSystem.get_tension_level(),
        mission.salvage_mechanics.tension_system.maximum_tension
    ])

    var total_compartments = randi() % 6 + 1  # 1D6
    var compartments_searched = []

    var round = 1
    var mission_complete = false

    while not mission_complete:
        print("\n=== Round %d ===" % round)

        # Crew searches compartments
        for crew_member in crew:
            if compartments_searched.size() < total_compartments:
                var compartment_id = "compartment_%d" % (compartments_searched.size() + 1)

                print("%s searching %s..." % [crew_member.name, compartment_id])

                # Search increases tension and rolls discovery
                var discovery = SalvageJobSystem.search_location(compartment_id)

                if not discovery.is_empty():
                    print("  Found: %s" % discovery.find)

                compartments_searched.append(compartment_id)

        # Check tension level
        var tension = SalvageJobSystem.get_tension_level()
        print("Current tension: %d/%d" % [
            tension,
            mission.salvage_mechanics.tension_system.maximum_tension
        ])

        if tension >= mission.salvage_mechanics.tension_system.maximum_tension:
            print("MISSION FAILED - Tension maxed! Must evacuate!")
            break

        # Check if searched enough
        if compartments_searched.size() >= 3:
            print("MISSION COMPLETE - Searched enough compartments!")
            mission_complete = true

        round += 1

    # Mission cleanup
    SalvageJobSystem.end_mission()

    # Calculate rewards
    var salvage_value = SalvageJobSystem.get_total_salvage_value()
    var discoveries = SalvageJobSystem.get_discovered_salvage()

    print("\nSalvage Collected:")
    for discovery in discoveries:
        print("  - %s" % discovery.find)
    print("Total Value: %d credits" % salvage_value)
```

### Example 3: Detection Check Implementation

```gdscript
# Detailed detection mechanic

func perform_detection_check(guard: Dictionary, crew: Dictionary) -> bool:
    print("\n--- Detection Check ---")

    # Check line of sight
    if not has_line_of_sight(guard, crew):
        print("No LOS - crew safe")
        return false

    # Calculate distance
    var distance = calculate_distance(guard, crew)
    print("Distance: %d\"" % distance)

    # Get crew cover status
    var cover = crew.get("cover_status", "none")
    var cover_modifier = 0

    match cover:
        "full":
            print("Crew in full cover - invisible!")
            return false  # Full cover = auto-safe
        "partial":
            cover_modifier = -2
            print("Partial cover: -2 to detection")
        "none":
            cover_modifier = 0
            print("No cover!")

    # Apply noise penalties
    if crew.get("is_running", false):
        cover_modifier -= 1
        print("Running penalty: -1")

    if crew.get("just_shot", false):
        print("Just fired weapon - AUTOMATIC DETECTION!")
        return true  # Gunfire = auto-detected

    # Roll detection
    var guard_roll = randi() % 6 + 1
    var guard_savvy = guard.get("savvy", 0)
    var crew_savvy = crew.get("savvy", 0)

    var guard_total = guard_roll + guard_savvy + cover_modifier

    print("Guard: %d (roll) + %d (Savvy) + %d (cover) = %d" % [
        guard_roll, guard_savvy, cover_modifier, guard_total
    ])
    print("Crew Savvy: %d" % crew_savvy)

    var detected = guard_total > crew_savvy

    print("Result: %s" % ("DETECTED!" if detected else "Safe"))

    return detected
```

### Example 4: Salvage Discovery System

```gdscript
# Implement salvage discovery with outcomes

func roll_and_process_salvage() -> Dictionary:
    print("\n=== Salvage Discovery ===")

    # Roll 1D10
    var roll = randi() % 10 + 1
    print("Roll: %d" % roll)

    # Determine discovery
    var discovery = {
        "roll": roll,
        "find": "",
        "credits": 0,
        "equipment": null
    }

    match roll:
        1, 2, 3:
            discovery.find = "Nothing of value"
            discovery.credits = 0
            print("Result: Nothing found")

        4, 5:
            var scrap_credits = randi() % 6 + 1  # 1D6
            discovery.find = "Scrap metal"
            discovery.credits = scrap_credits
            print("Result: Scrap metal (%d credits)" % scrap_credits)

        6, 7:
            var parts_credits = (randi() % 6 + 1) + (randi() % 6 + 1)  # 2D6
            discovery.find = "Functional parts"
            discovery.credits = parts_credits
            print("Result: Functional parts (%d credits)" % parts_credits)

        8, 9:
            discovery.find = "Intact equipment"
            discovery.equipment = roll_random_equipment()
            print("Result: Equipment - %s" % discovery.equipment.name)

        10:
            var rare_credits = (randi() % 6 + 1) + (randi() % 6 + 1) + 6  # 2D6+6
            discovery.find = "Rare salvage"
            discovery.credits = rare_credits
            print("Result: RARE FIND! (%d credits)" % rare_credits)

    return discovery

func roll_random_equipment() -> Dictionary:
    var equipment_table = [
        {"name": "Pulse Rifle", "type": "weapon", "value": 15},
        {"name": "Blast Pistol", "type": "weapon", "value": 8},
        {"name": "Combat Armor", "type": "armor", "value": 12},
        {"name": "Med Kit", "type": "consumable", "value": 5},
        {"name": "Scanner", "type": "equipment", "value": 10}
    ]

    return equipment_table[randi() % equipment_table.size()]
```

### Example 5: Alarm Effect Triggering

```gdscript
# Alarm effects with progressive consequences

func process_alarm_level_change(old_level: int, new_level: int):
    print("\n=== Alarm Level Changed: %d → %d ===" % [old_level, new_level])

    # Check each alarm effect threshold
    var effects = [
        {"level": 2, "name": "Additional Patrol"},
        {"level": 3, "name": "Guards Move Faster"},
        {"level": 4, "name": "Reinforcements"},
        {"level": 5, "name": "Full Lockdown"}
    ]

    for effect in effects:
        var effect_level = effect.level

        # Trigger if we crossed this threshold
        if old_level < effect_level and new_level >= effect_level:
            print("!!! ALARM EFFECT TRIGGERED: %s !!!" % effect.name)
            apply_alarm_effect(effect.name, effect_level)

func apply_alarm_effect(effect_name: String, level: int):
    match effect_name:
        "Additional Patrol":
            # Spawn 1D3 additional guards
            var extra_guards = randi() % 3 + 1
            print("Spawning %d additional guards" % extra_guards)
            for i in range(extra_guards):
                spawn_enemy("Guard", "patrol_route")

        "Guards Move Faster":
            # Increase all guard movement by 2"
            for guard in get_all_guards():
                guard.speed += 2
                print("Guard %s speed increased to %d\"" % [guard.name, guard.speed])

        "Reinforcements":
            # Add deployment points
            var reinforcement_points = 3
            print("Adding %d reinforcement deployment points" % reinforcement_points)
            spawn_reinforcements(reinforcement_points)

        "Full Lockdown":
            # Set mission failure timer
            print("=== FULL LOCKDOWN ===")
            print("Mission will FAIL in 3 rounds if not completed!")
            start_lockdown_timer(3)
```

---

## Troubleshooting

### Problem: "Stealth missions too easy - alarm never increases"

**Symptoms**:
- Players complete missions without alarm
- Guards never detect crew
- No tension or challenge

**Solutions**:

1. **Increase guard patrols**:
```gdscript
# Add more guards or tighter patrol routes
var guards_count = base_deployment_points * 1.5  # 50% more guards
```

2. **Add automatic alarm increases**:
```gdscript
# In stealth mission rules:
"special_rules": [
    "Security Sweep: Alarm increases by +1 every 3 rounds automatically",
    "Timed Objective: Must complete in 8 rounds or alarm +2"
]
```

3. **Reduce cover availability**:
```json
"special_terrain": [
  "Limited Cover: Only 1D3+1 cover positions available",
  "Open Spaces: Central area has no cover"
]
```

### Problem: "Salvage missions end too quickly - tension maxes fast"

**Symptoms**:
- Tension hits 10 before enough searching
- Players can't gather enough salvage
- Mission feels rushed

**Solutions**:

1. **Reduce tension gain per search**:
```gdscript
# Modify tension triggers
{"trigger": "Spend action searching compartment", "tension_increase": 1}
// Change to:
{"trigger": "Spend action searching compartment", "tension_increase": "1D3-1"} # 0-2 variable
```

2. **Increase max tension**:
```json
"tension_system": {
  "maximum_tension": 15  // Instead of 10
}
```

3. **Add tension reduction mechanics**:
```gdscript
# Allow crew to reduce tension
func stabilize_environment(character: Dictionary) -> void:
    # Spend 1 action to reduce tension by 1D3
    var reduction = randi() % 3 + 1
    SalvageJobSystem.current_tension_level = max(0, current_tension_level - reduction)
    print("Environment stabilized: -%d tension" % reduction)
```

### Problem: "Alarm/Tension effects not triggering"

**Symptoms**:
- Level increases but no effects occur
- Missing encounter spawns or alarm consequences

**Solutions**:

1. **Verify effect thresholds**:
```gdscript
# Debug alarm effect checks
func _check_alarm_effects(old_level: int, new_level: int):
    print("Checking effects between %d and %d" % [old_level, new_level])

    for effect in alarm_effects:
        var effect_level = effect.level
        print("  Effect at level %d: %s" % [effect_level, effect.effect])

        if old_level < effect_level and new_level >= effect_level:
            print("  → TRIGGERED!")
        else:
            print("  → Not triggered")
```

2. **Ensure process functions are called**:
```gdscript
# Must call check methods after increasing alarm/tension
func increase_alarm(amount: int):
    var old = current_alarm_level
    current_alarm_level += amount

    # IMPORTANT: Call this!
    _check_alarm_effects(old, current_alarm_level)
```

### Problem: "Mission data not loading"

**Symptoms**:
- `get_available_missions()` returns empty array
- System says missions not found

**Solutions**:

1. **Check DLC enabled**:
```gdscript
var enabled = ExpansionManager.is_expansion_enabled("fixers_guidebook")
print("Fixer's Guidebook enabled: %s" % enabled)

if not enabled:
    ExpansionManager.enable_expansion("fixers_guidebook")
```

2. **Verify file path**:
```gdscript
var missions_path = "res://data/dlc/fixers_guidebook/fixers_guidebook_missions.json"
var exists = FileAccess.file_exists(missions_path)
print("Missions file exists: %s" % exists)
```

3. **Check JSON structure**:
```gdscript
# Ensure data is in correct array
var data = load_json(missions_path)
print("Stealth missions: %d" % data.get("stealth_missions", []).size())
print("Salvage jobs: %d" % data.get("salvage_jobs", []).size())
```

---

## Best Practices

### 1. Balance Alarm/Tension Gain

```gdscript
# GOOD - Gradual pressure buildup
"tension_triggers": [
    {"trigger": "Search", "tension_increase": 1},
    {"trigger": "Combat", "tension_increase": 2}
]

# BAD - Too rapid escalation
"tension_triggers": [
    {"trigger": "Any action", "tension_increase": 3}  # Too punishing
]
```

### 2. Provide Counterplay Options

```gdscript
# GOOD - Players can mitigate alarm/tension
func hack_security_camera(character):
    # Disable camera to prevent alarm increase
    camera.disabled = true

func use_stealth_gear(character):
    # Equipment provides detection bonuses
    character.detection_modifier += 2

# BAD - No way to reduce alarm once raised
```

### 3. Signal Important Events

```gdscript
# GOOD - Use signals to communicate to UI/game
StealthMissionSystem.alarm_increased.connect(_on_alarm_raised)
SalvageJobSystem.tension_effect_triggered.connect(_show_tension_effect)

func _on_alarm_raised(trigger: String, level: int):
    show_warning("ALARM RAISED: %s (Level %d)" % [trigger, level])

# BAD - Silent failures or hidden mechanics
```

### 4. Test with Standard Crew

```gdscript
# GOOD - Test with average crew (3 members, standard stats)
var test_crew = [
    {"name": "Fighter", "savvy": 0, "combat": 1, "speed": 4},
    {"name": "Hacker", "savvy": 2, "combat": -1, "speed": 4},
    {"name": "Scout", "savvy": 1, "combat": 0, "speed": 5}
]

# Should be completable but challenging
run_test_mission(test_crew, "Corporate Infiltration")
```

---

## Summary

**Fixer's Guidebook** adds meaningful mission variety through:

1. **Stealth Missions** - Alarm-based tension, detection mechanics, non-combat objectives
2. **Salvage Jobs** - Tension-driven exploration, risk-reward searching, encounter tables
3. **Street Fights** - Civilian complications, urban tactics
4. **Expanded Opportunities** - Quest variety, economic missions, exploration

**Key Integration Points**:
- `StealthMissionSystem.start_stealth_mission()` - Initiate stealth operation
- `StealthMissionSystem.check_detection()` - Guard detection checks
- `SalvageJobSystem.search_location()` - Explore and discover
- `SalvageJobSystem.roll_encounter()` - Generate encounters

**Design Philosophy**:
- Missions that don't require combat
- Tension systems create organic difficulty curves
- Multiple success/failure conditions
- Tactical decision-making at every step

**Next Steps**:
- See [Mission Type Creation Guide](./MISSION_TYPE_CREATION_GUIDE.md) for designing custom missions
- See [StealthMissionSystem Deep Dive](./STEALTH_MISSION_SYSTEM_REFERENCE.md) for complete API
- See [SalvageJobSystem Deep Dive](./SALVAGE_JOB_SYSTEM_REFERENCE.md) for complete API

---

*For information on other expansions, see [Trailblazer's Toolkit Integration](./TRAILBLAZERS_TOOLKIT_INTEGRATION.md) and [Freelancer's Handbook Integration](./FREELANCERS_HANDBOOK_INTEGRATION.md)*
