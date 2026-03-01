# Five Parsecs Campaign Manager - Complete Data Flow & Implementation Map

**Created**: 2025-11-29
**Source**: Parallel agent analysis of core_rules.md vs codebase
**Purpose**: Map every functional mechanic to implementation status

---

## MASTER STATUS SUMMARY

| Category | Complete | Partial | Missing | Total |
|----------|----------|---------|---------|-------|
| Character Creation | 18 | 2 | 0 | 20 |
| Campaign Phases | 28 | 12 | 3 | 43 |
| Economy & Trading | 12 | 2 | 0 | 14 |
| Equipment System | 15 | 1 | 2 | 18 |
| Ship System | 10 | 3 | 0 | 13 |
| Loot System | 14 | 0 | 0 | 14 |
| **TOTAL** | **97** | **20** | **5** | **122** |

**Overall Completion: 79.5% Complete, 16.4% Partial, 4.1% Missing**

---

## 1. CHARACTER CREATION SYSTEM

### Core Mechanics (from rules p.24-35)

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS | NOTES |
|----------|-------------|------------|--------|-------|
| **Species Selection** | | | | |
| Baseline Human | `Character.gd` | - | COMPLETE | Default species with Luck >1 |
| Primary Aliens (6 types) | `Character.gd`, `GlobalEnums.gd` | - | COMPLETE | Engineer, K'Erin, Soulless, Precursor, Feral, Swift |
| Bots | `Character.gd` | - | COMPLETE | No XP, Bot upgrade system |
| Strange Characters (18 types) | `CharacterCreationTables.gd` | - | COMPLETE | D100 table implemented |
| **Stats Generation** | | | | |
| Reactions (1-6) | `CharacterStats.gd` | - | COMPLETE | Base 1, max 6 |
| Speed (4"-8") | `CharacterStats.gd` | - | COMPLETE | Base 4", max 8" |
| Combat Skill (+0 to +3) | `CharacterStats.gd` | - | COMPLETE | Base +0 |
| Toughness (3-6) | `CharacterStats.gd` | - | COMPLETE | Base 3, max 6 |
| Savvy (+0 to +3) | `CharacterStats.gd` | - | COMPLETE | Base +0 |
| Luck Points | `CharacterStats.gd` | - | COMPLETE | Humans only >1 |
| **Background/Motivation/Class** | | | | |
| Background Table (D100) | `CharacterCreationTables.gd` | - | COMPLETE | 100 options |
| Motivation Table (D66) | `CharacterCreationTables.gd` | - | COMPLETE | Stat bonuses applied |
| Class Table (D66) | `CharacterCreationTables.gd` | - | COMPLETE | Equipment/credits |
| **Character Factory** | | | | |
| Unified Creation | `FiveParsecsCharacter.gd` | - | COMPLETE | 6 creation modes |
| Starting Equipment Gen | `StartingEquipmentGenerator.gd` | - | COMPLETE | Class/background rolls |
| Connections Generation | `CharacterConnections.gd` | - | COMPLETE | Patrons/Rivals |

### Experience & Advancement (from rules p.128)

| MECHANIC | SCRIPT FILE | STATUS | NOTES |
|----------|-------------|--------|-------|
| XP Tracking | `Character.gd` | COMPLETE | Per-character |
| Stat Advancement Costs | `AdvancementSystem.gd` | COMPLETE | 5-10 XP per stat |
| Training Paths (9 types) | `AdvancementSystem.gd` | PARTIAL | Costs defined, UI needs work |
| Max Stat Values | `CharacterAdvancementService.gd` | COMPLETE | Species-dependent |

### Injury System (from rules p.123)

