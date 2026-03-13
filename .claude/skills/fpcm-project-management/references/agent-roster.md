# Agent Roster

## 7 Agents

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

### 6. qa-specialist (sonnet, magenta)
**Domain**: Testing, QA, bug reporting, gdUnit4
**Files Owned**: `tests/` (all test directories)
**Skill**: `qa-specialist` (6 references)

### 7. fpcm-project-manager (opus, white)
**Domain**: Orchestration, task decomposition, cross-agent coordination
**Files Owned**: None (coordinator only)
**Skill**: `fpcm-project-management` (3 references)

## Ownership Rules

1. Each agent owns specific files — don't route tasks to agents outside their domain
2. `character-data-engineer` exclusively owns all enum files (three-enum sync)
3. When a task touches files in multiple domains → decompose into sub-tasks
4. `bug-hunt-specialist` has review authority over any shared file (TacticalBattleUI, GameState, SceneRouter, GameStateManager)
5. `qa-specialist` is always the final step for verification

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
2. bug-hunt-specialist → Review for cross-mode safety
3. qa-specialist → Test both Standard and Bug Hunt battle modes
```

### Adding a new campaign phase
```
1. character-data-engineer → Add enum value to all 3 enum files
2. campaign-systems-engineer → Add phase to CampaignPhaseManager, create panel
3. ui-panel-developer → Style the panel with Deep Space theme
4. qa-specialist → Test phase transitions, save/load, checklist
```
