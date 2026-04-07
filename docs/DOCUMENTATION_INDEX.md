# Five Parsecs Campaign Manager - Documentation Index

**Last Updated**: April 7, 2026
**Engine**: Godot 4.6-stable (pure GDScript)
**Test Framework**: gdUnit4 v6.0.3

---

## Root Documents (Start Here)

- **[Project Status](PROJECT_STATUS_2026.md)** - Current state, completed phases, risk areas
- **[Quick Start Guide](QUICK_START.md)** - Developer setup and onboarding
- **[Game Mechanics Map](GAME_MECHANICS_IMPLEMENTATION_MAP.md)** - 100% compliance (170/170)
- **[QA Status Dashboard](QA_STATUS_DASHBOARD.md)** - Consolidated QA health overview
- **[QA Rules Accuracy Audit](QA_RULES_ACCURACY_AUDIT.md)** - Master data verification (925 values)
- **[Core Rules](core_rules.md)** / **[Compendium](compendium.md)** - Digitized rulebook references

## Technical Architecture (`technical/`)

- **[Architecture Guide](technical/ARCHITECTURE.md)** - System design and coordinator patterns
- **[Battle System Architecture](technical/BATTLE_SYSTEM_ARCHITECTURE.md)** - Battle state machine, resolver
- **[Tactical Battle UI Architecture](technical/TACTICAL_BATTLE_UI_ARCHITECTURE.md)** - TacticalBattleUI deep dive
- **[Battle HUD Signal Architecture](technical/BATTLE_HUD_SIGNAL_ARCHITECTURE.md)** - Signal patterns
- **[Data Architecture](technical/data_architecture.md)** - Data flow and storage
- **[Data Model & Save System](technical/DATA_MODEL_AND_SAVE_SYSTEM.md)** - Persistence layer
- **[System Architecture Deep Dive](technical/SYSTEM_ARCHITECTURE_DEEP_DIVE.md)** - Detailed systems
- **[Data Flow Consistency Tracker](technical/DATA_FLOW_CONSISTENCY_TRACKER.md)** - Data flow audit (45 issues, all resolved)
- **[Data File Reference](technical/DATA_FILE_REFERENCE.md)** - Game data files catalog
- **[Data Contracts](technical/DATA_CONTRACTS.md)** - Data structure contracts
- **[Screen Map](technical/SCREEN_MAP.md)** - Scene/screen inventory
- **[Codebase Optimization Audit](technical/CODEBASE_OPTIMIZATION_AUDIT.md)** - Optimization opportunities
- **[Connection Validation Template](technical/UNIVERSAL_CONNECTION_VALIDATION_TEMPLATE.md)** - Signal validation patterns

## Testing & QA (`testing/`)

- **[Testing Guide](../tests/TESTING_GUIDE.md)** - gdUnit4 test methodology
- **[Demo QA Script](testing/DEMO_QA_SCRIPT.md)** - Demo recording QA gate
- **[UX/UI Test Plan](testing/QA_UX_UI_TEST_PLAN.md)** - Systematic UI coverage
- **[Integration Scenarios](testing/QA_INTEGRATION_SCENARIOS.md)** - 10 end-to-end workflow test scripts
- **[Playtesting Strategy](testing/EFFICIENT_PLAYTESTING_STRATEGY.md)** - Testing methodology
- **[Sprint T1 Results](testing/SPRINT_T1_RESULTS.md)** - Sprint test results
- **[Battle Companion QA Sprint](testing/BATTLE_COMPANION_QA_SPRINT.md)** - 4 sprints of battle UI overhaul
- **[Battle UI Component Audit](testing/BATTLE_UI_COMPONENT_AUDIT.md)** - 28 user-facing components
- **[Battle UI QA Bugs](testing/BATTLE_UI_QA_BUGS.md)** - Battle-specific bug tracker
- **[UIUX Test Results](testing/UIUX_TEST_RESULTS.md)** - MCP automated: 71 bugs found & fixed

## Gameplay Documentation (`gameplay/`)