| MECHANIC | SCRIPT FILE | STATUS | NOTES |
|----------|-------------|--------|-------|
| Injury Types (8) | `InjurySystemConstants.gd` | COMPLETE | Fatal through Hard Knocks |
| D100 Roll Ranges | `InjurySystemConstants.gd` | COMPLETE | 1-15 Fatal, etc. |
| Recovery Times | `InjuryRecoverySystem.gd` | COMPLETE | 0-6 turns |
| Medical Treatment (6 types) | `InjuryRecoverySystem.gd` | COMPLETE | Field to Cybernetic |
| Injury Persistence | - | PARTIAL | Needs GameState wiring |

### Crew Management

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS |
|----------|-------------|------------|--------|
| Crew Creation (6 chars) | `CrewCreation.gd` | `InitialCrewCreation.tscn` | COMPLETE |
| Captain Creation | `CaptainCreation.gd` | - | COMPLETE |
| Crew Relationships | `CrewRelationshipManager.gd` | `CrewRelationshipsPanel.tscn` | COMPLETE |
| Crew Management Screen | `CrewManagementScreen.gd` | `CrewManagementScreen.tscn` | COMPLETE |
| Character Details | `CharacterDetailsScreen.gd` | `CharacterDetailsScreen.tscn` | COMPLETE |
| Character Card | `CharacterCard.gd` | `CharacterCard.tscn` | COMPLETE |

---

## 2. CAMPAIGN TURN STRUCTURE

### Campaign Turn Flow (from rules p.68)

```
STEP 1: TRAVEL → STEP 2: WORLD → STEP 3: BATTLE → STEP 4: POST-BATTLE
```

### Phase Orchestration

| SYSTEM | SCRIPT FILE | SCENE FILE | STATUS |
|--------|-------------|------------|--------|
| Campaign Phase Manager | `CampaignPhaseManager.gd` | - | COMPLETE |
| Campaign Turn Controller | `CampaignTurnController.gd` | `CampaignTurnController.tscn` | COMPLETE |
| Phase Handler Init | `CampaignPhaseManager.gd` | - | COMPLETE |

---

## 3. TRAVEL PHASE (Step 1)

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS | NOTES |
|----------|-------------|------------|--------|-------|
| **Flee Invasion** | | | | |
| Invasion escape (2D6, 8+) | `TravelPhase.gd` | - | COMPLETE | |
| Failed escape → battle | `TravelPhase.gd` | - | COMPLETE | |
| **Travel Decision** | | | | |
| Affordability check | `TravelPhase.gd` | - | COMPLETE | 5 credits fuel |
| Travel vs Stay | `TravelPhase.gd` | - | COMPLETE | |
| **Starship Travel Events** | | | | |
| D100 Event Table | `TravelPhase.gd` | - | COMPLETE | 18 event types |
| Event Processing | `TravelPhase.gd` | - | PARTIAL | Some events stubbed |
| **New World Arrival** | | | | |
| World Generation | `TravelPhase.gd` | - | COMPLETE | |
| World Traits (D100) | `TravelPhase.gd` | - | COMPLETE | 50+ traits |
| Rival Following (D6, 5+) | `TravelPhase.gd` | - | COMPLETE | |
| Patron Dismissal | `TravelPhase.gd` | - | PARTIAL | Stub |
| License Requirements | `TravelPhase.gd` | - | COMPLETE | |
| **UI** | | | | |
| Travel Controller | `CampaignTravelController.gd` | `CampaignTravelController.tscn` | COMPLETE | |

---

