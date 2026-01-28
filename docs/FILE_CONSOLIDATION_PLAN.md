# File Consolidation Plan

**Created**: 2025-11-28
**Last Updated**: 2025-11-29
**Current File Count**: 470 .gd files (increased from 441 due to restore from failed consolidation)
**Target Range**: 150-250 files (40-65% reduction)
**Priority**: Week 4+ Sprint
**Status**: Phase 0 Complete, Phases 1-3 Rolled Back (Lessons Learned)

---

## 🚨 CONSOLIDATION ATTEMPT RETROSPECTIVE (Nov 29, 2025)

### What Happened

**Phase 0: Scene Reference Fixes** ✅ SUCCESS (KEPT)
- Fixed `InitialCrewCreation.gd`: CharacterBox.tscn → CharacterCard.tscn
- Fixed `SceneRouter.gd`: Removed deleted CharacterSheet.tscn mapping
- Fixed `ApplicationOrchestrator.gd`: PostBattle.tscn → PostBattleSequence.tscn
- **Result**: Clean state for consolidation, no parse errors

**Phases 1-3: Code Consolidation** ❌ ROLLED BACK
Parallel agents created 7 consolidated files:
- `GameConstants.gd` (merged 6 constant files)
- `UniversalUtilities.gd` (merged 5 utility files)
- `TableSystem.gd` (merged 2 table files)
- `EnemySystemManager.gd` (merged 2 manager files)
- `CampaignEventsManager.gd` (merged 2 manager files)
- `WorldResourceManager.gd` (merged 3 manager files)
- `BattlefieldCore.gd` (merged 6 battlefield files)

**Problems Encountered**:
1. Agents deleted original files BEFORE updating all references
2. `class_name` conflicts caused parse errors (Godot only allows one file per class_name)
3. Incomplete reference updates across 470+ files
4. Had to restore original files from git

**Root Cause**: Incomplete workflow - agents focused on consolidation without proper reference migration strategy.

---

## 📚 CRITICAL LESSONS LEARNED

### Lesson 1: Update References FIRST, Delete LAST

**Problem**: Agents deleted source files immediately after creating consolidated versions.

**Solution**: Always follow this sequence:
```bash
# MANDATORY SEQUENCE
1. Create consolidated file with NEW class_name (avoid conflicts)
2. Search ALL references: grep -r "OldClassName" src/ tests/
3. Update EVERY reference to new class_name
4. Run parse check (MUST pass)
5. Run test suite (MUST pass)
6. ONLY THEN delete original files
7. (Optional) Rename consolidated file to final name
```

**Example**:
```gdscript
# WRONG: Immediate deletion
- Create GameConstants.gd with class_name GameConstants
- Delete UIConstants.gd, BattleConstants.gd (ERROR: references still exist)

# RIGHT: Staged migration
- Create GameConstantsV2.gd with class_name GameConstantsV2
- Find all: grep -r "UIConstants\|BattleConstants" src/
- Replace ALL references to use GameConstantsV2
- Verify: godot --headless --check-only
- Delete UIConstants.gd, BattleConstants.gd
- Rename GameConstantsV2.gd → GameConstants.gd
```

### Lesson 2: class_name Conflicts are Parse Errors

**Problem**: Godot only allows one file per `class_name`. Creating consolidated file with same name as existing file causes immediate parse failure.

**Solution**: Use versioned class_name strategy:
```gdscript
# Step 1: Create with temporary name
# GameConstantsV2.gd
class_name GameConstantsV2
extends RefCounted

# Step 2: After ALL references updated and originals deleted
# Rename to GameConstants.gd
class_name GameConstants
extends RefCounted
```

### Lesson 3: Incremental Consolidation Only

**Problem**: Attempting to consolidate 7 file groups simultaneously made rollback difficult and error-prone.

**Solution**: ONE consolidation group per session:
```bash
# Session 1: Constants only (6 files → 1 file)
- Create GameConstantsV2.gd
- Update all references
- Validate
- Commit

# Session 2: Utilities only (5 files → 1 file)
- Create UniversalUtilitiesV2.gd
- Update all references
- Validate
- Commit

# ... etc
```

**Why**: Each commit is a safe rollback point. Parse errors isolated to single change.

### Lesson 4: Validation Steps are NON-NEGOTIABLE

