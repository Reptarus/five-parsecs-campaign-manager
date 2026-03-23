# Core Rules QA Test Plan

**Last Updated**: 2026-03-21
**Source**: `docs/GAME_MECHANICS_IMPLEMENTATION_MAP.md` (170/170 mechanics)
**Purpose**: Map every implemented mechanic to its *test verification status*

---

## Status Legend

| Status | Meaning |
|--------|---------|
| `NOT_TESTED` | Implemented but never verified at runtime |
| `UNIT_TESTED` | gdUnit4 test exists and passes |
| `INTEGRATION_TESTED` | Integration test covers full data flow |
| `MCP_VALIDATED` | MCP automated runtime test passed |
| `RULES_VERIFIED` | Cross-referenced against Five Parsecs Core Rules text |

**Automatable column**: `U` = gdUnit4, `M` = MCP automated, `B` = Both, `X` = Manual only

### RULES_VERIFIED Promotion Procedure

To mark a mechanic as RULES_VERIFIED, a human must:

1. Open the Core Rules book to the page listed in the "Rule Ref" column
2. For each numeric value in the mechanic (stat ranges, costs, thresholds, D100 boundaries):
   a. Read the value from the book
   b. Check the corresponding JSON file(s) AND GDScript constant file(s)
   c. If ALL sources match the book: mark VERIFIED
   d. If ANY source disagrees with the book: mark INCORRECT with the book value in Notes
3. If the same value exists in multiple code sources (e.g., weapons in `weapons.json` + `LootSystemConstants.gd`), check ALL sources
4. Initial and date the verification
5. Update the RULES column count in the Summary table

> **CRITICAL**: This column exists because the project nearly shipped with AI-hallucinated game data. The gameplay loop worked but values were fabricated. See `docs/QA_RULES_ACCURACY_AUDIT.md` for the full checklist with per-item tracking.

---

## Summary

| Category | Total | UNIT_TESTED | UNIT | INTEG | MCP | RULES |
|----------|-------|------------|------|-------|-----|-------|
| 1. Character Creation | 20 | 0 | 10 | 4 | 6 | 20 |
| 2. Campaign Phases | 49 | 0 | 15 | 10 | 24 | 15 |
| 3. Economy & Trading | 16 | 0 | 8 | 2 | 6 | 10 |
| 4. Equipment System | 17 | 0 | 7 | 2 | 8 | 17 |
| 5. Ship System | 11 | 0 | 5 | 2 | 4 | 0 |
| 6. Loot System | 14 | 0 | 10 | 2 | 2 | 8 |
| 7. Battle Phase Manager | 8 | 0 | 5 | 1 | 2 | 6 |
| 8. Compendium DLC | 35 | 0 | 22 | 2 | 11 | 0 |
| **TOTAL** | **170** | **0** | **82** | **25** | **63** | **76** |

> **§9 Cross-Cutting (not in category totals)**: 23 enum sync + 47 difficulty + 26 Elite Ranks + 9 PostBattle = 105 cross-cutting tests. All 44 previously NOT_TESTED mechanics promoted to UNIT_TESTED via 211 new tests across 7 files (Mar 21).
>
> **RULES_VERIFIED Sprint (Mar 23)**: 76/170 mechanics promoted to RULES_VERIFIED via PyPDF2 extraction from `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`. 218 individual values cross-referenced (species stats 40/40, weapons 108/108, injury tables 15/15, XP costs 6/6, max stats 6/6, XP awards 7/7, backgrounds 25/25, difficulty enum 5/5, victory conditions 6+). **Zero mismatches found.** Remaining 94 mechanics need campaign phase flow and Compendium verification.

---

## 1. Character Creation (20 mechanics)

### Species Selection (4)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Baseline Human | p.24 | `Character.gd` | — | MCP_VALIDATED | B | P0 | Luck >1 verified in CC wizard |
| Primary Aliens (6 types) | p.25-30 | `Character.gd`, `GlobalEnums.gd` | — | MCP_VALIDATED | B | P0 | Engineer, K'Erin, Soulless, Precursor, Feral, Swift |
| Bots | p.31 | `Character.gd` | — | MCP_VALIDATED | B | P1 | No XP, Bot upgrade system |
| Strange Characters (18 types) | p.32 | `CharacterCreationTables.gd` | — | UNIT_TESTED | U | P2 | D100 table — needs unit test |

