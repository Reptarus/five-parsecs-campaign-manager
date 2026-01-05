# Navigation Test Plan - Phase Dead End Fixes
**Date Created**: 2025-12-15
**Sprint**: Navigation Integration - Phase Dead End Fixes
**Status**: Ready for Manual Testing

---

## Executive Summary

This document provides comprehensive QA verification for navigation fixes implemented across 7 files to eliminate phase dead ends in the Five Parsecs Campaign Manager.

### Changes Overview
- **Sprint 1**: Fixed phase dead ends (TravelPhaseUI, PostBattleSequence, WorldPhaseController)
- **Sprint 2**: Fixed broken handlers in CampaignDashboard and documented SceneRouter duplicates

### Files Modified (7 total)
1. `src/ui/screens/travel/TravelPhaseUI.gd` - Added return_to_dashboard signal
2. `src/ui/screens/postbattle/PostBattleSequence.gd` - Added navigation footer + signals
3. `src/ui/screens/postbattle/PostBattleSequence.tscn` - Added navigation buttons
4. `src/ui/screens/world/WorldPhaseController.gd` - Added navigation footer + signals
5. `src/ui/screens/world/WorldPhaseController.tscn` - Added navigation buttons
6. `src/ui/screens/campaign/CampaignDashboard.gd` - Fixed broken signal handlers
7. `src/ui/screens/SceneRouter.gd` - Documented duplicates & orphans

---

## Part 1: Code Verification Results

### 1.1 TravelPhaseUI.gd - Signal Declaration ✅

**Verification**: Lines 10-12
```gdscript
signal phase_completed()
signal travel_completed()
signal return_to_dashboard()  # ✅ ADDED
```

**Status**: ✅ **PASS** - Signal properly declared

---

### 1.2 TravelPhaseUI.gd - Handler Implementation ✅

**Verification**: Lines 402-409
```gdscript
func _on_back_button_pressed() -> void:
    """Handle back button - return to dashboard"""
    return_to_dashboard.emit()  # ✅ EMITS SIGNAL
    if SceneRouter and SceneRouter.has_method("navigate_to"):
        SceneRouter.navigate_to("campaign_dashboard")  # ✅ PRIMARY NAVIGATION
    else:
        get_tree().call_deferred("change_scene_to_file",
            "res://src/ui/screens/campaign/CampaignDashboard.tscn")  # ✅ FALLBACK
```

**Status**: ✅ **PASS** - Handler correctly emits signal and navigates

---

### 1.3 PostBattleSequence.gd - Signal Declaration ✅

**Verification**: Lines 17-20
```gdscript
signal post_battle_completed(results: Dictionary)
signal step_completed(step_index: int, results: Dictionary)
signal return_to_dashboard  # ✅ ADDED
signal sequence_completed  # ✅ ADDED
```

**Status**: ✅ **PASS** - Both signals properly declared

---

### 1.4 PostBattleSequence.gd - Navigation Footer Handlers ✅

**Verification**: Lines 928-942
```gdscript
func _on_back_pressed() -> void:
    """Handle back button press - return to Campaign Dashboard"""
    print("PostBattleSequence: Back pressed - returning to Campaign Dashboard")
    return_to_dashboard.emit()  # ✅ EMITS SIGNAL
    if has_node("/root/SceneRouter"):
        var scene_router = get_node("/root/SceneRouter")
        scene_router.navigate_to("campaign_dashboard")  # ✅ PRIMARY NAVIGATION
    else:
        get_tree().change_scene_to_file("res://src/ui/screens/campaign/CampaignDashboard.tscn")  # ✅ FALLBACK

func _on_next_turn_pressed() -> void:
    """Handle next turn button press - complete sequence and advance to next turn"""
    print("PostBattleSequence: Next turn pressed - completing post-battle sequence")
    sequence_completed.emit()  # ✅ EMITS SIGNAL
    _finish_post_battle()  # ✅ CALLS COMPLETION LOGIC
```

