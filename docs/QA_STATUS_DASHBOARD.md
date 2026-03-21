# QA Status Dashboard

**Last Updated**: 2026-03-21
**Engine**: Godot 4.6-stable
**Overall Coverage**: ~65% runtime-verified (170/170 implemented)

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Game Mechanics Implemented | 170/170 (100%) |
| Mechanics Runtime-Verified | ~110/170 (~65%) |
| Open Bugs | 0 confirmed + 0 UX + 4 deferred |
| Unit Test Files | 40 (tests/unit/) |
| Integration Test Files | 22 (tests/integration/) |
| MCP Test Sessions Completed | 18+ (106 bugs found, 102 fixed) |
| Demo Path Status | PASS (CC-1→CC-11, 5 turns, save/reload) |

---

## Coverage by Category

| Category | Mechanics | NOT_TESTED | UNIT_TESTED | INTEGRATION_TESTED | MCP_VALIDATED | RULES_VERIFIED |
|----------|-----------|------------|-------------|-------------------|---------------|----------------|
| Character Creation | 20 | 2 | 8 | 4 | 6 | 0 |
| Campaign Phases | 49 | 10 | 5 | 10 | 24 | 0 |
| Economy & Trading | 16 | 4 | 4 | 2 | 6 | 0 |
| Equipment System | 17 | 5 | 2 | 2 | 8 | 0 |
| Ship System | 11 | 5 | 0 | 2 | 4 | 0 |
| Loot System | 14 | 0 | 10 | 2 | 2 | 0 |
| Battle Phase Manager | 8 | 1 | 4 | 1 | 2 | 0 |
| Compendium DLC | 35 | 20 | 2 | 2 | 11 | 0 |
| **TOTAL** | **170** | **47** | **35** | **25** | **63** | **0** |

> **Note**: Counts are estimates based on existing test files and MCP session results. See `QA_CORE_RULES_TEST_PLAN.md` for per-mechanic detail. "RULES_VERIFIED" requires cross-reference against Five Parsecs Core Rules text — none done yet.

---

## Open Bugs

### Confirmed Bugs

None — all confirmed bugs resolved as of 2026-03-20.

### UX Issues

None — all UX issues resolved as of 2026-03-20.

### Deferred Items (Blocked on Architecture/User Decision)

| Item | Blocker | Impact |
|------|---------|--------|
| WEALTH motivation resource bonus | Needs resource bonus system architecture | Gives +1 SAVVY instead of credits |
| 49% character bonus coverage | Blocked on resource bonus system | Most bonuses are no-ops |
| Equipment table naming | User decision pending | Generic vs Core Rules names |
| Victory condition metric tracking | Feature addition needed | Uses turns_played as proxy, not actual counters |

### Battle UI Bugs (Standalone-Mode Only)

7 bugs from `BATTLE_UI_QA_BUGS.md` affect only direct TacticalBattleUI launch (no `initialize_battle()` call). These do NOT affect normal campaign flow. See `docs/BATTLE_UI_QA_BUGS.md` for details.

---

## Risk Areas

| Area | Risk | Reason | Mitigation |
|------|------|--------|------------|
| Save/Load dual-sync | **HIGH** | BUG-031 was systemic — all setters must sync to 3 targets | Dual-sync regression test in integration scenarios |
| Three-enum sync | **HIGH** | GlobalEnums, GameEnums, FiveParsecsGameEnums must stay aligned manually | Automated enum comparison test needed |
| Character type shadowing | **MEDIUM** | BUG-088 pattern in 15+ files — `const Character = preload(...)` shadows class_name | Systemic fix pending |
| TweenFX pivot_offset | **MEDIUM** | 13 animations silently break without `pivot_offset = size / 2` | Checklist in QA_UX_UI_TEST_PLAN.md |
| Bug Hunt cross-contamination | **LOW** | Namespace isolation verified, temp_data keys prefixed | Integration scenario 4 |
| Difficulty enum format | **LOW** | Fixed Phase 30, but old saves with 1-5 values map incorrectly | Migration handling in GameState |

---

## Recently Completed QA Work

