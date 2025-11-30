# Campaign Creation Wizard - Manual Testing Checklist

**Date Created**: 2025-11-28
**Status**: Data handoff fixes implemented - READY FOR MANUAL TESTING
**Purpose**: Validate complete campaign creation flow before UI/UX polish

---

## 🎯 Testing Objective

Validate that all data flows correctly from panels → coordinator → FinalPanel after implementing data handoff fixes.

---

## ✅ PRE-TEST VALIDATION (Automated)

**Status**: ✅ COMPLETED
- [x] GDScript compilation check (no parse errors)
- [x] All modified files compile successfully
- [x] No type errors in FinalPanel.gd lines 412, 269
- [x] Coordinator _character_to_dict() method accessible
- [x] Git commit successful with all fixes

---

## 🧪 MANUAL TEST SCENARIOS

### Scenario 1: Basic Campaign Creation Flow

**Objective**: Verify complete wizard progression with minimal data

**Steps**:
1. Launch game → Main Menu → "New Campaign"
2. **ConfigPanel (Step 1/7)**:
   - Set campaign name: "Test Campaign Alpha"
   - Difficulty: "Normal"
   - Story Track: Enabled
   - Click "Next"
   - ✅ **Verify**: Panel advances to Step 2/7

3. **CaptainPanel (Step 2/7)**:
   - Set captain name: "Captain TestRun"
   - Select background: Any option
   - Select motivation: Any option
   - Click "Next"
   - ✅ **Verify**: Panel advances to Step 3/7

4. **CrewPanel (Step 3/7)**:
   - Add at least 2 crew members
   - Assign names and basic stats
   - Click "Next"
   - ✅ **Verify**: Panel advances to Step 4/7

5. **ShipPanel (Step 4/7)**:
   - Set ship name: "Test Ship"
   - Click "Next"
   - ✅ **Verify**: Panel advances to Step 5/7

6. **EquipmentPanel (Step 5/7)**:
   - Accept default equipment or modify
   - Click "Next"
   - ✅ **Verify**: Panel advances to Step 6/7

7. **WorldPanel (Step 6/7)**:
   - Set starting location
   - Click "Next"
   - ✅ **Verify**: Panel advances to Step 7/7 (FinalPanel)

8. **FinalPanel (Step 7/7)** - ⚠️ CRITICAL TEST:
   - ✅ **Verify Campaign Name**: "Test Campaign Alpha" displays
   - ✅ **Verify Captain Name**: "Captain TestRun" displays
   - ✅ **Verify Crew Count**: Shows correct number of crew members
   - ✅ **Verify Ship Name**: "Test Ship" displays
   - ✅ **Verify No Errors**: Console shows NO errors about:
     - Type mismatch at line 412
     - Null parameter at line 269
     - Empty campaign_name validation errors
   - ✅ **Verify UI Renders**: All 5 summary cards display without crashes
   - Click "Create Campaign"
   - ✅ **Verify**: Campaign creates successfully

**Expected Console Output**:
```
CampaignCreationCoordinator: Updating captain state
CampaignCreationCoordinator: Set captain name to: Captain TestRun
FinalPanel: UI built successfully
```

**Failure Criteria**:
- ❌ Campaign name shows as empty/blank
- ❌ Captain name shows as empty/blank
- ❌ Crew count shows 0 when crew exists
- ❌ Type mismatch error at FinalPanel:412
- ❌ Null parameter error at FinalPanel:269
- ❌ Missing summary cards

---

### Scenario 2: Data Normalization Edge Cases

**Objective**: Test captain data extraction from nested structures

**Steps**:
1. Start campaign creation
2. ConfigPanel: Set campaign name "Nested Test"
3. **CaptainPanel**: Create captain with full details:
   - Name: "Captain Nested"
   - Background: "Military"
   - Motivation: "Wealth"
   - All stats assigned
4. Navigate to FinalPanel
5. ✅ **Verify**: Captain name extracted correctly from nested structure
6. ✅ **Verify**: Background displays as "Military"
7. ✅ **Verify**: Motivation displays as "Wealth"

**Expected Result**: Data extracted regardless of nesting structure

---

### Scenario 3: Character Object to Dictionary Conversion

**Objective**: Verify crew members convert correctly (Character objects → Dictionaries)

**Steps**:
1. Start campaign creation
2. **CrewPanel**: Add 4 crew members with:
   - Varied combat stats (3, 5, 7, 2)
   - Varied reaction stats (4, 3, 5, 6)