**Status**: ✅ **PASS** - Both handlers correctly implemented

---

### 1.5 PostBattleSequence.tscn - Button Connections ✅

**Verification**: Lines 162-181
```tscn
[node name="BackButton" type="Button" parent="MarginContainer/VBoxContainer/NavigationFooter"]
custom_minimum_size = Vector2(160, 48)
layout_mode = 2
text = "Back to Dashboard"

[node name="NextTurnButton" type="Button" parent="MarginContainer/VBoxContainer/NavigationFooter"]
custom_minimum_size = Vector2(200, 56)
layout_mode = 2
text = "Start Next Turn"

[connection signal="pressed" from="MarginContainer/VBoxContainer/NavigationFooter/BackButton"
    to="." method="_on_back_pressed"]  # ✅ CONNECTED
[connection signal="pressed" from="MarginContainer/VBoxContainer/NavigationFooter/NextTurnButton"
    to="." method="_on_next_turn_pressed"]  # ✅ CONNECTED
```

**Status**: ✅ **PASS** - Both buttons wired correctly

---

### 1.6 WorldPhaseController.gd - Signal Declaration ✅

**Verification**: Lines 8-11
```gdscript
# Signals for phase transition integration
signal phase_completed(results: Dictionary)
signal return_to_dashboard  # ✅ ADDED
signal proceed_to_battle  # ✅ ADDED
```

**Status**: ✅ **PASS** - Both signals properly declared

---

### 1.7 WorldPhaseController.gd - Navigation Handlers ✅

**Verification**: Lines 498-520
```gdscript
func _on_proceed_to_battle_pressed() -> void:
    """Handle Proceed to Battle button - primary action"""
    print("WorldPhaseController: User requested proceed to battle")
    _complete_world_phase()  # ✅ COMPLETES PHASE
    proceed_to_battle.emit()  # ✅ EMITS SIGNAL

func _on_back_to_dashboard_pressed() -> void:
    """Handle Back to Dashboard button - return navigation"""
    print("WorldPhaseController: User requested return to dashboard")
    return_to_dashboard.emit()  # ✅ EMITS SIGNAL
    if GameStateManager:
        GameStateManager.navigate_to_screen("campaign_dashboard")  # ✅ PRIMARY NAVIGATION
    else:
        get_tree().change_scene_to_file("res://src/ui/screens/campaign/CampaignDashboard.tscn")  # ✅ FALLBACK
```

**Status**: ✅ **PASS** - Both handlers correctly implemented

---

### 1.8 WorldPhaseController.tscn - Button Connections ✅

**Verification**: Lines 365-388
```tscn
[node name="BackToDashboardButton" type="Button" parent="MarginContainer/VBoxContainer/Footer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(200, 48)
layout_mode = 2
text = "← Back to Dashboard"

[node name="ProceedToBattleButton" type="Button" parent="MarginContainer/VBoxContainer/Footer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(220, 48)
layout_mode = 2
text = "⚔ Proceed to Battle"
```

**Finding**: ❌ **NO SIGNAL CONNECTIONS IN .tscn FILE**

**Status**: ⚠️ **NEEDS VERIFICATION** - Scene file does NOT show signal connections. Connections may be made in `_ready()` or `_connect_ui_signals()`.

**Verification Required**: Lines 156-166 in WorldPhaseController.gd
```gdscript
func _connect_ui_signals() -> void:
    """Connect UI navigation signals"""
    if back_button:
        back_button.pressed.connect(_on_back_button_pressed)  # OLD BUTTON
    if next_button:
        next_button.pressed.connect(_on_next_button_pressed)  # OLD BUTTON
    if automation_toggle:
        automation_toggle.toggled.connect(_on_automation_toggled)
    if back_to_dashboard_button:
        back_to_dashboard_button.pressed.connect(_on_back_to_dashboard_pressed)  # ✅ CONNECTED
    if proceed_to_battle_button:
        proceed_to_battle_button.pressed.connect(_on_proceed_to_battle_pressed)  # ✅ CONNECTED
```

