---
name: campaign-systems
description: "Use this skill when working with campaign creation (7-phase wizard), campaign turns (9-phase loop), save/load persistence, state management, or campaign dashboard UI. Covers CampaignPhaseManager, CampaignCreationCoordinator, GameState, GameStateManager, CampaignJournal, TurnPhaseChecklist, CampaignDashboard, CampaignCreationUI, and all campaign phase panels."
---

> 🛑 **RULE 0 (CLAUDE.md "Agent Verification Protocol" — MANDATORY, NON-NEGOTIABLE): READ THE ACTUAL CODE *AND* SCENES BEFORE ANY PLAN.** You may NOT propose a plan, design, edit, routing decision, or structural claim until you have opened and read the ACTUAL files involved — the `.gd` scripts AND the related `.tscn`/`.tres` scene/resource files. Memory, CLAUDE.md docblocks, SOPs, this file's own notes, and relayed sub-agent summaries are **LEADS TO VERIFY, never facts** — they go stale; open the file and confirm, citing `file:line`. The `.tscn` wiring (node tree, node types, `[ext_resource]` scripts, embedded/instanced sub-scenes, `unique_name_in_owner`, anchors/containers) is the **authority on what is actually instantiated and live** — a `.gd` can look dead but be wired into a scene, or look live but be orphaned. UI / layout / responsive work: reading the `.gd` is NOT enough, OPEN the `.tscn`. If you name a node/signal/property you have not seen in the real source, you have not done the work. **No first-hand read of the code + scene wiring = no plan.** Full code-and-scene due diligence is the floor, not extra effort.

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
6. **Post-creation crew additions go through `FiveParsecsCampaignCore.add_crew_member(member_dict)`** — the mutation chokepoint. Appends to `crew_data["members"]`, forces `is_captain = false`, rebuilds `_crew_id_index`, updates modified time. Used by the cross-mode character-transfer pickup
7. **Cross-mode transfer pickup is mode-generic, in `CampaignScreenBase`** — `_check_pending_transfers()` / `_apply_pending_transfers()` / `_add_character_to_mode()` dispatch to `add_crew_member` (5PFH), `add_main_character` (Bug Hunt), `add_roster_character` (Planetfall), or `add_veteran_character` (Tactics — shipped Jun 4, lands the import as a named veteran in `veteran_characters[]`, not a squad unit). Each dashboard calls `_check_pending_transfers.call_deferred()` in `_setup_screen` and overrides `_on_transfers_applied()`. `GameState.load_campaign` emits `pending_character_transfers(count)` on a 5PFH load. See gamemode skills' `cross-mode-safety.md`
