# Phase 29 QA Sprint — Demo Recording Runtime Test

**Date**: March 16, 2026
**Tester**: MCP Automated + Manual Verification
**Scope**: Full 3-turn demo path (CC-1 through SR-6) per DEMO_QA_SCRIPT.md
**Result**: 2 turns completed, save/reload tested. Multiple bugs found.

---

## Test Summary

| Section | Steps | Result | Notes |
|---------|-------|--------|-------|
| CC-1 (Main Menu) | Launch, verify | PASS | Clean launch, no CRITICAL errors |
| CC-2 (Campaign Name) | Type "Wandering Star" | PASS | Name accepted, propagated to Final Review |
| CC-3 (Victory/Difficulty) | Select victory, verify difficulty | PARTIAL | Victory cards NOT interactive (see BUG-029) |
| CC-4 (Continue to Captain) | Press Next | PASS | Warning about crew size default is expected |
| CC-5/CC-6 (Captain Creation) | Create Kira Voss | PASS w/note | Origin shows "None" in preview (BUG-030) |
| CC-7/CC-8 (Crew Setup) | Add 3 crew members | PASS | Randomize path works; manual MCP input unreliable |
| CC-9 (Edit crew) | SKIPPED | — | |
| CC-10 (Ship/World/Equipment) | Steps 4-6 | PASS | Ship hull 10 (6-14 range), debt 2 (0-5 range) |
| CC-11 (Final Review + Start) | Review + Begin Campaign | PASS | Name "Wandering Star" shown, validation warning for no VC |
| T1-C (Upkeep) | Pay upkeep | PASS | 5 credits deducted (4 crew + 1 ship), auto-calc works |
| T1-C4 (Crew Tasks) | Assign + resolve 4 tasks | PASS | 4/4 succeeded, task cap indicator working |
| T1-C5 (Job Offers) | Select job | PASS | 3 unique jobs, dedup working |
| T1-C6/C7 (Equipment/Mission Prep) | Steps 4-6 | PASS | Mission prep shows briefing correctly |
| T1-D (PreBattle) | Verify terrain + crew | PASS | All crew pre-selected, terrain guide shown |
| T1-D2 (Tactical Companion) | Battle UI | PASS | 3-tier selector, graph-paper map, phase bar, dice buttons |
| T1-D3 (Battle) | Auto-resolve | PASS | Battle resolved, transitioned to post-battle |
| T1-E (Post-Battle 14 steps) | Steps 1-14 | PASS | All 14 steps advance without crashes |
| T1-F (Advancement) | Complete | PASS | All crew Level 1 shown |
| T1-G (Trading) | View market | PASS | 7 items, buy/sell buttons, inventory shows |
| T1-H (Character Events) | Complete | PASS | D100 events fire correctly (no crash) |
| T1-I (Turn End) | Save + continue | PASS | Save file written, Turn 2 starts |
| T2 (Full Turn 2) | All phases | PASS | Complete turn with different terrain theme |
| SR-1 (Save file) | Verify file | PASS | Campaign_2026-03-16T11-03-26.fpcs exists (7,801 bytes) |
| SR-2/SR-3 (Load) | Main menu + load | PASS | "Continue Campaign" button appears, loads correctly |
| SR-4 (Verify data) | Check persisted values | PARTIAL FAIL | Turn number preserved, but stats counters reset (BUG-031) |

---

## Bugs Found

### BUG-029: Victory Condition Cards Not Interactive (P2 - UX Gap)
- **Location**: [ExpandedConfigPanel.gd](src/ui/screens/campaign/panels/ExpandedConfigPanel.gd) — Victory Conditions section
- **Symptom**: Victory cards (Wealth Victory, Reputation Victory, etc.) display correctly but have NO click handlers. `gui_input` signal not connected. `selected_victory_conditions` remains `{}`.
- **Impact**: Campaign starts with "Victory: None Selected — campaign will have no win condition" warning. Final validation warns but allows proceeding.
- **Root Cause**: Victory cards are built as static PanelContainers with Labels — no Button/CheckBox or `gui_input` connection for selection.
- **Fix Required**: Add click-to-toggle behavior to victory cards, update `selected_victory_conditions` dict, add visual selected state (border/checkmark).

### BUG-030: Origin "None" for Default Selection (P2 - Data)
- **Location**: [CharacterCreator.gd](src/core/character/Generation/CharacterCreator.gd)
- **Symptom**: When a character is created without changing the Origin dropdown from its default (index 0 = Human), the preview and captain summary show "Origin: None".
- **Impact**: Captain and crew members all show "Origin: None" unless the user actively clicks the Origin dropdown and re-selects.
- **Root Cause**: The OptionButton's default selection (index 0) doesn't fire `item_selected` signal on initial load. The CharacterCreator only sets the origin field when the signal fires, not from the dropdown's initial state.
- **Fix Required**: In `_ready()` or `start_creation()`, read the current OptionButton selection and initialize the character's origin from it.

### BUG-031: Campaign Statistics Not Persisted on Save/Load (P1 - Data Integrity)
- **Location**: [GameState.gd](src/core/state/GameState.gd) / [EndPhasePanel.gd](src/ui/screens/campaign/phases/EndPhasePanel.gd)
- **Symptom**: After save/reload, `missions_completed`, `battles_won`, `battles_lost` all reset to 0. `credits` is `null` in `progress_data`.
- **Impact**: Campaign Cycle Summary shows incorrect data after reload. Credits tracking broken — upkeep deductions don't persist.
- **Root Cause**: `progress_data` dictionary in FiveParsecsCampaignCore is not being updated during gameplay for:
  - `credits` — upkeep deduction may write to a different location than what EndPhasePanel reads
  - `missions_completed` — counter not incremented during post-battle
  - `battles_won` / `battles_lost` — auto-resolve result not written to progress_data
