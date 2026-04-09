# Five Parsecs Campaign Manager - Complete Data Flow & Implementation Map

**Created**: 2025-11-29
**Last Updated**: 2026-04-08
**Source**: Parallel agent analysis of core_rules.md vs codebase, Sprint 1-10 completions, Battle Phase Manager sprints, Tech Debt + Feature Gaps 12 sprints, Phase 5 Script Consolidation, Phase 16-22J Battle+UI sprints, Sessions 35-52 (Red/Black Zones, Story Track, Equipment Pipeline, Battle Reconciliation, Terrain Generator, Character Events, Strange Characters, Upkeep Failure)
**Purpose**: Map every functional mechanic to implementation status

---

## MASTER STATUS SUMMARY

| Category | Complete | Partial | Missing | Total |
|----------|----------|---------|---------|-------|
| Character Creation | 20 | 0 | 0 | 20 |
| Campaign Phases | 49 | 0 | 0 | 49 |
| Economy & Trading | 16 | 0 | 0 | 16 |
| Equipment System | 17 | 0 | 0 | 17 |
| Ship System | 11 | 0 | 0 | 11 |
| Loot System | 14 | 0 | 0 | 14 |
| Battle Phase Manager | 8 | 0 | 0 | 8 |
| Compendium DLC | 35 | 0 | 0 | 35 |
| **TOTAL** | **170** | **0** | **0** | **170** |

**Core Rules Completion: 100% Complete**
**Including Compendium DLC: 100% Complete (170/170)**

### Recent Updates (April 2026)

**Strange Characters + Upkeep Failure — Session 52 (Apr 8)**:
- 16/16 Strange Character species fully gameplay-wired (was 9/16): Unity Agent per-turn 2D6, De-converted/Assault Bot armor saves, Hulker shooting restriction, Primitive weapon limits, Empath task bonus, Feeler mental breakdown, implant capacity per species
- Upkeep failure system: Sick Bay crew excluded, crew lockout enforced (was defined but disconnected), sell-equipment-for-upkeep dialog, dismiss crew dialog, ship seizure threshold fix

**Character Events — Session 51 (Apr 8, 9 files)**:
- 30 D100 character events fully wired with status_effects persistence on Character.gd
- 9 multi-turn effect types (GROUNDED, SUSPICIOUS, VENGEFUL, SHAKEN, FATIGUED, INSPIRED, LUCKY_STREAK, VENDETTA, UNDER_INVESTIGATION)
- 6 enforcement gates across battle, upkeep, trading, character phase, world phase, crew tasks
- Dashboard status pills, turn rollover countdown, item mutation, Swift departure

**Terrain Generator Overhaul — Session 50 (Apr 8, 5 files)**:
- Shape placement fixes: adaptive density scaling (0.6x-1.0x), proportional rotation margins, grid-distributed fallback, hard sector clamping (no more overflow)
- 10 world trait terrain modifications (was 2): barren strips vegetation, flat strips hills, crystals adds 2D6, haze/gloom/fog visibility notes, frozen/reflective_dust/null_zone combat notes
- Map labels show terrain rules badges [L]/[I]/[B]/[F]/[A], scatter terrain visible as tiny dots, legend completed (12 entries), seeded RNG, planet-type-to-theme mapping

**Battle Phase Reconciliation — Session 48d (Apr 8, 4 files)**:
- CampaignTurnController confirmed as production battle path (BattlePhase.gd is dead)
- Missing mechanics wired: SeizeInitiativeSystem, rival attack types, SMALL_ENCOUNTER enemy -1/-2, quest finale +1, initiative_context dict
- UX streamlined from 5 screens to 3: BattleTransitionUI bypassed, tier selector moved to PreBattleUI
- Rich Dictionary result from TacticalBattleUI (20+ fields: held_field, crew_participants, defeated_enemies, mission flags)
- BattlePhase.gd deprecated, battle_phase_handler removed from CampaignPhaseManager, 3 dead PostBattlePhase files deleted

**Equipment Effects Pipeline — Session 47 (Apr 8, 12+ files)**:
- 12-phase equipment pipeline: fabricated traits fixed, armor saves un-broken, single-use removal, overheat tracking, 7 protective devices, consumables, gun mods, utility devices, on-board items, Compendium traits
- PostBattlePhase rewired to 14-step decomposed orchestrator (was using old 5-step stub)
- World Arrival UI: world trait display, rival follow results, forge license mechanic, 10 travel event mutations

**Red & Black Zone Jobs — Phase 35 (Apr 7, 11 files)**:
- Core Rules Appendix III (pp.148-151) fully integrated
- Zone selection UI in World Phase Step 0 (UpkeepPhaseComponent)
- Red Zone: license purchase, threat conditions (D6), time constraints (Round 6 D6), fixed opposition (7+3 specialists), invasion +2, galactic war -1, improved rewards
- Black Zone: access check (10 RZ turns), upkeep waiver, step auto-skip (Jobs/Rumors), mission types (D10, 5 types), Active/Passive team system, victory rewards (clear rivals, +2 patrons, 5cr, loan payoff, 3 loot, +1 XP all), failure rewards (1cr/casualty)
- Journal/history: zone-tagged battle entries, zone-enriched character timelines, Black Zone reward milestones, license purchase milestone, payment context
- Broker discount for license fee (checks `has_broker_training` + `"Broker Training"` trait)
- Backend existed: `red_zone_jobs.json`, `black_zone_jobs.json`, `RedZoneSystem.gd`, `BlackZoneSystem.gd`, `BattlePhase.gd` zone logic, `FiveParsecsCampaignCore` persistence

