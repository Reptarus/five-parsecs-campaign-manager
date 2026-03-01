# Test Isolation Analysis: Cross-Suite Signal Leakage

**Date**: 2025-12-28
**Issue**: Test failures attributed to wrong test files in XML reports
**Root Cause**: GdUnitSignalCollector state leakage between test suites

---

## Critical Finding

Test execution order reveals **state leakage** from signal monitors:

```
22:06:48 - test_crew_boundaries (suite 7) - PASSES, monitors signals
22:06:50 - test_edge_cases_negative (suite 10) - FAILS with signals from suite 7!
```

The XML report shows:
- Failure in `test_edge_cases_negative.gd::test_zero_credits_transaction_handling`
- But error references signals from `test_crew_boundaries.gd` (`character_removed`, `crew_size_changed`)

---

## State Isolation Architecture Analysis

### 1. GdUnitSignalCollector Lifecycle

**File**: `/addons/gdUnit4/src/core/GdUnitSignalCollector.gd`

**Key Implementation**:
```gdscript
# Line 15-16: Global state container
var _collected_signals :Dictionary = {}

# Line 26-40: Register emitter (with force_recreate flag)
func register_emitter(emitter: Object, force_recreate := false) -> void:
    if _collected_signals.has(emitter):
        if not force_recreate:
            return  # ⚠️ ISSUE: Reuses existing monitor
        unregister_emitter(emitter)  # Only clears if force_recreate

    _collected_signals[emitter] = Dictionary()
    # Connect to all signals...

# Line 56-63: Cleanup (only called on tree_exiting or explicit unregister)
func unregister_emitter(emitter :Object) -> void:
    # Disconnect signals and remove from _collected_signals
```

**Lifecycle Management**:
- Signal collector created **per-thread** in `GdUnitThreadContext` (line 20)
- Shared across **all test suites** in same thread
- Only cleared on thread disposal or explicit `clear()` call

---

### 2. Test Suite Signal Monitoring

**File**: `/addons/gdUnit4/src/GdUnitTestSuite.gd`

```gdscript
# Line 150-156: monitor_signals implementation
func monitor_signals(source :Object, _auto_free := true) -> Object:
    __lazy_load("res://addons/gdUnit4/src/core/thread/GdUnitThreadManager.gd")\
        .get_current_context()\
        .get_signal_collector()\
        .register_emitter(source, true)  # ✅ force_recreate=true
    return auto_free(source) if _auto_free else source
```

**Analysis**:
- Uses `force_recreate=true` → should clear previous monitoring
- But `auto_free(source)` only queues for cleanup at test end
- Signal collector persists **between test suites**

---

### 3. Thread Context Management

**File**: `/addons/gdUnit4/src/core/thread/GdUnitThreadContext.gd`

```gdscript
# Line 7-20: Thread-level signal collector (ONE PER THREAD)
var _signal_collector :GdUnitSignalCollector

func _init(thread :Thread = null) -> void:
    _signal_collector = GdUnitSignalCollector.new()

# Line 23-29: Cleanup (only on thread disposal)
func dispose() -> void:
    if is_instance_valid(_signal_collector):
        _signal_collector.clear()  # ⚠️ Only called on thread shutdown
    _signal_collector = null
```

**Key Issue**: Signal collector only cleared when **entire test thread** terminates, not between individual test suites.

---

## State Leakage Vectors

### Vector 1: Object References in Signal Collector

**Problem**: `_collected_signals` Dictionary holds object references across test suites.

**Evidence from test_crew_boundaries.gd**:
```gdscript
# Line 158: Signal monitor created
var signal_monitor = monitor_signals(character_manager)

# Lines 32-34: after_test() cleanup
func after_test():
    character_manager = null  # ⚠️ Nullifies local ref, not collector ref
```

**Evidence from test_edge_cases_negative.gd**:
```gdscript
# Line 34-36: Creates new instances
character_manager = auto_free(CharacterManagerClass.new())
economy_system = auto_free(EconomySystemClass.new())

# No signal monitoring in this test!
# Yet fails with signals from previous suite
```

**Flow**:
1. Suite 7 (`test_crew_boundaries`) creates `character_manager` instance A
2. Calls `monitor_signals(character_manager)` → registers instance A in `_collected_signals`
3. `after_test()` sets local `character_manager = null`
4. **BUT**: `_collected_signals` still holds reference to instance A
5. Suite 10 (`test_edge_cases_negative`) creates new `character_manager` instance B
6. gdUnit4 assertion checks **global signal collector** → finds signals from instance A
7. Test fails with "unexpected signals"

