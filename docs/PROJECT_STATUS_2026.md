# Five Parsecs Campaign Manager - Project Status

**Last Updated**: February 28, 2026 (Phase 22J)
**Engine**: Godot 4.6-stable (pure GDScript, non-mono)
**Test Framework**: gdUnit4 v6.0.3
**Repository**: https://github.com/Reptarus/five-parsecs-campaign-manager

---

## Overall Status

| Metric | Value |
|--------|-------|
| Game Mechanics Compliance (incl. Compendium) | **100%** (170/170 mechanics) |
| Core Rules Systems | **11/11** verified correct |
| Campaign Turn Phases | **9/9** fully wired |
| Battle Phase Manager | **8/8** sprints complete |
| Tech Debt + Feature Gaps | **ALL cleared** (12 sprints Feb 9) |
| Compile Errors (Godot 4.6) | **0** |
| UI/UX Design System | **7/7** sprints + **8/8** integration audit |
| Scene Routing & Navigation | **100%** — 20 calls migrated, back buttons, per-turn auto-save |
| Core/Compendium Wiring Audit | **6/6** sprints — Dashboard fix, phase data, loans, psionics, names |
| Script Consolidation (Phase 5) | **9/9** sprints — Dead code removal, logic extraction, enum fix, BattleResolver wiring |
| UI/UX Flow Wiring (Phase 6) | **Complete** — MainMenu SceneRouter, campaign creation handoff, Character.gd structural repair, docstring fixes |
| Campaign Creation (Phase 11) | **Complete** — 7-phase coordinator wired, tutorial bypass, redundant buttons removed, CharacterCreator flat stats fix |
| Equipment + D100 Extras | **Complete** — Per-character equipment generation (was hardcoded 8), D100 table extras (patrons/rivals/story points/rumors) wired into creation flow |
| World→Battle Data Flow (Phase 21) | **Complete** — Fixed campaign API mismatches, crew task result propagation, mission prep data, battle transition method names |
| Equipment Pipeline + PreBattle (Phase 22) | **Complete** — Fixed equipment_data key mismatch, Character.to_dictionary(), PreBattle method wiring |
| Battle Companion UI (Phase 22I-J) | **Complete** — Visual battlefield grid with canvas-drawn terrain, right sidebar layout fix, 26 tabbed companion panels |

---

## Systems Completed

### Campaign Turn Flow (9 Phases)
Full turn loop operational: STORY -> TRAVEL -> UPKEEP -> MISSION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT

Each phase has a dedicated panel wired into CampaignTurnController with proper completion signals and data handoff.

### Battle Phase Manager (Tabletop Companion)
The battle system is a **tabletop companion assistant** (NOT a tactical simulator). It generates TEXT INSTRUCTIONS for the player to execute on the physical tabletop.

Three-tier tracking system:
- **LOG_ONLY**: Player resolves everything, app records results
- **ASSISTED**: App suggests rolls and outcomes, player confirms
- **FULL_ORACLE**: App resolves all mechanics automatically

8 sprints completed: Tier controller, UI wiring, pre-battle checklist, terrain suggestions, round manager, events/escalation, AI oracle, battle log with keywords and cheat sheet.

**Tactical Battle UI** (`TacticalBattleUI.gd`, ~1,700 lines): Three-zone tabbed layout hosting 26 companion panels:

- **Left sidebar**: BattleLogPanel, QuickActionsPanel, ActivationTracker, InitiativePanel
- **Center**: BattlefieldGridPanel (visual 4x4 sector grid with canvas-drawn terrain shapes), RoundTracker, PhaseDisplay
- **Right sidebar** (tabbed): DiceDashboard, CombatCalculator, CombatSituationPanel, DualInputRoll, CheatSheetPanel, WeaponTableDisplay, TerrainSetupGuide

**Battlefield Grid**: 4x4 sector map (A1-D4) generated from compendium_terrain.json themes. Each cell renders terrain features as geometric shapes (buildings, walls, rocks, trees, water, etc.) via Godot's `_draw()` canvas API. Cells show cover ratings, notable feature indicators, and clickable detail popovers.

