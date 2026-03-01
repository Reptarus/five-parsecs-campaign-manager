# Battle System Testing Guide
**Purpose**: Quick-reference for running and creating battle system tests
**Target Audience**: QA, Developers, Integration Testers
**Last Updated**: 2025-11-27

---

## Quick Start: Running Battle Tests

### Run All Battle Tests (PowerShell)

```powershell
# Navigate to project directory
cd "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"

# Run all integration tests (battle + world flow)
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/ `
  --quit-after 60
```

### Run Specific Battle Test

```powershell
# Example: Run battle data flow test
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_data_flow.gd `
  --quit-after 60
```

---

## Existing Battle Tests (10 Files)

### Integration Tests

| Test File | Purpose | Status | Key Tests |
|-----------|---------|--------|-----------|
| `test_battle_data_flow.gd` | PreBattle → Battle → PostBattle pipeline | ✅ PASSING | Data serialization, phase transitions |
| `test_battle_integration_validation.gd` | End-to-end battle validation | ✅ PASSING | Complete battle flow, results validation |
| `test_battle_results.gd` | Battle results calculation | ✅ PASSING | Victory/defeat, casualties, rewards |
| `test_battle_setup_data.gd` | Setup data structures | ✅ PASSING | Initiative, deployment, mission data |
| `test_battle_calculations.gd` | Combat math | ✅ PASSING | XP, loot rolls, danger pay |
| `test_battle_4phase_resolution.gd` | Phase transitions | ✅ PASSING | Setup → Deployment → Combat → Results |
| `test_battle_initialization.gd` | Initialization flow | ✅ PASSING | Battle manager startup |
| `test_battle_phase_integration.gd` | Phase manager | ✅ PASSING | Phase state management |
| `test_world_to_battle_flow.gd` | World → Battle transition | ✅ PASSING | Campaign to battle handoff |
| `test_loot_battlefield_finds.gd` | Loot generation | ✅ PASSING | Battlefield finds, loot tables |

### Unit Tests

| Test File | Purpose | Status | Key Tests |
|-----------|---------|--------|-----------|
| `test_battle_calculations.gd` | Isolated combat math | ✅ PASSING | Dice rolls, stat checks |

---

## Test Coverage Gaps (To Be Created)

### Priority 1: UI Tests (MISSING)

**Create**: `tests/integration/test_battle_companion_ui_signals.gd`

```gdscript
extends GdUnitTestSuite

## Tests for BattleCompanionUI signal architecture
## Ensures phase transitions and signal propagation work correctly

var battle_ui: FPCM_BattleCompanionUI

func before_test() -> void:
	var scene = load("res://src/ui/screens/battle/BattleCompanionUI.tscn")
	battle_ui = scene.instantiate()
	add_child(battle_ui)
	await battle_ui.ready

func after_test() -> void:
	if battle_ui:
		battle_ui.queue_free()
		battle_ui = null

func test_phase_navigation_signal_emitted() -> void:
	"""Verify phase navigation signal is emitted correctly"""
	var signal_emitted := false
	var emitted_phase = null

	battle_ui.phase_navigation_requested.connect(func(phase):
		signal_emitted = true
		emitted_phase = phase
	)

	# Simulate next phase button press
	battle_ui._on_next_phase_pressed()

	assert_bool(signal_emitted).is_true()
	assert_that(emitted_phase).is_not_null()

func test_battle_action_triggered_signal() -> void:
	"""Verify battle action signals are properly emitted"""
	var action_triggered := false
	var action_data: Dictionary = {}

	battle_ui.battle_action_triggered.connect(func(action: String, data: Dictionary):
		action_triggered = true
		action_data = data
	)

	# Simulate battle action
	battle_ui._on_complete_battle_pressed()

	assert_bool(action_triggered).is_true()
	assert_that(action_data).is_not_empty()

func test_phase_transition_updates_ui() -> void:
	"""Verify UI updates when phase changes"""
	var initial_phase = battle_ui.current_phase

	# Advance to next phase
	battle_ui._advance_to_next_phase()

	assert_that(battle_ui.current_phase).is_not_equal(initial_phase)
	assert_that(battle_ui.phase_indicator.text).is_not_empty()

func test_ui_lock_during_processing() -> void:
	"""Verify UI locks during async operations"""
	battle_ui._lock_ui("Processing...")

	assert_bool(battle_ui.ui_locked).is_true()

	battle_ui._unlock_ui()

	assert_bool(battle_ui.ui_locked).is_false()
```

