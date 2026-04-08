# Ship Component System — Runtime QA Test Plan

**Created**: 2026-04-07
**Scope**: 16 ship components (14 Core Rules pp.60-62 + 2 Compendium p.28) wired into campaign loop
**Test Cases**: 40 across 7 priority groups
**Status**: IN PROGRESS

---

## Test Matrix

| ID | System | Component | Description | Status |
|----|--------|-----------|-------------|--------|
| SCQ-01 | Query | All | Component query with populated ship data | **PASS** |
| SCQ-02 | Query | All | Empty/missing components key | **PASS** |
| SCQ-03 | Query | Miniaturized | Billable count excludes miniaturized | **PASS** |
| SCQ-04 | Query | All | GameStateManager unavailable (safe defaults) | UNTESTED |
| TRV-01 | Travel | All | Fuel cost with billable component surcharge | UNTESTED |
| TRV-02 | Travel | Military Fuel Converters | -2 credit fuel reduction | UNTESTED |
| TRV-03 | Travel | Military Fuel Converters | Cost floor at zero (no negative) | UNTESTED |
| TRV-04 | Travel | All | ShipManager vs TravelPhase cost parity | UNTESTED |
| TRV-05 | Travel | Cargo Hold | Revenue happy path (2D6, discard 5-6) | UNTESTED |
| TRV-06 | Travel | Cargo Hold | Both dice >= 5 (zero revenue) | UNTESTED |
| TRV-07 | Travel | Cargo Hold | Ship damaged — cargo lost | UNTESTED |
| TRV-08 | Travel | Hidden Compartment | Revenue (3D6, keep 1-2s) | UNTESTED |
| TRV-09 | Travel | Scientific Research | D6 table (nothing/2cr/rumor) | UNTESTED |
| TRV-10 | Travel | Probe Launcher | Asteroids — roll twice take higher | UNTESTED |
| TRV-11 | Travel | Military Nav System | Navigation Trouble — no SP loss | UNTESTED |
| TRV-12 | Travel | Military Nav System | Travel-Time — also Uneventful Trip | UNTESTED |
| TRV-13 | Travel | Auto-Turrets | Raided — +1 avoidance | UNTESTED |
| TRV-14 | Travel | Auto-Turrets | Invasion flee — +1 | UNTESTED |
| TRV-15 | Travel | Shuttle | Invasion flee — +2 | UNTESTED |
| TRV-16 | Travel | Shuttle | Distress Call — roll twice | UNTESTED |
| TRV-17 | Travel | Hidden Compartment | Patrol Ship — 1 roll not 2 | UNTESTED |
| UPK-01 | Upkeep | Living Quarters | Crew count -2 (both systems) | UNTESTED |
| UPK-02 | Upkeep | Suspension Pod | Component gate divergence (BUG-1) | **FIXED** |
| UPK-03 | Upkeep | Suspension Pod | Counting algorithm divergence (BUG-2) | UNTESTED |
| UPK-04 | Upkeep | Suspension Pod + LQ | Combined effect stacking | UNTESTED |
| UPK-05 | Upkeep | Living Quarters | Small crew (below threshold) | UNTESTED |
| BTL-01 | Battle | Drop Launcher | 2D6 roll at battle setup | UNTESTED |
| BTL-02 | Battle | Drop Launcher | Journal entry on success/fail | UNTESTED |
| BTL-03 | Battle | Drop Launcher | Not installed — no key in data | UNTESTED |
| PBT-01 | PostBattle | Expanded Database | +1 quest progress roll | UNTESTED |
| PBT-02 | PostBattle | Expanded Database | Journal entry with correct tags | UNTESTED |
| PBT-03 | PostBattle | Medical Bay | Accelerated recovery (+1 extra) | UNTESTED |
| PBT-04 | PostBattle | Medical Bay | Selects highest-remaining candidate | UNTESTED |
| PBT-05 | PostBattle | Medical Bay | Skips suspended crew | UNTESTED |
| PBT-06 | PostBattle | Medical Bay | No injured crew — no crash | UNTESTED |
| DMG-01 | Damage | Improved Shielding | Reduces damage by 1 | **PASS** |
| DMG-02 | Damage | Improved Shielding | Does not reduce below 0 | **PASS** |
| DMG-03 | Damage | Improved Shielding | Stacks with Armored trait | UNTESTED |
| JRN-01 | Journal | All | CampaignJournal null — no crash | UNTESTED |
| JRN-02 | Journal | All | All entries include "ship_component" tag | UNTESTED |

---