### Character System
Consolidated to **1 canonical Character class** (`src/core/character/Character.gd`, ~1,900 lines) with thin redirects for backward compatibility:
- `BaseCharacterResource` -> redirect to Character
- `BaseCharacter` (character_base.gd) -> API-compatible stub
- `game/character/Character.gd` -> redirect to Character
- `CharacterUnit` -> separate Node2D battle unit (kept)

Character features: stats (combat, reaction, toughness, speed, savvy, luck), skills/abilities, XP/leveling, equipment, implants (6 types, max 3), morale, faction relations, serialization.

### Post-Battle Processing (14 Sub-Steps)
- Injury processing (human + bot injury tables)
- Loot gathering with implant auto-install pipeline
- Experience distribution
- Stars of Story persistence
- Morale updates
- Equipment damage/repair
- Recovery ticks
- Journal entries

### Other Completed Systems
- **Victory Checking**: 21 victory types with real campaign data
- **Trading Backend**: EquipmentManager + GameStateManager integration
- **Crew Morale**: MoraleSystem.gd (0-100 scale)
- **Bot/Precursor Upgrades**: Credit-based advancement
- **Brawling**: Full rules with weapon bonuses, natural 6/1
- **Escalating Battles**: EscalatingBattlesManager wired into battle setup
- **Story Phase**: StoryPhasePanel wired to EventManager with 8 event catalog + GameState effects
- **End Phase**: Snapshot/delta mechanism for turn summaries
- **Battle Setup Wizard**: One-click battle generation from EnemyGenerator + GameState crew data
- **Accessibility**: Focus indicator (cyan ring), automation settings panel options toggle
- **PatronSystem**: Fully wired into WorldPhase (job generation) + PostBattlePhase (job completion)
- **FactionSystem**: Wired into PostBattlePhase (rival reputation/faction standing) + WorldPhase (faction missions)
- **StoryTrackSystem**: Activated in CampaignPhaseManager (DLC-gated, 6-tick story clock)
- **KeywordSystem**: Enriches story events with keyword matches via KeywordDB autoload
- **LegacySystem**: Archives campaigns on victory, applies legacy bonus on new campaigns
- **Mission Generators**: Stealth, StreetFight, Salvage generators wired into WorldPhase job pipeline
- **Equipment Comparison**: Side-by-side stat comparison panel in TradePhasePanel

### Scene Routing & Navigation (Feb 9, 2026)
- **SceneRouter migration**: All 20 player-facing `change_scene_to_file()` calls across 12 files migrated to `SceneRouter.navigate_to()` / `navigate_back()` / `return_to_main_menu()`. Remaining raw calls are infrastructure-only (SceneRouter.gd, TransitionManager.gd, BaseController.gd, DeveloperDashboard.gd).
- **Back buttons**: Added to WorldPhaseSummary + SaveLoadUI (48px touch target, "< Back" text, `SceneRouter.navigate_back()`). PatronRivalManager already had one. Battle screens intentionally excluded (end_battle_button is the exit mechanism).
- **Per-turn auto-save**: `CampaignPhaseManager._auto_save_turn_start()` saves `turn_N_autosave` via PersistenceService before each turn increment. Leverages existing atomic save + rotating backup system.
- **Scene routing audit** (prerequisite): Fixed 4 broken SceneRouter paths, deleted 43 dead scene/script files.

### Script Consolidation — Phase 5 (Feb 20, 2026)
Campaign turn loop audit for dead code, misplaced game logic in UI panels, enum unification, and battle system wiring. 9 sprints:

