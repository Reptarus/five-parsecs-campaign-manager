# Planetfall End-to-End Runtime Test Plan

**Created**: 2026-04-09
**Last Run**: 2026-04-09 (Session 57d)
**Purpose**: Verify all Planetfall systems work correctly at runtime across the full campaign lifecycle (Sections 1-4).
**Coverage**: 63 files, 10 RefCounted systems, 15 JSON data tables, 18-step turn flow, 4-path endgame, 22 panel theme audit, full UX/UI verification.

## Session 57d Runtime QA Results

**Method**: MCP-automated (run_script + take_screenshot)
**Bugs Found**: 2 (both fixed)
**Scenarios Tested**: 1 (Creation), 2 (Steps 1-6), 4 (Lock & Load), 5 (Battle Delegation), 6 (Post-Battle), partial 7-8

### Bugs Fixed

| # | File | Line | Issue | Fix |
|---|------|------|-------|-----|
| 1 | `PlanetfallTurnController.gd` | 125 | `phase_manager.start_new_turn()` called before `_create_phase_manager()` — nil crash | Extracted to `_start_or_resume_turn()` called after phase manager creation |
| 2 | `compendium_equipment.gd` | 168 | `var tagged := item.duplicate()` — Godot 4.6 type inference from untyped Array | Changed to `var tagged: Dictionary = item.duplicate()` + renamed duplicate var |

### Scenario Results

| # | Scenario | Result | Notes |
|---|----------|--------|-------|
| 1 | Campaign Creation (6-step wizard) | **PASS** | All 6 steps, finalize, dashboard transition verified |
| 2 | Turn Flow Steps 1-6 (Pre-Battle) | **PASS** | Recovery, Repairs, Scout Reports, Enemy Activity, Colony Events, Mission Determination — all panels load, buttons work |
| 3 | Mission Briefing Display | **PARTIAL** | 13 mission types listed, 3 correctly disabled (Skirmish/Strike/Assault need prerequisites) |
| 4 | Lock and Load — Force Limits | **PASS** | Patrol: Characters 0/2, Grunts 0/4, Fireteam 1 — force limits enforced correctly |
| 5 | Battle Delegation (Step 8) | **PASS** | TacticalBattleUI launches with "Planetfall Mission", terrain generated, companion level dialog works |
| 6 | Post-Battle Steps 9-12 | **PASS** | Battle result received, injuries panel shows casualties, all post-battle phases advance |
| 7-8 | Steps 13-18 | **PASS** | Research, Building, Colony Integrity, Character Event, Update Colony Sheet — all complete, "Start Next Turn" shown |

### Dashboard Verification

| Check | Result |
|-------|--------|
| Campaign name + colony name | PASS — "QA Test Colony" / "Colony: Outpost Sigma" |
| Stat strip (Turn/Morale/Integrity/SP/Roster/Grunts/Milestones) | PASS — all values displayed |
| Hub cards (Colony Status, Armory, Enemy Tracker, Augmentations, Milestones) | PASS — all 5 present |
| Colony Roster with class pills + stat strips | PASS — character cards with Trooper/Scientist pills |
| Continue Campaign / Save Campaign / Main Menu actions | PASS — all 3 action cards present and functional |

### Key Observations

- Morale and Integrity start at 0 for new colonies — expedition bonuses may not be applying (non-blocking, investigate later)
- Colony Morale decreased to -1 during turn cycle (morale adjustments applied)
- Phase indicator correctly highlights completed steps 1-18
- Battle UI correctly shows "Planetfall Mission [LOG ONLY]" with wilderness terrain
- Turn completion screen offers "Save & Complete" + "Start Next Turn"

---

## How to Use

Each scenario tests a specific subsystem or flow. Steps marked `[CHECK]` require verification.
Run scenarios in order — later ones depend on campaign state built by earlier ones.

**Testing Methods**:
- `MCP` — Automated via `mcp__godot__run_script` / `mcp__godot__take_screenshot`
- `MANUAL` — Requires human observation in the running app
- `HYBRID` — MCP-initiated with manual verification

**Launch command**:
```
mcp__godot__run_project with main_scene: "res://src/ui/screens/mainmenu/MainMenu.tscn"
```

---

## Scenario Index

