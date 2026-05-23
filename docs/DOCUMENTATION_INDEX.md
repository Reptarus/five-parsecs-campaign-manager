# Five Parsecs Campaign Manager - Documentation Index

**Last Updated**: May 1, 2026 (added Alpha-1 docs section + Modiphius Apr 29 followups)
**Engine**: Godot 4.6-stable (pure GDScript)
**Test Framework**: gdUnit4 v6.0.3

---

## Root Documents (Start Here)

- **[Project Status](PROJECT_STATUS_2026.md)** - Current state, completed phases, risk areas
- **[Quick Start Guide](QUICK_START.md)** - Developer setup and onboarding
- **[Game Mechanics Map](GAME_MECHANICS_IMPLEMENTATION_MAP.md)** - 100% compliance (170/170)
- **[QA Status Dashboard](QA_STATUS_DASHBOARD.md)** - Consolidated QA health overview
- **[QA Rules Accuracy Audit](QA_RULES_ACCURACY_AUDIT.md)** - Master data verification (925 values)
- **[QOL Feature Candidates](QOL_FEATURE_CANDIDATES.md)** - Product backlog of 10 QOL items from May 22 fiveparsecs.online audit; per-item depth analysis, sequencing, sprint shapes. **Sprints 1+2 shipped 2026-05-22** (Shape A items 1, 2, 4, 5, 7 + Shape S2-A F1, F2, F3, Item 6, Item 9; commit 839524c6, 35 gdUnit4 tests). **RulesPopup popup-race hotfix shipped 2026-05-23**. See Sprint 3 Candidates section for remaining items.
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

## Partnership / Modiphius (Phase A)

### Strategic + Forecast Documents

- **[Modiphius Digital Forecast](MODIPHIUS_DIGITAL_FORECAST.md)** - Plug-in financial forecast model, 50/50 baseline (superseded by May 5 deal proposal — see correspondence journal), §11 industry research with 30+ sources
- **[Modiphius Forecast Summary](MODIPHIUS_FORECAST_SUMMARY.md)** - 1-page summary delivered to Chris/Gavin May 1, 2026
- **[Upfront Investment Transparency](UPFRONT_INVESTMENT_TRANSPARENCY.md)** - WORKING DRAFT — operating floor + Tier 1 Mac/iOS hardware expansion lever (Mac Mini M4 base $799 + Apple Dev $99/yr + used iPhone $300 = ~$1,200 total) with workload-matched rationale (desktop-first + Claude Code as foundation), ROI math + deal-mechanics framing (MG / threshold / upfront). Updated May 5 to align with Chris's MG + threshold reproposal email.
- **[Modiphius Ask List](MODIPHIUS_ASK_LIST.md)** - Legal + publishing blockers requiring Modiphius input
- **[Modiphius Progress Demo](MODIPHIUS_PROGRESS_DEMO.md)** - Build demo notes for Modiphius

### Research Documents (citation-anchored, for negotiation use)

- **[Partnership Deal Structure Research](PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md)** - Industry research on MG + threshold rev share deals, scaling across projects, licensed IP cap-table mechanics, multi-SKU platform deals (~30 sources, claim-level verification status)
- **[Zombicide TTS Precedent Research](ZOMBICIDE_TTS_PRECEDENT_RESEARCH.md)** - CMON Tabletop Simulator playbook research, official DLC + Kickstarter demo pattern, audience scale comparison vs Steam (~16 sources, claim-level verification status)

### Meeting + Correspondence Records

- **[Modiphius Correspondence Journal](MODIPHIUS_CORRESPONDENCE_JOURNAL.md)** - Chronological touchpoint log with verbatim email excerpts (independent backup of email archive)
- **[Apr 16 Meeting Notes](MEETING_NOTES_2026-04-16.md)** - Initial pitch / vision alignment with Chris Birch + Gavin
- **[Apr 29 Meeting Followups](MEETING_FOLLOWUPS_2026-04-29.md)** - Strategic theses (T1-T4), Modiphius asks queue, response tracking

## Closed Alpha (Phase B, May 25 → Jul 6, 2026)

### Strategic + Tester-Facing