## Known Bugs (Found During Code Review)

| ID | Severity | Description | File:Line |
|----|----------|-------------|-----------|
| BUG-1 | **Medium** | `UpkeepSystem.gd` does NOT gate Suspension Pod on `has_component()` — uses `suspended_crew` list even if pod is uninstalled. `UpkeepPhaseComponent.gd` correctly gates. | `UpkeepSystem.gd:71` vs `UpkeepPhaseComponent.gd:145` |
| BUG-2 | Low | Suspension Pod counting differs: UpkeepSystem iterates crew IDs (accurate), UpkeepPhaseComponent subtracts `suspended.size()` (could desync with stale IDs) | `UpkeepSystem.gd:73-83` vs `UpkeepPhaseComponent.gd:152-154` |
| BUG-3 | Low | Hidden Compartment revenue logs nothing when all dice > 2 (other components always log) | `TravelPhase.gd:1098-1117` |
| RISK-1 | **Medium** | Travel cost formula duplicated in `TravelPhase.gd:126-149` AND `ShipManager.gd:181-206` — will drift | Both files |

---

## Priority 1 — ShipComponentQuery Foundation

Key file: `src/core/ship/ShipComponentQuery.gd`

All component checks in the entire system flow through this class. If these fail, nothing downstream is trustworthy.

### SCQ-01: Component query with populated ship data

**Setup**: Ensure `GameStateManager.get_ship_data()` returns dict with `"components": ["medical_bay", "cargo_hold"]`

**Expected**:
- `ShipComponentQuery.has_component("medical_bay")` → `true`
- `ShipComponentQuery.has_component("nonexistent")` → `false`
- `ShipComponentQuery.get_installed_ids()` → `["medical_bay", "cargo_hold"]`
- `ShipComponentQuery.get_component_count()` → `2`

**Code Reference**:
- `ShipComponentQuery.gd:18-20` — `has_component()` checks `component_id in components`
- `ShipComponentQuery.gd:24-29` — `get_installed_ids()` reads `ship.get("components", [])`
- `ShipComponentQuery.gd:62-68` — `_get_ship_data()` accesses GameStateManager via scene tree

**MCP Script**:
```gdscript
var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
var ship = gsm.get_ship_data() if gsm else {}
print("ship_data keys: ", ship.keys())
print("components: ", ship.get("components", "MISSING"))
print("has medical_bay: ", ShipComponentQuery.has_component("medical_bay"))
print("has nonexistent: ", ShipComponentQuery.has_component("nonexistent"))
print("installed_ids: ", ShipComponentQuery.get_installed_ids())
print("count: ", ShipComponentQuery.get_component_count())
```

**Status**: UNTESTED

---

### SCQ-02: Empty/missing components key

**Setup**: Ship data dict exists but `"components"` key is absent or value is `null`

**Expected**:
- `get_installed_ids()` → `[]`
- `has_component("anything")` → `false`
- `get_component_count()` → `0`
- No crash

**Code Reference**:
- `ShipComponentQuery.gd:28` — `ship.get("components", [])` provides empty default
- `ShipComponentQuery.gd:29` — `components if components is Array else []` type guard

**Status**: UNTESTED

---

### SCQ-03: Billable count excludes miniaturized

**Setup**: 4 components installed, 1 listed in `ship_data["miniaturized_components"]`

**Expected**: `get_billable_component_count()` → `3`

**Code Reference**:
- `ShipComponentQuery.gd:49-55` — iterates IDs, skips those where `is_miniaturized()` returns true
- `ShipComponentQuery.gd:39-44` — `is_miniaturized()` checks `ship.get("miniaturized_components", [])`

**MCP Script**:
```gdscript
var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
var ship = gsm.get_ship_data() if gsm else {}
ship["components"] = ["medical_bay", "cargo_hold", "shuttle", "auto_turrets"]
ship["miniaturized_components"] = ["cargo_hold"]
print("total: ", ShipComponentQuery.get_component_count())       # expect 4
print("billable: ", ShipComponentQuery.get_billable_component_count())  # expect 3
print("cargo miniaturized: ", ShipComponentQuery.is_miniaturized("cargo_hold"))  # expect true
print("shuttle miniaturized: ", ShipComponentQuery.is_miniaturized("shuttle"))    # expect false
```

**Status**: UNTESTED

---

### SCQ-04: GameStateManager unavailable (safe defaults)

**Setup**: Call queries before scene tree is ready or in headless mode without autoloads

**Expected**: All methods return safe defaults (`[]`, `false`, `0`). No crash.