**Resolution**: ✅ **PASS** - Connections made in code (line 163-166)

---

### 1.9 CampaignDashboard.gd - Signal Handler Fixes ✅

**Verification**: Lines 1136-1153
```gdscript
func _on_mission_details_requested() -> void:
    """Handle MissionStatusCard click - navigate to mission details"""
    print("CampaignDashboard: Navigating to Mission Details...")
    get_tree().call_deferred("change_scene_to_file",
        "res://src/ui/screens/world/WorldPhaseController.tscn")  # ✅ FIXED

func _on_world_details_requested() -> void:
    """Handle WorldStatusCard click - navigate to world details"""
    print("CampaignDashboard: Navigating to World Details...")
    get_tree().call_deferred("change_scene_to_file",
        "res://src/ui/screens/world/WorldPhaseController.tscn")  # ✅ FIXED

func _on_story_details_requested() -> void:
    """Handle StoryTrackSection click - navigate to story/quest details"""
    print("CampaignDashboard: Navigating to Story Details...")
    _navigate_with_return("world_phase",
        "res://src/ui/screens/world/WorldPhaseController.tscn")  # ✅ FIXED
```

**Status**: ✅ **PASS** - All handlers now navigate to correct scene

---

### 1.10 SceneRouter.gd - Duplicate & Orphan Documentation ✅

**Known Duplicates** (Lines 19-50):
```gdscript
"main_campaign": "res://src/ui/screens/campaign/MainCampaignScene.tscn",  # Duplicate of campaign_dashboard
"campaign_turn": "res://src/ui/CampaignTurnUI.tscn",  # Legacy - not accessible from dashboard
"post_battle": "res://src/ui/screens/postbattle/PostBattleSequence.tscn",  # Alias for post_battle_sequence
```

**Orphaned Scenes** (scenes not directly reachable from dashboard):
- `mission_selection` - Used by WorldPhaseController only
- `patron_rival_manager` - Not directly accessible
- `battlefield_main` - Not directly accessible
- `battle_resolution` - Not directly accessible
- `campaign_events` - Not directly accessible
- `ship_inventory` - Not directly accessible

**Status**: ✅ **PASS** - Duplicates/orphans documented with comments

---

## Part 2: Manual Test Cases

### Test Environment Setup
1. Launch game in DEBUG mode (not headless)
2. Load existing campaign OR create test campaign
3. Navigate through campaign phases sequentially

---

### TC-001: Travel Phase → Dashboard Navigation
**Priority**: HIGH
**Precondition**: Campaign loaded, Travel Phase active

**Test Steps**:
1. Navigate to Travel Phase (Step 1)
2. Click "Back" button (top navigation)
3. Verify return to Campaign Dashboard

**Expected Results**:
- Signal `return_to_dashboard` emitted
- Navigation to `campaign_dashboard` scene
- No errors in console

**Status**: ⬜ NOT TESTED

---

### TC-002: World Phase → Dashboard Navigation
**Priority**: HIGH
**Precondition**: Campaign loaded, World Phase active

**Test Steps**:
1. Navigate to World Phase (Step 2)
2. Click "Back to Dashboard" button (footer)
3. Verify return to Campaign Dashboard

**Expected Results**:
- Signal `return_to_dashboard` emitted
- Navigation to `campaign_dashboard` scene
- No errors in console

**Status**: ⬜ NOT TESTED

---

### TC-003: World Phase → Battle Navigation
**Priority**: HIGH
**Precondition**: Campaign loaded, World Phase complete

**Test Steps**:
1. Complete World Phase steps (Upkeep → Job Offers → Mission Prep)
2. Click "⚔ Proceed to Battle" button (footer)
3. Verify navigation to Pre-Battle screen

**Expected Results**:
- Signal `proceed_to_battle` emitted
- World phase completion logic runs
- Navigation to `pre_battle` scene
- No errors in console