| Phase | Date | Scope | Bugs Found | Bugs Fixed |
|-------|------|-------|------------|------------|
| QA Playthrough | Mar 20, 2026 | 5-turn campaign (T3-T5): world→battle→post-battle→late phases. Sprint 9 runtime fixes. | 3 runtime | 3 (UpkeepPhaseComponent _help_dialog, CrewTaskComponent _help_dialog, TacticalBattleUI type inference) |
| QA Sprint | Mar 20, 2026 | BUG-033/034 + UX-091/092 fix sweep | 4 | 4 (BUG-033 was already fixed, confirmed; 3 code fixes) |
| Phase 33 | Mar 20, 2026 | Codebase optimization (12 sprints) — PostBattlePhase decomp, WorldPhaseComponent inheritance | 0 | 0 (refactor only) |
| Phase 32 | Mar 16, 2026 | 2-turn campaign playthrough + battle companion | 4 crashers | 4 (inline) |
| Phase 31 | Mar 16, 2026 | Bug fix sprint (10 bugs + 3 UX) | 13 | 13 |
| Phase 30 | Mar 16, 2026 | Core Rules parity — difficulty enum fix | 1 critical | 1 |
| Phase 29 | Mar 15, 2026 | 2-turn MCP playthrough, save/reload | 4 | 1 (inline) |
| Battle UI QA | Mar 15, 2026 | Battle phase UI audit | 18 | 11 |

---

## Completed Priority Items (Mar 21, 2026)

All 5 previous priority items are now verified:
- ~~5-turn campaign playthrough~~ — PASS (Turns 3-5, all counters consistent, 0 crashes)
- ~~Equipment save/reload lifecycle~~ — PASS (9-stage chain verified end-to-end)
- ~~Difficulty modifier matrix~~ — PASS (18/18 Core Rules, 40+ methods, 11 call sites)
- ~~PostBattlePhase subsystem regression~~ — PASS (19/19 signals, 100% emission isolation)
- ~~WorldPhaseComponent inheritance regression~~ — PASS (9/9 components, 3 runtime fixes applied)

## Next Priority Items

1. **Commit all changes** — ~99 uncommitted files (Phase 33 optimization + QA fixes + runtime fixes)
2. **47 NOT_TESTED mechanics** — Focus: Compendium DLC (20), Ship System (5), Equipment (5)
3. **RULES_VERIFIED column** — Cross-reference 170 mechanics against Core Rules text (0/170 done)
4. **Character type shadowing** — Systemic fix for `const Character = preload(...)` pattern in 15+ files
5. **Deferred architectural items** — WEALTH motivation resource bonuses, victory metric counters
6. **Integration gaps** — BattleJournal logging, NPCTracker gameplay calls, LegacySystem lifecycle
7. **Battle UI standalone mode** — 7 bugs only when TacticalBattleUI launched without campaign flow

---

## Cross-Reference Index

| Document | Location | Purpose |
|----------|----------|---------|
| **Core Rules Test Plan** | `docs/QA_CORE_RULES_TEST_PLAN.md` | Per-mechanic test status (170 mechanics) |
| **Integration Scenarios** | `docs/QA_INTEGRATION_SCENARIOS.md` | 9 end-to-end workflow test scripts |
| **UX/UI Test Plan** | `docs/QA_UX_UI_TEST_PLAN.md` | Systematic UI coverage (theme, responsive, animations) |
| UI/UX Session Walkthroughs | `docs/testing/UI_UX_TEST_PLAN.md` | 8-session walkthrough plan (~200 tests) |
| Demo QA Script | `docs/testing/DEMO_QA_SCRIPT.md` | Demo recording gate script |
| UIUX Test Results | `docs/UIUX_TEST_RESULTS.md` | Historical MCP results (106 bugs) |
| Battle UI Bugs | `docs/BATTLE_UI_QA_BUGS.md` | 18 battle-specific bugs |
| QA Sprint Results | `docs/QA_SPRINT_PHASE{29-32}_RESULTS.md` | Sprint-by-sprint findings |
| Game Mechanics Map | `docs/GAME_MECHANICS_IMPLEMENTATION_MAP.md` | 170 mechanics implementation status |
| Test Matrices | `.claude/skills/qa-specialist/references/test-matrices.md` | 1,355 combinatorial test cases |
| Edge Cases | `.claude/skills/qa-specialist/references/edge-cases.md` | 120+ boundary conditions |
| MCP Testing Guide | `.claude/skills/qa-specialist/references/mcp-testing-guide.md` | Automation recipes |
| gdUnit4 Patterns | `.claude/skills/qa-specialist/references/gdunit4-patterns.md` | Unit test templates |
| Data Consistency | `.claude/skills/qa-specialist/references/data-consistency.md` | Save/load schema validation |
| Signal Contracts | `.claude/skills/qa-specialist/references/cross-system-verification.md` | Cross-system signal verification |
| Bug Tracker | `.claude/skills/qa-specialist/references/bug-notes.md` | Canonical bug list (15 issues) |
| Playtesting Strategy | `docs/testing/EFFICIENT_PLAYTESTING_STRATEGY.md` | Testing methodology |
