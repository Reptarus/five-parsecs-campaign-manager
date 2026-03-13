# Cross-Mode Safety Reference

## Isolation Protocols

### Campaign Type Validation
Always check before Bug Hunt code:
```gdscript
if "main_characters" in campaign:
    # Bug Hunt code
else:
    # Standard 5PFH code
```

### Temp Data Namespacing
```
Bug Hunt keys:     "bug_hunt_battle_context", "bug_hunt_battle_result", "bug_hunt_mission"
Standard keys:     "world_phase_results", "return_screen", "selected_character"
```
No collisions by convention. Bug Hunt keys always prefixed with `"bug_hunt_"`.

### Signal Connection Guards
```gdscript
if not signal_source.is_connected("signal_name", _on_handler):
    signal_source.connect("signal_name", _on_handler)
```
Always check `is_connected()` before connecting on shared components.

### _bug_hunt_returning Flag
Prevents double-navigation when both Abort and Complete buttons are pressed:
```gdscript
var _bug_hunt_returning: bool = false

func _on_abort():
    if _bug_hunt_returning: return
    _bug_hunt_returning = true
    # navigate back

func _on_complete():
    if _bug_hunt_returning: return
    _bug_hunt_returning = true
    # navigate to post-battle
```
Must be cleared after navigation completes.

## CharacterTransferService

### Enlistment (5PFH → Bug Hunt)
```
1. Roll 2D6 + Combat Skill
2. Need >= 8 (ENLISTMENT_TARGET)
3. Equipment stashed (except one Pistol)
4. Stats mapped: reaction→reactions, combat→combat_skill
5. game_mode = "bug_hunt"
6. xp, reputation, completed_missions_count → 0
7. Luck → 0 (Bug Hunt doesn't use it)
```

### Muster Out (Bug Hunt → 5PFH)
```
1. Military equipment stripped
2. Stats mapped: reactions→reaction, combat_skill→combat
3. Luck → 1 (base value)
4. game_mode = "standard"
5. Stashed equipment restored
6. bug_hunt_missions_completed saved
```

### Stat Key Mapping
| Bug Hunt | Standard 5PFH |
|----------|---------------|
| `reactions` | `reaction` |
| `combat_skill` | `combat` |
| `speed` | `speed` |
| `toughness` | `toughness` |
| `savvy` | `savvy` |
| `luck` | `luck` |
| `xp` | `xp` |

## Shared Files (Require Cross-Mode Review)

| File | Why Shared | Safety Mechanism |
|------|-----------|-----------------|
| `TacticalBattleUI.gd` | Both modes use for battle | Mode detection at BugHuntBattleSetup level |
| `GameState.gd` | Save/load both campaign types | `_detect_campaign_type()` peeks JSON |
| `SceneRouter.gd` | Both modes navigate | Separate route keys (bug_hunt_*) |
| `GameStateManager.gd` | Both use temp_data | Key namespacing (bug_hunt_* prefix) |

## Standard Battle Temp Data Cleanup
`CampaignTurnController._on_post_battle_completed()` cleans up standard temp_data.
Bug Hunt temp_data cleaned up in `BugHuntTurnController` equivalents.
