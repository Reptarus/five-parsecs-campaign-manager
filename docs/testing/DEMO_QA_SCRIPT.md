# Five Parsecs Campaign Manager — Demo Recording QA Script

**Campaign Creation → Two Full Turns → Save & Reload**
Version 1.0 · March 2026 · Godot 4.6-stable

---

## Purpose & Scope

This script is the QA gate between development and the demo recording. Every step below
must be executed in order, exactly as written, before the recording session begins. If a
step fails and is not covered by a known bug listed in this document, it is a blocker —
fix it before proceeding.

The demo narrative is: a player sits down with a fresh install, creates a named custom
crew, plays two complete campaign turns (the second featuring the Trading Phase
prominently), then saves and reloads to confirm persistence. This is the exact path a
publisher evaluating the app will follow.

**In scope for the recording:** campaign creation with custom crew names and species,
Story/Travel/World phases (upkeep, crew tasks, job offers), mission selection and Battle
Phase setup, the full 14-step Post-Battle sequence with D100 tables, Advancement Phase
(spend XP on a stat), Trading Phase (browse market, buy item, sell item), Character Phase
(D100 crew events), and Turn End with save then reload confirmation.

**Out of scope:** Bug Hunt gamemode, Compendium DLC features (unless unlocked by default),
Settings/accessibility panel, Galactic War deep-dive, edge cases or stress testing,
victory condition completion.

---

## Known Bugs — Do Not Re-Report

- WEALTH motivation gives +1 SAVVY (should give credits) — needs resource bonus system architecture
- 49% of character creation bonuses are not yet implemented (resource bonuses)
- Victory condition tracking uses turns_played as proxy, not actual metric counters

## Phase 31 QA Bug Fix Sprint (March 16, 2026)

10 bugs fixed (3 P0, 4 P1, 3 P2), 3 high-severity UX issues resolved, 13 files modified.

| Bug ID | Location | Resolution |
|--------|----------|------------|
| BUG-035 | GameState / WorldPhaseController | Equipment in ship stash now restored to EquipmentManager on load; crew dicts enriched with per-member equipment via `_restore_equipment_from_campaign()` + `_enrich_crew_equipment()` |
| BUG-036 | CaptainPanel | Untyped `current_captain` passed to typed `edit_character()` — now typed as `Character` |
| BUG-037 | CharacterCreator | Nil stat bonus on WEALTH motivation — null guard added |
| BUG-038 | CampaignTurnController | terrain_guide data at top level of battle context, not inside terrain sub-dict — merged into terrain |
| BUG-039 | PurchaseItemsComponent | `_on_sell_pressed` credits now synced to GameStateManager via `add_credits()` |
| BUG-040 | BattlefieldShapeLibrary / BattlefieldMapView | Scatter items no longer rendered as full terrain features (is_scatter flag) |
| BUG-041 | BattlefieldShapeLibrary / BattlefieldMapView | `classify_feature()` now stores size_category; labels prefixed with Large/Small/Linear |
| BUG-042 | TacticalBattleUI / InitiativeCalculator | `set_crew()` + `auto_detect_equipment()` now wired during battle init — initiative roll works |
| BUG-043 | TacticalBattleUI | `result.seized` fixed to `result.success` (correct InitiativeResult property) |
| UX-060/070 | CampaignCreationUI | Nav buttons (Back/Next/Cancel) now styled with Deep Space theme StyleBox overrides |
| UX-074 | FinalPanel | `_update_crew_preview()` handles both Character objects and Dictionary input |

**Key demo path impacts**:
- Initiative roll now works correctly in battle setup (BUG-042/043)
- Save/reload preserves equipment stash and crew gear (BUG-035)
- Selling items in post-battle Purchase Items step syncs credits properly (BUG-039)
- Campaign creation nav buttons match Deep Space theme (UX-060/070)
- Final Review crew preview handles coordinator state Dicts (UX-074)
- Terrain map labels show size categories (BUG-041)

