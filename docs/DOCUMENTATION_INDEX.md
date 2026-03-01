# Five Parsecs Campaign Manager - Documentation Index

**Last Updated**: February 28, 2026
**Engine**: Godot 4.6-stable (pure GDScript)
**Test Framework**: gdUnit4 v6.0.3

---

## Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Developer setup and onboarding
- **[Project Status](PROJECT_STATUS_2026.md)** - Current state (Feb 2026)
- **[README](README.md)** - Main documentation hub

## Core Game Documentation
- **[Game Mechanics Implementation Map](GAME_MECHANICS_IMPLEMENTATION_MAP.md)** - 100% compliance (170/170 incl. Compendium)
- **[Core Rules](core_rules.md)** - Core rulebook reference
- **[Compendium](compendium.md)** - Expansion content reference
- **[Implants System](IMPLANTS_SYSTEM_IMPLEMENTATION.md)** - Implant types and pipeline
- **[Data File Reference](DATA_FILE_REFERENCE.md)** - Game data files
- **[Event Effects Reference](EVENT_EFFECTS_REFERENCE.md)** - Campaign/character events
- **[Data Contracts](DATA_CONTRACTS.md)** - Data structure contracts

## Gameplay Documentation
- **[Official Campaign Rules](gameplay/OFFICIAL_CAMPAIGN_RULES_IMPLEMENTATION.md)** - 9-phase campaign turn
- **[Rules Implementation Guide](gameplay/RULES_IMPLEMENTATION_GUIDE.md)** - Tabletop-to-digital mapping
- **[Compendium Implementation](gameplay/COMPENDIUM_IMPLEMENTATION.md)** - Expansion content guide
- **[Compendium Roadmap](features/COMPENDIUM_ROADMAP.md)** - Historical planning doc (all 10 sprints complete)
- **[Dice System Guide](gameplay/DICE_SYSTEM_GUIDE.md)** - Random number generation
- **[Victory Conditions](gameplay/VICTORY_CONDITIONS.md)** - 21 victory types
- **[Rules-Based File Budget](gameplay/RULES_BASED_FILE_BUDGET.md)** - Architecture constraints
- **[QoL Features](gameplay/qol/)** - Quality of life features (9 docs)
  - **[Campaign Journal](gameplay/qol/Campaign_Journal.md)** - Journal, timeline, history (IMPLEMENTED)

## Technical Documentation
- **[Architecture Guide](technical/ARCHITECTURE.md)** - System design and patterns
- **[Data Architecture](technical/data_architecture.md)** - Data flow and storage
- **[Data Model & Save System](technical/DATA_MODEL_AND_SAVE_SYSTEM.md)** - Persistence layer
- **[System Architecture Deep Dive](technical/SYSTEM_ARCHITECTURE_DEEP_DIVE.md)** - Detailed systems
- **[Battle HUD Signal Architecture](technical/BATTLE_HUD_SIGNAL_ARCHITECTURE.md)** - Signal patterns

## Development
- **[Core Rules Compliance Report](development/core_rules_compliance_report.md)** - 11/11 systems verified
- **[Development Implementation Guide](development/DEVELOPMENT_IMPLEMENTATION_GUIDE.md)** - Dev workflow
- **[Codebase Cleanup List](development/CODEBASE_CLEANUP_LIST.md)** - Cleanup tracking

## Testing
- **[Testing Guide](../tests/TESTING_GUIDE.md)** - gdUnit4 test methodology

## Design
- **[UI Overview](design/ui_overview.md)** - User interface design
- **[Battlefield Data Schema](design/BATTLEFIELD_DATA_SCHEMA.md)** - Battlefield generation
- **[Portrait System Guide](design/PORTRAIT_SYSTEM_GUIDE.md)** - Character portraits
- **[Accessibility](design/accessibility_automation.md)** - A11y implementation
- **[Visual Fidelity Options](design/visual_fidelity_options.md)** - Graphics settings
- **[UIColors](../src/ui/components/base/UIColors.gd)** - Canonical design tokens (Deep Space theme, spacing, typography, touch targets)
- **[IconRegistry](../src/ui/components/base/IconRegistry.gd)** - Game concept → Lorc RPG icon mapping with static cache
- **[ResponsiveManager](../src/autoload/ResponsiveManager.gd)** - Breakpoint detection autoload (MOBILE/TABLET/DESKTOP/WIDE)