**Code Reference**:
- `ShipComponentQuery.gd:63` — `Engine.get_main_loop()` guard (returns null if no main loop)
- `ShipComponentQuery.gd:64` — `get_node_or_null("/root/GameStateManager")` returns null gracefully

**Status**: UNTESTED

---

## Priority 2 — Travel Phase

Key file: `src/core/campaign/phases/TravelPhase.gd`

### TRV-01: Fuel cost with billable component surcharge

**Setup**: 6 components installed, 1 miniaturized. Billable = 5. No fuel traits. No fuel converters.

**Expected**: `5 (base) + floor(5/3) = 5 + 1 = 6`

**Code Reference**:
- `TravelPhase.gd:140` — `ShipComponentQuery.get_billable_component_count()`
- `TravelPhase.gd:142-143` — `base_cost += billable / 3` (integer division)

**Status**: UNTESTED

---

### TRV-02: Military Fuel Converters reduces cost by 2

**Setup**: Military Fuel Converters installed, 0 other billable components, base cost = 5

**Expected**: `5 - 2 = 3`

**Code Reference**:
- `TravelPhase.gd:146-147` — `has_component("military_fuel_converters")` → `base_cost -= 2`

**Status**: UNTESTED

---

### TRV-03: Cost floor at zero

**Setup**: Base cost 5, Fuel-efficient trait (-1) = 4, military_fuel_converters (-2) = 2, 0 billable. Then test with Fuel-efficient + MFC on base 5: 5-1-2=2. Also test extreme: 2 fuel-efficient traits... Actually traits loop so only 1 applies. Test: base 5, fuel efficient (-1), MFC (-2) = 2.

For floor test: inject base_cost to be low enough. Simplest: set `travel_costs["starship_travel"] = 1`, add MFC → `1 - 2 = -1` → clamped to 0.

**Expected**: Returns `0`, not negative

**Code Reference**:
- `TravelPhase.gd:149` — `return max(0, base_cost)` (note: `max()` not `maxi()`)

**Status**: UNTESTED

---

### TRV-04: ShipManager vs TravelPhase cost parity

**CRITICAL**: Both files implement the same formula independently.

**Setup**: Same ship_data with traits + components

**Expected**: Both return identical values

**Code Reference**:
- `TravelPhase.gd:125-149` — `_calculate_travel_cost()` uses `max(0, base_cost)` (float max)
- `ShipManager.gd:181-206` — `_calculate_travel_cost()` uses `maxi(0, base_cost)` (int max)
- Functionally identical for integer inputs, but `max()` returns float in Godot 4.6

**Risk**: If TravelPhase returns `float` and caller expects `int`, comparison could fail.

**Status**: UNTESTED

---

### TRV-05: Cargo Hold revenue — happy path

**Setup**: `cargo_hold` installed, `_ship_damaged_this_travel = false`

**Expected**: Rolls 2D6. Dice showing 5 or 6 are discarded. Earn highest remaining die value. Credits added via `game_state_manager.add_credits()`.

**Code Reference**:
- `TravelPhase.gd:1070` — `has_component("cargo_hold")`
- `TravelPhase.gd:1073-1076` — dice filtering (`if d1 < 5: valid.append(d1)`)
- `TravelPhase.gd:1084` — `var revenue: int = valid.max()`
- `TravelPhase.gd:1085-1086` — credits added

**Status**: UNTESTED

---

### TRV-06: Cargo Hold — both dice >= 5

**Expected**: `valid` array is empty, no credits earned. Journal: "No Cargo Available"

**Code Reference**:
- `TravelPhase.gd:1092-1096` — else branch when `valid.size() == 0` (implicit via elif chain)

**Status**: UNTESTED

---

### TRV-07: Cargo Hold — ship damaged during travel

**Setup**: `_ship_damaged_this_travel = true` (set by Asteroids at line 578 or Distress Call at line 655)

**Expected**: Cargo lost regardless of dice. Journal: "Cargo Lost"

**Code Reference**:
- `TravelPhase.gd:1078-1082` — checked BEFORE revenue calculation
- `TravelPhase.gd:1057` — flag reset happens AFTER revenue processing (correct order)

**Status**: UNTESTED

---

### TRV-08: Hidden Compartment revenue

**Setup**: `hidden_compartment` installed

**Expected**: 3D6 rolled. Keep only dice showing 1 or 2. Sum kept dice = revenue. Credits added.

**Edge case (BUG-3)**: If all dice > 2, revenue = 0 and NO journal entry is created. Inconsistent with Cargo Hold which always logs.