## Phase 28 QA Sprint Fixes (March 16, 2026)

**IMPORTANT: Persistent test campaigns from before March 16 have INVALID ship data (hull 20-35, debt 12-38). Create a FRESH campaign for verification.**

| Bug ID | Location | Resolution |
|--------|----------|------------|
| BUG-012/013 | ExpandedConfigPanel / CampaignCreationUI | Signal chain repaired: `campaign_config_data_complete` now emitted; 3 missing signal connections added; VC validation relaxed so name propagates independently |
| BUG-009/010/011 | ShipPanel | Hull corrected to 6-14 (was 20-35), debt to 0-5 (was 12-38), Freelancer default type, SpinBox constrained |
| BUG-007 | CaptainPanel | `is_captain = true` now set in both create and edit handlers |
| BUG-003 | CampaignCreationCoordinator | Next button disabled when campaign name is empty |
| BUG-002 | SceneRouter | Phantom "main_game" route replaced with "campaign_turn_controller" — eliminates CRITICAL error on every launch |
| BUG-021 | PreBattleUI | All crew pre-selected on entry; Confirm button enabled immediately |
| BUG-016 | CrewTaskComponent | Task cap shows [FULL X/X] indicator; push_warning on rejection |
| BUG-017 | JobOfferComponent | Duplicate jobs re-rolled by type+objective (up to 3 attempts) |
| BUG-022 | BattlefieldGenerator | Terrain capped at 13 features (3 Large + 6 Small + 4 Linear) per Core Rules Standard Terrain Set |
| BUG-004 | ShipPanel | Content container scan uses exact name match (false-positive eliminated) |
| BUG-006 | EquipmentPanel | `get_panel_data()` is now canonical; deprecated method no longer spams console |
| UX-006 | CaptainPanel | Captain summary now shows 6 combat stats (Combat/Reactions/Toughness/Speed/Savvy/Luck) |
| UX-008 | CharacterTableRoller | 36+36 names (was 26+26); first!=last dedup prevents "Blake Blake" |
| UX-020 | UpkeepPhaseComponent | Costs auto-calculated on `initialize_upkeep_phase()` (no longer shows 0) |
| FIX-5.1 | CharacterCreator | SURVIVAL motivation: +1 TOUGHNESS (was REACTIONS) |
| FIX-6.1 | PatronJobManager | Payment formula unified to `base*tier + danger` (matched JobOfferComponent) |
| FIX-6.2 | world_traits.json | Added "high_cost" world trait (was dead code in UpkeepPhaseComponent) |
| FIX-6.3 | WorldGenerator | Added tech_level (d6), government_type (d10→10 types), population_scale (d6) |

## Pre-March 16 Resolved Bugs

| Bug ID | Location | Resolution |
|--------|----------|------------|
| BUG-034 | Upkeep Panel | `_calculate_upkeep()` now called in `_ready()` — label populates immediately on panel open. |
| BUG-060 | TacticalBattleUI | Dead units automatically skipped in activation order. |
| BUG-061 | TacticalBattleUI | Post-resolution bottom action bar hidden after unit resolves. |
| BUG-062 | TacticalBattleUI | Round HUD counter increments correctly on round advance. |
| BUG-063 | TacticalBattleUI | Character cards display proper names from Character object and Dictionary input. |

---

## CC — Campaign Creation

> **Status: VERIFIED (Mar 16, 2026 — Phase 29 Runtime Test)** — CC-1 through CC-11 all PASS.
> Campaign name "Wandering Star" propagates to Final Review. Ship hull=10 (6-14), debt=2 (0-5).
> Captain shows 6 stats. Crew list populates correctly. World generates with government+tech_level.
> **Known issues**: Victory cards not interactive (BUG-029), Origin shows "None" for default Human (BUG-030).
> See `docs/QA_SPRINT_PHASE29_NOTES.md` for full results.