**Status**: ⬜ NOT TESTED

---

### TC-004: Post-Battle → Dashboard Navigation
**Priority**: HIGH
**Precondition**: Battle complete, Post-Battle Phase active

**Test Steps**:
1. Complete battle and enter Post-Battle Phase
2. Click "Back to Dashboard" button (footer)
3. Verify return to Campaign Dashboard

**Expected Results**:
- Signal `return_to_dashboard` emitted
- Navigation to `campaign_dashboard` scene
- Phase state preserved
- No errors in console

**Status**: ⬜ NOT TESTED

---

### TC-005: Post-Battle → Next Turn Navigation
**Priority**: HIGH
**Precondition**: Post-Battle Phase complete

**Test Steps**:
1. Complete all 14 Post-Battle steps
2. Click "Start Next Turn" button (footer)
3. Verify turn advancement

**Expected Results**:
- Signal `sequence_completed` emitted
- Post-battle summary displayed
- Turn number increments
- Phase resets to Setup/Travel
- No errors in console

**Status**: ⬜ NOT TESTED

---

### TC-006: Dashboard Component Navigation
**Priority**: MEDIUM
**Precondition**: Campaign Dashboard displayed

**Test Steps**:
1. Click MissionStatusCard
2. Verify navigation to World Phase
3. Return to dashboard
4. Click WorldStatusCard
5. Verify navigation to World Phase
6. Return to dashboard
7. Click StoryTrackSection
8. Verify navigation to World Phase

**Expected Results**:
- All component cards navigate to `WorldPhaseController.tscn`
- No navigation to non-existent scenes
- No errors in console

**Status**: ⬜ NOT TESTED

---

### TC-007: Signal Flow Validation
**Priority**: HIGH
**Type**: Integration Test

**Test Flow**:
```
Dashboard → Travel Phase
  ↓ (return_to_dashboard signal)
Dashboard → World Phase
  ↓ (proceed_to_battle signal)
Pre-Battle → Battle → Post-Battle
  ↓ (return_to_dashboard signal)
Dashboard
  ↓ (sequence_completed signal)
Next Turn
```

**Expected Results**:
- All signals emit correctly
- Navigation completes without deadlocks
- State persists across transitions
- No console errors

**Status**: ⬜ NOT TESTED

---

### TC-008: Fallback Navigation (SceneRouter Unavailable)
**Priority**: LOW
**Type**: Edge Case

**Test Steps**:
1. Temporarily disable SceneRouter autoload
2. Navigate to Travel Phase
3. Click "Back" button
4. Verify fallback navigation works

**Expected Results**:
- Fallback `change_scene_to_file` executes
- Navigation completes successfully
- Warning logged about SceneRouter unavailable

**Status**: ⬜ NOT TESTED

---

## Part 3: Signal Flow Diagram (ASCII)

```
CAMPAIGN DASHBOARD (Hub)
    │
    ├──[Next Phase]──► TRAVEL PHASE (Step 1)
    │                     │
    │                     ├──[Back]──────────┐
    │                     │                  │ return_to_dashboard
    │                     └──[Next]──► WORLD PHASE (Step 2)
    │                                     │
    │                                     ├──[Back to Dashboard]─┐
    │                                     │                      │ return_to_dashboard
    │                                     └──[Proceed to Battle]─┼─► PRE-BATTLE
    │                                                            │        │
    │◄───────────────────────────────────────────────────────────┘        │
    │                                                                     │
    │                                                                BATTLE
    │                                                                     │
    │                                                            POST-BATTLE (14 Steps)
    │                                                                     │
    │◄──────[Back to Dashboard]─────────────────────────────────────────┤
    │                                                                     │
    │◄──────[Start Next Turn]───────────────────────────────────────────┘
    │                           (sequence_completed)
    │
    └──► (Turn increments, cycle repeats)
```

**Legend**:
- `──►` Direct navigation
- `───┐` Signal emission
- `◄───┘` Return path

---