### Earlier Updates (February-March 2026)

**Feature Integration — Parts A/B/C (Mar 1, 3 parts)**:

- README rewrite with 4 screenshots (main-menu, battle-companion, companion-levels, world-phase)
- Historical log recall: CampaignTimelinePanel, CharacterHistoryPanel, NPCTracker inline display, LegacySystem inline display wired into CampaignDashboard (3 buttons in Intel column) and CharacterDetailsScreen (View History button)
- TacticalBattleUI auto-resolve rewired from simplified power math to BattleResolver.resolve_battle() (rules-accurate multi-round combat with hit rolls, armor saves, deployment conditions)
- EndPhasePanel cycle summary reads real campaign data (progress_data, credits, story_points, crew size, victory conditions) instead of hardcoded placeholders

**Battle System Audit — Phases 16-18 (Feb 27-28, 30 sprints)**:

- Phase 16: 14 sprints — battle flow works end-to-end (CampaignTurnController → BattleTransitionUI → PreBattleUI → TacticalBattleUI → PostBattleSequence)
- Phase 17: 9 sprints — wired 26 battle companion panels into TacticalBattleUI with 3-zone tabbed layout
- Phase 18: 7 sprints — integration audit, deleted BattleResolutionUI (1,055 lines) + FPCM_BattleEventBus (388 lines), wired 10 orphaned component signals

**Battle Companion UI — Phase 22I-J (Feb 28)**:

- BattlefieldGridPanel.gd (~380 lines): 4x4 sector grid with terrain from compendium_terrain.json themes
- Visual canvas-drawn terrain shapes via `_draw()` API (11 shape types with keyword classification)
- Fixed right sidebar overlap (CombatSituationPanel offsets, DiceDashboard/CombatCalculator EXPAND_FILL flags)

**World→Battle Data Flow — Phase 21 (Feb 28, 3 sub-phases)**:

- Fixed 11+ files treating FiveParsecsCampaignCore as Dictionary (is Resource — use `"key" in campaign` not `.has()`)
- Crew task propagation, mission prep refresh, job offer → battle data handoff

**Equipment Pipeline — Phase 22 (Feb 28, 4 sprints)**:

- Fixed equipment_data key mismatch: 5 files read `"pool"` but FiveParsecsCampaignCore stores under `"equipment"`
- Uncommented Character.to_dictionary() with dual key aliases (`"id"`/`"character_id"`, `"name"`/`"character_name"`)
- Fixed PreBattleUI method mismatch: CampaignTurnController called non-existent `initialize_battle()` → fixed to `setup_preview()`
- Added terrain setup guide for tabletop text-based terrain suggestions

**Script Consolidation — Phase 5 (Feb 20, 9 sprints)**:
- Deleted 4 dead code files (~545 lines)
- Extracted game logic from UI panels: CharacterPhasePanel EVENT_TABLE → `character_events.gd`; EndPhasePanel victory checking → `VictoryChecker.gd`; sell value formula → EquipmentManager; deployment/terrain inference → DeploymentManager
- Fixed CampaignDashboard stale enum bug (CampaignPhase → FiveParsecsCampaignPhase)
- Wired BattleResolver.resolve_battle() into BattlePhase._simulate_battle_outcome() (replaces ad-hoc formula with rules-accurate multi-round combat)
- Deprecated old CampaignPhase enum (kept for save-format compat)

**Campaign Turn System (Sprints 1-10)**:
- Turn flow expanded from 4 phases to 9: STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT
- CampaignPhaseManager fully rewritten (~761 lines) with handler instantiation, transitions, data handoff
- Sprint 2: Character data model (skills/abilities/XP persistence)
- Sprint 3: Story phase integration (StoryPhasePanel wired)
- Sprint 4: Victory checking (21 victory types, real campaign data)
- Sprint 5: EndPhasePanel snapshot/delta mechanism
- Sprint 6: Trading backend (EquipmentManager + GameStateManager)
- Sprint 7: World phase audit (7+ components verified)
- Sprint 8: Stars of Story (persistence + PostBattlePhase integration)
- Sprint 9: Crew morale system (MoraleSystem.gd, 0-100 scale)
- Sprint 10: Bot/Precursor upgrades (AdvancementPhasePanel fix)

**Battle Phase Manager (8 sprints)**:
- Tabletop companion assistant (NOT a tactical simulator)
- Three-Tier Tracking: LOG_ONLY / ASSISTED / FULL_ORACLE
- ~11 new files (~2,000 lines), ~17 modified files (~1,000 lines)
- All output is TEXT INSTRUCTIONS for the player to execute on physical table

**Compendium DLC (10 sprints, Feb 2026)**:
- DLC Infrastructure: DLCManager autoload, 35 ContentFlags, 3 DLC packs
- Krag & Skulker species with enum sync, battle/character wiring
- Psionics system: legality, enemy powers, PsionicManager rewrite
- New kit: training, bot upgrades, psionic equipment (compendium_equipment.gd)
- Difficulty + combat: ProgressiveDifficultyTracker, compendium_difficulty_toggles
- Stealth missions, street fights, salvage jobs (3 mission generators)
- Faction DLC gating, world strife, expanded loans, name generation
- Expanded missions, no-minis combat, prison planet, introductory campaign
- UI polish: CheatSheet +8 compendium sections, DLCManagementDialog, grid movement ref
- ~15 new files, ~20 modified files, ~5,000 lines added
- Zero impact on core gameplay when all DLC disabled

