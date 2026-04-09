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
| `src/game/campaign/TacticsCampaignCore.gd` | Resource (future) | Tactics campaign data |
| `src/ui/screens/tactics/TacticsScreenBase.gd` | Control base (future) | Base class for Tactics screens |
| `src/ui/screens/tactics/TacticsDashboard.gd` | Control (future) | Army/campaign overview |
| `src/ui/screens/tactics/TacticsCreationUI.gd` | Control (future) | Army builder wizard (extends Control, NOT ScreenBase) |
| `src/ui/screens/tactics/TacticsArmyBuilderUI.gd` | Control (future) | Points-based army composition |
| `data/tactics/` | JSON (future) | Army lists, species, vehicles, missions |
| `docs/rules/tactics_source.txt` | Text | Full rulebook extraction (503KB) |
| `docs/TACTICS_EXPANSION_NOTES.md` | Markdown | Design notes and research |

## Rules Data Authority

Tactics data — species profiles, point costs, weapon stats, vehicle rules, army composition limits, special abilities — MUST be verified against `docs/rules/tactics_source.txt` and the Tactics PDF. Never invent Tactics values. Never copy data from the Tactica prototype (wrong IP — Age of Fantasy, not Five Parsecs).

## Critical Gotchas

1. **ZERO code exists yet** — All Tactics files must be created from scratch, following Bug Hunt/Planetfall patterns
2. **Prototype data is wrong IP** — Structure transfers, data does NOT. 17 fantasy factions ≠ 14 Five Parsecs species
3. **GameState needs update** — `_detect_campaign_type()` doesn't handle `"tactics"` yet
4. **SceneRouter needs routes** — No `tactics_*` routes exist yet
5. **Training stat is new** — Not in 5PFH/Bug Hunt/Planetfall. Must be in all unit profiles
6. **Kill Points (KP) replace wounds** — Vehicles have 2-8 KP, characters 1-3 KP
7. **Temp data prefix** — All keys use `"tactics_*"` prefix
8. **Creation UI extends Control** — NOT TacticsScreenBase (thin shell pattern, matches all other modes)
9. **Army building validation** — Hero limit (1 per 375pts), duplicate limit (1+1 per 750pts), max 35% single unit
