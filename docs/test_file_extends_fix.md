# Test File Extends Statement Fixes

## Overview

As described in the Action Plan (Phase 3: Code Architecture Refinement), we've identified issues with the way test files reference their base classes. This document explains the changes needed and provides guidance for fixing all test files.

## Problem

Test files currently use direct class references in extends statements, for example:

```gdscript
extends GameTest
```

This approach causes errors when the class names are removed or when there are conflicts with other classes. The test files should use explicit file paths instead.

## Solution

Replace direct class name references with explicit file paths in all test files:

| Current Pattern | Replacement Pattern |
|-----------------|---------------------|
| `extends GameTest` | `extends "res://tests/fixtures/base/game_test.gd"` |
| `extends BattleTest` | `extends "res://tests/fixtures/specialized/battle_test.gd"` |
| `extends UITest` | `extends "res://tests/fixtures/specialized/ui_test.gd"` |
| `extends CampaignTest` | `extends "res://tests/fixtures/specialized/campaign_test.gd"` |
| `extends EnemyTest` | `extends "res://tests/fixtures/specialized/enemy_test.gd"` |
| `extends MobileTest` | `extends "res://tests/fixtures/specialized/mobile_test.gd"` |

## Test File Locations

The primary test files that need updates are organized in these directories:

1. `tests/unit/` - Unit tests for individual components/systems
2. `tests/integration/` - Integration tests for system interactions
3. `tests/performance/` - Performance tests

## Template Update

The test template (`tests/templates/test_template.gd`) has been updated to use explicit file paths:

```gdscript
@tool
# Choose the appropriate base class for your test
# Replace with one of:
# - extends "res://tests/fixtures/base/game_test.gd" (general game tests)
# - extends "res://tests/fixtures/specialized/ui_test.gd" (UI component tests)
# - extends "res://tests/fixtures/specialized/battle_test.gd" (battle system tests)
# - extends "res://tests/fixtures/specialized/campaign_test.gd" (campaign system tests)
# - extends "res://tests/fixtures/specialized/enemy_test.gd" (enemy system tests)
# - extends "res://tests/fixtures/specialized/mobile_test.gd" (mobile-specific tests)
extends "res://tests/fixtures/base/game_test.gd"

# Use explicit preloads instead of global class names
const TestedClass = preload("res://path/to/class/being/tested.gd")
```

## Manual Fix Examples

Here are examples of files that have been fixed:

1. `tests/unit/campaign/test_patron.gd`
2. `tests/unit/ui/components/combat/test_validation_panel.gd`
3. `tests/integration/battle/test_battle_phase_flow.gd`
4. `tests/unit/mission/test_mission_system.gd`
5. `tests/unit/mission/test_mission_generator.gd`
6. `tests/unit/mission/test_mission_edge_cases.gd`

## Additional Considerations

When updating test files:

1. Add a comment after the extends line: `# Use explicit preloads instead of global class names`
2. Check for any type-related errors that might occur due to removing class_name declarations
3. Update any preload statements to use full paths if they previously relied on global class names
4. Ensure that test resource tracking is properly handled when using explicit paths

## Automation

A PowerShell script (`fix_test_extends.ps1`) has been created to automate these changes, but it should be run with caution and tested thoroughly afterward.

## Verification

After fixing extends statements, verify that:

1. GUT tests run without errors related to missing base classes
2. Test files correctly inherit methods and properties from their parent classes
3. No new script cache errors are introduced 