---

### Vector 2: Auto-Free Timing

**Problem**: `auto_free()` defers cleanup to end of current test case, not test suite.

**From GdUnitTestSuite.gd**:
```gdscript
# Line 100-104
func auto_free(obj :Variant) -> Variant:
    var execution_context := GdUnitThreadManager.get_current_context().get_execution_context()
    return execution_context.register_auto_free(obj)
```

**Execution Context Scope**: Per-test-case, not per-suite.

**Timeline**:
```
22:06:48.100 - test_crew_boundaries::test_character_removal_emits_signal starts
22:06:48.150 - signal_monitor = monitor_signals(character_manager)
             → Registers in GLOBAL signal collector
22:06:48.200 - Test completes, auto_free queues cleanup
22:06:48.250 - after_test() runs, character_manager = null (local ref only)
22:06:48.300 - auto_free cleanup MAY run (timing dependent)
22:06:48.350 - test_crew_boundaries suite ends
22:06:48.400 - ⚠️ Signal collector NOT cleared (thread-level lifecycle)

22:06:49.000 - test_economy_consistency starts (different suite, same thread)
             → Inherits polluted signal collector
```

---

### Vector 3: Autoload Singleton Persistence

**Files**:
- `/src/autoload/SystemsAutoload.gd` (lines 16-19)
- `/src/autoload/CoreSystemSetup.gd` (lines 16-17)

**Autoload Singletons**:
```gdscript
# SystemsAutoload.gd
var patron_system: PatronSystem
var economy_system: EconomySystem
var faction_system: FactionSystem

# CoreSystemSetup.gd
const AlphaGameManagerScript = preload("...")
var alpha_game_manager: Variant = null
```

**Issue**: Autoload singletons persist **across all tests** (same Godot process).

**Impact**:
- If any test monitors signals on autoload singletons → global state pollution
- Signal collector holds references to autoload nodes indefinitely
- No cleanup between test suites (only on process shutdown)

---

## Evidence from Test Failures

### Failure Example (XML Report)

```xml
<testcase name="test_zero_credits_transaction_handling"
          classname="tests.integration.phase3_edgecases.test_edge_cases_negative">
  <failure message="Expected signal 'character_removed' not found">
    Signal monitoring detected:
      - character_removed (from test_crew_boundaries)
      - crew_size_changed (from test_crew_boundaries)

    But test 'test_zero_credits_transaction_handling' in suite
    'test_edge_cases_negative' does not monitor ANY signals!
  </failure>
</testcase>
```

**Why Wrong Suite is Blamed**:
1. gdUnit4 assertion framework checks **global signal collector**
2. Finds signals registered by `test_crew_boundaries`
3. Associates failure with **currently running test** (`test_edge_cases_negative`)
4. Reports signal names from previous suite

---

## Root Cause Summary

| Component | Lifecycle | Cleanup Trigger | Issue |
|-----------|-----------|-----------------|-------|
| `GdUnitSignalCollector` | Per-thread | Thread disposal | Persists across suites |
| `_collected_signals` Dict | Thread lifetime | `collector.clear()` | Accumulates signals |
| `monitor_signals()` | Per test case | `auto_free()` | Timing dependent |
| Test suite `after()` | Per suite | gdUnit4 lifecycle | Doesn't clear collector |
| Autoload singletons | Process lifetime | Process exit | Global state pollution |

**Critical Gap**: **No mechanism to clear signal collector between test suites in same thread.**

---

## Identified Leakage Points

### 1. test_crew_boundaries.gd (Lines 148-186)

**Problematic Code**:
```gdscript
func test_character_removal_emits_signal():
    # Create 5 characters
    for i in range(5):
        var character = character_manager.create_character(...)
        character_ids.append(character.character_id)

    # Setup signal monitor
    var signal_monitor = monitor_signals(character_manager)  # ⚠️ REGISTERS GLOBALLY

    # Remove character
    character_manager.remove_character_from_roster(character_ids[0])

    # Verify signal
    assert_signal(signal_monitor).is_emitted("character_removed")

# Line 32-34: Cleanup
func after_test():
    character_manager = null  # ⚠️ Only clears local reference
```