- **[Official Campaign Rules](gameplay/OFFICIAL_CAMPAIGN_RULES_IMPLEMENTATION.md)** - 9-phase campaign turn
- **[Rules Implementation Guide](gameplay/RULES_IMPLEMENTATION_GUIDE.md)** - Tabletop-to-digital mapping
- **[Compendium Implementation](gameplay/COMPENDIUM_IMPLEMENTATION.md)** - Expansion content guide
- **[Dice System Guide](gameplay/DICE_SYSTEM_GUIDE.md)** - Random number generation
- **[Victory Conditions](gameplay/VICTORY_CONDITIONS.md)** - 21 victory types
- **[Event Effects Reference](gameplay/EVENT_EFFECTS_REFERENCE.md)** - Campaign/character events
- **[QoL Features](gameplay/qol/)** - QOL roadmap, Campaign Journal, Keyword System

## Design (`design/`)

- **[UI Overview](design/ui_overview.md)** - Design tokens, Deep Space palette
- **[UI/UX Component Guide](design/UI_UX_COMPONENT_GUIDE.md)** - Component patterns
- **[Battlefield Data Schema](design/BATTLEFIELD_DATA_SCHEMA.md)** - Battlefield generation
- **[Battlefield Visualization](design/battlefield_visualization.md)** - Tactical grid rendering
- **[Portrait System](design/PORTRAIT_SYSTEM_GUIDE.md)** - Character portraits
- **[Accessibility](design/accessibility_automation.md)** - A11y implementation
- **[Visual Fidelity Options](design/visual_fidelity_options.md)** - Graphics settings

## Features (`features/`)

- **[Implants System](features/IMPLANTS_SYSTEM_IMPLEMENTATION.md)** - Implant types and pipeline
- **[DLC Gating](features/dlc_gating_mechanism.md)** / **[Compendium Roadmap](features/COMPENDIUM_ROADMAP.md)**
- **[Galactic War](features/GALACTIC_WAR_SYSTEM.md)** / **[Character Creation](features/character_creation.md)**
- Subdirectories: `bug_hunt/`, `campaign/`, `combat/`, `difficulty/`, `enemy/`, `missions/`, `psionics/`, `species/`, `world/`

## UI Components (`ui/`)

- **[Character Card Spec](ui/CHARACTER_CARD_COMPONENT_SPEC.md)** - 3 visual variants
- **[Galactic War UI Mockup](ui/GALACTIC_WAR_UI_MOCKUP.md)** - End-game UI
- **[UX Design Analysis](falloutappscreenshots/five-parsecs-ux-design-analysis.md)** - Fallout companion app analysis + adoption checklist (65 screenshots)

## Development (`development/`)

- **[Core Rules Compliance Report](development/core_rules_compliance_report.md)** - 11/11 systems verified
- **[Development Guide](development/DEVELOPMENT_IMPLEMENTATION_GUIDE.md)** - Dev workflow
- **[MCP Setup](development/MCP_Setup_Summary.md)** - MCP integration

## Legal & Partnership

- **[Modiphius Ask List](MODIPHIUS_ASK_LIST.md)** - Partnership blockers, asset needs, monetization, multi-IP vision
- **[Modiphius Progress Demo](MODIPHIUS_PROGRESS_DEMO.md)** - Demo walkthrough for Modiphius pitch
- **[Store Submission Checklist](legal/STORE_SUBMISSION_CHECKLIST.md)** - Pre-filled Data Safety + Nutrition Label answers
- **[Steam Research](archive/modiphius-steam-research.md)** - Modiphius digital platform analysis
- Legal documents: `data/legal/eula.md`, `privacy_policy.md`, `third_party_licenses.md`, `credits.md`
- GitHub Pages: `docs/legal/gh-pages/` (privacy.html, eula.html, index.html)

## Other

- **[User Guide](user_guide/00_index.md)** - 16-chapter player guide
- **[Modding Guide](modding/CONTENT_CREATION_GUIDE.md)** - Custom content creation
- **[Release & Deployment](releases/)** - Deployment guide, checklists, versioning
- **[Rules PDFs](rules/)** - Core Rules + Compendium source material

## Agent Architecture

- **[Agent Roster](../.claude/skills/fpcm-project-management/references/agent-roster.md)** - 7 agents with Haiku/Sonnet/Opus tiers
- **[Task Decomposition](../.claude/skills/fpcm-project-management/references/task-decomposition.md)** - Dependency order

## Archived (`archive/`)

Historical reference: QA sprint phases 29-32, test plans, verification reports, stale development files, QOL stubs, legacy docs.