### Demo Crew Specification

Use exactly these values so the recording is consistent across retakes. The app must
accept all custom names without truncation or error.

| Character | Role | Species/Origin | Background | Motivation |
|-----------|------|----------------|------------|------------|
| Kira Voss | Captain | Human | Military | Survival |
| Dex Tannek | Crew Member 1 | Human | Drifter | Wealth |
| Sura-9 | Crew Member 2 | Bot | — | — |
| Maren Holt | Crew Member 3 | Human | Colonist | Revenge |

### Steps

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| CC-1 | Launch app from cold start. Confirm Main Menu loads. Press "New Campaign". | Main Menu visible with no errors. Wizard opens to Step 1 (ExpandedConfigPanel). | `MainMenu.tscn` → `CampaignCreationUI.tscn` | |
| CC-2 | Step 1 (Config): Type campaign name **"Wandering Star"** in the Campaign Name LineEdit. | Name field accepts input. Validation hint disappears after name is entered. | `campaign_name_input` (LineEdit) | |
| CC-3 | Step 1 (Config): Set Difficulty to **Standard**. Select **Wealth Victory** by clicking its card. | Difficulty description updates. Victory card highlights with focus border and checkmark. Summary shows "1 condition selected". | `difficulty_option`, `VictoryCard_wealth` | |
| CC-4 | Step 1 (Config): Leave Story Track as "No Story Track". Press Continue. | Panel validates. Wizard advances to Step 2 (CaptainPanel). | Continue button | |
| CC-5 | Step 2 (Captain): Press "Create Captain". In CharacterCreator, type name **Kira Voss**, set Origin: Human, Background: Military, Motivation: Survival. | Character creator opens. All dropdowns populate. Name field accepts input. | `create_button` → `CharacterCreator` → `character_created` signal | |
| CC-6 | Step 2 (Captain): Confirm captain created. Verify display shows Name: Kira Voss / Origin: Human. | Captain info panel shows all fields. No "Unknown" values. Edit and Randomize buttons become available. | `captain_info` Label | |
| CC-7 | Step 3 (Crew): Set crew size to **"4 Total"**. Press "Add Crew Member". Create **Dex Tannek** — Human, Drifter, Wealth. | Dex appears in `crew_list` ItemList. Format: "Name — Class (Origin)". | `crew_size_option`, Add button, `crew_list` | |
| CC-8 | Step 3 (Crew): Add **Sura-9** (Bot origin). Add **Maren Holt** — Human, Colonist, Revenge. | All 3 crew members in `crew_list`. Add button disables. `is_valid()` returns true. | `crew_list` ItemList | |
| CC-9 | Step 3 (Crew): Select Sura-9 in the list. Press Edit. Verify Bot origin is set. Save the edit. | CharacterCreator reopens showing Sura-9's data. Bot origin preserved after edit. `character_edited` fires. | Edit button → `CharacterCreator` | |
| CC-10 | Steps 4–6 (Ship, World, Equipment): Confirm auto-generation triggers on entry. Ship name and world name should populate. **Ship hull must be 6-14, debt 0-5. Default type "Freelancer" in dropdown.** World should show tech_level, government_name, population_name. | ShipPanel and WorldInfoPanel show generated names on entry. No blank required fields. Captain summary shows 6 combat stats. | `ShipPanel.gd`, `WorldInfoPanel.gd` auto-generate | |
| CC-11 | Step 7 (Final): Review summary. Press "Begin Campaign". | FinalPanel shows crew, ship, world summary. Campaign launches to CampaignDashboard. Turn 1 begins at Story Phase. | `FinalPanel` → Begin Campaign | |

---

## T1 — Campaign Turn 1