## 4. WORLD PHASE (Step 2)

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS | NOTES |
|----------|-------------|------------|--------|-------|
| **1. Upkeep & Ship Repairs** | | | | |
| Crew Upkeep (1 cr/member) | `UpkeepPhaseComponent.gd` | `.tscn` | COMPLETE | |
| World Trait Modifiers | `UpkeepPhaseComponent.gd` | - | COMPLETE | |
| Ship Maintenance | `UpkeepPhaseComponent.gd` | - | COMPLETE | |
| Insufficient Funds | `UpkeepPhaseComponent.gd` | - | COMPLETE | |
| Ship Debt Interest | `UpkeepPhaseComponent.gd` | - | COMPLETE | +1/+2 per turn |
| **2. Crew Tasks (8 types)** | | | | |
| Find Patron (2D6) | `WorldPhase.gd` | `CrewTaskComponent.tscn` | COMPLETE | |
| Train (+XP) | `WorldPhase.gd` | - | COMPLETE | |
| Trade (D6 table) | `WorldPhase.gd` | - | COMPLETE | |
| Recruit | `WorldPhase.gd` | - | COMPLETE | |
| Explore (D100) | `WorldPhase.gd` | - | COMPLETE | |
| Track Rivals | `WorldPhase.gd` | - | COMPLETE | |
| Repair Kit | `WorldPhase.gd` | - | COMPLETE | |
| Decoy | `WorldPhase.gd` | - | COMPLETE | |
| **3. Job Offers** | | | | |
| Patron Jobs | `WorldPhase.gd` | `JobOfferComponent.tscn` | COMPLETE | |
| Opportunity Missions | `WorldPhase.gd` | - | COMPLETE | |
| **4. Equipment Assignment** | | | | |
| Redistribute Gear | `WorldPhase.gd` | `AssignEquipmentComponent.tscn` | PARTIAL | |
| Ship Stash Management | - | - | MISSING | |
| **5. Resolve Rumors** | | | | |
| Quest Trigger (D6) | `WorldPhase.gd` | `ResolveRumorsComponent.tscn` | COMPLETE | |
| **6. Choose Battle** | | | | |
| Rival Attack Check | `WorldPhase.gd` | `MissionPrepComponent.tscn` | COMPLETE | |
| Battle Options | `WorldPhase.gd` | - | COMPLETE | |
| **World Phase Controller** | | | | |
| 9-Step Orchestration | `WorldPhaseController.gd` | `WorldPhaseController.tscn` | COMPLETE | |
| Automation Toggle | `WorldPhaseController.gd` | - | COMPLETE | |
| Deferred Events | `WorldPhaseController.gd` | - | COMPLETE | |

---

## 5. BATTLE PHASE (Step 3)

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS | NOTES |
|----------|-------------|------------|--------|-------|
| **Pre-Battle Setup** | | | | |
| Mission Type Generation | `BattlePhase.gd` | - | COMPLETE | |
| Enemy Count (crew size formula) | `BattlePhase.gd` | - | COMPLETE | 2D6 pick high/low |
| Enemy Force Generation | `BattlePhase.gd` | - | COMPLETE | |
| Terrain Determination | `BattlePhase.gd` | - | COMPLETE | |
| Deployment Conditions | `BattlePhase.gd` | `DeploymentConditionsPanel.tscn` | COMPLETE | |
| **Deployment** | | | | |
| Crew Selection | `BattlePhase.gd` | - | COMPLETE | |
| Deployment Positions | `BattlePhase.gd` | - | COMPLETE | |
| **Combat** | | | | |
| Initiative (D6, 4+ crew first) | `BattlePhase.gd` | - | COMPLETE | |
| Combat Rounds | `BattlePhase.gd` | - | PARTIAL | Placeholder simulation |
| Tactical Combat System | - | `TacticalBattleUI.tscn` | PARTIAL | Basic framework |
| **Battle Events** | | | | |
| D6 Event Table | `BattlePhase.gd` | - | PARTIAL | |
| **UI** | | | | |
| Pre-Battle UI | `PreBattleUI.gd` | `PreBattleUI.tscn` | COMPLETE | |
| Pre-Battle Equipment | `PreBattleEquipmentUI.gd` | `PreBattleEquipmentUI.tscn` | COMPLETE | |
| Battle Transition | `BattleTransitionUI.gd` | `BattleTransitionUI.tscn` | COMPLETE | |
| Enemy Gen Wizard | `EnemyGenerationWizard.gd` | - | COMPLETE | |

---