- **Dead code removal**: 4 orphan files deleted (~545 lines) — BattlePhaseController, UpkeepPhaseManager, BasePostBattlePhase, FiveParsecsPostBattlePhase
- **Data/logic extraction**: CharacterPhasePanel EVENT_TABLE → `src/data/character_events.gd`; EndPhasePanel victory checking → `src/core/victory/VictoryChecker.gd`; sell value formula → EquipmentManager; deployment/terrain inference → DeploymentManager
- **Enum fix (BUG)**: CampaignDashboard used `CampaignPhase` (10 values) with incompatible integer mappings vs `FiveParsecsCampaignPhase` (14 values). e.g., `UPKEEP=2` sent to PhaseManager, read as `STORY=2`. Migrated to correct enum.
- **BattleResolver wiring**: `BattlePhase._simulate_battle_outcome()` now uses `BattleResolver.resolve_battle()` (rules-accurate multi-round combat with per-unit tracking) instead of ad-hoc formula (`crew.size()*5` vs `enemies.size()*4`)
- **Old enum deprecated**: `CampaignPhase` in GlobalEnums.gd marked deprecated (kept for save-format compatibility)

**Key new files**: `src/data/character_events.gd`, `src/core/victory/VictoryChecker.gd`
**Files deleted**: 4 | **Files modified**: ~10 | **Zero compile errors** verified after each sprint

### Core/Compendium Wiring Audit (Feb 9, 2026)
Deep audit of core rules + compendium integration. 8 issues investigated, 6 fixed, 2 confirmed non-issues:
- **CRITICAL**: CampaignDashboard was creating isolated `GameState.new()` instead of using real autoloads. Fixed to `get_node("/root/GameState")`.
- **Phase data pipeline**: Added missing `get_phase_data()` overrides to BattleSetupPhasePanel + BattleResolutionPhasePanel.
- **PsionicManager legality**: Wired `roll_world_legality()` into WorldPhase (DLC-gated, writes to world data).
- **LoanManager**: Fixed API mismatch (`game_state.credits` -> `add_credits()/remove_credits()`). Wired DLC-gated loan UI into TradePhasePanel + loan interest into UpkeepPhasePanel.
- **Compendium names**: Character._generate_name() now delegates to compendium species-specific name tables for non-human origins.
- **Non-issues**: MoraleSystem is stateless (morale on campaign.crew_morale). VictoryConditionTracker is dead code (EndPhasePanel handles victory).

---

## Architecture

### Enum Systems (3 files, must stay in sync)
1. `src/core/systems/GlobalEnums.gd` - autoloaded as `GlobalEnums`
2. `src/core/enums/GameEnums.gd` - class_name `GameEnums`
3. `src/game/campaign/crew/FiveParsecsGameEnums.gd` - CharacterClass only

### Key Autoloads
- GameState, GameStateManager, CampaignPhaseManager
- DiceSystem, SignalBus, KeywordDB, TurnPhaseChecklist
- PlanetDataManager, CampaignJournal, DLCManager
- NPCTracker, LegacySystem, EquipmentManager
- ResponsiveManager, TransitionManager, NotificationManager

### QOL State Persistence (Feb 9, 2026)
All QOL autoloads now persist state through PersistenceService save/load pipeline:
- CampaignJournal (entries, milestones, character histories)
- TurnPhaseChecklist (veteran mode settings)
- NPCTracker (patron/rival/location tracking)
- LegacySystem (hall of fame archives)

### File Count
~441 GDScript files across `src/` directory. Significant consolidation from earlier phases.

---

## Known Minor Items (Not Bugs)
- BattleSetupData/BattleResults use plain Dictionaries (not typed Resource classes)
- Memory leak warnings on quit from phase handler nodes (cosmetic)
- Old `CampaignPhase` enum in GlobalEnums.gd deprecated — 3 files still reference it (Campaign.gd, GameCampaignManager.gd, ValidationManager.gd) for save-format compat; turn loop uses `FiveParsecsCampaignPhase`

---

## Compendium DLC Implementation (Feb 2026): ALL 10 SPRINTS COMPLETE

The Five Parsecs Compendium is implemented as paid DLC gated by DLCManager with 35 ContentFlags across 3 DLC packs. Zero impact on core gameplay when disabled.

### DLC Packs
| Pack | Features | Status |
|------|----------|--------|
| **Trailblazer's Toolkit** | Krag & Skulker species, Psionics, Training, Bot Upgrades, Ship Parts, Psionic Gear | Complete |
| **Freelancer's Handbook** | Progressive Difficulty, Difficulty Toggles, AI Variations, Escalating Battles, Elite Enemies, No-Minis Combat, Grid Movement, PvP/Co-op, Expanded Missions/Quests/Connections | Complete |
| **Fixer's Guidebook** | Stealth Missions, Street Fights, Salvage Jobs, Expanded Factions, World Strife, Loans, Names, Introductory Campaign, Prison Planet | Complete |

