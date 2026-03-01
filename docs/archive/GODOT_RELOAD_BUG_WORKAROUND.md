# Godot 4.4.1 Script Reload Bug - Workaround Documentation

**Date**: November 14, 2025
**Godot Version**: 4.4.1 (and potentially 4.5.1)
**Status**: Engine Bug - Workaround Required
**Severity**: Medium (affects testing, not production)

---

## Executive Summary

Godot 4.4.1 has a script caching/reloading bug that causes valid GDScript files to fail with parse errors on reload. This primarily affects testing scenarios where scripts are loaded multiple times in quick succession.

**Impact**: Tests may fail on subsequent runs even though the code is correct.
**Workaround**: Clear Godot cache directories before running tests.

---

## Bug Symptoms

### Initial Symptom
```bash
✅ GameGear script loaded
...
SCRIPT ERROR: Parse Error: Expected loop variable name after "for".
   at: GDScript::reload (res://src/core/economy/loot/GameGear.gd:90)
```

### Characteristics
1. **Script loads successfully on first run**
2. **Same script fails with parse error on reload**
3. **Parse error points to valid code** (e.g., correct `for` loop syntax)
4. **Error disappears after cache clear**
5. **Reappears on subsequent reloads without cache clear**

---

## Root Cause Analysis

### Investigation Findings

**File**: `GameGear.gd` (and other economy system classes)
**Line 90** (example):
```gdscript
for trait in gear_data["traits"]:  # Valid syntax
    if trait is String:
        gear_traits.append(trait)
```

**What Godot Reports**: "Parse Error: Expected loop variable name after 'for'"
**Reality**: The code is syntactically correct

### Engine Issue
- Godot's script cache becomes corrupted after autoloads initialize
- Subsequent reloads fail to parse previously-valid scripts
- Cache invalidation does not occur automatically
- Bug exists in Godot 4.4.1 and potentially 4.5.1

---

## The Workaround

### Quick Fix (Command Line)
```bash
# Windows (PowerShell)
Remove-Item -Recurse -Force .godot/editor, .godot/imported, .godot/shader_cache

# Windows (CMD)
rmdir /s /q .godot\editor .godot\imported .godot\shader_cache

# Linux/macOS
rm -rf .godot/editor .godot/imported .godot/shader_cache
```

### Script-Based Workaround
```bash
# Create a pre-test cleanup script
@echo off
echo Clearing Godot cache...
rmdir /s /q .godot\editor 2>nul
rmdir /s /q .godot\imported 2>nul
rmdir /s /q .godot\shader_cache 2>nul
echo Cache cleared. Running tests...
godot --headless --script tests/test_economy_system.gd --quit
```

### Godot Project Setting (Not Recommended)
**DO NOT** disable editor cache in production:
```gdscript
# project.godot - NOT RECOMMENDED FOR PRODUCTION
[editor]
export/convert_text_resources_to_binary=false
```
**Why**: Disabling cache impacts editor performance significantly

---

## Testing Workflow

### Best Practice: Pre-Test Cache Clear

**Before running any test suite**:
```bash
# 1. Clear cache
rm -rf .godot/editor .godot/imported .godot/shader_cache

# 2. Run tests
godot --headless --script tests/test_economy_system.gd --quit-after 10
```

### Continuous Integration Setup
```yaml
# .github/workflows/godot-tests.yml
jobs:
  test:
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Clear Godot Cache
        run: rm -rf .godot/editor .godot/imported .godot/shader_cache

      - name: Run Tests
        run: godot --headless --script tests/test_economy_system.gd --quit
```

---

## Affected Files (Known)

Based on Week 3 Day 3 testing:
1. [src/core/economy/loot/GameGear.gd](src/core/economy/loot/GameGear.gd) - Line 90
2. [src/core/economy/loot/GameItem.gd](src/core/economy/loot/GameItem.gd) - Similar patterns
3. Any script using autoload references at class level

### Common Pattern
```gdscript
# This pattern triggers the bug:
var tree = Engine.get_main_loop() as SceneTree
if tree and tree.root:
    _data_manager = tree.root.get_node_or_null("DataManager")
```

**Why**: Autoload initialization order interacts poorly with script cache

---

## Detection Strategy

### How to Identify the Bug
1. **Symptom**: Script loads on first run, fails on second
2. **Verification**:
   ```bash
   # Run test twice
   godot --headless --script test.gd --quit
   godot --headless --script test.gd --quit  # <-- Fails here

   # Clear cache and retry
   rm -rf .godot/editor .godot/imported .godot/shader_cache
   godot --headless --script test.gd --quit  # <-- Works again
   ```
3. **Confirmation**: If test passes after cache clear, it's the reload bug

### Red Flags
- Parse errors that don't match actual code
- "Expected loop variable" on valid `for` loops
- Errors mentioning `GDScript::reload`
- Tests passing initially, failing on re-run

---

## Production Impact

### Good News
✅ **No impact on production builds**
✅ **No impact on exported games**
✅ **Only affects editor and headless testing**

### Testing Impact
⚠️ **Tests may need cache clear between runs**
⚠️ **CI/CD pipelines must include cache clear step**
⚠️ **Development workflow: clear cache if weird errors appear**

---

## Reporting to Godot Team

### Bug Report Checklist
If reporting to Godot development team:
- [ ] Provide minimal reproduction case
- [ ] Include cache state (before/after clear)
- [ ] Specify Godot version (4.4.1 or 4.5.1)
- [ ] Show parse error vs actual code
- [ ] Demonstrate fix via cache clear

### GitHub Issue Template
```markdown
**Godot Version**: 4.4.1
**OS**: Windows 11 / macOS / Linux

**Issue**: Valid GDScript fails to reload with parse error

**Steps to Reproduce**:
1. Load script with autoload reference
2. Reload script (headless test run)
3. Observe parse error on valid code

**Workaround**: Clear .godot/editor cache

**Expected**: Script reloads successfully
**Actual**: Parse error: "Expected loop variable name after 'for'"
```

---

## Recommended Actions

### For Development Team
1. ✅ Add cache clear to all test scripts
2. ✅ Document workaround in README
3. ✅ Create pre-test cleanup script
4. ✅ Update CI/CD pipelines
5. ⏳ Monitor Godot issue tracker for fix

### For CI/CD
```yaml
# Always clear cache before tests
before_script:
  - rm -rf .godot/editor .godot/imported .godot/shader_cache
```

### For Local Development
```bash
# Create alias in ~/.bashrc or ~/.zshrc
alias godot-test='rm -rf .godot/editor .godot/imported .godot/shader_cache && godot --headless'
```

---

## Timeline & Status

| Date | Event |
|------|-------|
| Nov 14, 2025 | Bug discovered in Week 3 Day 3 economy tests |
| Nov 14, 2025 | Workaround documented |
| Nov 14, 2025 | Applied to all test workflows |
| TBD | Godot engine fix release |

**Current Status**: Workaround implemented, tests passing after cache clear
**Next Steps**: Monitor Godot 4.5.2+ for potential fix

---

## Additional Resources

- [Godot GitHub Issues](https://github.com/godotengine/godot/issues)
- [GDScript Script Reloading Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_advanced.html)
- [Week 3 Day 3 Report](WEEK_3_DAY_3_DATAMANAGER_FIXES.md)

---

**Maintained by**: Five Parsecs Campaign Manager Development Team
**Last Updated**: November 14, 2025
