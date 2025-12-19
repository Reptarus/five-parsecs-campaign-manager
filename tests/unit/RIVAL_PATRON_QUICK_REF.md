# Rival & Patron Mechanics - Quick Reference

## Test Execution Checklist

### Pre-Run Verification
- [ ] Test file exists: `tests/unit/test_rival_patron_mechanics.gd`
- [ ] Helper exists: `tests/helpers/RivalPatronMechanicsHelper.gd`
- [ ] Run script exists: `tests/unit/run_rival_patron_tests.ps1`
- [ ] Test count: 7 tests (well within 13-test limit)
- [ ] No Node inheritance in helper (plain RefCounted class)

### Run Tests
```powershell
cd tests/unit
.\run_rival_patron_tests.ps1
```

### Expected Results
- **All 7 tests should PASS**
- **0 failures**
- **Exit code 0**

---

## Core Formulas Tested

### 1. Track Task (p.108)
```
1D6 + trackers >= 6 → Success
```
**Tests**: 1 consolidated

### 2. Decoy System (p.82)
```
Modified Roll = 1D6 + decoys
Attack if original_roll <= num_rivals
```
**Tests**: 1 consolidated

### 3. Rival Removal (p.82)
```
Base:       1D6 >= 4     (50%)
Tracked:    1D6+1 >= 4   (67%)
Persistent: 1D6-1 >= 4   (33%)
```
**Tests**: 1 consolidated

### 4. Find Patron (p.50)
```
Roll = 1D6 + existing_patrons + credits_spent
  >= 5 → 1 patron
  >= 6 → 2 patrons
```
**Tests**: 1 consolidated

### 5. Freelancer License (p.51)
```
1D6 >= 5 → License required (33%)
Cost = 1D6 credits
```
**Tests**: 1 consolidated

### 6. Criminal Rival (p.81)
```
2D6:
  Any 1 → Becomes rival (31%)
  Both 1s → Hates crew (3%)
```
**Tests**: 1 consolidated

### 7. Persistent Patron (p.51)
```
"Persistent" → Follows crew
No trait → Dismissed on travel
```
**Tests**: 1 consolidated

---

## Test File Structure

```gdscript
extends GdUnitTestSuite

# Setup
func before()          # Load helper class once
func after()           # Cleanup helper class
func before_test()     # Reset test data per test
func after_test()      # Cleanup test data per test

# Track Task Test (1 consolidated)
func test_track_task_formula()

# Decoy Test (1 consolidated)
func test_decoy_system()

# Rival Removal Test (1 consolidated)
func test_rival_removal_formulas()

# Find Patron Test (1 consolidated)
func test_find_patron_formulas()

# Freelancer License Test (1 consolidated)
func test_freelancer_license()

# Criminal Rival Test (1 consolidated)
func test_criminal_rival_status()

# Persistent Patron Test (1 consolidated)
func test_persistent_patron_travel()
```

---

## Helper Class API

```gdscript
extends RefCounted

# Track Task
_resolve_track_task(die_roll: int, trackers: int) -> Dictionary

# Decoy System
_apply_decoy_modifier(base_roll: int, decoys: int) -> int
_check_rival_attack(die_roll: int, campaign: Dictionary) -> Dictionary

# Rival Removal
_attempt_rival_removal(die_roll: int, is_tracked: bool, is_persistent: bool) -> Dictionary

# Find Patron
_find_patron(die_roll: int, existing_patrons: int, credits_spent: int) -> Dictionary

# Freelancer License
_check_freelancer_license_requirement(die_roll: int) -> Dictionary
_calculate_freelancer_license_cost(die_roll: int) -> int

# Criminal Rival
_check_criminal_rival_status(die1: int, die2: int) -> Dictionary

# Persistent Patron
_apply_planet_travel(patron: Dictionary, new_planet_id: String) -> Dictionary
```

---

## Common Test Patterns

### Success/Failure Tests
```gdscript
var result = helper._resolve_track_task(6, 0)
assert_bool(result.success).is_true()
assert_string(result.description).contains("successfully")
```

### Roll Modifier Tests
```gdscript
var modified_roll = helper._apply_decoy_modifier(4, 2)
assert_int(modified_roll).is_equal(6)  # 4 + 2 decoys
```

### Threshold Tests
```gdscript
var result = helper._find_patron(3, 2, 0)
assert_int(result.patrons_found).is_equal(1)  # 3+2=5, 1 patron
assert_int(result.total_roll).is_equal(5)
```

---

## Troubleshooting

### Test Runner Crashes
**Problem**: Signal 11 crash after 8-18 tests
**Solution**: Always use UI mode (not --headless)
**Current**: Script uses UI mode ✅

### Helper Class Not Found
**Problem**: Cannot load helper class
**Solution**: Check path: `res://tests/helpers/RivalPatronMechanicsHelper.gd`

### Test Count > 13
**Problem**: Runner instability with >13 tests
**Solution**: Split into multiple test files or consolidate tests
**Current**: 7 consolidated tests ✅

---

## Integration Checklist

After tests pass, integrate formulas into:

1. **RivalSystem.gd**
   - [ ] Track task resolution
   - [ ] Rival removal logic
   - [ ] Criminal rival status
   - [ ] Decoy system integration

2. **PatronSystem** (create if needed)
   - [ ] Find patron mechanics
   - [ ] Freelancer license checks
   - [ ] Persistent patron travel

3. **World Phase UI**
   - [ ] Crew task assignments
   - [ ] Patron search interface
   - [ ] Rival tracking interface

---

## Success Criteria

✅ **All 7 tests pass**
✅ **0 failures**
✅ **Exit code 0**
✅ **No signal 11 crashes**
✅ **Test run completes in <60 seconds**

---

## File Locations

```
tests/
├── unit/
│   ├── test_rival_patron_mechanics.gd      # Main test file
│   ├── run_rival_patron_tests.ps1          # Run script
│   ├── RIVAL_PATRON_TEST_SUMMARY.md        # Detailed docs
│   └── RIVAL_PATRON_QUICK_REF.md           # This file
└── helpers/
    └── RivalPatronMechanicsHelper.gd       # Test helper (no Node inheritance)
```

---

## Next Actions

1. **Run tests**: `.\run_rival_patron_tests.ps1`
2. **Verify all pass**: Check for 7/7 PASSED
3. **Integrate formulas**: Apply to RivalSystem.gd
4. **Create PatronSystem**: Use validated formulas
5. **Add UI integration**: World Phase controller