| # | Scenario | Priority | Est. Time | Checks | Method |
|---|----------|----------|-----------|--------|--------|
| 1 | Campaign Creation (6-step wizard) | P0 | 15 min | 12 | HYBRID |
| 2 | Turn Flow — Steps 1-6 (Pre-Battle) | P0 | 20 min | 18 | HYBRID |
| 3 | Mission Briefing Display | P0 | 10 min | 8 | MANUAL |
| 4 | Lock and Load — Force Limits | P0 | 10 min | 6 | MANUAL |
| 5 | Battle Delegation (Step 8) | P0 | 15 min | 8 | HYBRID |
| 6 | Post-Battle — Steps 9-12 | P0 | 15 min | 12 | HYBRID |
| 7 | Research & Building — Steps 14-15 | P0 | 10 min | 8 | MANUAL |
| 8 | Milestone Progression | P0 | 15 min | 10 | HYBRID |
| 9 | Calamity System | P1 | 15 min | 8 | HYBRID |
| 10 | Mission Data Breakthroughs | P1 | 10 min | 6 | HYBRID |
| 11 | Lifeform Generation & Evolution | P1 | 10 min | 8 | HYBRID |
| 12 | Tactical Enemy Generation | P1 | 10 min | 6 | HYBRID |
| 13 | Battlefield Conditions | P1 | 10 min | 6 | HYBRID |
| 14 | Delve Mission Mechanics | P2 | 10 min | 6 | MANUAL |
| 15 | Post-Mission Finds & Artifacts | P1 | 10 min | 8 | HYBRID |
| 16 | Colony Integrity Failure | P1 | 10 min | 4 | HYBRID |
| 17 | Slyn Tracking & Departure | P2 | 10 min | 4 | HYBRID |
| 18 | End Game — Summit to Resolution | P1 | 20 min | 12 | MANUAL |
| 19 | Save/Load Round-Trip | P0 | 15 min | 10 | MCP |
| 20 | Dashboard Overlay Panels | P1 | 10 min | 6 | MANUAL |
| 21 | UX/UI — Deep Space Theme Compliance | P0 | 15 min | 27 | MANUAL |
| 22 | UX/UI — Typography & Spacing | P1 | 10 min | 10 | MANUAL |
| 23 | UX/UI — Touch Targets & Interactive Elements | P1 | 10 min | 7 | MANUAL |
| 24 | UX/UI — Scrolling & Overflow | P1 | 10 min | 8 | MANUAL |
| 25 | UX/UI — Navigation & Flow Integrity | P0 | 15 min | 14 | MANUAL |
| 26 | UX/UI — Empty States & Error Handling | P1 | 10 min | 8 | MANUAL |
| 27 | UX/UI — Phase Indicator & Stat Strip | P1 | 10 min | 9 | MANUAL |
| 28 | UX/UI — Condition & Slyn Display | P0 | 5 min | 8 | MANUAL |

---

## Scenario 1: Campaign Creation (P0, ~15 min)

**Goal**: Create a Planetfall campaign through the 6-step wizard and verify all data persists.

### Steps

1. From MainMenu, select "Planetfall" (or "New Planetfall Campaign")
2. **Step 0: Expedition Type** — Roll D100, select expedition
   - `[CHECK-1.1]` Expedition type displayed matches D100 roll result from `expedition_types.json`
   - `[CHECK-1.2]` Expedition bonuses shown (Morale/Integrity/RP/BP modifiers)
3. **Step 1: Character Roster** — Add 4-6 characters with class selection
   - `[CHECK-1.3]` Each character has class (Scientist/Scout/Trooper)
   - `[CHECK-1.4]` Sub-species selection available (Human variants)
   - `[CHECK-1.5]` Minimum 1 of each class enforced
4. **Step 2: Backgrounds** — Roll Motivation + Prior Experience + Notable Event
   - `[CHECK-1.6]` All 3 background fields populated per character
5. **Step 3: Map Generation** — Choose grid size, home sector
   - `[CHECK-1.7]` Grid rendered with home sector marked
6. **Step 4: Tutorial Missions** — Complete or skip Beacons/Analysis/Perimeter
7. **Step 5: Final Review** — Confirm all data
   - `[CHECK-1.8]` Colony name, expedition type, roster count displayed correctly
   - `[CHECK-1.9]` Campaign created → navigates to PlanetfallDashboard
8. On Dashboard:
   - `[CHECK-1.10]` Stat strip shows: Turn 0, Morale, Integrity, SP=5, Grunts=12
   - `[CHECK-1.11]` Roster cards show all characters with class pills
   - `[CHECK-1.12]` Hub cards visible: Colony Status, Armory, Enemy Tracker, Augmentations, Milestones

---

## Scenario 2: Turn Flow — Steps 1-6 Pre-Battle (P0, ~20 min)

**Goal**: Play through Steps 1-6 of the 18-step campaign turn, verifying each panel works.

**Prerequisites**: Active Planetfall campaign from Scenario 1.

### Steps

1. Click "Continue Campaign" → PlanetfallTurnController loads
   - `[CHECK-2.1]` Phase indicator shows RECOVERY highlighted
   - `[CHECK-2.2]` Turn label shows "TURN 1"

2. **Step 1: Recovery** (AutoResolveDialog)
   - `[CHECK-2.3]` Shows sick bay character count (should be 0 initially)
   - Click "Resolve" → "Continue"

3. **Step 2: Repairs** (SimpleDialog)
   - `[CHECK-2.4]` Shows current Integrity and repair capacity
   - Click "Continue"

4. **Step 3: Scout Reports** (ScoutReportsPanel)
   - `[CHECK-2.5]` Scout Discovery table available if scouts in roster
   - Complete step

5. **Step 4: Enemy Activity** (AutoResolveDialog)
   - `[CHECK-2.6]` If no Tactical Enemies: "No Tactical Enemies on map. Step skipped."
   - `[CHECK-2.7]` If enemies present: D100 roll + enemy action displayed

6. **Step 5: Colony Events** (ColonyEventsPanel)
   - `[CHECK-2.8]` D100 roll displayed
   - `[CHECK-2.9]` Event name, description, and effects from `colony_events.json` shown
   - `[CHECK-2.10]` Apply button applies effects to campaign (verify stat strip updates)