**Compendium Mechanics Wiring Audit (10 sprints C-1 to C-10, Mar 2026)**:
- Found only 10/37 flags actually wired into gameplay despite data classes existing for all
- Fixed BOT_UPGRADES inversion (bots skipped in crew list), wired 12 additional flags
- Wired: EXPANDED_MISSIONS, DEPLOYMENT_VARIABLES, DIFFICULTY_TOGGLES math, PSIONICS legality, INTRODUCTORY_CAMPAIGN routing, EXPANDED_QUESTS, EXPANDED_LOANS, EXPANDED_CONNECTIONS, AI_VARIATIONS, DRAMATIC_COMBAT, NAME_GENERATION (ship+world), TERRAIN_GENERATION, FRINGE_WORLD_STRIFE downstream
- Style fixes: explicit preloads in 4 files, randomized weapon types, variable rename
- 12 files modified, zero compile errors, all scene nodes verified
- Final status: 22/37 wired, 10 deferred, 5 placeholder (Bug Hunt)

**Data Integrity Fixes (Feb 2026)**:
- PostBattlePhase verified: all 18+ data types persist to GameState/campaign
- Shallow copy fix at PostBattlePhase entry (duplicate → duplicate(true))
- Snapshot timing fix (snapshot before turn increment)
- Battle skip path fix (routes through POST_MISSION for recovery ticks)
- Property bridges: combat_skill, combat, reactions, is_dead, weapons, items
- FiveParsecsCampaign bridge methods (crew_members, credits, get_active_crew_members)
- Campaign serialize/deserialize unified
- GameStateManager refactored (game_state getter delegates to real autoload)

**Tech Debt + Feature Gaps (12 sprints, Feb 9 2026)**:
- Wired 5 dormant systems: PatronSystem, FactionSystem, StoryTrackSystem, KeywordSystem, LegacySystem
- Wired 3 mission generators (Stealth/StreetFight/Salvage) into WorldPhase job pipeline
- Properly gated 6 DLC ContentFlags in BattlePhase (ELITE_ENEMIES, NO_MINIS, GRID, SPECIES)
- Fixed brawling weapon_traits derivation from equipment properties
- New EquipmentComparisonPanel for side-by-side stat comparison in TradePhasePanel
- Replaced 3 WorldPhase TODO stubs with real implementations
- Activated KeywordSystem + LegacySystem in CampaignPhaseManager

**Final 3 Mechanics (3 sprints, Feb 9 2026) — 170/170 = 100%**:
- Travel Costs: Ship trait modifiers (Fuel-efficient -1cr, Fuel Hog +1cr), component fuel (+1/3), Fuel Converters (-2cr)
- Ship Repairs: Free +1 hull/turn, Mechanic Training +1, paid repair text instructions, emergency takeoff warning
- Travel Events: All 16 official D100 events with rules-accurate mechanics (pp.72-75), irregular ranges

**4-Feature Implementation (9 sprints, Feb 8 2026)**:
- Planet Persistence: PlanetDataManager autoload, per-planet contacts
- Tactical Grid: BattlefieldGridUI wired into BattleSetupPhasePanel
- History/Storytelling: CampaignJournal autoload, CharacterHistoryPanel, CampaignTimelinePanel
- Import/Export: ExportPanel + ImportPanel in CampaignDashboard

**Stub/TODO Flesh-Out (11 sprints, Feb 9 2026)**:
- Sprint 0: Patched WorldPhase null check + safe wrapper double-call + TravelPhase state mutations
- Sprint 1: Deleted 9 empty files + dead FactionManager stub
- Sprint 2-3: Upgraded NPCTracker (37→192 lines) + LegacySystem (18→111 lines) with serialize/deserialize
- Sprint 4-5: CharacterInventory armor/items serialization + CampaignManager item rewards wiring
- Sprint 6: StoryPhasePanel wired to EventManager (8 events, real GameState API)
- Sprint 7: AutomationSettings options + AccessibilityManager focus indicator
- Sprint 8: BattleSetupWizard wired to EnemyGenerator + GameState crew size
- Sprint 9: QOL autoload serialization pipeline (4 autoloads → PersistenceService)
- Sprint 10: world_traits.json (16 traits) + 5 path constants fixed across 3 data manager files

**Migration**:
- Godot 4.5.1 → 4.6 complete
- Test framework: GUT (Godot Unit Test)
- Zero compile errors verified

### Previous Updates (December 2025)
- BattleResolver: Real combat system using BattleCalculations
- Event Effects: All 53+ campaign/character events fully wired
- Training UI: TrainingSelectionDialog integrated
- Galactic War: GalacticWarPanel integrated
- Story Points: Turn-based earning wired
- Species Restrictions: 5 Core Rules species

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
| XP Tracking | `Character.gd` | COMPLETE | Per-character, persistent |
| Stat Advancement Costs | `AdvancementSystem.gd` | COMPLETE | 5-10 XP per stat |
| Training Paths (9 types) | `AdvancementSystem.gd` | COMPLETE | Sprint 2: skills/abilities/XP model |
| Max Stat Values | `CharacterAdvancementService.gd` | COMPLETE | Species-dependent |
| Bot/Precursor Upgrades | `AdvancementPhasePanel.gd` | COMPLETE | Sprint 10: credit-based upgrades |