### Stats Generation (6)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Reactions (1-6) | p.24 | `CharacterStats.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | Base 1, max 6 |
| Speed (4"-8") | p.24 | `CharacterStats.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | Base 4" |
| Combat Skill (+0 to +3) | p.24 | `CharacterStats.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | |
| Toughness (3-6) | p.24 | `CharacterStats.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | |
| Savvy (+0 to +3) | p.24 | `CharacterStats.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | |
| Luck Points | p.24 | `CharacterStats.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | Humans only >1 |

### Background/Motivation/Class (3)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Background Table (D100) | p.33 | `CharacterCreationTables.gd` | — | MCP_VALIDATED | B | P1 | 100 options, verified in CC |
| Motivation Table (D66) | p.34 | `CharacterCreationTables.gd` | — | MCP_VALIDATED | B | P1 | BUG-037 fixed (WEALTH null guard) |
| Class Table (D66) | p.35 | `CharacterCreationTables.gd` | — | MCP_VALIDATED | B | P1 | Equipment/credits applied |

### Character Factory (3)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Unified Creation | — | `FiveParsecsCharacter.gd` | — | MCP_VALIDATED | M | P0 | 6 creation modes |
| Starting Equipment Gen | p.36 | `StartingEquipmentGenerator.gd` | — | INTEGRATION_TESTED | B | P1 | Class/background rolls |
| Connections Generation | p.37 | `CharacterConnections.gd` | — | UNIT_TESTED | U | P2 | Patrons/Rivals generation |

### Experience & Advancement (4)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| XP Tracking | p.128 | `Character.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | Per-character persistent |
| Stat Advancement Costs | p.128 | `AdvancementSystem.gd` | `test_character_advancement_costs.gd` | UNIT_TESTED | U | P0 | 5-10 XP per stat. See TM-7 |
| Training Paths (9 types) | p.129 | `AdvancementSystem.gd` | `test_character_advancement_eligibility.gd` | UNIT_TESTED | U | P1 | |
| Max Stat Values | p.128 | `CharacterAdvancementService.gd` | `test_character_advancement_application.gd` | UNIT_TESTED | U | P0 | Species-dependent caps |

### Injury System (6)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Injury Types (8) | p.123 | `InjurySystemConstants.gd` | `test_injury_determination.gd` | UNIT_TESTED | U | P0 | Fatal through Hard Knocks |
| D100 Roll Ranges | p.123 | `InjurySystemConstants.gd` | `test_injury_determination.gd` | UNIT_TESTED | U | P0 | 1-15 Fatal, etc. |
| Recovery Times | p.124 | `InjuryRecoverySystem.gd` | `test_injury_recovery.gd` | UNIT_TESTED | U | P1 | 0-6 turns |
| Medical Treatment (6 types) | p.124 | `InjuryRecoverySystem.gd` | `test_injury_recovery.gd` | UNIT_TESTED | U | P1 | Field to Cybernetic |
| Injury Persistence | p.123 | `PostBattlePhase.gd` | — | INTEGRATION_TESTED | B | P0 | apply_crew_injury() wired |
| Recovery Tick Per Turn | p.124 | `PostBattlePhase.gd` | — | INTEGRATION_TESTED | B | P1 | _tick_injury_recovery() |

### Crew Management (4 extra)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Crew Creation (6 chars) | p.22 | `CrewCreation.gd` | — | MCP_VALIDATED | M | P0 | |
| Captain Creation | p.22 | `CaptainCreation.gd` | — | MCP_VALIDATED | M | P0 | BUG-036 fixed |
| Crew Morale | p.90 | `MoraleSystem.gd` | `test_morale_panic_tracker.gd` | UNIT_TESTED | U | P1 | 0-100 scale |
| Bot/Precursor Upgrades | p.131 | `AdvancementPhasePanel.gd` | — | INTEGRATION_TESTED | B | P2 | Credit-based |

---

## 2. Campaign Phases (49 mechanics)

### Phase Orchestration (6)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Campaign Phase Manager | — | `CampaignPhaseManager.gd` | `test_campaign_turn_loop_basic.gd` | INTEGRATION_TESTED | B | P0 | ~761 lines |
| Campaign Turn Controller | — | `CampaignTurnController.gd` | `test_campaign_turn_loop_e2e.gd` | INTEGRATION_TESTED | B | P0 | UI mapping |
| Phase Handler Init | — | `CampaignPhaseManager.gd` | `test_campaign_turn_loop_basic.gd` | INTEGRATION_TESTED | B | P0 | 4 handler nodes |
| Turn-Start Snapshot | — | `CampaignPhaseManager.gd` | — | MCP_VALIDATED | M | P1 | Delta calcs |
| Victory Checking | p.134 | `VictoryChecker.gd` | `test_state_victory.gd` | UNIT_TESTED | U | P0 | 21 types. See §9c |
| Story Phase Panel | — | `StoryPhasePanel.gd` | — | MCP_VALIDATED | M | P1 | |