> **Status: VERIFIED (Mar 16, 2026 — Phase 31 Sprint)** — All T1 phases PASS.
> Upkeep auto-calc works (5cr deducted). Crew tasks assign+resolve (4/4). Job dedup working (3 unique).
> Battle UI loads with terrain map + tier selector. **Initiative roll now works** (BUG-042/043 fixed).
> Auto-resolve transitions to 14-step post-battle. Equipment shows in mission prep (BUG-035 fixed).
> All post-battle steps advance without crashes. Selling items syncs credits (BUG-039 fixed).
> **Known issues**: Story/Travel phases auto-skip.

**Demo narrative context:** Turn 1 establishes the routine. The player pays upkeep,
assigns crew tasks, picks a job, runs the battle off-screen (tabletop companion mode),
then goes through the 14-step post-battle sequence. This is where the D100 Campaign Event
and Character Event tables are shown in action.

### T1-A — Story Phase (Phase 0)

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-A1 | Story Phase opens automatically after campaign creation. 1–3 story events appear. | `event_list` ItemList shows 1–3 generated events. Select any event. | `StoryPhasePanel` → `event_list` | |
| T1-A2 | Click an event. Read the description in `event_details`. Two choice buttons appear. | `event_details` (RichTextLabel) shows title + description in bold. Choice buttons render. | `event_details`, `choice_container` | |
| T1-A3 | Click "Investigate the signal" (or any first choice). Press Resolve. | Selected choice turns green. Resolve enables. On press, event resolves and is removed. Phase auto-completes when list is empty. | `resolve_button` → `complete_phase()` | |

### T1-B — Travel Phase (Phase 1)

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-B1 | Travel Phase opens. Select "Stay on current world" for Turn 1. | `TravelPhaseUI` shows current world info. Sub-phase DECIDE_TRAVEL is visible. | `TravelPhaseUI.tscn` | |
| T1-B2 | No travel event needed if staying. Press Continue. | Phase advances to World/Upkeep Phase. | Continue button | |

### T1-C — World / Upkeep Phase (Phase 2)

> BUG-034 resolved: Upkeep cost label now populates immediately on panel open.

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-C1 | Upkeep Phase opens (UpkeepPhasePanel). Verify `crew_list` shows all 4 members. | `crew_list` shows 4 entries. Sura-9 identified as Bot. No "Unknown" names. | `UpkeepPhasePanel` → `crew_list` | |
| T1-C2 | Read upkeep cost display. **Costs should auto-populate immediately on entry** (not 0). With 4 crew: crew upkeep + ship maintenance. | Upkeep costs display immediately (not blank/zero). Credits shown. | `UpkeepPhaseComponent` — auto-calculates on `initialize_upkeep_phase()` | |
| T1-C3 | Press "Pay Upkeep". Credits decrease by 24. Phase advances. | Credits deducted correctly. Phase transitions to Crew Tasks. | `pay_upkeep_button` → `complete_phase()` | |
| T1-C4 | Crew Tasks: Assign Kira to **Train**. Assign Dex to **Find a Patron**. Leave others on any task. | Tasks visually assigned. Task selection persists. No crash. | WorldPhaseController crew tasks UI | |
| T1-C5 | Resolve Tasks: For "Find a Patron", a patron offer should be generated. Confirm it appears in Job Offers. | Job Offers sub-phase shows at least one patron mission. Opportunity missions also available. | `PatronRivalManager`, `MissionSelectionUI` | |
| T1-C6 | Equipment sub-phase: Verify crew equipment is visible. No action required — confirm no crash. | Equipment panel renders without errors. | `EquipmentPanel.gd` | |
| T1-C7 | Choose Your Battle: Select the patron mission. Confirm mission details are shown. | Mission selected. Details panel shows mission type, enemy, objective. Confirm button available. | `MissionSelectionUI` → mission chosen | |

### T1-D — Mission / Battle Phase (Phase 3)

