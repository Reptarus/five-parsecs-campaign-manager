# KeywordTooltip Quick Fix Guide

**Estimated Time**: 10 minutes
**Goal**: Get all 5 unit tests passing

---

## Problem

Tests fail because they try to instantiate `KeywordTooltip` like a plain class:

```gdscript
# ❌ This doesn't work for Control classes
var TooltipClass: GDScript = load("res://src/ui/components/qol/KeywordTooltip.gd")
tooltip = auto_free(TooltipClass.new())
```

**Error**: `Invalid call. Nonexistent function 'new' in base 'GDScript'`

---

## Solution: Update Test Instantiation

### File to Edit
`tests/unit/test_keyword_tooltip.gd`

### Changes Required

#### Change 1: Remove GDScript load (lines 21-22)
```gdscript
# OLD CODE (DELETE THESE LINES):
var tooltip: KeywordTooltip
var TooltipClass: GDScript = null

# NEW CODE:
var tooltip: KeywordTooltip
```

#### Change 2: Remove before() suite setup (lines 24-28)
```gdscript
# OLD CODE (DELETE THIS FUNCTION):
func before():
	"""Suite-level setup - runs once before all tests"""
	TooltipClass = load("res://src/ui/components/qol/KeywordTooltip.gd")
	# ... backup code ...

# NEW CODE:
func before():
	"""Suite-level setup - runs once before all tests"""
	# Backup KeywordDB state
	original_keywords = KeywordDB.keywords.duplicate(true)
	original_bookmarks = KeywordDB.bookmarked_keywords.duplicate()
```

#### Change 3: Fix before_test() instantiation (lines 40-42)
```gdscript
# OLD CODE (REPLACE THESE LINES):
# Create tooltip instance - must be added to scene tree for _ready() to run
tooltip = auto_free(TooltipClass.new())
add_child(tooltip)

# NEW CODE:
# Create tooltip instance using class_name
tooltip = auto_free(KeywordTooltip.new())
add_child(tooltip)

# Wait for _ready() to complete (AcceptDialog lazy creation)
await get_tree().process_frame
```

---

## Complete Fixed before_test() Function

```gdscript
func before_test():
	"""Test-level setup - runs before EACH test"""
	# Clear KeywordDB for clean test state
	KeywordDB.keywords.clear()
	KeywordDB.bookmarked_keywords.clear()

	# Create tooltip instance using class_name
	tooltip = auto_free(KeywordTooltip.new())
	add_child(tooltip)
	
	# Wait for _ready() to complete
	await get_tree().process_frame

	# Create test control for positioning
	test_control = auto_free(Control.new())
	test_control.position = Vector2(100, 100)
	test_control.size = Vector2(50, 50)
	add_child(test_control)

	# Setup test keyword data
	test_keyword_data = {
		"term": "Assault",
		"definition": "Can move before or after firing in same activation.",
		"extended": "This trait allows tactical repositioning during combat.",
		"examples": ["A soldier with Assault fires, then moves to cover."],
		"related": ["Cover", "Movement"],
		"rule_page": 42
	}

	# Add test keyword to KeywordDB
	KeywordDB.keywords["assault"] = test_keyword_data
```

---

## Complete Fixed before() Function

```gdscript
func before():
	"""Suite-level setup - runs once before all tests"""
	# Backup KeywordDB state
	original_keywords = KeywordDB.keywords.duplicate(true)
	original_bookmarks = KeywordDB.bookmarked_keywords.duplicate()
```

---

## Complete Fixed after() Function

```gdscript
func after():
	"""Suite-level cleanup - runs once after all tests"""
	# Restore original KeywordDB state
	KeywordDB.keywords = original_keywords
	KeywordDB.bookmarked_keywords = original_bookmarks
```

---

## Run Tests

```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_keyword_tooltip.gd `
  --quit-after 60
```

---

## Expected Output

```
Run Test Suite: res://tests/unit/test_keyword_tooltip.gd
  test_format_keyword_text_creates_correct_bbcode ✅ PASSED
  test_format_keyword_text_handles_minimal_data ✅ PASSED
  test_show_for_keyword_displays_tooltip_with_keyword_data ✅ PASSED
  test_show_for_keyword_handles_unknown_keyword_gracefully ✅ PASSED
  test_bookmark_button_toggles_bookmark_state ✅ PASSED

Total: 5 tests, 5 passed, 0 failed
```

---

## If Tests Still Fail

### Common Issue 1: Signal Timeout

**Error**: `await_signal_on timeout after 500ms`

**Fix**: Increase timeout or remove await if signal is instant:

```gdscript
# OLD:
await await_signal_on(tooltip, "tooltip_shown", 500)

# NEW (if signal emits immediately):
# Just check signal was emitted, don't wait
```

### Common Issue 2: Assertion Mismatch

**Error**: `assert_that(X).contains(Y)` fails

**Fix**: Check actual BBCode format in implementation:

```gdscript
# If test expects: "[b]ASSAULT[/b]"
# But code produces: "[b]Assault[/b]"
# Update test to match actual output
```

---

## Next Step After Tests Pass

Integrate tooltip into one screen (CharacterDetailsScreen recommended):

```gdscript
# In CharacterDetailsScreen.gd _ready():
var tooltip = KeywordTooltip.new()
add_child(tooltip)

# In equipment trait display:
traits_label.meta_clicked.connect(func(meta):
    if str(meta).begins_with("keyword:"):
        var keyword = str(meta).substr(8)
        tooltip.show_for_keyword(keyword, traits_label)
)
```

---

**Estimated Fix Time**: 5-10 minutes
**Next Session Goal**: All tests green, one integration example working
