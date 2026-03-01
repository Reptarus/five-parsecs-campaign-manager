# BattleResolver.gd Implementation Summary

**Status**: ✅ COMPLETE  
**File**: `src/core/battle/BattleResolver.gd`  
**Lines**: 433 lines  
**Created**: 2025-12-16

## Purpose

BattleResolver.gd is a **thin orchestration layer** that calls BattleCalculations methods for real combat resolution. It replaces the FAKE MATH in BattlePhase._simulate_battle_outcome() (lines 651-721) with real combat calculations.

## Architecture

```
BattlePhase.gd
    └─> BattleResolver.resolve_battle()  [THIN ORCHESTRATOR]
            └─> BattleCalculations.resolve_ranged_attack()  [REAL MATH]
            └─> BattleCalculations.calculate_loot_rolls()   [REAL MATH]
            └─> BattleCalculations.check_seize_initiative() [REAL MATH]
```

## Public API (4 static methods)

### 1. `resolve_battle()` - Main Entry Point
```gdscript
static func resolve_battle(
    crew_deployed: Array,
    enemies_deployed: Array,
    battlefield_data: Dictionary,
    deployment_condition: Dictionary,
    dice_roller: Callable
) -> Dictionary
```

**Returns**: Dictionary matching BattlePhase.combat_results format
- `success`: bool (victory/defeat)
- `rounds_fought`: int (3-6 rounds)
- `crew_casualties`: int
- `enemies_defeated`: int
- `held_field`: bool (Core Rules p.119)
- `loot_opportunities`: int (from BattleCalculations)
- `battlefield_finds`: int (0-2 if held field)

### 2. `initialize_battle()` - Setup Battle State
```gdscript
static func initialize_battle(
    crew_deployed: Array,
    enemies_deployed: Array,
    deployment_condition: Dictionary
) -> Dictionary
```

**Returns**: Battle state with:
- `crew_units`: Array (with hp_current, is_stunned, is_alive)
- `enemy_units`: Array
- `crew_casualties`: int (starts at 0)
- `enemy_casualties`: int (starts at 0)
- `condition_effects`: Dictionary (deployment bonuses/penalties)

**Deployment Conditions Supported**:
- `ambush`: crew_first_strike=true, crew_hit_bonus=+2
- `surrounded`: enemy_bonus=+2, crew_hit_penalty=-1
- `defensive`: crew_cover_bonus=+1
- `headlong_assault`: no_cover=true, crew_hit_bonus=+1
- `standard`: no special effects

### 3. `execute_combat_round()` - Run One Round
```gdscript
static func execute_combat_round(
    round_number: int,
    crew_units: Array,
    enemy_units: Array,
    battlefield_data: Dictionary,
    condition_effects: Dictionary,
    dice_roller: Callable
) -> Dictionary
```

**Returns**: Round results
- `crew_casualties`: int (casualties this round)
- `enemy_casualties`: int
- `events`: Array (elimination, stunned, armor_save events)

**Combat Flow**:
1. Check initiative (BattleCalculations.check_seize_initiative)
2. First side attacks (uses BattleCalculations.resolve_ranged_attack)
3. Second side attacks (if any alive)
4. Clear temporary status effects (stun, suppression)

### 4. `calculate_battle_outcome()` - Determine Victory
```gdscript
static func calculate_battle_outcome(
    crew_casualties: int,
    enemy_casualties: int,
    crew_deployed: Array,
    enemies_deployed: Array
) -> Dictionary
```

**Returns**: Outcome analysis
- `success`: bool (victory if enemies eliminated or enemy_loss > crew_loss * 1.5)
- `held_field`: bool (victory OR killed 3+ enemies, Core Rules p.119)
- `margin_of_victory`: int (enemy_casualties - crew_casualties)
- `crew_alive`: int
- `enemies_alive`: int

## Private Helper Functions (6 methods)