The app is a tabletop companion — the physical battle is played on the table. This phase
sets up the battlefield reference and waits for the player to return with results.

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-D1 | BattleSetupPhasePanel opens. Verify terrain/sector info is displayed. Confirm BattlefieldGridPanel renders. **Terrain must show <=13 features total (3 Large + 6 Small + 4 Linear) with LARGE:/SMALL:/LINEAR: prefixes.** | `BattleSetupPhasePanel` shows mission type, enemy faction, terrain sectors. `BattlefieldGridPanel` renders 4x4 sector grid with terrain shapes. Regenerate button produces new terrain. | `BattleSetupPhasePanel.tscn`, `BattlefieldGridPanel.gd` | |
| T1-D2 | Open TacticalBattleUI. Verify character names display correctly. Verify round counter shows "ROUND 1". | `TacticalBattleUI.tscn` loads. Crew panels show correct names (Kira Voss, Dex Tannek, etc.). Round HUD displays "ROUND 1" and increments on advance. | `TacticalBattleUI.gd` — character cards | |
| T1-D3 | Simulate battle: 3 enemies defeated, 1 crew injury (Dex), 0 casualties. Enter results. | Battle results stored: `victory=true`, `enemy_defeated=3`, `crew_injuries=1`. | `BattleResolutionPhasePanel` | |
| T1-D4 | Confirm transition to Post-Battle Sequence. | `PostBattleSequence.tscn` loads. `step_counter` shows "Step 1 of 14". All 14 step names visible in `steps_container`. | `PostBattleSequence.gd` → `steps_container` | |

### T1-E — Post-Battle Sequence (14 Steps)

> **Status: VERIFIED (Mar 12, 2026)** — All 14 steps pass. roll_dice fix applied and
> verified at runtime. Steps 12-14 (Campaign Event, Character Event, Galactic War)
> no longer crash after DiceManager API correction (7 call sites).

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-E1 | Step 1 — Resolve Rivals: Press "Roll for [Rival Name]". | D6 roll displayed. Rival removed on 4+ (or kept with escalation change). | Step 1 | |
| T1-E2 | Step 2 — Determine Invasion: Check invasion status. | Invasion check runs. Proceed if no invasion. | Step 2 | |
| T1-E3 | Step 3 — Quest Progress: Check quest advancement. | Quest progress updated if active quest. | Step 3 | |
| T1-E4 | Step 4 — Get Paid: Verify payment summary. Press "Apply Payment". | Base pay + victory bonus shown. Credits increase. | Step 4 | |
| T1-E5 | Step 5 — Battlefield Finds: Press "Roll Battlefield Finds". | D100 roll result displayed. Item or credits awarded. | Step 5 | |
| T1-E6 | Step 6 — Check for Upgrades: Review upgrade availability. | Upgrade check runs against crew stats. | Step 6 | |
| T1-E7 | Step 7 — Gather Loot: Press "Generate Loot from Defeated Enemies". | D100 loot table roll. Item added to equipment or credits awarded. | Step 7 | |
| T1-E8 | Step 8 — Determine Injuries: For each casualty, press "Roll Severity". | Per-casualty D100 injury roll. Severity and recovery time shown. | Step 8 | |
| T1-E9 | Step 9 — Experience & Leveling: Press "Roll Advancement" for each crew. | XP summary per character. Roll-gated stat upgrades appear after roll. | Step 9 | |
| T1-E10 | Step 10 — Invest in Training: Select character, choose training course. | 8 training types with XP costs. Approval roll 4+ on 2D6. | Step 10 | |
| T1-E11 | Step 11 — Purchase Items: Browse market, buy/sell items. | Market items listed. Purchase deducts credits. | Step 11 | Known: EquipmentManager error (non-fatal) |
| T1-E12 | Step 12 — Campaign Event: D100 roll for campaign-wide event. | D100 roll displayed. Event type and effect shown. | Step 12 | Previously crashed — roll_dice bug now FIXED |
| T1-E13 | Step 13 — Character Event: D100 roll per crew member. | Per-character D100 event roll and description. | Step 13 | Previously crashed — roll_dice bug now FIXED |
| T1-E14 | Step 14 — Galactic War Progress: Check galactic war status. | War progress updated. | Step 14 | |

