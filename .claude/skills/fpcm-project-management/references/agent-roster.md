# Agent Roster

## 9 Agents

### 1. character-data-engineer (sonnet, blue)
**Domain**: Character model, 3 enum systems, JSON data, equipment, world/economy
**Files Owned**:
- `src/core/character/`, `src/game/character/`
- `src/core/enums/GameEnums.gd`, `src/core/systems/GlobalEnums.gd`, `src/game/campaign/crew/FiveParsecsGameEnums.gd`
- `src/core/equipment/`, `src/core/data/`, `src/core/managers/GameDataManager.gd`
- `src/core/world/`, `data/` (132 JSON files)
**Skill**: `character-data` (4 references)

### 2. campaign-systems-engineer (sonnet, green)
**Domain**: Campaign creation (7 phases), turns (9 phases), save/load, state
**Files Owned**:
- `src/core/campaign/` (excl. BugHuntPhaseManager), `src/core/state/`
- `src/ui/screens/campaign/`, `src/game/campaign/`
- `src/core/managers/GameStateManager.gd`, `src/qol/TurnPhaseChecklist.gd`
**Skill**: `campaign-systems` (4 references)

### 3. battle-systems-engineer (opus, red)
**Domain**: Battle state machine, combat resolution, deployment, victory
**Files Owned**:
- `src/core/battle/` (43 files), `src/core/combat/`, `src/core/mission/`
- `src/ui/screens/battle/`, `src/core/victory/`, `src/core/terrain/`
**Skill**: `battle-systems` (4 references)

### 4. ui-panel-developer (haiku, yellow)
**Domain**: UI components, Deep Space theme, TweenFX, scene routing
**Files Owned**:
- `src/ui/components/` (125+ files)
- `src/ui/screens/` (non-campaign, non-battle, non-bug-hunt subdirs)
- `src/ui/screens/SceneRouter.gd`
**Skill**: `ui-development` (4 references)

### 5. bug-hunt-specialist (sonnet, cyan)
**Domain**: Bug Hunt gamemode, cross-mode safety
**Files Owned**:
- `src/ui/screens/bug_hunt/`, `src/core/campaign/BugHuntPhaseManager.gd`
- `data/bug_hunt/` (15 files), any file with `bug_hunt` in name
**Skill**: `bug-hunt-gamemode` (3 references)

### 6. planetfall-specialist (sonnet, orange)
**Domain**: Planetfall gamemode, colony management, 18-step turns, cross-mode safety for Planetfall
**Files Owned**:
- `src/ui/screens/planetfall/` (15 GDScript + 3 TSCN)
- `src/game/campaign/PlanetfallCampaignCore.gd`
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

### 8. qa-specialist (sonnet, magenta)
**Domain**: Testing, QA, bug reporting, gdUnit4
**Files Owned**: `tests/` (all test directories)
**Skill**: `qa-specialist` (6 references)

### 9. fpcm-project-manager (opus, white)
**Domain**: Orchestration, task decomposition, cross-agent coordination
**Files Owned**: None (coordinator only)
**Skill**: `fpcm-project-management` (3 references)

## Ownership Rules

1. Each agent owns specific files — don't route tasks to agents outside their domain
2. `character-data-engineer` exclusively owns all enum files (three-enum sync)
3. When a task touches files in multiple domains → decompose into sub-tasks
4. All gamemode specialists (`bug-hunt-specialist`, `planetfall-specialist`, `tactics-specialist`) review shared file changes for their own mode's safety
5. `qa-specialist` is always the final step for verification
6. Never route Planetfall or Tactics tasks to `campaign-systems-engineer` (incompatible data models)

## Search Accuracy by Model Tier

| Tier | Agents | Search Guidance |
| ---- | ------ | --------------- |
| Opus | project-manager, battle-systems | Highest accuracy. Use for cross-system searches, complex pattern matching. Can handle broad queries. |
| Sonnet | campaign, character, bug-hunt, qa | Good accuracy with specific prompts. Always provide file path hints and exact names. |
| Haiku | ui-panel-developer | Lowest search accuracy. Provide exact file paths, limit search scope to known dirs, always verify claims. Do not delegate search-heavy exploration to Haiku agents. |

### Search Delegation Rules

- When routing tasks, verify that claimed files/APIs actually exist before downstream agents start work
- Include structural anchors in every agent prompt: key directories, known file paths, class names
- If an agent returns results that seem wrong or incomplete, re-search with a higher-tier model
- Never trust a single Explore result for routing decisions — spot-check by reading actual files

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
1. character-data-engineer → Add enum value to all 3 enum files
2. campaign-systems-engineer → Add phase to CampaignPhaseManager, create panel
3. ui-panel-developer → Style the panel with Deep Space theme
4. qa-specialist → Test phase transitions, save/load, checklist
```
