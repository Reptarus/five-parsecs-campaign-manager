# Phase 2C Deduplication - ACTION PLAN 🎯

## Executive Summary

**Current Status**: 456 .gd files in src/
**Target**: ~200 files (Framework Bible realistic goal)
**Gap**: 256 files to eliminate (56% reduction needed)

**Phase 2C Goal**: Delete 15-20 files (~1,000-1,500 lines)
**Estimated New Total**: 436-441 files

---

## 🚨 HIGH-PRIORITY DELETION TARGETS

### Batch 14: Orphaned Manager Files (5 files, ~700 lines)

**DELETE - Zero References Found:**

1. **src/core/managers/LoanManager.gd** (83 lines)
   - **References**: ZERO (only self)
   - **Rationale**: Functional loan system never integrated
   - **Risk**: ✅ ZERO - completely orphaned

2. **src/base/campaign/BaseCampaignManager.gd** (207 lines)
   - **References**: ZERO (only self)
   - **Rationale**: Base template never extended
   - **Risk**: ✅ ZERO - no inheritance usage

3. **src/core/battle/enemy/Enemy.gd** (4 lines)
   - **Content**: Compatibility shim extending base Enemy class
   - **Rationale**: Simple redirect that can be replaced
   - **Risk**: ✅ LOW - update references to base class directly

4. **src/game/missions/StreetFightMission.gd** (18 lines)
   - **References**: ZERO
   - **Content**: Stub with print statements
   - **Risk**: ✅ ZERO - never implemented

5. **src/game/missions/SalvageMission.gd** (22 lines)
   - **References**: ZERO
   - **Content**: Stub with print statements
   - **Risk**: ✅ ZERO - never implemented

6. **src/game/missions/StealthMission.gd** (28 lines)
   - **References**: ZERO
   - **Content**: Stub with print statements
   - **Risk**: ✅ ZERO - never implemented

**Total Batch 14**: 6 files, ~362 lines

---

### Batch 15: Unused Base* Classes (8 files, ~3,200 lines)

**Base classes that are NOT extended anywhere:**

1. **src/base/campaign/BaseCampaign.gd** (146 lines)
   - **Extended by**: NONE
   - **Rationale**: Template never used

2. **src/base/combat/BaseBattleCharacter.gd** (225 lines)
   - **Extended by**: NONE
   - **Rationale**: Template never used

3. **src/base/combat/BaseBattleData.gd** (334 lines)
   - **Extended by**: NONE
   - **Rationale**: Template never used

4. **src/base/campaign/BaseMissionGenerator.gd** (394 lines)
   - **Extended by**: NONE
   - **Rationale**: Template never used

5. **src/base/combat/BaseMainBattleController.gd** (571 lines)
   - **Extended by**: NONE
   - **Rationale**: Template never used

6. **src/base/combat/BaseCombatManager.gd** (578 lines)
   - **Extended by**: NONE
   - **Rationale**: Template never used

7. **src/base/combat/BaseBattleRules.gd** (668 lines)
   - **Extended by**: NONE
   - **Rationale**: Template never used

8. **src/base/combat/battlefield/BaseBattlefieldManager.gd** (~300 lines est.)
   - **Extended by**: NONE
   - **Rationale**: Template never used

**Total Batch 15**: 8 files, ~3,216 lines

**NOTE**: These Base* classes were originally designed as templates for inheritance, but the actual implementation went in a different direction. They're now dead code.

---

### Batch 16: Small Files - Framework Bible Violations (<50 lines)

**Candidates for consolidation or deletion:**

**Consolidation Targets:**
- src/core/character/Equipment/base/gear.gd (8 lines)
- src/base/items/equipment.gd (29 lines)
- src/core/character/Equipment/implementations/five_parsecs_gear.gd (28 lines)
- src/core/character/Equipment/implementations/five_parsecs_equipment.gd (42 lines)
- src/core/character/Equipment/FiveParsecsArmor.gd (37 lines)

**Strategy**: Consolidate these 5 small equipment files into a single Equipment.gd file (~144 lines combined)

**UI Consolidation:**
- src/ui/screens/campaign/CampaignSummaryPanel.gd (32 lines)
- src/ui/screens/GameOverScreen.gd (45 lines)
- src/ui/components/victory/VictoryOption.gd (44 lines)

**Strategy**: Merge these 3 UI files into their parent components or a single EndGameUI.gd (~121 lines combined)

**System Files:**
- src/core/settings/SystemEnhancements.gd (24 lines)
- src/core/systems/ErrorLogger.gd (45 lines)
- src/core/systems/IGameSystem.gd (49 lines)

**Strategy**: Consolidate into CoreSystemUtilities.gd or inline into existing systems (~118 lines combined)

**Total Batch 16**: 11 files deleted → 3 new files created (net -8 files, ~383 lines → ~383 lines consolidated)