### Sprint Summary
- **Sprint 0**: DLC Infrastructure (DLCManager autoload, ContentFlag enum, 3-pack structure)
- **Sprint 1**: Krag & Skulker Species (7 files, enum sync, battle/character wiring)
- **Sprint 2**: Psionics System (legality, enemy powers, PsionicManager rewrite)
- **Sprint 3**: New Kit (compendium_equipment.gd, AdvancementPhasePanel + TradePhasePanel wiring)
- **Sprint 4**: Difficulty + Combat (ProgressiveDifficultyTracker, compendium_difficulty_toggles)
- **Sprint 5**: Stealth Missions (StealthMissionGenerator + StealthMissionPanel)
- **Sprint 6**: Street Fights & Salvage (StreetFightGenerator + SalvageJobGenerator)
- **Sprint 7**: Factions gate + World/Economy (compendium_world_options, FactionSystem DLC gate)
- **Sprint 8**: Expanded Missions/No-Minis/Prison Planet (3 new data files + NoMinisCombatPanel)
- **Sprint 9**: UI Polish (CheatSheet +8 compendium sections, DLCManagementDialog, grid movement ref)

### Key Files
- `src/core/systems/DLCManager.gd` - Autoload singleton, ContentFlag enum, ownership/flag management
- `src/data/compendium_*.gd` - 6 data files with Dictionary-driven tables and static query methods
- `src/core/mission/Stealth|StreetFight|Salvage*.gd` - 3 mission generators
- `src/ui/dialogs/DLCManagementDialog.gd` - DLC ownership and feature toggle UI
- See [Compendium Implementation Guide](gameplay/COMPENDIUM_IMPLEMENTATION.md) for detailed content

### Architecture
- All output follows **tabletop companion** text instruction model
- DLC gating via `DLCManager.is_feature_enabled(ContentFlag.X)` at entry points
- ~15 new files, ~20 modified files, ~5,000 lines added
- Zero compile errors verified after every sprint

---

## 4-Feature Implementation (Feb 2026): ALL 9 SPRINTS COMPLETE

Four major features implemented across 9 sprints:

### Planet Persistence (Sprints 1-3)
- `PlanetDataManager` autoload singleton for per-planet data storage
- Rival location tracking fields on rival data structures
- Phase handler wiring: travel arrival loads planet contacts automatically

### Tactical Grid (Sprint 4)
- Wired existing `BattlefieldGridUI` into `BattleSetupPhasePanel`
- Grid movement reference in cheat sheet (DLC-gated via GRID ContentFlag)

### History/Storytelling (Sprints 5-7)
- Consolidated `CampaignJournal` to autoload (580+ lines, auto-entries from phase handlers)
- New `CharacterHistoryPanel` and `CampaignTimelinePanel` UI components
- Wired into `CampaignDashboard` via overlay pattern

### Import/Export (Sprints 8-9)
- `ExportPanel`: JSON and Markdown export of campaign state
- `ImportPanel`: JSON campaign import with validation
- Both wired into `CampaignDashboard`

### Key Files
- `src/core/world/PlanetDataManager.gd` - Planet persistence autoload
- `src/core/campaign/CampaignJournal.gd` - Journal autoload
- `src/ui/components/history/CharacterHistoryPanel.gd` - Character history UI
- `src/ui/components/history/CampaignTimelinePanel.gd` - Campaign timeline UI
- `src/ui/components/export/ExportPanel.gd` - Export functionality
- `src/ui/components/export/ImportPanel.gd` - Import functionality

---

## UI/UX Optimization (Feb 2026): ALL 7 SPRINTS COMPLETE

Comprehensive design system and mobile-first UI polish across ~50 files.