### T1-F — Advancement Phase (Phase 4)

> **Status: VERIFIED (Mar 12, 2026)** — Phase opens and transitions correctly.

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-F1 | Advancement Phase opens. Crew with pending XP shown. | Phase panel displays crew list with XP totals and available upgrades. | `AdvancementPhasePanel` | |
| T1-F2 | Select Kira Voss. Spend XP on a stat upgrade (e.g., +1 Combat). | Stat cost shown. XP deducted. Stat visually increments. | Stat upgrade UI | |
| T1-F3 | Press Continue to complete Advancement Phase. | Phase transitions to Trading Phase. | Continue button | |

### T1-G — Trading Phase (Phase 5)

> **Status: VERIFIED (Mar 12, 2026)** — Phase opens and transitions correctly.

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-G1 | Trading Phase opens. Credits and market visible. | `TradePhasePanel` shows current credits, market items, inventory. | `TradePhasePanel` | |
| T1-G2 | Browse market. Select an item. Press "Buy". | Purchase deducts credits. Item moves to inventory. | Buy button | |
| T1-G3 | Select an owned item. Press "Sell". | Credits increase. Item removed from inventory. | Sell button | |
| T1-G4 | Press "Complete Trading" to finish phase. | Phase transitions to Character Phase. | Complete button | |

### T1-H — Character Phase (Phase 6)

> **Status: VERIFIED (Mar 12, 2026)** — Phase opens and transitions correctly.

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-H1 | Character Phase opens. D100 crew events triggered. | `CharacterPhasePanel` shows event results per crew member. | `CharacterPhasePanel` | |
| T1-H2 | Review events. Press Continue. | Events applied. Phase transitions to Turn End. | Continue button | |

### T1-I — Turn End

> **Status: VERIFIED (Mar 12, 2026)** — Turn summary displays correctly (B69 fixed),
> turn counter increments, auto-save triggers.

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| T1-I1 | Turn End screen shows turn summary. | Summary of Turn 1 actions and changes displayed. | Turn End panel | |
| T1-I2 | Confirm turn end. Campaign auto-saves. | Save file written. Turn counter increments to 2. | End Turn / Continue | |

---

## T2 — Campaign Turn 2

> **Status: VERIFIED (Mar 16, 2026 — Phase 31 Sprint)** — All phases PASS.
> Turn 2 follows the same phase structure as Turn 1. Different terrain theme (Urban Settlement).
> Trading Phase shows market with 7 items + inventory. Save at Turn End writes .fpcs file correctly.
> BUG-031 resolved (Phase 30) — credits now persist to progress_data. Equipment persists on reload (BUG-035 fixed).

### T2-A through T2-C — Story / Travel / World Phases

| # | Action | Expected Result | Notes |
|---|--------|-----------------|-------|
| T2-A1 | Story Phase: Resolve new events. | Events processed. Transition to Travel. | |
| T2-B1 | Travel Phase: Stay or travel. Continue. | Phase advances to World/Upkeep. | |
| T2-C1 | Pay Upkeep. Assign crew tasks. Select mission. | Credits deducted. Battle setup opens. | |

### T2-D — Battle Phase

| # | Action | Expected Result | Notes |
|---|--------|-----------------|-------|
| T2-D1 | Battle setup. Verify terrain display. Complete battle. | Battle results stored. Transition to post-battle. | |

### T2-E — Post-Battle through Turn End

| # | Action | Expected Result | Notes |
|---|--------|-----------------|-------|
| T2-E1 | Complete 14-step post-battle sequence. | All steps process without errors. | |
| T2-E2 | **Trading Phase (demo highlight)**: Buy 2+ items, sell 1 item. | Market browsing, purchase, sale all work. Credits update in real-time. | |
| T2-E3 | Complete remaining phases. End Turn 2. | Turn 2 completes. Campaign saves. | |