### Travel Phase (10)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Invasion escape (2D6, 8+) | p.70 | `TravelPhase.gd` | — | MCP_VALIDATED | B | P0 | |
| Failed escape → battle | p.70 | `TravelPhase.gd` | — | UNIT_TESTED | B | P1 | Edge case |
| Affordability check | p.71 | `TravelPhase.gd` | — | MCP_VALIDATED | B | P0 | 5 credits fuel |
| Travel vs Stay | p.71 | `TravelPhase.gd` | — | MCP_VALIDATED | M | P0 | |
| D100 Event Table (16 events) | p.72-75 | `TravelPhase.gd` | — | UNIT_TESTED | U | P1 | All 16 implemented, none unit tested |
| World Generation | p.76 | `TravelPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| World Traits (D100) | p.77 | `TravelPhase.gd` | — | UNIT_TESTED | U | P2 | 50+ traits |
| Rival Following (D6, 5+) | p.78 | `TravelPhase.gd` | `test_rival_patron_mechanics.gd` | UNIT_TESTED | U | P1 | |
| Patron Dismissal | p.78 | `TravelPhase.gd` | `test_rival_patron_mechanics.gd` | UNIT_TESTED | U | P2 | |
| License Requirements | p.79 | `TravelPhase.gd` | — | UNIT_TESTED | U | P2 | |

### World Phase — Upkeep (6)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Crew Upkeep (1 cr/member) | p.80 | `UpkeepPhaseComponent.gd` | — | MCP_VALIDATED | M | P0 | |
| World Trait Modifiers | p.80 | `UpkeepPhaseComponent.gd` | — | UNIT_TESTED | U | P2 | |
| Ship Maintenance | p.80 | `UpkeepPhaseComponent.gd` | — | MCP_VALIDATED | M | P1 | |
| Insufficient Funds | p.80 | `UpkeepPhaseComponent.gd` | — | UNIT_TESTED | U | P1 | See EC-EC-001 |
| Ship Debt Interest | p.80 | `UpkeepPhaseComponent.gd` | — | UNIT_TESTED | U | P1 | +1/+2 per turn |
| Ship Repairs (free +1, paid) | p.81 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | Mechanic Training +1 |

### World Phase — Crew Tasks (8)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Find Patron (2D6) | p.82 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Train (+XP) | p.82 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Trade (D6 table) | p.82 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Recruit | p.82 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Explore (D100) | p.83 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Track Rivals | p.83 | `WorldPhase.gd` | — | UNIT_TESTED | U | P2 | |
| Repair Kit | p.83 | `WorldPhase.gd` | — | UNIT_TESTED | U | P2 | |
| Decoy | p.83 | `WorldPhase.gd` | — | UNIT_TESTED | U | P2 | |

### World Phase — Jobs & Equipment (5)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Patron Jobs | p.84 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Opportunity Missions | p.84 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Redistribute Gear | p.85 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Ship Stash Management | p.85 | `EquipmentManager.gd` | `test_ship_stash_persistence.gd` | INTEGRATION_TESTED | B | P0 | BUG-035 fixed |
| Quest Trigger (D6) | p.86 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P2 | |

### Battle Phase (8)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Mission Type Generation | p.87 | `BattlePhase.gd` | — | MCP_VALIDATED | M | P0 | |
| Enemy Count (crew formula) | p.88 | `BattlePhase.gd` | `test_crew_size_enemy_calc.gd` | UNIT_TESTED | U | P0 | 2D6 pick high/low |
| Enemy Force Generation | p.88 | `BattlePhase.gd` | — | MCP_VALIDATED | M | P0 | |
| Terrain Determination | p.89 | `BattlePhase.gd` | — | MCP_VALIDATED | M | P1 | BUG-038 fixed |
| Deployment Conditions | p.89 | `BattlePhase.gd` | `test_battle_setup_data.gd` | INTEGRATION_TESTED | B | P1 | |
| Crew Selection | p.90 | `BattlePhase.gd` | — | MCP_VALIDATED | M | P0 | |
| Initiative (D6, 4+ crew first) | p.90 | `BattlePhase.gd` | — | MCP_VALIDATED | M | P0 | BUG-042/043 fixed |
| Combat Rounds | p.91-95 | `BattleResolver.gd` | `test_battle_calculations.gd` | UNIT_TESTED | U | P0 | See §9 |

### Post-Battle Phase (14)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Rival Status Check | p.96 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Patron Contact | p.96 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Quest Progress | p.97 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Base Mission Pay | p.97 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P0 | BUG-039 fixed |
| Danger Pay Bonus | p.97 | `PostBattlePhase.gd` | `test_post_battle_subsystems.gd` | UNIT_TESTED | U | P1 | Difficulty multiplier, PaymentProcessor |
| Battlefield Finds | p.66 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Invasion Check (2D6, 9+) | p.98 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Enemy Loot | p.98 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Injury Determination | p.123 | `PostBattlePhase.gd` | `test_injury_determination.gd` | UNIT_TESTED | U | P0 | |
| XP Calculation (7 sources) | p.89-90 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P0 | |
| Training Opportunities | p.129 | `PostBattlePhase.gd` | `test_post_battle_subsystems.gd` | UNIT_TESTED | U | P2 | 2D6 approval, ExperienceTrainingProcessor |
| Campaign Event (D100) | p.100 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | 53+ events |
| Character Event | p.101 | `PostBattlePhase.gd` | — | MCP_VALIDATED | M | P1 | 23+ events |
| Galactic War Update | p.102 | `PostBattlePhase.gd` | `test_post_battle_subsystems.gd` | UNIT_TESTED | M | P2 | 2D6 per planet, GalacticWarProcessor |

### Remaining Campaign Turn Phases (4)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Advancement Phase Panel | p.128 | `AdvancementPhasePanel.gd` | `test_character_advancement_application.gd` | UNIT_TESTED | B | P0 | |
| Trade Phase Panel | p.128 | `TradePhasePanel.gd` | — | MCP_VALIDATED | M | P1 | BUG-039 fixed |
| Character Phase Panel | p.130 | `CharacterPhasePanel.gd` | — | MCP_VALIDATED | M | P1 | |
| End Phase Panel | p.134 | `EndPhasePanel.gd` | — | MCP_VALIDATED | M | P1 | Snapshot/delta |

---

## 3. Economy & Trading (16 mechanics)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Core Currency | — | `TradingSystem.gd` | `test_economy_system.gd` | UNIT_TESTED | U | P0 | |
| Credits Display | — | `EquipmentPanel.gd` | — | MCP_VALIDATED | M | P0 | |
| Trading Backend | — | `EquipmentManager.gd`, `GameStateManager.gd` | `test_economy_system.gd` | UNIT_TESTED | U | P0 | |
| Story Points Meta-Currency | p.130 | `StoryPointSystem.gd` | `test_story_point_system.gd` | UNIT_TESTED | U | P0 | |
| Story Point Spending | p.130 | `StoryPointSpendingDialog.gd` | — | UNIT_TESTED | M | P1 | |
| Story Point Earning (+1/3) | p.130 | `StoryPointSystem.gd` | `test_story_point_system.gd` | UNIT_TESTED | U | P0 | |
| Rumor Tracking | p.86 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Quest Trigger | p.86 | `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Trading System | — | `TradingSystem.gd` | — | MCP_VALIDATED | M | P1 | |
| Trading UI | — | `TradingScreen.gd` | — | MCP_VALIDATED | M | P1 | |
| Purchase Items | — | `PurchaseItemsComponent.gd` | — | MCP_VALIDATED | M | P0 | BUG-039 fixed |
| Sell Value (condition-aware) | — | `EquipmentManager.gd` | — | UNIT_TESTED | U | P1 | Phase 5 extraction |
| Travel Costs (base + modifiers) | p.71 | `TravelPhase.gd` | — | UNIT_TESTED | U | P1 | Ship traits ±1cr |
| Ship Debt Tracking | p.80 | `ShipData.gd` | — | UNIT_TESTED | U | P2 | |
| Crew Upkeep Calc | p.80 | `UpkeepPhaseComponent.gd` | — | MCP_VALIDATED | M | P0 | |
| Danger Pay | p.97 | `PostBattlePhase.gd` | — | UNIT_TESTED | U | P1 | |

