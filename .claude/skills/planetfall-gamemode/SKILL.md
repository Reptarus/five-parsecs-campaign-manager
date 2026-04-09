---
name: planetfall-gamemode
description: "Use this skill when working with the Planetfall gamemode — colony management, creation wizard, dashboard, 18-step turn controller, map/research/buildings systems, lifeform generation, character roster, expedition types, or any Planetfall-specific data files. Also use for cross-mode safety review when changes touch files shared between Planetfall and other modes."
---

# Planetfall Gamemode

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/planetfall-data-model.md` | PlanetfallCampaignCore full property table, colony stats, roster structure, equipment pool, map/research/buildings/lifeform data, serialization contract |
| `references/planetfall-turn-flow.md` | 18-step turn phases, PlanetfallPhaseManager design, dashboard navigation, creation wizard 6-step flow, signal contracts |
| `references/cross-mode-safety.md` | 4-mode isolation protocols, shared file list, temp_data namespacing, campaign type detection, character transfer |

## Quick Decision Tree

- **Planetfall data model questions** → Read `planetfall-data-model.md`
- **Colony management (Integrity/Morale/Buildings/Research)** → Read `planetfall-data-model.md` (colony section)
- **Turn/phase transitions (18-step)** → Read `planetfall-turn-flow.md`
- **Creation wizard changes** → Read `planetfall-turn-flow.md` (CreationUI section)
- **Dashboard UI changes** → Read `planetfall-turn-flow.md` (Dashboard section)
- **Map/grid system** → Read `planetfall-data-model.md` (map section)
- **Lifeform generation/evolution** → Read `planetfall-data-model.md` (lifeform section)
- **Cross-mode safety review** → Read `cross-mode-safety.md`
- **Character transfer (5PFH ↔ Planetfall)** → Read `cross-mode-safety.md`

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/game/campaign/PlanetfallCampaignCore.gd` | Resource | Planetfall campaign data (538 lines, Section 1 complete) |
| `src/ui/screens/planetfall/PlanetfallScreenBase.gd` | Control base | Base class for Planetfall screens (extends CampaignScreenBase) |
| `src/ui/screens/planetfall/PlanetfallDashboard.gd` | Control | Colony overview dashboard |
| `src/ui/screens/planetfall/PlanetfallCreationUI.gd` | Control | 6-step creation wizard (extends Control, NOT ScreenBase) |
| `src/ui/screens/planetfall/PlanetfallCreationCoordinator.gd` | Node | Creation wizard orchestration |
| `src/ui/screens/planetfall/PlanetfallTurnController.gd` | Control | 18-step turn (placeholder, expanding) |
| `src/ui/screens/planetfall/panels/` | 6 panel files | Creation wizard step panels |
| `data/planetfall/` | 8 JSON files | Planetfall-specific data |

## Rules Data Authority

Planetfall data — colony stats, turn phases, injury tables, research trees, building costs, lifeform generation, weapon stats — MUST be verified against `docs/rules/planetfall_source.txt` and the Planetfall PDF. Never invent Planetfall values.

## Critical Gotchas

1. **Incompatible data model** — `roster[]` (Planetfall) vs `crew_data["members"]` (5PFH) vs `main_characters[]` (Bug Hunt)
2. **Central equipment pool** — Characters do NOT own items; colony armory is `equipment_pool`
3. **Validate campaign type** — File: `campaign_type == "planetfall"`, Runtime: `"roster" in campaign`
4. **Colony stats are campaign-level** — `colony_morale`, `colony_integrity` on PlanetfallCampaignCore, not characters
5. **Grunts are count-based** — `grunts: int = 12`, NOT an array of dictionaries
6. **Temp data prefix** — All keys use `"planetfall_*"` prefix
7. **Creation UI extends Control** — NOT PlanetfallScreenBase (thin shell pattern)
8. **No ship, no patrons/rivals, no credits, no Luck stat** — replaced by colony systems + raw_materials + Story Points
