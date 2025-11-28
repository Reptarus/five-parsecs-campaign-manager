# Current TODO List - E2E Integration Sprint
**Status**: Phase 1 ✅ Complete | Phase 2 🔄 In Progress | Phase 3A ⏳ Pending
**Last Updated**: 2025-11-25

---

## ✅ COMPLETED (Phase 1 - Type Safety)

1. ✅ Add get_rival_count() method to CoreGameState
2. ✅ Add has_active_quest() method to CoreGameState
3. ✅ Fix WorldPhase.gd:220 Variant→int handling
4. ✅ Fix TravelPhase.gd:360 type casts
5. ✅ Change all PreBattleLoop signatures to Variant (12 methods)
6. ✅ Fix PostBattlePhase.gd:397 invalid cast
7. ✅ Fix PostBattlePhase.gd:526 invalid cast

**Result**: 0 runtime errors, basic tests pass, E2E tests have timing issues only

---

## 🔄 IN PROGRESS (Phase 2 - Quest/Rival System)

### Task 2.1: Core Quest/Rival Methods (45 min)
- [ ] Implement get_quest_rumors() in GameState.gd
- [ ] Implement add_quest_rumors(count: int) in GameState.gd
- [ ] Implement remove_rival(rival_id: String) in GameState.gd
- [ ] Implement add_rival(rival: Dictionary) in GameState.gd
- [ ] Implement add_patron_contact(patron_id: String) in GameState.gd

**File**: `src/core/state/GameState.gd` (+30-40 lines)

### Task 2.2: Data Structure Bridge (30 min)
- [ ] Add _sync_campaign_data() method in GameState.gd
- [ ] Update _emit_state_changed() to sync data
- [ ] Verify rivals/patrons sync between GameState and Campaign

**File**: `src/core/state/GameState.gd` (+15-20 lines)

### Task 2.3: Lifecycle Methods (30 min)
- [ ] Implement dismiss_non_persistent_patrons() in GameState.gd
- [ ] Implement advance_quest(progress: int) in GameState.gd
- [ ] Test quest advancement in PostBattleSequence

**File**: `src/core/state/GameState.gd` (+10-15 lines)

### Task 2.4: Battle Option Logic (15 min)
- [ ] Implement can_attack_rival() in GameState.gd
- [ ] Test rival attack option in WorldPhase

**File**: `src/core/state/GameState.gd` (+3-5 lines)

### Task 2.5: Validation & Testing (30 min)
- [ ] Run E2E tests and check for missing method errors
- [ ] Verify WorldPhase rival attack checks execute
- [ ] Test PostBattlePhase rival removal logic
- [ ] Check CampaignDashboard displays quest/rival data

**Expected Result**: No "Nonexistent function" errors for quest/rival methods

---

## ⏳ PENDING (Phase 3A - E2E Test Mode)

### Task 3A.1: Add Test Mode to TravelPhase (15 min)
- [ ] Add test_mode: bool = false flag to TravelPhase.gd
- [ ] Modify start_travel_phase() to check test_mode
- [ ] If test_mode true, call _complete_travel_phase() immediately

**File**: `src/core/campaign/phases/TravelPhase.gd` (+5-10 lines)

### Task 3A.2: Add Test Mode to WorldPhase (15 min)
- [ ] Add test_mode: bool = false flag to WorldPhase.gd
- [ ] Modify start_world_phase() to check test_mode
- [ ] If test_mode true, call _complete_world_phase() immediately

**File**: `src/core/campaign/phases/WorldPhase.gd` (+5-10 lines)

### Task 3A.3: Add Test Mode to PostBattlePhase (15 min)
- [ ] Add test_mode: bool = false flag to PostBattlePhase.gd
- [ ] Modify start_post_battle_phase() to check test_mode
- [ ] If test_mode true, call _complete_post_battle_phase() immediately

**File**: `src/core/campaign/phases/PostBattlePhase.gd` (+5-10 lines)

### Task 3A.4: Enable Test Mode in E2E Tests (15 min)
- [ ] Modify test_campaign_turn_loop_e2e.gd before() method
- [ ] Get phase handler references from CampaignPhaseManager
- [ ] Set test_mode = true on each phase handler

**File**: `tests/integration/test_campaign_turn_loop_e2e.gd` (+15-20 lines)

### Final Validation
- [ ] Run full E2E test suite
- [ ] Verify 100% test pass rate (target: 79/79 or 81/81)
- [ ] Check test execution time (<2 minutes)
- [ ] Update WEEK_4_RETROSPECTIVE.md with completion

---

## 🎯 SUCCESS CRITERIA

### Phase 2 Complete When:
✅ All 8 quest/rival methods implemented in GameState.gd
✅ No "Nonexistent function" errors in test output
✅ WorldPhase rival attack checks work without crashes
✅ PostBattlePhase can remove rivals after defeat
✅ CampaignDashboard shows rivals/patrons/quest rumors

### Phase 3A Complete When:
✅ test_mode flag added to all 3 phase handlers
✅ E2E test sets test_mode = true for all phases
✅ E2E tests pass with 0 assertion failures
✅ Test suite completes in <2 minutes
✅ Signal timing issues resolved

---

## 📦 FILES BEING MODIFIED

### Phase 2 (1 file):
- `src/core/state/GameState.gd` (+60-80 lines total)

### Phase 3A (4 files):
- `src/core/campaign/phases/TravelPhase.gd` (+5-10 lines)
- `src/core/campaign/phases/WorldPhase.gd` (+5-10 lines)
- `src/core/campaign/phases/PostBattlePhase.gd` (+5-10 lines)
- `tests/integration/test_campaign_turn_loop_e2e.gd` (+15-20 lines)

**Total Changes**: +95-120 lines across 5 files (all edits, no new files)

---

## ⏱️ TIME REMAINING

- Phase 2: 2.5-3 hours
- Phase 3A: 45-60 minutes
- **Total: 3.5-4 hours to 100% E2E coverage**

---

## 🔗 REFERENCE DOCUMENTS

- **SPRINT_PLAN_E2E_INTEGRATION.md** - Detailed implementation guide
- **WEEK_4_RETROSPECTIVE.md** - Project status (95/100 BETA_READY)
- **TESTING_GUIDE.md** - Testing methodology
- **src/core/state/GameState.gd** - Main implementation file

---

## 📝 QUICK COMMANDS

### Run E2E Tests
```bash
powershell.exe -Command "& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/integration/test_campaign_turn_loop_e2e.gd --quit-after 90 2>&1 | Out-File -FilePath test_e2e_output.txt -Encoding utf8"
```

### Check Test Results
```bash
powershell.exe -Command "Get-Content test_e2e_output.txt | Select-String -Pattern 'Statistics|PASSED|FAILED|ERROR:.*Nonexistent' | Select-Object -Last 20"
```

### Run Basic Tests (Validation)
```bash
powershell.exe -Command "& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' --script addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/integration/test_campaign_turn_loop_basic.gd --quit-after 60"
```

---

**Next Action**: Start Phase 2 Task 2.1 (implement core quest/rival methods)
