# Phase 32 QA Sprint — Comprehensive 2-Turn Campaign Playthrough

**Date**: 2026-03-16
**Tester**: Claude Code (MCP-automated)
**Scope**: Full campaign creation + 2-turn playthrough + battle companion testing + save/reload verification
**Engine**: Godot 4.6-stable
**Goal**: Comprehensive 3-turn QA with battle phase companion simulation, save persistence verification, and UI/UX audit

---

## Executive Summary

Completed campaign creation (7 steps) + 2 full campaign turns with battle companion (Full Oracle mode). Found **4 new crashers** (all fixed inline), confirmed **BUG-031 regression** (save persistence still broken), and documented **30+ UX observations** with professional improvement suggestions.

### Key Results
- **3 P0 crashes found and FIXED during QA** (CaptainPanel type shadow, InitiativeCalculator null, SeizeInitiativeSystem type mismatch)
- **1 P0 data persistence regression confirmed** (BUG-031 — save file writes zeros for all progress counters)
- **Campaign creation**: 7 steps pass with 2 inline fixes
- **Campaign turns**: 2 full 9-phase turns complete without crashes
- **Battle companion**: Full Oracle mode loads successfully with terrain map, checklist, dice, and combat calculator
- **Post-battle**: All 14 steps advance without crashes
- **Terrain system**: Size prefixes (LARGE/SMALL/LINEAR) working, but theme mismatch persists

### Blockers Preventing Full 3-Turn Demo
1. **BUG-031 (P0)**: Save file writes all-zero progress data — multi-session play impossible
2. Time constraints prevented Turn 3 completion (Turns 1-2 fully verified)

---

## Bugs Found & Fixed During QA

### BUG-087 (P0, FIXED): CaptainPanel `_enum_value_name()` Type Mismatch
- **Location**: `CaptainPanel.gd:79`
- **Error**: `Parser Error: Invalid argument for "_enum_value_name()" function: argument 2 should be "int" but is "String"`
- **Root Cause**: Character properties (`character_class`, `origin`, `background`, `motivation`) are `String` on canonical `Character.gd` but `_enum_value_name()` was typed to accept `int`
- **Fix**: Changed parameter type from `int` to `Variant`, added String handling
- **Impact**: Campaign creation crashed immediately on entering Step 2

### BUG-088 (P0, FIXED): CaptainPanel/CrewPanel Character Type Shadowing
- **Location**: `CaptainPanel.gd:3`, `CrewPanel.gd:3`
- **Error**: `Trying to assign value of type 'Character.gd' to a variable of type 'Character.gd'`
- **Root Cause**: `const Character = preload("res://src/core/character/Base/Character.gd")` shadows the global `class_name Character` with `BaseCharacterResource`. When `CharacterCreator` returns a canonical `Character`, Godot sees a type mismatch
- **Fix**: Removed const preload (uses global class_name), untyped `current_captain` and `crew_members` array
- **Impact**: Captain randomization crashed. **15 other files** have the same pattern (systemic risk)
- **Systemic**: Files with same shadowing: `Campaign.gd`, `PostBattlePhase.gd`, `PreBattleUI.gd`, `CampaignCreationManager.gd`, `EnemyDeploymentManager.gd`, `EnemyAIManager.gd`, and 9 more

### BUG-089 (P0, FIXED): InitiativeCalculator Null `initiative_system`
- **Location**: `InitiativeCalculator.gd:118`
- **Error**: `Invalid call. Nonexistent function 'set_crew_data' in base 'Nil'`
- **Root Cause**: `initiative_system` initialized in `_ready()` but `set_crew()` called during `initialize_battle()` before child `_ready()` fires (Godot timing issue)
- **Fix**: Lazy initialization — `if not initiative_system: initiative_system = SeizeInitiativeSystem.new()`

### BUG-090 (P0, FIXED): SeizeInitiativeSystem Int-to-String Type Mismatch
- **Location**: `SeizeInitiativeSystem.gd:100`
- **Error**: `Trying to assign value of type 'int' to a variable of type 'String'`
- **Root Cause**: `var species: String = member.origin` — `origin` property is `int` on some Character instances but typed as `String` in the local variable
- **Fix**: Variant-safe extraction with `str()` conversion for int origins

### BUG-031 REGRESSION (P0): Save File Writes All-Zero Progress Data
- **Symptom**: After 2 complete turns, save file shows:
  - `progress.turns_played: 0` (should be 2)
  - `progress.missions_completed: 0` (should be 2)
  - `progress.battles_won: 0` (should be 2)
  - `progress.credits: 0` (should be 1590)
  - `resources.credits: 1600` (stale creation value)
- **In-game display**: Shows correct values (Turns: 2, Missions: 2, Credits: 1590)
- **Root Cause**: The `to_dictionary()` serialization reads from `progress` dict which is never updated during gameplay. Runtime updates go to `progress_data` (used by UI summary) but serialization reads from a different path
- **Impact**: **Multi-session play is impossible** — all progress lost on reload
- **Priority**: P0 — must fix before any demo or beta