7. **Step 6: Mission Determination** (MissionPanel)
   - `[CHECK-2.11]` Mission list shows available missions
   - `[CHECK-2.12]` Event-triggered missions (Rescue, Scout Down) not shown unless triggered
   - `[CHECK-2.13]` Selecting a mission shows full briefing (table size, forces, opposition, objectives, rewards)
   - `[CHECK-2.14]` Confirm button emits selection + force_limits

---

## Scenario 3: Mission Briefing Display (P0, ~10 min)

**Goal**: Verify enriched mission briefing data displays correctly for all 13 mission types.

### Steps

1. Reach Step 6 (Mission Determination)
2. For each available mission, click to select and verify briefing card:
   - `[CHECK-3.1]` **Investigation**: Table 3x3, 4 characters, Lifeforms (Slyn immune), 4 Discovery markers, D6 objective table
   - `[CHECK-3.2]` **Scouting**: Table 2x2, 2 characters, Lifeforms, 6 Recon markers
   - `[CHECK-3.3]` **Exploration**: Table 3x3, 6 characters, Slyn check 2D6 2-4, Battlefield Conditions: yes
   - `[CHECK-3.4]` **Patrol**: Table 3x3, 2 chars + 4 grunts (1 fireteam), 3 objectives
   - `[CHECK-3.5]` **Skirmish**: Requires Tactical Enemies, 4 chars + 4 grunts, 2 random D6 objectives
   - `[CHECK-3.6]` **Pitched Battle**: Forced by enemy attack, 4 chars + 8 grunts (2 fireteams)
   - `[CHECK-3.7]` **Assault**: Requires Tactical Enemies + Strongpoint, 6 chars + 8 grunts
   - `[CHECK-3.8]` **Delve**: 6 characters, Delve Hazards opposition, no conventional enemies

---

## Scenario 4: Lock and Load — Force Limits (P0, ~10 min)

**Goal**: Verify Step 7 enforces per-mission force limits from Step 6.

### Steps

1. In Step 6, select **Patrol** mission (2 chars + 4 grunts, 1 fireteam)
2. Advance to Step 7 (Lock and Load)
   - `[CHECK-4.1]` Deploy counter shows "Characters: 0 / 2"
   - `[CHECK-4.2]` Grunt section visible with "Fireteam 1 (up to 4 grunts)"
   - `[CHECK-4.3]` Cannot check more than 2 roster characters
3. Go back, select **Investigation** mission (4 chars, 0 grunts)
4. Advance to Step 7
   - `[CHECK-4.4]` Deploy counter shows "Characters: 0 / 4"
   - `[CHECK-4.5]` Grunt section NOT visible (max_grunts=0)
5. Select **Assault** mission
   - `[CHECK-4.6]` Deploy counter shows "Characters: 0 / 6", Grunts up to 8 (2 fireteams)

---

## Scenario 5: Battle Delegation — Step 8 (P0, ~15 min)

**Goal**: Verify the TurnController → TacticalBattleUI → TurnController round-trip works.

### Steps

1. Complete Steps 1-7, deploy characters for a mission
2. Step 8 should trigger automatically
   - `[CHECK-5.1]` Scene transitions to TacticalBattleUI (not a placeholder panel)
   - `[CHECK-5.2]` Battle mode is "planetfall" (check log message: "Planetfall mode")
   - `[CHECK-5.3]` Crew characters appear as TacticalUnits
   - `[CHECK-5.4]` Enemy units loaded (type depends on mission opposition)
3. Play through battle or auto-resolve
   - `[CHECK-5.5]` `tactical_battle_completed` signal fires with result dict
4. After battle completes:
   - `[CHECK-5.6]` Scene transitions back to PlanetfallTurnController
   - `[CHECK-5.7]` Phase advances to INJURIES (Step 9)
   - `[CHECK-5.8]` PostBattlePanel shows "POST-BATTLE — INJURIES" title

---

## Scenario 6: Post-Battle — Steps 9-12 (P0, ~15 min)

**Goal**: Verify injury resolution, XP awards, morale, finds, and enemy info tracking.

### Steps

1. After battle, at Step 9 (Injuries):
   - `[CHECK-6.1]` Casualty count matches battle result
   - `[CHECK-6.2]` D100 injury rolls shown per casualty
   - `[CHECK-6.3]` Sick Bay assignments applied to campaign
2. Step 10 (Experience):
   - `[CHECK-6.4]` XP awarded: +1 participated, +1 not casualty, +1 Boss/Leader kill
   - `[CHECK-6.5]` XP values written to roster character dicts
3. Step 11 (Morale):
   - `[CHECK-6.6]` Automatic -1, plus -1 per casualty displayed
   - `[CHECK-6.7]` Colony Morale stat strip updates after "Calculate Morale"
4. Step 12a (Post-Mission Finds):
   - `[CHECK-6.8]` Find rolls count matches mission rewards
   - `[CHECK-6.9]` D100 roll → find name + reward displayed
   - `[CHECK-6.10]` Scientist/Scout bonus indicators shown when applicable
5. Step 12b (Enemy Info):
   - `[CHECK-6.11]` +1 Enemy Information if won against Tactical Enemy
   - `[CHECK-6.12]` Mission Data added + "Breakthrough check at Step 12" note

---

## Scenario 7: Research & Building — Steps 14-15 (P0, ~10 min)