## 6. POST-BATTLE PHASE (Step 4)

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS | NOTES |
|----------|-------------|------------|--------|-------|
| **1. Rival Status** | | | | |
| Rival Defeat Check | `PostBattlePhase.gd` | - | COMPLETE | |
| Rival Removal Roll | `PostBattlePhase.gd` | - | COMPLETE | |
| **2. Patron Status** | | | | |
| New Patron Contact | `PostBattlePhase.gd` | - | COMPLETE | |
| Persistent Patrons | `PostBattlePhase.gd` | - | PARTIAL | |
| **3. Quest Progress** | | | | |
| Quest Advancement | `PostBattlePhase.gd` | - | COMPLETE | |
| **4. Payment** | | | | |
| Base Mission Pay | `PostBattlePhase.gd` | - | COMPLETE | |
| Danger Pay Bonus | `PostBattlePhase.gd` | - | COMPLETE | |
| **5. Battlefield Finds** | | | | |
| Search Rolls | `PostBattlePhase.gd` | - | COMPLETE | |
| Find Result Table | `PostBattlePhase.gd` | - | COMPLETE | |
| **6. Invasion Check** | | | | |
| World Invasion (D100, 5%) | `PostBattlePhase.gd` | - | COMPLETE | |
| **7. Loot** | | | | |
| Enemy Loot Tables | `PostBattlePhase.gd` | - | COMPLETE | |
| Loot to Inventory | `PostBattlePhase.gd` | - | COMPLETE | |
| **8. Injuries** | | | | |
| Injury Determination | `PostBattlePhase.gd` | - | COMPLETE | |
| Severity Roll (D100) | `PostBattlePhase.gd` | - | COMPLETE | |
| Recovery Time Calc | `PostBattlePhase.gd` | - | COMPLETE | |
| **9. Experience** | | | | |
| XP Calculation | `PostBattlePhase.gd` | - | COMPLETE | |
| XP Distribution | `PostBattlePhase.gd` | - | COMPLETE | |
| **10. Training** | | | | |
| Training Opportunities | `PostBattlePhase.gd` | - | PARTIAL | Stub |
| **11. Purchase Items** | | | | |
| Shop Interface | `PurchaseItemsComponent.gd` | `.tscn` | PARTIAL | Basic |
| **12. Campaign Event** | | | | |
| D100 Event Table | `PostBattlePhase.gd` | `CampaignEventComponent.tscn` | COMPLETE | |
| Event Effects | `PostBattlePhase.gd` | - | PARTIAL | Some stubbed |
| **13. Character Event** | | | | |
| Character Event Roll | `PostBattlePhase.gd` | `CharacterEventComponent.tscn` | COMPLETE | |
| Event Effects | `PostBattlePhase.gd` | - | PARTIAL | Some stubbed |
| **14. Galactic War** | | | | |
| War Progress Update | `PostBattlePhase.gd` | - | PARTIAL | Stub |
| **Post-Battle Processor** | | | | |
| Results Pipeline | `PostBattleProcessor.gd` | - | COMPLETE | |
| Casualty Processing | `PostBattleProcessor.gd` | - | COMPLETE | |

---

## 7. ECONOMY SYSTEM

| MECHANIC | SCRIPT FILE | DATA FILE | STATUS |
|----------|-------------|-----------|--------|
| **Credits** | | | |
| Core Currency | `TradingSystem.gd` | `equipment_database.json` | COMPLETE |
| Credits Display | `EquipmentPanel.gd` | - | COMPLETE |
| **Story Points** | | | |
| Meta-Currency | `StoryPointSystem.gd` | - | COMPLETE |
| Spending Dialog | `StoryPointSpendingDialog.gd` | - | COMPLETE |
| Earning Rules (+1/3 turns) | `StoryPointSystem.gd` | - | COMPLETE |
| **Quest Rumors** | | | |
| Rumor Tracking | `WorldPhase.gd` | - | COMPLETE |
| Quest Trigger | `WorldPhase.gd` | - | COMPLETE |
| **Trading** | | | |
| Trading System | `TradingSystem.gd` | `equipment_database.json` | COMPLETE |
| Trading UI | `TradingScreen.gd` | `TradingScreen.tscn` | COMPLETE |
| Purchase Items | `PurchaseItemsComponent.gd` | - | COMPLETE |