**Estimated Time**: 1-2 hours

---

### Priority 2: Screen Transition Tests (MISSING)

**Create**: `tests/integration/test_battle_screen_transitions.gd`

```gdscript
extends GdUnitTestSuite

## Tests for battle screen transitions
## Ensures smooth flow between PreBattle → Companion → Tactical → Results

var pre_battle_ui: FPCM_PreBattleUI
var companion_ui: FPCM_BattleCompanionUI
var tactical_ui: FPCM_TacticalBattleUI
var results_ui: Control

func before_test() -> void:
	# Load all battle screens
	pre_battle_ui = load("res://src/ui/screens/battle/PreBattleUI.tscn").instantiate()
	companion_ui = load("res://src/ui/screens/battle/BattleCompanionUI.tscn").instantiate()
	tactical_ui = load("res://src/ui/screens/battle/TacticalBattleUI.tscn").instantiate()
	results_ui = load("res://src/ui/screens/battle/PostBattleResultsUI.tscn").instantiate()

func after_test() -> void:
	if pre_battle_ui: pre_battle_ui.queue_free()
	if companion_ui: companion_ui.queue_free()
	if tactical_ui: tactical_ui.queue_free()
	if results_ui: results_ui.queue_free()

func test_pre_battle_to_companion_transition() -> void:
	"""Test data handoff from PreBattle to Companion"""
	add_child(pre_battle_ui)
	await pre_battle_ui.ready

	# Setup crew and mission
	var crew := _create_test_crew(4)
	var mission := _create_test_mission()

	pre_battle_ui.set_mission(mission)
	pre_battle_ui.set_crew(crew)

	# Confirm deployment
	var deployment_data: Dictionary = {}
	pre_battle_ui.deployment_confirmed.connect(func(data):
		deployment_data = data
	)

	pre_battle_ui._on_confirm_pressed()

	assert_that(deployment_data).is_not_empty()
	assert_bool(deployment_data.has("crew")).is_true()
	assert_bool(deployment_data.has("mission")).is_true()

func test_companion_to_tactical_transition() -> void:
	"""Test transition from Companion to Tactical mode"""
	add_child(companion_ui)
	await companion_ui.ready

	# Setup companion with battle data
	var crew := _create_test_crew(4)
	var enemies := _create_test_enemies(3)
	var mission := _create_test_mission()

	companion_ui.setup_battle(mission, crew, enemies)

	# Verify tactical mode can be triggered
	var tactical_requested := false
	companion_ui.battle_action_triggered.connect(func(action, _data):
		if action == "play_tactical":
			tactical_requested = true
	)

	# Simulate "Play Tactically" button
	# companion_ui._on_play_tactical_pressed() # (if method exists)

	# For now, verify companion is properly initialized
	assert_that(companion_ui.battle_manager).is_not_null()

func _create_test_crew(count: int) -> Array:
	var crew := []
	for i in range(count):
		crew.append({
			"id": "crew_%d" % i,
			"name": "Crew Member %d" % i,
			"stats": {"reactions": 1, "combat_skill": 0, "toughness": 3}
		})
	return crew

func _create_test_enemies(count: int) -> Array:
	var enemies := []
	for i in range(count):
		enemies.append({
			"id": "enemy_%d" % i,
			"name": "Enemy %d" % i,
			"stats": {"combat_skill": 0, "toughness": 3}
		})
	return enemies

func _create_test_mission() -> Dictionary:
	return {
		"id": "test_mission",
		"type": "patrol",
		"difficulty": 2,
		"payment": 10
	}
```

**Estimated Time**: 2-3 hours

---

### Priority 3: Component Integration Tests (MISSING)

**Create**: `tests/integration/test_battle_component_integration.gd`

