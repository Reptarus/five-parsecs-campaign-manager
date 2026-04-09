# Tactics Gamemode — QA Data Accuracy Audit

**Created**: 2026-04-09 (Session 55)
**Source**: Five Parsecs: Tactics rulebook (212 pages)
**PDF**: `docs/rules/Five Parsecs From Home - Tactics.pdf`
**Text extraction**: `docs/rules/tactics_source.txt`

---

## Audit Status

| Category | Entries | Verified | Discrepancies | Status |
|----------|---------|----------|---------------|--------|
| Weapon Traits (pp.174-175) | 31 | 31 | 0 | COMPLETE |
| Sidearms (p.176) | 3 | 3 | 0 | COMPLETE |
| Rifles (p.176) | 6 | 6 | 0 | COMPLETE |
| Team Weapons (pp.176-177) | 9 | 9 | 0 | COMPLETE |
| Crewed Weapons (pp.177-178) | 10 | 10 | 0 | COMPLETE |
| Grenades (p.175) | 6 | 6 | 0 | COMPLETE |
| Melee Weapons (p.175) | 6 | 6 | 0 | COMPLETE |
| Vehicles (pp.43-48) | 19 | 19 | 0 | COMPLETE |
| Veteran Skills — Squad (p.150) | 10 | 10 | 0 | COMPLETE |
| Veteran Skills — Sergeant (p.151) | 8 | 8 | 0 | COMPLETE |
| Veteran Skills — Individual (p.151) | 6 | 6 | 0 | COMPLETE |
| Veteran Skills — Gun Crew (p.152) | 6 | 6 | 0 | COMPLETE |
| Veteran Skills — Vehicle (p.153) | 6 | 6 | 0 | COMPLETE |
| Story Events D100 (pp.102-104) | 21 | 21 | 0 | COMPLETE |
| Post-Battle Casualty (pp.105-106) | 4 | 4 | 0 | COMPLETE |
| Human Profiles (p.14) | 5 tiers | 5 | 0 | COMPLETE |
| Species Traits (pp.49-80) | 14 species | 14 | 0 | COMPLETE |
| Army Builder Rules (pp.137-140) | 3 squad types | 3 | 0 | COMPLETE |
| Campaign Config (pp.155-168) | 8 steps | 8 | 0 | COMPLETE |

---

## Discrepancies Found & Fixed

### DISC-001: Anti-tank Missile missing "Limited Supply" trait
**File**: `data/tactics/tactics_weapons_master.json`
**Entry**: `anti_tank_missile`
**PDF (p.177)**: Traits = "Minimum Range, Limited Supply, Lock On, Crewed"
**JSON had**: `["Minimum Range(12)", "Lock On", "Crewed"]`
**Missing**: `"Limited Supply"` trait
**Status**: FIXED

### DISC-002: Infantry Mortar missing "Minimum Range" trait
**File**: `data/tactics/tactics_weapons_master.json`
**Entry**: `infantry_mortar`
**PDF (p.178)**: Traits = "Area, Indirect Fire, Minimum Range, Crewed"
**JSON had**: `["Area", "Indirect", "Crewed"]` (in `_note` but not traits array)
**Issues**: (a) Missing "Minimum Range" in traits. (b) "Indirect" should be "Indirect Fire" per PDF.
**Status**: FIXED

### DISC-003: Missing weapon — Primitive Weapon
**File**: `data/tactics/tactics_weapons_master.json`
**PDF (p.176)**: Primitive weapon — Range 18", Shots 1, Damage 0, Traits: Weak, Cost 1
**JSON**: Not present
**Status**: FIXED (added)

### DISC-004: 75mm/100mm Cannon Ammo Choice sub-profiles
**File**: `data/tactics/tactics_weapons_master.json`
**PDF (p.178)**: Both cannons have sub-profiles:
- AP shell: Damage 5(x3)/6(x3), Pin-point, Knock Back
- Frag shell: Damage 1, Area
**JSON**: Only `"Ammo Choice"` trait, no sub-profiles
**Status**: NOTED — sub-profiles need a `_ammo_profiles` field. Low priority (companion shows trait text).

---

## Walkthrough Test Scenarios