**Code Reference**:
- `TravelPhase.gd:1099-1117` — full implementation
- `TravelPhase.gd:1104-1107` — filtering `if d <= 2: kept.append(d)`
- `TravelPhase.gd:1111` — credits only added `if revenue > 0`

**Status**: UNTESTED

---

### TRV-09: Scientific Research System (D6 table)

**Setup**: `scientific_research_system` installed (Compendium p.28)

**Expected**:
- Roll 1-2: Nothing. Journal: "Nothing found"
- Roll 3-4: +2 credits. Journal: "Research data analyzed"
- Roll 5-6: +1 Quest Rumor. Journal: "Quest Rumor"

**Code Reference**:
- `TravelPhase.gd:1120-1141` — match statement on roll value
- `TravelPhase.gd:1129-1130` — `add_credits(2)` gated on `has_method`
- `TravelPhase.gd:1136-1137` — `add_quest_rumor()` gated on `has_method`

**Status**: UNTESTED

---

### TRV-10: Probe Launcher on Asteroids

**Setup**: `probe_launcher` installed, Asteroids event triggered

**Expected**: Two D6 avoidance rolls, take higher. Need 5+ to avoid.

**Code Reference**:
- `TravelPhase.gd:561-569` — second roll, `maxi(avoid_roll, second_roll)`
- Journal entry created at `TravelPhase.gd:564-568`

**Status**: UNTESTED

---

### TRV-11: Military Nav System on Navigation Trouble

**Setup**: `military_nav_system` installed, Navigation Trouble event

**Expected**: No story point loss. Journal: "Military Nav Override"

**Code Reference**:
- `TravelPhase.gd:582-588` — checks component, skips SP loss

**Status**: UNTESTED

---

### TRV-12: Military Nav System on Travel-Time

**Setup**: `military_nav_system` installed, Travel-Time event

**Expected**: Gets BOTH Travel-Time rest AND Uneventful Trip item repair bonus

**Code Reference**:
- `TravelPhase.gd:726-731` — appends Uneventful Trip text + journal entry

**Status**: UNTESTED

---

### TRV-13: Auto-Turrets on Raided event

**Setup**: `auto_turrets` installed, Raided event triggered

**Expected**: +1 modifier to intimidation/avoidance roll

**Code Reference**:
- `TravelPhase.gd:604-609` — `modifier += 1`
- Journal: "Auto-Turrets Engaged"

**Status**: UNTESTED

---

### TRV-14: Auto-Turrets on invasion flee

**Setup**: `auto_turrets` installed, invasion escape attempt

**Expected**: +1 to escape roll (need 8+ on 2D6)

**Code Reference**:
- `TravelPhase.gd:381-386` — `escape_roll += 1`

**Status**: UNTESTED

---

### TRV-15: Shuttle on invasion flee

**Setup**: `shuttle` installed, invasion escape attempt

**Expected**: +2 to escape roll. Stacks with Auto-Turrets (+3 total if both installed).

**Code Reference**:
- `TravelPhase.gd:388-393` — `escape_roll += 2`
- Both checks are independent if-blocks (not elif), so they stack

**Status**: UNTESTED

---

### TRV-16: Shuttle on Distress Call

**Setup**: `shuttle` installed, Distress Call event triggered

**Expected**: Two D6 rolls, take higher for sub-table

**Code Reference**:
- `TravelPhase.gd:641-649` — second roll, `maxi(aid_roll, second)`

**Status**: UNTESTED

---

### TRV-17: Hidden Compartment on Patrol Ship

**Setup**: `hidden_compartment` installed, Patrol Ship event

**Expected**: Only 1 confiscation roll (D6-3) instead of 2

**Code Reference**:
- `TravelPhase.gd:674-679` — `rolls = 1` when component present

**Status**: UNTESTED

---

## Priority 3 — Upkeep System

Key files: `src/core/systems/UpkeepSystem.gd`, `src/ui/screens/world/components/UpkeepPhaseComponent.gd`

### UPK-01: Living Quarters reduces crew count by 2

**Setup**: `living_quarters` installed, 8 crew members

**Expected**: Effective crew = 6. Upkeep = 1 credit (4-6 crew = 1cr base).

**Code Reference** (must match in BOTH files):
- `UpkeepSystem.gd:91-98` — `crew_size = maxi(0, crew_size - 2)`
- `UpkeepPhaseComponent.gd:162-169` — `effective_crew_size = maxi(0, effective_crew_size - 2)`

**Status**: UNTESTED

---

