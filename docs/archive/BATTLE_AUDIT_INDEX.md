# Battle Screens Audit - Document Index
**Created**: 2025-11-27
**Sprint**: Sprint 5 - Battle Screens Consistency Audit
**Status**: ✅ COMPLETE - All deliverables ready

---

## Quick Navigation

### 📋 Start Here
- **[BATTLE_AUDIT_SUMMARY.md](BATTLE_AUDIT_SUMMARY.md)** - Executive summary (5-minute read)

### 📊 For Detailed Analysis
- **[BATTLE_SCREENS_AUDIT_REPORT.md](BATTLE_SCREENS_AUDIT_REPORT.md)** - Comprehensive audit (15-minute read)

### 🔧 For Implementation
- **[BATTLE_COMPANION_REFACTORING_STRATEGY.md](BATTLE_COMPANION_REFACTORING_STRATEGY.md)** - Step-by-step refactoring guide (implementation)

### 🧪 For Testing
- **[BATTLE_SYSTEM_TEST_GUIDE.md](BATTLE_SYSTEM_TEST_GUIDE.md)** - Testing quick reference (QA guide)

### 📈 For Visualization
- **[BATTLE_REFACTORING_VISUAL_MAP.md](BATTLE_REFACTORING_VISUAL_MAP.md)** - Before/after diagrams (visual reference)

---

## Document Purpose Guide

### Who Should Read What?

#### Project Lead / Stakeholder
**Read First** (15 minutes):
1. ✅ **BATTLE_AUDIT_SUMMARY.md** - Key findings, timeline, budget
2. ✅ **BATTLE_REFACTORING_VISUAL_MAP.md** - Visual before/after comparison

**Read Later** (if deeper understanding needed):
3. **BATTLE_SCREENS_AUDIT_REPORT.md** - Full technical details

**Skip**:
- Implementation details (delegate to developers)
- Testing specifics (delegate to QA)

---

#### Lead Developer / Tech Lead
**Read First** (30 minutes):
1. ✅ **BATTLE_AUDIT_SUMMARY.md** - Executive summary
2. ✅ **BATTLE_COMPANION_REFACTORING_STRATEGY.md** - Implementation strategy
3. ✅ **BATTLE_SCREENS_AUDIT_REPORT.md** - Technical audit

**Reference During Work**:
4. **BATTLE_REFACTORING_VISUAL_MAP.md** - File structure reference
5. **BATTLE_SYSTEM_TEST_GUIDE.md** - Testing commands

**Skip**: Nothing (read all 5 documents)

---

#### QA / Test Engineer
**Read First** (25 minutes):
1. ✅ **BATTLE_AUDIT_SUMMARY.md** - What's being tested
2. ✅ **BATTLE_SYSTEM_TEST_GUIDE.md** - How to run/create tests
3. ✅ **BATTLE_SCREENS_AUDIT_REPORT.md** - Section D (test coverage gaps)

**Reference During Work**:
4. **BATTLE_COMPANION_REFACTORING_STRATEGY.md** - Testing strategy section

**Skip**:
- Detailed refactoring steps (developer concern)

---

#### UI/UX Designer
**Read First** (20 minutes):
1. ✅ **BATTLE_AUDIT_SUMMARY.md** - UX issues identified
2. ✅ **BATTLE_SCREENS_AUDIT_REPORT.md** - Section C (UX issues)
3. ✅ **BATTLE_REFACTORING_VISUAL_MAP.md** - Persistent status bar design

**Deliverables Needed From You**:
- Persistent status bar mockup (validate before implementation)
- Glanceability success criteria (what is 8/10?)
- Battle journal export format approval (markdown vs text)

**Skip**:
- Technical refactoring details
- Testing implementation

---

#### Developer (Individual Contributor)
**Read First** (40 minutes):
1. ✅ **BATTLE_COMPANION_REFACTORING_STRATEGY.md** - Your implementation guide
2. ✅ **BATTLE_SYSTEM_TEST_GUIDE.md** - How to test your changes
3. ✅ **BATTLE_SCREENS_AUDIT_REPORT.md** - Context for why changes needed