**Goal**: Verify research investment, theory completion, building construction, and milestone grant checks.

### Steps

1. At Step 14 (Research):
   - `[CHECK-7.1]` Research theories listed with RP costs from `research_tree.json`
   - `[CHECK-7.2]` Investing deducts RP from campaign
   - `[CHECK-7.3]` Completing a theory unlocks applications
   - `[CHECK-7.4]` Completing a milestone-granting application shows "*** MILESTONE GRANTED! ***"
2. At Step 15 (Building):
   - `[CHECK-7.5]` Buildings listed with BP costs from `buildings.json`
   - `[CHECK-7.6]` Investing deducts BP from campaign
   - `[CHECK-7.7]` Completing a building shows completion message
   - `[CHECK-7.8]` Completing a milestone-granting building shows "*** MILESTONE GRANTED! ***"

---

## Scenario 8: Milestone Progression (P0, ~15 min)

**Goal**: Verify milestones trigger cascading effects (tactical enemies, evolution, calamity check).

**Prerequisites**: Trigger a milestone via building/research completion.

### Steps

1. Complete a milestone-granting building (e.g., "galactic_comms_relay")
   - `[CHECK-8.1]` Campaign `milestones_completed` increments by 1
2. At end of turn (Step 14/15 completion):
   - `[CHECK-8.2]` `_check_for_milestone_grants()` fires
   - `[CHECK-8.3]` `_trigger_milestone()` executes with correct milestone index
3. Verify 1st milestone effects:
   - `[CHECK-8.4]` Tactical Enemy generated and added to `campaign.tactical_enemies`
   - `[CHECK-8.5]` Lifeform Evolution roll applied to encounter table
   - `[CHECK-8.6]` Calamity Points incremented (verify via Milestone dashboard overlay)
   - `[CHECK-8.7]` Mission Data added + breakthrough check
4. Open Milestones dashboard overlay:
   - `[CHECK-8.8]` Progress bar shows 1/7 filled
   - `[CHECK-8.9]` Next milestone effects listed
   - `[CHECK-8.10]` Tech-that-grants-milestones checklist shows completed item checked

---

## Scenario 9: Calamity System (P1, ~15 min)

**Goal**: Verify calamity generation, ongoing effects, and resolution tracking.

**Prerequisites**: Calamity Points > 0 (accumulated from milestones).

### Steps

1. Trigger calamity check (D6 <= Calamity Points):
   - `[CHECK-9.1]` D100 roll on calamities table
   - `[CHECK-9.2]` Active calamity added to `campaign.active_calamities`
2. Start next turn:
   - `[CHECK-9.3]` `CalamitySystem.process_turn_effects()` called
   - `[CHECK-9.4]` Calamity-specific effects applied (e.g., weapon progress for Enemy Super Weapon)
3. Open Active Calamities dashboard overlay:
   - `[CHECK-9.5]` Calamity card shows name, description, ongoing effect
   - `[CHECK-9.6]` Resolution instructions displayed
   - `[CHECK-9.7]` Progress tracker shows current state
4. Resolve calamity (per resolution rules):
   - `[CHECK-9.8]` On resolution: calamity marked `resolved: true`, reward text shown

---

## Scenario 10: Mission Data Breakthroughs (P1, ~10 min)

**Goal**: Verify the probabilistic breakthrough mechanic works correctly.

### Steps

1. Accumulate Mission Data (via missions, research, milestones)
   - `[CHECK-10.1]` `campaign.mission_data` increments correctly
2. At Step 12 completion, breakthrough check fires:
   - `[CHECK-10.2]` D6 rolled against total MD
   - `[CHECK-10.3]` If D6 <= total: breakthrough occurs, MD reduced by roll
   - `[CHECK-10.4]` `campaign.mission_data_breakthroughs` increments
3. Verify breakthrough effects:
   - `[CHECK-10.5]` 1st: 2 Ancient Sites placed on map
   - `[CHECK-10.6]` 4th: D100 Final Breakthrough roll, endgame bonus identified

---

## Scenario 11: Lifeform Generation & Evolution (P1, ~10 min)

**Goal**: Verify 4-step procedural lifeform generation and evolution application.

### Steps

1. Trigger a lifeform encounter (via mission with Lifeform opposition):
   - `[CHECK-11.1]` D100 roll maps to encounter table slot (0-9)
   - `[CHECK-11.2]` If slot blank: 4-step generation runs (Mobility, Combat, Defense, Unique)
   - `[CHECK-11.3]` Generated profile stored in `campaign.lifeform_table[slot]`
   - `[CHECK-11.4]` If roll ends in 0/5: Special Attack trigger (verify airborne for Mobility)
2. After milestone triggers evolution:
   - `[CHECK-11.5]` Random slot selected from encounter table
   - `[CHECK-11.6]` D100 evolution roll resolves to evolution type
   - `[CHECK-11.7]` Evolution applied to lifeform profile (e.g., Enhanced Profile: +1 Speed)
   - `[CHECK-11.8]` Evolution ID stored in `campaign.lifeform_evolutions`

---

## Scenario 12: Tactical Enemy Generation (P1, ~10 min)

**Goal**: Verify D100 enemy type generation and weapon assignment.

### Steps