3. Navigate to FinalPanel
4. ✅ **Verify Crew Count**: Shows "Crew Members: 4"
5. ✅ **Verify Stats**: Average combat and reactions calculated correctly
6. ✅ **Verify No Errors**: No type conversion errors in console
7. Open console and check for:
   ```
   # Should NOT see:
   "Trying to assign an array of type 'Array' to a variable of type 'Array[Dictionary]'"
   ```

**Expected Result**: All crew data displays with correct averages

---

### Scenario 4: Null Safety Validation

**Objective**: Verify FinalPanel handles missing/null data gracefully

**Steps**:
1. Start campaign creation
2. ConfigPanel: Set minimal campaign name only
3. **Skip optional fields** where possible
4. Navigate quickly to FinalPanel
5. ✅ **Verify**: FinalPanel renders without crashes
6. ✅ **Verify**: Missing data shows as defaults (not null errors)
7. ✅ **Verify**: "Create Campaign" button disabled until required data present

**Expected Result**: No null parameter errors even with minimal data

---

### Scenario 5: Signal Data Flow Validation

**Objective**: Verify real-time data updates as panels change

**Steps**:
1. Start campaign creation
2. ConfigPanel: Set campaign name "Signal Test A"
3. Navigate to CaptainPanel
4. Navigate back to ConfigPanel
5. Change campaign name to "Signal Test B"
6. Navigate forward to FinalPanel
7. ✅ **Verify**: Campaign name shows "Signal Test B" (latest value)
8. Navigate back to CaptainPanel
9. Change captain name
10. Navigate to FinalPanel
11. ✅ **Verify**: Captain name updated correctly

**Expected Result**: All changes reflected in FinalPanel immediately

---

## 📊 SUCCESS CRITERIA

### ✅ All Tests Must Pass:
- [ ] Scenario 1: Basic flow completes without errors
- [ ] Scenario 2: Nested data extraction works
- [ ] Scenario 3: Character-to-Dictionary conversion works
- [ ] Scenario 4: Null safety prevents crashes
- [ ] Scenario 5: Signal updates propagate correctly

### ✅ Zero Console Errors For:
- [ ] Type mismatch at FinalPanel.gd:412
- [ ] Null parameter at FinalPanel.gd:269
- [ ] Empty campaign_name validation errors
- [ ] Missing character data errors

### ✅ UI Rendering:
- [ ] All 5 summary cards display correctly
- [ ] Progress indicator shows "7/7"
- [ ] Create Campaign button enables when valid
- [ ] Crew preview section renders

---

## 🐛 Known Issues to Watch For

### RESOLVED (Should NOT Appear):
- ~~Type mismatch Array vs Array[Dictionary]~~ → Fixed in commit ff94486e
- ~~Null cascade from failed card creation~~ → Fixed with null guards
- ~~Captain name empty in FinalPanel~~ → Fixed with normalized extraction

### POTENTIAL NEW ISSUES:
- UI spacing/alignment may need refinement
- Card styling may need polish
- Button states may need visual feedback
- Crew preview layout may need adjustment

---

## 📝 Test Results Template

```markdown
## Test Session: [Date/Time]
**Tester**: [Name]
**Build**: feature/campaign-creation-final @ ff94486e

### Scenario 1: Basic Flow
- Status: ✅ PASS / ❌ FAIL
- Notes: [Any observations]

### Scenario 2: Nested Data
- Status: ✅ PASS / ❌ FAIL
- Notes: [Any observations]

### Scenario 3: Type Conversion
- Status: ✅ PASS / ❌ FAIL
- Notes: [Any observations]

### Scenario 4: Null Safety
- Status: ✅ PASS / ❌ FAIL
- Notes: [Any observations]

### Scenario 5: Signal Flow
- Status: ✅ PASS / ❌ FAIL
- Notes: [Any observations]

### Overall Result
- Status: ✅ READY FOR UI POLISH / ❌ NEEDS FIXES
- Critical Issues: [List any blockers]
- UI/UX Observations: [Improvements needed]
```

---

## 🎨 Next Steps After Testing

### If All Tests PASS:
1. ✅ Mark data handoff as COMPLETE
2. 🎨 Begin UI/UX polish phase (user requested)
3. 🧹 Optimize code and file structure
4. 📖 Document architecture

### If Tests FAIL:
1. 🐛 Log specific failure scenarios
2. 🔍 Debug root cause
3. 🔧 Apply targeted fixes
4. 🔄 Re-test affected scenarios

---

**Document Owner**: Claude Code AI
**Last Updated**: 2025-11-28
**Status**: READY FOR MANUAL TESTING
