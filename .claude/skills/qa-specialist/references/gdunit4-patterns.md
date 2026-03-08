# gdUnit4 Test Patterns — Five Parsecs Campaign Manager

## Test File Template

```gdscript
extends GdUnitTestSuite

# Preload system under test and helpers
const SystemUnderTest = preload("res://src/path/to/system.gd")
const BattleTestFactory = preload("res://tests/fixtures/BattleTestFactory.gd")
const TestCharacterFactory = preload("res://tests/fixtures/TestCharacterFactory.gd")

# Instance variables
var helper
var test_data: Dictionary

func before() -> void:
    """Suite-level setup — runs ONCE before all tests"""
    var HelperClass = load("res://tests/helpers/SomeHelper.gd")
    helper = HelperClass.new()

func after() -> void:
    """Suite-level cleanup — runs ONCE after all tests"""
    helper = null  # Set to null, do NOT call .free()

func before_test() -> void:
    """Test-level setup — runs before EACH test"""
    test_data = TestCharacterFactory.create_character("Test Char", 2, 1, 3, 1, 1, 4, 4, 0)

func after_test() -> void:
    """Test-level cleanup — runs after EACH test"""
    test_data = {}

func test_descriptive_name() -> void:
    """Docstring explaining what this tests"""
    # Arrange
    var character = BattleTestFactory.create_character("Fighter", 3, 4, 2)
    # Act
    var result = helper.some_method(character)
    # Assert
    assert_that(result).is_not_null()
    assert_int(result.value).is_equal(7)
```

## Assertion Patterns

```gdscript
# Value assertions
assert_that(value).is_not_null()
assert_that(value).is_equal(expected)
assert_int(value).is_equal(expected)
assert_int(value).is_greater(5)
assert_str(value).is_equal("expected")
assert_str(value).contains("substring")
assert_bool(value).is_true()
assert_bool(value).is_false()
assert_float(value).is_equal_approx(1.5, 0.01)

# Collection assertions
assert_array(arr).has_size(5)
assert_array(arr).contains(["item1", "item2"])
assert_array(arr).is_empty()
assert_dict(dict).contains_keys(["key1", "key2"])

# Null/type
assert_that(value).is_null()
assert_that(value).is_instanceof(SomeClass)
```

## Signal Assertions (CRITICAL)

Signal assertions MUST use `await` and argument matchers. This is the #1 source of test failures.

```gdscript
# CORRECT: await + argument matcher
func test_signal_emitted() -> void:
    var monitor = monitor_signals(my_object)
    my_object.do_something()
    await get_tree().process_frame  # Required for deferred signals
    verify(monitor, 1).signal_name(any())

# Common argument matchers
any()         # Match any value
any_string()  # Match any String
any_int()     # Match any int
any_bool()    # Match any bool
any_float()   # Match any float
```

## Test Factories

### BattleTestFactory (tests/fixtures/BattleTestFactory.gd)

```gdscript
# Create a character dict matching Character.gd schema
var char = BattleTestFactory.create_character(
    "Name",       # name: String
    2,            # combat: int (NOT combat_skill)
    3,            # toughness: int
    1             # savvy: int
)
# Returns Dictionary with: character_id, name, character_name (alias),
# combat, toughness, savvy, reactions, tech, move, speed, luck,
# health, max_health, armor, equipment, is_captain, status, experience

# Create a crew
var crew = BattleTestFactory.create_test_crew(4)  # Array[Dictionary]
```

### TestCharacterFactory (tests/fixtures/TestCharacterFactory.gd)

```gdscript
# Full-schema character (production-compliant)
var char = TestCharacterFactory.create_character(
    "Name",       # name
    2,            # combat
    1,            # reactions
    3,            # toughness
    1,            # savvy
    1,            # tech
    4,            # move
    4,            # speed
    0             # luck
)
# Returns Dictionary with ALL Character.gd fields including:
# schema_version, created_at, credits, lifetime stats, etc.
```

## Available Test Helpers (tests/helpers/)

| Helper | Purpose | Key Methods |
|--------|---------|-------------|
| `CharacterAdvancementHelper.gd` | XP costs, stat advancement | `_get_character_advancement_cost(stat)`, `_is_advancement_eligible(char, stat)` |
| `InjurySystemHelper.gd` | Injury determination & recovery | `determine_injury(severity)`, `process_recovery(char)` |
| `LootSystemHelper.gd` | All loot table functions | `roll_battlefield_finds()`, `roll_main_loot_table()` |
| `StateSystemHelper.gd` | Save/load, validation | `validate_campaign_data(data)`, `check_victory_conditions(campaign)` |
| `BattleTestHelper.gd` | Mock mission/crew/enemy | `create_mock_mission()`, `validate_battle_state()` |
| `CampaignTurnTestHelper.gd` | Turn orchestration | `create_campaign_at_phase(phase)`, `validate_phase_transition()` |
| `EconomyTestHelper.gd` | Transactions, market | `create_mock_items()`, `validate_transaction()` |
| `MockDiceSystem.gd` | Deterministic dice | `set_next_roll(value)`, `roll_d6()` |
| `MockCampaignData.gd` | Realistic campaign fixtures | `create_campaign()`, `create_with_crew(count)` |

## File Organization Rules

1. **Max 15 tests per file** — split by concern if more are needed
2. **Naming**: `test_[system]_[aspect].gd` (e.g., `test_character_advancement_costs.gd`)
3. **Arrange/Act/Assert** pattern in every test
4. **Docstrings** on every test function
5. **Reset state** in `before_test()` — never share mutable state between tests
6. **Cleanup**: Set to `null` in `after()`, never call `.free()` (let GC handle)

## Execution Commands

```powershell
# Single test file
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" `
  --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_file_name.gd `
  --quit-after 60

# Headless mode (CI/CD)
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" `
  --headless `
  --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_file_name.gd `
  --ignoreHeadlessMode `
  -c

# Run all tests in a directory
-a tests/unit/

# Run full suite
-a tests/

# Compile check only (no tests)
& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" `
  --headless --quit `
  --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager" 2>&1
```

## Common Gotchas

1. **Stats are FLAT**: Use `combat`, `reactions`, `toughness`, `savvy`, `tech`, `move`, `speed`, `luck` — NOT a `stats` sub-object
2. **Dual key aliases**: Character dicts return both `"id"` AND `"character_id"`, `"name"` AND `"character_name"`
3. **Godot 4.6 type inference**: `var x := arr[i]` fails for untyped arrays. Use `var x: Type = arr[i]`
4. **Signal orphan warnings**: Non-blocking but cluttery. Minimize with cleanup in `after_test()`
5. **Headless mode + InputEvents**: UI interaction tests don't work headless (Godot limitation)
6. **Autoload null-check**: Always `get_node_or_null("/root/AutoloadName")` before use
7. **load() not preload()**: In `before()` use `load()` for runtime scripts, `preload()` for const refs