### UPK-02: Suspension Pod component gate divergence (BUG-1)

**Setup**: `suspended_crew` list has 2 IDs BUT `suspension_pod` is NOT installed

**Expected BEFORE fix**:
- `UpkeepSystem.gd` would INCORRECTLY exclude suspended crew (no component gate at line 71)
- `UpkeepPhaseComponent.gd` would CORRECTLY count all crew (gates on `has_component` at line 145)

**Expected AFTER fix**: Both systems count all crew (no exclusion without the component)

**Code Reference**:
- `UpkeepSystem.gd:69-88` — suspension section (BUG: no `has_component` gate before line 71)
- `UpkeepPhaseComponent.gd:143-159` — suspension section (CORRECT: gates on line 145)

**Status**: UNTESTED

---

### UPK-03: Suspension Pod counting algorithm divergence (BUG-2)

**Setup**: 6 crew members, 2 IDs in `suspended_crew`, but 1 ID doesn't match any current crew member

**Expected**:
- `UpkeepSystem.gd` counts by iterating crew and matching IDs → finds 1 match → active = 5
- `UpkeepPhaseComponent.gd` subtracts `suspended.size()` → `6 - 2 = 4`

**Code Reference**:
- `UpkeepSystem.gd:73-83` — iterates members, counts non-matches
- `UpkeepPhaseComponent.gd:152-154` — `effective_crew_size - suspended.size()`

**Impact**: UI shows different upkeep than backend charges. Low severity — stale IDs are unlikely in normal play.

**Status**: UNTESTED

---

### UPK-04: Combined Suspension Pod + Living Quarters

**Setup**: 8 crew, `suspension_pod` installed, 2 suspended, `living_quarters` installed

**Expected**: 8 - 2 (suspended) = 6, then 6 - 2 (quarters) = 4. Upkeep = 1 credit.
Order: suspension first, then quarters (both files do this).

**Code Reference**:
- `UpkeepSystem.gd:69-98` — suspension block (lines 69-88) before LQ block (lines 90-98)
- `UpkeepPhaseComponent.gd:143-169` — same order

**Status**: UNTESTED

---

### UPK-05: Living Quarters with small crew

**Setup**: 3 crew, `living_quarters` installed

**Expected**: `maxi(0, 3 - 2) = 1`. Below threshold (4), so upkeep = 0.

**Code Reference**:
- `UpkeepSystem.gd:93` — `maxi(0, crew_size - 2)`
- `UpkeepSystem.gd:100-103` — threshold check: `if crew_size >= CREW_UPKEEP_THRESHOLD`

**Status**: UNTESTED

---

## Priority 4 — Battle Phase

Key file: `src/core/campaign/phases/BattlePhase.gd`

### BTL-01: Drop Launcher 2D6 roll at battle setup

**Setup**: `drop_launcher` installed

**Expected**: Rolls 2D6. If >= 8: `battle_setup_data["drop_deployment_available"] = true`. If < 8: `false`. Roll stored in `battle_setup_data["drop_deployment_roll"]`.

**Code Reference**:
- `BattlePhase.gd:432` — `has_component("drop_launcher")`
- `BattlePhase.gd:433` — `randi_range(1, 6) + randi_range(1, 6)`
- `BattlePhase.gd:434-435` — data stored in `battle_setup_data`

**Status**: UNTESTED

---

### BTL-02: Drop Launcher journal entries

**Setup**: `drop_launcher` installed

**Expected**:
- On >= 8: Journal "Drop Launcher Activated" with tags `["ship_component", "drop_launcher", "deployment"]`
- On < 8: Journal "Drop Launcher — No Window" with tags `["ship_component", "drop_launcher"]`

**Code Reference**:
- `BattlePhase.gd:436-452` — success journal entry
- `BattlePhase.gd:453-460` — failure journal entry

**Status**: UNTESTED

---

### BTL-03: Drop Launcher not installed

**Setup**: `drop_launcher` NOT in components list

**Expected**: No `drop_deployment_available` or `drop_deployment_roll` keys in `battle_setup_data`

**Code Reference**:
- `BattlePhase.gd:432` — entire block guarded by `if ShipComponentQuery.has_component("drop_launcher")`

**Status**: UNTESTED

---

## Priority 5 — Post-Battle / Recovery

### PBT-01: Expanded Database +1 to quest progress roll

**Setup**: `expanded_database` installed, active quest, post-battle

**Expected**: Quest progress roll total = base_d6 + quest_rumors + 1