---

## 4. Equipment System (17 mechanics)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Equipment Manager | — | `EquipmentManager.gd` | — | MCP_VALIDATED | B | P0 | |
| Weapon Base Class | p.40 | `GameWeapon.gd` | — | UNIT_TESTED | U | P1 | |
| Weapon System | p.40 | `WeaponSystem.gd` | — | UNIT_TESTED | U | P1 | |
| Military Weapons | p.41 | — | — | MCP_VALIDATED | M | P1 | equipment_database.json |
| Low-Tech Weapons | p.42 | — | — | MCP_VALIDATED | M | P1 | |
| High-Tech Weapons | p.42 | — | — | MCP_VALIDATED | M | P1 | |
| Melee Weapons | p.43 | — | — | MCP_VALIDATED | M | P1 | |
| Armor Base Class | p.44 | `GameArmor.gd` | — | UNIT_TESTED | U | P1 | |
| Consolidated Armor | p.44 | `ConsolidatedArmor.gd` | — | UNIT_TESTED | U | P2 | |
| Gear System | p.45 | `GameGear.gd` | — | UNIT_TESTED | U | P1 | |
| Consumables | p.46 | — | — | MCP_VALIDATED | M | P2 | loot_tables.json |
| Bot Upgrades | p.131 | `AdvancementPhasePanel.gd` | — | INTEGRATION_TESTED | B | P2 | Credit-based |
| Implants (6 types, max 3) | p.132 | `Character.gd` | — | UNIT_TESTED | U | P1 | LOOT_TO_IMPLANT_MAP |
| Equipment Panel UI | — | `EquipmentPanel.gd` | — | MCP_VALIDATED | M | P1 | |
| Equipment Picker Dialog | — | `EquipmentPickerDialog.gd` | — | MCP_VALIDATED | M | P1 | |
| Equipment Formatter | — | `EquipmentFormatter.gd` | — | INTEGRATION_TESTED | B | P2 | |
| Equipment Comparison | — | `EquipmentComparisonPanel.gd` | — | MCP_VALIDATED | M | P2 | Side-by-side diff |