## Part 4: Verification Checklist

### Code Review Checklist

#### Signal Declarations
- [x] TravelPhaseUI.gd: `return_to_dashboard` signal declared (line 12)
- [x] PostBattleSequence.gd: `return_to_dashboard` signal declared (line 19)
- [x] PostBattleSequence.gd: `sequence_completed` signal declared (line 20)
- [x] WorldPhaseController.gd: `return_to_dashboard` signal declared (line 10)
- [x] WorldPhaseController.gd: `proceed_to_battle` signal declared (line 11)

#### Handler Implementations
- [x] TravelPhaseUI.gd: `_on_back_button_pressed()` emits signal + navigates (lines 402-409)
- [x] PostBattleSequence.gd: `_on_back_pressed()` emits signal + navigates (lines 928-936)
- [x] PostBattleSequence.gd: `_on_next_turn_pressed()` emits signal + completes (lines 938-942)
- [x] WorldPhaseController.gd: `_on_back_to_dashboard_pressed()` emits signal + navigates (lines 508-520)
- [x] WorldPhaseController.gd: `_on_proceed_to_battle_pressed()` emits signal + completes (lines 498-506)

#### Scene Connections
- [x] PostBattleSequence.tscn: BackButton connected to `_on_back_pressed` (line 180)
- [x] PostBattleSequence.tscn: NextTurnButton connected to `_on_next_turn_pressed` (line 181)
- [x] WorldPhaseController.gd: Footer buttons connected in code (lines 163-166)

#### Dashboard Fixes
- [x] CampaignDashboard.gd: `_on_mission_details_requested()` navigates to WorldPhaseController (line 1141)
- [x] CampaignDashboard.gd: `_on_world_details_requested()` navigates to WorldPhaseController (line 1146)
- [x] CampaignDashboard.gd: `_on_story_details_requested()` navigates to WorldPhaseController (line 1152)

#### SceneRouter Documentation
- [x] Duplicate scenes documented with comments (lines 19, 21, 49)
- [x] Orphaned scenes documented with comments (lines 36, 40, 41, 46, 48, 53)

---

### Integration Points Checklist

- [ ] TravelPhaseUI signals connected to CampaignDashboard listeners
- [ ] WorldPhaseController signals connected to CampaignDashboard listeners
- [ ] PostBattleSequence signals connected to CampaignDashboard listeners
- [ ] CampaignPhaseManager receives phase completion events
- [ ] GameStateManager state updates persist across transitions
- [ ] No orphaned signal connections (disconnected listeners)

---

## Part 5: Known Issues & Recommendations

### Issues Found During Verification

1. **WorldPhaseController.tscn - No Visible Signal Connections**
   - **Status**: RESOLVED ✅
   - **Location**: Lines 365-388 (scene file)
   - **Resolution**: Connections made in code at lines 163-166 (GDScript)
   - **Action**: None required

2. **SceneRouter Duplicates May Cause Confusion**
   - **Status**: DOCUMENTED ⚠️
   - **Duplicates**: `main_campaign`, `campaign_turn`, `post_battle`
   - **Recommendation**: Consolidate to single canonical route per screen
   - **Action**: Low priority cleanup task

### Recommendations

1. **Add Unit Tests for Signal Emission**
   ```gdscript
   # Example test structure
   func test_travel_phase_back_button_emits_signal():
       var travel_ui = TravelPhaseUI.new()
       var signal_received = false
       travel_ui.return_to_dashboard.connect(func(): signal_received = true)
       travel_ui._on_back_button_pressed()
       assert_true(signal_received, "return_to_dashboard signal should emit")
   ```

2. **Create Integration Test for Full Navigation Loop**
   - Test complete turn cycle: Dashboard → Travel → World → Battle → Post-Battle → Dashboard
   - Verify state persistence at each transition
   - Ensure no memory leaks from orphaned signals

3. **Add Console Logging for Signal Flow**
   - Already implemented in handlers (good!)
   - Consider adding signal listener logging in CampaignDashboard for debugging

