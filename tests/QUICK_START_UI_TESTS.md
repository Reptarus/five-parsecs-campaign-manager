# Quick Start: UI Component Tests

**Run All Tests**: `.\tests\run_ui_component_tests.ps1`

## What's Tested

| Component | Tests | What Gets Validated |
|-----------|-------|---------------------|
| CampaignTurnProgressTracker | 8 | 7-step cycle, state colors, signals |
| MissionStatusCard | 3 | Name, progress bar, click signals |
| WorldStatusCard | 2 | Planet name, threat indicators |
| StoryTrackSection | 2 | Purple progress, milestone markers |
| QuickActionsFooter | 4 | 6 buttons, 72x72 touch targets |
| Glass Morphism | 2 | Alpha transparency, blur effects |

**Total**: 21 tests covering 100% of component public APIs

## Run Individual Tests

```powershell
# Turn Tracker (8 tests)
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_campaign_turn_tracker.gd `
  --quit-after 60

# Dashboard Components (13 tests)
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_dashboard_components.gd `
  --quit-after 60
```

## Expected Results

**Before Components Implemented**: All tests skip gracefully
```
✓ 21/21 SKIPPED (components not found)
```

**After Components Implemented**: All tests pass
```
✓ 21/21 PASSED
```

## Component API Cheat Sheet

### CampaignTurnProgressTracker
```gdscript
func get_step_count() -> int
func set_current_step(index: int)
func mark_step_completed(index: int)
signal step_clicked(step_index: int)
```

### MissionStatusCard
```gdscript
func set_mission_data(data: Dictionary)
var progress_bar: ProgressBar
signal details_requested(mission_data)
```

### QuickActionsFooter
```gdscript
func get_button_count() -> int  # Should return 6
signal action_triggered(action_name: String)
# Buttons must be 72x72 minimum
```

## Full Documentation

- [UI_COMPONENT_TESTING_GUIDE.md](UI_COMPONENT_TESTING_GUIDE.md) - Complete testing guide
- [UI_COMPONENT_TESTS_SUMMARY.md](UI_COMPONENT_TESTS_SUMMARY.md) - Delivery summary
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Main testing framework

## Test File Locations

```
tests/
├── unit/test_campaign_turn_tracker.gd      (8 tests)
├── integration/test_dashboard_components.gd (13 tests)
└── run_ui_component_tests.ps1              (automation)
```

## Framework Constraints

- **Mode**: UI mode ONLY (no --headless)
- **Limit**: Max 13 tests per file
- **Framework**: gdUnit4 v6.0.1
- **Godot**: 4.5.1-stable

## Need Help?

1. Tests skipping? Components not implemented yet (expected)
2. Tests failing? Check component API matches expectations
3. Crashes? Using headless mode (switch to UI mode)
4. Questions? See UI_COMPONENT_TESTING_GUIDE.md

---

**Quick Win**: Run `.\tests\run_ui_component_tests.ps1` to see current state