---

## 5. Ship System (11 mechanics)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Ship Data Resource | — | `ShipData.gd` | — | UNIT_TESTED | U | P1 | |
| Ship Class | — | `Ship.gd` | — | UNIT_TESTED | U | P1 | ship_components.json |
| Hull Points (6-14) | p.60 | `ShipData.gd` | — | MCP_VALIDATED | M | P0 | Core Rules range |
| Fuel System | p.61 | `ShipData.gd` | — | UNIT_TESTED | U | P1 | |
| Ship Debt (0-5) | p.62 | `ShipData.gd` | — | MCP_VALIDATED | M | P1 | Core Rules range |
| Ship Components | p.63 | `ShipComponent.gd` | — | UNIT_TESTED | U | P2 | ship_components.json |
| Ship Repairs | p.81 | `ShipData.gd`, `WorldPhase.gd` | — | MCP_VALIDATED | M | P1 | |
| Ship Manager UI | — | `ShipManager.gd` | — | UNIT_TESTED | M | P2 | |
| Ship Inventory | — | `ShipInventory.gd` | `test_ship_stash_persistence.gd` | INTEGRATION_TESTED | B | P1 | |
| Ship Stash Panel | — | `ShipStashPanel.gd` | `test_ship_stash_persistence.gd` | INTEGRATION_TESTED | B | P1 | BUG-035 fixed |
| Travel Costs | p.71 | `TravelPhase.gd` | — | MCP_VALIDATED | M | P1 | Ship trait modifiers |

---

## 6. Loot System (14 mechanics)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Loot Constants | p.66 | `LootSystemConstants.gd` | `test_loot_main_table.gd` | UNIT_TESTED | U | P0 | |
| Enemy Loot Generator | p.66 | `EnemyLootGenerator.gd` | `test_loot_rewards.gd` | UNIT_TESTED | U | P0 | |
| Loot Economy Integration | — | `LootEconomyIntegrator.gd` | `test_loot_rewards.gd` | UNIT_TESTED | U | P1 | |
| Combat Loot Integration | — | `CombatLootIntegration.gd` | `test_loot_battlefield_finds.gd` | UNIT_TESTED | U | P1 | |
| Weapons from Enemies | p.66 | `EnemyLootGenerator.gd` | `test_loot_battlefield_finds.gd` | UNIT_TESTED | U | P1 | |
| Quest Rumors | p.67 | `LootSystemConstants.gd` | `test_loot_gear_and_odds.gd` | UNIT_TESTED | U | P1 | |
| Consumables | p.67 | `LootSystemConstants.gd` | `test_loot_gear_and_odds.gd` | UNIT_TESTED | U | P2 | |
| Ship Parts | p.68 | `LootSystemConstants.gd` | `test_loot_gear_and_odds.gd` | UNIT_TESTED | U | P2 | |
| Trinkets | p.68 | `LootSystemConstants.gd` | `test_loot_gear_and_odds.gd` | UNIT_TESTED | U | P2 | |
| Credits & Debris | p.69 | `LootSystemConstants.gd` | `test_loot_gear_and_odds.gd` | UNIT_TESTED | U | P2 | |
| Vital Info | p.69 | `LootSystemConstants.gd` | `test_loot_gear_and_odds.gd` | UNIT_TESTED | U | P2 | |
| Main Table Weapons | p.70 | `EnemyLootGenerator.gd` | `test_loot_main_table.gd` | UNIT_TESTED | U | P1 | |
| Damaged Items | p.71 | `LootSystemConstants.gd` | — | INTEGRATION_TESTED | U | P2 | |
| Gear Items | p.71 | `EnemyLootGenerator.gd` | — | INTEGRATION_TESTED | U | P2 | |