**Code Reference**:
- `RivalPatronResolver.gd:119` — `has_component("expanded_database")`
- `RivalPatronResolver.gd:120` — `total_roll += 1`

**Status**: UNTESTED

---

### PBT-02: Expanded Database journal entry

**Expected**: Journal entry with type "story", title "Database-Assisted Research", tags `["ship_component", "expanded_database", "quest", "compendium"]`

**Code Reference**:
- `RivalPatronResolver.gd:121-131` — uses direct `Engine.get_main_loop().root.get_node_or_null` pattern (different from TravelPhase's `_journal_component` helper, but functionally equivalent)

**Status**: UNTESTED

---

### PBT-03: Medical Bay accelerated recovery

**Setup**: `medical_bay` installed, 1 crew member with 3 recovery turns remaining

**Expected**: After `_process_sick_bay_recovery()`:
- Normal decrement: 3 → 2
- Medical Bay bonus: 2 → 1
- Net: 3 → 1 (marked off 2 turns total, per Core Rules p.61)

**Code Reference**:
- `CampaignPhaseManager.gd:240-244` — candidate tracking (best = highest remaining turns)
- `CampaignPhaseManager.gd:245` / `260` — normal `process_recovery_turn()` / manual decrement
- `CampaignPhaseManager.gd:274` — `_apply_medical_bay_bonus(medical_bay_candidate)`
- `CampaignPhaseManager.gd:301-342` — bonus implementation (decrements first injury by 1 more)

**Status**: UNTESTED

---

### PBT-04: Medical Bay selects highest-remaining candidate

**Setup**: `medical_bay` installed, 2 injured crew:
- Crew A: 1 recovery turn remaining
- Crew B: 3 recovery turns remaining

**Expected**: Crew B selected as Medical Bay candidate (has higher remaining turns)

**Code Reference**:
- `CampaignPhaseManager.gd:242` — `if remaining > medical_bay_best_turns` (strict `>`, first-found wins on ties)

**Status**: UNTESTED

---

### PBT-05: Medical Bay skips suspended crew

**Setup**: `medical_bay` + `suspension_pod` installed, suspended crew member has injuries

**Expected**: Suspended member skipped (not considered for Medical Bay candidate), non-suspended injured member gets bonus

**Code Reference**:
- `CampaignPhaseManager.gd:228-236` — suspended ID check → `continue`
- `CampaignPhaseManager.gd:240` — candidate tracking happens AFTER the `continue`, so suspended crew are never considered

**Status**: UNTESTED

---

### PBT-06: Medical Bay with no injured crew

**Setup**: `medical_bay` installed, no crew with recovery_turns > 0

**Expected**: `medical_bay_candidate` remains `null`. Line 274 guard prevents crash.

**Code Reference**:
- `CampaignPhaseManager.gd:224` — `var medical_bay_candidate: Variant = null`
- `CampaignPhaseManager.gd:274` — `if medical_bay_candidate and ShipComponentQuery.has_component("medical_bay")`

**Status**: UNTESTED

---

## Priority 6 — Ship Damage

Key file: `src/core/managers/GameStateManager.gd`

### DMG-01: Improved Shielding reduces damage by 1

**Setup**: `improved_shielding` installed, apply 3 hull damage

**Expected**: Actual damage = 2 (after -1 from shielding)

**Code Reference**:
- `GameStateManager.gd:357` — `_ShipComponentQuery.has_component("improved_shielding")`
- `GameStateManager.gd:359` — `final_amount = maxi(0, final_amount - 1)`

**Note**: GameStateManager imports as `_ShipComponentQuery` (prefixed underscore, line 5) — different from other files that use `ShipComponentQuery`. Functionally identical.

**Status**: UNTESTED

---

### DMG-02: Improved Shielding does not reduce below 0

**Setup**: `improved_shielding` installed, apply 1 hull damage

**Expected**: `maxi(0, 1 - 1) = 0` damage. Journal entry created (pre != post).

**Code Reference**:
- `GameStateManager.gd:359` — `maxi(0, final_amount - 1)` clamps at 0

**Status**: UNTESTED

---

### DMG-03: Improved Shielding stacks with Armored trait

**Setup**: Ship has "Armored" trait AND `improved_shielding` installed, apply 3 damage

**Expected**:
1. Armored reduces: 3 → 2 (line 353)
2. Shielding reduces: 2 → 1 (line 359)
3. Final damage = 1

**Code Reference**:
- `GameStateManager.gd:350-354` — Armored trait check (applied FIRST)
- `GameStateManager.gd:357-375` — Improved Shielding (applied SECOND)
- `GameStateManager.gd:377-383` — Dodgy Drive check (applied THIRD, could increase damage)

**Status**: UNTESTED

---

## Priority 7 — Journal Cross-Cutting

### JRN-01: CampaignJournal unavailable — no crash

**Expected**: All journal writes are guarded by null checks. No crash if journal node missing.

**Files to verify**:
| File | Guard Pattern | Line |
|------|--------------|------|
| `TravelPhase.gd` | `_journal_component()` helper checks `if not journal or not journal.has_method` | 776 |
| `BattlePhase.gd` | `Engine.get_main_loop().root.get_node_or_null` + `if journal_node and journal_node.has_method` | 436-438 |
| `RivalPatronResolver.gd` | Same Engine pattern + `if journal and journal.has_method` | 121-123 |
| `CampaignPhaseManager.gd` | `get_node_or_null("/root/CampaignJournal")` + `if journal and journal.has_method` | 332-333 |
| `GameStateManager.gd` | `Engine.get_main_loop().root.get_node_or_null` + `if journal and journal.has_method` | 361-363 |
| `UpkeepPhaseComponent.gd` | `get_node_or_null("/root/CampaignJournal")` + `if journal and journal.has_method` | 238-240 |

**Status**: UNTESTED

---

### JRN-02: All entries include "ship_component" tag

**Expected**: Every ship component journal entry includes `"ship_component"` in tags array.

**Verification**:
- `TravelPhase._journal_component()` at line 778 prepends `"ship_component"` to tags — ALL travel entries covered
- `BattlePhase.gd` lines 450, 458 — manually includes `"ship_component"` in tags array
- `RivalPatronResolver.gd` line 128 — manually includes `"ship_component"`
- `CampaignPhaseManager.gd` line 339 — manually includes `"ship_component"`
- `GameStateManager.gd` line 371 — manually includes `"ship_component"`
- `UpkeepPhaseComponent.gd` line 250 — manually includes `"ship_component"`

**Status**: UNTESTED

---

## New Bugs Found During Runtime

| ID | Severity | Description | File:Line | Status |
|----|----------|-------------|-----------|--------|
| BUG-4 | **High** | Old save files missing `"components"` key in ship_data. ShipComponentQuery handles gracefully (returns []) but all component effects silently no-op. New campaigns include it via `ShipPanel._initialize_ship_data()` line 839. | `FiveParsecsCampaignCore.gd:26` | OPEN — needs migration on load |
| BUG-5 | Medium | `EULAScreen._apply_max_width()` used `custom_maximum_size` which doesn't exist in Godot 4.6. Crashed on first launch. | `EULAScreen.gd:267` | **FIXED** |
| BUG-6 | Medium | `TutorialUI._load_tutorial_steps()` returned typed `Array[Dictionary]` but JSON returns untyped Array. Debugger break on MainMenu. | `TutorialUI.gd:48`, `TutorialOverlay.gd:25,110` | **FIXED** |
| BUG-7 | Medium | `CampaignDashboard._create_stat_badge()` override signature mismatched parent `CampaignScreenBase`. Parser error on dashboard load. | `CampaignDashboard.gd:302` | **FIXED** (renamed to `_create_colored_badge`) |
| BUG-8 | **P0** | HubFeatureCard blank cards on Bug Hunt Dashboard — `setup()` called before `_ready()`, labels null | `HubFeatureCard.gd:130-161` | **FIXED** (pending data pattern) |
| BUG-9 | **P1** | Bug Hunt dialog buttons don't navigate — `AcceptDialog` modal blocks scene change | `MainMenu.gd:534-538` | **FIXED** (`queue_free` + timer) |
| BUG-10 | **P1** | `bug_hunt_dashboard` missing from MainMenu `scene_map` — "coming soon" shown | `MainMenu.gd:845-856` | **FIXED** (added route) |
| BUG-11 | **P1** | BugHuntTurnController `_ready()` uses `get_node_or_null("/root/...")` before in tree — crashes and bounces to MainMenu | `BugHuntTurnController.gd:42-50` | **FIXED** (`call_deferred("_initialize")`) |
| BUG-12 | P2 | Stats display as floats "R:2.0" instead of "R:2" | `BugHuntDashboard.gd:117-123` | **FIXED** (`int()` wrap) |
| BUG-13 | P2 | Turn shown as "0.0" in Bug Hunt dialog | `MainMenu.gd:505,520` | **FIXED** (`%d` + `int()`) |
| BUG-14 | P3 | AcceptDialog uses default light theme | `MainMenu.gd:489-491` | **FIXED** (Deep Space panel style) |

## Execution Log

| Timestamp | Test IDs | Result | Notes |
|-----------|----------|--------|-------|
| 2026-04-07 | SCQ-01 | PASS | MCP script: has_component, get_installed_ids, get_component_count all correct with injected data |
| 2026-04-07 | SCQ-02 | PASS | Empty components → [], count 0, has_component false. No crash |
| 2026-04-07 | SCQ-03 | PASS | 4 components, 1 miniaturized → billable=3. is_miniaturized correct for both |
| 2026-04-07 | DMG-01 | PASS | apply_ship_damage(3) with improved_shielding → returned 2 (3-1). No Armored trait on test ship |
| 2026-04-07 | DMG-02 | PASS | apply_ship_damage(1) with improved_shielding → returned 0. Hull unchanged |
| 2026-04-07 | BUG-1 FIX | VERIFIED | Added `has_component("suspension_pod")` gate to UpkeepSystem.gd:72 |
| 2026-04-07 | BUG-3 FIX | VERIFIED | Added "No Contraband Revenue" journal entry for zero Hidden Compartment revenue |
| 2026-04-07 | UI FLOW | PASS | Full path: MainMenu → Continue → Dashboard → World Phase → Battle Phase. Zero crashes after fixes |
| 2026-04-07 | BUG-4 | FOUND | Live save file ship_data has NO "components" key — all queries return empty. ShipPanel creates key for new campaigns |
| 2026-04-07 | NOTES | — | Introductory Campaign (Turn 0) skips Travel/Upkeep steps → component effects in those phases not exercised. Need Turn 1+ for travel revenue, upkeep modifiers |
| 2026-04-08 | BUG HUNT | PASS | Full flow: MainMenu → dialog (dark themed) → Continue → Dashboard (cards visible) → Turn Controller → Special Assignments → Mission Generate → Launch → Tactical Battle |
| 2026-04-08 | BUG-8..14 | FIXED | 7 Bug Hunt UX bugs found and fixed during runtime testing |
| 2026-04-08 | TURN CTRL | PASS | BugHuntTurnController loads correctly with `call_deferred` fix — no more `get_node_or_null` errors |
| 2026-04-08 | CREATION | PASS | 4-step wizard: Config → Squad (D100 tables) → Equipment (read-only) → Review → Launch Campaign |

---

## MCP Test Scripts

### Setup: Inject test components
```gdscript
var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
if not gsm:
    print("ERROR: GameStateManager not found")
    return
var ship = gsm.get_ship_data()
ship["components"] = [
    "medical_bay", "cargo_hold", "military_fuel_converters",
    "living_quarters", "improved_shielding", "drop_launcher",
    "auto_turrets", "shuttle", "probe_launcher", "hidden_compartment",
    "military_nav_system", "expanded_database", "suspension_pod",
    "scientific_research_system"
]
ship["miniaturized_components"] = ["cargo_hold"]
print("OK — Injected %d components (%d miniaturized)" % [
    ship["components"].size(), ship["miniaturized_components"].size()])
print("Billable: ", ShipComponentQuery.get_billable_component_count())
# Expected: 13 (14 total minus 1 miniaturized)
```

### Verify ShipComponentQuery (SCQ-01 to 03)
```gdscript
print("=== SCQ-01: Basic queries ===")
print("has medical_bay: ", ShipComponentQuery.has_component("medical_bay"))
print("has nonexistent: ", ShipComponentQuery.has_component("nonexistent"))
print("installed: ", ShipComponentQuery.get_installed_ids())
print("count: ", ShipComponentQuery.get_component_count())

print("\n=== SCQ-03: Billable ===")
print("billable: ", ShipComponentQuery.get_billable_component_count())
print("cargo miniaturized: ", ShipComponentQuery.is_miniaturized("cargo_hold"))
print("shuttle miniaturized: ", ShipComponentQuery.is_miniaturized("shuttle"))
```

### Verify upkeep calculations (UPK-01 to 05)
```gdscript
var upkeep_sys = UpkeepSystem.new()
var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
var campaign = gs.get_current_campaign() if gs and gs.has_method("get_current_campaign") else null
if campaign:
    var breakdown = upkeep_sys.calculate_upkeep_costs(campaign)
    print("crew_upkeep: ", breakdown.crew_upkeep)
    print("ship_maintenance: ", breakdown.ship_maintenance)
    print("total: ", breakdown.total)
    print("component_effects: ", breakdown.component_effects)
else:
    print("ERROR: No active campaign")
```