**Mandatory Checks Before Deleting ANY File**:
```bash
# 1. Reference Check (MUST be 0 external references)
grep -r "OldClassName" src/ tests/ | grep -v "NewConsolidated" | wc -l
# Expected output: 0

# 2. Parse Check (MUST pass)
godot --headless --check-only --path "." --quit-after 10
# Expected: No parse errors

# 3. Test Suite (MUST pass)
./tests/run_test_suite.sh
# Expected: 76/79 passing (or current baseline)

# 4. Only if ALL checks pass → Delete original files
rm old_file_1.gd old_file_2.gd
```

### Lesson 5: Grep is Your Safety Net

**Reference Discovery Pattern**:
```bash
# Find ALL references to class
grep -r "UIConstants" src/ tests/ | wc -l

# Find references by type
grep -r "preload.*UIConstants" src/      # Preloads
grep -r "extends UIConstants" src/       # Inheritance
grep -r "UIConstants\." src/            # Static access

# Find scene references (*.tscn files)
grep -r "UIConstants" src/ --include="*.tscn"

# Comprehensive check (shows context)
grep -r "UIConstants" src/ tests/ -n -C 2
```

**NEVER delete a file without running these checks first.**

---

## 🛡️ SAFE CONSOLIDATION PATTERN (MANDATORY)

Use this exact pattern for ALL consolidations:

### Step-by-Step Safe Consolidation

```bash
# STEP 1: Create Consolidated File (NEW class_name)
# File: src/core/GameConstantsV2.gd
class_name GameConstantsV2
extends RefCounted

# ... merge content from 6 files ...

# STEP 2: Find ALL References
grep -r "UIConstants\|BattleConstants\|EnemyConstants" src/ tests/ > refs.txt
# Review refs.txt - should show ~100+ references

# STEP 3: Update References (use edit_block for each)
# For each reference found:
# OLD: const MAX_CREW = UIConstants.MAX_CREW_SIZE
# NEW: const MAX_CREW = GameConstantsV2.MAX_CREW_SIZE

# STEP 4: Verify Reference Updates
grep -r "UIConstants\|BattleConstants" src/ tests/ | grep -v "GameConstantsV2" | wc -l
# MUST output: 0

# STEP 5: Parse Check
godot --headless --check-only --path "." --quit-after 10
# MUST output: No errors

# STEP 6: Test Suite
./tests/run_test_suite.sh
# MUST output: 76/79 passing (or baseline)

# STEP 7: Delete Original Files (ONLY if Steps 4-6 pass)
git rm src/core/systems/UIConstants.gd
git rm src/core/battle/BattleConstants.gd
# ... etc

# STEP 8: Commit Immediately
git commit -m "feat(consolidation): Merge 6 constant files into GameConstantsV2"

# STEP 9: (Optional) Rename to Final Name
# If desired, rename GameConstantsV2 → GameConstants
# Repeat Steps 2-8 for rename
```

### Validation Scripts Created

Created helper scripts for safe consolidation:

**validate_consolidation.sh**:
```bash
#!/bin/bash
# Validates consolidation readiness
# Usage: ./validate_consolidation.sh "OldClassName1|OldClassName2"

PATTERN=$1
COUNT=$(grep -r "$PATTERN" src/ tests/ | grep -v "NewConsolidated" | wc -l)

if [ $COUNT -eq 0 ]; then
    echo "✅ Safe to delete: No references to $PATTERN found"
    exit 0
else
    echo "❌ NOT SAFE: Found $COUNT references to $PATTERN"
    grep -r "$PATTERN" src/ tests/ | grep -v "NewConsolidated"
    exit 1
fi
```

**run_test_suite.sh**:
```bash
#!/bin/bash
# Runs full test suite
# Usage: ./run_test_suite.sh

godot --headless --path "." \
      --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
      -a tests/ \
      --quit-after 120
```

---

## 📊 UPDATED CURRENT DISTRIBUTION