---

## 📊 PHASE 2C PROJECTED IMPACT

### Conservative Estimate (Batches 14-15 Only)

```
Starting count:               456 files
Batch 14 (Orphaned):          -6 files
Batch 15 (Base* unused):      -8 files
─────────────────────────────────────
Projected count:              442 files (~3,578 lines removed)
```

### Aggressive Estimate (Batches 14-16)

```
Starting count:               456 files
Batch 14 (Orphaned):          -6 files
Batch 15 (Base* unused):      -8 files
Batch 16 (Consolidation):     -8 files (net)
─────────────────────────────────────
Projected count:              434 files (~3,961 lines removed/consolidated)
```

---

## 🔍 ADDITIONAL RESEARCH FINDINGS

### Base Classes Actually Being Used (DO NOT DELETE)

✅ **KEEP - Active Usage:**
- src/ui/screens/campaign/controllers/BaseController.gd (239 lines)
  - Extended by: 2 controllers
  - Has UniversalControllerUtilities consolidated into it (Phase 2B)

- src/base/ui/BaseCrewComponent.gd (450 lines est.)
  - Extended by: 2 components
  - Active crew management functionality

- src/base/items/armor.gd (small file)
  - Extended by: equipment implementations

### Manager Hierarchy Analysis

**Multiple Overlapping Campaign Managers Found:**
- src/core/managers/CampaignManager.gd (1,197 lines) - **PRIMARY**
- src/core/campaign/CampaignPhaseManager.gd - Phase orchestration
- src/core/campaign/GameCampaignManager.gd - Game-specific logic
- src/base/campaign/BaseCampaignManager.gd (207 lines) - **ORPHANED (DELETE)**

**Recommendation**: Defer consolidation of the production CampaignManager files to Phase 3. BaseCampaignManager can be safely deleted now (Phase 2C Batch 14).

### Small Manager Files (<200 lines)

Potential Phase 3 consolidation targets (DEFER FOR NOW):
- LoanManager.gd (83 lines) - **DELETE in Batch 14 (orphaned)**
- EscalatingBattlesManager.gd (133 lines)
- EnemyManager.gd (134 lines)
- SectorManager.gd (161 lines)
- AdvTrainingManager.gd (171 lines)
- EliteLevelEnemiesManager.gd (183 lines)
- GalacticWarManager.gd (187 lines)

**Note**: Need to verify usage before considering consolidation (not part of Phase 2C).

---

## 🎯 EXECUTION STRATEGY FOR CURSOR

### Batch 14: Direct Deletion (Zero Risk)

**No preparatory work needed - straight deletion:**

```bash
# Verify zero references first
for file in \
  "src/core/managers/LoanManager.gd" \
  "src/base/campaign/BaseCampaignManager.gd" \
  "src/game/missions/StreetFightMission.gd" \
  "src/game/missions/SalvageMission.gd" \
  "src/game/missions/StealthMission.gd"; do
  echo "=== $file ==="
  grep -r "$(basename "$file" .gd)" src --include="*.gd" | grep -v "^$file:" | head -5
done

# If zero references confirmed, delete:
git rm src/core/managers/LoanManager.gd
git rm src/base/campaign/BaseCampaignManager.gd
git rm src/game/missions/StreetFightMission.gd
git rm src/game/missions/SalvageMission.gd
git rm src/game/missions/StealthMission.gd

# Special case: Enemy.gd shim (4 lines)
# First find references and update to use base class directly:
grep -r "res://src/core/battle/enemy/Enemy.gd" src --include="*.gd" -l
# Update those references to: res://src/core/enemy/base/Enemy.gd
# Then delete the shim
```

**Verification**: `godot --headless --quit --check-only`

**Commit**: `feat(phase2c-batch14): Delete 6 orphaned manager and stub mission files`

---

### Batch 15: Base* Class Deletion (Zero Risk)

**No preparatory work needed - templates never extended:**

```bash
# Verify zero inheritance usage first
grep -r "extends Base" src/core src/ui --include="*.gd" | grep -E "(BaseCampaign|BaseBattleCharacter|BaseBattleData|BaseMissionGenerator|BaseMainBattleController|BaseCombatManager|BaseBattleRules|BaseBattlefieldManager)"

# If zero results, safe to delete:
git rm src/base/campaign/BaseCampaign.gd
git rm src/base/combat/BaseBattleCharacter.gd
git rm src/base/combat/BaseBattleData.gd
git rm src/base/campaign/BaseMissionGenerator.gd
git rm src/base/combat/BaseMainBattleController.gd
git rm src/base/combat/BaseCombatManager.gd
git rm src/base/combat/BaseBattleRules.gd
git rm src/base/combat/battlefield/BaseBattlefieldManager.gd
```

**Verification**: `godot --headless --quit --check-only`

**Commit**: `feat(phase2c-batch15): Delete 8 unused Base* template classes`

