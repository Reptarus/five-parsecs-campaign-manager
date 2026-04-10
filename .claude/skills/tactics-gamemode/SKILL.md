---
name: tactics-gamemode
description: "Use this skill when working with the Tactics gamemode — army building, species army lists, vehicle rules, points-based composition, operational campaign, squad/platoon management, or any Tactics-specific data files. Also use for cross-mode safety review when changes touch files shared between Tactics and other modes. Use for Tactica prototype conversion questions."
---

# Tactics Gamemode

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/tactics-data-model.md` | TacticsCampaignCore design, army building rules (points/heroes/duplicates), 14 species overview, vehicles, Training stat, KP system |
| `references/tactics-turn-flow.md` | Operational campaign turn phases, army builder wizard, battle resolution, Solo AI system |
| `references/prototype-conversion-map.md` | Tactica→FPCM file mapping, rename table, what transfers (structure) vs what to discard (data/3D/VFX), army book schema |
| `references/cross-mode-safety.md` | 4-mode isolation protocols, shared file list, temp_data namespacing, campaign type detection |

## Quick Decision Tree

- **Tactics data model questions** → Read `tactics-data-model.md`
- **Army building (points, composition)** → Read `tactics-data-model.md` (army building section)
- **Species army lists** → Read `tactics-data-model.md` (species section)
- **Vehicle rules** → Read `tactics-data-model.md` (vehicles section)
- **Turn/phase transitions** → Read `tactics-turn-flow.md`
- **Prototype conversion questions** → Read `prototype-conversion-map.md`
- **Cross-mode safety review** → Read `cross-mode-safety.md`
- **Army builder UI** → Read `tactics-turn-flow.md` (wizard section)

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/game/campaign/TacticsCampaignCore.gd` | Resource | Tactics campaign persistence (save/load) |
| `src/data/tactics/*.gd` | 14 Resource classes | Data model (SpeciesBook, UnitProfile, Roster, etc.) |
| `src/data/tactics/TacticsSpeciesBookLoader.gd` | RefCounted | JSON→Resource pipeline (species manifest for export) |
| `src/ui/screens/tactics/TacticsScreenBase.gd` | Control base | Base class for Tactics screens |
| `src/ui/screens/tactics/TacticsCreationUI.gd` | Control | 5-step creation wizard shell |
| `src/ui/screens/tactics/TacticsCreationCoordinator.gd` | Node | Creation state machine + validation |
| `src/ui/screens/tactics/TacticsDashboard.gd` | Control | Campaign overview + army roster display |
| `src/ui/screens/tactics/TacticsTurnController.gd` | Control | 8-phase operational turn flow |
| `src/ui/screens/tactics/panels/*.gd` | 7 panel scripts | Config, Species, Roster, Review, BattleSetup, PostBattle, OperationalMap |
| `src/core/campaign/TacticsPhaseManager.gd` | RefCounted | 8-phase turn state machine |
| `src/core/systems/TacticsInitiativeManager.gd` | RefCounted | D6 alternating activations |
| `src/core/systems/TacticsEnemyGenerator.gd` | RefCounted | Enemy army generation |
| `src/core/systems/TacticsMissionGenerator.gd` | RefCounted | D100 mission seed generation |
| `data/tactics/` | 24 JSON files | Species (16), weapons, vehicles, traits, skills, events, config |
| `docs/rules/Five Parsecs From Home - Tactics.pdf` | PDF | Tactics rulebook (212 pages) |
| `docs/QA_TACTICS_AUDIT.md` | Markdown | QA audit — 108 costs verified, 9 bugs fixed, 5/7 scenarios PASS |

## Rules Data Authority

Tactics data — species profiles, point costs, weapon stats, vehicle rules, army composition limits, special abilities — MUST be verified against `docs/rules/tactics_source.txt` and the Tactics PDF. Never invent Tactics values. Never copy data from the Tactica prototype (wrong IP — Age of Fantasy, not Five Parsecs).

## Critical Gotchas

1. **Implementation COMPLETE (Session 55-57)** — 59 files created, 108 costs verified, 5/7 QA scenarios PASS
2. **class_name parse-order** — UI files use runtime `load()` for Tactics data classes, NOT `preload()` or bare class_names. This avoids Godot 4.6 parse-order issues across directories. See RT-003 in QA doc
3. **Missing `.uid` files** — If new `.gd` files are created outside the Godot editor, UIDs won't be generated. Open the editor once to trigger UID generation. See RT-002 in QA doc
4. **Training stat is new** — Not in 5PFH/Bug Hunt/Planetfall. In all unit profiles
5. **Kill Points (KP) replace wounds** — Vehicles have 2-8 KP, characters 1-3 KP
6. **Temp data prefix** — All keys use `"tactics_*"` prefix
7. **Creation UI extends Control** — NOT TacticsScreenBase (thin shell pattern, matches all other modes)
8. **Army building validation** — Hero limit (1 per 375pts), duplicate limit (1+1 per 750pts), max 35% single unit
9. **15 specialist unit costs are GAME_BALANCE_ESTIMATE** — Not in Master Points Costs table (pp.178-180). Tagged in JSON
10. **HubFeatureCards emit `card_pressed`** — Dashboard uses PanelContainers, not Button nodes. Can't use `click_element` in MCP testing