- **[Closed Alpha Plan](CLOSED_ALPHA_PLAN.md)** - Master alpha execution plan (cohort, cadence, gates, comms)
- **[Alpha-1 QA Plan](testing/ALPHA_1_QA_PLAN.md)** - Strategic scope (Core + Compendium DLC only) + 5 alpha-specific scenarios + A0 smoke + graduation gate measurement
- **[Alpha Tester Onboarding](testing/ALPHA_TESTER_ONBOARDING.md)** - 1-pager that ships with the build (install, SmartScreen, Discord channels, bug template, telemetry, FAQ)
- **[Pricing Research Plan](PRICING_RESEARCH_PLAN.md)** - Van Westendorp + Gabor-Granger methodology, Prolific n=200 paid survey
- **[Apr 29 Meeting Followups](MEETING_FOLLOWUPS_2026-04-29.md)** - Strategic theses (T1-T4), Modiphius asks queue, response tracking

### Operational QA Documentation Suite (added May 1, 2026)

- **[Alpha-1 Test Plan](testing/ALPHA_1_TEST_PLAN.md)** - IEEE 829-style formal test plan (test items, features tested/not tested, approach, pass/fail criteria, suspension/resumption, deliverables, schedule, responsibilities, risks, approvals)
- **[Alpha-1 Entry & Exit Criteria](testing/ALPHA_1_ENTRY_EXIT_CRITERIA.md)** - Formal binary gates (5 entry gates EG1-EG5, 6 per-build gates PB-G1 through PB-G6, suspension/resumption requirements)
- **[Alpha-1 Regression Checklist](testing/ALPHA_1_REGRESSION_CHECKLIST.md)** - Per-build mandatory sweep (~60 min, 12 sections, must pass before each weekly build ships)
- **[Alpha-1 Traceability Matrix](testing/ALPHA_1_TRACEABILITY_MATRIX.md)** - Feature → Scenario → Test Case → Gate → Thesis mapping (forward + reverse trace)
- **[Defects Log](testing/DEFECTS_LOG.md)** - Live bug tracker with schema, severity tiers (P0-P3), per-build trend, 3 demonstration seed entries

### Reusable QA Templates (`testing/templates/`)

- **[Test Case Template](testing/templates/TEST_CASE_TEMPLATE.md)** - Standardized format for individual test cases (objective, preconditions, steps, acceptance criteria, MCP automation hook)
- **[Bug Report Template](testing/templates/BUG_REPORT_TEMPLATE.md)** - Formal bug report (vs lightweight Discord intake), full lifecycle states, severity + priority guidance
- **[Test Execution Report Template](testing/templates/TEST_EXECUTION_REPORT_TEMPLATE.md)** - Per-build report (execution summary, scenario coverage, regression sweep results, telemetry snapshot, recommendations)
- **[Test Summary Report Template](testing/templates/TEST_SUMMARY_REPORT_TEMPLATE.md)** - End-of-cycle synthesis (cycle objectives, graduation gates, pricing synthesis, category-perception findings, conversion mechanism findings, what worked / didn't, recommended next-cycle scope)

### Workback

- **Alpha readiness workback**: `C:\Users\admin\.claude\plans\warm-weaving-llama.md` (Phase 0 + Phase 0.5 + Phase 1-3 task IDs)

## Testing & QA (`testing/`)

- **[Testing Guide](../tests/TESTING_GUIDE.md)** - gdUnit4 test methodology
- **[Demo QA Script](testing/DEMO_QA_SCRIPT.md)** - Demo recording QA gate
- **[Battle UI Redesign](testing/BATTLE_UI_REDESIGN.md)** - Map-Primary + Drawers design-spec, element→zone→tier map, Core Rules anchoring, per-figure bookkeeping wiring (durable QA reference for the shared `TacticalBattleUI`)
- **[UX/UI Test Plan](testing/QA_UX_UI_TEST_PLAN.md)** - Systematic UI coverage
- **[Integration Scenarios](testing/QA_INTEGRATION_SCENARIOS.md)** - 10 end-to-end workflow test scripts (S11-S15 alpha-1 specific)
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