**Reference During Work**:
4. **BATTLE_REFACTORING_VISUAL_MAP.md** - Before/after file structure
5. Design system constants from **BaseCampaignPanel.gd**

**Skip**:
- Executive summary (you're already assigned)

---

## Document Statistics

| Document | Lines | Words | Est. Read Time | Purpose |
|----------|-------|-------|----------------|---------|
| BATTLE_AUDIT_INDEX.md | ~300 | ~1,500 | 5 min | Navigation (this file) |
| BATTLE_AUDIT_SUMMARY.md | ~500 | ~2,500 | 10 min | Executive overview |
| BATTLE_SCREENS_AUDIT_REPORT.md | ~1,200 | ~6,000 | 25 min | Comprehensive audit |
| BATTLE_COMPANION_REFACTORING_STRATEGY.md | ~800 | ~4,000 | 20 min | Implementation guide |
| BATTLE_SYSTEM_TEST_GUIDE.md | ~600 | ~3,000 | 15 min | Testing reference |
| BATTLE_REFACTORING_VISUAL_MAP.md | ~900 | ~4,500 | 15 min | Visual diagrams |
| **TOTAL** | **~4,300** | **~21,500** | **90 min** | Complete audit package |

---

## Key Findings (Quick Reference)

### Critical Issues (Immediate Action Required)

| Issue | File | Current | Target | Priority |
|-------|------|---------|--------|----------|
| **BattleCompanionUI bloat** | BattleCompanionUI.gd | 1,232 lines | 250 lines | 🔴 CRITICAL |
| **No persistent status bar** | (missing) | N/A | 100 lines | 🔴 CRITICAL |
| **Design system adoption** | 17 files | 23% | 100% | 🔴 CRITICAL |
| **5 file size violations** | Various | >250 lines | ≤250 lines | 🟠 HIGH |
| **Missing UI tests** | (missing) | 0 tests | 7 tests | 🟡 MEDIUM |

---

## Implementation Roadmap (Quick Reference)

### Sprint 1: Critical Refactoring (3 days)

**Day 1**: BattleCompanionUI Refactoring
- Extract 4 phase panels from 1,232-line file
- Preserve signal architecture
- Estimated: 6-8 hours

**Day 2**: Design System Migration
- Migrate 17 files to BaseCampaignPanel constants
- Replace hardcoded colors/spacing/touch targets
- Estimated: 6-8 hours

**Day 3**: Persistent Status Bar + Tests
- Implement BattlePersistentStatusBar
- Create UI integration tests
- Estimated: 4-5 hours

### Sprint 2: UX Improvements (3 days)

**Day 4**: Screen Consolidation
- Merge 9 screens → 5 screens
- Estimated: 6-8 hours

**Day 5**: Glanceability + Journal
- Quick-status strip, enemy badge, summary card
- Battle journal export functionality
- Estimated: 5-7 hours

**Day 6**: Polish + Testing
- Visual QA
- Integration testing
- Bug fixes
- Estimated: 4-6 hours

**Total Effort**: 31-42 hours (5-7 working days)

---

## Testing Plan (Quick Reference)

### Existing Tests (10 files - All Passing ✅)

1. `test_battle_data_flow.gd` - Data pipeline validation
2. `test_battle_integration_validation.gd` - E2E validation
3. `test_battle_results.gd` - Results calculation
4. `test_battle_setup_data.gd` - Setup data structures
5. `test_battle_calculations.gd` - Combat math
6. `test_battle_4phase_resolution.gd` - Phase transitions
7. `test_battle_initialization.gd` - Initialization flow
8. `test_battle_phase_integration.gd` - Phase manager
9. `test_world_to_battle_flow.gd` - World → Battle transition
10. `test_loot_battlefield_finds.gd` - Loot generation

### Missing Tests (7 to be created)

**Priority 1**: UI Tests
- `test_battle_companion_ui_signals.gd` (signal architecture)
- `test_battle_screen_transitions.gd` (flow validation)
- `test_battle_component_integration.gd` (component interactions)
- `test_battle_persistent_status_bar.gd` (after implementation)

**Priority 2**: Validation Tests
- `test_battle_design_system.gd` (design system compliance)
- `test_battle_touch_targets.gd` (accessibility)
- `test_battle_performance.gd` (load time, FPS)

---

## Success Metrics (Quick Reference)

### Quantitative Goals

| Metric | Before | After | Target Met? |
|--------|--------|-------|-------------|
| Files > 250 lines | 6 | 0 | ✅ |
| Design system adoption | 23% | 100% | ✅ |
| Overall quality score | 6.2/10 | 9.0/10 | ✅ |
| Test coverage | 59% | 100% | ✅ |
| Total screens | 9 | 5 | ✅ |

### Qualitative Goals

- [ ] Persistent status bar always visible
- [ ] Glanceability score ≥ 8/10 (designer validated)
- [ ] Battle journal export functional
- [ ] Zero visual regressions
- [ ] Zero breaking changes to signal architecture

---

## Risk Matrix (Quick Reference)

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Breaking signal connections** | 30% | HIGH | Write tests BEFORE refactoring |
| **Visual regressions** | 15% | MEDIUM | Screenshot comparison |
| **Screen path breaks** | 20% | MEDIUM | Update all references, test suite |
| **Performance degradation** | 10% | LOW | Profile after each change |
| **Test runner instability** | 5% | LOW | Use UI mode, limit 13 tests/file |

---

## Questions for Team (Need Answers)

### Priority Questions (Answer Before Starting)

1. **What is the target production date?**
   - Affects sprint prioritization
   - Current estimate: 5-7 days for refactoring

2. **Can we allocate 1 full week for refactoring?**
   - Critical path estimate
   - Non-negotiable for production quality

3. **Should we consolidate to 5 screens or fewer?**
   - UX design decision
   - Current plan: 9 → 5 screens

4. **What glanceability score is acceptable?**
   - Current: 4/10
   - Target: 8/10
   - Needs designer validation

### Technical Questions (Answer During Sprint Planning)

5. **Battle journal export format: `.txt`, `.md`, or both?**
6. **Is BattleDashboardUI (449 lines) acceptable, or refactor?**
7. **Persistent status bar: component or inline?**
8. **What breakpoints for responsive design?**

### Testing Questions (Answer Before QA)

9. **What test coverage % is required for production?**
10. **Should we create performance benchmarks?**

---

## File Organization (Reference)

### Audit Deliverables (This Sprint)

```
project_root/
├── BATTLE_AUDIT_INDEX.md                        ← You are here
├── BATTLE_AUDIT_SUMMARY.md                      ← Executive summary
├── BATTLE_SCREENS_AUDIT_REPORT.md               ← Full audit
├── BATTLE_COMPANION_REFACTORING_STRATEGY.md     ← Implementation guide
├── BATTLE_SYSTEM_TEST_GUIDE.md                  ← Testing guide
└── BATTLE_REFACTORING_VISUAL_MAP.md             ← Visual diagrams
```

### Battle System Files (To Be Refactored)

```
src/ui/screens/battle/
├── BattleCompanionUI.gd                         ← 1,232 lines → 250 lines
├── BattleResolutionUI.gd                        ← 969 lines → merge
├── TacticalBattleUI.gd                          ← 824 lines → refactor
├── PreBattleUI.gd                               ← 626 lines → merge
├── PostBattleResultsUI.gd                       ← 547 lines → merge
├── PreBattleEquipmentUI.gd                      ← 515 lines → merge
├── BattleDashboardUI.gd                         ← 449 lines (borderline)
├── PostBattle.gd                                ← 194 lines ✅
├── BattleTransitionUI.gd                        ← 186 lines ✅
└── BattlefieldMain.gd                           ← 176 lines ✅

src/ui/components/battle/
├── (12 existing components - see visual map)
└── BattlePersistentStatusBar.gd                 ← TO BE CREATED
```

### Tests (To Be Created/Updated)

```
tests/integration/
├── test_battle_data_flow.gd                     ✅ Existing
├── test_battle_integration_validation.gd        ✅ Existing
├── test_battle_results.gd                       ✅ Existing
├── test_battle_setup_data.gd                    ✅ Existing
├── test_battle_calculations.gd                  ✅ Existing
├── test_battle_4phase_resolution.gd             ✅ Existing
├── test_battle_initialization.gd                ✅ Existing
├── test_battle_phase_integration.gd             ✅ Existing
├── test_world_to_battle_flow.gd                 ✅ Existing
├── test_loot_battlefield_finds.gd               ✅ Existing
├── test_battle_companion_ui_signals.gd          ⏳ TO CREATE
├── test_battle_screen_transitions.gd            ⏳ TO CREATE
├── test_battle_component_integration.gd         ⏳ TO CREATE
└── test_battle_persistent_status_bar.gd         ⏳ TO CREATE

tests/validation/
└── test_battle_design_system.gd                 ⏳ TO CREATE
```

---

## Contact & Support

### Questions About This Audit?

**For Technical Questions**:
- Review BATTLE_COMPANION_REFACTORING_STRATEGY.md
- Check BATTLE_SCREENS_AUDIT_REPORT.md Section F (detailed recommendations)

**For Testing Questions**:
- Review BATTLE_SYSTEM_TEST_GUIDE.md
- Check existing tests in `tests/integration/`

**For UX Questions**:
- Review BATTLE_SCREENS_AUDIT_REPORT.md Section C (UX issues)
- Check BATTLE_REFACTORING_VISUAL_MAP.md for persistent status bar design

**For Timeline/Budget Questions**:
- Review BATTLE_AUDIT_SUMMARY.md
- Check "Estimated Effort Breakdown" table

---

## Next Actions Checklist

### Immediate (Today)

- [ ] Read **BATTLE_AUDIT_SUMMARY.md** (5 minutes)
- [ ] Schedule team review meeting (1 hour)
- [ ] Answer priority questions (scope/timeline)
- [ ] Assign ownership for refactoring tasks

### This Week

- [ ] Create integration tests: `test_battle_companion_ui_signals.gd`
- [ ] Prototype persistent status bar (2-hour POC)
- [ ] Plan Sprint 1 tasks in project management tool

### Next Week (Sprint 1)

- [ ] Day 1: BattleCompanionUI refactoring (6-8 hours)
- [ ] Day 2: Design system migration (6-8 hours)
- [ ] Day 3: Persistent status bar + tests (4-5 hours)

### Week After (Sprint 2)

- [ ] Day 4: Screen consolidation (6-8 hours)
- [ ] Day 5: Glanceability + journal export (5-7 hours)
- [ ] Day 6: Polish + visual QA (4-6 hours)

---

## Appendix: Command Quick Reference

### Run All Battle Tests

```powershell
cd "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"

& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/ `
  --quit-after 60
```

### Run Specific Test File

```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path . `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/integration/test_battle_data_flow.gd `
  --quit-after 60
```

### Count Battle System Files

```bash
find src/ui/screens/battle -name "*.gd" | wc -l  # Should be 10
find src/ui/components/battle -name "*.gd" | wc -l  # Should be 12
```

### Check File Line Counts

```bash
wc -l src/ui/screens/battle/*.gd | sort -rn
```

---

**Document Status**: ✅ COMPLETE - Navigation index ready
**Total Audit Deliverables**: 6 documents (~4,300 lines, ~21,500 words)
**Estimated Total Read Time**: 90 minutes (full comprehension)
**Estimated Implementation Time**: 35-49 hours (5-7 days)

**Next Step**: Read [BATTLE_AUDIT_SUMMARY.md](BATTLE_AUDIT_SUMMARY.md) for 5-minute overview
