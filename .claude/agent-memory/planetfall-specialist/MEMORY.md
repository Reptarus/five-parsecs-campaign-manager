# Planetfall Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: cross-mode isolation issues, colony management edge cases, verified rulebook facts -->

## ABSOLUTE RULE: Planetfall Rulebook Is Word of God

The Planetfall rulebook PDF at `docs/Five_Parsecs_From_Home_Modiphius_Entertainment_Planetfall_MUH084V044OEF2026/` and text extraction at `docs/rules/planetfall_source.txt` are the canonical authority for all Planetfall mechanics. If code disagrees with the book, the code is wrong.

---

## Verified Implementation State (Apr 2026)

### Section 1: COMPLETE (22 files)
- `PlanetfallCampaignCore.gd` — 538 lines, fully functional Resource with to_dictionary/from_dictionary
- `PlanetfallScreenBase.gd` — 104 lines, extends CampaignScreenBase, class/loyalty pills, scroll layout
- `PlanetfallDashboard.gd` — functional, HubFeatureCards, colony stat strip, TODO for Colony Systems sprint
- `PlanetfallTurnController.gd` — 45-line placeholder, no turn phases wired yet
- `PlanetfallCreationUI.gd` — thin shell extending Control (NOT PlanetfallScreenBase), 6-step wizard
- `PlanetfallCreationCoordinator.gd` — extends Node, step navigation, accumulated state
- 6 creation panels in `panels/`
- 8 JSON data files in `data/planetfall/`
- 3 TSCN scene files

### Sections 2-5: NOT YET IMPLEMENTED
- Section 2 (pp.47-106): Campaign turns, colony management, research, buildings — BIGGEST section
- Section 3 (pp.109-154): Missions & battles
- Section 4 (pp.155-172): Campaign development, milestones, endings
- Section 5 (pp.173-200): Appendices

### SceneRouter Routes (lines 88-91)
- `planetfall_creation` → `PlanetfallCreationUI.tscn`
- `planetfall_dashboard` → `PlanetfallDashboard.tscn`
- `planetfall_turn_controller` → `PlanetfallTurnController.tscn`

### GameState Detection
- `_detect_campaign_type()` at line 427: handles `"planetfall"` via `data.get("campaign_type")`
- `load_campaign()` at lines 479-484: routes to `PlanetfallCampaignCore.load_from_file()`

---

## Cross-Mode Safety Notes

### Campaign Type Validation
- File-level: `campaign_type == "planetfall"` in JSON root
- Runtime: `"roster" in campaign` (checks Resource property existence)
- PlanetfallDashboard uses `"roster" in _campaign` at line 23

### Equipment Pool Is CENTRAL
Unlike all other modes, Planetfall characters do NOT own equipment individually. The colony armory (`equipment_pool`) is the single source. Equipment is assigned at Lock & Load and returns after missions.

### Temp Data Keys
All use `"planetfall_*"` prefix. No collisions with standard, Bug Hunt, or Tactics keys.

### Character Transfer
`CharacterTransferService.convert_to_planetfall()` exists. Class training roll required. Stat mapping: `combat` → `combat_skill`, `reaction` → `reactions`. Imported characters tracked in `stashed_equipment` and `original_character_snapshots` for lossless export.

---

## Gotchas

### 1. _get_planetfall_campaign() Returns Untyped Resource
`PlanetfallScreenBase._get_planetfall_campaign()` returns `Resource` (duck typing), NOT typed `PlanetfallCampaignCore`. Use property checks like `"roster" in campaign`.

### 2. Colony Stats Are Campaign-Level Integers
`colony_morale`, `colony_integrity` etc. are on `PlanetfallCampaignCore`, not on characters. Don't confuse with per-character stats.

### 3. Grunts Are Count-Based, Not Individual
`grunts: int = 12` — just a count. NOT an array of dictionaries like Bug Hunt's `grunts: Array`. Planetfall grunts have no individual tracking (Planetfall p.16).

### 4. Godot 4.6 Type Inference
`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
Always use explicit type annotation: `var x: Type = dict["key"]`.

### 5. Modiphius Approval Pending
Meeting scheduled 2026-04-23. Code implementation proceeds, but shipping is blocked until approval.

### 6. PDF Extraction Tools
- Python: `py` launcher (NOT `python`), PyMuPDF installed
- Example: `py -c "import fitz; doc = fitz.open('docs/rules/planetfall_source.txt'); print(doc[PAGE].get_text())"`
- For PDF: `py -c "import fitz; doc = fitz.open('docs/Five_Parsecs_From_Home_Modiphius_Entertainment_Planetfall_MUH084V044OEF2026/Five Parsecs From Home - [Modiphius Entertainment] - Planetfall [MUH084V044][OEF][2026-03-16].pdf'); print(doc[PAGE].get_text())"`