4. **Document Navigation Architecture**
   - Create architecture diagram showing signal flow
   - Document which components listen to which signals
   - Include in developer documentation

---

## Part 6: Test Execution Summary

**Test Date**: _________
**Tester**: _________
**Build Version**: _________

### Test Results Summary

| Test Case | Status | Notes |
|-----------|--------|-------|
| TC-001: Travel → Dashboard | ⬜ NOT TESTED | |
| TC-002: World → Dashboard | ⬜ NOT TESTED | |
| TC-003: World → Battle | ⬜ NOT TESTED | |
| TC-004: Post-Battle → Dashboard | ⬜ NOT TESTED | |
| TC-005: Post-Battle → Next Turn | ⬜ NOT TESTED | |
| TC-006: Dashboard Components | ⬜ NOT TESTED | |
| TC-007: Signal Flow | ⬜ NOT TESTED | |
| TC-008: Fallback Navigation | ⬜ NOT TESTED | |

**Overall Status**: ⬜ PENDING MANUAL TESTING

**Critical Blockers**: None identified in code review

**Minor Issues**: None identified

**Next Steps**:
1. Execute manual test cases TC-001 through TC-007
2. Verify signal flow diagram matches actual behavior
3. Test edge cases (TC-008)
4. Create integration tests if all manual tests pass

---

## Appendix A: File Modification Summary

### Sprint 1: Phase Dead End Fixes

| File | Lines Changed | Changes Made |
|------|---------------|--------------|
| TravelPhaseUI.gd | +1 signal, +8 handler | Added `return_to_dashboard` signal + handler |
| PostBattleSequence.gd | +2 signals, +15 handlers | Added navigation footer signals + handlers |
| PostBattleSequence.tscn | +20 nodes | Added NavigationFooter with 2 buttons |
| WorldPhaseController.gd | +2 signals, +23 handlers | Added navigation footer signals + handlers |
| WorldPhaseController.tscn | +24 nodes | Added footer with 2 buttons |

### Sprint 2: Dashboard & Router Fixes

| File | Lines Changed | Changes Made |
|------|---------------|--------------|
| CampaignDashboard.gd | ~15 fixes | Fixed 3 broken navigation handlers |
| SceneRouter.gd | +8 comments | Documented duplicates & orphans |

**Total Files Modified**: 7
**Total Signals Added**: 5
**Total Handlers Added**: 5
**Total Scene Nodes Added**: 44

---

## Appendix B: Navigation Pattern Best Practices

### Pattern 1: Signal + Navigation (Recommended)
```gdscript
func _on_back_button_pressed() -> void:
    return_to_dashboard.emit()  # Notify listeners
    if SceneRouter:
        SceneRouter.navigate_to("campaign_dashboard")  # Primary path
    else:
        get_tree().change_scene_to_file("path/to/scene.tscn")  # Fallback
```

**Why**: Decouples UI from navigation, allows external listeners, provides fallback

### Pattern 2: Direct Navigation (Avoid)
```gdscript
func _on_back_button_pressed() -> void:
    get_tree().change_scene_to_file("path/to/scene.tscn")  # No signal, no fallback
```

**Why Avoid**: Tight coupling, no extensibility, no signal-based state management

### Pattern 3: Signal Only (Incomplete)
```gdscript
func _on_back_button_pressed() -> void:
    return_to_dashboard.emit()  # Signal only, no navigation
```

**Why Avoid**: Requires external system to handle navigation, breaks if listener missing

---

## Document Metadata

**Created By**: QA & Integration Specialist (Claude)
**Creation Date**: 2025-12-15
**Last Updated**: 2025-12-15
**Version**: 1.0
**Related Documents**:
- MANUAL_TESTING_CHECKLIST.md
- docs/design/ui_overview.md
- QUICK_START.md

**Revision History**:
| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-15 | Initial creation - comprehensive navigation test plan |

---

**END OF DOCUMENT**
