# Phase 31 QA Sprint — Full 3-Turn Campaign Playthrough

**Date**: 2026-03-16
**Tester**: Claude Code (MCP-automated)
**Scope**: Full campaign creation + 2-turn playthrough + battle phase manager testing + save/reload verification
**Engine**: Godot 4.6-stable
**Goal**: Simulate real tabletop companion user experience across maximum feature coverage

---

## Executive Summary

Completed campaign creation (7 steps) + 1 full turn + partial Turn 2 (crashed at battle initiative roll). Found **11 new bugs** (3 P0/P1 crashers, 4 P1 data issues, 4 P2 functional issues) and documented **30+ UX observations**. The most critical finding is that **save/reload loses all gameplay progress** — turns_played, credits, missions, and battle stats revert to creation defaults.

### Blockers Preventing Full 3-Turn Demo

1. **BUG-043 (P0)**: Initiative roll crashes — cannot complete a battle through the UI
2. **BUG-037 (P0)**: Crew creation crashes (FIXED during QA — null guard applied)
3. **BUG-031 regression**: Save/reload doesn't preserve gameplay progress

---

## Test Coverage

| Area | Steps | Result | Notes |
|------|-------|--------|-------|
| Main Menu launch | CC-1 | PASS | 8 buttons, no critical errors |
| Campaign Config | CC-2 to CC-4 | PASS | Name, VCs, difficulty all propagate |
| Victory Condition selection | CC-3 | PASS | BUG-029 fix verified (dual VC selection works) |
| Captain Creation (Random) | CC-5/CC-6 | PASS | Stats + origin correct |
| Captain Edit | CC-9 | **CRASH** | BUG-036: Type mismatch BaseCharacterResource vs Character |
| Crew Randomize All | CC-7/CC-8 | **CRASH→FIXED** | BUG-037: Nil stat bonus. Fixed with null guard |
| Equipment Assignment | CC-10 | PASS | 3 items generated, auto-assign works |
| Ship Generation | CC-10 | PASS | Hull 10 (6-14), Debt 1 (0-5), Armed Trader |
| World Generation | CC-10 | PASS | Government + Tech Level present |
| Final Review | CC-11 | PASS | Name + VCs propagated E2E |
| Upkeep Phase | T1-C | PASS | 5cr auto-calculated, credits deducted |
| Crew Tasks | T1-C4/C5 | PASS | 4/4 tasks assigned + resolved |
| Job Offers | T1-C5 | PASS | 4 jobs, dedup working |
| Mission Prep | T1-C6/C7 | PASS | Briefing correct, 0 equipment on crew (BUG-035) |
| Pre-Battle UI | T1-D1 | PASS | 3-column layout, crew pre-selected |
| Tactical Battle UI | T1-D2 | PASS | Map, checklist, dice, tier selector all work |
| Battle Setup Checklist | T1-D2 | PASS | All items checkable, dice rolls inline |
| Battle Initiative Roll | — | **CRASH** | BUG-043: 'seized' property not on InitiativeResult |
| Auto-Resolve Battle | T1-D3 | PASS | Programmatic resolution works |
| Post-Battle (14 steps) | T1-E | PASS | All 14 steps advance without crashes |
| Advancement Phase | T1-F | PASS | 4 crew at Level 1 |
| Trading Phase | T1-G | PASS | Buy/sell work, credits update correctly |
| Character Events | T1-H | PASS | 4 unique D100 events |
| Turn End Summary | T1-I | PASS | All stats correct in display |
| Save Campaign | SR-1 | PASS | File written to disk |
| Reload Campaign | SR-3/SR-4 | **FAIL** | All progress data reverted to defaults |
| Turn 2 World Phase | T2-A/C | PASS | Upkeep, tasks, jobs, mission prep all work |
| Turn 2 Battle | T2-D | **CRASH** | BUG-043 again at initiative roll |

---

## New Bugs Found

### P0 — Crash / Blocker

#### BUG-036: Edit Captain Crashes — Type Mismatch
- **Location**: `CaptainPanel.gd:37`
- **Error**: `Invalid type in function 'edit_character'. Resource (BaseCharacterResource) is not a subclass of the expected argument class`
- **Impact**: Edit Captain completely broken after randomization
- **Repro**: Randomize captain → Click "Edit Captain"

#### BUG-037: Crew Creation Crashes — Nil Stat Bonus (FIXED)
- **Location**: `CharacterCreator.gd:308`
- **Error**: `Trying to assign value of type 'Nil' to a variable of type 'int'`
- **Root Cause**: `STAT_PROPERTY_MAP` maps "CREDITS" to "credits" property, but `BaseCharacterResource` has no `credits` field. WEALTH motivation bonus (+100 credits) tries to write to nonexistent character property.
- **Fix Applied**: Null guard on `current_character.get(prop_name)` at line 308
- **Impact**: Both "Add Member" and "Randomize All" crashed. Fixed during QA.

