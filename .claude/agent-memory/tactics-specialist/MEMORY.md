# Tactics Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: army composition edge cases, prototype conversion gotchas, cross-mode issues, verified rulebook facts -->

## ABSOLUTE RULE: Tactics Rulebook Is Word of God

The Tactics rulebook PDF at `docs/rules/Five Parsecs From Home - Tactics.pdf` and text extraction at `docs/rules/tactics_source.txt` (503KB) are the canonical authority for all Tactics mechanics. If code disagrees with the book, the code is wrong.

**The Tactica prototype at `tacticaprototype1\` uses Age of Fantasy IP — NEVER copy data values from it. Only structure/patterns transfer.**

---

## Implementation Status (Apr 2026)

### ZERO FPCM Code Exists
- No `src/ui/screens/tactics/` directory yet
- No `src/game/campaign/TacticsCampaignCore.gd` yet
- No `data/tactics/` directory yet
- No SceneRouter routes for Tactics yet
- GameState._detect_campaign_type() does NOT handle "tactics" yet

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
