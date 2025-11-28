# BattleCompanionUI Refactoring Strategy
**Target**: 1,232 lines → ~250 lines (orchestrator)
**Extracted Components**: 4 phase panels (~150 lines each)
**Estimated Effort**: 6-8 hours
**Risk Level**: Medium (requires careful signal preservation)

---

## Current Structure Analysis

### File Breakdown by Section

```gdscript
BattleCompanionUI.gd (1,232 lines total)

├── Lines 1-88:   Dependencies & Constants (88 lines)
│                 - 20 preload statements
│                 - 6 signal definitions
│                 - @onready node references
│                 - State variables
│
├── Lines 90-226: Initialization & Setup (136 lines)
│                 - _ready(), _initialize_core_systems()
│                 - _setup_responsive_design()
│                 - _connect_ui_signals()
│                 - _adjust_touch_targets()
│
├── Lines 227-399: Terrain Phase UI (172 lines) → EXTRACT
│                 - _setup_terrain_phase_ui()
│                 - _on_generate_terrain_pressed()
│                 - _display_terrain_suggestions()
│                 - _create_terrain_suggestion_item()
│
├── Lines 400-499: Deployment Phase UI (99 lines) → EXTRACT
│                 - _setup_deployment_phase_ui()
│                 - _on_start_tracking_pressed()
│                 - _show_deployment_popup()
│
├── Lines 500-699: Tracking Phase UI (199 lines) → EXTRACT
│                 - _setup_tracking_phase_ui()
│                 - _on_track_round_pressed()
│                 - _update_battle_tracking()
│                 - _display_tracking_suggestions()
│
├── Lines 700-799: Results Phase UI (99 lines) → EXTRACT
│                 - _setup_results_phase_ui()
│                 - _display_battle_results()
│                 - _on_complete_battle_pressed()
│
├── Lines 800-899: Navigation & UI Management (99 lines) → KEEP
│                 - _show_phase_ui()
│                 - _update_navigation_ui()
│                 - _advance_to_next_phase()
│
└── Lines 900-1232: Event Handlers & Utilities (332 lines) → REFACTOR
                  - _on_phase_changed()
                  - _on_battlefield_ready()
                  - _lock_ui() / _unlock_ui()
                  - Battle manager integration
```

---

## Extraction Plan

### Phase 1: Create TerrainPhasePanel.gd (150 lines)

**Extract**: Lines 227-399 + relevant @onready references

**New File Structure**:
```gdscript
class_name BattleTerrainPhasePanel
extends PanelContainer

## Terrain Phase Panel for Battle Companion
## Handles terrain generation, suggestions, and confirmation

const BaseCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const SetupSuggestions = preload("res://src/core/battle/SetupSuggestions.gd")

# Signals (UP to orchestrator)
signal terrain_generated(suggestions: SetupSuggestions)
signal terrain_confirmed(data: Dictionary)
signal terrain_import_requested()
signal terrain_export_requested(data: Dictionary)

# UI References
@onready var suggestions_container: VBoxContainer = %SuggestionsList
@onready var generate_button: Button = %GenerateButton
@onready var confirm_button: Button = %ConfirmButton
@onready var import_button: Button = %ImportButton
@onready var export_button: Button = %ExportButton

# State
var current_suggestions: SetupSuggestions = null
var terrain_confirmed: bool = false

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_apply_design_system()

func _setup_ui() -> void:
	# Extract lines 291-299 from BattleCompanionUI.gd
	...

func _on_generate_pressed() -> void:
	# Extract lines 313-331 from BattleCompanionUI.gd
	...

func _display_suggestions(suggestions: SetupSuggestions) -> void:
	# Extract lines 407-425 from BattleCompanionUI.gd
	...

func _create_suggestion_item(feature) -> Control:
	# Extract lines 426-462 from BattleCompanionUI.gd
	...

func _apply_design_system() -> void:
	# NEW: Apply BaseCampaignPanel styling
	var style := StyleBoxFlat.new()
	style.bg_color = BaseCampaignPanel.COLOR_ELEVATED
	style.set_border_width_all(1)
	style.border_color = BaseCampaignPanel.COLOR_BORDER
	style.set_corner_radius_all(8)
	style.set_content_margin_all(BaseCampaignPanel.SPACING_MD)
	add_theme_stylebox_override("panel", style)

func get_terrain_data() -> Dictionary:
	return {
		"terrain_confirmed": terrain_confirmed,
		"setup_time": Time.get_unix_time_from_system(),
		"suggestions": current_suggestions
	}
```