#### BUG-043: Initiative Roll Crashes — Missing 'seized' Property
- **Location**: `TacticalBattleUI.gd:741`
- **Error**: `Invalid access to property or key 'seized' on a base object of type 'Resource (InitiativeResult)'`
- **Impact**: Cannot complete Round 1 Reaction Roll phase. Full battle impossible through UI.
- **Repro**: Enter Tactical Battle → Full Oracle → Begin Battle → Roll Initiative

### P1 — Data Integrity

#### BUG-031 (REGRESSION): Save/Reload Loses All Progress Data
- **Symptom**: After save + reload, turns_played=0, missions_completed=0, battles_won=0, credits=1400 (creation defaults)
- **Expected**: turns_played=1, missions_completed=1, battles_won=1, credits=1345
- **Note**: Turn End summary displayed correct values during gameplay. The save mechanism captures initial state, not current state.

#### BUG-039: Trading Credits Not Persisted Between Turns
- **Symptom**: Turn 1 ended with credits 1,345 (after buying/selling). Turn 2 Upkeep showed 1,395 (only upkeep deduction persisted, trading changes lost)
- **Impact**: All trading activity is lost on turn transition

#### BUG-035 (CONFIRMED): Equipment Not Carried to Mission Prep
- **Symptom**: Campaign creation Step 4 shows "Assigned: 3/3", but Mission Prep shows all crew with "(0 equipment)"
- **Impact**: Crew enters battle without any equipment

#### BUG-042: Phantom Equipment Modifiers in Initiative
- **Symptom**: Initiative dialog shows "Motion Tracker (+1)" and "Scanner Bot (+1)" modifiers despite crew having 0 equipment
- **Impact**: Initiative calculations use phantom bonuses

### P2 — Functional / UX

#### BUG-038: Battlefield Theme Mismatch
- **Symptom**: PreBattle said "Urban Settlement" but map showed "Wilderness" terrain (trees, hills, water instead of buildings, containers, streets)
- **Impact**: Terrain setup guide doesn't match generated map

#### BUG-040: Terrain Feature Count May Exceed Core Rules Cap
- **Symptom**: Map shows ~15+ terrain features vs Core Rules max of 13 (3 Large + 6 Small + 4 Linear)
- **Note**: Needs precise count verification; some features may be overlay artifacts

#### BUG-041: Missing LARGE/SMALL/LINEAR Type Prefixes
- **Symptom**: Labels show "Trees 18",7"" instead of expected "SMALL: Trees 18",7""
- **Impact**: Players can't distinguish terrain size categories for rulebook compliance

---

## UX/UI Observations

### Campaign Creation

| ID | Location | Observation | Severity |
|----|----------|-------------|----------|
| UX-039 | Step 1 | No "Next" button visible until campaign name entered — confusing, users may think form is broken | Medium |
| UX-040 | Step 1 | Form is ~2100px tall in ~900px viewport — Victory Conditions below the fold, easily missed | Medium |
| UX-041 | Step 1 | All form nodes have auto-generated names (@Label@445) — bad for accessibility/testing | Low |
| UX-046 | Step 2 | ~90% blank space between prompt and buttons — very sparse | Medium |
| UX-047 | Steps 2,3 | No "Next" button shown even as disabled — progressive disclosure gap | Medium |
| UX-048 | Step 2 | "Create Captain" and "Random Captain" buttons have different widths — inconsistent | Low |
| UX-049 | Step 2 | Captain info is plain text, no card/container — sparse presentation | Medium |
| UX-050 | Step 2 | Stats as single pipe-delimited line — grid layout would be more readable | Medium |
| UX-054 | Step 3 | No description or guidance text — Steps 1,2 had prompts | Low |
| UX-055 | Step 3 | Button widths wildly inconsistent (150, 161, 207, 160px) | Low |
| UX-057 | Step 3 | Cross-character name dedup missing — "Ember Russo" + "Yuri Russo" share surname | Low |
| UX-060 | Steps 4-7 | **"Next" button has NO background/border styling** — appears as bare text while "Back" has proper button container. Very confusing. | High |
| UX-063 | Step 5 | Ship Traits section empty with no content — should hide or show "None" | Low |
| UX-065 | Step 6 | World name "New Campaign Prime" is generic — procedural naming would add flavor | Low |
| UX-066 | Step 6 | No population_name displayed despite FIX-6.3 adding the field | Medium |
| UX-067 | Step 6 | "Market Prices:" header with no content — empty section visible | Low |
| UX-068 | Step 6 | ~8 horizontal separators with sparse content — excessive visual segmentation | Low |
| UX-070 | Step 7 | "Start Campaign" button unstyled text — most important CTA looks like hyperlink | High |
| UX-074 | Step 7 | Crew members not visible in Final Review — can't verify crew before committing | High |
| UX-075 | Step 7 | TWO start buttons — "Start Campaign" nav + "Create Campaign & Start Adventure" form | Medium |
| UX-076 | Step 7 | 4 "Use Ability" buttons in StarsOfTheStoryPanel — unclear purpose in creation | Low |