---

## Previous Bug Fix Verifications

| Bug ID | Description | Status |
|--------|-------------|--------|
| BUG-029 | Victory cards not interactive | **VERIFIED FIXED** — click toggles checkmark + blue highlight |
| BUG-041 | Missing LARGE/SMALL/LINEAR prefixes | **VERIFIED FIXED** — labels show correctly on terrain map |
| UX-060/070 | Unstyled nav buttons | **VERIFIED FIXED** — Cancel/Next/Start Campaign all styled |
| BUG-043 | Initiative roll crash | **CANNOT VERIFY** — battle completed programmatically |
| BUG-035 | Equipment not carried to Mission Prep | **PARTIAL** — items in ship stash but not auto-assigned to crew |

---

## UI/UX Observations

### Campaign Creation (Steps 1-7)

| ID | Location | Observation | Severity |
|----|----------|-------------|----------|
| UX-101 | Step 1 | Form is ~2100px tall, Victory Conditions below fold — users may miss them | Medium |
| UX-102 | Step 1 | Campaign name LineEdit has auto-generated name (@LineEdit@444) — bad for accessibility | Low |
| UX-103 | Step 2 | ~90% blank space between prompt and buttons — very sparse, unprofessional | Medium |
| UX-104 | Step 2 | No "Next" button visible until captain created — progressive disclosure gap | Medium |
| UX-105 | Step 2 | Captain info as plain centered text — no card container, looks sparse vs Step 1 | Medium |
| UX-106 | Step 2 | Stats as single pipe-delimited line — 2x3 grid would be more readable | Low |
| UX-107 | Step 2 | Create/Random Captain buttons have border-only styling (inconsistent with nav buttons) | Low |
| UX-108 | Step 3 | No description/guidance text unlike Steps 1-2 | Low |
| UX-109 | Step 3 | Crew list shows no stats — quick stat summary per member would help | Low |
| UX-110 | Step 4 | Equipment panel has excellent 2-column layout with condition badges — POSITIVE | Positive |
| UX-111 | Step 5 | SHIP TRAITS section empty with no content — should hide or show "None" | Low |
| UX-112 | Step 6 | World name "New Campaign Prime" generic — procedural names would add flavor | Low |
| UX-113 | Step 6 | "Market Prices:" header with no content — empty section visible | Low |
| UX-114 | Step 6 | Too many horizontal separators between sparse content | Low |
| UX-115 | Step 7 | Final Review card layout with icons is EXCELLENT — major improvement from prior sprints | Positive |
| UX-116 | Step 7 | Crew Summary shows count + averages but no individual names/classes | Medium |
| UX-117 | Step 7 | TWO start buttons still present (FinishButton + Create Campaign & Start Adventure) | Medium |
| UX-118 | Step 7 | 4 "Use Ability" buttons from StarsOfTheStoryPanel — unclear purpose in creation | Low |
| UX-119 | Step 7 | BUG-034 confirmed — selected VC card description text low contrast on blue bg | P2 |

### Campaign Turn Phases

| ID | Location | Observation | Severity |
|----|----------|-------------|----------|
| UX-120 | Upkeep | Auto-calculation works immediately — POSITIVE | Positive |
| UX-121 | Upkeep | "Calculate Costs" button redundant since auto-calculated | Low |
| UX-122 | Upkeep | Step 5 indicator has checkmark at start (off-by-one) | Low |
| UX-123 | Crew Tasks | Task assignments shown in brackets [FIND A PATRON] — excellent | Positive |
| UX-124 | Crew Tasks | Task slot tracking [1/2 crew] on available tasks list | Positive |
| UX-125 | Crew Tasks | Dice roll breakdown visible (Roll 6 → 8 vs 5) — excellent transparency | Positive |
| UX-126 | Job Offers | "(generic)" labels uninspiring — "Delivery Mission" would be better | Low |
| UX-127 | Job Offers | 5 unique job types with dedup working | Positive |
| UX-128 | Equipment | Crew shows "(0 equipment)" despite creation step showing "Assigned: 14/14" | Medium |
| UX-129 | Mission Prep | "Status: READY" with "0/4 crew equipped" — contradictory | Medium |
| UX-130 | Mission Prep | "Assign Equipment" grayed while "Ready for Battle" active — inverted priority | Medium |
| UX-131 | PreBattle | Grammar: "a Urban Settlement" / "a Industrial Zone" should be "an" | Low |
| UX-132 | PreBattle | Enemy Forces shows just "Rivals" with no stats/count/weapons | Medium |
| UX-133 | PreBattle | Deployment condition effects are well-detailed — POSITIVE | Positive |
| UX-134 | Battle UI | Three-tier companion selector is outstanding onboarding UX | Positive |
| UX-135 | Battle UI | Terrain map with size-prefixed labels + deployment zones — professional grade | Positive |
| UX-136 | Battle UI | Core Rules page references (p.90, p.94) in checklist — brilliant | Positive |
| UX-137 | Battle UI | Dual "Roll d100" + "I rolled..." buttons for digital/physical dice | Positive |
| UX-138 | Battle UI | Battlefield theme "Wilderness" despite PreBattle saying "Industrial Zone" | P2 |
| UX-139 | Post-Battle | 14-step sidebar with visual progress (green/orange) | Positive |
| UX-140 | Post-Battle | Battle Results panel accumulates results across steps | Positive |
| UX-141 | Post-Battle | "Not rolled" text doesn't update inline after roll | Low |
| UX-142 | Post-Battle | Dark gray styling — needs Deep Space card treatment | Medium |
| UX-143 | Turn End | Summary shows correct counters during gameplay | Positive |
| UX-144 | Turn End | "Save your campaign before continuing" warning is helpful | Positive |
| UX-145 | Turn End | Save grays out + Continue activates after save — good flow | Positive |

