# KeywordTooltip Test Suite - Testing Notes

## Test File
**Location**: `tests/unit/test_keyword_tooltip.gd`
**Framework**: GDUnit4 v6.0.1
**Test Count**: 5 tests (well under 13-test limit)
**Status**: Ready to run

## Test Coverage

### 1. BBCode Formatting Tests (2 tests)
- **test_format_keyword_text_creates_correct_bbcode()**
  - Validates full keyword data formatting with term, definition, extended info, and examples
  - Verifies BBCode structure: `[b]TERM[/b]`, `[i]Example:[/i]`
  - Tests with complete keyword data (all optional fields present)

- **test_format_keyword_text_handles_minimal_data()**
  - Edge case: Keyword with only required fields (term + definition)
  - Verifies optional sections (extended, examples) omitted when not present
  - Prevents empty BBCode tag generation

### 2. Tooltip Display Tests (2 tests)
- **test_show_for_keyword_displays_tooltip_with_keyword_data()**
  - End-to-end tooltip display workflow
  - Verifies KeywordDB integration (get_keyword() call)
  - Validates signal emission (`tooltip_shown`)
  - Checks tooltip visibility and content population

- **test_show_for_keyword_handles_unknown_keyword_gracefully()**
  - Edge case: Non-existent keyword lookup
  - Verifies graceful degradation (no crash, tooltip hidden)
  - Tests empty Dictionary handling from KeywordDB

### 3. Bookmark Functionality Test (1 test)
- **test_bookmark_button_toggles_bookmark_state()**
  - Full bookmark toggle lifecycle (off → on → off)
  - Verifies KeywordDB.toggle_bookmark() integration
  - Validates UI updates (☆ → ★ → ☆)
  - Tests bidirectional state synchronization (logic ↔ UI)

## How to Run Tests

### Via PowerShell (Required - No Headless Mode)
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_keyword_tooltip.gd `
  --quit-after 60
```

### Via Godot Editor (Alternative)
1. Open project in Godot
2. Open GDUnit4 panel (bottom dock)
3. Navigate to `tests/unit/test_keyword_tooltip.gd`
4. Click "Run Tests" button
5. View results in GDUnit4 panel

## Expected Behavior

### All Tests Pass Scenario
```
[PASSED] test_format_keyword_text_creates_correct_bbcode
[PASSED] test_format_keyword_text_handles_minimal_data
[PASSED] test_show_for_keyword_displays_tooltip_with_keyword_data
[PASSED] test_show_for_keyword_handles_unknown_keyword_gracefully
[PASSED] test_bookmark_button_toggles_bookmark_state

Tests: 5/5 passed
```

### Common Failure Scenarios

#### Missing @onready Nodes
**Symptom**: `null instance access` errors on `bookmark_button`, `related_keywords_container`
**Cause**: KeywordTooltip scene (.tscn) not created yet
**Solution**: Tests use defensive null checks (e.g., `if bookmark_button:`)

#### Signal Timeout
**Symptom**: `await_signal_on(tooltip, "tooltip_shown", 500)` times out
**Cause**: Tooltip parent class `show_immediately()` not triggering signal
**Solution**: Increase timeout to 1000ms or verify Tooltip.gd `_show_tooltip()` emits signal

#### KeywordDB State Pollution
**Symptom**: Tests pass individually but fail when run together
**Cause**: KeywordDB autoload state not cleared between tests
**Solution**: `before_test()` clears KeywordDB, `after()` restores original state

## Integration Test Scenarios (Future)

These tests cover **unit-level** functionality. For full integration testing:

### 1. Equipment Panel Integration
```gdscript
# Test: Equipment descriptions show clickable keyword links
var equipment_label = EquipmentPanel.get_node("EquipmentDescription")
equipment_label.text = "[url=keyword:Assault]Assault[/url] weapon"
# Click "Assault" → KeywordTooltip appears
```

### 2. Character Details Integration
```gdscript
# Test: Character traits display with keyword tooltips
var traits_label = CharacterDetailsScreen.get_node("TraitsLabel")
traits_label.text = "Traits: [url=keyword:Bulky]Bulky[/url], [url=keyword:Armor]Armor[/url]"
# Hover over "Bulky" → KeywordTooltip shows definition
```

### 3. Rules Reference Integration
```gdscript
# Test: "See full rules" button navigates to RulesReference screen
tooltip.show_for_keyword("assault", target)
tooltip._on_see_rules_pressed()
# Verify: RulesReference screen opens to page 42
```

## Test Architecture Notes

### Autoload Handling Strategy
**Approach**: Direct KeywordDB autoload usage (no mocking)
**Rationale**:
- KeywordDB is lightweight (Dictionary + Array)
- State easily cleared/restored
- Mocking adds complexity without benefit
- Real autoload tests actual integration

**Backup/Restore Pattern**:
```gdscript
# before() - Save original state
original_keywords = KeywordDB.keywords.duplicate(true)

# after() - Restore original state
KeywordDB.keywords = original_keywords
```

### Scene Tree Requirements
**Critical**: KeywordTooltip must be added to scene tree
**Reason**: `@onready` nodes require `_ready()` to execute
**Pattern**: `add_child(tooltip)` in `before_test()`

### auto_free() Usage
**Pattern**: All test-created nodes use `auto_free()`
**Benefit**: Automatic cleanup prevents memory leaks
**Example**: `tooltip = auto_free(TooltipClass.new())`

## Dependencies

### Required Files
- `src/ui/components/qol/KeywordTooltip.gd` - System under test
- `src/ui/components/common/Tooltip.gd` - Parent class
- `src/qol/KeywordDB.gd` - Autoload singleton
- `tests/helpers/MockKeywordDB.gd` - Mock helper (not used, kept for reference)

### Optional Files
- `KeywordTooltip.tscn` - Scene file (tests work without it via null checks)

## Performance Expectations

- **Test Execution Time**: ~2-3 seconds (all 5 tests)
- **Signal Timeout**: 500ms per signal wait
- **Test Isolation**: Zero state pollution between tests
- **Memory Cleanup**: auto_free() prevents leaks

## Known Limitations

1. **Scene File Not Required**: Tests work without .tscn by using null checks for @onready nodes
2. **Related Keywords**: `_update_related_keywords()` test omitted (requires Button creation, adds complexity)
3. **Static Helper**: `attach_to_rich_text_label()` not tested (integration test scope)

## Success Criteria

✅ All 5 tests pass
✅ No memory leaks (auto_free() cleanup)
✅ No KeywordDB state pollution
✅ Tests run in <5 seconds
✅ Zero false positives/negatives
✅ Handles edge cases (empty data, unknown keywords)

## Next Steps (Integration Phase)

1. Create EquipmentPanel integration test with keyword links
2. Test CharacterDetailsScreen trait keyword tooltips
3. Implement RulesReference navigation test
4. Add performance benchmark (tooltip show latency <100ms)