### Injury System (from rules p.123)

| MECHANIC | SCRIPT FILE | STATUS | NOTES |
|----------|-------------|--------|-------|
| Injury Types (8) | `InjurySystemConstants.gd` | COMPLETE | Fatal through Hard Knocks |
| D100 Roll Ranges | `InjurySystemConstants.gd` | COMPLETE | 1-15 Fatal, etc. |
| Recovery Times | `InjuryRecoverySystem.gd` | COMPLETE | 0-6 turns |
| Medical Treatment (6 types) | `InjuryRecoverySystem.gd` | COMPLETE | Field to Cybernetic |
| Injury Persistence | `PostBattlePhase.gd` | COMPLETE | GameStateManager.apply_crew_injury() wired |
| Recovery Tick Per Turn | `PostBattlePhase.gd` | COMPLETE | _tick_injury_recovery() runs every turn |

### Crew Management

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS |
|----------|-------------|------------|--------|
| Crew Creation (6 chars) | `CrewCreation.gd` | `InitialCrewCreation.tscn` | COMPLETE |
| Captain Creation | `CaptainCreation.gd` | - | COMPLETE |
| Crew Relationships | `CrewRelationshipManager.gd` | `CrewRelationshipsPanel.tscn` | COMPLETE |
| Crew Management Screen | `CrewManagementScreen.gd` | `CrewManagementScreen.tscn` | COMPLETE |
| Character Details | `CharacterDetailsScreen.gd` | `CharacterDetailsScreen.tscn` | COMPLETE |
| Character Card | `CharacterCard.gd` | `CharacterCard.tscn` | COMPLETE |
| Crew Morale | `MoraleSystem.gd` | - | COMPLETE | Sprint 9: 0-100 scale |

---

## 2. CAMPAIGN TURN STRUCTURE

### Campaign Turn Flow (Updated Feb 2026)

```
STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT → (next turn)
```

### Phase Types
- **Handler-driven** (4): Travel, World/Upkeep, Battle/Mission, PostBattle/PostMission
- **UI-driven** (5): Story, Advancement, Trading, Character, Retirement

### Phase Orchestration

| SYSTEM | SCRIPT FILE | SCENE FILE | STATUS | NOTES |
|--------|-------------|------------|--------|-------|
| Campaign Phase Manager | `CampaignPhaseManager.gd` | - | COMPLETE | ~761 lines, full rewrite Feb 2026 |
| Campaign Turn Controller | `CampaignTurnController.gd` | `CampaignTurnController.tscn` | COMPLETE | UI mapping, progress display |
| Phase Handler Init | `CampaignPhaseManager.gd` | - | COMPLETE | 4 handlers as child nodes |
| Turn-Start Snapshot | `CampaignPhaseManager.gd` | - | COMPLETE | Sprint 5: delta calculations |
| Story Phase Panel | `StoryPhasePanel.gd` | `StoryPhasePanel.tscn` | COMPLETE | Sprint 3 |
| Advancement Phase Panel | `AdvancementPhasePanel.gd` | `AdvancementPhasePanel.tscn` | COMPLETE | Sprint 10 |
| Trade Phase Panel | `TradePhasePanel.gd` | `TradePhasePanel.tscn` | COMPLETE | Sprint 6 |
| Character Phase Panel | `CharacterPhasePanel.gd` | `CharacterPhasePanel.tscn` | COMPLETE | Sprint 1: weighted random events |
| End Phase Panel | `EndPhasePanel.gd` | `EndPhasePanel.tscn` | COMPLETE | Sprint 5: snapshot/delta |
| Victory Checking | `VictoryChecker.gd`, `EndPhasePanel.gd` | - | COMPLETE | Sprint 4: 21 victory types; Phase 5: extracted to VictoryChecker.gd |

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
| D100 Event Table | `TravelPhase.gd` | - | COMPLETE | 16 official events with irregular D100 ranges |
| Event Processing | `TravelPhase.gd` | - | COMPLETE | All 16 events with rules-accurate mechanics (pp.72-75) |
| **New World Arrival** | | | | |
| World Generation | `TravelPhase.gd` | - | COMPLETE | |
| World Traits (D100) | `TravelPhase.gd` | - | COMPLETE | 50+ traits |
| Rival Following (D6, 5+) | `TravelPhase.gd` | - | COMPLETE | |
| Patron Dismissal | `TravelPhase.gd` | - | COMPLETE | PatronSystem wired (Feb 9) |
| License Requirements | `TravelPhase.gd` | - | COMPLETE | |
| **UI** | | | | |
| Travel Controller | `CampaignTravelController.gd` | `CampaignTravelController.tscn` | COMPLETE | |

---

## 4. WORLD PHASE (Step 2 - UPKEEP)

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
| Redistribute Gear | `WorldPhase.gd` | `AssignEquipmentComponent.tscn` | COMPLETE | Sprint 7 verified |
| Ship Stash Management | `EquipmentManager.gd` | - | COMPLETE | Sprint 6: trading backend |
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