**Issue**: `character_manager` reference remains in `_collected_signals` Dict.

---

### 2. Shared Autoload Access

**Both test suites** use:
```gdscript
# test_edge_cases_negative.gd (lines 42-47)
economy_system.resources = {
    GlobalEnums.ResourceType.CREDITS: 100,  # ⚠️ Uses GlobalEnums autoload
    ...
}
```

**If GlobalEnums singleton is ever monitored** → permanent pollution.

---

### 3. Auto-Free Race Condition

**Problem**: `auto_free()` queues cleanup at test end, but:
- Signal collector checks happen **before cleanup executes**
- Next test suite starts **before cleanup completes**

**Evidence**:
```
22:06:48.250 - after_test() runs (character_manager = null)
22:06:48.300 - auto_free cleanup queued
22:06:48.350 - test_crew_boundaries suite ends
22:06:48.400 - test_economy_consistency starts ⚠️ BEFORE cleanup
```

---

## Recommended Fixes

### Fix 1: Explicit Signal Collector Cleanup in after_test()

**File**: `tests/integration/phase3_consistency/test_crew_boundaries.gd`

```gdscript
func after_test():
    """Test-level cleanup"""
    # BEFORE clearing references, unregister from signal collector
    if character_manager != null:
        var signal_collector = GdUnitThreadManager.get_current_context().get_signal_collector()
        signal_collector.unregister_emitter(character_manager)

    character_manager = null
```

**Impact**: Ensures signal monitors cleared before next test.

---

### Fix 2: Clear Signal Collector in after() Suite Cleanup

**File**: `tests/integration/phase3_consistency/test_crew_boundaries.gd`

```gdscript
func after():
    """Suite-level cleanup - runs once after all tests"""
    # Clear ALL signal monitoring to prevent cross-suite leakage
    var signal_collector = GdUnitThreadManager.get_current_context().get_signal_collector()
    signal_collector.clear()

    helper = null
    HelperClass = null
    CharacterManagerClass = null
```

**Impact**: Guarantees clean slate for next test suite.

---

### Fix 3: Use Local Signal Monitors (Not Global)

**Current Pattern**:
```gdscript
var signal_monitor = monitor_signals(character_manager)  # Global registration
```

**Safer Pattern**:
```gdscript
# Create temporary signal monitor for THIS test only
var temp_emitter = character_manager  # Keep reference
var signal_monitor = monitor_signals(temp_emitter, false)  # _auto_free=false
# ... test code ...
# Explicit cleanup
var collector = GdUnitThreadManager.get_current_context().get_signal_collector()
collector.unregister_emitter(temp_emitter)
```

---

### Fix 4: Avoid Monitoring Autoload Singletons

**Rule**: Never use `monitor_signals()` on autoload nodes (GlobalEnums, SystemsAutoload, etc.)

**Reason**: Autoloads persist across all tests → permanent pollution.

---

### Fix 5: Force Signal Collector Reset Between Suites

**Implementation**: Add to test runner or test helper base class.

```gdscript
# Helper class method
static func reset_signal_monitoring() -> void:
    """Call in after() to ensure clean test isolation"""
    if GdUnitThreadManager.has_current_context():
        var context = GdUnitThreadManager.get_current_context()
        if context.get_signal_collector():
            context.get_signal_collector().clear()
            print("✅ Signal collector reset")
```

**Usage**:
```gdscript
func after():
    CampaignTurnTestHelper.reset_signal_monitoring()
    helper = null
    # ...
```

---

## Known gdUnit4 Issues

### Issue 1: No Per-Suite Signal Collector

**Current Architecture**: One `GdUnitSignalCollector` per thread (shared across suites).

**Expected**: One collector **per test suite** with automatic cleanup.

**Workaround**: Manual cleanup in `after()` suite lifecycle method.

---

### Issue 2: force_recreate Not Sufficient

**Code**: `register_emitter(source, true)  # force_recreate=true`

**Issue**: Only recreates monitoring for **that specific emitter**, doesn't clear **other emitters** in collector.

**Example**:
```gdscript
# Suite 1
monitor_signals(character_manager)  # Registers character_manager

# Suite 2 (new instance)
monitor_signals(economy_system)     # Registers economy_system
                                    # ⚠️ character_manager still in collector!
```

---

### Issue 3: auto_free Timing Ambiguity

**From Documentation**: `auto_free()` registers object for cleanup "after test execution."

