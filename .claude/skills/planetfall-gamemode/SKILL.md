---
name: planetfall-gamemode
description: "Use this skill when working with the Planetfall gamemode — colony management, creation wizard, dashboard, 18-step turn controller, map/research/buildings systems, lifeform generation, character roster, expedition types, or any Planetfall-specific data files. Also use for cross-mode safety review when changes touch files shared between Planetfall and other modes."
---

> 🛑 **RULE 0 (CLAUDE.md "Agent Verification Protocol" — MANDATORY, NON-NEGOTIABLE): READ THE ACTUAL CODE *AND* SCENES BEFORE ANY PLAN.** You may NOT propose a plan, design, edit, routing decision, or structural claim until you have opened and read the ACTUAL files involved — the `.gd` scripts AND the related `.tscn`/`.tres` scene/resource files. Memory, CLAUDE.md docblocks, SOPs, this file's own notes, and relayed sub-agent summaries are **LEADS TO VERIFY, never facts** — they go stale; open the file and confirm, citing `file:line`. The `.tscn` wiring (node tree, node types, `[ext_resource]` scripts, embedded/instanced sub-scenes, `unique_name_in_owner`, anchors/containers) is the **authority on what is actually instantiated and live** — a `.gd` can look dead but be wired into a scene, or look live but be orphaned. UI / layout / responsive work: reading the `.gd` is NOT enough, OPEN the `.tscn`. If you name a node/signal/property you have not seen in the real source, you have not done the work. **No first-hand read of the code + scene wiring = no plan.** Full code-and-scene due diligence is the floor, not extra effort.

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
- **Character transfer (5PFH/Bug Hunt ↔ Planetfall — SHIPPED P1)** → Read `cross-mode-safety.md` (Character Transfer Framework section). Import UI: `PlanetfallCharacterImportPanel.gd`; import buttons in `PlanetfallRosterPanel.gd` (creation wizard) + PlanetfallDashboard "Import Veterans" / "Muster Colonists Out" cards

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `src/game/campaign/PlanetfallCampaignCore.gd` | Resource | Planetfall campaign data (shipped — full 18-step turn flow, runtime-verified) |
| `src/ui/screens/planetfall/PlanetfallScreenBase.gd` | Control base | Base class for Planetfall screens (extends CampaignScreenBase) |
| `src/ui/screens/planetfall/PlanetfallDashboard.gd` | Control | Colony overview dashboard |
| `src/ui/screens/planetfall/PlanetfallCreationUI.gd` | Control | 6-step creation wizard (extends Control, NOT ScreenBase) |
| `src/ui/screens/planetfall/PlanetfallCreationCoordinator.gd` | Node | Creation wizard orchestration |
| `src/ui/screens/planetfall/PlanetfallTurnController.gd` | Control | 18-step turn (placeholder, expanding) |
| `src/ui/screens/planetfall/panels/` | 6 panel files | Creation wizard step panels |
| `src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd` | Control | Veteran import UI (SHIPPED P1) — source select → preview → Class Training D6 → `add_roster_character` |
| `src/core/character/CharacterTransferService.gd` | `CharacterTransferService` | Canonical-hub transfer; `convert_to_planetfall` / `convert_from_planetfall` / `attempt_class_training` / `_layer_planetfall_ending` |
| `src/ui/screens/campaign/CampaignScreenBase.gd` | base | Generic pending-transfer pickup (`_add_character_to_mode` → `add_roster_character` for Planetfall) |
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