- **Fix Required**: Audit the data flow for credits (UpkeepPhaseComponent → GameState → save), battle results (TacticalBattleUI auto-resolve → CampaignTurnController → progress_data), and mission completion tracking.

### BUG-032: ExpandedConfigPanel Crash on get_panel_data() (P2 - Fixed)
- **Location**: [ExpandedConfigPanel.gd:1090](src/ui/screens/campaign/panels/ExpandedConfigPanel.gd)
- **Symptom**: `Invalid access to property or key 'difficulty_level' on a base object of type 'Dictionary'` — crash when `get_campaign_config_data()` called after external state update overwrites `local_campaign_config` with partial dictionary.
- **Root Cause**: `_on_campaign_state_updated()` at line 189 replaced `local_campaign_config` entirely with `config_state_data.duplicate()`, losing required keys.
- **Fix Applied**: Changed to `.merge(config_state_data, true)` and added `.get()` with defaults in `get_campaign_config_data()`.
- **Status**: FIXED in this sprint.

---

## UI/UX Observations (Non-Blocking)

| ID | Location | Observation |
|----|----------|-------------|
| UX-030 | Steps 4-6 Navigation | "Next" button has no background box styling (text-only appearance) while "Back" has styled box. Inconsistent button treatment. |
| UX-031 | Step 5 (Ship) | Ship type is "Armed Trader" instead of expected default "Freelancer". Randomization picks a type — may be intended. |
| UX-032 | Step 6 (World) | World name is generic "New Campaign Prime". No `population_name` displayed despite FIX-6.3 adding population_scale field. |
| UX-033 | Step 7 (Final Review) | "Stars of the Story" panel with 4 "Use Ability" buttons visible — unclear purpose in campaign creation context. |
| UX-034 | Turn End Summary | Credits display shows starting value (1700) not post-deduction value. Related to BUG-031. |
| UX-035 | Story/Travel Phases | Story and Travel phases appear to be auto-skipped on new campaign. QA script expects manual interaction. |
| UX-036 | Step indicator bar | Step 5 shows checkmark on initial World Phase load (before completing step 1). Off-by-one in indicator initialization. |
| UX-037 | Trading Phase | Duplicate items possible in market (2x Market Pistol at 82cr). May be intended by design. |
| UX-038 | Kira Voss background | Equipment Panel shows "Wasteland Nomads" instead of "Military Brat" — possible label mapping issue. |

---

## Console Warnings (Recurring, Non-Blocking)

| Warning | Frequency | Notes |
|---------|-----------|-------|
| `StoryPhasePanel: EventManager not found` | Every scene transition | Fallback event generation works fine |
| `CampaignTurnController: RivalBattleGenerator not available` | Every battle phase | Non-blocking — encounter checks skipped |
| `GalacticWarPanel: GalacticWarManager not found` | Post-battle step 14 | War progress panel loads without manager |
| `Setting node name 'Content' to be unique` | Every scene transition | Duplicate unique name in PreBattleUI.tscn |
| `ResponsiveContainer deprecated` | Scene transitions | Should migrate to `base/ResponsiveContainer.gd` |
| `CharacterPhasePanel.tscn invalid UID` | On load | UID mismatch — uses text path fallback |
| `EquipmentPanel.get_data() deprecated` | Captain creation | Non-functional, uses get_panel_data() internally |

---

## Fixes Applied During This Sprint

1. **ExpandedConfigPanel.gd** — `get_campaign_config_data()`: Changed direct property access to `.get()` with defaults to prevent crash on partial dictionaries.
2. **ExpandedConfigPanel.gd** — `_on_campaign_state_updated()`: Changed full dictionary replacement to `.merge()` to preserve required keys.
3. **ExpandedConfigPanel.gd** — `set_campaign_config()`: Same merge fix for external config setting.

---

## Recommended Next Steps (Priority Order)

1. **BUG-031 (P1)**: Fix credits/stats persistence pipeline — this is the most impactful data integrity issue
2. **BUG-030 (P2)**: Fix default Origin not being set on CharacterCreator — affects every character created without touching Origin dropdown
3. **BUG-029 (P2)**: Make Victory Condition cards interactive — currently no way to select victory conditions
4. **UX-035**: Investigate Story/Travel phase auto-skip behavior — QA script expects manual interaction
5. **UX-030**: Fix Next button styling inconsistency on Steps 4-6
6. **Console warnings**: Clean up deprecated ResponsiveContainer reference, fix CharacterPhasePanel UID

---

## MCP Testing Notes

- `find_child()` returns the FIRST match — with 2 CharacterCreators (CaptainPanel + CrewPanel), must scope search to the correct parent panel
- ItemList selection via MCP coordinates unreliable — use `list.select(idx)` + `list.item_selected.emit(idx)` via `run_script`
- `pressed.emit()` on buttons is more reliable than `simulate_input` click_element for buttons inside nested containers
- WorldPhaseController advancement requires `_debug_complete_current_step()` + `_advance_to_next_step()` sequentially
- Auto-generated button names (`@Button@NNN`) change across sessions — find by parent node path instead