**Integration in BattleCompanionUI**:
```gdscript
# BattleCompanionUI.gd (orchestrator)
var terrain_panel: BattleTerrainPhasePanel

func _initialize_phase_ui() -> void:
	terrain_panel = TerrainPhasePanelScene.instantiate()
	setup_panel.add_child(terrain_panel)

	# Connect signals (panel signals UP to orchestrator)
	terrain_panel.terrain_generated.connect(_on_terrain_generated)
	terrain_panel.terrain_confirmed.connect(_on_terrain_confirmed)
```

---

### Phase 2: Create DeploymentPhasePanel.gd (150 lines)

**Extract**: Lines 400-499 + deployment-specific UI

**New File Structure**:
```gdscript
class_name BattleDeploymentPhasePanel
extends PanelContainer

# Signals (UP to orchestrator)
signal deployment_ready(crew: Array, enemies: Array)
signal deployment_guide_requested()

# UI References
@onready var crew_list: VBoxContainer = %CrewList
@onready var enemy_list: VBoxContainer = %EnemyList
@onready var start_tracking_button: Button = %StartTrackingButton
@onready var deployment_guide_button: Button = %DeploymentGuideButton

# State
var crew_members: Array = []
var enemy_units: Array = []
var deployment_confirmed: bool = false

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_apply_design_system()

func set_units(crew: Array, enemies: Array) -> void:
	crew_members = crew
	enemy_units = enemies
	_update_unit_display()

func _on_start_tracking_pressed() -> void:
	deployment_ready.emit(crew_members, enemy_units)

func _update_unit_display() -> void:
	# Display crew and enemy units with deployment zones
	...
```

---

### Phase 3: Create TrackingPhasePanel.gd (200 lines)

**Extract**: Lines 500-699 + tracking UI components

**New File Structure**:
```gdscript
class_name BattleTrackingPhasePanel
extends PanelContainer

# Signals (UP to orchestrator)
signal round_tracked(round_data: Dictionary)
signal battle_action_requested(action: String, data: Dictionary)

# Component References
var initiative_calculator: Control
var reaction_dice_panel: Control
var morale_tracker: Control
var battle_journal: Control

# State
var current_round: int = 0
var tracking_data: Dictionary = {}

func _ready() -> void:
	_setup_components()
	_connect_signals()
	_apply_design_system()

func _setup_components() -> void:
	# Instantiate battle assistance components
	initiative_calculator = InitiativeCalculatorScene.instantiate()
	reaction_dice_panel = ReactionDicePanelScene.instantiate()
	morale_tracker = MoralePanicTrackerScene.instantiate()
	battle_journal = BattleJournalScene.instantiate()

	# Add to panel
	...

func track_round() -> void:
	current_round += 1
	_update_tracking_display()
	round_tracked.emit(_get_round_data())

func _get_round_data() -> Dictionary:
	return {
		"round": current_round,
		"actions": [],
		"casualties": [],
		"morale_checks": []
	}
```

---

### Phase 4: Create ResultsPhasePanel.gd (150 lines)

**Extract**: Lines 700-799 + results display

**New File Structure**:
```gdscript
class_name BattleResultsPhasePanel
extends PanelContainer

# Signals (UP to orchestrator)
signal battle_completed(results: Dictionary)
signal results_exported(file_path: String)

# UI References
@onready var victory_label: Label = %VictoryLabel
@onready var casualties_list: VBoxContainer = %CasualtiesList
@onready var rewards_list: VBoxContainer = %RewardsList
@onready var complete_button: Button = %CompleteButton
@onready var export_button: Button = %ExportButton

# State
var battle_results: Dictionary = {}

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_apply_design_system()

func display_results(results: Dictionary) -> void:
	battle_results = results
	_update_results_display()

func _update_results_display() -> void:
	var victory: bool = battle_results.get("victory", false)
	victory_label.text = "VICTORY" if victory else "DEFEAT"
	victory_label.add_theme_color_override("font_color",
		BaseCampaignPanel.COLOR_SUCCESS if victory else BaseCampaignPanel.COLOR_DANGER
	)

	_display_casualties()
	_display_rewards()

func _on_export_pressed() -> void:
	var journal_text := _format_battle_journal()
	var file_path := _save_journal_to_file(journal_text)
	results_exported.emit(file_path)
```

---

## Refactored BattleCompanionUI.gd (Orchestrator - ~250 lines)