---

## Post-Battle Page Improvement Suggestions

1. **Step progress visualization**: Add green checkmarks on completed steps, gray out future steps, add progress bar
2. **Battle Results persistence**: Show victory/defeat, enemies killed, crew status across all 14 steps
3. **Step-specific icons**: Sword (combat), coin (payment), bandage (injuries), etc. for scannable sidebar
4. **Auto-roll option**: "Roll All" for non-interactive steps (Rival Status, Invasion, Galactic War)
5. **Inline roll results**: Show "Rolled 4 — The Red Fang stays behind" with color coding
6. **Step grouping**: Resolution (1-3), Rewards (4-7), Casualties (8), Growth (9-10), Economy (11), Events (12-14)
7. **Deep Space theme**: Adopt card-based sections with `COLOR_ELEVATED` backgrounds and `COLOR_BORDER` borders
8. **Sticky progress bar**: Full-width bar instead of just "Step X of 14" text

---

## General UI/UX Professional Polish Suggestions

1. **Consistent button styling**: Border-only buttons (Create Captain, Add Member) should match Deep Space filled buttons
2. **Card layouts everywhere**: Steps 2-3 have plain text/lists — wrap in cards like Steps 1, 4, 5, 7
3. **Empty state handling**: Hide empty sections or show "None" (Ship Traits, Market Prices)
4. **Grammar fixes**: "a Urban" → "an Urban", "a Industrial" → "an Industrial"
5. **Crew detail in Final Review**: List each crew member by name with class/origin before committing
6. **Equipment auto-assignment persistence**: Creation step assignments should carry into campaign turns
7. **Enemy Forces detail**: Show enemy count, unit types, weapons, and threat level in PreBattle
8. **Reduce blank space**: Steps 2-3 have ~70-90% empty viewport — consolidate layout
9. **Step indicator fix**: Off-by-one checkmark on upkeep step indicator (step 5 marked at step 1)
10. **Proceed to Battle visibility**: Button sometimes doesn't appear after ReadyForBattle click — timing issue

---

## Files Modified During QA (Bug Fixes)

| File | Change |
|------|--------|
| `src/ui/screens/campaign/panels/CaptainPanel.gd` | Removed const Character preload, untyped current_captain, fixed _enum_value_name() to accept Variant |
| `src/ui/screens/campaign/panels/CrewPanel.gd` | Removed const Character preload, untyped crew_members array |
| `src/ui/components/battle/InitiativeCalculator.gd` | Lazy init of initiative_system in set_crew() |
| `src/core/battle/SeizeInitiativeSystem.gd` | Variant-safe origin extraction in set_crew_data() |

---

## Recommended Fix Priority

1. **BUG-031 (P0)**: Save persistence — `to_dictionary()` reads from wrong data path. THE most critical issue
2. **BUG-088 systemic**: 15 files with `const Character = preload(Base/Character.gd)` shadowing — ticking time bombs
3. **UX-128/129/130**: Equipment not flowing from creation to campaign turns — confusing user experience
4. **UX-138**: Battlefield theme mismatch (Wilderness vs Industrial Zone)
5. **UX-116**: Individual crew names in Final Review
6. **Post-battle improvements**: Step progress, card styling, auto-roll

---

## Positive Highlights

1. **Tactical Battle UI** is genuinely impressive — professional-grade tabletop companion
2. **Three-tier companion system** (Log Only / Assisted / Full Oracle) is excellent UX
3. **Campaign creation Final Review** has massively improved with card sections and emoji icons
4. **Crew task system** with dice breakdowns and task tracking is informative
5. **Terrain map** with size-categorized labels and deployment zones is publication-quality
6. **Post-battle 14-step sequence** advances reliably without crashes
7. **Turn counter and credit tracking** work correctly during gameplay (just not persisted to save)
8. **Victory condition selection** with visual card state is clean
9. **Navigation button styling** (UX-060/070 fix) works throughout creation
10. **Progress bar in header** provides constant awareness of campaign phase position
