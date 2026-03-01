# Rival & Patron Mechanics Test Summary

## Overview
Comprehensive test suite for Five Parsecs From Home rival and patron mechanics.

**Test File**: `tests/unit/test_rival_patron_mechanics.gd`
**Helper File**: `tests/helpers/RivalPatronMechanicsHelper.gd`
**Run Script**: `tests/unit/run_rival_patron_tests.ps1`
**Total Tests**: 7 consolidated tests covering 7 game mechanics

---

## Test Coverage

### 1. Track Task Test (1 consolidated test)
**Source**: Five Parsecs From Home p.108

**Formula**: `1D6 + trackers >= 6 = success`

| Test | Description | Validates |
|------|-------------|-----------|
| `test_track_task_formula()` | Complete formula validation | Success: 6+0, 3+3, 1+5 / Failure: 5+0, 3+2 |

**Example**:
- 0 trackers + roll 6 = 6 (SUCCESS)
- 3 trackers + roll 3 = 6 (SUCCESS)
- 2 trackers + roll 3 = 5 (FAILURE)

---

### 2. Decoy Integration Test (1 consolidated test)
**Source**: Five Parsecs From Home p.82

**Mechanics**:
- Each decoy adds +1 to rival attack roll
- Attack triggers if original roll <= number of rivals

| Test | Description | Validates |
|------|-------------|-----------|
| `test_decoy_system()` | Complete decoy mechanics | Modifier calculation + attack resolution |

**Example** (2 rivals, 2 decoys):
- Roll 1 → modified 3 (attack triggers, original 1 <= 2 rivals)
- Roll 2 → modified 4 (attack triggers, original 2 <= 2 rivals)
- Roll 3 → modified 5 (no attack, original 3 > 2 rivals)

---

### 3. Rival Removal Formula Test (1 consolidated test)
**Source**: Five Parsecs From Home p.82

**Formulas**:
- **Base**: 1D6, success on 4+ (50% chance)
- **Tracked**: 1D6+1, success on 4+ (67% chance)
- **Persistent**: 1D6-1, success on 4+ (33% chance)

| Test | Description | Validates |
|------|-------------|-----------|
| `test_rival_removal_formulas()` | All removal formulas | Base, Tracked +1, Persistent -1 |

**Success Probabilities**:
- Base: 3/6 = 50%
- Tracked: 4/6 = 67%
- Persistent: 2/6 = 33%
- Tracked + Persistent: 3/6 = 50% (modifiers cancel)

---

### 4. Find Patron Formula Test (1 consolidated test)
**Source**: Five Parsecs From Home p.50

**Formula**:
- `1D6 + existing_patrons + credits_spent >= 5` → 1 patron
- `1D6 + existing_patrons + credits_spent >= 6` → 2 patrons

| Test | Description | Validates |
|------|-------------|-----------|
| `test_find_patron_formulas()` | Complete patron finding mechanics | Thresholds (5/6) + patron bonus + credit bonus |

**Example**:
- Roll 3 + 2 existing patrons = 5 (1 patron)
- Roll 3 + 0 patrons + 3 credits = 6 (2 patrons)

---

### 5. Freelancer License Test (1 consolidated test)
**Source**: Five Parsecs From Home p.51

**Mechanics**:
- D6 roll of 5-6 = license required (33% chance)
- Cost is 1D6 credits (1-6 range)

| Test | Description | Validates |
|------|-------------|-----------|
| `test_freelancer_license()` | Complete license mechanics | Requirement trigger (>=5) + cost (1-6) |

---

### 6. Criminal 2D6 Rule Test (1 consolidated test)
**Source**: Five Parsecs From Home p.81

**Mechanics**:
- 2D6, 1 on either die = becomes rival
- Both dice show 1 = "hates" modifier (+1 troops always)

| Test | Description | Validates |
|------|-------------|-----------|
| `test_criminal_rival_status()` | Complete criminal rival mechanics | Any 1 = rival, both 1s = hates |

**Probabilities**:
- Becomes rival: 11/36 = 30.6% (any roll with at least one 1)
- Hates crew: 1/36 = 2.8% (double 1s)