## 5. BATTLE PHASE (Step 3 - MISSION)

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
| Deployment Positions | `BattlePhase.gd` | `BattleSetupPhasePanel.tscn` | COMPLETE | Wired to DeploymentManager |
| **Combat** | | | | |
| Initiative (D6, 4+ crew first) | `BattlePhase.gd` | - | COMPLETE | |
| Combat Rounds | `BattlePhase.gd`, `BattleResolver.gd` | - | COMPLETE | BattlePhase auto-resolve now delegates to BattleResolver.resolve_battle() (Phase 5 Sprint 5.8) |
| **Battle Events** | | | | |
| D6 Event Table | `BattlePhase.gd` | - | COMPLETE | Sprint BPM-6: BattleEventManager |
| **UI** | | | | |
| Pre-Battle UI | `PreBattleUI.gd` | `PreBattleUI.tscn` | COMPLETE | |
| Pre-Battle Equipment | `PreBattleEquipmentUI.gd` | `PreBattleEquipmentUI.tscn` | COMPLETE | |
| Battle Transition | `BattleTransitionUI.gd` | `BattleTransitionUI.tscn` | COMPLETE | |
| Enemy Gen Wizard | `EnemyGenerationWizard.gd` | - | COMPLETE | |

---

## 5b. BATTLE PHASE MANAGER (Tabletop Companion - Feb 2026)

The Battle Phase Manager is a **tabletop companion assistant** that generates TEXT INSTRUCTIONS
for the player to execute on the physical table. It is NOT a tactical simulator.

### Three-Tier Tracking System

| TIER | DESCRIPTION | STATUS |
|------|-------------|--------|
| LOG_ONLY | Player handles all rules, app just logs outcomes | COMPLETE |
| ASSISTED | App provides suggestions, dice roll helpers, reminders | COMPLETE |
| FULL_ORACLE | App makes all AI decisions for solo play | COMPLETE |

### Battle Phase Manager Components

| MECHANIC | SCRIPT FILE | STATUS | NOTES |
|----------|-------------|--------|-------|
| Tier Controller | `BattleTierController.gd` | COMPLETE | BPM Sprint 1 |
| UI Wiring | `BattlePhaseUI.gd` | COMPLETE | BPM Sprint 2 |
| Pre-Battle Checklist | `PreBattleChecklist.gd` | COMPLETE | BPM Sprint 3 |
| Terrain Suggestions | `TerrainSuggestions.gd` | COMPLETE | BPM Sprint 4 |
| Round Manager | `BattleRoundManager.gd` | COMPLETE | BPM Sprint 5 |
| Events & Escalation | `BattleEventManager.gd` | COMPLETE | BPM Sprint 6 |
| AI Oracle | `AIOracle.gd` | COMPLETE | BPM Sprint 7 |
| Battle Log / Keywords / Cheat Sheet | `BattleLogUI.gd` | COMPLETE | BPM Sprint 8 |

---

## 6. POST-BATTLE PHASE (Step 4 - POST_MISSION)

| MECHANIC | SCRIPT FILE | SCENE FILE | STATUS | NOTES |
|----------|-------------|------------|--------|-------|
| **1. Rival Status** | | | | |
| Rival Defeat Check | `PostBattlePhase.gd` | - | COMPLETE | Persists to campaign |
| Rival Removal Roll | `PostBattlePhase.gd` | - | COMPLETE | |
| **2. Patron Status** | | | | |
| New Patron Contact | `PostBattlePhase.gd` | - | COMPLETE | GameState.add_patron_contact() |
| Persistent Patrons | `PostBattlePhase.gd` | - | COMPLETE | PatronSystem wired (Feb 9) |
| **3. Quest Progress** | | | | |
| Quest Advancement | `PostBattlePhase.gd` | - | COMPLETE | D6+rumors, 3 outcomes |
| **4. Payment** | | | | |
| Base Mission Pay | `PostBattlePhase.gd` | - | COMPLETE | GameState.add_credits() |
| Danger Pay Bonus | `PostBattlePhase.gd` | - | COMPLETE | Difficulty multiplier |
| **5. Battlefield Finds** | | | | |
| Search Rolls | `PostBattlePhase.gd` | - | COMPLETE | |
| Find Result Table | `PostBattlePhase.gd` | - | COMPLETE | |
| **6. Invasion Check** | | | | |
| World Invasion (2D6, 9+) | `PostBattlePhase.gd` | - | COMPLETE | GameState.set_invasion_pending() |
| **7. Loot** | | | | |
| Enemy Loot Tables | `PostBattlePhase.gd` | - | COMPLETE | |
| Loot to Inventory | `PostBattlePhase.gd` | - | COMPLETE | add_to_ship_inventory() |
| **8. Injuries** | | | | |
| Injury Determination | `PostBattlePhase.gd` | - | COMPLETE | |
| Severity Roll (D100) | `PostBattlePhase.gd` | - | COMPLETE | InjurySystemConstants |
| Recovery Time Calc | `PostBattlePhase.gd` | - | COMPLETE | |
| Stars of Story Protection | `PostBattlePhase.gd` | - | COMPLETE | Sprint 8: DRAMATIC_ESCAPE, IT_WASNT_THAT_BAD |
| **9. Experience** | | | | |
| XP Calculation | `PostBattlePhase.gd` | - | COMPLETE | 7 XP sources (Core Rules p.89-90) |
| XP Distribution | `PostBattlePhase.gd` | - | COMPLETE | GameState.add_crew_experience() |
| Bot XP Skip | `PostBattlePhase.gd` | - | COMPLETE | Sprint 10: Bots skip XP |
| **10. Training** | | | | |
| Training Opportunities | `PostBattlePhase.gd` | `TrainingSelectionDialog.tscn` | COMPLETE | 2D6 approval, 8 courses |
| **11. Purchase Items** | | | | |
| Shop Interface | `PurchaseItemsComponent.gd` | `.tscn` | COMPLETE | Sprint 6: trading backend |
| **12. Campaign Event** | | | | |
| D100 Event Table | `PostBattlePhase.gd` | `CampaignEventComponent.tscn` | COMPLETE | |
| Event Effects | `PostBattlePhase.gd` | - | COMPLETE | All 53+ events wired |
| Precursor Double-Roll | `PostBattlePhase.gd` | - | COMPLETE | Sprint 10 |
| **13. Character Event** | | | | |
| Character Event Roll | `PostBattlePhase.gd` | `CharacterEventComponent.tscn` | COMPLETE | |
| Event Effects | `PostBattlePhase.gd` | - | COMPLETE | All 23+ events wired |
| **14. Galactic War** | | | | |
| War Progress Update | `PostBattlePhase.gd` | `GalacticWarPanel.tscn` | COMPLETE | 2D6 per planet |
| **Post-Battle Completion** | | | | |
| Injury Recovery Tick | `PostBattlePhase.gd` | - | COMPLETE | Runs every turn (incl. no-battle) |
| Morale Adjustment | `PostBattlePhase.gd` | - | COMPLETE | Sprint 9: MoraleSystem |
| Character Lifetime Stats | `PostBattlePhase.gd` | - | COMPLETE | kills, battles, damage |
| Battle Journal Entry | `PostBattlePhase.gd` | - | COMPLETE | CampaignJournal |
| Battle-Skip Handling | `PostBattlePhase.gd` | - | COMPLETE | Feb 2026: graceful no-battle path |

