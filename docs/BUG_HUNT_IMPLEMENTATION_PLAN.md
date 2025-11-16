# Bug Hunt DLC Implementation Plan

## Overview

Bug Hunt is a standalone campaign mode DLC ($9.99) that provides a military-themed bug hunting experience. The key design principle is **90% code reuse from core Five Parsecs mechanics** with bug-themed overlays and military-specific additions.

## Code Reuse Strategy

### What We Reuse from Core (~90%)

1. **Campaign Structure** - Four-phase turn system (with renamed phases)
2. **Character Stats** - Exact same: Reactions, Speed, Combat Skill, Toughness, Savvy
3. **Combat System** - All combat calculations, dice rolling, damage
4. **Equipment System** - Equipment slots, gear management
5. **XP & Leveling** - Character progression system
6. **Injury System** - Casualty processing and recovery
7. **Battle Setup** - Deployment, terrain, objectives
8. **AI System** - Enemy behavior patterns (modified for bugs)

### What We Add/Override (~10%)

1. **Panic System** - Morale checks and panic effects
2. **Motion Tracker** - Bug detection mechanics
3. **Infestation System** - Colony corruption levels
4. **Military Hierarchy** - Rank-based bonuses
5. **Requisition Points** - Replaces credits system
6. **Bug Enemies** - New enemy types with bug behaviors
7. **Military Equipment** - Specialized military gear
8. **Extraction Objectives** - Time-limited evac missions

## File Organization

All Bug Hunt content is bundled in `/data/dlc/bug_hunt/`:

```
data/dlc/bug_hunt/
├── bug_enemies.json              ✅ Created
├── military_equipment.json       ✅ Created
├── bug_hunt_missions.json        ⏳ TODO
├── panic_tables.json              ⏳ TODO
├── infestation_mechanics.json     ⏳ TODO
├── colony_terrain.json            ⏳ TODO
└── character_transfer_rules.json  ⏳ TODO
```

## System Architecture

### Core System (Reused)

```
CampaignManager (Core)
├── Turn Structure
├── Character System
├── Combat System
├── Equipment System
└── XP/Leveling
```

### Bug Hunt Extension

```
BugHuntCampaignSystem ✅ Created (~90% core code reuse)
├── REUSES: Campaign data structure
├── REUSES: Character creation (soldiers are characters)
├── REUSES: Battle setup (bugs are enemies)
├── REUSES: XP/leveling system
├── REUSES: Equipment system
├── REUSES: Injury/casualty processing
│
├── ADDS: PanicSystem ⏳ TODO
├── ADDS: MotionTrackerSystem ⏳ TODO
├── ADDS: InfestationSystem ⏳ TODO
├── ADDS: MilitaryHierarchySystem ⏳ TODO
└── ADDS: CharacterTransferSystem ⏳ TODO
```

## Campaign Phase Mapping

| Core Phase | Bug Hunt Phase | Reuse % | Notes |
|------------|---------------|---------|-------|
| Travel | Deployment | 60% | Mission selection, loadout (reuse structure) |
| World | Base | 80% | Upkeep, training, equipment (core systems) |
| Battle | Tactical | 95% | Combat is nearly identical |
| Post-Battle | Post-Action | 90% | XP, injuries, rewards (core systems) |

## Data Files Completed

### ✅ bug_enemies.json (100%)

8 bug enemy types with full stats:
- Worker Bug, Soldier Bug, Hunter Bug, Spitter Bug
- Heavy Bug, Flying Bug, Bug Queen, Infested Human
- All use same stat structure as core enemies
- Special abilities defined
- AI behavior patterns specified
- Deployment point costs

### ✅ military_equipment.json (100%)

Military weapons and equipment:
- **Weapons**: Pulse Rifle, Smart Gun, Flamethrower, Combat Shotgun, Sniper Rifle
- **Equipment**: Motion Tracker, Sentry Gun, Combat Armor, Med Kit, Breach Charges, Combat Shield, Tactical Scanner, Grenade Launcher
- **Loadouts**: 5 specialist loadouts defined
- All use core equipment structure

### ✅ BugHuntCampaignSystem.gd (100%)

Main campaign system (~600 lines):
- **Reuses** core campaign data structure
- **Reuses** core character stats (soldier = character)
- **Reuses** core combat system (~95%)
- **Reuses** core XP/leveling system
- **Reuses** core injury/recovery system
- **Adds** Bug Hunt-specific phases
- **Adds** Morale and Infestation tracking
- **Adds** Requisition Points system
- **Integrates** with Bug Hunt subsystems

## Systems TODO

### ⏳ PanicSystem.gd

```gdscript
## Manages panic and morale checks
- Panic triggers (bugs appear, casualties, etc.)
- Panic effects (frozen, flee, fire wildly)
- Squad morale tracking
- Leadership bonuses
```

### ⏳ MotionTrackerSystem.gd

```gdscript
## Motion tracker detection mechanics
- Blip tracking (unknown contacts)
- Range-based detection
- Battery drain mechanics
- Audio cues (beeping)
```

### ⏳ InfestationSystem.gd

```gdscript
## Colony corruption mechanics
- Infestation levels (1-5)
- Environmental hazards
- Hive expansion
- Cleansing objectives
```

### ⏳ MilitaryHierarchySystem.gd

```gdscript
## Rank system and command bonuses
- Rank progression (Private → Captain)
- Leadership abilities
- Command radius bonuses
- Tactical abilities per rank
```

### ⏳ CharacterTransferSystem.gd