---

### 7. Persistent Patron Test (1 consolidated test)
**Source**: Five Parsecs From Home p.51

**Mechanics**:
- Patrons with "Persistent" characteristic follow crew to new planet
- Regular patrons stay behind when traveling

| Test | Description | Validates |
|------|-------------|-----------|
| `test_persistent_patron_travel()` | Complete patron travel mechanics | Persistent follows + non-persistent dismissed |

---

## Running the Tests

### Option 1: PowerShell Script (Recommended)
```powershell
cd tests/unit
.\run_rival_patron_tests.ps1
```

### Option 2: Manual Command
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_rival_patron_mechanics.gd `
  --quit-after 60
```

---

## Test Constraints

⚠️ **CRITICAL**: Use UI mode (NOT headless)
- Headless mode causes signal 11 crash after 8-18 tests
- UI mode is stable and reliable
- Max 13 tests per file for runner stability (this suite has 7 tests)

---

## Expected Output

```
========================================
Running Rival & Patron Mechanics Tests
========================================

Test File: tests/unit/test_rival_patron_mechanics.gd
Godot Version: 4.5.1 (UI mode for stability)

[PASSED] test_track_task_formula
[PASSED] test_decoy_system
[PASSED] test_rival_removal_formulas
[PASSED] test_find_patron_formulas
[PASSED] test_freelancer_license
[PASSED] test_criminal_rival_status
[PASSED] test_persistent_patron_travel

========================================
All 7 rival patron tests PASSED!
========================================
```

---

## Integration with Main Systems

These tests validate the formulas that should be used in:

1. **RivalSystem.gd** (`src/core/rivals/RivalSystem.gd`)
   - Track task resolution
   - Rival removal attempts
   - Criminal rival status checks
   - Decoy system integration

2. **PatronSystem** (when implemented)
   - Find patron mechanics
   - Freelancer license requirements
   - Persistent patron travel rules

3. **World Phase Controller** (`src/ui/screens/world/WorldPhaseController.gd`)
   - Crew task assignments (Track, Decoy)
   - Patron search actions

---

## Quick Reference: Game Formulas

### Track Task
```
1D6 + trackers >= 6 → Success
```

### Rival Attack with Decoys
```
Roll 1D6
Modified roll = roll + decoys
Attack if original_roll <= number_of_rivals
```

### Rival Removal
```
Base: 1D6 >= 4
Tracked: 1D6+1 >= 4
Persistent: 1D6-1 >= 4
```

### Find Patron
```
1D6 + existing_patrons + credits_spent
  >= 5 → 1 patron
  >= 6 → 2 patrons
```

### Freelancer License
```
1D6 >= 5 → License required
Cost = 1D6 credits
```

### Criminal Rival Status
```
2D6
Any 1 → Becomes rival
Both 1s → Hates crew (+1 troops always)
```

### Persistent Patron
```
"Persistent" characteristic → Follows crew to new planet
No characteristic → Dismissed on travel
```

---

## Test Health Status

**Last Run**: Not yet run
**Status**: Ready for execution
**Test Count**: 7/13 (well within 13-test limit)
**Coverage**: 7 core mechanics from Five Parsecs From Home
**Dependencies**: None (uses plain helper class)

---

## Next Steps

1. Run test suite to validate all formulas pass
2. Integrate validated formulas into RivalSystem.gd
3. Implement PatronSystem using validated formulas
4. Add these mechanics to World Phase UI
5. Create integration tests for full workflow

---

## Related Files

- **Test File**: `tests/unit/test_rival_patron_mechanics.gd`
- **Helper**: `tests/helpers/RivalPatronMechanicsHelper.gd`
- **Run Script**: `tests/unit/run_rival_patron_tests.ps1`
- **Rival System**: `src/core/rivals/RivalSystem.gd`
- **Patron Manager UI**: `src/ui/screens/world/PatronRivalManager.gd`
- **Crew Tasks JSON**: `data/campaign_tables/crew_tasks/crew_task_resolution.json`
