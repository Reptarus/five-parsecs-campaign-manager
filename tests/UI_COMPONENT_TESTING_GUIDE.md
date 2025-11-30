# UI Component Testing Guide

**Created**: 2025-11-28
**Test Framework**: gdUnit4 v6.0.1
**Status**: Test suites created, awaiting component implementation

## Overview

This guide covers testing for the modernized UI components being developed for the Five Parsecs Campaign Manager dashboard. Tests are designed to be **forward-compatible** - they gracefully skip when components aren't yet implemented.

## Test Files Created

### 1. test_campaign_turn_tracker.gd (Unit Tests)
**Location**: `tests/unit/test_campaign_turn_tracker.gd`
**Target Component**: `src/ui/components/campaign/CampaignTurnProgressTracker.gd`
**Test Count**: 8 tests (under 13-test stability limit)

#### Coverage
- **Initialization** (2 tests)
  - 7-step tracker initialization
  - Default "upcoming" state for all steps

- **State Management** (3 tests)
  - Current step highlighting (amber color)
  - Completed step styling (emerald + checkmark)
  - Auto-completion of previous steps

- **Signals** (1 test)
  - `step_clicked` signal emission with step index

- **Content** (2 tests)
  - Step labels (Travel, World, Battle, Post-Battle, Upkeep, Travel, World)
  - Connector lines between steps

### 2. test_dashboard_components.gd (Integration Tests)
**Location**: `tests/integration/test_dashboard_components.gd`
**Target Components**:
- `src/ui/components/mission/MissionStatusCard.gd`
- `src/ui/components/world/WorldStatusCard.gd`
- `src/ui/components/campaign/StoryTrackSection.gd`
- `src/ui/components/campaign/QuickActionsFooter.gd`

**Test Count**: 13 tests (at 13-test stability limit)

#### Coverage
- **MissionStatusCard** (3 tests)
  - Mission name display
  - Progress bar rendering (67% progress)
  - `details_requested` signal emission

- **WorldStatusCard** (2 tests)
  - Planet name display
  - Threat level indicators + invasion warning

- **StoryTrackSection** (2 tests)
  - Story progress bar with purple accent
  - Milestone markers at 25%/50%/75%/100%

- **QuickActionsFooter** (4 tests)
  - 6 action buttons present
  - Touch target compliance (72x72 minimum)
  - `action_triggered` signal emission
  - Correct button labels (Crew, Ship, Market, Missions, Story, Settings)

- **Glass Morphism Styling** (2 tests)
  - Alpha transparency on panels (0.7-1.0 range)
  - Background blur support (BackBufferCopy detection)

## Running Tests

### Prerequisites
- Godot 4.5.1 console executable
- gdUnit4 v6.0.1 installed in project
- Component scripts/scenes in expected locations

### Running All UI Tests (PowerShell)

```powershell
# Run turn tracker tests
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_campaign_turn_tracker.gd `
  --quit-after 60

# Run dashboard component tests
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_dashboard_components.gd `
  --quit-after 60
```

### Running Both Tests in Sequence

```powershell
$testFiles = @(
    'tests/unit/test_campaign_turn_tracker.gd',
    'tests/integration/test_dashboard_components.gd'
)

foreach ($testFile in $testFiles) {
    Write-Host "Running: $testFile" -ForegroundColor Cyan
    & 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
      --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
      --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
      -a $testFile `
      --quit-after 60
    Write-Host ""
}
```

## Test Design Patterns

### Forward Compatibility
All tests use **graceful skipping** when components aren't implemented yet:

```gdscript
func test_example():
    if component == null:
        skip_test("Component not yet implemented")
        return

    if not component.has_method("required_method"):
        skip_test("required_method() not yet implemented")
        return

    # Test logic here
```

### Null Safety
Components are loaded with null checks:

```gdscript
func _load_component():
    var ComponentScene = load("res://path/to/Component.gd")
    if ComponentScene != null:
        component = auto_free(ComponentScene.new())
        test_container.add_child(component)
```

### Signal Testing Pattern
```gdscript
# Create monitor
var signal_monitor = monitor_signals(component)

# Trigger action
component._on_action()

# Verify emission
assert_signal(signal_monitor).is_emitted("signal_name", [expected_args])
```

### Visual Property Testing
```gdscript
# Test progress bar value
var progress = component.progress_bar.value
assert_that(progress).is_between(0.66, 0.68)

# Test color (approximate)
var color = component.get_step_color(3)
assert_that(color.r).is_greater(0.7)  # Amber has high red
```

## Expected Test Results

### Before Component Implementation
```
test_campaign_turn_tracker.gd:
  8/8 tests SKIPPED (component not found)

test_dashboard_components.gd:
  13/13 tests SKIPPED (components not found)