```gdscript
class_name FPCM_BattleCompanionUI
extends Control

## Battlefield Companion UI - Orchestrator
## Manages phase-based battle workflow using modular panels

# Dependencies
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const FPCM_BattleManager = preload("res://src/core/battle/FPCM_BattleManager.gd")

# Phase Panel Scenes
const TerrainPanelScene = preload("res://src/ui/screens/battle/panels/TerrainPhasePanel.tscn")
const DeploymentPanelScene = preload("res://src/ui/screens/battle/panels/DeploymentPhasePanel.tscn")
const TrackingPanelScene = preload("res://src/ui/screens/battle/panels/TrackingPhasePanel.tscn")
const ResultsPanelScene = preload("res://src/ui/screens/battle/panels/ResultsPhasePanel.tscn")

# Signals
signal phase_completed(phase: BattlefieldTypes.BattlePhase)
signal battle_completed(results: Dictionary)
signal ui_error_occurred(error: String, context: Dictionary)

# UI Containers
@onready var phase_container: Control = %PhaseContainer
@onready var status_bar: Control = %PersistentStatusBar
@onready var phase_indicator: Label = %PhaseIndicator
@onready var phase_progress: ProgressBar = %PhaseProgress

# Phase Panels
var terrain_panel: BattleTerrainPhasePanel
var deployment_panel: BattleDeploymentPhasePanel
var tracking_panel: BattleTrackingPhasePanel
var results_panel: BattleResultsPhasePanel

# State
var current_phase: BattlefieldTypes.BattlePhase = BattlefieldTypes.BattlePhase.SETUP_TERRAIN
var battle_manager: FPCM_BattleManager = null

func _ready() -> void:
	_initialize_battle_manager()
	_initialize_phase_panels()
	_connect_panel_signals()
	_show_phase(BattlefieldTypes.BattlePhase.SETUP_TERRAIN)

func _initialize_phase_panels() -> void:
	"""Instantiate and setup all phase panels"""
	terrain_panel = TerrainPanelScene.instantiate()
	deployment_panel = DeploymentPanelScene.instantiate()
	tracking_panel = TrackingPanelScene.instantiate()
	results_panel = ResultsPanelScene.instantiate()

	phase_container.add_child(terrain_panel)
	phase_container.add_child(deployment_panel)
	phase_container.add_child(tracking_panel)
	phase_container.add_child(results_panel)

	# Hide all initially
	terrain_panel.hide()
	deployment_panel.hide()
	tracking_panel.hide()
	results_panel.hide()

func _connect_panel_signals() -> void:
	"""Connect phase panel signals to orchestrator"""
	# Terrain Phase
	terrain_panel.terrain_confirmed.connect(_on_terrain_confirmed)

	# Deployment Phase
	deployment_panel.deployment_ready.connect(_on_deployment_ready)

	# Tracking Phase
	tracking_panel.round_tracked.connect(_on_round_tracked)
	tracking_panel.battle_action_requested.connect(_on_battle_action)

	# Results Phase
	results_panel.battle_completed.connect(_on_battle_completed)

func _show_phase(phase: BattlefieldTypes.BattlePhase) -> void:
	"""Show the appropriate phase panel"""
	current_phase = phase

	# Hide all panels
	terrain_panel.hide()
	deployment_panel.hide()
	tracking_panel.hide()
	results_panel.hide()

	# Show current phase panel
	match phase:
		BattlefieldTypes.BattlePhase.SETUP_TERRAIN:
			terrain_panel.show()
			phase_indicator.text = "Terrain Setup"
		BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT:
			deployment_panel.show()
			phase_indicator.text = "Deployment"
		BattlefieldTypes.BattlePhase.TRACK_BATTLE:
			tracking_panel.show()
			phase_indicator.text = "Battle Tracking"
		BattlefieldTypes.BattlePhase.PREPARE_RESULTS:
			results_panel.show()
			phase_indicator.text = "Battle Results"

	_update_phase_progress()

func _update_phase_progress() -> void:
	"""Update progress bar based on current phase"""
	var progress_values := {
		BattlefieldTypes.BattlePhase.SETUP_TERRAIN: 25,
		BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT: 50,
		BattlefieldTypes.BattlePhase.TRACK_BATTLE: 75,
		BattlefieldTypes.BattlePhase.PREPARE_RESULTS: 100
	}
	phase_progress.value = progress_values.get(current_phase, 0)

func _advance_phase() -> void:
	"""Advance to next phase in workflow"""
	var next_phase_map := {
		BattlefieldTypes.BattlePhase.SETUP_TERRAIN: BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT,
		BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT: BattlefieldTypes.BattlePhase.TRACK_BATTLE,
		BattlefieldTypes.BattlePhase.TRACK_BATTLE: BattlefieldTypes.BattlePhase.PREPARE_RESULTS
	}

	var next_phase = next_phase_map.get(current_phase)
	if next_phase:
		phase_completed.emit(current_phase)
		_show_phase(next_phase)

# Phase Event Handlers
func _on_terrain_confirmed(terrain_data: Dictionary) -> void:
	"""Handle terrain confirmation from TerrainPhasePanel"""
	# Pass terrain data to deployment phase
	deployment_panel.set_terrain_data(terrain_data)
	_advance_phase()

func _on_deployment_ready(crew: Array, enemies: Array) -> void:
	"""Handle deployment confirmation from DeploymentPhasePanel"""
	# Setup tracking phase with deployed units
	tracking_panel.set_units(crew, enemies)
	_advance_phase()

func _on_round_tracked(round_data: Dictionary) -> void:
	"""Handle round completion from TrackingPhasePanel"""
	# Update status bar with round info
	if status_bar:
		status_bar.update_round(round_data["round"])

func _on_battle_action(action: String, data: Dictionary) -> void:
	"""Handle battle actions from TrackingPhasePanel"""
	# Forward to battle manager or other systems
	if battle_manager:
		battle_manager.handle_action(action, data)

func _on_battle_completed(results: Dictionary) -> void:
	"""Handle battle completion from ResultsPhasePanel"""
	battle_completed.emit(results)

func setup_battle(mission: Resource, crew: Array, enemies: Array) -> void:
	"""Initialize battle companion for new battle"""
	if battle_manager:
		battle_manager.initialize_battle(mission, crew, enemies)

	# Setup deployment panel with units
	deployment_panel.set_units(crew, enemies)

func _exit_tree() -> void:
	"""Cleanup on removal"""
	if battle_manager:
		battle_manager.unregister_ui_component("BattleCompanionUI")
```

