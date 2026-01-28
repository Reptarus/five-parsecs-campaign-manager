# Signal Timeout Debugging Plan

**Target**: `test_crew_boundaries.gd` lines 164 and 185
**Issue**: `character_removed` and `crew_size_changed` signals timeout
**Status**: ✅ **RESOLVED** (2025-12-28)

---

## ✅ RESOLUTION (Added 2025-12-28)

### Root Cause Found: Missing Signal Argument Matchers

The timeouts were caused by gdUnit4's **strict equality matching** on signal arguments:
- `is_emitted("character_removed")` looks for signals with **NO arguments**
- Actual signal: `character_removed.emit(character_id)` has **one String argument**
- `[] != ["char_123"]` → NO MATCH → 2-second timeout

### The Fix Applied

```gdscript
# Line 165 - BEFORE (timeout)
assert_signal(signal_monitor).is_emitted("character_removed")

# Line 165 - AFTER (works)
await assert_signal(signal_monitor).is_emitted("character_removed", [any_string()])

# Line 187 - BEFORE (timeout)
assert_signal(signal_monitor).is_emitted("crew_size_changed")

# Line 187 - AFTER (works)
await assert_signal(signal_monitor).is_emitted("crew_size_changed", [any_int()])
```

### Results
- **Before**: 5 tests failing with timeouts
- **After**: 868 tests passing, 0 failures

### Documentation Updated
- `tests/INTEGRATION_TEST_FIX_PATTERNS.md` - Pattern 9 added
- `tests/TESTING_GUIDE.md` - Signal best practices added
- `docs/SIGNAL_MONITOR_LEAKAGE_ANALYSIS.md` - Resolution summary added

---

## Original Debug Plan (Kept for Reference)

---

## Debugging Hypotheses (Ordered by Likelihood)

### Hypothesis 1: Character Not Found in Roster (MOST LIKELY)
**Theory**: `character.character_id` doesn't match any roster entry

**Why This Could Happen**:
```gdscript
# In test (line 154):
var character = character_manager.create_character(character_data)
character_ids.append(character.character_id)

# In remove (line 89):
for i: int in range(crew_roster.size()):
	if crew_roster[i].character_id == character_id:  # ← Never matches?
		# ... emit signals ...
```

**Possible Causes**:
1. `create_character()` doesn't add character to `crew_roster`
2. `character.character_id` is null/empty
3. ID generation creates duplicates
4. Roster cleared after creation but before removal

**Debug Steps**:
```gdscript
func test_character_removal_emits_signal():
	var character_ids = []
	for i in range(5):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		print("[DEBUG] Created character: ", character.character_id)
		character_ids.append(character.character_id)

	print("[DEBUG] Crew roster size: ", character_manager.get_crew_size())
	print("[DEBUG] Crew roster IDs: ")
	for char in character_manager.crew_roster:
		print("  - ", char.character_id)

	print("[DEBUG] Target removal ID: ", character_ids[0])
	var found = character_manager.get_character_by_id(character_ids[0])
	print("[DEBUG] Character found in roster: ", found != null)

	var signal_monitor = monitor_signals(character_manager)
	var result = character_manager.remove_character_from_roster(character_ids[0])

	print("[DEBUG] Removal result: ", result)
	assert_that(result).is_true()  # ← Will fail if character not found

	assert_signal(signal_monitor).is_emitted("character_removed")
```

---

### Hypothesis 2: Signal Emitted Before Monitor Attached (TIMING)
**Theory**: `create_character()` emits signals, exhausting gdUnit4's signal buffer

**Why This Could Happen**:
```gdscript
# CharacterManager.gd (line 58):
func create_character(character_data: Dictionary) -> Character:
	# ... create character ...
	if added:
		character_created.emit(character)  # ← Emitted BEFORE monitor setup
```

**Evidence**:
- Test creates 5 characters (lines 151-155)
- Monitor attached at line 158 (AFTER character creation)
- Each creation emits `character_created` signal
- gdUnit4 may be confused by pre-monitor signals