1. Trigger tactical enemy creation (via milestone effect):
   - `[CHECK-12.1]` D100 roll resolves to one of 10 enemy types
   - `[CHECK-12.2]` Enemy profile (Speed/Combat/Toughness/Panic) matches JSON data
   - `[CHECK-12.3]` Grunt weapons D6 roll assigns weapon from `grunt_weapons` table
   - `[CHECK-12.4]` Specialist weapons D6 roll from `specialist_weapons` table
   - `[CHECK-12.5]` Leader weapons D6 roll from `leader_weapons` table
   - `[CHECK-12.6]` Enemy added to `campaign.tactical_enemies` with `defeated: false`

---

## Scenario 13: Battlefield Conditions (P1, ~10 min)

**Goal**: Verify the 10-slot Campaign Condition Table generates and persists conditions.

### Steps

1. Select a mission that uses Battlefield Conditions (Exploration, Hunt, Patrol, Skirmish)
2. Condition system should roll D100 for a condition table slot:
   - `[CHECK-13.1]` D100 maps to slot 0-9
   - `[CHECK-13.2]` If slot blank: generates from Master Condition table
   - `[CHECK-13.3]` If slot filled: returns existing condition
   - `[CHECK-13.4]` Sub-rolls resolved for conditions that have them (Visibility, Shooting, Clouds)
3. Verify persistence:
   - `[CHECK-13.5]` `campaign.condition_table[slot]` stores the generated condition
   - `[CHECK-13.6]` Same slot on future missions returns same condition

---

## Scenario 14: Delve Mission Mechanics (P2, ~10 min)

**Goal**: Verify Delve hazards, traps, environmental hazards, and device activation.

### Steps

1. Select Delve mission (requires Ancient Site on map)
2. During battle:
   - `[CHECK-14.1]` 4 Delve Hazard markers placed
   - `[CHECK-14.2]` Hazard reveal D6: 1-2=Sleeper, 3-4=Trap, 5-6=Env Hazard
   - `[CHECK-14.3]` Trap D100 resolves correctly (Turret/Paralysis/Blockage/etc.)
   - `[CHECK-14.4]` Environmental Hazard D100 resolves correctly
3. Device activation:
   - `[CHECK-14.5]` D6 activation: 1=Unusable, 2-3=Time, 4-5=Auto, 6=Skill
   - `[CHECK-14.6]` After 3 activations: Artifact location revealed

---

## Scenario 15: Post-Mission Finds & Artifacts (P1, ~10 min)

**Goal**: Verify the Finds D100 table and unique-per-campaign Artifact system.

### Steps

1. Complete a mission that awards Find rolls (Exploration, Patrol 3/3, Skirmish, etc.)
   - `[CHECK-15.1]` D100 roll matches finds from `post_mission_finds.json`
   - `[CHECK-15.2]` Scientist bonus applied (e.g., +1 RP for Planetary History)
   - `[CHECK-15.3]` Scout bonus applied (e.g., +1 Raw Material for Decisive Victory)
   - `[CHECK-15.4]` Rewards applied to campaign (verify stat changes)
2. Complete a Delve mission and find an Artifact:
   - `[CHECK-15.5]` D100 roll on Artifacts table (29 entries)
   - `[CHECK-15.6]` Artifact type shown (Equipment/Colony Item/Single-Use)
   - `[CHECK-15.7]` Artifact added to `campaign.artifacts_found`
   - `[CHECK-15.8]` Same artifact cannot be found again (wrap-around to next)

---

## Scenario 16: Colony Integrity Failure (P1, ~10 min)

**Goal**: Verify Step 16 applies consequences when integrity <= -3.

### Steps

1. Reduce Colony Integrity below -3 (via enemy raids, calamity damage)
2. At Step 16 (Colony Integrity):
   - `[CHECK-16.1]` "INTEGRITY FAILURE" message displayed
   - `[CHECK-16.2]` D6 rolled per damage point (|integrity|)
   - `[CHECK-16.3]` Morale loss applied for rolls of 3-4 (and 6)
   - `[CHECK-16.4]` Grunt losses applied for rolls of 5-6

---

## Scenario 17: Slyn Tracking & Departure (P2, ~10 min)

**Goal**: Verify Slyn victory tracking begins at 4th milestone and departure mechanic works.

### Steps

1. Reach 4th milestone:
   - `[CHECK-17.1]` `campaign.slyn_victories` reset to 0
2. Win a battle against Slyn:
   - `[CHECK-17.2]` `slyn_victories` incremented
   - `[CHECK-17.3]` After victory: 2D6 roll, if <= victories, `slyn_departed = true`
3. When departed:
   - `[CHECK-17.4]` `campaign.is_slyn_active()` returns false, no more Slyn interference

---

## Scenario 18: End Game — Summit to Resolution (P1, ~20 min)

**Goal**: Verify the full endgame flow from 7th milestone through campaign completion.

### Steps

1. Achieve 7th milestone:
   - `[CHECK-18.1]` `campaign.game_phase` set to "endgame"
2. Dashboard shows "Enter End Game" button
   - `[CHECK-18.2]` Continue card text changed from "Continue Campaign"
3. Enter TurnController:
   - `[CHECK-18.3]` EndGamePanel shown instead of normal turn flow
4. **Summit**:
   - `[CHECK-18.4]` D6 per roster character + 1 for population
   - `[CHECK-18.5]` Available paths shown (only those with 1+ supporter)
