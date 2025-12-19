# Activation Tracker Test Suite - Implementation Guide

**Test File**: `tests/unit/test_activation_tracker.gd`
**Status**: Tests created, awaiting component implementation
**Test Count**: 13 tests (at runner stability limit)

## Test Coverage Matrix

| Test ID | Test Name | Requirement | Status | Component |
|---------|-----------|-------------|--------|-----------|
| T01 | `test_card_activation_toggle` | Tapping toggles activation | PENDING | UnitActivationCard |
| T02 | `test_health_bar_color_updates` | Health updates bar color | PENDING | UnitActivationCard |
| T03 | `test_status_effects_show_as_badges` | Status effects visible | PENDING | UnitActivationCard |
| T04 | `test_stunned_units_show_cannot_act_state` | Stunned state display | PENDING | UnitActivationCard |
| T05 | `test_dead_units_show_deceased_state` | Casualty state display | PENDING | UnitActivationCard |
| T06 | `test_round_reset_clears_all_activations` | Round reset logic | PENDING | ActivationTrackerPanel |
| T07 | `test_crew_and_enemies_in_separate_sections` | Team separation | PENDING | ActivationTrackerPanel |
| T08 | `test_unit_addition_updates_tracker` | Dynamic unit add | PENDING | ActivationTrackerPanel |
| T09 | `test_unit_removal_updates_tracker` | Dynamic unit remove | PENDING | ActivationTrackerPanel |
| T10 | `test_activation_signal_propagates_to_panel` | Signal integration | PENDING | Both |
| T11 | `test_multiple_units_can_be_activated_same_round` | Multi-activation | PENDING | Both |
| T12 | `test_health_update_reflects_across_all_instances` | State sync | PENDING | Both |
| T13 | (Reserved) | Future test | - | - |

**Note**: Test count at 12/13 to stay within stability limit. Reserve 1 slot for future edge cases.

---

## Component Specifications (Derived from Tests)

### UnitActivationCard.gd

**Expected Public API**:
```gdscript
class_name UnitActivationCard
extends PanelContainer

# Signals
signal activation_toggled(unit_id: String, is_activated: bool)

# Public Methods
func set_unit_data(unit: Dictionary) -> void
func toggle_activation() -> void
func is_activated() -> bool
func update_health(new_health: int) -> void
func get_health_bar_color() -> Color
func get_status_badges() -> Array[String]
func can_activate() -> bool
func is_deceased() -> bool
func get_status_text() -> String
func get_current_health() -> int
```

**Expected Properties**:
- `unit_id: String` - Unique identifier
- `unit_name: String` - Display name
- `current_health: int` - Current HP
- `max_health: int` - Maximum HP
- `activated_this_round: bool` - Activation state
- `team: String` - "crew" or "enemy"
- `status_effects: Array[String]` - Active effects

**Visual States**:
1. **Ready**: Full opacity, activation button enabled
2. **Activated**: Dimmed/grayed, activation button toggled
3. **Stunned**: Overlay/border, activation disabled, "Cannot Act" text
4. **Deceased**: Semi-transparent, grayed health bar (black), "CASUALTY" text

**Health Bar Colors** (based on CharacterStatusCard pattern):
- **100%-60%**: Green (`Color.GREEN`)
- **60%-30%**: Yellow (`Color.YELLOW`)
- **30%-1%**: Red (`Color.RED`)
- **0%**: Black (`Color.BLACK`)

---

### ActivationTrackerPanel.gd

**Expected Public API**:
```gdscript
class_name ActivationTrackerPanel
extends PanelContainer

# Signals
signal round_reset()
signal unit_added(unit_id: String)
signal unit_removed(unit_id: String)

# Public Methods
func set_units(units: Array[Dictionary]) -> void
func add_unit(unit: Dictionary) -> void
func remove_unit(unit_id: String) -> void
func start_new_round() -> void
func update_unit_health(unit_id: String, new_health: int) -> void
func get_card_by_id(unit_id: String) -> UnitActivationCard
func get_crew_section() -> VBoxContainer
func get_enemy_section() -> VBoxContainer
func get_all_cards() -> Array[UnitActivationCard]
func get_total_unit_count() -> int
```

