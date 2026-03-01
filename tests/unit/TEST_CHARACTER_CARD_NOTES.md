# CharacterCard Component Test Suite - Testing Notes

**Test File**: `tests/unit/test_character_card.gd`
**Mock Helper**: `tests/unit/helpers/MockCharacterCardScript.gd`
**Component Path**: `src/ui/components/character/CharacterCard.tscn` (to be created by ui-designer)

## Test Suite Overview

**Total Tests**: 13/13 (exactly at runner stability limit)
**Framework**: GDUnit4 v6.0.1
**Test Categories**:
- Instantiation: 3 tests
- Data Binding: 3 tests
- Signal Emission: 4 tests
- Touch Targets: 2 tests
- Performance: 1 test

---

## Running Tests (PowerShell Command)

**CRITICAL**: Never use `--headless` flag (causes signal 11 crash after 8-18 tests)

```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_character_card.gd `
  --quit-after 60
```

**Expected Runtime**: <5 seconds (13 tests with <1ms each + setup/teardown)

---

## Test Breakdown

### Instantiation Tests (3 tests)

#### 1. `test_card_instantiates_with_default_variant()`
- **Purpose**: Verify card defaults to STANDARD variant
- **Success Criteria**: `get_variant()` returns `VARIANT_STANDARD` (1)
- **Failure Cases**: Card starts in COMPACT or EXPANDED instead

#### 2. `test_card_accepts_character_data()`
- **Purpose**: Ensure `set_character()` doesn't crash with valid Character resource
- **Success Criteria**: No crash, `get_character()` returns non-null
- **Failure Cases**: Null pointer exception, character data rejected

#### 3. `test_card_switches_variants_at_runtime()`
- **Purpose**: Validate dynamic variant switching
- **Success Criteria**: Card successfully switches STANDARD → COMPACT → EXPANDED
- **Failure Cases**: Variant doesn't update, layout breaks on switch

---

### Data Binding Tests (3 tests)

#### 4. `test_compact_displays_name_and_class()`
- **Purpose**: COMPACT shows minimal data (name + class only)
- **Success Criteria**: Name label contains "Test Character", Class label contains "MILITARY"
- **Failure Cases**: Labels empty, wrong data displayed, stats shown in compact view

#### 5. `test_standard_displays_stats_summary()`
- **Purpose**: STANDARD shows name + Combat/Reactions/Toughness
- **Success Criteria**: At least one stat label found and populated
- **Failure Cases**: No stats visible, wrong stats displayed

#### 6. `test_expanded_displays_full_stats()`
- **Purpose**: EXPANDED shows all stats + XP progression
- **Success Criteria**: XP bar or experience label visible
- **Failure Cases**: XP missing, full stats not displayed

---

### Signal Tests (4 tests)

#### 7. `test_card_tapped_signal_emits()`
- **Purpose**: Card body click emits `card_tapped` signal
- **Success Criteria**: Signal count ≥1 after simulated click
- **Failure Cases**: Signal not emitted, wrong signal emitted

#### 8. `test_view_details_button_emits_signal()`
- **Purpose**: View Details button emits `view_details_pressed`
- **Success Criteria**: Signal emitted when button pressed
- **Failure Cases**: Button not found, signal not wired, wrong signal

#### 9. `test_edit_button_emits_signal()`
- **Purpose**: Edit button emits `edit_pressed`
- **Success Criteria**: Signal emitted when button pressed
- **Failure Cases**: Button missing, signal not connected

#### 10. `test_remove_button_emits_signal()`
- **Purpose**: Remove button emits `remove_pressed`
- **Success Criteria**: Signal emitted when button pressed
- **Failure Cases**: Dangerous button not implemented properly

---

### Touch Target Tests (2 tests)

#### 11. `test_buttons_meet_minimum_touch_target()`
- **Purpose**: All interactive buttons ≥48dp height (mobile accessibility)
- **Success Criteria**: Every button `custom_minimum_size.y` or `size.y` ≥48
- **Failure Cases**: Any button <48dp (unusable on touchscreens)

#### 12. `test_card_height_matches_variant()`
- **Purpose**: Card size matches variant specifications
- **Success Criteria**:
  - COMPACT: 80px ± 10px
  - STANDARD: 120px ± 10px
  - EXPANDED: 160px ± 10px
- **Failure Cases**: Card size wrong, doesn't resize on variant change

---

### Performance Test (1 test)

#### 13. `test_instantiation_performance()`
- **Purpose**: Ensure card instantiation + population <1ms (60fps target)
- **Success Criteria**: Total time from `new()` to `set_character()` <1000µs
- **Failure Cases**: Performance >1ms (framerate impact), memory leak

**Performance Benchmarks to Watch**:
- Baseline (empty card): <100µs
- With character data: <500µs
- Acceptable limit: <1000µs
- Unacceptable: >2000µs (investigate scene complexity)

---

## Expected Pass/Fail Behavior

### Before CharacterCard.tscn Exists
**Status**: Tests use MockCharacterCardScript.gd
**Expected Results**: All 13 tests PASS (mock provides expected interface)
**Purpose**: Validate test suite correctness before UI implementation

### After CharacterCard.tscn Created
**Status**: Tests load actual component scene
**Expected Results**:
- **First Run**: Some tests may FAIL (UI implementation incomplete)
- **After UI Polish**: All 13 tests PASS
- **Regression Testing**: Monitor for failures after changes

### Common Failure Patterns
1. **Signal Not Found**: UI designer didn't define required signals
2. **Node Not Found**: UI hierarchy doesn't match expected naming
3. **Touch Target Failure**: Buttons too small for mobile
4. **Performance Failure**: Scene too complex (too many nodes)

---

## Mock Helper Script Details

**File**: `tests/unit/helpers/MockCharacterCardScript.gd`
**Purpose**: Provide minimal CharacterCard interface before UI implementation

**Provides**:
- 4 signals: `card_tapped`, `view_details_pressed`, `edit_pressed`, `remove_pressed`
- 3 variants: COMPACT (80px), STANDARD (120px), EXPANDED (160px)
- Character binding: `set_character()`, `get_character()`
- Variant switching: `set_variant()`, `get_variant()`
- Touch-compliant buttons: All ≥48dp height
- Performance: <100µs instantiation

**Limitations**:
- No actual styling (uses default Godot theme)
- Minimal layout (VBoxContainer with labels)
- No animations or transitions
- No visual polish

**Replacement Strategy**:
1. Tests use mock initially (all pass)
2. UI designer creates CharacterCard.tscn
3. Tests auto-detect scene and use real component
4. Fix any failures (missing signals, wrong sizes, etc.)
5. Delete mock once real component passes all tests

---

## Integration with Test Suite

**Current Test Coverage**: 138/138 passing
**New Coverage**: +13 tests for CharacterCard
**Updated Coverage**: 151/151 (target)

**Test File Organization**:
```
tests/
├── unit/
│   ├── test_character_card.gd          ← NEW (13 tests)
│   ├── test_character_advancement_costs.gd (36 tests)
│   ├── test_injury_system.gd (26 tests)
│   ├── test_loot_system.gd (44 tests)
│   └── test_state_save_load.gd (32 tests)
│
└── helpers/
    └── MockCharacterCardScript.gd      ← NEW (temporary mock)