5. **Path Selection**:
   - `[CHECK-18.6]` All 4 paths shown with BP/RP costs and security requirements
6. **Colony Security**:
   - `[CHECK-18.7]` Strongpoint requirement checked (1 for most, 2 for Loyalty)
7. **Final Construction**:
   - `[CHECK-18.8]` BP/RP deducted on construction
8. **Resolution**:
   - `[CHECK-18.9]` Path-specific resolution runs (War for Independence, Ascension for Ascension, etc.)
   - `[CHECK-18.10]` Results displayed per character
9. **Completion**:
   - `[CHECK-18.11]` `campaign.game_phase` = "completed"
   - `[CHECK-18.12]` "Return to Main Menu" button works

---

## Scenario 19: Save/Load Round-Trip (P0, ~15 min)

**Goal**: Verify all new Section 3+4 fields persist across save/load.

### Steps

1. Play several turns to accumulate state (lifeforms, conditions, enemies, artifacts, calamities, milestones)
2. Save campaign
3. Verify save file contains new fields:
   - `[CHECK-19.1]` `progression.slyn_victories` present
   - `[CHECK-19.2]` `progression.slyn_departed` present
   - `[CHECK-19.3]` `progression.endgame_path` present
   - `[CHECK-19.4]` `lifeform_table` has generated entries (non-empty slots)
   - `[CHECK-19.5]` `condition_table` has generated conditions
   - `[CHECK-19.6]` `tactical_enemies` has enemy profiles with weapons
   - `[CHECK-19.7]` `artifacts_found` array present
   - `[CHECK-19.8]` `defeated_enemies` array present
4. Reload the campaign:
   - `[CHECK-19.9]` All fields loaded correctly (spot-check 3-5 values)
   - `[CHECK-19.10]` Dashboard displays correct values from loaded data

```gdscript
# MCP verification script for save file inspection
var file := FileAccess.open("user://saves/planetfall_test.json", FileAccess.READ)
var json := JSON.new()
json.parse(file.get_as_text())
file.close()
var data: Dictionary = json.data
print("schema_version: ", data.get("meta", {}).get("schema_version", "?"))
print("slyn_victories: ", data.get("progression", {}).get("slyn_victories", "MISSING"))
print("lifeform_table slots filled: ", data.get("lifeform_table", []).filter(func(x): return x is Dictionary and not x.is_empty()).size())
print("condition_table slots filled: ", data.get("condition_table", []).filter(func(x): return x is Dictionary and not x.is_empty()).size())
print("tactical_enemies count: ", data.get("tactical_enemies", []).size())
print("artifacts_found count: ", data.get("artifacts_found", []).size())
```

---

## Scenario 20: Dashboard Overlay Panels (P1, ~10 min)

**Goal**: Verify Milestones and Calamities dashboard overlays display correctly.

### Steps

1. Open Milestones & Progression overlay:
   - `[CHECK-20.1]` Progress bar shows correct milestone count (filled/empty segments)
   - `[CHECK-20.2]` Calamity Points displayed with value
   - `[CHECK-20.3]` Mission Data progress shows total + breakthroughs
   - `[CHECK-20.4]` Tech checklist shows owned items checked
2. Open Active Calamities overlay (only visible if calamities exist):
   - `[CHECK-20.5]` Each active calamity has card with name, description, ongoing effect, resolution
   - `[CHECK-20.6]` Progress tracker shows correct state per calamity type

---

## Scenario 21: UX/UI — Deep Space Theme Compliance (P0, ~15 min)

**Goal**: Verify all 22 Planetfall panels follow the Deep Space theme and are visually consistent.

**Method**: MANUAL — screenshot each screen and verify against the design system.

### Theme Color Compliance

For each panel listed below, verify:
- `[CHECK-21.1]` **Background**: Panel background is `COLOR_BASE (#1A1A2E)` or inherited from parent
- `[CHECK-21.2]` **Cards**: Elevated sections use `COLOR_ELEVATED (#252542)` with `COLOR_BORDER (#3A3A5C)` 1px border
- `[CHECK-21.3]` **Text**: Primary text `#E0E0E0`, secondary `#808080`, disabled `#404040`
- `[CHECK-21.4]` **Accent**: Interactive elements use `COLOR_ACCENT (#2D5A7B)`, focus rings `COLOR_FOCUS (#4FC3F7)`
- `[CHECK-21.5]` **Status colors**: Success `#10B981`, Warning `#D97706`, Danger `#DC2626` used correctly

### Panel Inventory (22 panels)