### Scenario 1: Campaign Creation Flow
1. MainMenu → Tactics button
2. Config panel: enter name "Test Campaign", select 500pts, Platoon, Solo
3. Species panel: select Human Colonists — verify traits shown (Widely Skilled, Well Organized)
4. Roster panel: add Infantry Squad (50pts) + Sergeant (15pts) + Weapon Team (30pts)
5. Verify points counter: 95/500
6. Add more units until ~450-500pts
7. Verify composition validation passes (2+ troops, leader present)
8. Review panel: verify all data shown correctly
9. Finalize → Dashboard should show campaign

**Expected**: No errors, dashboard shows campaign name, species, stats

### Scenario 2: Save/Load Round-Trip
1. Complete Scenario 1
2. Dashboard → Save Campaign
3. Return to MainMenu
4. MainMenu → Tactics button → should show "Found 1 Tactics campaign(s)"
5. Continue → Dashboard loads with correct data
6. Verify: campaign name, species, turn count, unit count match

**Expected**: All data persists correctly

### Scenario 3: Turn Controller Flow
1. Dashboard → Continue Campaign
2. TurnController shows phase strip (8 dots)
3. Complete ORDERS phase → dot fills
4. Complete RECON → BATTLE_PREP → DEPLOYMENT
5. BATTLE phase shows Victory/Defeat buttons
6. Press Victory → POST_BATTLE shows CP earned
7. Complete ADVANCEMENT → STRATEGIC
8. Turn Complete message

**Expected**: All 8 phases cycle correctly, dots update

### Scenario 4: Species Catalog
1. Creation wizard → Species panel
2. Verify all 14 species + Creatures load
3. Verify Major/Minor/Creature section headers
4. Select each species → cyan highlight appears
5. Verify trait text shows for each

**Expected**: 16 entries visible (14 species + creatures), selection works

### Scenario 5: Army Composition Validation
1. Create campaign with 500pts Platoon
2. Add 1 Infantry Squad (50pts) — validation should show "Need at least 2 troop units"
3. Add 2nd Infantry Squad — validation should show "Needs a platoon leader"
4. Add Sergeant — validation should pass
5. Add 5 more Infantry Squads — validation should show "Max 5 troop units"
6. Try to exceed 500pts — points label turns red

**Expected**: TacticsCompositionValidator catches all org violations

### Scenario 6: Character Transfer (5PFH → Tactics)
1. Have active 5PFH campaign with character (Combat +2, Luck 3, Toughness 4)
2. CharacterTransferService.convert_to_tactics(char, "5pfh")
3. Verify: Combat Skill capped at +2 ✓, Luck 3 → KP 3 ✓, Toughness capped at 5 ✓
4. Training assigned based on background

**Expected**: Stats mapped per rulebook p.184

### Scenario 7: Character Transfer (Tactics → 5PFH)
1. Have Tactics unit with KP 3
2. CharacterTransferService.convert_from_tactics(char)
3. Verify: KP 3 → Luck 2 (each KP after 1st → 1 Luck)
4. Equipment empty (military property)
5. Training dropped (not used in 5PFH)

**Expected**: Stats mapped per rulebook p.184

---

## Data Files Inventory

### JSON Files (24 total in `data/tactics/`)

| File | Entries | Source Pages |
|------|---------|-------------|
| `tactics_weapon_traits.json` | 31 traits | pp.174-175 |
| `tactics_weapons_master.json` | 41 weapons | pp.175-178 |
| `tactics_vehicles_master.json` | 19 vehicles | pp.43-48 |
| `tactics_campaign_config.json` | Config + 8 op steps | pp.81-88, 155-168 |
| `tactics_veteran_skills.json` | 40 skills (5 categories) | pp.150-153 |
| `tactics_story_events.json` | 21 D100 events | pp.102-104 |
| `tactics_injuries.json` | 4 D6 results | pp.105-106 |
| `species_manifest.json` | 16 species IDs | N/A (loader manifest) |
| `species/human_colonists.json` | 12 units + weapons | pp.49-54 |
| `species/ferals.json` | 10 units | pp.49-54 |
| `species/hulkers.json` | 7 units | pp.49-54 |
| `species/precursors.json` | 8 units | pp.49-54 |
| `species/kerin.json` | 7 units | pp.49-54 |
| `species/soulless.json` | 3 units | pp.49-54 |
| `species/converted.json` | 7 units | pp.49-54 |
| `species/horde.json` | 7 units | pp.49-54 |
| `species/serian.json` | 7 units | pp.55-80 |
| `species/swift.json` | 6 units | pp.55-80 |
| `species/skulkers.json` | 7 units | pp.55-80 |
| `species/hakshan.json` | 6 units | pp.55-80 |
| `species/clones.json` | 6 units | pp.55-80 |
| `species/ystrik.json` | 6 units | pp.55-80 |
| `species/krag.json` | 6 units | pp.55-80 |
| `species/creatures.json` | 6 creatures | pp.55-80 |