**Debug Steps**:
```gdscript
func test_character_removal_emits_signal():
	# Attach monitor BEFORE character creation
	var signal_monitor = monitor_signals(character_manager)

	var character_ids = []
	for i in range(5):
		var character_data = {"name": "Crew %d" % i, "class": 0}
		var character = character_manager.create_character(character_data)
		character_ids.append(character.character_id)

	# Verify character_created was emitted 5 times
	assert_signal(signal_monitor).is_emitted("character_created", [], 5)

	# Remove one character
	character_manager.remove_character_from_roster(character_ids[0])

	# Now check removal signal
	assert_signal(signal_monitor).is_emitted("character_removed")
```

---

### Hypothesis 3: Signal Connections Not Established (INITIALIZATION)
**Theory**: CharacterManager signals not properly declared or connected

**Why This Could Happen**:
- `CharacterManager` created outside scene tree (no `_ready()` called)
- Test calls `_initialize_manager()` manually, which doesn't connect signals
- gdUnit4 signal monitor can't find signal definitions

**Evidence**:
```gdscript
# CharacterManager.gd:
signal character_removed(character_id: String)  # ← Declared at class level
signal crew_size_changed(new_size: int)

# Test:
character_manager = auto_free(CharacterManagerClass.new())  # ← No scene tree
character_manager._initialize_manager()  # ← Doesn't set up signals
```

**Debug Steps**:
```gdscript
func test_character_removal_emits_signal():
	# Verify signals exist
	var signal_list = character_manager.get_signal_list()
	print("[DEBUG] CharacterManager signals:")
	for sig in signal_list:
		print("  - ", sig["name"])

	assert_that(character_manager.has_signal("character_removed")).is_true()
	assert_that(character_manager.has_signal("crew_size_changed")).is_true()

	# Rest of test...
```

---

### Hypothesis 4: Auto-Free Cleanup Race Condition (MEMORY)
**Theory**: `auto_free()` frees CharacterManager before signals propagate

**Why This Could Happen**:
```gdscript
character_manager = auto_free(CharacterManagerClass.new())
# ... test runs ...
# auto_free() schedules manager for deletion
# Signals may be disconnected before assertion runs
```

**Debug Steps**:
```gdscript
func test_character_removal_emits_signal():
	# DON'T use auto_free for this test
	character_manager = CharacterManagerClass.new()
	character_manager._initialize_manager()

	# ... rest of test ...

	# Manual cleanup in after_test()
```

---

### Hypothesis 5: gdUnit4 Signal Monitor Bug with Typed Arrays (FRAMEWORK)
**Theory**: `Array[Character]` typed array confuses signal collector

**Why This Could Happen**:
- CharacterManager uses `var crew_roster: Array[Character] = []`
- gdUnit4 signal monitor may not handle typed arrays correctly
- Signal emission fails silently

**Debug Steps**:
```gdscript
# CharacterManager.gd - Add manual signal verification:
func remove_character_from_roster(character_id: String) -> bool:
	for i: int in range(crew_roster.size()):
		if crew_roster[i].character_id == character_id:
			# ... validation ...
			crew_roster.remove_at(i)

			# VERIFY SIGNAL CAN BE EMITTED
			print("[DEBUG] About to emit character_removed")
			character_removed.emit(character_id)
			print("[DEBUG] Signal emitted successfully")

			crew_size_changed.emit(crew_roster.size())
			return true
	return false
```

---

## Systematic Debugging Process

### Step 1: Isolate the Test
Run ONLY `test_crew_boundaries.gd`:
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/phase3_consistency/test_crew_boundaries.gd `
  --quit-after 60
```

### Step 2: Add Comprehensive Debug Logging
Modify `CharacterManager.gd` and test file with all debug prints from hypotheses above

### Step 3: Run Test and Capture Output
```bash
# Redirect output to file
... > test_debug_output.txt 2>&1
```

### Step 4: Analyze Output
Look for:
- Character ID mismatches
- Roster size inconsistencies
- Missing signal definitions
- Timing issues (signals before monitor)

