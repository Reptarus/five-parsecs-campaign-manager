# Cross-Mode Safety Reference (4 Modes)

This reference is shared across all gamemode skills (Bug Hunt, Planetfall, Tactics). It documents the isolation protocols, shared files, and safety mechanisms that prevent cross-mode contamination.

**IMPORTANT**: With 4 modes, cross-mode review is distributed. Each gamemode agent reviews for its own mode's safety. The project manager routes shared file changes to ALL affected gamemode agents.

## Campaign Type Detection (Two Layers)

### File-Level Detection
`GameState._detect_campaign_type(path)` at line 427:
```gdscript
static func _detect_campaign_type(path: String) -> String:
    # ... reads JSON file ...
    return data.get("campaign_type", "five_parsecs")
    # Returns: "bug_hunt", "planetfall", "tactics", or "five_parsecs"
```

**NOTE**: As of Apr 2026, "tactics" is NOT yet handled. Must add before Tactics implementation.

### Runtime Duck-Typing (in UI screens)
| Mode | Validation Check |
|------|-----------------|
| Standard 5PFH | Default (no check needed, or `"crew_data" in campaign`) |
| Bug Hunt | `"main_characters" in campaign` |
| Planetfall | `"roster" in campaign` |
| Tactics | `"army_lists" in campaign` (future) |

## Temp Data Namespacing

| Mode | Prefix | Examples |
|------|--------|---------|
| Standard 5PFH | (none) | `world_phase_results`, `return_screen`, `selected_character` |
| Bug Hunt | `bug_hunt_*` | `bug_hunt_battle_context`, `bug_hunt_battle_result`, `bug_hunt_mission` |
| Planetfall | `planetfall_*` | `planetfall_battle_context`, `planetfall_battle_result`, `planetfall_expedition` |
| Tactics | `tactics_*` | `tactics_battle_context`, `tactics_battle_result`, `tactics_army_list` |

No collisions by convention. Each mode's keys are exclusively prefixed.

## Signal Connection Guards
```gdscript
if not signal_source.is_connected("signal_name", _on_handler):
    signal_source.connect("signal_name", _on_handler)
```
Always check `is_connected()` before connecting on shared components.

## Shared Files (Require Cross-Mode Review)

| File | 5PFH | BH | PF | Tactics | Safety Mechanism |
|------|:---:|:---:|:---:|:---:|-----------------|
| `TacticalBattleUI.gd` | Y | Y | Y | Y | Mode detection at battle setup level |
| `BattleResolver.gd` | Y | Y | Y | Y | Static methods, no mode-specific state |
| `BattleCalculations.gd` | Y | Y | Y | Y | Static methods, trait effects via dict |
| `GameState.gd` | Y | Y | Y | Y | `_detect_campaign_type()` handles 4 types |
| `SceneRouter.gd` | Y | Y | Y | Y | Separate route key prefixes per mode |
| `GameStateManager.gd` | Y | Y | Y | Y | Key namespacing (mode prefix) |
| `HubFeatureCard.gd` | Y | Y | Y | Y | Pending data pattern |
| `MainMenu.gd` | Y | Y | Y | Y | Mode-specific dialogs + routes |
| `CharacterTransferService.gd` | Y | Y | Y | N* | Deep copy, atomic writes |

*Tactics uses army lists, not individual character transfer.

## Character Transfer Rules

### 5PFH ↔ Bug Hunt (Compendium pp.212-213)
- Enlistment: 2D6 + Combat >= 7+, equipment stashed, Luck → 0
- Muster Out: Equipment restored, Luck → 1, rewards per missions completed
- Stat mapping: `reaction` ↔ `reactions`, `combat` ↔ `combat_skill`

### 5PFH ↔ Planetfall
- `CharacterTransferService.convert_to_planetfall()`: Class training roll required
- Stat mapping: `combat` → `combat_skill`, `reaction` → `reactions`
- Imported characters tracked in `stashed_equipment` and `original_character_snapshots`
- Export back via `convert_from_planetfall()` for lossless return

### Tactics
Tactics does NOT use individual character transfer. Army lists are built from species profiles. Characters from other modes cannot be imported into Tactics armies.

## Data Safety Rules
- **Deep copy**: Every cross-campaign transfer uses `.duplicate(true)` — NEVER shared references
- **Atomic writes**: Transfer files use temp+rename pattern to prevent corruption
- **Validate-then-delete**: Transfer files validated before import, deleted after
- **No Resource refs in JSON**: Transfer files contain only JSON-safe primitives

## Scene Initialization Safety
Any screen using `get_node_or_null("/root/...")` in `_ready()` MUST use `call_deferred("_initialize")`. TransitionManager instantiates scenes before adding to tree — `_ready()` fires before `/root/` autoloads are accessible.

## SceneRouter Route Keys

| Mode | Routes |
|------|--------|
| Standard 5PFH | `campaign_creation`, `campaign_dashboard`, ... |
| Bug Hunt | `bug_hunt_creation`, `bug_hunt_dashboard`, `bug_hunt_turn_controller` |
| Planetfall | `planetfall_creation`, `planetfall_dashboard`, `planetfall_turn_controller` |
| Tactics | `tactics_creation`, `tactics_dashboard`, `tactics_army_builder`, `tactics_turn_controller` (future) |