```

---

## Debugging Tips

### Test Fails: "Scene not found"
**Cause**: CharacterCard.tscn doesn't exist yet
**Fix**: Tests automatically use mock - verify mock script loads

### Test Fails: "Signal not connected"
**Cause**: Real component missing signal definition
**Fix**: Add signal to CharacterCard.gd:
```gdscript
signal card_tapped(character: Character)
signal view_details_pressed(character: Character)
signal edit_pressed(character: Character)
signal remove_pressed(character: Character)
```

### Test Fails: "Touch target too small"
**Cause**: Buttons <48dp height
**Fix**: In CharacterCard.tscn, set button `custom_minimum_size.y = 48`

### Test Fails: "Performance >1ms"
**Cause**: Too many child nodes or complex shaders
**Fix**:
- Reduce node count (flatten hierarchy)
- Remove expensive shaders/effects
- Use TextureRect instead of complex controls

### Test Fails: "Node not found by partial name"
**Cause**: UI naming doesn't match test expectations
**Fix**: Rename nodes to include keywords:
- Name labels: Include "Name" in node name
- Class labels: Include "Class" in node name
- Stat labels: Include "Combat", "Reactions", "Toughness", etc.
- Buttons: Include "View", "Edit", "Remove" in names

---

## Quality Gates

**Before Component Approved**:
- ✅ All 13 tests PASS
- ✅ Performance <1ms (measured in test 13)
- ✅ Touch targets ≥48dp (measured in test 11)
- ✅ All 4 signals emit correctly (tests 7-10)
- ✅ All 3 variants display correctly (tests 4-6)
- ✅ No memory leaks (run test suite 100x)

**Regression Prevention**:
- Run test suite after any CharacterCard changes
- Monitor performance test (watch for degradation)
- Check signal tests (breaking changes detection)

---

## Next Steps

1. **UI Designer**: Create `src/ui/components/character/CharacterCard.tscn`
   - Use BaseCampaignPanel design system
   - Implement 3 variants (COMPACT/STANDARD/EXPANDED)
   - Add 4 signals
   - Ensure buttons ≥48dp

2. **Test Validation**: Run test suite
   ```powershell
   # Run CharacterCard tests only
   & 'C:\...\Godot_v4.5.1-stable_win64_console.exe' `
     --path 'c:\...\five-parsecs-campaign-manager' `
     --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
     -a tests/unit/test_character_card.gd `
     --quit-after 60
   ```

3. **Fix Failures**: Address any failing tests
   - Check signal definitions
   - Verify node naming conventions
   - Measure touch targets
   - Profile performance

4. **Integration**: Once all tests pass
   - Delete MockCharacterCardScript.gd
   - Update TESTING_GUIDE.md (+13 tests)
   - Add CharacterCard to component library
   - Create integration tests (CharacterCard in CrewManagementScreen)

---

## Testing Philosophy Alignment

**Framework Bible Compliance**:
- ✅ Max 13 tests per file (runner stability)
- ✅ Plain helper class (no Node inheritance in mock)
- ✅ UI mode only (no headless flag)
- ✅ Self-contained test (no external dependencies)

**Week 3 Methodology**:
- ✅ Test-driven bug discovery (300% productivity boost)
- ✅ Property-based testing (all variants tested)
- ✅ Performance benchmarking (mobile target <1ms)
- ✅ Regression prevention (automated signal/size checks)

**Production Readiness**:
- ✅ Mobile-first (48dp touch targets)
- ✅ Performance-conscious (<1ms instantiation)
- ✅ Accessibility (keyboard navigation via signals)
- ✅ Data integrity (Character resource validation)

---

**Test Suite Created**: 2025-11-27
**Last Updated**: 2025-11-27
**Status**: Ready for UI implementation