### Design System
- **UIColors.gd** (`class_name UIColors`, RefCounted): Canonical design token source — Deep Space color palette (10 colors + semantic aliases), spacing system (8px grid), typography scale (11-24px), touch target minimums (48/56px), icon size constants (16-128px)
- **IconRegistry.gd** (`class_name IconRegistry`, RefCounted): Maps game concepts (stats, phases, equipment, missions) to 789 Lorc RPG icon assets with static cache
- **ResponsiveManager** (autoload): Breakpoint detection (MOBILE/TABLET/DESKTOP/WIDE) with signals, layout helpers, font/spacing multipliers

### Sprint Summary
| Sprint | Focus | Files |
|--------|-------|-------|
| 1 | Mobile foundation (stretch mode) + design tokens (UIColors rewrite) | 3 |
| 2 | Icon registry (IconRegistry.gd, ~140 lines) | 1 new |
| 3 | Battle component design system adoption | 13 |
| 4 | Post-battle + campaign component adoption | 12 |
| 5 | Icon integration (CharacterCard portraits, phase icons, stat icons, tooltips) | 5 |
| 6 | Signal leak fixes + ResponsiveManager wiring into battle screens | 6 |
| 7 | Polish pass (batch Color replacement across 33 files) | 33 |

### Key Changes
- `project.godot`: Added `canvas_items` stretch mode + `expand` aspect for mobile auto-scaling; ResponsiveManager autoload
- 25 battle/campaign components migrated from local COLOR constants to UIColors.X
- 33 files batch-updated: bare `Color.RED/GREEN/CYAN/YELLOW/ORANGE` replaced with UIColors semantic equivalents
- `Color.WHITE` selectively triaged: ~20 font_color overrides converted to `UIColors.COLOR_TEXT_PRIMARY`; ~65 remaining are modulate resets, draw calls, and accessibility contrast (correctly left as literal white)
- Signal leaks fixed: AccessibilityManager timer, TooltipManager tween cleanup
- Battle screens (BattleCompanionUI, BattleDashboardUI) now responsive via ResponsiveManager

---

## UI/UX Integration Audit (Feb 9, 2026): ALL 8 SPRINTS COMPLETE

Follow-up audit of the UI/UX overhaul to close integration gaps, register missing autoloads, and extend design token coverage.

### Sprint Summary
| Sprint | Focus | Impact |
|--------|-------|--------|
| 1 | Register TransitionManager + NotificationManager autoloads in project.godot | CRITICAL — activated 2 dead autoloads, 3 existing consumers now work |
| 2+3 | UIColors integration for both autoloads + _exit_tree() tween cleanup | HIGH — design consistency + memory safety |
| 4 | Color.PURPLE + Color.GRAY → UIColors (~32 replacements across ~19 files) | MEDIUM — completed color token migration |
| 5 | Color.WHITE triage — converted ~20 font_color uses, preserved ~65 modulate/draw | MEDIUM — selective, safe conversion |
| 6 | Inline Color(0.x...) extraction to UIColors (~37 replacements across 12 files) | MEDIUM — eliminated hardcoded RGB in UI code |
| 7 | Data integrity spot check (zero color comparisons, all preloads valid, persistence intact) | HIGH — verified no regressions |
| 8 | Documentation updates | LOW — accuracy |

### Key Changes
- **TransitionManager** (`src/autoload/TransitionManager.gd`): CanvasLayer (layer=100) for scene fade overlays, now registered as autoload, colors use UIColors tokens, _exit_tree() cleanup
- **NotificationManager** (`src/autoload/NotificationManager.gd`): CanvasLayer (layer=90) for toast notifications, now registered as autoload, COLORS dict uses UIColors tokens, _exit_tree() cleanup
- **~45 files modified** across Sprints 4-6 for extended color token coverage
- **Zero color comparison operations** found in codebase (safe to use UIColors tokens with different hex values)

---

- **279 -> ~240 markdown files** in docs/ (39 archived/deleted)
- **0 stale references** in active docs (Godot version, test framework, user paths all current)
- **~140 files** in docs/archive/ (historical reference)
- **Documentation Index**: [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)

---