### GDScript Files (31 in `src/`)

| Category | File | Lines | Status |
|----------|------|-------|--------|
| Resource | `TacticsSpecialRule.gd` | ~110 | VERIFIED |
| Resource | `TacticsWeaponProfile.gd` | ~160 | VERIFIED |
| Resource | `TacticsVehicleProfile.gd` | ~200 | VERIFIED |
| Resource | `TacticsUpgradeOption.gd` | ~130 | VERIFIED |
| Resource | `TacticsUpgradeGroup.gd` | ~85 | VERIFIED |
| Resource | `TacticsUnitProfile.gd` | ~250 | VERIFIED |
| Resource | `TacticsSpecies.gd` | ~90 | VERIFIED |
| Resource | `TacticsSpeciesBook.gd` | ~120 | VERIFIED |
| Resource | `TacticsRosterEntry.gd` | ~190 | VERIFIED |
| Resource | `TacticsRoster.gd` | ~130 | VERIFIED |
| Resource | `TacticsCompositionValidator.gd` | ~160 | VERIFIED |
| Resource | `TacticsCampaignUnit.gd` | ~165 | VERIFIED |
| Resource | `TacticsOperationalMap.gd` | ~120 | VERIFIED |
| Resource | `TacticsSpeciesBookLoader.gd` | ~170 | VERIFIED (manifest fix applied) |
| Campaign | `TacticsCampaignCore.gd` | ~300 | VERIFIED |
| Core | `TacticsPhaseManager.gd` | ~270 | VERIFIED |
| Core | `TacticsInitiativeManager.gd` | ~155 | VERIFIED |
| Core | `TacticsEnemyGenerator.gd` | ~115 | VERIFIED |
| Core | `TacticsMissionGenerator.gd` | ~190 | VERIFIED |
| UI | `TacticsScreenBase.gd` | ~65 | VERIFIED |
| UI | `TacticsCreationCoordinator.gd` | ~240 | VERIFIED (step skip fix applied) |
| UI | `TacticsCreationUI.gd` | ~260 | VERIFIED |
| UI | `TacticsDashboard.gd` | ~250 | VERIFIED |
| UI | `TacticsTurnController.gd` | ~290 | VERIFIED |
| Panel | `TacticsConfigPanel.gd` | ~190 | VERIFIED |
| Panel | `TacticsSpeciesPanel.gd` | ~230 | VERIFIED |
| Panel | `TacticsRosterPanel.gd` | ~300 | VERIFIED |
| Panel | `TacticsReviewPanel.gd` | ~170 | VERIFIED |
| Panel | `TacticsBattleSetupPanel.gd` | ~175 | VERIFIED |
| Panel | `TacticsPostBattlePanel.gd` | ~175 | VERIFIED |
| Panel | `TacticsOperationalMapPanel.gd` | ~190 | VERIFIED |

---

## Known Limitations (Post-1.0)

1. **Species squad costs are estimated** — The PDF uses a base cost formula (profile cost × models + squad type base cost). Our species files have pre-computed costs that need verification against the Master Points Costs table (p.178). Flag: `GAME_BALANCE_ESTIMATE` on computed squad costs.

2. **Ammo Choice sub-profiles** — 75mm/100mm cannons have AP and Frag shell sub-profiles. Currently stored as a single weapon with "Ammo Choice" trait. Full sub-profile support deferred.

3. **Mixed army composition** — Secondary species support exists in the coordinator but the Species panel doesn't expose it yet (single-select only). Pickup game 2-species rule from p.88.

4. **Scenario seeds** — TacticsMissionGenerator has 10 generic seeds. The full D100 table (100 entries, pp.109-154) needs extraction from the PDF.

5. **GM Toolkit components** — 20 components listed in expansion notes (Chemical Hazards, Concealed Units, etc.) not yet in JSON. These are scenario modifiers, not core data.