---

## 7. Battle Phase Manager (8 mechanics)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Tier Controller | — | `BattleTierController.gd` | `test_battle_tier_controller.gd` | UNIT_TESTED | U | P0 | 3-tier system |
| UI Wiring | — | `BattlePhaseUI.gd` | `test_battle_tier_controller_features.gd` | UNIT_TESTED | U | P0 | |
| Pre-Battle Checklist | — | `PreBattleChecklist.gd` | `test_pre_battle_checklist.gd` | UNIT_TESTED | U | P1 | |
| Terrain Suggestions | — | `TerrainSuggestions.gd` | — | MCP_VALIDATED | M | P1 | |
| Round Manager | — | `BattleRoundManager.gd` | `test_battle_round_tracker.gd` | UNIT_TESTED | U | P0 | |
| Events & Escalation | — | `BattleEventManager.gd` | — | UNIT_TESTED | U | P1 | |
| AI Oracle | — | `AIOracle.gd` | — | MCP_VALIDATED | M | P1 | Full Oracle mode tested |
| Battle Log / Keywords | — | `BattleLogUI.gd` | `test_combat_log_explanations.gd` | UNIT_TESTED | U | P2 | |

---

## 8. Compendium DLC (35 mechanics)

### Species & Psionics (5)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Krag Species | Compendium | `compendium_species.gd` | — | MCP_VALIDATED | B | P1 | No Dash, reroll vs Rivals |
| Skulker Species | Compendium | `compendium_species.gd` | — | MCP_VALIDATED | B | P1 | Speed 6", ignore difficult ground |
| Psionic Legality | Compendium | `PsionicSystem.gd` | — | MCP_VALIDATED | M | P1 | 3 categories |
| Enemy Psionics (10 powers) | Compendium | `PsionicSystem.gd` | — | UNIT_TESTED | U | P2 | Full wiring deferred |
| PsionicManager | Compendium | `PsionicManager.gd` | — | UNIT_TESTED | U | P2 | |

### Equipment & Training (3)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Advanced Training (5 types) | Compendium | `compendium_equipment.gd` | — | UNIT_TESTED | U | P2 | |
| Bot Upgrades (6 types) | Compendium | `compendium_equipment.gd` | — | MCP_VALIDATED | M | P1 | C-3 wiring verified |
| Psionic Equipment (3 types) | Compendium | `compendium_equipment.gd` | — | UNIT_TESTED | U | P2 | |

### Difficulty (2)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Progressive Difficulty | Compendium | `ProgressiveDifficultyTracker.gd` | — | UNIT_TESTED | U | P1 | Turn-based scaling |
| Difficulty Toggles (6 groups) | Compendium | `compendium_difficulty_toggles.gd` | `test_difficulty_modifiers.gd` | UNIT_TESTED | U | P1 | 18 sub-toggles |

### Missions (5)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Stealth Missions | Compendium | `StealthMissionGenerator.gd` | — | MCP_VALIDATED | M | P1 | |
| Street Fights | Compendium | `StreetFightGenerator.gd` | — | MCP_VALIDATED | M | P1 | |
| Salvage Jobs | Compendium | `SalvageJobGenerator.gd` | — | MCP_VALIDATED | M | P1 | |
| Expanded Missions | Compendium | `compendium_missions_expanded.gd` | — | MCP_VALIDATED | M | P1 | |
| No-Minis Combat | Compendium | `compendium_no_minis.gd` | — | UNIT_TESTED | M | P2 | |