---

## 7. ECONOMY SYSTEM

| MECHANIC | SCRIPT FILE | DATA FILE | STATUS |
|----------|-------------|-----------|--------|
| **Credits** | | | |
| Core Currency | `TradingSystem.gd` | `equipment_database.json` | COMPLETE |
| Credits Display | `EquipmentPanel.gd` | - | COMPLETE |
| Trading Backend | `EquipmentManager.gd`, `GameStateManager.gd` | - | COMPLETE | Sprint 6 |
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
| **Bot Upgrades** | `AdvancementPhasePanel.gd` | - | COMPLETE | Sprint 10: credit-based |
| **Implants** | `Character.gd` | IMPLANT_TYPES, add_implant(), loot pipeline | COMPLETE |
| **Equipment UI** | | | |
| Equipment Panel | `EquipmentPanel.gd` | `EquipmentPanel.tscn` | COMPLETE |
| Equipment Picker | `EquipmentPickerDialog.gd` | - | COMPLETE |
| Equipment Formatter | `EquipmentFormatter.gd` | - | COMPLETE |
| **Equipment Comparison** | `EquipmentComparisonPanel.gd` | - | COMPLETE | Side-by-side stat diff (Feb 9) |

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
| Ship Repairs | `ShipData.gd`, `WorldPhase.gd` | - | COMPLETE | Free +1/turn, Mechanic Training +1, paid 1cr/point |
| Ship Manager UI | `ShipManager.gd` | - | COMPLETE |
| Ship Inventory | `ShipInventory.gd` | - | COMPLETE |
| Ship Stash Panel | `ShipStashPanel.gd` | `ShipStashPanel.tscn` | COMPLETE |
| Ship Panel (Wizard) | `ShipPanel.gd` | - | COMPLETE |
| Travel Costs | `TravelPhase.gd` | - | COMPLETE | Base 5cr + Fuel-efficient/-Hog/components/Fuel Converters modifiers |

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

## 11. COMPENDIUM DLC (Feb 2026 - 10 Sprints)

All Compendium content is gated behind DLCManager with 35 ContentFlags across 3 DLC packs.
Zero impact on core gameplay when disabled. All output follows tabletop companion text instruction model.

### DLC Packs

| Pack | Features | Status |
|------|----------|--------|
| **Trailblazer's Toolkit** | Krag & Skulker species, Psionics, Training, Bot Upgrades, Ship Parts, Psionic Gear | COMPLETE |
| **Freelancer's Handbook** | Progressive Difficulty, Difficulty Toggles, AI Variations, Escalating Battles, Elite Enemies, No-Minis Combat, Grid Movement, Expanded Missions/Quests/Connections | COMPLETE |
| **Fixer's Guidebook** | Stealth Missions, Street Fights, Salvage Jobs, Expanded Factions, World Strife, Loans, Names, Introductory Campaign, Prison Planet | COMPLETE |

### Compendium Mechanics