1. `_check_initiative()` - Roll 2d6 + highest Savvy >= 10
2. `_count_alive_units()` - Count units with is_alive=true
3. `_find_alive_target()` - Get first alive defender
4. `_estimate_range()` - Simplified range calculation (6" to weapon_range)
5. `_has_cover()` - Check cover (50% random, respects no_cover condition)
6. `_clear_round_status()` - Clear stun/suppression at round end

## Integration with BattleCalculations

### Methods Called from BattleCalculations.gd:

1. **BattleCalculations.resolve_ranged_attack()** (line 283)
   - Full combat resolution with hit/damage/armor saves
   - Returns: {hit, critical, damage, armor_saved, wounds_inflicted, effects}
   - Handles all weapon traits, species abilities, armor mods

2. **BattleCalculations.calculate_loot_rolls()** (line 76)
   - Determines loot opportunities based on victory/enemies_defeated/held_field
   - Returns: int (number of loot rolls)

3. **BattleCalculations.check_seize_initiative()** (line 386)
   - Initiative check: 2d6 + highest Savvy >= 10
   - Returns: {seized, roll_total, die1, die2, savvy_bonus}

## Combat Round Structure (Lines 177-243)

```
execute_combat_round():
    1. Check initiative (crew vs enemy, ambush overrides)
    2. Determine action order (first/second based on initiative)
    3. First side attacks:
        - For each attacker:
            - Find alive target
            - Estimate range, check cover
            - Apply deployment modifiers
            - Call BattleCalculations.resolve_ranged_attack()
            - Apply damage, track casualties
            - Record events (elimination, stunned, armor_save)
    4. Second side attacks (if any alive)
    5. Clear temporary status (stun, suppression)
```

## Victory Calculation Logic (Lines 329-375)

```
calculate_battle_outcome():
    IF enemies_alive == 0:
        success = true, held_field = true  (total victory)
    ELIF crew_alive == 0:
        success = false, held_field = false  (total defeat)
    ELSE:
        crew_loss_percent = crew_casualties / total_crew
        enemy_loss_percent = enemy_casualties / total_enemies
        success = enemy_loss_percent > crew_loss_percent * 1.5
        held_field = success OR enemy_casualties >= 3  (Core Rules p.119)
```

## Integration Points

### Called By:
- `BattlePhase._simulate_battle_outcome()` (line 651)
  - Replace: `var crew_strength = crew_deployed.size() * 5`
  - With: `var result = BattleResolver.resolve_battle(...)`

### Calls Into:
- `BattleCalculations.gd` (95% complete, 79 tests passing)
  - resolve_ranged_attack()
  - calculate_loot_rolls()
  - check_seize_initiative()

## NOT Implemented (Out of Scope)

This is a THIN orchestrator. The following are intentionally NOT in this file:

1. **BattleCalculations internals** - Fixed by Terminal B
   - Weapon trait effects
   - Species combat abilities
   - Armor modifications
   - Utility device effects
   - Detailed damage calculations

2. **Tactical movement/positioning** - Future enhancement
   - Grid-based movement
   - Line of sight calculations
   - Cover system (simplified to 50% random)
   - Precise range tracking (simplified to estimate)

3. **AI decision-making** - Future enhancement
   - Enemy target selection (uses first alive)
   - Tactical positioning
   - Weapon choice

4. **Full brawl combat** - Future enhancement
   - Currently only ranged attacks
   - BattleCalculations.resolve_brawl() exists but not wired

## Testing Strategy

### Unit Tests Needed:
1. `test_resolve_battle_victory()` - All enemies eliminated
2. `test_resolve_battle_defeat()` - All crew eliminated
3. `test_resolve_battle_partial()` - Mixed outcome
4. `test_deployment_conditions()` - Ambush, surrounded, defensive, headlong_assault
5. `test_held_field_threshold()` - 3+ enemies killed holds field
6. `test_loot_calculation()` - Victory + held field = max loot
7. `test_initiative_check()` - Seize initiative mechanics
8. `test_combat_round()` - Single round execution

### Integration Tests Needed:
1. `test_battlephase_integration()` - BattlePhase calls BattleResolver
2. `test_battlecalculations_integration()` - All BattleCalculations methods work

## File Structure

```
BattleResolver.gd (433 lines)
├── Constants (lines 1-17)
│   ├── MAX_COMBAT_ROUNDS = 6
│   ├── MIN_COMBAT_ROUNDS = 3
│   └── HOLD_FIELD_ENEMY_THRESHOLD = 3
├── Public API (lines 18-375)
│   ├── resolve_battle() (lines 30-105)
│   ├── initialize_battle() (lines 111-175)
│   ├── execute_combat_round() (lines 177-243)
│   └── calculate_battle_outcome() (lines 329-375)
└── Private Helpers (lines 377-433)
    ├── _check_initiative()
    ├── _count_alive_units()
    ├── _find_alive_target()
    ├── _estimate_range()
    ├── _has_cover()
    └── _clear_round_status()
```

## Next Steps (Separate Terminal)

1. **Terminal B** - Fix BattleCalculations internals
2. **Terminal C** - Wire BattleResolver into BattlePhase
3. **Terminal D** - Create unit tests for BattleResolver
4. **Terminal E** - Create integration tests

## Success Criteria

✅ File created: 433 lines  
✅ Clean interface: 4 public methods  
✅ BattleCalculations integration: 3 methods called  
✅ Deployment conditions: 4 types supported  
✅ Victory logic: Matches Core Rules p.119  
✅ No BattleCalculations internals duplicated  

## Performance Notes

- All methods are static (no instance overhead)
- Uses existing BattleCalculations (no code duplication)
- Simplified range/cover (performance-friendly)
- Minimal state tracking (battle_state dictionary)
- Early exit on all-eliminated (no wasted rounds)

## Code Quality

- **Static typing**: All parameters and returns typed
- **Documentation**: Every method has docstring
- **Constants**: Named constants for magic numbers
- **Error handling**: Checks for alive units before attacking
- **Modularity**: Private helpers for reusable logic
- **Readability**: Clear variable names, step-by-step comments