---

## 8. EQUIPMENT SYSTEM

| MECHANIC | SCRIPT FILE | DATA FILE | STATUS |
|----------|-------------|-----------|--------|
| **Equipment Manager** | `EquipmentManager.gd` | - | COMPLETE |
| **Weapons** | | | |
| Weapon Base Class | `GameWeapon.gd` | `weapons.json` | COMPLETE |
| Weapon System | `WeaponSystem.gd` | `weapons.json` | COMPLETE |
| Military Weapons | - | `equipment_database.json` | COMPLETE |
| Low-Tech Weapons | - | `equipment_database.json` | COMPLETE |
| High-Tech Weapons | - | `equipment_database.json` | COMPLETE |
| Melee Weapons | - | `equipment_database.json` | COMPLETE |
| **Armor** | | | |
| Armor Base Class | `GameArmor.gd` | `armor.json` | COMPLETE |
| Consolidated Armor | `ConsolidatedArmor.gd` | `armor.json` | COMPLETE |
| **Gear & Gadgets** | | | |
| Gear System | `GameGear.gd` | `gear_database.json` | COMPLETE |
| Consumables | - | `loot_tables.json` | COMPLETE |
| **Bot Upgrades** | - | - | MISSING |
| **Implants** | - | - | MISSING |
| **Equipment UI** | | | |
| Equipment Panel | `EquipmentPanel.gd` | `EquipmentPanel.tscn` | COMPLETE |
| Equipment Picker | `EquipmentPickerDialog.gd` | - | COMPLETE |
| Equipment Formatter | `EquipmentFormatter.gd` | - | COMPLETE |

---

## 9. SHIP SYSTEM

| MECHANIC | SCRIPT FILE | DATA FILE | STATUS |
|----------|-------------|-----------|--------|
| **Ship Core** | | | |
| Ship Data Resource | `ShipData.gd` | - | COMPLETE |
| Ship Class | `Ship.gd` | `ship_components.json` | COMPLETE |
| Hull Points | `ShipData.gd` | - | COMPLETE |
| Fuel System | `ShipData.gd` | - | COMPLETE |
| Ship Debt | `ShipData.gd` | - | COMPLETE |
| **Ship Components** | | | |
| Component Base | `ShipComponent.gd` | `ship_components.json` | COMPLETE |
| Hull Components | - | `ship_components.json` | COMPLETE |
| Engine Components | - | `ship_components.json` | COMPLETE |
| Weapon Components | `WeaponsComponent.gd` | `ship_components.json` | COMPLETE |
| Defense Systems | - | `ship_components.json` | COMPLETE |
| **Ship Management** | | | |
| Ship Repairs | `ShipData.gd` | - | PARTIAL |
| Ship Manager UI | `ShipManager.gd` | - | COMPLETE |
| Ship Inventory | `ShipInventory.gd` | - | COMPLETE |
| Ship Stash Panel | `ShipStashPanel.gd` | `ShipStashPanel.tscn` | COMPLETE |
| Ship Panel (Wizard) | `ShipPanel.gd` | - | COMPLETE |
| Travel Costs | `TradingSystem.gd` | - | PARTIAL |

---

## 10. LOOT SYSTEM

