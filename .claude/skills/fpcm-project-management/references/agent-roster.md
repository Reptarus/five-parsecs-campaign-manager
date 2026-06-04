# Agent Roster

## 9 Agents

### 1. character-data-engineer (sonnet, blue)
**Domain**: Character model, 2 enum systems, JSON data, equipment, world/economy
**Files Owned**:
- `src/core/character/` (incl. `CharacterTransferService.gd` — the cross-mode canonical-hub transfer service; export/import to/from the 5PFH-standard Character dict), `src/game/character/`
- `src/core/enums/GameEnums.gd`, `src/core/systems/GlobalEnums.gd` (FiveParsecsGameEnums.gd deleted Sprint A Bug 3, 2026-05-24 — project is now two-enum)
- `src/core/equipment/`, `src/core/data/`, `src/core/managers/GameDataManager.gd`
- `src/core/world/`, `data/` (132 JSON files)
**Skill**: `character-data` (4 references)

### 2. campaign-systems-engineer (sonnet, green)
**Domain**: Campaign creation (7 phases), turns (9 phases), save/load, state
**Files Owned**:
- `src/core/campaign/` (excl. BugHuntPhaseManager), `src/core/state/`
- `src/ui/screens/campaign/` (incl. `CampaignScreenBase.gd` — the mode-generic cross-mode transfer pickup: `_check_pending_transfers` / `_add_character_to_mode` dispatch), `src/game/campaign/` (incl. `FiveParsecsCampaignCore.add_crew_member` — the post-creation crew-add chokepoint)
- `src/core/managers/GameStateManager.gd`, `src/qol/TurnPhaseChecklist.gd`
**Skill**: `campaign-systems` (4 references)

### 3. battle-systems-engineer (opus, red)
**Domain**: Battle state machine, combat resolution, deployment, victory
**Files Owned**:
- `src/core/battle/` (43 files), `src/core/combat/`, `src/core/mission/`
- `src/ui/screens/battle/`, `src/core/victory/`, `src/core/terrain/`
**Skill**: `battle-systems` (4 references)

### 4. ui-panel-developer (sonnet, yellow)
**Domain**: UI components, Deep Space theme, TweenFX, scene routing, narrative event overlay system, sheet/PDF export
**Files Owned**:
- `src/ui/components/` (125+ files, incl. `src/ui/components/sheet/SheetRenderer.gd`)
- `src/ui/screens/` (non-campaign, non-battle, non-bug-hunt subdirs)
- `src/ui/screens/SceneRouter.gd`
- `src/ui/screens/narrative/` (NarrativeScreen, NarrativeTextGenerator, AdvisorSystem, NarrativeChoiceButton, SceneStage)
- `src/ui/screens/print/` (PrintSheetScreen — tab bar + right rail for sheet export)
- `src/core/export/PdfExportRouter.gd` (PDF backend abstraction: GodotHaru → GodotPDF → none)
- `data/narrative/` (atmosphere_openers.json, advisor_quotes.json, species_personality.json)
- `data/sheets/` (field manifests: rect, source dot-path, font_size per field)
- `assets/sheets/` (source sheet PNGs from Modiphius bundles, by book)
- `addons/godotpdf/` + `addons/godotharu/` (third-party PDF addons — read-only awareness)
**Skill**: `ui-development` (6 references including narrative-screen + sheet-export)

### 5. bug-hunt-specialist (sonnet, cyan)
**Domain**: Bug Hunt gamemode, cross-mode safety
**Files Owned**:
- `src/ui/screens/bug_hunt/`, `src/core/campaign/BugHuntPhaseManager.gd`
- `data/bug_hunt/` (15 files), any file with `bug_hunt` in name
**Skill**: `bug-hunt-gamemode` (3 references)

### 6. planetfall-specialist (sonnet, orange)
**Domain**: Planetfall gamemode, colony management, 18-step turns, cross-mode safety for Planetfall
**Files Owned**:
- `src/ui/screens/planetfall/` (15 GDScript + 3 TSCN; incl. `panels/PlanetfallCharacterImportPanel.gd` — the shipped veteran-import UI)
- `src/game/campaign/PlanetfallCampaignCore.gd` (incl. `add_roster_character` — the Planetfall transfer-pickup target)
- `data/planetfall/` (8 JSON files)
- Future: `src/core/campaign/PlanetfallPhaseManager.gd`
- Any file with `planetfall` in name
**Skill**: `planetfall-gamemode` (3 references)