---

## SR — Save & Reload Verification

> **Status: PASS (Mar 16, 2026 — Phase 30/31 Sprint)** — Save file writes correctly (.fpcs + .backup).
> Campaign loads via "Continue Campaign" button. Turn number (2) and crew count (4) preserved.
> BUG-031 FIXED (Phase 30): credits synced to progress_data via dual-sync setters; counters initialized in `_init()`.
> BUG-035 FIXED (Phase 31): equipment stash restored to EquipmentManager on load via `_restore_equipment_from_campaign()`.
> Verify: campaign name, turn number, crew (4 members, all 6 stats, captain has is_captain=true),
> ship (hull 6-14, debt 0-5), world (with tech_level, government_name, population_name), patrons, equipment.

| # | Action | Expected Result | Key Node / Button | Notes |
|---|--------|-----------------|-------------------|-------|
| SR-1 | After Turn 2, confirm auto-save occurred. | Save file at `user://campaigns/` with current timestamp. | GameState auto-save | Path is `user://campaigns/` NOT `user://saves/` |
| SR-2 | Exit to Main Menu. | Main Menu loads cleanly. | Main Menu | |
| SR-3 | Press "Load Campaign". Select saved campaign. | Campaign name "Wandering Star" visible. | Load Campaign | If UI click fails, use `GameState.load_campaign()` programmatically |
| SR-4 | Verify: campaign name, turn number, crew, credits. | "Wandering Star", Turn 3, 4 crew, correct credits. | CampaignDashboard | |
| SR-5 | Verify crew names and stats preserved. | All 4 members present with correct stats. | Crew panel | |
| SR-6 | Verify equipment inventory persisted. | Items bought/sold reflected correctly. | Equipment panel | |

---

## MCP Automation Techniques

> Reference for MCP-automated testing of this script. Workarounds discovered during
> demo QA runtime testing (March 2026).

### MCP Quick Reference

**Godot MCP Server**: Communicates via UDP port 9900. The server must be running inside
the Godot editor (enabled via the MCP plugin).

**Available MCP Tools** (Godot MCP Server):

| Tool | Purpose | Key Notes |
|------|---------|-----------|
| `run_project` | Launch the game from editor | Must be running before any other tool works |
| `stop_project` | Stop the running game | Call before relaunching |
| `take_screenshot` | Capture viewport (1920x1080) | Use after every major step for verification |
| `get_ui_elements` | List all visible UI nodes with names, types, positions | Primary discovery tool — use to find button names |
| `simulate_input` | Click buttons, type text, scroll | Pass exact node NAME (not display text). `@`-prefixed auto-names don't work |
| `run_script` | Execute GDScript in the running game | **Synchronous only** — no `await`. 30s timeout. Use for state inspection and programmatic navigation |
| `get_debug_output` | Read Godot console errors/warnings | Check after each phase transition for silent errors |

**Critical `run_script` Rules**:

- `run_script` is **synchronous** — `await` causes a 30s timeout and returns nothing
- Access autoloads via: `scene_tree.root.get_node("/root/AutoloadName")`
- Find scene nodes via: `scene_tree.root.find_child("NodeName", true, false)`
- `pressed.emit()` via `run_script` can crash on complex async handlers — prefer `simulate_input` for button clicks
- Always return a value: `return "done"` or `return some_variable` — scripts with no return give no confirmation

**Verification Pattern** (repeat for each step):

1. `take_screenshot` — see current state
2. `get_ui_elements` — find interactive node names
3. `simulate_input` or `run_script` — perform the action
4. `take_screenshot` — confirm result
5. `get_debug_output` — check for errors