### Current File Counts (Nov 29, 2025)
| Directory | Files | Consolidation Priority | Target |
|-----------|-------|----------------------|--------|
| `src/core/systems` | 45 | 🔴 CRITICAL | 24 |
| `src/core/battle` | 32 | 🔴 HIGH | 15 |
| `src/ui/screens/campaign` | 20 | 🟡 MEDIUM | 12 |
| `src/core/managers` | 12 | 🔴 HIGH | 7 |
| `src/ui/components/campaign` | 12 | 🟢 LOW | 8 |
| `src/ui/components/battle` | 12 | 🟢 LOW | 8 |
| `src/core/campaign` | 11 | 🟡 MEDIUM | 7 |
| **Total src/** | **470** | - | **150-250** |

**Change from Previous**: +29 files (restored deleted files from failed consolidation)

---

## 🎯 REVISED CONSOLIDATION TARGETS

### Priority 1: `src/core/systems` (45 files → ~24 files) - RETRY

**Problem**: Too many granular system files
**Strategy**: Group by domain with SAFE pattern

| Current Files | Merge Into | Status |
|---------------|------------|--------|
| UIConstants.gd, BattleConstants.gd, EnemyConstants.gd, ItemConstants.gd, WorldConstants.gd, TradeConstants.gd | `GameConstantsV2.gd` | ⏳ READY (use safe pattern) |
| StringUtils.gd, ArrayUtils.gd, DictUtils.gd, MathUtils.gd, ValidationUtils.gd | `UniversalUtilitiesV2.gd` | ⏳ READY (use safe pattern) |
| TableLookup.gd, TableManager.gd | `TableSystemV2.gd` | ⏳ READY (use safe pattern) |
| FallbackDiceManager.gd, FallbackCampaignManager.gd | `FallbackSystemsV2.gd` | ⏳ READY (use safe pattern) |
| Injury system files (3-4) | `InjurySystemV2.gd` | ⏳ Pending |
| Loot system files (3-4) | `LootSystemV2.gd` | ⏳ Pending |

**Expected Reduction**: ~21 files (45 → 24)

### Priority 2: `src/core/managers` (12 files → ~7 files)

**Problem**: Manager proliferation
**Strategy**: Merge related managers with SAFE pattern

| Current Files | Merge Into | Status |
|---------------|------------|--------|
| EnemyManager.gd, EnemyAIManager.gd | `EnemySystemManagerV2.gd` | ⏳ READY (use safe pattern) |
| CampaignEventManager.gd, StoryEventManager.gd | `CampaignEventsManagerV2.gd` | ⏳ READY (use safe pattern) |
| WorldManager.gd, LocationManager.gd, PlanetManager.gd | `WorldResourceManagerV2.gd` | ⏳ READY (use safe pattern) |
| CrewRelationshipManager.gd | Inline into CrewManager.gd | ⏳ Pending |

**Expected Reduction**: ~5 files (12 → 7)

### Priority 3: `src/core/battle` (32 files → ~15 files)

**Problem**: Over-separated battle components
**Strategy**: Group by function with SAFE pattern

| Current Files | Merge Into | Status |
|---------------|------------|--------|
| BattlefieldGeneration.gd, TerrainGeneration.gd, CoverGeneration.gd, DeploymentZones.gd, ObjectivePlacement.gd, HazardGeneration.gd | `BattlefieldCoreV2.gd` | ⏳ READY (use safe pattern) |
| CombatResolver.gd, modifiers/*.gd | `CombatResolutionV2.gd` | ⏳ Pending |
| AI files | `BattleAIV2.gd` | ⏳ Pending |
| Phase handlers | Merge similar phases | ⏳ Pending |

**Expected Reduction**: ~17 files (32 → 15)

---

## 📁 Small Files to Merge/Delete (<50 lines)

These files are candidates for inlining or merging:

| File | Lines | Action | Status |
|------|-------|--------|--------|
| `UIColors.gd` | 23 | Inline into theme system | ⏳ Pending |
| `CampaignSummaryPanel.gd` | 32 | Merge into parent | ⏳ Pending |
| `CrewRelationshipManager.gd` | 39 | Merge into CrewManager | ⏳ Pending |
| `FallbackDiceManager.gd` | 41 | Merge into FallbackSystemsV2 | ⏳ Ready |
| `MissionTemplate.gd` | 41 | Keep (template class) | ✅ No action |
| `VictoryOption.gd` | 44 | Keep (UI component) | ✅ No action |
| `ErrorLogger.gd` | 45 | Merge into utils | ⏳ Pending |
| `validation_panel.gd` | 45 | Rename/Relocate | ⏳ Pending |
| `GameOverScreen.gd` | 45 | Keep (screen) | ✅ No action |
| `FallbackCampaignManager.gd` | 46 | Merge into FallbackSystemsV2 | ⏳ Ready |
| `IGameSystem.gd` | 49 | Delete (interface only) | ⏳ Pending |

**Expected Reduction**: ~8 files

---

## 🔄 REVISED CONSOLIDATION PROCESS

### Phase 1: Systems Consolidation (Estimated: 5-7 hours - includes validation)

**Session 1.1: Game Constants (6 files → 1 file)**
1. Create `GameConstantsV2.gd` with all merged constants
2. Run: `grep -r "UIConstants\|BattleConstants" src/ tests/ > refs_constants.txt`
3. Update ALL references to use `GameConstantsV2`
4. Validate: `./validate_consolidation.sh "UIConstants|BattleConstants"`
5. Parse check: `godot --headless --check-only`
6. Test suite: `./run_test_suite.sh`
7. Delete original files: `git rm UIConstants.gd BattleConstants.gd ...`
8. Commit: `git commit -m "feat(consolidation): Merge 6 constants into GameConstantsV2"`

**Session 1.2: Universal Utilities (5 files → 1 file)**
(Repeat safe pattern from Session 1.1)

**Session 1.3: Table System (2 files → 1 file)**
(Repeat safe pattern from Session 1.1)

**Session 1.4: Fallback Systems (2 files → 1 file)**
(Repeat safe pattern from Session 1.1)

### Phase 2: Manager Consolidation (Estimated: 4-5 hours)

**Session 2.1: Enemy System Managers (2 files → 1 file)**
(Use safe pattern)

**Session 2.2: Campaign Event Managers (2 files → 1 file)**
(Use safe pattern)

**Session 2.3: World Resource Managers (3 files → 1 file)**
(Use safe pattern)

### Phase 3: Battle System (Estimated: 4-6 hours)

**Session 3.1: Battlefield Core (6 files → 1 file)**
(Use safe pattern)

**Session 3.2: Combat Resolution (3+ files → 1 file)**
(Use safe pattern)

**Session 3.3: Battle AI (3+ files → 1 file)**
(Use safe pattern)

---

## ⚠️ DO NOT CONSOLIDATE

Keep these files separate (Godot architecture requirements):

- Scene-attached scripts (*.tscn requires *.gd)
- Autoload singletons (registered in project.godot)
- Resource classes (used in exports)
- Base classes with inheritance chains
- Test helper files
- Files with external plugin dependencies

**Additional "Do Not Delete" Categories** (Learned from Nov 29):
- Files still referenced in *.tscn files (check with `grep -r "FileName" src/ --include="*.tscn"`)
- Files with `class_name` used in type hints across codebase
- Files with signal definitions used by other scripts

---

## 📈 EXPECTED RESULTS

| Metric | Before (Nov 28) | After Failed (Nov 29) | Target | Change |
|--------|--------|-------|--------|--------|
| Total .gd files | 441 | 470 | ~200 | -57% from current |
| `src/core/systems` | 43 | 45 | 24 | -47% |
| `src/core/managers` | 12 | 12 | 7 | -42% |
| `src/core/battle` | 29 | 32 | 15 | -53% |
| Small files (<50 lines) | 11 | 11 | 3 | -73% |

**Note**: File count increased due to restoring deleted files from git after failed consolidation.

---

## 🧪 VALIDATION CHECKLIST

After EACH consolidation session (before committing):

### Pre-Delete Validation (MANDATORY)
```bash
☐ Run reference check: grep -r "OldClassName" src/ tests/ | wc -l → 0
☐ Run parse check: godot --headless --check-only → No errors
☐ Run test suite: ./run_test_suite.sh → 76/79 passing (baseline)
☐ Check *.tscn references: grep -r "OldClassName" src/ --include="*.tscn" → 0
☐ Verify no class_name conflicts: Only ONE file with class_name NewClassName
```

### Post-Delete Validation (MANDATORY)
```bash
☐ Re-run parse check: godot --headless --check-only → No errors
☐ Re-run test suite: ./run_test_suite.sh → 76/79 passing (no regressions)
☐ Verify autoloads load: Check Godot console on startup
☐ Test critical paths:
   ☐ Campaign creation
   ☐ Save/Load
   ☐ Battle flow
   ☐ Character screen navigation
```

### Commit Checklist
```bash
☐ All validation passed
☐ Descriptive commit message
☐ Update this tracking table
☐ Update CLAUDE.md file count if milestone reached
```

---

## 📋 CONSOLIDATION TRACKING

Update this section after EACH successful session:

| Phase | Session | Files Reduced | Date | Status |
|-------|---------|---------------|------|--------|
| Phase 0 | Scene Fixes | 0 (fixes only) | 2025-11-29 | ✅ Complete |
| Phase 1.1 | Game Constants | 0 (rolled back) | 2025-11-29 | ❌ Failed (lessons learned) |
| Phase 1.1 RETRY | Game Constants | TBD | - | ⏳ Planned (use safe pattern) |
| Phase 1.2 | Universal Utilities | TBD | - | ⏳ Planned |
| Phase 1.3 | Table System | TBD | - | ⏳ Planned |
| Phase 1.4 | Fallback Systems | TBD | - | ⏳ Planned |
| Phase 2.1 | Enemy Managers | TBD | - | ⏳ Planned |
| Phase 2.2 | Event Managers | TBD | - | ⏳ Planned |
| Phase 2.3 | World Managers | TBD | - | ⏳ Planned |
| Phase 3.1 | Battlefield Core | TBD | - | ⏳ Planned |
| Phase 3.2 | Combat Resolution | TBD | - | ⏳ Planned |
| Phase 3.3 | Battle AI | TBD | - | ⏳ Planned |
| **Total** | - | **0** (net change after rollback) | - | In Progress |

**Target**: Reduce from 470 → 200 files (270 file reduction across all phases)

---

## 🎯 NEXT STEPS (Immediate)

### Session Priority Order

1. **Phase 1.1 RETRY: Game Constants** (Estimated: 1.5 hours)
   - Use SAFE pattern (GameConstantsV2 strategy)
   - Merge: UIConstants, BattleConstants, EnemyConstants, ItemConstants, WorldConstants, TradeConstants
   - Expected reduction: 6 → 1 (-5 files)
   - Success criteria: All validation checks pass, 76/79 tests still passing

2. **Phase 1.2: Universal Utilities** (Estimated: 1.5 hours)
   - Use SAFE pattern (UniversalUtilitiesV2 strategy)
   - Merge: StringUtils, ArrayUtils, DictUtils, MathUtils, ValidationUtils
   - Expected reduction: 5 → 1 (-4 files)

3. **Phase 1.3: Table System** (Estimated: 1 hour)
   - Use SAFE pattern (TableSystemV2 strategy)
   - Merge: TableLookup, TableManager
   - Expected reduction: 2 → 1 (-1 file)

### Success Metrics
- Zero parse errors after each consolidation
- Test suite maintains 76/79 passing baseline
- Each session committed separately
- File count decreases incrementally

### Blocker Prevention
- NEVER delete files without validation
- NEVER consolidate multiple groups in one session
- ALWAYS use versioned class_name (V2 strategy)
- ALWAYS run full grep check before deletion

---

## 📖 REFERENCE: Failed Consolidation Details (Nov 29, 2025)

### Files Created (Then Rolled Back)
1. `src/core/GameConstants.gd` (merged 6 files)
2. `src/core/utils/UniversalUtilities.gd` (merged 5 files)
3. `src/core/systems/TableSystem.gd` (merged 2 files)
4. `src/core/managers/EnemySystemManager.gd` (merged 2 files)
5. `src/core/managers/CampaignEventsManager.gd` (merged 2 files)
6. `src/core/managers/WorldResourceManager.gd` (merged 3 files)
7. `src/core/battle/BattlefieldCore.gd` (merged 6 files)

### Parse Errors Encountered
- `class_name` conflicts (multiple files defining same class_name)
- Missing references to deleted constants (UIConstants, BattleConstants)
- Broken preload() paths

### Rollback Command Used
```bash
git checkout HEAD -- src/core/systems/*.gd
git checkout HEAD -- src/core/managers/*.gd
git checkout HEAD -- src/core/battle/*.gd
git checkout HEAD -- src/core/utils/*.gd
git checkout HEAD -- src/core/GameConstants.gd
# Restored all deleted files
```

### Total Time Lost: ~2 hours (consolidation + debugging + rollback)
### Prevention: Use SAFE pattern (this document) - estimated time savings: ~10 hours over project

---

**Last Updated**: 2025-11-29
**Next Review**: After first successful consolidation session using SAFE pattern