| MECHANIC | SCRIPT FILE | STATUS | NOTES |
|----------|-------------|--------|-------|
| **Species** | | | |
| Krag Species | `compendium_species.gd`, `Character.gd`, `BattleCalculations.gd` | COMPLETE | No Dash, reroll vs Rivals |
| Skulker Species | `compendium_species.gd`, `Character.gd`, `BattleCalculations.gd` | COMPLETE | Speed 6", ignore difficult ground |
| **Psionics** | | | |
| Psionic Legality | `PsionicSystem.gd` | COMPLETE | Outlawed/Unusual/Who Cares |
| Enemy Psionics (10 powers) | `PsionicSystem.gd` | COMPLETE | Assail through Psionic Rage |
| PsionicManager Rewrite | `PsionicManager.gd` | COMPLETE | Was 14-line stub |
| **Equipment** | | | |
| Advanced Training (5 types) | `compendium_equipment.gd` | COMPLETE | Freelancer Cert through Tactical |
| Bot Upgrades (6 types) | `compendium_equipment.gd` | COMPLETE | Built-in Weapon through Vision |
| Psionic Equipment (3 types) | `compendium_equipment.gd` | COMPLETE | Amplifier, Shield, Dampener |
| **Difficulty** | | | |
| Progressive Difficulty | `ProgressiveDifficultyTracker.gd` | COMPLETE | Turn-based scaling, 2 options |
| Difficulty Toggles (6 groups) | `compendium_difficulty_toggles.gd` | COMPLETE | 18 sub-toggles |
| **Missions** | | | |
| Stealth Missions | `StealthMissionGenerator.gd` | COMPLETE | 6 objectives, spotting mechanics |
| Street Fights | `StreetFightGenerator.gd` | COMPLETE | Suspect markers, police response |
| Salvage Jobs | `SalvageJobGenerator.gd` | COMPLETE | Tension track, contact resolution |
| Expanded Missions | `compendium_missions_expanded.gd` | COMPLETE | 13 objectives, 6 deployments |
| No-Minis Combat | `compendium_no_minis.gd`, `NoMinisCombatPanel.gd` | COMPLETE | Abstract zone-based |
| **World Systems** | | | |
| Fringe World Strife (10 events) | `compendium_world_options.gd` | COMPLETE | Instability 0-10 scale |
| Expanded Loans (6 origins) | `compendium_world_options.gd` | COMPLETE | Interest + enforcement |
| Name Generation (7 species) | `compendium_world_options.gd` | COMPLETE | + ship/world names |
| Expanded Factions | `FactionSystem.gd` | COMPLETE | DLC gate on existing code |
| **Misc** | | | |
| PvP/Co-op Rules | `compendium_missions_expanded.gd` | COMPLETE | Text instruction format |
| Introductory Campaign (5 missions) | `compendium_missions_expanded.gd` | COMPLETE | Guided tutorial |
| Prison Planet Character | `compendium_missions_expanded.gd` | COMPLETE | Creation option |
| Grid Movement Reference | `CheatSheetPanel.gd` | COMPLETE | 1 square = 2" conversion |
| **UI** | | | |
| CheatSheet +8 Sections | `CheatSheetPanel.gd` | COMPLETE | DLC-gated accordion sections |
| DLC Management Dialog | `DLCManagementDialog.gd` | COMPLETE | Pack ownership + flag toggles |
| Stealth Mission Panel | `StealthMissionPanel.gd` | COMPLETE | Code-only UI |
| No-Minis Combat Panel | `NoMinisCombatPanel.gd` | COMPLETE | Zone-based abstract UI |

### Key Files
- `src/core/systems/DLCManager.gd` - Autoload, ContentFlag enum, ownership/flag management
- `src/data/compendium_*.gd` - 6 data files with Dictionary-driven tables and static query methods
- `src/core/mission/Stealth|StreetFight|Salvage*.gd` - 3 mission generators
- `src/ui/dialogs/DLCManagementDialog.gd` - DLC ownership and feature toggle UI

---

## REMAINING GAPS

### HIGH PRIORITY

No remaining high-priority gaps.

### MEDIUM PRIORITY

| Gap | Impact | Location |
|-----|--------|----------|
| BattleJournal logging | Battles produce blank journal — logging methods never called | TacticalBattleUI |
| NPCTracker integration | Patron/rival/location tracking API exists but 0% gameplay calls | WorldPhaseController, PostBattlePhase |
| LegacySystem lifecycle | No campaign archival on end, no legacy bonus on new campaign | EndPhasePanel, CampaignCreationCoordinator |
| CampaignJournal character events | Only PostBattlePhase generates entries; advancement/injuries unlogged | AdvancementPhasePanel, CharacterPhasePanel |

### LOW PRIORITY (Compendium Deferred Items)

| Gap | Impact | Location |
|-----|--------|----------|
| Full PSIONICS (creation/advancement/battle) | Legality wired; no character creation, advancement, or battle action hooks | PsionicSystem.gd, CharacterCreator, TacticalBattleUI |
| PVP_BATTLES / COOP_BATTLES | Complete rule sets exist, no battle mode selection UI | TacticalBattleUI |
| PRISON_PLANET_CHARACTER | Full effect data exists, no character creation panel option | CharacterCreator |
| GRID_BASED_MOVEMENT | Flag stored, no grid system reads it | TacticalBattleUI |
| Species creation text + armor rules | Krag/Skulker creation guidance not shown, armor rules not enforced | CharacterCreator, EquipmentManager |
| PSIONIC_EQUIPMENT psionic_only | Restriction not enforced in equipment assignment | EquipmentManager |
| NEW_TRAINING one_per_crew | Freelancer Cert/Instructor duplicate purchase allowed | AdvancementPhasePanel |
| NEW_SHIP_PARTS to ship slots | Parts go to generic pool, not dedicated ship slots | ShipPanel |