### Step 5: Implement Fix Based on Root Cause
See "Fix Implementations" section below

---

## Fix Implementations (Once Root Cause Found)

### Fix for Hypothesis 1: Character Not Found
```gdscript
# CharacterManager.gd
func create_character(character_data: Dictionary) -> Character:
	var character = Character.new()
	# ... configure character ...

	# ENSURE ID IS SET
	if character.character_id == null or character.character_id.is_empty():
		push_error("Character created without ID!")
		return null

	# ENSURE ADDED TO ROSTER
	var added = add_character_to_roster(character)
	if not added:
		push_warning("Character created but not added to roster (max crew size)")

	return character
```

### Fix for Hypothesis 2: Signal Timing
```gdscript
# test_crew_boundaries.gd
func test_character_removal_emits_signal():
	# Attach monitor FIRST
	var signal_monitor = monitor_signals(character_manager)

	# Then create characters
	for i in range(5):
		# ...
```

### Fix for Hypothesis 3: Signal Declaration
```gdscript
# CharacterManager.gd - Verify signals are class-level
class_name CharacterManager
extends RefCounted  # Or Node if needed

signal character_removed(character_id: String)
signal crew_size_changed(new_size: int)
signal character_created(character: Character)
```

### Fix for Hypothesis 4: Auto-Free Race
```gdscript
# test_crew_boundaries.gd
var character_manager = null

func before_test():
	character_manager = CharacterManagerClass.new()
	character_manager._initialize_manager()

func after_test():
	if character_manager:
		character_manager.free()
	character_manager = null
```

### Fix for Hypothesis 5: Typed Array Issue
```gdscript
# CharacterManager.gd - Change to untyped array
var crew_roster: Array = []  # Instead of Array[Character]
```

---

## Expected Outcomes

### If Hypothesis 1 is Correct
**Output**:
```
[DEBUG] Created character: char_001
[DEBUG] Created character: char_002
...
[DEBUG] Crew roster IDs:
  - char_001
  - char_002
...
[DEBUG] Target removal ID: char_001
[DEBUG] Character found in roster: true
[DEBUG] Removal result: true
✅ Test passes
```

### If Hypothesis 2 is Correct
**Output**:
```
# Before fix:
FAILED: Expecting emit signal: 'character_removed()' but timed out

# After fix (monitor attached early):
✅ Test passes
```

### If Hypothesis 3 is Correct
**Output**:
```
[DEBUG] CharacterManager signals:
  - character_removed
  - crew_size_changed
  - character_created
✅ Test passes
```

### If Root Cause is Different
**Output**: New error message revealing actual issue

---

## Priority Actions

1. ✅ **IMMEDIATE**: Add debug logging to `test_character_removal_emits_signal`
2. ✅ **IMMEDIATE**: Run isolated test with full console output
3. **HIGH**: Verify character IDs are populated and match roster
4. **MEDIUM**: Test with monitor attached before character creation
5. **LOW**: Try without auto_free to rule out cleanup timing

---

## Success Criteria ✅ ALL MET (2025-12-28)

- [x] `test_character_removal_emits_signal` passes consistently
- [x] `test_character_removal_updates_crew_size` passes consistently
- [x] ~~Debug logging reveals exact failure point~~ **Root cause: missing argument matchers**
- [x] Fix applied to ~~CharacterManager.gd or~~ test file (test_crew_boundaries.gd)
- [x] All 8 tests in `test_crew_boundaries.gd` pass
- [x] No signal timeouts in test reports (868 tests, 0 failures)

---

## Next Steps After Fix ✅ ALL COMPLETED

1. ✅ Applied same fix to `test_character_removal_updates_crew_size` (line 187)
2. ✅ Verified no regressions - 868 tests passing
3. ✅ Documented findings in `TESTING_GUIDE.md` (Signal Assertions best practice #5)
4. ✅ Updated `SIGNAL_MONITOR_LEAKAGE_ANALYSIS.md` with confirmed root cause
5. ✅ Pattern 9 documented in `INTEGRATION_TEST_FIX_PATTERNS.md` for future prevention