```

### During Implementation (Partial)
```
test_campaign_turn_tracker.gd:
  3/8 tests PASSED (initialization + basic state)
  5/8 tests SKIPPED (advanced features not yet implemented)

test_dashboard_components.gd:
  4/13 tests PASSED (MissionStatusCard + WorldStatusCard basic)
  9/13 tests SKIPPED (StoryTrack, QuickActions, glass morphism)
```

### Full Implementation Target
```
test_campaign_turn_tracker.gd:
  8/8 tests PASSED ✅

test_dashboard_components.gd:
  13/13 tests PASSED ✅

Total: 21/21 tests PASSED
```

## Component API Expectations

### CampaignTurnProgressTracker
```gdscript
# Required methods
func get_step_count() -> int
func get_step_state(index: int) -> String  # "upcoming" | "current" | "completed"
func set_current_step(index: int) -> void
func mark_step_completed(index: int) -> void
func get_step_label(index: int) -> String
func get_step_color(index: int) -> Color
func get_step_icon(index: int) -> String
func get_connector_count() -> int
func is_connector_visible(index: int) -> bool

# Required signals
signal step_clicked(step_index: int)
```

### MissionStatusCard
```gdscript
# Required methods
func set_mission_data(data: Dictionary) -> void
func get_displayed_name() -> String
func get_progress() -> float

# Required properties
var name_label: Label
var progress_bar: ProgressBar

# Required signals
signal details_requested(mission_data: Dictionary)
```

### WorldStatusCard
```gdscript
# Required methods
func set_world_data(data: Dictionary) -> void
func get_displayed_planet() -> String
func get_threat_level() -> int
func is_invasion_warning_visible() -> bool

# Required properties
var planet_label: Label
var threat_indicator: Node
```

### StoryTrackSection
```gdscript
# Required methods
func set_story_progress(progress: float) -> void
func get_progress() -> float
func set_milestones(positions: Array[float]) -> void
func get_milestone_count() -> int

# Required properties
var progress_bar: ProgressBar
var milestone_markers: Array
```

### QuickActionsFooter
```gdscript
# Required methods
func get_button_count() -> int
func get_action_buttons() -> Array
func get_action_labels() -> Array[String]

# Required properties
var action_buttons: Array  # [Button, Button, ...]

# Required signals
signal action_triggered(action_name: String)
```

## Integration with UI Design System

Tests reference the design system from `BaseCampaignPanel.gd`:

### Color Constants
- `COLOR_ACCENT` (#2D5A7B) - Deep Space Blue
- `COLOR_SUCCESS` (#10B981) - Emerald green (completed steps)
- `COLOR_WARNING` (#D97706) - Amber (current step)
- `COLOR_TEXT_PRIMARY` (#E0E0E0)

### Spacing System (8px grid)
- `SPACING_XS` = 4px
- `SPACING_SM` = 8px
- `SPACING_MD` = 16px
- `SPACING_LG` = 24px

### Touch Targets
- `TOUCH_TARGET_MIN` = 48px (tested: 72px for comfort)
- `TOUCH_TARGET_COMFORT` = 56px

## Debugging Failed Tests

### Common Issues

1. **Component not found**
   - Verify file exists at expected path
   - Check `load()` path matches actual location

2. **Method not found**
   - Verify component implements expected API
   - Check method spelling and signature

3. **Signal not emitted**
   - Verify signal is declared in component
   - Check signal is connected to test slot
   - Use `monitor_signals()` for verification

4. **Visual property mismatches**
   - Color/size tests may need adjustment for actual implementation
   - Use approximate assertions (`is_between()`, `is_greater()`)

### Test Debugging Pattern
```gdscript
func test_example():
    # Add debug prints
    print("Component: ", component)
    print("Has method: ", component.has_method("test_method"))
    print("Signal list: ", component.get_signal_list())

    # Test logic with checks
    if component == null:
        push_error("Component is null!")
        return
```

## Next Steps

1. **Component Implementation**: Agents building components should reference this guide
2. **API Compliance**: Ensure components implement expected methods/signals/properties
3. **Test Execution**: Run tests after each component milestone
4. **Bug Fixes**: Use test failures to guide implementation corrections
5. **Documentation Updates**: Update this guide if API changes during implementation

## Success Metrics

- **Code Coverage**: 100% of public component API tested
- **Signal Coverage**: All component signals have test cases
- **Edge Cases**: Null safety, missing data, boundary conditions tested
- **Visual Compliance**: Design system constants validated
- **Mobile UX**: Touch target sizes validated (72x72 minimum)

## Reference Documentation

- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Main testing framework guide
- [CLAUDE.md](../CLAUDE.md) - Project architecture and design system
- [BaseCampaignPanel.gd](../src/ui/screens/campaign/panels/BaseCampaignPanel.gd) - Design system source