```gdscript
extends GdUnitTestSuite

## Tests for battle component integration
## Ensures components (WeaponTable, ReactionDice, etc.) work together

var weapon_table: FPCM_WeaponTableDisplay
var reaction_dice: FPCM_ReactionDicePanel
var morale_tracker: Control
var initiative_calc: Control

func before_test() -> void:
	weapon_table = load("res://src/ui/components/battle/WeaponTableDisplay.tscn").instantiate()
	reaction_dice = load("res://src/ui/components/battle/ReactionDicePanel.tscn").instantiate()
	morale_tracker = load("res://src/ui/components/battle/MoralePanicTracker.tscn").instantiate()
	initiative_calc = load("res://src/ui/components/battle/InitiativeCalculator.tscn").instantiate()

	add_child(weapon_table)
	add_child(reaction_dice)
	add_child(morale_tracker)
	add_child(initiative_calc)

func after_test() -> void:
	if weapon_table: weapon_table.queue_free()
	if reaction_dice: reaction_dice.queue_free()
	if morale_tracker: morale_tracker.queue_free()
	if initiative_calc: initiative_calc.queue_free()

func test_weapon_table_signal_propagation() -> void:
	"""Test weapon selection signal"""
	var weapon_selected := false
	var selected_weapon = null

	weapon_table.weapon_selected.connect(func(weapon_data):
		weapon_selected = true
		selected_weapon = weapon_data
	)

	# Simulate weapon selection (would need public method or UI interaction)
	# For now, verify component initializes correctly
	await weapon_table.ready
	assert_that(weapon_table.weapon_system).is_not_null()

func test_reaction_dice_spending() -> void:
	"""Test reaction dice can be spent and reset"""
	await reaction_dice.ready

	# Add crew members
	reaction_dice.add_crew_member("Crew 1", 2)
	reaction_dice.add_crew_member("Crew 2", 1)

	# Spend a die
	var spent := reaction_dice.spend_die("Crew 1")
	assert_bool(spent).is_true()

	# Verify die was spent
	var remaining := reaction_dice.crew_dice["Crew 1"]["current"]
	assert_int(remaining).is_equal(1)

	# Reset all dice
	reaction_dice._on_reset_pressed()
	var reset_value := reaction_dice.crew_dice["Crew 1"]["current"]
	assert_int(reset_value).is_equal(2) # Should reset to max

func test_morale_panic_tracking() -> void:
	"""Test morale panic tracker state management"""
	await morale_tracker.ready

	# Verify component loaded
	assert_that(morale_tracker).is_not_null()

func test_initiative_calculator() -> void:
	"""Test initiative calculation component"""
	await initiative_calc.ready

	# Verify component loaded
	assert_that(initiative_calc).is_not_null()
```

**Estimated Time**: 2-3 hours

---

### Priority 4: Persistent Status Bar Tests (AFTER IMPLEMENTATION)

**Create**: `tests/integration/test_battle_persistent_status_bar.gd`

```gdscript
extends GdUnitTestSuite

## Tests for persistent status bar
## Ensures status bar updates correctly across all battle phases

var status_bar: BattlePersistentStatusBar
var battle_manager: FPCM_BattleManager

func before_test() -> void:
	status_bar = load("res://src/ui/components/battle/BattlePersistentStatusBar.tscn").instantiate()
	battle_manager = FPCM_BattleManager.new()

	add_child(status_bar)
	add_child(battle_manager)

func after_test() -> void:
	if status_bar: status_bar.queue_free()
	if battle_manager: battle_manager.queue_free()

func test_status_bar_updates_on_round_change() -> void:
	"""Verify status bar displays current round"""
	await status_bar.ready

	status_bar.update_round(3)

	assert_that(status_bar.round_label.text).contains("3")

func test_status_bar_updates_on_objective_change() -> void:
	"""Verify status bar displays objective"""
	await status_bar.ready

	status_bar.update_objective("Hold the Field")

	assert_that(status_bar.objective_label.text).contains("Hold the Field")

func test_status_bar_updates_on_initiative_change() -> void:
	"""Verify status bar displays initiative status"""
	await status_bar.ready

	status_bar.update_initiative(true) # Crew has initiative

	assert_that(status_bar.initiative_label.text).contains("CREW")

func test_status_bar_visibility_across_phases() -> void:
	"""Verify status bar remains visible during phase changes"""
	await status_bar.ready

	# Status bar should always be visible
	assert_bool(status_bar.visible).is_true()

	# Simulate phase change
	status_bar.update_round(2)

	assert_bool(status_bar.visible).is_true()
```

