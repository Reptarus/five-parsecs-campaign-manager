# Running Campaign Wizard Integration Tests

## Quick Start

### PowerShell Command (UI Mode - Required)
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_campaign_wizard_flow.gd `
  --quit-after 60
```

## Test File Details

**File**: `test_campaign_wizard_flow.gd`
**Total Tests**: 13
**Test Suites**: 8
**Lines**: 433

## Test Coverage

### Suite 1: Panel Navigation
- ✅ test_wizard_panel_navigation
- ✅ test_panel_navigation_validates_before_advancing

### Suite 2: Data Flow Between Panels
- ✅ test_config_to_captain_data_flow
- ✅ test_captain_data_persistence

### Suite 3: Crew Management Flow
- ✅ test_crew_creation_persistence

### Suite 4: Equipment Assignment
- ✅ test_equipment_assignment_flow

### Suite 5: FinalPanel Integration
- ✅ test_final_panel_receives_all_data
- ✅ test_final_panel_displays_without_errors

### Suite 6: End-to-End Campaign Creation
- ✅ test_complete_wizard_creates_campaign
- ✅ test_campaign_data_validation_before_creation

### Suite 7: Data Type Safety
- ✅ test_character_dictionary_conversion
- ✅ test_mixed_array_type_handling

### Suite 8: Panel State Synchronization
- ✅ test_panel_sync_with_coordinator_state

## Expected Results

**Pass Rate**: 100% (13/13 tests)
**Execution Time**: ~5-10 seconds
**Memory Usage**: <100MB

## Critical Constraints

⚠️ **NEVER use --headless flag**: Causes signal 11 crash after 8-18 tests
✅ **ALWAYS use UI mode**: Tests interact with UI components
✅ **Test limit**: 13 tests (within safe limit of max 13 per file)

## Troubleshooting

### Test Failures
If tests fail, check:
1. CampaignCreationUI.gd has `get_coordinator()` method
2. CampaignCreationCoordinator.gd has proper state methods
3. FinalPanel.gd has `update_campaign_data()` method
4. All panel classes inherit from FiveParsecsCampaignPanel

### Signal 11 Crash
If you encounter signal 11:
- Verify UI mode is enabled (no --headless)
- Check test count doesn't exceed 13
- Ensure proper cleanup in `after_test()`

### Missing Methods
If you see "method not found" errors:
- Verify coordinator methods: `get_unified_campaign_state()`, `_character_to_dict()`
- Check panel methods: `update_captain_state()`, `update_crew_state()`

## Test Maintenance

### Adding New Tests
When adding tests to this file:
- Keep total under 13 tests (runner stability limit)
- Use `before_test()` / `after_test()` for setup/cleanup
- Always call `await get_tree().process_frame` after UI changes
- Use GdUnit4 fluent assertions

### Related Test Files
- `test_campaign_creation_data_flow.gd` - Data handoff validation
- `test_final_panel_ui_improvements.gd` - FinalPanel UI tests
- `test_campaign_workflow.gd` - Legacy workflow tests

## Success Criteria

All tests must pass for campaign wizard to be production-ready:
- ✅ Panel navigation works bidirectionally
- ✅ Data persists across panel switches
- ✅ FinalPanel displays complete campaign data
- ✅ Type conversions handle mixed Arrays
- ✅ End-to-end campaign creation completes

## Next Steps After Tests Pass

1. Manual QA: Test victory condition descriptions in live UI
2. Performance: Profile wizard flow on mobile device
3. UX: Validate touch targets on tablet screen
4. Documentation: Update TESTING_GUIDE.md with new test count

---

**File**: tests/integration/test_campaign_wizard_flow.gd
**Created**: 2025-11-28
**Status**: Ready to Run ✅