### RESOLVED (Previously listed as gaps)
| Gap | Resolution | Date |
|-----|------------|------|
| Patron Persistence Details | NPCTracker upgraded (192 lines, serialize/deserialize) + PatronSystem wired | Feb 9, 2026 |
| Some Starship Travel Events | All 16 D100 events with state mutations (Sprint 0 bug fix) | Feb 9, 2026 |
| Ship Repair Details | Free +1/turn, Mechanic Training +1, paid 1cr/point text instructions | Feb 9, 2026 |
| Travel Cost Details | Ship trait modifiers, component fuel, Fuel Converters | Feb 9, 2026 |
| QOL State Persistence | 4 autoloads wired into PersistenceService save/load pipeline | Feb 9, 2026 |
| Armor/Item Serialization | CharacterInventory serialize/deserialize implemented | Feb 9, 2026 |
| Mission Item Rewards | CampaignManager wires rewards to GameState inventory | Feb 9, 2026 |
| World Traits Data | world_traits.json populated with 16 traits | Feb 9, 2026 |
| Equipment Path Constants | 5 path constants fixed across 3 data manager files | Feb 9, 2026 |
| Brawling Weapon Bonuses | CheatSheetPanel + CombatCalculator text updated (+2 Melee, +1 Pistol, Natural 6/1) | Feb 2026 |
| Implants | Character.gd IMPLANT_TYPES registry + loot pipeline in PostBattlePhase | Feb 2026 |
| Bot Injury Table | InjurySystemConstants BotInjuryType enum + PostBattlePhase bot detection | Feb 2026 |
| EscalatingBattlesManager | Instantiated in BattleSetupPhasePanel.setup_phase() | Feb 2026 |
| Character Class Fragmentation | Consolidated to 1 canonical Character + thin redirects | Feb 2026 |
| Ship Stash Management | EquipmentManager + GameStateManager Sprint 6 | Feb 2026 |
| Injury Persistence | GameStateManager.apply_crew_injury() | Feb 2026 |
| Bot Upgrades | AdvancementPhasePanel Sprint 10 | Feb 2026 |
| Training UI Integration | TrainingSelectionDialog wired | Dec 2025 |
| Event Effects Application | All 53+ events wired | Dec 2025 |
| Galactic War Progress | GalacticWarPanel wired | Dec 2025 |
| Battle Simulation Only | BattleResolver uses BattleCalculations | Dec 2025 |
| Species Restrictions | 5 Core Rules restrictions | Dec 2025 |

---

## SIGNAL WIRING STATUS

### Properly Wired (Working)
- Character creation → GameState.current_campaign.crew
- Crew management ↔ Character details screens
- Phase transitions: STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT
- Phase handler completion callbacks with data handoff (Feb 2026)
- campaign_turn_started / campaign_turn_completed signals (Feb 2026)
- PostBattlePhase → GameState persistence (18+ data types verified Feb 2026)
- Loot generation → Ship inventory (add_to_ship_inventory)
- XP gain → Character advancement (add_crew_experience)
- Upkeep → Credits deduction
- Event effects → Full game state changes
- Training UI → AdvancementSystem
- Story point turn earning → CampaignPhaseManager
- Galactic War → PostBattleSequence
- MoraleSystem → Campaign.crew_morale (Sprint 9)
- Stars of Story → Campaign.stars_of_story_data (Sprint 8)
- Battle skip → POST_MISSION (with battle_skipped flag, Feb 2026)
- StoryPhasePanel → EventManager (local instantiation, 8-event catalog, Feb 9)
- BattleSetupWizard → EnemyGenerator + GameState crew size (Feb 9)
- PersistenceService → QOL autoloads save/load (CampaignJournal, TurnPhaseChecklist, NPCTracker, LegacySystem, Feb 9)
- CampaignManager → GameState.add_inventory_item() for mission rewards (Feb 9)
- AccessibilityManager → focus indicator StyleBoxFlat (Feb 9)

### Needs Wiring

- BattleJournal logging calls from TacticalBattleUI battle event handlers
- NPCTracker.track_patron_interaction() / track_rival_encounter() / visit_location() from gameplay phases
- LegacySystem.archive_campaign() from campaign end, get_legacy_bonus() from new campaign start
- CampaignJournal.auto_create_character_event() from advancement and character phases

---

## RECOMMENDED NEXT STEPS

1. ~~Complete brawling weapon bonuses~~ ✅ DONE (Feb 2026)
2. ~~Add Bot Injury Table~~ ✅ DONE (Feb 2026)
3. ~~Implement Implants subsystem~~ ✅ DONE (Feb 2026)
4. **Optional: Tactical Combat UI** for turn-by-turn battle interface
5. **Full E2E testing** of campaign turn loop with real combat
6. ~~Character class consolidation~~ ✅ DONE (Feb 2026)

---

**Document Status**: COMPREHENSIVE UPDATE COMPLETE
**Last Updated**: 2026-04-07
**Engine Version**: Godot 4.6-stable
**Test Framework**: gdUnit4 v6.0.3
