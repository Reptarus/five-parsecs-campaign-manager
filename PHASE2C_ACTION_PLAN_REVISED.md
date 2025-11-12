# Phase 2C Deduplication - REVISED ACTION PLAN 🎯

## ⚠️ REVISION NOTICE

After running verification script (`verify_phase2c_deletions.sh`), initial analysis has been refined. Some files flagged for deletion actually have references requiring migration work.

**This revision focuses on ZERO-RISK deletions only.**

---

## Executive Summary

**Current Status**: 456 .gd files in src/
**Target**: ~200 files (Framework Bible realistic goal)

**Phase 2C Revised Goal**: Delete 6 files (~350 lines) - ZERO RISK
**Conservative, verified approach**

---

## ✅ VERIFIED ZERO-RISK DELETIONS

### Batch 14: Orphaned Files (5 files, ~340 lines)

**VERIFIED SAFE - Zero references:**

1. ✅ **src/core/managers/LoanManager.gd** (83 lines)
   - **Verification**: 0 references
   - **Status**: Orphaned manager never integrated

2. ✅ **src/base/campaign/BaseCampaignManager.gd** (207 lines)
   - **Verification**: 0 references
   - **Status**: Template never extended or used

3. ✅ **src/game/missions/StreetFightMission.gd** (18 lines)
   - **Verification**: 0 references
   - **Status**: Stub never implemented

4. ✅ **src/game/missions/SalvageMission.gd** (22 lines)
   - **Verification**: 0 references
   - **Status**: Stub never implemented

5. ✅ **src/game/missions/StealthMission.gd** (28 lines)
   - **Verification**: 0 references
   - **Status**: Stub never implemented

**Total Batch 14**: 5 files, ~358 lines

---

### Batch 15: Unused Base Template (1 file, ~394 lines)

**VERIFIED SAFE - Zero references:**

1. ✅ **src/base/campaign/BaseMissionGenerator.gd** (394 lines)
   - **Verification**: 0 extends, 0 references
   - **Status**: Template never extended or used

**Total Batch 15**: 1 file, ~394 lines

---

## ⚠️ DEFERRED ITEMS (Require Migration Work)

### Batch 14 Deferred

**❌ DEFER - Has Active Usage:**

1. **src/core/battle/enemy/Enemy.gd** (4 lines)
   - **Verification**: 332 references (word "Enemy" appears everywhere)
   - **Actual Usage**: Extended by 6 enemy types, imported by 3 managers
   - **Issue**: Compatibility shim that extends base Enemy class
   - **Solution Needed**: Update 9 files to use base class directly
   - **Risk**: MEDIUM - requires reference migration
   - **Defer to**: Phase 3 (consolidation phase)

### Batch 15 Deferred

**❌ DEFER - Has References or Needs Analysis:**

2. **src/base/campaign/BaseCampaign.gd** (146 lines)
   - **Verification**: 54 references found (mostly string matches)
   - **Defer to**: Phase 3 - verify if references are in comments

3. **src/base/combat/BaseBattleCharacter.gd** (225 lines)
   - **Verification**: 4 references found
   - **Defer to**: Phase 3 - verify reference context

4. **src/base/combat/BaseBattleData.gd** (334 lines)
   - **Verification**: 2 references (preload + comment)
   - **Defer to**: Phase 3 - check if preload is used

5. **src/base/combat/BaseMainBattleController.gd** (571 lines)
   - **Verification**: 1 reference (comment in FiveParsecsCombatSystem)
   - **Defer to**: Phase 3 - verify comment-only usage

6. **src/base/combat/BaseCombatManager.gd** (578 lines)
   - **Verification**: 14 references found
   - **Defer to**: Phase 3 - extensive reference analysis needed

7. **src/base/combat/BaseBattleRules.gd** (668 lines)
   - **Verification**: 3 references (likely internal print statements)
   - **Defer to**: Phase 3 - verify internal vs external

8. **src/base/combat/battlefield/BaseBattlefieldManager.gd** (~300 lines)
   - **Verification**: 4 references found
   - **Defer to**: Phase 3 - reference analysis needed

---

## 📊 PHASE 2C REVISED IMPACT

### Conservative Verified Approach

```
Starting count:               456 files
Batch 14 (Verified Safe):    -5 files (~358 lines)
Batch 15 (Verified Safe):    -1 file (~394 lines)
─────────────────────────────────────────────────
Projected count:              450 files (~752 lines removed)
```

### Original Plan vs Revised

| Metric | Original Plan | Revised Plan |
|--------|--------------|--------------|
| Files to Delete | 14 | 6 |
| Lines Removed | ~3,578 | ~752 |
| Risk Level | "Zero" (unverified) | ZERO (verified) |
| Prep Work | None | None |
| Deferred Items | 0 | 8 |

**Lesson**: Verification script revealed that word-matching grep finds false positives. Conservative approach is safer.

---

## 🎯 EXECUTION STRATEGY FOR CURSOR

### Step 1: Run Verification (Already Done)

```bash
./verify_phase2c_deletions.sh
```

**Result**: 6/14 files verified safe (5 from Batch 14, 1 from Batch 15)

---

### Step 2: Execute Batch 14 (5 files)

```bash
# Delete verified orphaned files
git rm src/core/managers/LoanManager.gd
git rm src/base/campaign/BaseCampaignManager.gd
git rm src/game/missions/StreetFightMission.gd
git rm src/game/missions/SalvageMission.gd
git rm src/game/missions/StealthMission.gd
```

**Verify**: `godot --headless --quit --check-only`