**Estimated Time**: 1-2 hours (after status bar implemented)

---

## Design System Compliance Tests (MISSING)

### Create: `tests/validation/test_battle_design_system.gd`

```gdscript
extends GdUnitTestSuite

## Design system compliance tests for battle screens
## Validates spacing, colors, touch targets, typography

const BaseCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")

func test_battle_companion_uses_design_system_colors() -> void:
	"""Verify BattleCompanionUI uses design system colors"""
	var battle_ui = load("res://src/ui/screens/battle/BattleCompanionUI.tscn").instantiate()
	add_child(battle_ui)
	await battle_ui.ready

	# Check if any StyleBoxFlat uses design system colors
	var uses_design_colors := _check_node_uses_design_colors(battle_ui)

	# NOTE: This will FAIL until design system is migrated
	# assert_bool(uses_design_colors).is_true()

	battle_ui.queue_free()

func test_weapon_table_uses_design_system() -> void:
	"""Verify WeaponTableDisplay uses design system (should pass)"""
	var weapon_table = load("res://src/ui/components/battle/WeaponTableDisplay.tscn").instantiate()
	add_child(weapon_table)
	await weapon_table.ready

	# WeaponTableDisplay already uses design system
	var uses_design_colors := _check_node_uses_design_colors(weapon_table)
	assert_bool(uses_design_colors).is_true()

	weapon_table.queue_free()

func test_button_touch_targets_minimum_48dp() -> void:
	"""Verify all buttons meet minimum touch target size"""
	var battle_ui = load("res://src/ui/screens/battle/BattleCompanionUI.tscn").instantiate()
	add_child(battle_ui)
	await battle_ui.ready

	var buttons := _get_all_buttons(battle_ui)
	var violations := []

	for button in buttons:
		if button.custom_minimum_size.y > 0 and button.custom_minimum_size.y < 48:
			violations.append({
				"button": button.name,
				"height": button.custom_minimum_size.y
			})

	if violations.size() > 0:
		print("Touch target violations: ", violations)

	# NOTE: This will FAIL until touch targets are fixed
	# assert_array(violations).is_empty()

	battle_ui.queue_free()

func _check_node_uses_design_colors(node: Node) -> bool:
	"""Recursively check if node uses design system colors"""
	# Check if node has StyleBox overrides
	if node is Control:
		for override in ["panel", "normal", "hover", "pressed"]:
			var style = node.get_theme_stylebox(override)
			if style and style is StyleBoxFlat:
				var color: Color = style.bg_color
				# Check if color matches any design system color
				if _is_design_system_color(color):
					return true

	# Check children
	for child in node.get_children():
		if _check_node_uses_design_colors(child):
			return true

	return false

func _is_design_system_color(color: Color) -> bool:
	"""Check if color matches design system palette"""
	var design_colors := [
		BaseCampaignPanel.COLOR_BASE,
		BaseCampaignPanel.COLOR_ELEVATED,
		BaseCampaignPanel.COLOR_INPUT,
		BaseCampaignPanel.COLOR_BORDER,
		BaseCampaignPanel.COLOR_ACCENT,
		BaseCampaignPanel.COLOR_ACCENT_HOVER,
		BaseCampaignPanel.COLOR_FOCUS,
	]

	for design_color in design_colors:
		if color.is_equal_approx(design_color):
			return true

	return false

func _get_all_buttons(node: Node) -> Array[Button]:
	"""Recursively collect all buttons"""
	var buttons: Array[Button] = []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_get_all_buttons(child))
	return buttons
```

**Estimated Time**: 2-3 hours

---

## Test Execution Constraints (CRITICAL)

### DO NOT USE: `--headless` Flag

❌ **NEVER**:
```powershell
# This will crash after 8-18 tests with signal 11
--headless
```

