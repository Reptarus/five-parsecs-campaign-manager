# Tactics Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: army composition edge cases, prototype conversion gotchas, cross-mode issues, verified rulebook facts -->

## ABSOLUTE RULE: Tactics Rulebook Is Word of God

The Tactics rulebook PDF at `docs/rules/Five Parsecs From Home - Tactics.pdf` and text extraction at `docs/rules/tactics_source.txt` (503KB) are the canonical authority for all Tactics mechanics. If code disagrees with the book, the code is wrong.

**The Tactica prototype at `tacticaprototype1\` uses Age of Fantasy IP — NEVER copy data values from it. Only structure/patterns transfer.**

---

## Implementation Status

### Tactics gamemode IMPLEMENTED (Sessions 55-57) — 59 files
- `src/ui/screens/tactics/` exists (creation UI, dashboard, turn controller, panels)
- `src/game/campaign/TacticsCampaignCore.gd` exists (Resource; army lists, units, points)
- `data/tactics/` exists (~18-24 JSON data files; 108 costs verified)
- SceneRouter keys `tactics_creation` / `tactics_dashboard` / `tactics_turn_controller` exist
- `GameState._detect_campaign_type()` routes `campaign_type == "tactics"`
- **SHIPPED (Jun 4)**: per-character cross-mode transfer to/from Tactics. A transferred character becomes a NAMED VETERAN in `TacticsCampaignCore.veteran_characters[]` (see the cross-mode section below). Tactics now interconnects any-to-any with the other 3 modes.

### Source Materials Available
- Rulebook text: `docs/rules/tactics_source.txt` (503KB, 212 pages)
- Rulebook PDF: `docs/rules/Five Parsecs From Home - Tactics.pdf`
- Design notes: `docs/TACTICS_EXPANSION_NOTES.md`
- Prototype reference: `c:\Users\admin\Desktop\tacticaprototype1\` (322 GDScript files)

### Implementation Order (from memory project_tactics_gamemode_plan.md)
~64 new files total (39 GDScript + 25 JSON), 4 existing files modified (SceneRouter, GameState, MainMenu, CharacterTransferService)

---

## Architecture Decisions (Locked In)

### Serialization Contract
Must follow BugHuntCampaignCore/PlanetfallCampaignCore pattern:
- `@export var campaign_type: String = "tactics"` 
- `to_dictionary()` with `"campaign_type": "tactics"` at root AND in `meta` section
- `from_dictionary()` with `.get(key, default)` safe defaults
- `save_to_file()` / `load_from_file()` via FileAccess + JSON
- `.duplicate(true)` on all complex data

### GameState Integration Needed
- `_detect_campaign_type()` needs: `elif campaign_type == "tactics":` block
- `load_campaign()` needs: TacticsCampaignCore routing (like Planetfall at lines 479-484)

### SceneRouter Routes Needed
- `tactics_creation` → TacticsCreationUI.tscn
- `tactics_dashboard` → TacticsDashboard.tscn  
- `tactics_army_builder` → TacticsArmyBuilderUI.tscn
- `tactics_turn_controller` → TacticsTurnController.tscn

### UI Pattern
- `TacticsScreenBase` extends CampaignScreenBase (path-based extends)
- `TacticsCreationUI` extends `Control` directly (thin shell pattern, NOT TacticsScreenBase)
- Code-built UI with Deep Space theme tokens
- `preload()` for scripts, `const` for UIColors refs

### Temp Data
All keys use `"tactics_*"` prefix: `"tactics_battle_context"`, `"tactics_battle_result"`, `"tactics_army_list"`, `"tactics_mission"`

---

## Prototype Conversion Notes

### Transferable Patterns (~16 files worth)
- `ArmyCompositionValidator.gd` — hero limits, duplicate limits, points caps validation logic
- `AOFRulesEngine.gd` (~1200 lines) — combat resolution pipeline structure
- `GameStateMachine.gd` — tactical state machine pattern
- `src/data/army_books/` — army book JSON schema (17 dirs)
- Unit/weapon profile Resource shapes

### Critical Differences
- Prototype uses `.tres` Resource instances; FPCM uses JSON + GameDataManager
- Prototype has 17 Age of Fantasy factions; Tactics has 14 Five Parsecs species
- Prototype is 3D (Terrain3D, sprites, VFX); FPCM is 2D UI-only with Deep Space theme
- Prototype uses LimboAI for behavior trees; FPCM does not use LimboAI
- Prototype uses `quality`/`defense`; Tactics uses `combat_skill`/`toughness`/`KP`/`training`

### Army Book Data Structure (from prototype, adapt for Tactics)
Each species army book JSON should contain:
- Faction metadata (name, special_rules, faction_abilities)
- Unit profiles per tier (Civilian → Epic): speed, reactions, combat_skill, toughness, kp, savvy, training, cost
- Weapon profiles: name, range, shots, damage, traits, cost
- Vehicle profiles (for species that have them): kp, armor, transport, weapons

---

## Gotchas

### 1. Training Stat Is New
Tactics introduces a `Training` stat not present in 5PFH/Bug Hunt/Planetfall. Used for morale tests, tactical actions, and competence checks. Must be in all unit profiles.

### 2. Kill Points (KP) Replace Wounds
Vehicles have 2-8 KP. Characters have 1-3 KP. Different from the binary alive/dead model in other modes.

### 3. Godot 4.6 Type Inference
`var x := dict["key"]` won't compile. Use `var x: Type = dict["key"]`.

### 4. Modiphius Approval Pending
Meeting 2026-04-23. Code proceeds, shipping blocked.

### 5. PDF Extraction (PyPDF2 ONLY)
- Python: `py` launcher (NOT `python`). **PyPDF2 3.0.1 is the only PDF tool — do NOT use PyMuPDF/fitz.**
- All Tactics rules come from the PDF via PyPDF2. Example: `py -c "from PyPDF2 import PdfReader; r = PdfReader('docs/rules/Five Parsecs From Home - Tactics.pdf'); print(r.pages[PAGE].extract_text())"`

### 6. Cross-Mode Character Transfer — Tactics leg SHIPPED (Jun 4)

The Cross-Mode Character Transfer Framework (`src/core/character/CharacterTransferService.gd`, canonical-hub design) is SHIPPED for all 4 persistent modes: Bug Hunt ↔ 5PFH (Foundation), Planetfall (P1), and **Tactics (P2, Jun 4)**. `convert_to_tactics` / `convert_from_tactics` are wired and book-faithful. Tests: `tests/unit/test_tactics_transfer.gd` (9 tests; 24/24 total transfer tests pass; editor parse clean).

How it works:

- A transferred character becomes a **NAMED VETERAN** (an "officer or hero" figure, Tactics p.185) stored in the serialized `veteran_characters[]` array on TacticsCampaignCore — NEVER a squad unit in `campaign_units[]`. The book uses "no points cost formula" (p.184), so veterans stay OUT of points validation. Army lists stay species-profile-based; the veteran is a named attachment, not a profile entry. New core methods: `add_veteran_character()` (applies a tagged playability floor of >=1 Kill Point), `remove_veteran_character()`, `get_veteran_characters()`.
- The data-integrity prerequisite is DONE — `convert_to_tactics` / `convert_from_tactics` were verified against Tactics PDF p.184 ("Converting Characters") and THREE fabrications were removed: (1) the invented `military_backgrounds` list → replaced with a "military"/"war-torn" substring check grounded in the real `gear_database.json` backgrounds (the book says only "+2 with a military-type background" with NO enumerated list); (2) a `max(luck,1)` KP floor → the book is exactly "1 Kill Point per Luck point", so the floor moved to the veteran layer (tagged playability) and the conversion stays book-exact; (3) a "military property, equipment not transferred" strip → the book says "carry weapons over as they are". Combat cap +2, Toughness cap 5, and "each Kill Point after the first becomes 1 Luck" on export were confirmed CORRECT. The `military_backgrounds` GAME_BALANCE_ESTIMATE tag is GONE; it is no longer a blocker or prerequisite.
- Of the 12 directed routes among the 4 modes, Tactics→Bug Hunt and Tactics→Planetfall have NO direct book rule — they are offered ONLY by composing two book-defined legs through the 5PFH canonical (zero invented values). Tactics→5PFH and 5PFH→Tactics are the direct legs.
- Pickup dispatch for tactics is wired: `CampaignScreenBase._add_character_to_mode()` "tactics" case now dispatches to `add_veteran_character()` (it was previously a push_warning Phase-2 placeholder). UI: TacticsDashboard has "Commission Veteran" (opens `src/ui/screens/tactics/panels/TacticsVeteranImportPanel.gd`) and "Retire Veteran Out" cards.

Architectural truth (unchanged): a veteran is a named figure, NOT a squad unit, and never affects army points (`campaign_units[]`); the army-list / points system itself is unchanged. P3 persistent "veteran barracks" remains DEFERRED.
