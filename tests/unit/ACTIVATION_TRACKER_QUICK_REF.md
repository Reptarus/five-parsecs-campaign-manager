# Activation Tracker Tests - Quick Reference

**Files Created**: 2025-12-15
**Status**: Ready for component implementation
**Test Runner**: gdUnit4 v6.0.1

---

## Files Created

1. **tests/unit/test_activation_tracker.gd** (409 lines)
   - 12 comprehensive tests
   - Mock data helpers
   - Full component API specifications in comments

2. **tests/unit/ACTIVATION_TRACKER_TEST_SUMMARY.md**
   - Test coverage matrix
   - Component specifications
   - Implementation checklist
   - Success criteria

3. **tests/unit/run_activation_tracker_tests.ps1**
   - PowerShell test runner script
   - Pre-configured paths

---

## Quick Start

### Run Tests
```powershell
cd tests/unit
.\run_activation_tracker_tests.ps1
```

### Implement Components Order
1. **UnitActivationCard.gd** - Create activation card component
2. **ActivationTrackerPanel.gd** - Create tracker panel
3. **Uncomment tests** - Phase by phase (see test summary)
4. **Run tests** - Validate each phase
5. **Integrate** - Connect to BattleRoundTracker signals

---

## Test Categories

### Unit Tests (9)
- Card activation toggle
- Health bar visualization
- Status effects display
- Stunned state handling
- Deceased state handling
- Round reset logic
- Team separation
- Dynamic unit add/remove

### Integration Tests (3)
- Signal propagation
- Multi-unit activation
- State synchronization

---

## Expected API

### UnitActivationCard
```gdscript
signal activation_toggled(unit_id: String, is_activated: bool)

func set_unit_data(unit: Dictionary) -> void
func toggle_activation() -> void
func is_activated() -> bool
func update_health(new_health: int) -> void
```

### ActivationTrackerPanel
```gdscript
signal round_reset()
signal unit_added(unit_id: String)
signal unit_removed(unit_id: String)

func set_units(units: Array[Dictionary]) -> void
func add_unit(unit: Dictionary) -> void
func remove_unit(unit_id: String) -> void
func start_new_round() -> void
```

---

## Mock Data Examples

```gdscript
# Standard crew member
var crew = _create_mock_unit("crew_001", "Rex", 10, 10, true)

# Stunned unit
var stunned = _create_stunned_unit("crew_002", "Vex")

# Deceased unit
var dead = _create_dead_unit("crew_003", "Kass")
```

---

## Success Metrics

- ✅ 12/12 tests passing (100%)
- ✅ No test runner crashes
- ✅ All signals emit correctly
- ✅ Visual states match specs
- ✅ Zero memory leaks on add/remove

---

## Integration Points

**Signal Flow**:
```
BattleRoundTracker.round_changed
  → ActivationTrackerPanel.start_new_round()
  → UnitActivationCard.reset_activation()
```

**Related Components**:
- CharacterStatusCard.gd (similar pattern)
- BattleRoundHUD.gd (UI integration)
- BattleRoundTracker.gd (round signals)

---

## Constraints

- Max 13 tests per file (stability limit)
- No headless mode (crashes)
- Plain helpers only (no Node inheritance)
- Follow Five Parsecs rules (per-unit activation)

---

## Next Steps After Implementation

1. Test with real battle data
2. Performance benchmark (60fps with 20+ units)
3. Mobile touch target validation (48px minimum)
4. Add to integration test suite
5. Document in UI design system