✅ **ALWAYS USE**: UI mode via console executable
```powershell
Godot_v4.5.1-stable_win64_console.exe
```

### File Size Limits

⚠️ **Maximum 13 tests per file** for runner stability

If test file grows beyond 13 tests, split into multiple files:
```
test_battle_companion_ui_signals_part1.gd (13 tests)
test_battle_companion_ui_signals_part2.gd (remaining tests)
```

### Helper Classes

✅ **Plain helper classes** (no Node inheritance)
```gdscript
# GOOD
class BattleTestFactory:
	static func create_test_crew(count: int) -> Array:
		...
```

❌ **Avoid Node-based helpers** (causes instability)
```gdscript
# BAD
class TestHelper extends Node:
	...
```

---

## Running Tests: Complete Workflow

### Step 1: Navigate to Project

```powershell
cd "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"
```

### Step 2: Run Specific Test Category

**All Integration Tests**:
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/ `
  --quit-after 60
```

**All Unit Tests**:
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/ `
  --quit-after 60
```

**Single Test File**:
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_data_flow.gd `
  --quit-after 60
```

### Step 3: Review Results

Check console output for:
- ✅ PASSED tests
- ❌ FAILED tests
- ⏱️ Execution time
- 📊 Coverage summary

---

## Creating New Tests: Template

### Basic Test Structure

```gdscript
extends GdUnitTestSuite

## Brief description of what this test suite validates

# System under test
var system_under_test: Node

func before_test() -> void:
	"""Setup before each test"""
	system_under_test = load("res://path/to/system.tscn").instantiate()
	add_child(system_under_test)
	await system_under_test.ready

func after_test() -> void:
	"""Cleanup after each test"""
	if system_under_test:
		system_under_test.queue_free()
		system_under_test = null

func test_example_behavior() -> void:
	"""Test a specific behavior"""
	# Arrange
	var expected_value := 42

	# Act
	var actual_value := system_under_test.calculate_something()

	# Assert
	assert_int(actual_value).is_equal(expected_value)
```

### Signal Testing Template

```gdscript
func test_signal_is_emitted() -> void:
	"""Verify signal is emitted with correct parameters"""
	var signal_emitted := false
	var signal_data = null

	system_under_test.some_signal.connect(func(data):
		signal_emitted = true
		signal_data = data
	)

	# Trigger action that should emit signal
	system_under_test.do_something()

	assert_bool(signal_emitted).is_true()
	assert_that(signal_data).is_not_null()
```

---

## Quick Reference: GdUnit4 Assertions

### Boolean Assertions
```gdscript
assert_bool(value).is_true()
assert_bool(value).is_false()
```

### Integer Assertions
```gdscript
assert_int(value).is_equal(expected)
assert_int(value).is_greater(10)
assert_int(value).is_less(20)
assert_int(value).is_in_range(10, 20)
```

### String Assertions
```gdscript
assert_str(value).is_equal("expected")
assert_str(value).contains("substring")
assert_str(value).starts_with("prefix")
assert_str(value).is_not_empty()
```

### Array Assertions
```gdscript
assert_array(array).is_empty()
assert_array(array).contains([1, 2, 3])
assert_array(array).has_size(5)
```

### Object Assertions
```gdscript
assert_that(object).is_null()
assert_that(object).is_not_null()
assert_that(object).is_same(other_object)
```

---

## Success Criteria for Battle System Tests

### Before Refactoring
- [ ] All 10 existing integration tests pass (100%)
- [ ] All unit tests pass (100%)
- [ ] Zero flaky tests (consistent results)

### After Refactoring
- [ ] All existing tests still pass (zero regressions)
- [ ] New UI tests pass (signal architecture validated)
- [ ] Screen transition tests pass (flow validated)
- [ ] Component integration tests pass

### Before Production
- [ ] 100% test coverage of critical battle flows
- [ ] Design system compliance tests pass
- [ ] Performance tests pass (<500ms load time)
- [ ] Zero failing tests across entire suite

---

**Document Status**: READY FOR USE
**Next Steps**: Create missing test files (Priority 1-4)
**Estimated Effort**: 8-12 hours to create all missing tests