## Migration History
- **Nov 2025**: Initial development on Godot 4.4/4.5
- **Feb 6, 2026**: Migrated to Godot 4.6-stable
- **Feb 7, 2026**: Fixed ~150+ compile errors from migration, 4-phase fix process
- **Feb 7-8, 2026**: 10 campaign turn sprints + 8 battle phase manager sprints
- **Feb 8, 2026**: All tech debt cleared, documentation audit complete
- **Feb 8, 2026**: Compendium DLC implementation (10 sprints, ~5,000 lines, 3 DLC packs)
- **Feb 8, 2026**: 4-Feature Implementation (planet persistence, tactical grid, history/storytelling, import/export)
- **Feb 9, 2026**: Tech Debt + Feature Gaps audit and fix (12 sprints):
  - Bug fix: COMBAT_REFLEX implant typo
  - Wired 5 dormant systems: PatronSystem, FactionSystem, StoryTrackSystem, KeywordSystem, LegacySystem
  - Wired 3 mission generators into WorldPhase pipeline
  - Properly gated 6 DLC ContentFlags in BattlePhase (ELITE_ENEMIES, NO_MINIS, GRID, SPECIES)
  - Fixed brawling weapon_traits derivation
  - New EquipmentComparisonPanel UI component
  - Replaced 3 WorldPhase TODO stubs with real implementations
- **Feb 9, 2026**: Stub/TODO Flesh-Out sprints (11 sprints, ~400 lines changed):
  - Sprint 0: Patched WorldPhase null check bug, double-call safe wrappers, TravelPhase state mutations
  - Sprint 1: Deleted 9 zero-byte files + dead FactionManager stub
  - Sprint 2: Upgraded NPCTracker autoload (37→192 lines, Dictionary tracking, serialize/deserialize)
  - Sprint 3: Upgraded LegacySystem autoload (18→111 lines, archive, legacy bonus, serialize/deserialize)
  - Sprint 4: CharacterInventory armor/items serialization (was empty TODO)
  - Sprint 5: Wired CampaignManager item rewards (was `pass` TODO)
  - Sprint 6: Wired StoryPhasePanel to EventManager (8 story events, real GameState API)
  - Sprint 7: Implemented AutomationSettingsPanel options + AccessibilityManager focus indicator
  - Sprint 8: Wired BattleSetupWizard to EnemyGenerator + GameState crew size
  - Sprint 9: Fixed TurnPhaseChecklist autoload path, wired 4 QOL autoloads into PersistenceService save/load
  - Sprint 10: Populated world_traits.json (16 traits), fixed 5 path constants across 3 data manager files
- **Feb 9, 2026**: UI/UX Optimization (7 sprints, ~50 files):
  - Design system: UIColors.gd canonical tokens (colors, spacing, typography, touch targets, icon sizes)
  - Icon registry: IconRegistry.gd mapping game concepts to 789 Lorc RPG icons
  - Mobile foundation: canvas_items stretch mode, ResponsiveManager autoload wired into battle screens
  - Migrated 25 battle/campaign components from local COLOR constants to UIColors.X
  - Batch replaced 202 bare Color.XX across 33 .gd files with semantic UIColors equivalents
  - Signal leak fixes: AccessibilityManager timer, TooltipManager tween cleanup
  - Icon integration: CharacterCard portraits, phase indicators, stat displays, button tooltips
- **Feb 9, 2026**: UI/UX Integration Audit (8 sprints):
  - Registered TransitionManager + NotificationManager autoloads (were implemented but never registered)
  - UIColors integration + _exit_tree() cleanup for both new autoloads
  - Extended color token coverage: Color.PURPLE, Color.GRAY, Color.WHITE (selective), inline Color() → UIColors (~90 total replacements across ~45 files)
  - Data integrity verified: zero color comparisons, all preloads valid, persistence intact
- **Feb 9, 2026**: Scene Routing & Navigation (3 sprints):
  - Migrated 20 hardcoded change_scene_to_file() calls to SceneRouter across 12 files
  - Added back buttons to WorldPhaseSummary + SaveLoadUI (PatronRivalManager already had one)
  - Added per-turn auto-save in CampaignPhaseManager (turn_N_autosave via PersistenceService)
  - Prerequisite audit: fixed 4 broken SceneRouter paths, deleted 43 dead files