### Campaign Turn Phases

| ID | Location | Observation | Severity |
|----|----------|-------------|----------|
| UX-077 | Upkeep | Step indicator shows checkmark on step 5 at start — off-by-one | Low |
| UX-078 | Upkeep | "Calculate Costs" button redundant since costs auto-calculate | Low |
| UX-084 | Crew Tasks | Task results informative — dice rolls, thresholds, rewards visible | Positive |
| UX-087 | Job Offers | Two identical "Rescue (generic)" jobs — dedup allows same type+different pay | Low |
| UX-088 | Job Offers | "(generic)" label uninspiring — "Rescue Mission" would be better | Low |
| UX-091 | Mission Prep | "Status: READY" while "0/4 crew equipped" — contradictory | Medium |
| UX-092 | Mission Prep | "Assign Equipment" grayed, "Ready for Battle" active — inverted priority | Medium |
| UX-095 | PreBattle | Grammar: "a Urban Settlement" should be "an Urban Settlement" | Low |
| UX-097 | PreBattle | Enemy Forces shows only "Raiders" with no stats/count | Medium |

### Battle Phase

| ID | Location | Observation | Severity |
|----|----------|-------------|----------|
| UX-100 | Tier Selector | Tier descriptions clear and well-differentiated — excellent onboarding | Positive |
| UX-103 | Tactical UI | Core Rules page references (p.90, p.94) in checklist — brilliant | Positive |
| UX-104 | Tactical UI | "Roll d100" + "I rolled..." dual buttons support digital+physical dice | Positive |
| UX-105 | Tactical UI | Terrain position labels enable exact physical tabletop recreation | Positive |
| UX-125 | Deploy Phase | Deployment zone overlays (blue crew / pink enemy) — excellent visual | Positive |
| UX-126 | Deploy Phase | Multiple crew at Combat 0 — may indicate stat generation imbalance | Medium |
| UX-128 | Initiative | 17% probability display for initiative seizure — excellent transparency | Positive |
| UX-129 | Combat Calc | To-Hit calculator with cover modifiers — invaluable for tabletop | Positive |
| UX-130 | Journal | Battle Journal with [R#] timestamps — great campaign record | Positive |

### Terrain Compliance Issues (vs Core Rules)

| Issue | Rule | Actual | Status |
|-------|------|--------|--------|
| Feature count | Max 13 (3L + 6S + 4Lin) | ~15+ features on map | FAIL |
| Size prefixes | LARGE:/SMALL:/LINEAR: labels | No prefixes shown | FAIL |
| Theme consistency | Should match PreBattle theme | Wilderness always, regardless of mission theme | FAIL |
| Cover density | Varies by theme (40-70%) | Not validated — visual estimate needed | UNKNOWN |
| Objective placement | Center for Special missions | OBJ marker in center ✓ | PASS |

---

## Positive Highlights

1. **Campaign name propagation** works E2E (config → final review → turn controller)
2. **Victory condition selection** works with dual-VC support (BUG-029 fix verified)
3. **Upkeep auto-calculation** works correctly (4 crew + 1 ship = 5cr)
4. **Crew task system** is informative and functional (dice rolls, rewards, caps)
5. **Tactical Battle UI** is impressively detailed — map, checklist, dice, combat calculator, journal
6. **Three-tier companion system** (Log Only / Assisted / Full Oracle) is excellent for different player skill levels
7. **Post-battle 14-step sequence** advances without crashes
8. **Trading phase** buy/sell mechanics work correctly during session
9. **Character events** generate diverse, thematic outcomes

---

## Fixes Applied During QA

1. **CharacterCreator.gd:308** — Added null guard for `current_character.get(prop_name)` to prevent crash when motivation bonus targets non-character property (e.g., "credits")

---

## Recommended Fix Priority

1. **BUG-031 (P0)**: Save/reload data persistence — most critical, makes the app unusable for multi-session play
2. **BUG-043 (P0)**: Initiative roll crash — blocks all manual battle play
3. **BUG-036 (P0)**: Edit Captain crash — blocks character editing after randomization
4. **BUG-039 (P1)**: Trading credits persistence — data lost between turns
5. **BUG-035 (P1)**: Equipment not carried to Mission Prep — crew always enters battle empty-handed
6. **BUG-042 (P2)**: Phantom equipment modifiers in initiative
7. **BUG-038 (P2)**: Battlefield theme mismatch
8. **UX-060/070 (High)**: Unstyled Next/Start buttons across all creation steps
9. **UX-074 (High)**: Crew not visible in Final Review

---

## MCP Testing Notes

- `pressed.emit()` on Initiative Roll causes 30s timeout + crash (async handler)
- `click_element` fails with multiple same-named nodes — use coordinate clicks or scoped `find_child()`
- Auto Deploy works via `pressed.emit()` but Confirm Deployment may need manual click
- Battle can only be completed via programmatic `_on_battle_completed()` call (initiative roll blocks UI path)
- 20 save files accumulated from prior QA sessions in `user://campaigns/`