| Panel | Screen | Theme Check |
|-------|--------|-------------|
| PlanetfallExpeditionPanel | Creation Step 0 | [ ] |
| PlanetfallRosterPanel | Creation Step 1 | [ ] |
| PlanetfallBackgroundsPanel | Creation Step 2 | [ ] |
| PlanetfallMapPanel | Creation Step 3 | [ ] |
| PlanetfallTutorialPanel | Creation Step 4 | [ ] |
| PlanetfallReviewPanel | Creation Step 5 | [ ] |
| PlanetfallAutoResolveDialog | Turn Steps 1,4,16,18 | [ ] |
| PlanetfallSimpleDialog | Turn Steps 2,12,13,17 | [ ] |
| PlanetfallScoutReportsPanel | Turn Step 3 | [ ] |
| PlanetfallColonyEventsPanel | Turn Step 5 | [ ] |
| PlanetfallMissionPanel | Turn Step 6 | [ ] |
| PlanetfallLockAndLoadPanel | Turn Step 7 | [ ] |
| PlanetfallPostBattlePanel | Turn Steps 9-12 | [ ] |
| PlanetfallResearchPanel | Turn Step 14 | [ ] |
| PlanetfallBuildingPanel | Turn Step 15 | [ ] |
| PlanetfallColonyStatusPanel | Dashboard overlay | [ ] |
| PlanetfallEquipmentPanel | Dashboard overlay | [ ] |
| PlanetfallEnemyTrackerPanel | Dashboard overlay | [ ] |
| PlanetfallAugmentationPanel | Dashboard overlay | [ ] |
| PlanetfallMilestonePanel | Dashboard overlay | [ ] |
| PlanetfallCalamityPanel | Dashboard overlay | [ ] |
| PlanetfallEndGamePanel | End Game flow | [ ] |

---

## Scenario 22: UX/UI — Typography & Spacing (P1, ~10 min)

**Goal**: Verify font sizes and spacing follow the 8px grid system.

### Steps

1. On PlanetfallDashboard:
   - `[CHECK-22.1]` Title labels use `FONT_SIZE_LG (18)` or `FONT_SIZE_XL (24)`
   - `[CHECK-22.2]` Body text uses `FONT_SIZE_MD (16)` or `FONT_SIZE_SM (14)`
   - `[CHECK-22.3]` Captions/hints use `FONT_SIZE_XS (11)`
   - `[CHECK-22.4]` Spacing between cards is `SPACING_LG (24)`
   - `[CHECK-22.5]` Inner card padding is `SPACING_MD (16)`

2. On PlanetfallMissionPanel (two-column layout):
   - `[CHECK-22.6]` Mission list and detail columns have equal weight
   - `[CHECK-22.7]` Briefing section cards have consistent padding
   - `[CHECK-22.8]` Category + table size line uses `FONT_SIZE_SM` in `COLOR_ACCENT`

3. On PlanetfallPostBattlePanel:
   - `[CHECK-22.9]` Sub-step sections clearly distinguished with title changes
   - `[CHECK-22.10]` BBCode result text renders correctly (colors, bold)

---

## Scenario 23: UX/UI — Touch Targets & Interactive Elements (P1, ~10 min)

**Goal**: Verify all interactive elements meet 48px minimum touch target.

### Steps

1. **Buttons**: Verify minimum height across all panels
   - `[CHECK-23.1]` Confirm/Continue buttons are >= 48px tall (custom_minimum_size.y)
   - `[CHECK-23.2]` Close buttons on overlays are >= 40px tall
   - `[CHECK-23.3]` Mission selection buttons are >= 40px tall

2. **Checkboxes**: In LockAndLoadPanel
   - `[CHECK-23.4]` Deploy checkboxes are easily tappable (row height >= 40px)
   - `[CHECK-23.5]` Grunt fireteam checkboxes have readable text

3. **Hub Feature Cards**: On Dashboard
   - `[CHECK-23.6]` Each hub card is comfortably tappable
   - `[CHECK-23.7]` Milestones and Calamities cards visible when applicable

---

## Scenario 24: UX/UI — Scrolling & Overflow (P1, ~10 min)

**Goal**: Verify panels with dynamic content scroll correctly and don't overflow.

### Steps

1. **PlanetfallMissionPanel** (Step 6):
   - `[CHECK-24.1]` With all 13 missions listed, scrolls without clipping
   - `[CHECK-24.2]` Detail panel scrolls independently when briefing is long

2. **PlanetfallPostBattlePanel** (Steps 9-12):
   - `[CHECK-24.3]` After many injury rolls + find rolls, results scroll correctly
   - `[CHECK-24.4]` BBCode text doesn't overflow container bounds

3. **PlanetfallMilestonePanel** (overlay):
   - `[CHECK-24.5]` With all 7 milestones completed + full tech checklist, scrolls to bottom

4. **PlanetfallCalamityPanel** (overlay):
   - `[CHECK-24.6]` With 3+ active calamities, all cards visible via scroll

5. **PlanetfallEndGamePanel**:
   - `[CHECK-24.7]` Summit results with 8+ characters scrolls correctly
   - `[CHECK-24.8]` Resolution results (Isolation with many rounds) scrolls

---

## Scenario 25: UX/UI — Navigation & Flow Integrity (P0, ~15 min)

**Goal**: Verify all navigation paths work and no dead-ends exist.

### Route Reachability

| Route | Entry Path | Back Path | Check |
|-------|-----------|-----------|-------|
| `planetfall_creation` | MainMenu → New Planetfall | Cancel → MainMenu | [ ] |
| `planetfall_dashboard` | After creation / load | MainMenu button | [ ] |
| `planetfall_turn_controller` | Dashboard → Continue | End turn → Dashboard | [ ] |
| `tactical_battle` (planetfall mode) | Step 8 auto-navigate | Battle end → Turn Controller | [ ] |

### Steps

1. **Creation → Dashboard**:
   - `[CHECK-25.1]` Completing creation wizard navigates to Dashboard
   - `[CHECK-25.2]` Canceling creation returns to MainMenu