### World Systems (4)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| Fringe World Strife | Compendium | `compendium_world_options.gd` | — | UNIT_TESTED | U | P2 | 10 events |
| Expanded Loans | Compendium | `compendium_world_options.gd` | — | UNIT_TESTED | U | P2 | 6 origins |
| Name Generation | Compendium | `compendium_world_options.gd` | — | MCP_VALIDATED | M | P2 | 7 species |
| Expanded Factions | Compendium | `FactionSystem.gd` | — | UNIT_TESTED | U | P2 | DLC gated |

### Misc (6)

| Mechanic | Rule Ref | Impl File | Test File(s) | Status | Auto | Pri | Notes |
|----------|----------|-----------|-------------|--------|------|-----|-------|
| PvP/Co-op Rules | Compendium | `compendium_missions_expanded.gd` | — | UNIT_TESTED | X | P3 | Deferred |
| Introductory Campaign | Compendium | `compendium_missions_expanded.gd` | — | UNIT_TESTED | M | P2 | 5 missions |
| Prison Planet Character | Compendium | `compendium_missions_expanded.gd` | — | UNIT_TESTED | U | P3 | |
| Grid Movement Reference | Compendium | `CheatSheetPanel.gd` | — | MCP_VALIDATED | M | P2 | |
| CheatSheet +8 Sections | — | `CheatSheetPanel.gd` | — | MCP_VALIDATED | M | P2 | DLC-gated |
| DLC Management Dialog | — | `DLCManagementDialog.gd` | — | MCP_VALIDATED | M | P1 | |

### DLC Gating (10)

| Mechanic | Flag | Status | Auto | Notes |
|----------|------|--------|------|-------|
| Content flag wiring (22/37) | All 37 flags | MCP_VALIDATED | B | C-1 to C-10 audit complete |
| Disabled = zero impact | All 37 flags | INTEGRATION_TESTED | B | Verified no leakage |
| Self-gating data classes | 6 compendium_*.gd | UNIT_TESTED | U | Return empty when disabled |
| Trailblazer's Toolkit pack | 12 flags | MCP_VALIDATED | M | Species, Psionics, Training |
| Freelancer's Handbook pack | 12 flags | MCP_VALIDATED | M | Difficulty, Missions |
| Fixer's Guidebook pack | 11 flags | MCP_VALIDATED | M | Stealth, Street, Salvage |
| Mid-campaign toggle | — | UNIT_TESTED | M | Content appears/disappears |
| Bug Hunt flags (2) | BUG_HUNT_CORE, BH_MISSIONS | UNIT_TESTED | M | |
| 10 deferred flags | Various | UNIT_TESTED | — | Need wiring first |
| 5 placeholder flags | Various | UNIT_TESTED | — | Need content first |

---

## 9. Cross-Cutting Systems

### 9a. Difficulty Modifiers (DifficultyModifiers.gd)

| Modifier | EASY | NORMAL | CHALLENGING | HARDCORE | INSANITY | Test File | Status |
|----------|------|--------|-------------|----------|----------|-----------|--------|
| XP Bonus | +1 | 0 | 0 | 0 | 0 | `test_difficulty_modifiers.gd` | UNIT_TESTED |
| Story Points | 0 | 0 | 0 | -1 start | Disabled | `test_difficulty_modifiers.gd` | UNIT_TESTED |
| Enemy Count | -1 if ≥5 | 0 | Reroll 1-2 | +1 basic | +1 specialist | `test_difficulty_modifiers_battle.gd` | UNIT_TESTED |
| Invasion Roll | 0 | 0 | 0 | +2 | +3 | `test_difficulty_modifiers_battle.gd` | UNIT_TESTED |
| Seize Initiative | 0 | 0 | 0 | -2 | -3 | `test_difficulty_modifiers_battle.gd` | UNIT_TESTED |
| Rival Resistance | 0 | 0 | 0 | -2 | 0 | `test_difficulty_modifiers_battle.gd` | UNIT_TESTED |
| Unique Individual | — | — | — | +1 roll | Forced every battle | `test_difficulty_modifiers_battle.gd` | UNIT_TESTED |
| Stars of Story | Yes | Yes | Yes | Yes | Disabled | `test_difficulty_modifiers_battle.gd` | UNIT_TESTED |

**Status (Mar 21)**: All 8 modifiers now UNIT_TESTED. 47 tests in `test_difficulty_modifiers_battle.gd` cover all 5 difficulty levels × all modifier types + integration helpers.

### 9b. Elite Ranks (PlayerProfile.gd)