**Commit**:
```bash
git commit -m "feat(phase2c-batch14): Delete 5 orphaned manager and stub mission files

Deleted files:
- LoanManager.gd (83 lines) - orphaned loan system never integrated
- BaseCampaignManager.gd (207 lines) - base template never extended
- StreetFightMission.gd (18 lines) - stub never implemented
- SalvageMission.gd (22 lines) - stub never implemented
- StealthMission.gd (28 lines) - stub never implemented

Total: 358 lines removed
Verification: Zero references confirmed via verification script
Risk: ZERO - all files completely orphaned"
```

---

### Step 3: Execute Batch 15 (1 file)

```bash
# Delete verified unused template
git rm src/base/campaign/BaseMissionGenerator.gd
```

**Verify**: `godot --headless --quit --check-only`

**Commit**:
```bash
git commit -m "feat(phase2c-batch15): Delete unused BaseMissionGenerator template

Deleted files:
- BaseMissionGenerator.gd (394 lines) - template never extended or used

Total: 394 lines removed
Verification: Zero extends, zero references confirmed
Risk: ZERO - template completely unused"
```

---

### Step 4: Generate Completion Report

Create `PHASE2C_SPRINT_COMPLETE.md` with:
- Files deleted: 6
- Lines removed: ~752
- Verification method: Automated script + manual review
- Deferred items: 8 files requiring migration analysis (Phase 3)

---

## 📋 PHASE 3 PREPARATION

### High Priority for Phase 3 Investigation

**Enemy.gd Migration** (4 lines, 9 files affected):
- Update 6 enemy type extends: Wildlife, Mercenaries, Enforcers, Cultists, Raiders, Pirates
- Update 3 manager imports: EliteLevelEnemiesManager, EnemyAIManager, EnemyTacticalAI
- Replace `res://src/core/battle/enemy/Enemy.gd` → `res://src/core/enemy/base/Enemy.gd`
- Risk: LOW-MEDIUM - straightforward find/replace, but affects battle system

**Base* Reference Analysis**:
1. Audit references in deferred Base* files
2. Determine if references are:
   - Comments/documentation (can ignore)
   - Actual preload/extends (needs migration)
   - String literals (can ignore)
3. Create migration plan for any active usage

**Consolidation Opportunities**:
- After Base* analysis, check if remaining base/ files can be consolidated
- Consider merging small managers (<200 lines)
- Equipment file consolidation (from original Batch 16)

---

## ✅ RECOMMENDED EXECUTION

### Phase 2C Conservative (6 files - EXECUTE THIS)

1. ✅ Verification already completed
2. 🗑️ Execute Batch 14 (5 orphaned files)
3. ✅ Verify with Godot headless
4. 💾 Commit Batch 14
5. 🗑️ Execute Batch 15 (1 unused template)
6. ✅ Verify with Godot headless
7. 💾 Commit Batch 15
8. 📝 Generate PHASE2C_SPRINT_COMPLETE.md

**Time Estimate**: 15-20 minutes
**Risk**: ZERO - verified safe deletions only
**Impact**: 6 files deleted, ~752 lines removed

---

## 📊 CUMULATIVE PROGRESS TRACKING

```
Original (estimated):         ~506 files
After Phase 1 (Batches 5-9):  476 files (-30)
After Phase 2A (Batches 10-11): 466 files (-10)
After Phase 2B (Batches 12-13): 456 files (-10)
After Phase 2C (Batches 14-15): 450 files (-6) [PROJECTED]
─────────────────────────────────────────────────
Total Reduction:              56 files (11.1%)
Remaining to Target (200):    250 files (55.6% more reduction needed)
```

**Note**: Original Phase 2C plan projected -14 files, but verification revealed 8 files need migration work first. Revised plan focuses on verified safe deletions only.

---

## 🚀 NEXT STEPS FOR CURSOR

### Immediate Actions

1. ✅ Review revised action plan
2. 🗑️ Execute Batch 14 (5 files - verified safe)
3. ✅ Verify with Godot
4. 💾 Commit Batch 14
5. 🗑️ Execute Batch 15 (1 file - verified safe)
6. ✅ Verify with Godot
7. 💾 Commit Batch 15
8. 📝 Generate completion report

### Phase 3 Planning

After Phase 2C completion:
1. Analyze deferred Base* files (8 files)
2. Plan Enemy.gd migration (9 files affected)
3. Continue small file consolidation
4. Target: additional 20-30 files

---

## 🎲 LESSONS LEARNED

### What This Revision Teaches

1. **Verification is Essential**: Initial grep analysis had false positives
2. **Conservative > Aggressive**: Better to defer than risk breakage
3. **Word Matching ≠ File Usage**: "Enemy" appears 332 times but only ~10 actual file references
4. **Comment References ≠ Code Dependencies**: Many "references" are just documentation

### Improved Verification Strategy

For future phases:
- ✅ Use verification script first
- ✅ Manually inspect flagged references
- ✅ Distinguish between:
  - File path preloads (real dependency)
  - extends ClassName (inheritance)
  - String matches (false positives)
  - Comments/docs (ignore)

---

## 🎯 SUCCESS CRITERIA

**Phase 2C will be considered successful when:**
- ✅ 6 verified files deleted
- ✅ ~752 lines removed
- ✅ Zero parse errors in Godot verification
- ✅ All commits pushed to branch
- ✅ Completion report generated
- ✅ Deferred items documented for Phase 3

---

*Generated: 2025-11-12 (REVISED after verification)*
*Branch: phase1-safe-deletions*
*Research by: Claude (Documentation Mode)*
*Execution by: Cursor CLI*
*Status: READY FOR EXECUTION*
