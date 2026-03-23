---
name: campaign-systems
description: "Use this skill when working with campaign creation (7-phase wizard), campaign turns (9-phase loop), save/load persistence, state management, or campaign dashboard UI. Covers CampaignPhaseManager, CampaignCreationCoordinator, GameState, GameStateManager, CampaignJournal, TurnPhaseChecklist, CampaignDashboard, CampaignCreationUI, and all campaign phase panels."
---

# Campaign Systems

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/campaign-creation-flow.md` | 7-phase coordinator pattern, CampaignCreationStateManager API, panel signal adapters, step validation |
| `references/campaign-turn-phases.md` | 9-phase turn loop, CampaignPhaseManager signals, phase panel completion contracts, data handoff |
| `references/save-load-persistence.md` | GameState save/load methods, campaign JSON schema, FiveParsecsCampaignCore Resource gotchas |
| `references/autoload-contracts.md` | CampaignPhaseManager, GameState, GameStateManager, CampaignJournal, TurnPhaseChecklist — signal lists and public APIs |

## Quick Decision Tree

- **Campaign creation wizard** → Read `campaign-creation-flow.md`
- **Campaign turn transitions** → Read `campaign-turn-phases.md`
- **Save/load bugs** → Read `save-load-persistence.md`
- **Autoload API questions** → Read `autoload-contracts.md`
- **Phase checklist changes** → Read `autoload-contracts.md` (TurnPhaseChecklist section)
- **Dashboard UI issues** → Read `campaign-turn-phases.md` + `autoload-contracts.md`

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/core/campaign/CampaignPhaseManager.gd` | Autoload | Turn phase orchestration (9 phases) |
| `src/core/state/GameState.gd` | Autoload | Campaign state + save/load |
| `src/core/managers/GameStateManager.gd` | Autoload | State mutation + inter-screen temp data |
| `src/ui/screens/campaign/CampaignCreationCoordinator.gd` | `CampaignCreationCoordinator` | 7-phase wizard orchestration |
| `src/ui/screens/campaign/CampaignCreationUI.gd` | Control | Thin shell wiring panels to coordinator |
| `src/ui/screens/campaign/CampaignDashboard.gd` | `CampaignScreenBase` | Main campaign hub UI |
| `src/core/campaign/CampaignJournal.gd` | Autoload | Auto-entries, timeline, character histories |
| `src/qol/TurnPhaseChecklist.gd` | Autoload | Phase completion tracking (required/optional actions) |

## Campaign Creation Phases (7)

| Step | Phase | Panel | Key Data |
|------|-------|-------|----------|
| 0 | CONFIG | ExpandedConfigPanel | Difficulty, story track, victory conditions |
| 1 | CAPTAIN_CREATION | CaptainPanel + CharacterCreator | Main character |
| 2 | CREW_SETUP | CrewPanel | 3-5 crew members |
| 3 | EQUIPMENT_GENERATION | EquipmentPanel | Loadout |
| 4 | SHIP_ASSIGNMENT | ShipPanel | Ship selection |
| 5 | WORLD_GENERATION | WorldInfoPanel | Planet/homeworld |
| 6 | FINAL_REVIEW | FinalPanel | Validation + finalize |

## Campaign Turn Phases (9)

```
STORY → TRAVEL → UPKEEP → MISSION → POST_MISSION → ADVANCEMENT → TRADING → CHARACTER → RETIREMENT
```

Note: CampaignDashboard uses `FiveParsecsCampaignPhase` (14 values, aliased `FPC`). Old `CampaignPhase` (10 values) is deprecated.

## Rules Data Authority

Campaign event tables, world traits, upkeep costs, and turn phase outcomes MUST be verified against `data/RulesReference/` files. Key files: `Campaign.json` (campaign rules), `DifficultyOptions.json` (difficulty modifiers), `Factions.json` (faction mechanics).

**NEVER invent event outcomes, costs, or thresholds.** Verify against RulesReference or ask the user.

## Critical Gotchas

1. **FiveParsecsCampaignCore is Resource** — `campaign["key"] = val` silently fails. Use `progress_data["key"]`
2. **CampaignCreationUI is a thin shell** (~161 lines) — don't put logic there, use coordinator
3. **World phase panels need refresh** — `_ready()` data is stale, call `_refresh_*()` on step entry
4. **Temp data for inter-screen** — `GameStateManager.set_temp_data(key, value)` pattern
5. **Bug Hunt keys namespaced** — `"bug_hunt_*"` prefix prevents collision with standard keys