## Systems (Implemented February 2026)
- **[Galactic War System](features/GALACTIC_WAR_SYSTEM.md)** - 4 war tracks with faction conflicts
- **[DLC/Compendium System](features/COMPENDIUM_ROADMAP.md)** - 35 ContentFlags across 3 DLC packs
  - DLCManager autoload, 6 compendium data files, DLCManagementDialog UI
- **[Battle Phase Manager](../src/core/battle/)** - Three-tier tracking (LOG_ONLY / ASSISTED / FULL_ORACLE)
- **[Planet Persistence](../src/core/world/PlanetDataManager.gd)** - PlanetDataManager autoload, per-planet contacts
- **[Campaign Journal](../src/core/campaign/CampaignJournal.gd)** - Autoloaded journal with auto-entries, timeline, export
- **[Morale System](../src/core/systems/MoraleSystem.gd)** - 0-100 crew morale with post-battle effects
- **[Import/Export](../src/ui/components/export/)** - ExportPanel + ImportPanel (JSON/Markdown)
- **[History/Timeline UI](../src/ui/components/history/)** - CharacterHistoryPanel + CampaignTimelinePanel
- **[PatronSystem](../src/core/systems/PatronSystem.gd)** - Job generation (WorldPhase) + completion (PostBattlePhase)
- **[FactionSystem](../src/core/systems/FactionSystem.gd)** - Rival reputation + faction missions
- **[Equipment Comparison](../src/ui/components/inventory/EquipmentComparisonPanel.gd)** - Side-by-side stat comparison in TradePhasePanel
- **[StoryTrackSystem](../src/core/story/)** - DLC-gated 6-tick story clock with evidence collection
- **[KeywordSystem](../src/qol/KeywordSystem.gd)** - Enriches story events with keyword matches
- **[LegacySystem](../src/core/campaign/LegacySystem.gd)** - Archives campaigns on victory, legacy bonus on new campaigns (upgraded Feb 9)
- **[NPCTracker](../src/core/campaign/NPCTracker.gd)** - Patron/rival/location tracking with relationships and serialize/deserialize (upgraded Feb 9)
- **[BattleSetupWizard](../src/qol/BattleSetupWizard.gd)** - One-click battle generation from EnemyGenerator + crew data (wired Feb 9)
- **[QOL Persistence](../src/core/services/PersistenceService.gd)** - Save/load pipeline for QOL autoloads (CampaignJournal, TurnPhaseChecklist, NPCTracker, LegacySystem)
- **[Accessibility](../src/ui/accessibility/AccessibilityManager.gd)** - Focus indicator, automation settings panel
- **[Scene Routing & Navigation](../src/ui/screens/SceneRouter.gd)** - All screen transitions via SceneRouter (36 registered scenes, navigation history, back buttons, per-turn auto-save)
- **[VictoryChecker](../src/core/victory/VictoryChecker.gd)** - Centralized victory condition checking (18 types), extracted from EndPhasePanel (Phase 5)
- **[Character Events Data](../src/data/character_events.gd)** - Character phase event table with weighted random selection, extracted from CharacterPhasePanel (Phase 5)

## Features (Specs)
- **[Features Directory](features/)** - Feature specifications organized by system:
  - bug_hunt/, campaign/, combat/, difficulty/, enemy/, missions/, psionics/, species/, world/
  - Galactic War, DLC Gating, Character Creation, Combat System, Compendium Roadmap

## Release & Deployment
- **[Deployment Guide](releases/DEPLOYMENT_GUIDE.md)** - Production deployment
- **[Deployment Checklist](releases/DEPLOYMENT_CHECKLIST.md)** - Pre-release checks
- **[Build & Versioning](releases/build_and_versioning_process.md)** - Version management
- **[Multi-Platform Release](releases/multi_platform_release_checklist.md)** - Platform support

## Modding
- **[Content Creation Guide](modding/CONTENT_CREATION_GUIDE.md)** - Modding documentation

## Archived Documentation
Located in `docs/archive/` (~160 files) - Historical reference from earlier development phases.
Includes: GUT guides, Godot mastery references, premature deployment/marketing/legal docs, player guide, support plans.