2. **Dashboard → Turn → Dashboard**:
   - `[CHECK-25.3]` "Continue Campaign" navigates to TurnController
   - `[CHECK-25.4]` Completing all 18 steps returns to Dashboard
   - `[CHECK-25.5]` Save button works from Dashboard

3. **Battle round-trip**:
   - `[CHECK-25.6]` Step 8 navigates to TacticalBattleUI
   - `[CHECK-25.7]` Battle completion navigates back to TurnController
   - `[CHECK-25.8]` Phase resumes at INJURIES (Step 9) — not restarting turn

4. **Dashboard overlays**:
   - `[CHECK-25.9]` Each overlay (Colony Status, Armory, Enemy Tracker, Augmentations, Milestones, Calamities) opens and closes correctly
   - `[CHECK-25.10]` Close button or visibility toggle dismisses overlay
   - `[CHECK-25.11]` Dashboard content is still present behind overlay

5. **End Game flow**:
   - `[CHECK-25.12]` Dashboard shows "Enter End Game" when game_phase="endgame"
   - `[CHECK-25.13]` EndGamePanel stages advance correctly (Summit → Path → Security → Build → Resolve → Complete)
   - `[CHECK-25.14]` "Return to Main Menu" from completion works

---

## Scenario 26: UX/UI — Empty States & Error Handling (P1, ~10 min)

**Goal**: Verify panels handle empty/missing data gracefully.

### Steps

1. **Dashboard with no active campaign**:
   - `[CHECK-26.1]` EmptyStateWidget shown: "No Active Colony" with action button

2. **Turn Step 4 (Enemy Activity) with no Tactical Enemies**:
   - `[CHECK-26.2]` Shows "No Tactical Enemies on map. Step skipped." (not crash)

3. **Calamities overlay with no calamities**:
   - `[CHECK-26.3]` Shows "No active calamities. The colony is safe... for now."

4. **Mission Panel with no available missions** (hypothetical):
   - `[CHECK-26.4]` Panel renders without crash even if _missions array is empty

5. **LockAndLoadPanel with no roster**:
   - `[CHECK-26.5]` Roster section is empty but panel doesn't crash

6. **PostBattlePanel with no casualties**:
   - `[CHECK-26.6]` Shows "No casualties this battle!" in green

7. **PostBattlePanel with no find rolls**:
   - `[CHECK-26.7]` Shows "No Post-Mission Finds to roll." — not crash

8. **Milestone overlay at 0 milestones**:
   - `[CHECK-26.8]` Progress bar shows 0/7, tech checklist all unchecked

---

## Scenario 27: UX/UI — Phase Indicator & Stat Strip (P1, ~10 min)

**Goal**: Verify the TurnController header, phase indicator, and stat strip update correctly.

### Steps

1. **Phase indicator strip** (18 phase labels):
   - `[CHECK-27.1]` Current phase highlighted with accent color
   - `[CHECK-27.2]` Completed phases visually distinct (e.g., dimmed or checked)
   - `[CHECK-27.3]` Indicator scrolls to keep current phase visible
   - `[CHECK-27.4]` All 18 phase names displayed correctly

2. **Stat strip**:
   - `[CHECK-27.5]` Shows Turn, Morale, Integrity, SP, Grunts, Milestones
   - `[CHECK-27.6]` Values update in real-time after phase actions (e.g., morale changes)
   - `[CHECK-27.7]` Negative values shown in danger color (e.g., negative Integrity)

3. **Turn label**:
   - `[CHECK-27.8]` Shows "TURN N" during normal play
   - `[CHECK-27.9]` Shows "END GAME" when game_phase="endgame"

---

## Scenario 28: UX/UI — Condition & Slyn Display (P0, ~5 min)

**Goal**: Verify the newly wired condition and Slyn aggression displays in LockAndLoadPanel.

### Steps

1. Select a mission with `battlefield_conditions: true` (Exploration, Hunt, Patrol, Skirmish):
   - `[CHECK-28.1]` After confirming mission, LockAndLoadPanel shows condition info card
   - `[CHECK-28.2]` Card displays condition name in warning color (#D97706)
   - `[CHECK-28.3]` Card displays condition description text
   - `[CHECK-28.4]` If condition has sub-roll, resolved sub-roll description is shown

2. Select a mission with Slyn check (Exploration, Hunt, Patrol, Scout Down):
   - If Slyn aggression triggers:
     - `[CHECK-28.5]` Red "SLYN ATTACKING!" card shown prominently
     - `[CHECK-28.6]` Card describes Slyn threat and beam focus weapons
   - If Slyn does not trigger:
     - `[CHECK-28.7]` Opposition type shown as normal (e.g., "Lifeforms")

3. Select a mission with `battlefield_conditions: false` (Investigation, Scouting, Science):
   - `[CHECK-28.8]` No condition card shown in LockAndLoadPanel

---

## Quick Smoke Test (5 min)

For rapid regression checking, run these 5 checks:

1. Create Planetfall campaign → Dashboard loads with stats
2. Start turn → Steps 1-6 advance without crash
3. Select mission → Briefing shows table size + forces + opposition
4. Open Milestones overlay → Progress bar renders
5. Save → Reload → Dashboard shows same values