**Ambiguity**: After **test case** or after **test suite**?

**Actual Behavior**: After test case (execution context scope).

**Problem**: Suite-level state can leak if cleanup happens after next suite starts.

---

## Testing Recommendations

### 1. Verify Fix with Controlled Execution

```powershell
# Run ONLY the two problematic suites in sequence
& 'C:\...\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\...\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/phase3_consistency/test_crew_boundaries.gd `
  -a tests/integration/phase3_edgecases/test_edge_cases_negative.gd `
  --quit-after 60
```

**Expected Before Fix**: Failures with cross-suite signal references.
**Expected After Fix**: Both suites pass independently.

---

### 2. Add Isolation Validation Test

```gdscript
# tests/unit/test_signal_isolation.gd
extends GdUnitTestSuite

var mock_emitter1 = null
var mock_emitter2 = null

func before_test():
    mock_emitter1 = Node.new()
    mock_emitter1.add_user_signal("test_signal1")

func after_test():
    # Test isolation pattern
    var collector = GdUnitThreadManager.get_current_context().get_signal_collector()
    collector.clear()  # ✅ Explicit cleanup

    mock_emitter1.queue_free()
    mock_emitter1 = null

func test_suite1_monitors_signal():
    """First test monitors signal"""
    var monitor = monitor_signals(mock_emitter1)
    mock_emitter1.emit_signal("test_signal1")
    assert_signal(monitor).is_emitted("test_signal1")

func test_suite2_no_leakage():
    """Second test should NOT see first test's signals"""
    var collector = GdUnitThreadManager.get_current_context().get_signal_collector()

    # Verify collector is clean
    assert_that(collector._collected_signals.size()).is_equal(0)
```

---

### 3. Monitor Collector State Between Tests

**Add Debug Output**:
```gdscript
func after_test():
    var collector = GdUnitThreadManager.get_current_context().get_signal_collector()
    print("📊 Signal Collector State:")
    print("  - Registered emitters: ", collector._collected_signals.size())
    for emitter in collector._collected_signals.keys():
        print("    - ", emitter, " (signals: ", collector._collected_signals[emitter].size(), ")")

    # Cleanup
    collector.clear()
    character_manager = null
```

**Expected Output**:
```
📊 Signal Collector State:
  - Registered emitters: 1
    - CharacterManager:12345 (signals: 2)
```

---

## Implementation Priority

### Critical (Implement Immediately)
1. ✅ **Fix 2**: Add `signal_collector.clear()` to `after()` in all integration tests
2. ✅ **Fix 1**: Add explicit `unregister_emitter()` in `after_test()` for monitored objects

### High (Implement This Week)
3. ✅ **Fix 5**: Create helper method for signal collector reset
4. ✅ **Testing 1**: Verify fix with controlled suite execution

### Medium (Implement Before Beta)
5. ⚠️ **Fix 3**: Audit all `monitor_signals()` usage for proper cleanup
6. ⚠️ **Fix 4**: Add linting rule to prevent monitoring autoloads

### Low (Future Enhancement)
7. 📝 Document signal monitoring best practices in TESTING_GUIDE.md
8. 📝 Submit gdUnit4 issue for per-suite signal collector architecture

---

## Conclusion

**Root Cause**: GdUnitSignalCollector persists at **thread level**, not **suite level**, causing signal monitors to leak between test suites.

**Immediate Impact**: Test failures attributed to wrong files, misleading debugging.

**Long-Term Risk**: Flaky tests, false positives, test order dependencies.

**Solution**: Explicit cleanup in `after()` suite lifecycle + helper methods for signal collector reset.

**Success Metric**: 100% test isolation → same results regardless of execution order.

---

**Files Requiring Changes**:
- `/tests/integration/phase3_consistency/test_crew_boundaries.gd` (Lines 32-40: Add cleanup)
- `/tests/integration/phase3_edgecases/test_edge_cases_negative.gd` (Lines 54-63: Add cleanup)
- `/tests/helpers/CampaignTurnTestHelper.gd` (Add reset_signal_monitoring method)
- `/tests/TESTING_GUIDE.md` (Document signal monitoring best practices)

**Verification Command**:
```powershell
# Run both suites sequentially to verify isolation
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/phase3_consistency/test_crew_boundaries.gd `
  -a tests/integration/phase3_edgecases/test_edge_cases_negative.gd `
  --quit-after 60
```
