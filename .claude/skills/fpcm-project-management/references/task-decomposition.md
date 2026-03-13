# Task Decomposition Framework

## Dependency Order

When a task spans multiple agents, execute in this order:

```
1. character-data-engineer   → data contracts (enums, JSON, Character API)
2. campaign-systems-engineer  → campaign flow consuming data
3. battle-systems-engineer    → battle flow consuming data + campaign context
4. bug-hunt-specialist        → Bug Hunt variants (parallel with battle if independent)
5. ui-panel-developer         → display layer (always last for new features)
6. qa-specialist              → verify everything (always final)
```

## Decomposition Steps

1. **Identify all affected systems** — which files need changing?
2. **Map files to agents** — check agent-roster.md for ownership
3. **Determine dependencies** — which changes must complete before others can start?
4. **Order by dependency chain** — data first, UI last, QA final
5. **Identify parallel opportunities** — independent sub-tasks can run simultaneously
6. **Define handoff contracts** — what data/signals flow between agents?

## Worked Examples

### Example 1: "Add a new weapon type"
```
Agents: character-data-engineer, battle-systems-engineer, ui-panel-developer, qa-specialist
Order:
  1. character-data-engineer: Add weapon to GlobalEnums.WeaponType, create JSON entry in weapons.json
  2. battle-systems-engineer: Wire weapon stats into BattleResolver attack calculations
  3. ui-panel-developer: Add weapon icon/display to equipment screens
  4. qa-specialist: Test weapon in creation, combat, save/load
```

### Example 2: "Fix campaign turn not advancing"
```
Agents: campaign-systems-engineer, qa-specialist
Order:
  1. campaign-systems-engineer: Debug CampaignPhaseManager.complete_current_phase() signal flow
  2. qa-specialist: Regression test all 9 phase transitions
```

### Example 3: "Add co-op support to Bug Hunt"
```
Agents: bug-hunt-specialist, battle-systems-engineer, campaign-systems-engineer, ui-panel-developer, qa-specialist
Order:
  1. bug-hunt-specialist: Design co-op data model extension to BugHuntCampaignCore
  2. campaign-systems-engineer: Extend save/load for multi-player state
  3. battle-systems-engineer: Modify TacticalBattleUI for 2-player turns (cross-mode review!)
  4. ui-panel-developer: Build co-op lobby/join UI
  5. qa-specialist: Full sweep of co-op + regression on single-player
```

### Example 4: "Improve character card visual design"
```
Agents: ui-panel-developer, qa-specialist
Order:
  1. ui-panel-developer: Update _create_character_card() with new layout/animations
  2. qa-specialist: UI/UX compliance check, responsive layout test
```

### Example 5: "Add new DLC content flag"
```
Agents: character-data-engineer, campaign-systems-engineer, qa-specialist
Order:
  1. character-data-engineer: Add ContentFlag to DLCManager, create self-gating data class
  2. campaign-systems-engineer: Wire DLC check into appropriate campaign phase
  3. qa-specialist: Test with DLC enabled and disabled
```

### Example 6: "Rename a character stat"
```
Agents: character-data-engineer, battle-systems-engineer, campaign-systems-engineer, bug-hunt-specialist, ui-panel-developer, qa-specialist
Order:
  1. character-data-engineer: Rename in Character.gd, BaseCharacterResource, all 3 enum files, update to_dictionary/from_dictionary
  2. battle-systems-engineer: Update BattleResolver references
  3. campaign-systems-engineer: Update any phase panel stat displays
  4. bug-hunt-specialist: Update CharacterTransferService stat mapping
  5. ui-panel-developer: Update stat display components
  6. qa-specialist: Full sweep — rename could break everything
```

## Parallel Execution Rules

- Steps at the same dependency level CAN run in parallel
- Steps that consume another step's output MUST run sequentially
- QA is always sequential (final)
- Bug Hunt review is sequential after shared file changes