### 7. tactics-specialist (sonnet, lime)
**Domain**: Tactics gamemode, army building, species army lists, vehicles, cross-mode safety for Tactics
**Files Owned**:
- Future: `src/ui/screens/tactics/`
- Future: `src/game/campaign/TacticsCampaignCore.gd`
- Future: `data/tactics/`
- Future: `src/core/campaign/TacticsPhaseManager.gd`
- Any file with `tactics` in name (within FPCM project)
**Skill**: `tactics-gamemode` (4 references)
**Prototype Reference**: `c:\Users\admin\Desktop\tacticaprototype1\` (structure only, NOT data)

### 8. qa-specialist (opus, magenta)
**Domain**: Testing, QA, bug reporting, gdUnit4
**Files Owned**: `tests/` (all test directories)
**Skill**: `qa-specialist` (6 references)

### 9. fpcm-project-manager (opus, white)
**Domain**: Orchestration, task decomposition, cross-agent coordination
**Files Owned**: None (coordinator only)
**Skill**: `fpcm-project-management` (3 references)

## Ownership Rules

1. Each agent owns specific files — don't route tasks to agents outside their domain
2. `character-data-engineer` exclusively owns both enum files (two-enum sync: GlobalEnums + GameEnums; FiveParsecsGameEnums deleted Sprint A Bug 3)
3. When a task touches files in multiple domains → decompose into sub-tasks
4. All gamemode specialists (`bug-hunt-specialist`, `planetfall-specialist`, `tactics-specialist`) review shared file changes for their own mode's safety
5. `qa-specialist` is always the final step for verification
6. Never route Planetfall or Tactics tasks to `campaign-systems-engineer` (incompatible data models)

## Model Tiers Reflect Cost/Latency, Not Trust

Current-generation models (Opus 4.8, Sonnet 4.6, Haiku 4.5) are all reliable at searching and reading code. Tier assignment matches cost/latency to task difficulty — it is NOT a statement about how much you can trust an agent's findings.

| Tier | Agents | Use for |
| ---- | ------ | ------- |
| Opus | project-manager, battle-systems, qa-specialist | Cross-system reasoning, multi-file pattern matching, cross-system verification |
| Sonnet | character-data, campaign, bug-hunt, planetfall, tactics, ui-panel | Well-scoped single-domain work (the bulk of tasks) |

### Verification Rules

- **Game-data values** (always): confirm any stat/cost/range/table value against `data/RulesReference/` + the Core Rules / Compendium PDFs before acting. A source-of-truth rule, independent of model capability — see CLAUDE.md "Data Integrity Rules."
- **Routing targets** (project-manager): confirm a file/API exists before routing downstream work; a bad route cascades across the multi-agent flow.
- Include structural anchors in agent prompts (key directories, known file paths, class names) — good practice for fast, on-target results.

## Tools & Environment

### PDF Rulebooks and Python Extraction

Rulebook PDFs and Python tools are available for data extraction and verification:

- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python**: 3.14.2 via `py` launcher (NOT `python`). **PyPDF2 3.0.1 is the ONLY PDF tool — do NOT use PyMuPDF/fitz.**
- **Example**: `py -c "from PyPDF2 import PdfReader; r = PdfReader('path'); print(r.pages[PAGE].extract_text())"`
- **All rules data is extracted from the PDFs via PyPDF2** — no exceptions.

## Cross-Domain Flow Examples

### Adding a new character trait
```
1. character-data-engineer → Add to Character.gd, update enums, add JSON data
2. battle-systems-engineer → Wire trait effects into BattleResolver
3. ui-panel-developer → Display trait in character cards
4. qa-specialist → Test trait across creation, battle, save/load
```

### Fixing a save/load bug
```
1. campaign-systems-engineer → Debug GameState.save/load_campaign()
2. character-data-engineer → If issue is in Character.to_dictionary/from_dictionary
3. bug-hunt-specialist → If issue affects Bug Hunt saves (check _detect_campaign_type)
4. qa-specialist → Regression test save/load round-trip
```

### Modifying battle UI tier system
```
1. battle-systems-engineer → Change TacticalBattleUI._apply_tier_visibility()
2. bug-hunt-specialist → Review for Bug Hunt cross-mode safety
3. planetfall-specialist → Review for Planetfall cross-mode safety
4. tactics-specialist → Review for Tactics cross-mode safety
5. qa-specialist → Test all 4 battle modes
```

### Adding a Planetfall colony building type
```
1. planetfall-specialist → Add JSON data, update PlanetfallCampaignCore.buildings_data handling
2. ui-panel-developer → Style building card in Planetfall dashboard
3. qa-specialist → Test building construction, save/load, colony stats
```

### Adding a Tactics army species
```
1. tactics-specialist → Create species JSON army book, unit profiles, weapon profiles
2. battle-systems-engineer → Wire any new special rules into BattleResolver (if shared)
3. ui-panel-developer → Display species in army builder UI
4. qa-specialist → Test army composition validation, points calculation, save/load
```

### Adding a new campaign phase
```
1. character-data-engineer → Add enum value to both enum files (GlobalEnums + GameEnums)
2. campaign-systems-engineer → Add phase to CampaignPhaseManager, create panel
3. ui-panel-developer → Style the panel with Deep Space theme
4. qa-specialist → Test phase transitions, save/load, checklist
```

### Extending cross-mode character transfer (canonical hub)
```
Transfer logic spans 3 owners — route by file:
1. character-data-engineer → CharacterTransferService.gd (export_to_canonical / import_from_canonical /
   convert_to_<mode> legs, snapshot, reward-suppression). The canonical interchange form is the
   5PFH-standard Character dict; any-to-any route composes two book-defined legs through 5PFH.
   GAME-DATA GATE: any per-mode conversion value (e.g. the Tactics P2 military_backgrounds table,
   currently UNVERIFIED) must be book-sourced before wiring — never invent.
2. campaign-systems-engineer → CampaignScreenBase pickup (_check_pending_transfers / _add_character_to_mode),
   FiveParsecsCampaignCore.add_crew_member, GameState.pending_character_transfers signal
3. <gamemode>-specialist → the receiving mode's import UI + mutator
   (bug-hunt: add_main_character; planetfall: PlanetfallCharacterImportPanel + add_roster_character;
   tactics: P2, NOT BUILT — named-veteran attachment, not a squad unit)
4. qa-specialist → tests/unit/test_character_transfer_hub.gd + test_planetfall_transfer.gd
   (round-trip lossless, reward-suppression, ending matrix)
```