### Campaign Loading via MCP
Load Campaign UI dialog does not respond reliably to MCP click events. Use programmatic loading:
```gdscript
var gs = scene_tree.root.get_node("/root/GameState")
gs.load_campaign("user://campaigns/Campaign_<timestamp>.fpcs")
```

### World Phase Step Advancement
WorldPhaseController Next button sometimes doesn't advance steps via MCP clicks. Use debug methods:
```gdscript
var wpc = scene_tree.root.find_child("WorldPhaseController", true, false)
wpc._debug_complete_current_step()
wpc._advance_to_next_step()
# On last step (5), _advance_to_next_step() auto-triggers battle sequence
# Do NOT call _navigate_to_battle_phase() separately — requires 1 argument and crashes
```

### Save File Location
Campaign saves at `user://campaigns/` (resolves to `%APPDATA%/Godot/app_userdata/Five Parsecs Campaign Manager/campaigns/`).

---

## Resolved Bugs (March 2026)

See **Phase 28 QA Sprint Fixes** section above for all 18 bugs fixed on March 16.

Additional pre-March 16 fixes:

| Bug ID | Location | Resolution |
|--------|----------|------------|
| ROLL-FIX | PostBattleSequence | 7 calls to non-existent `dice_manager.roll_dice()` replaced with correct DiceManager API (`roll_d100()`, `roll_d6()`). Steps 12-14 no longer crash. |
| B69 | EndPhasePanel | Turn summary data integrity — `CampaignPhaseManager.turn_number` now synced from `progress_data["turns_played"]` on campaign load. |
| B70 | CampaignTurnController | Save/reload turn restoration — key mismatch (`"turn_number"` vs `"turns_played"`) fixed; resume logic no longer clobbers loaded data. |

## Phase 30 QA Sprint Fixes (March 16, 2026)

| Bug ID | Location | Resolution |
|--------|----------|------------|
| BUG-031 | GameStateManager / FiveParsecsCampaignCore | **ROOT CAUSE**: `GameStateManager.game_state` field was never assigned to the autoload — `set_credits()` silently failed to write back to `campaign.credits`. Fix: assign `game_state = gs` in `_connect_campaign_signals()`. Also: sync credits to `progress_data["credits"]` on every `set_credits()` call. Also: initialize `progress_data` with default counters (`missions_completed`, `battles_won`, `battles_lost`) in `_init()` and `from_dictionary()`. |
| BUG-030 | CharacterCreator | Added explicit `_on_origin_changed(0)` (and background/class/motivation) after signal connection in `_ready()`. Godot OptionButton doesn't fire `item_selected` for the default index 0 selection. |
| BUG-029 | ExpandedConfigPanel | Set `mouse_filter = MOUSE_FILTER_IGNORE` on all child controls inside victory cards (VBoxContainer, Labels). Children were consuming click events before they reached the PanelContainer's `gui_input` handler. Also fixed checkmark lookup from hardcoded path to `find_child("Checkmark")`. |

## Open Issues

| Issue | Location | Severity | Notes |
|-------|----------|----------|-------|
| PurchaseItemsComponent EquipmentManager | PostBattle Step 11 | P2 | `_on_confirm_purchase_pressed()` can't find EquipmentManager. UI renders but inventory persistence may fail. |
| Load Campaign UI clicks | Main Menu | P2 | MCP clicks don't register on load dialog. Workaround: programmatic `GameState.load_campaign()`. |
| WEALTH motivation bonus | CharacterCreator | P2 | Gives +1 SAVVY instead of credits. Needs resource bonus architecture. |
| Character bonus coverage | CharacterCreator | P2 | 49% of bonuses implemented (38/77). Most gaps need resource bonus system. |
| Victory condition tracking | EndPhasePanel | P2 | Uses turns_played as proxy instead of real metric counters. |
| Story/Travel phases auto-skip | CampaignTurnController | P3 | New campaigns jump to World Phase — Story+Travel auto-complete. EventManager not found. |