---

### Batch 16: Small File Consolidation (OPTIONAL - DEFER IF COMPLEX)

**Requires consolidation work - similar to Phase 2B Batch 12:**

1. **Equipment Consolidation**:
   - Create `src/core/character/Equipment/Equipment.gd` (consolidate 5 files)
   - Update imports in affected files
   - Delete original 5 small files

2. **UI Consolidation**:
   - Create `src/ui/EndGameUI.gd` or merge into existing UI files
   - Update scene references
   - Delete original 3 small files

3. **System Utilities**:
   - Inline into existing CoreSystems.gd or create CoreSystemUtilities.gd
   - Update references
   - Delete original 3 small files

**Recommendation for Cursor**: DEFER Batch 16 to Phase 3 if time-constrained. Batches 14-15 provide excellent value with zero risk.

---

## ✅ RECOMMENDED APPROACH FOR CURSOR

### Phase 2C Minimum (Batches 14-15)

1. ✅ Execute Batch 14 (6 orphaned files)
2. ✅ Verify with Godot headless
3. ✅ Commit Batch 14
4. ✅ Execute Batch 15 (8 Base* templates)
5. ✅ Verify with Godot headless
6. ✅ Commit Batch 15
7. ✅ Generate PHASE2C_SPRINT_COMPLETE.md

**Time Estimate**: 30-45 minutes
**Risk**: ZERO - all targets are orphaned or unused templates
**Impact**: 14 files deleted, ~3,578 lines removed

### Phase 2C Extended (Add Batch 16 - Optional)

8. 📋 Plan consolidation strategy for Batch 16
9. 🔧 Create consolidated files
10. 🔄 Update references
11. 🗑️ Delete original small files
12. ✅ Verify and commit

**Additional Time**: 1-2 hours
**Risk**: LOW - requires reference updates (similar to Phase 2B Batch 12)
**Additional Impact**: 8 net files deleted (11 → 3 consolidated)

---

## 📋 DEFERRED ITEMS (Phase 3+)

### High Priority Deferrals

1. **SafeDataAccess Consolidation** (from Phase 1)
   - API mismatch with DataValidator
   - 6 files affected
   - Requires manual refactoring

2. **Manager Hierarchy Consolidation**
   - Multiple overlapping managers
   - CampaignPhaseManager + GameCampaignManager potentially consolidatable
   - Need usage analysis first

3. **Small Managers (<200 lines)**
   - EscalatingBattlesManager.gd (133 lines)
   - EnemyManager.gd (134 lines)
   - SectorManager.gd (161 lines)
   - Others listed above
   - Need reference count verification

### Low Priority Deferrals

4. **Base/ Directory Cleanup**
   - After Phase 2C, check if entire src/base can be removed
   - Only BaseController, BaseCrewComponent, and armor.gd are actively used
   - Consider consolidating these 3 into production code

5. **Empty Directory Removal**
   - Phase 2A identified 26 empty directories
   - Clean up after major deletion phases complete

---

## 🎲 FIVE PARSECS FOCUS

Remember the project goal from BLOAT_REMOVAL_COMPLETE.md:

> **The bloat is gone. Time to build Five Parsecs!** 🎲

Phase 2C continues the bloat removal mission:
- Delete orphaned managers that were never integrated
- Remove unused Base* template classes from abandoned architecture
- Consolidate tiny files that violate Framework Bible principles

**After Phase 2C**: The codebase will have ~442 files (down from 506 at Phase 1 start), representing a **64-file reduction (12.6%)** with more work ahead to reach the ~200 file target.

---

## 📊 CUMULATIVE PROGRESS TRACKING

```
Original (estimated):         ~506 files
After Phase 1 (Batches 5-9):  476 files (-30)
After Phase 2A (Batches 10-11): 466 files (-10)
After Phase 2B (Batches 12-13): 456 files (-10)
After Phase 2C (Batches 14-15): 442 files (-14) [PROJECTED]
─────────────────────────────────────────────────
Total Reduction:              64 files (12.6%)
Remaining to Target (200):    242 files (54.8% more reduction needed)
```

---

## 🚀 NEXT STEPS FOR CURSOR

1. **Review this action plan**
2. **Execute Batch 14** (orphaned files - straight deletion)
3. **Verify with Godot**
4. **Commit Batch 14**
5. **Execute Batch 15** (Base* templates - straight deletion)
6. **Verify with Godot**
7. **Commit Batch 15**
8. **Generate completion report** (PHASE2C_SPRINT_COMPLETE.md)
9. **(Optional)** Execute Batch 16 if time permits

**Focus**: Pure execution of zero-risk deletions. All research is complete.

---

*Generated: 2025-11-12*
*Branch: phase1-safe-deletions*
*Research by: Claude (Documentation Mode)*
*Execution by: Cursor CLI*