- **Feb 20, 2026**: Script Consolidation — Phase 5 (9 sprints):
  - Sprint 5.1: Deleted 4 dead code files (~545 lines): BattlePhaseController, UpkeepPhaseManager, BasePostBattlePhase, FiveParsecsPostBattlePhase
  - Sprint 5.2: Extracted CharacterPhasePanel EVENT_TABLE to `src/data/character_events.gd` (data/logic separation)
  - Sprint 5.3: Fixed CampaignDashboard stale enum — migrated from CampaignPhase (10 values) to FiveParsecsCampaignPhase (14 values). Integer values were incompatible (e.g., UPKEEP=2 mapped to STORY=2)
  - Sprint 5.4: Extracted 100-line victory checking logic from EndPhasePanel to `src/core/victory/VictoryChecker.gd` (18 victory types)
  - Sprint 5.5: Deprecated old CampaignPhase enum in GlobalEnums.gd (kept for save-format compat)
  - Sprint 5.6: Extracted sell value formula to EquipmentManager.get_sell_value() (condition-aware 50% resale)
  - Sprint 5.7: Extracted deployment/terrain inference from BattleSetupPhasePanel to DeploymentManager static methods
  - Sprint 5.8: Wired BattleResolver.resolve_battle() into BattlePhase._simulate_battle_outcome() — replaces ad-hoc formula with rules-accurate multi-round combat simulation
  - Sprint 5.9: Documentation updates
- **Feb 28, 2026**: World→Battle Data Flow — Phase 21 (3 sub-phases):
  - Phase 21.6: Fixed 11+ files treating FiveParsecsCampaignCore (Resource) as Dictionary — bracket assignment silently fails
  - Phase 21.7: Fixed crew task result propagation — job offers refresh, rumors auto-complete, world phase results persist via progress_data
  - Phase 21.8: Fixed mission prep empty data, duplicate battle buttons, battle transition method name mismatch (set_mission_data → show_mission_briefing)
  - Added get_current_mission() to FiveParsecsCampaignCore, _refresh_mission_prep() to WorldPhaseController
  - Archived 11 stale root-level docs + 7 stale directories to docs/archive/
- **Feb 28, 2026**: Equipment Pipeline + Mission Prep + PreBattle — Phase 22 (4 sprints):
  - Fixed systemic equipment_data key mismatch: 5 files read `"pool"` but FiveParsecsCampaignCore stores under `"equipment"` — all corrected
  - Uncommented Character.to_dictionary() — added dual key aliases (`"id"`/`"character_id"`, `"name"`/`"character_name"`) for all consumers
  - Fixed PreBattleUI method mismatch: CampaignTurnController called non-existent `initialize_battle()` → now calls `setup_preview()`
  - Added terrain setup guide generation for tabletop text-based terrain suggestions
  - Files changed: Character.gd, WorldPhaseController.gd, MissionPrepComponent.gd, PostBattleSequence.gd, TradePhasePanel.gd, CharacterDetailsScreen.gd, CampaignTurnController.gd
- **Feb 28, 2026**: Battle Companion UI — Phase 22I-J:
  - **Phase 22I**: Created BattlefieldGridPanel.gd (~380 lines) — 4x4 sector grid with terrain generation from compendium_terrain.json themes (industrial_zone, wilderness, alien_ruin, crash_site)
  - **Phase 22I**: Removed dead DeploymentPanel from PreBattle.tscn/PreBattleUI.gd, cleaned up PreBattle flow
  - **Phase 22J**: Fixed right sidebar tool overlap — removed absolute positioning artifacts from CombatSituationPanel.tscn, removed EXPAND_FILL vertical flags from DiceDashboard.tscn and CombatCalculator.tscn
  - **Phase 22J**: Upgraded battlefield grid from text-only Labels to visual canvas-drawn terrain shapes using Godot's `_draw()` API — 11 shape types (buildings, walls, rocks, hills, trees, water, containers, crystals, hazards, debris, scatter) with keyword classification from terrain feature text