```gdscript
## Transfer characters between Five Parsecs ↔ Bug Hunt
- Skill conversion (spacer ↔ soldier)
- Equipment conversion (credits for gear)
- Background assignment (Veteran Spacer / Military Veteran)
- Level/XP retention
```

## Data Files TODO

### ⏳ bug_hunt_missions.json

Mission templates:
- Extraction missions
- Hive cleansing
- Rescue operations
- Defense scenarios
- Recon missions

### ⏳ panic_tables.json

```json
{
  "panic_triggers": [...],
  "panic_effects": [...],
  "morale_modifiers": [...]
}
```

### ⏳ infestation_mechanics.json

```json
{
  "infestation_levels": [...],
  "environmental_hazards": [...],
  "hive_expansion_rules": [...]
}
```

### ⏳ colony_terrain.json

```json
{
  "colony_locations": [...],
  "terrain_features": [...],
  "environmental_hazards": [...]
}
```

### ⏳ character_transfer_rules.json

```json
{
  "skill_conversion_table": {...},
  "equipment_conversion": {...},
  "background_assignment": {...}
}
```

## Integration Points

### With Core Systems

```gdscript
# BugHuntCampaignSystem uses core references:
var core_campaign: Node = get_node("/root/CampaignManager")

# Reuse core character creation:
func _create_soldier() -> Dictionary:
    # Uses exact same stat structure as core characters
    return core_character_template

# Reuse core combat:
func _setup_bug_hunt_battle() -> Dictionary:
    # Uses core battle structure
    # Bugs use same enemy format
    return core_battle_template
```

### With ExpansionManager

```gdscript
# Load Bug Hunt content:
var bugs = ExpansionManager.load_expansion_data("bug_hunt", "bug_enemies.json")
var equipment = ExpansionManager.load_expansion_data("bug_hunt", "military_equipment.json")

# Check DLC ownership:
if ExpansionManager.is_expansion_available("bug_hunt"):
    show_bug_hunt_mode()
```

## UI Requirements

### Main Menu

```
[Five Parsecs Campaign] (Core)
[Bug Hunt Campaign]     (Bug Hunt DLC - gated)
[Load Campaign]         (Both modes)
[Options]
```

### Bug Hunt-Specific UI

1. **Squad Roster Screen** - Shows soldiers, ranks, stats
2. **Equipment Requisition** - Spend RP to buy gear
3. **Mission Briefing** - Intel, objectives, extraction
4. **Motion Tracker HUD** - Blip display during battle
5. **Panic Indicators** - Morale bars, panic status
6. **After-Action Report** - Mission results, casualties
7. **Character Transfer** - Import/Export to Five Parsecs

## Testing Strategy

### Core System Compatibility Tests

```gdscript
# Verify soldier stats work with core combat
func test_soldier_combat_compatibility():
    var soldier = BugHuntCampaignSystem.create_soldier()
    # Should work with core combat functions
    assert(core_combat.calculate_to_hit(soldier, enemy))
    assert(core_combat.apply_damage(soldier, 2))

# Verify bug enemies work with core AI
func test_bug_enemy_compatibility():
    var bug = load_bug_enemy("Worker Bug")
    # Should work with core enemy AI
    assert(core_ai.determine_movement(bug))
    assert(core_ai.select_target(bug, soldiers))
```

### Bug Hunt-Specific Tests

```gdscript
# Test panic system
func test_panic_triggers():
    PanicSystem.set_squad_morale(50)
    PanicSystem.check_panic(soldier, "bug_appeared")
    assert(soldier.has_panic_effect())

# Test motion tracker
func test_motion_tracker():
    MotionTrackerSystem.scan(12) # 12" range
    var blips = MotionTrackerSystem.get_blips()
    assert(blips.size() > 0)
```

## Implementation Priority

### Phase 1: Core Systems (Week 1)
- ✅ Directory structure
- ✅ Bug enemies data
- ✅ Military equipment data
- ✅ BugHuntCampaignSystem (main system)

### Phase 2: Subsystems (Week 2)
- ⏳ PanicSystem
- ⏳ MotionTrackerSystem
- ⏳ InfestationSystem
- ⏳ MilitaryHierarchySystem

### Phase 3: Content & Transfer (Week 3)
- ⏳ Bug Hunt missions data
- ⏳ CharacterTransferSystem
- ⏳ Remaining data files

### Phase 4: UI & Polish (Week 4)
- ⏳ Bug Hunt UI screens
- ⏳ Integration testing
- ⏳ Balance adjustments
- ⏳ Documentation

## Key Design Principles

1. **Maximum Code Reuse** - Leverage 90% of core Five Parsecs code
2. **Data-Driven** - All content in JSON files by DLC
3. **Modular Systems** - Bug Hunt systems are optional additions
4. **Compatible Stats** - Soldiers use exact same stats as core characters
5. **Familiar Structure** - Campaign phases mirror core Four Phases
6. **Clean Separation** - All Bug Hunt content in `/data/dlc/bug_hunt/`

## Success Criteria

- [ ] Bug Hunt campaign can be started and completed
- [ ] All core combat systems work with bugs/soldiers
- [ ] Panic, Motion Tracker, and Infestation systems functional
- [ ] Character transfer works both directions
- [ ] No core game code modified (only extended)
- [ ] All content properly gated by DLC ownership
- [ ] UI shows Bug Hunt option when DLC owned

## Next Steps

1. Create remaining Bug Hunt subsystems (Panic, MotionTracker, etc.)
2. Create mission data files
3. Implement CharacterTransferSystem
4. Update ExpansionManager to load from /data/dlc/ directories
5. Create Bug Hunt UI screens
6. Integration testing with core systems
7. Documentation and examples