---

## Signal Architecture Diagram

```
BattleCompanionUI (Orchestrator)
       │
       ├─── Terrain Panel
       │    ├─ terrain_confirmed ──→ _on_terrain_confirmed()
       │    ├─ terrain_generated ──→ (optional logging)
       │    └─ terrain_import_requested ──→ (file dialog)
       │
       ├─── Deployment Panel
       │    ├─ deployment_ready ──→ _on_deployment_ready()
       │    └─ deployment_guide_requested ──→ (show guide)
       │
       ├─── Tracking Panel
       │    ├─ round_tracked ──→ _on_round_tracked()
       │    └─ battle_action_requested ──→ _on_battle_action()
       │
       └─── Results Panel
            ├─ battle_completed ──→ _on_battle_completed()
            └─ results_exported ──→ (show success toast)

EXTERNAL SIGNALS (from orchestrator):
├─ phase_completed ──→ BattleManager / CampaignPhaseManager
├─ battle_completed ──→ PostBattlePhase
└─ ui_error_occurred ──→ ErrorHandler
```

---

## Testing Strategy

### Before Refactoring: Create Safety Net

**Create**: `tests/integration/test_battle_companion_ui_signals.gd`

```gdscript
extends GdUnitTestSuite

var battle_ui: FPCM_BattleCompanionUI

func before_test() -> void:
	battle_ui = load("res://src/ui/screens/battle/BattleCompanionUI.tscn").instantiate()
	add_child(battle_ui)

func after_test() -> void:
	battle_ui.queue_free()

func test_terrain_confirmation_advances_phase() -> void:
	# Verify terrain panel signals trigger phase advancement
	var phase_changed := false
	battle_ui.phase_completed.connect(func(_p): phase_changed = true)

	# Simulate terrain confirmation
	battle_ui.terrain_panel.terrain_confirmed.emit({})

	assert_bool(phase_changed).is_true()
	assert_that(battle_ui.current_phase).is_equal(BattlefieldTypes.BattlePhase.SETUP_DEPLOYMENT)

func test_signal_chain_integrity() -> void:
	# Ensure all phase panels properly emit signals
	var signals_received := []

	battle_ui.phase_completed.connect(func(p): signals_received.append(p))

	# Simulate full battle flow
	battle_ui.terrain_panel.terrain_confirmed.emit({})
	battle_ui.deployment_panel.deployment_ready.emit([], [])
	battle_ui.tracking_panel.round_tracked.emit({"round": 1})

	assert_int(signals_received.size()).is_equal(3)
```

### During Refactoring: Incremental Testing

