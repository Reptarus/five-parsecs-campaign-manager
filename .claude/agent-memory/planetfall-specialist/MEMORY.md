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

### Character Transfer — Framework SHIPPED (Planetfall P1)

Cross-Mode Character Transfer Framework: a canonical-hub design in `src/core/character/CharacterTransferService.gd` (RefCounted). Every mode exports-to / imports-from the full 5PFH-standard Character dict (the canonical interchange form); any-to-any = compose export+import legs. Transfer mechanism is direct file-drop via `user://transfers/<id>.json` (schema_version 2 envelope), NOT a persistent barracks. Mode-generic pickup lives in `src/ui/screens/campaign/CampaignScreenBase.gd` (`_check_pending_transfers`/`_apply_pending_transfers`/`_add_character_to_mode` — planetfall dispatches to `add_roster_character` — `_on_transfers_applied` virtual hook). PlanetfallDashboard calls `_check_pending_transfers.call_deferred()` in `_setup_screen` and overrides `_on_transfers_applied()` to rebuild.

**Planetfall P1 SHIPPED**:

- Import UI: `src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd` — select source char from 5PFH/Bug Hunt saves → preview → Class Training D6 aptitude (1-2 fail, 3 random class, 4-6 player choice; max 3 trained, one per class) → embed lossless snapshot → `add_roster_character`. Stat maps: 5PFH Luck → 1 Kill Point each; Bug Hunt Tech → Savvy. Imported chars begin Loyal (Planetfall pp.26-27).
- Creation-wizard entry: import button in `src/ui/screens/planetfall/panels/PlanetfallRosterPanel.gd` (was disabled "future sprint", now wired).
- Dashboard cards on PlanetfallDashboard: "Import Veterans" + "Muster Colonists Out".
- Lossless snapshot: each imported char embeds its canonical form under a `snapshot` key; `export_to_canonical` short-circuits on it so muster-out restores the original verbatim. `_layer_planetfall_ending` applies ending bonuses on top of the snapshot-restored veteran (bonuses depend on ending, not stats).
- Reward suppression: Planetfall ending bonuses attach ONLY when `target_mode == "five_parsecs"`.

**DATA-INTEGRITY FIX — convert_from_planetfall ending matrix (Planetfall pp.165-166, verified planetfall_source.txt L12088-12113)**: matrix was WRONG, now corrected — loyalty = bonus_ship, ship_debt 0; independence_won = bonus_ship + ship_debt_prepaid (2D6 PARTIAL prepayment) + bonus_story_points 2 (the OLD BUG zeroed the whole debt); independence_lost = add_rival (Enforcers/Bounty Hunters) + bonus_story_points 2; isolation = +1 Luck + isolation_single_char flag; ascension = gains_psionic. KP→Luck is deliberately NOT converted on Planetfall export (book silent; snapshot restores imported veterans' Luck; born-in-Planetfall keep base Luck).

Methods: `convert_to_planetfall` / `convert_from_planetfall` / `attempt_class_training` / `_layer_planetfall_ending` / `_attach_snapshot` / `_restore_from_snapshot`. 15/15 gdUnit4 tests pass (`tests/unit/test_character_transfer_hub.gd`, `tests/unit/test_planetfall_transfer.gd`). NOTE: of 12 directed routes among the 4 modes, Planetfall→Bug Hunt has NO direct book rule — it is offered ONLY by composing two book-defined legs through the 5PFH canonical (zero invented values).

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

### 6. PDF Extraction Tools (PyPDF2 ONLY)
- Python: `py` launcher (NOT `python`). **PyPDF2 3.0.1 is the only PDF tool — do NOT use PyMuPDF/fitz.**
- All Planetfall rules come from the PDF via PyPDF2. Example: `py -c "from PyPDF2 import PdfReader; r = PdfReader('docs/Five_Parsecs_From_Home_Modiphius_Entertainment_Planetfall_MUH084V044OEF2026/Five Parsecs From Home - [Modiphius Entertainment] - Planetfall [MUH084V044][OEF][2026-03-16].pdf'); print(r.pages[PAGE].extract_text())"`