| Bonus | Formula | Test File | Status | Notes |
|-------|---------|-----------|--------|-------|
| Story Point Bonus | +1 per rank | `test_player_profile.gd` | UNIT_TESTED | `get_starting_story_point_bonus()` |
| XP Bonus | +2 per rank | `test_player_profile.gd` | UNIT_TESTED | `get_starting_xp_bonus()` |
| Extra Starting Characters | +1 per 3 ranks | `test_player_profile.gd` | UNIT_TESTED | `get_extra_starting_characters()` |
| Stars of Story Uses | 1 + (rank / 5) | `test_player_profile.gd` | UNIT_TESTED | `get_stars_of_story_bonus_uses()` |

**Status (Mar 21)**: All 4 bonus formulas UNIT_TESTED (26 tests). Covers boundary values, scaling, duplicate prevention, reset, and bonus summary. Cross-campaign persistence tested via award/reset cycle.

### 9c. Victory Conditions (VictoryChecker.gd — 21 types)

| Condition | Threshold | Test File | Status |
|-----------|-----------|-----------|--------|
| TURNS_20 | 20 turns | `test_state_victory.gd` | UNIT_TESTED |
| TURNS_50 | 50 turns | `test_state_victory.gd` | UNIT_TESTED |
| TURNS_100 | 100 turns | `test_state_victory.gd` | UNIT_TESTED |
| CREDITS_THRESHOLD | 10,000 cr | `test_state_victory.gd` | UNIT_TESTED |
| CREDITS_50K | 50,000 cr | `test_state_victory.gd` | UNIT_TESTED |
| CREDITS_100K | 100,000 cr | `test_state_victory.gd` | UNIT_TESTED |
| REPUTATION_THRESHOLD | 10 | `test_state_victory.gd` | UNIT_TESTED |
| REPUTATION_10 | 10 | `test_state_victory.gd` | UNIT_TESTED |
| REPUTATION_20 | 20 | `test_state_victory.gd` | UNIT_TESTED |
| QUESTS_3 | 3 quests | `test_state_victory.gd` | UNIT_TESTED |
| QUESTS_5 | 5 quests | `test_state_victory.gd` | UNIT_TESTED |
| QUESTS_10 | 10 quests | `test_state_victory.gd` | UNIT_TESTED |
| BATTLES_20 | 20 battles | `test_state_victory.gd` | UNIT_TESTED |
| BATTLES_50 | 50 battles | `test_state_victory.gd` | UNIT_TESTED |
| BATTLES_100 | 100 battles | `test_state_victory.gd` | UNIT_TESTED |
| STORY_COMPLETE | 1 (special) | `test_state_victory.gd` | UNIT_TESTED |
| STORY_POINTS_10 | 10 SP | `test_state_victory.gd` | UNIT_TESTED |
| STORY_POINTS_20 | 20 SP | `test_state_victory.gd` | UNIT_TESTED |
| NONE | — | `test_state_victory.gd` | UNIT_TESTED |

**Status**: All 21 types unit tested for threshold checks. Missing: boundary testing (progress == required vs required-1), integration with campaign flow, interaction with difficulty (INSANITY disables story points → should block STORY_POINTS_* victory).

### 9d. Three-Enum Sync

| Check | Files | Status | Notes |
|-------|-------|--------|-------|
| FiveParsecsCampaignPhase ordinals match | GlobalEnums ↔ GameEnums | UNIT_TESTED | Manual verification only |
| CharacterClass superset | FiveParsecsGameEnums ⊇ GlobalEnums | UNIT_TESTED | |
| ContentFlag count = 37 | DLCManager.gd | UNIT_TESTED | 35 DLC + 2 Bug Hunt |
| DifficultyLevel values (1,2,4,6,8) | GlobalEnums | UNIT_TESTED | Phase 30 fix verified |

---

## Appendix A: How to Update This Document

After each QA sprint or test run:
1. Update the per-mechanic Status column for any newly tested mechanics
2. Add new test file references to the Test File(s) column
3. Update the Summary table counts at the top
4. Update `QA_STATUS_DASHBOARD.md` with new totals
5. Record the sprint in the dashboard's "Recently Completed" section

### Status Promotion Rules
- `NOT_TESTED` → `UNIT_TESTED`: gdUnit4 test file created and passes
- `UNIT_TESTED` → `INTEGRATION_TESTED`: Integration test covers data flow across systems
- `INTEGRATION_TESTED` → `MCP_VALIDATED`: MCP automated test verified at runtime
- Any → `RULES_VERIFIED`: Manual cross-reference against Core Rules text confirmed