**Visual Structure**:
```
ActivationTrackerPanel
├── CrewSection (VBoxContainer)
│   ├── SectionLabel ("Your Crew")
│   └── CrewCards (Container)
│       ├── UnitActivationCard (crew)
│       └── UnitActivationCard (crew)
├── Separator (HSeparator)
└── EnemySection (VBoxContainer)
    ├── SectionLabel ("Enemies")
    └── EnemyCards (Container)
        ├── UnitActivationCard (enemy)
        └── UnitActivationCard (enemy)
```

---

## Test Implementation Checklist

When implementing components, uncomment tests in this order:

### Phase 1: Basic UnitActivationCard
- [ ] T01: `test_card_activation_toggle` - Core toggle logic
- [ ] T02: `test_health_bar_color_updates` - Visual feedback
- [ ] T03: `test_status_effects_show_as_badges` - Status display

### Phase 2: Special States
- [ ] T04: `test_stunned_units_show_cannot_act_state` - Stunned logic
- [ ] T05: `test_dead_units_show_deceased_state` - Casualty handling

### Phase 3: ActivationTrackerPanel
- [ ] T06: `test_round_reset_clears_all_activations` - Round management
- [ ] T07: `test_crew_and_enemies_in_separate_sections` - Layout
- [ ] T08: `test_unit_addition_updates_tracker` - Dynamic add
- [ ] T09: `test_unit_removal_updates_tracker` - Dynamic remove

### Phase 4: Integration
- [ ] T10: `test_activation_signal_propagates_to_panel` - Signal flow
- [ ] T11: `test_multiple_units_can_be_activated_same_round` - Multi-activation
- [ ] T12: `test_health_update_reflects_across_all_instances` - State sync

---

## Running Tests

**After components implemented, run via PowerShell**:
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_activation_tracker.gd `
  --quit-after 60
```

**Expected Output (when all implemented)**:
```
TestActivationTracker
  ✓ test_card_activation_toggle
  ✓ test_health_bar_color_updates
  ✓ test_status_effects_show_as_badges
  ✓ test_stunned_units_show_cannot_act_state
  ✓ test_dead_units_show_deceased_state
  ✓ test_round_reset_clears_all_activations
  ✓ test_crew_and_enemies_in_separate_sections
  ✓ test_unit_addition_updates_tracker
  ✓ test_unit_removal_updates_tracker
  ✓ test_activation_signal_propagates_to_panel
  ✓ test_multiple_units_can_be_activated_same_round
  ✓ test_health_update_reflects_across_all_instances

Tests: 12 passed, 0 failed, 0 skipped
```

---

## Mock Data Helpers

The test suite provides reusable mock data creators:

```gdscript
# Create standard unit
_create_mock_unit(
    id: "crew_001",
    name: "Captain Rex",
    health: 10,
    max_health: 10,
    is_crew: true,
    activated: false,
    status_effects: []
)

# Create stunned unit
_create_stunned_unit("crew_001", "Rex")

# Create deceased unit
_create_dead_unit("crew_001", "Rex")
```

---

## Known Constraints

**From TESTING_GUIDE.md**:
- ⚠️ Max 13 tests per file (runner crashes beyond this)
- ✅ Currently at 12/13 (1 reserved for future)
- ⚠️ Never use `--headless` flag (signal 11 crash)
- ✅ Always use UI mode via PowerShell

**Design Constraints**:
- No Node inheritance in test helpers (plain classes only)
- Follow Five Parsecs tabletop rules (activation per unit, not exclusive)
- Signal-based architecture (call-down-signal-up pattern)

---

## Integration with Existing Systems

**Related Components**:
- `CharacterStatusCard.gd` - Similar health/status display pattern
- `BattleRoundHUD.gd` - Round tracking integration point
- `BattleRoundTracker.gd` - Round reset signal source

**Signal Flow**:
```
BattleRoundTracker.round_changed
  ↓
ActivationTrackerPanel.start_new_round()
  ↓
UnitActivationCard.reset_activation() (for each card)
```

---

## Success Criteria

**Test Suite Passes When**:
- ✅ All 12 tests pass (100% pass rate)
- ✅ Zero failing tests
- ✅ Test run completes without crashes
- ✅ All signals emit with correct parameters
- ✅ Visual states match specifications

**Component Quality Gates**:
- ✅ Activation toggle works reliably
- ✅ Health bar colors match state
- ✅ Stunned/deceased states visually distinct
- ✅ Round reset clears all activations
- ✅ Crew/enemy sections properly separated
- ✅ Dynamic unit add/remove works without memory leaks