| MECHANIC | SCRIPT FILE | DATA FILE | STATUS |
|----------|-------------|-----------|--------|
| **Loot Core** | | | |
| Loot Constants | `LootSystemConstants.gd` | `loot_tables.json` | COMPLETE |
| Enemy Loot Generator | `EnemyLootGenerator.gd` | - | COMPLETE |
| Loot Economy Integration | `LootEconomyIntegrator.gd` | - | COMPLETE |
| Combat Loot Integration | `CombatLootIntegration.gd` | - | COMPLETE |
| **Battlefield Finds (p.66)** | | | |
| Weapons from Enemies | `EnemyLootGenerator.gd` | `equipment_database.json` | COMPLETE |
| Quest Rumors | `LootSystemConstants.gd` | `loot_tables.json` | COMPLETE |
| Consumables | `LootSystemConstants.gd` | `loot_tables.json` | COMPLETE |
| Ship Parts | `LootSystemConstants.gd` | `loot_tables.json` | COMPLETE |
| Trinkets | `LootSystemConstants.gd` | `loot_tables.json` | COMPLETE |
| Credits & Debris | `LootSystemConstants.gd` | `loot_tables.json` | COMPLETE |
| Vital Info | `LootSystemConstants.gd` | `loot_tables.json` | COMPLETE |
| **Main Loot Table (p.70-72)** | | | |
| Weapons | `EnemyLootGenerator.gd` | - | COMPLETE |
| Damaged Weapons | `LootSystemConstants.gd` | - | COMPLETE |
| Damaged Gear | `LootSystemConstants.gd` | - | COMPLETE |
| Gear Items | `EnemyLootGenerator.gd` | - | COMPLETE |
| Odds & Ends | `LootSystemConstants.gd` | - | COMPLETE |

---

## CRITICAL GAPS (Priority Implementation Needed)

### HIGH PRIORITY
| Gap | Impact | Location |
|-----|--------|----------|
| Ship Stash Equipment Management | Can't manage ship inventory | World Phase |
| Injury Persistence to GameState | Injuries don't carry over | Post-Battle → GameState |
| Training UI Integration | Can't spend XP on training | AdvancementManager |

### MEDIUM PRIORITY
| Gap | Impact | Location |
|-----|--------|----------|
| Tactical Combat System | Battle simulation only | BattlePhase |
| Event Effects Application | Some events have no effect | PostBattlePhase |
| Bot Upgrades | Missing entire subsystem | Equipment |
| Implants | Missing entire subsystem | Equipment |

### LOW PRIORITY
| Gap | Impact | Location |
|-----|--------|----------|
| Galactic War Progress | Feature incomplete | PostBattlePhase |
| Patron Persistence Details | Partial implementation | TravelPhase |
| Some Starship Travel Events | Stubbed implementations | TravelPhase |

---

## SIGNAL WIRING STATUS

### Properly Wired (Working)
- Character creation → GameState.current_campaign.crew
- Crew management ↔ Character details screens
- Phase transitions (Travel → World → Battle → Post-Battle)
- Loot generation → Inventory
- XP gain → Character advancement
- Upkeep → Credits deduction

### Needs Wiring
- Injury status → GameState persistence
- Training purchases → XP deduction
- Ship stash ↔ Character equipment
- Event effects → Full game state changes

---

## FILE COUNT BY SUBSYSTEM

| Subsystem | Core Files | UI Files | Data Files | Total |
|-----------|------------|----------|------------|-------|
| Character | 15 | 8 | 3 | 26 |
| Campaign Phases | 8 | 12 | 0 | 20 |
| Economy | 4 | 5 | 4 | 13 |
| Equipment | 6 | 6 | 5 | 17 |
| Ship | 8 | 5 | 1 | 14 |
| Loot | 4 | 0 | 1 | 5 |
| **TOTAL** | **45** | **36** | **14** | **95** |

---

## RECOMMENDED NEXT STEPS

1. **Complete HIGH priority gaps** (Ship Stash, Injury Persistence, Training UI)
2. **Wire event effects** for Campaign and Character events
3. **Implement Bot Upgrades and Implants** for full equipment coverage
4. **Enhance tactical combat** beyond simulation
5. **Test full campaign turn loop** end-to-end

---

**Document Status**: COMPLETE
**Last Updated**: 2025-11-29
**Agents Used**: 3 parallel Explore agents