1. **Extract TerrainPhasePanel** → Run tests → Verify signals work
2. **Extract DeploymentPhasePanel** → Run tests → Verify phase transitions
3. **Extract TrackingPhasePanel** → Run tests → Verify battle flow
4. **Extract ResultsPhasePanel** → Run tests → Verify completion

### After Refactoring: Validation

- [ ] All existing tests pass (zero regressions)
- [ ] New panel tests pass (signal integrity)
- [ ] Visual QA (no UI changes visible to user)
- [ ] Performance check (no FPS drop)

---

## Migration Checklist

### Pre-Refactoring
- [ ] Create backup: `BattleCompanionUI.gd.backup`
- [ ] Write integration tests for current functionality
- [ ] Document all signal connections
- [ ] Take screenshots of all 4 phases

### Phase 1: Terrain Panel
- [ ] Create `src/ui/screens/battle/panels/TerrainPhasePanel.gd`
- [ ] Create `src/ui/screens/battle/panels/TerrainPhasePanel.tscn`
- [ ] Extract lines 227-399 from BattleCompanionUI.gd
- [ ] Apply design system styling
- [ ] Test terrain generation flow
- [ ] Verify signal propagation

### Phase 2: Deployment Panel
- [ ] Create `DeploymentPhasePanel.gd/.tscn`
- [ ] Extract lines 400-499
- [ ] Apply design system styling
- [ ] Test deployment setup
- [ ] Verify phase transition

### Phase 3: Tracking Panel
- [ ] Create `TrackingPhasePanel.gd/.tscn`
- [ ] Extract lines 500-699
- [ ] Integrate battle assistance components
- [ ] Apply design system styling
- [ ] Test round tracking
- [ ] Verify component communication

### Phase 4: Results Panel
- [ ] Create `ResultsPhasePanel.gd/.tscn`
- [ ] Extract lines 700-799
- [ ] Add journal export functionality
- [ ] Apply design system styling
- [ ] Test results display
- [ ] Verify battle completion

### Phase 5: Orchestrator Cleanup
- [ ] Remove extracted code from BattleCompanionUI.gd
- [ ] Add panel instantiation logic
- [ ] Connect all panel signals
- [ ] Update navigation logic
- [ ] Verify orchestrator is ~250 lines

### Post-Refactoring
- [ ] Run full test suite
- [ ] Visual QA all 4 phases
- [ ] Performance profiling
- [ ] Update documentation
- [ ] Delete `.backup` file (if all tests pass)

---

## Rollback Plan

**If tests fail or regressions occur**:

1. **Immediate**: `git checkout -- src/ui/screens/battle/BattleCompanionUI.gd`
2. **Restore backup**: `cp BattleCompanionUI.gd.backup BattleCompanionUI.gd`
3. **Analyze failure**: Review test output, check signal connections
4. **Fix issue**: Address specific failing test
5. **Retry**: Resume refactoring from last successful phase

**Success Criteria for Each Phase**:
- All tests pass (100%)
- Zero visual regressions
- Zero FPS drops
- Signal chain intact

---

## Estimated Timeline

| Task | Estimated Time | Critical Path |
|------|---------------|---------------|
| Pre-refactoring setup (backup, tests, docs) | 1 hour | Yes |
| Extract TerrainPhasePanel | 1.5 hours | Yes |
| Extract DeploymentPhasePanel | 1 hour | Yes |
| Extract TrackingPhasePanel | 2 hours | Yes |
| Extract ResultsPhasePanel | 1 hour | Yes |
| Orchestrator cleanup | 1 hour | Yes |
| Testing & QA | 1.5 hours | Yes |
| **Total** | **9 hours** | - |

**Note**: Add 20% buffer for unexpected issues → **~11 hours total**

---

## Success Metrics

### Quantitative
- [ ] BattleCompanionUI reduced from 1,232 → ~250 lines (80% reduction)
- [ ] 4 new panel files created (~150 lines each)
- [ ] 100% test pass rate (no regressions)
- [ ] Zero visual changes (user-facing)
- [ ] Zero performance degradation

### Qualitative
- [ ] Code maintainability improved (smaller files easier to navigate)
- [ ] Phase panels reusable (can be used independently)
- [ ] Design system adoption increased (17 → 21 files compliant)
- [ ] Framework Bible compliance achieved (all files ≤ 250 lines)

---

**Document Status**: READY FOR IMPLEMENTATION
**Next Step**: Create backup and integration tests
**Risk Level**: Medium (requires careful signal preservation)
**Approval Required**: Yes (team review recommended)
