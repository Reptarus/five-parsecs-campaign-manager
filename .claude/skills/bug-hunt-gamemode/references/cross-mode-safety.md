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

### Canonical-Hub Architecture (shipped)

`CharacterTransferService` (`src/core/character/CharacterTransferService.gd`, `class_name CharacterTransferService`, extends RefCounted) routes ALL 4 modes through a single **canonical interchange form** — the full 5PFH-standard Character dict. Every mode `export_to_canonical(char, source_mode)` and `import_from_canonical(canonical, target_mode)`; `transfer_character(char, source_mode, target_mode)` composes the two legs. Mode constants: `MODE_5PFH = "five_parsecs"`, `MODE_BUG_HUNT = "bug_hunt"`, `MODE_PLANETFALL = "planetfall"`, `MODE_TACTICS = "tactics"`.

- **Lossless snapshot**: each imported character embeds a `snapshot` key (its canonical form); `export_to_canonical` short-circuits on it so a later muster-out restores the original verbatim.
- **Reward-suppression**: 5PFH-specific exit rewards (Bug Hunt mustering credits / +1 Story Point / +Sector Government patron) attach ONLY when `target_mode == "five_parsecs"`.
- **File-drop transfer**: `user://transfers/<id>.json` (NOT a persistent barracks). Envelope `schema_version 2` keys include `direction, source_mode, target_mode, character, snapshot, stashed_equipment, mustering_credits, bonus_story_points, add_sector_government_patron`. Static `load_pending_transfers(target_mode)` filters by destination (v1 files always target 5PFH). Static `apply_transfer_rewards(campaign, transfer_data)` applies rewards and deletes the file (prevents double-import).
- **Generic pickup** lives in `CampaignScreenBase.gd`: `_check_pending_transfers()`, `_apply_pending_transfers()`, `_add_character_to_mode()` dispatch (`five_parsecs` → `add_crew_member`, `bug_hunt` → `add_main_character`, `planetfall` → `add_roster_character`, `tactics` → P2 placeholder), `_notify_transfer_result()`, the `_on_transfers_applied()` hook. BugHuntDashboard calls `_check_pending_transfers.call_deferred()` in `_setup_screen` and overrides `_on_transfers_applied()` to rebuild. `GameState.load_campaign` emits `pending_character_transfers(count)` on a 5PFH load.
- **Foundation shipped**: this Bug Hunt ↔ 5PFH path also fixed the previously-broken muster-out pickup (files were written to `user://transfers/` but never read). 15/15 gdUnit4 tests pass.

### Enlistment (5PFH → Bug Hunt) — Compendium p.212
```
1. Roll 2D6 + Combat Skill >= 7+ (ENLISTMENT_TARGET = 7, FIXED Session 42)
2. Equipment stashed (except one Pistol) — stored in campaign.stashed_equipment
3. Full Character.to_dictionary() snapshot stored in campaign.original_character_snapshots
4. Stats mapped: reaction→reactions, combat→combat_skill
5. game_mode = "bug_hunt"
6. xp, reputation, completed_missions_count → 0
7. Luck → 0 (Bug Hunt doesn't use it)
```

### Muster Out (Bug Hunt → 5PFH) — Compendium p.213
```
1. Military equipment stripped
2. Stats mapped: reactions→reaction, combat_skill→combat
3. Luck → 1 (base value)
4. game_mode = "standard"
5. Stashed equipment restored from campaign.stashed_equipment
6. Rewards: +1 credit per 2 completed_missions, +1 Story Point, +Sector Gov Patron
7. Service Pistol retained if 10+ missions
8. Transfer file written to user://transfers/ (atomic write, validate-then-delete)
```

### Data Safety Rules (Session 44)
- **Deep copy**: Every cross-campaign transfer uses `.duplicate(true)` — NEVER shared references
- **Atomic writes**: Transfer files use temp+rename pattern to prevent corruption
- **Validate-then-delete**: Transfer files are validated before import, deleted after to prevent double-application
- **No Resource refs in JSON**: Transfer files contain only JSON-safe primitives

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

### Scene Initialization Safety (Session 45)
**BugHuntTurnController** and any Bug Hunt screen using `get_node_or_null("/root/...")` in `_ready()` MUST use `call_deferred("_initialize")`. TransitionManager instantiates scenes before adding to tree — `_ready()` fires before `/root/` autoloads are accessible.

**HubFeatureCard** has pending data pattern — safe to call `setup()` before or after `add_child()`. Data stored in `_pending_*` vars if UI not built yet.

**MainMenu Bug Hunt dialog** uses `dialog.queue_free()` + `create_timer(0.05).timeout` for navigation — AcceptDialog modal blocks direct `SceneRouter.navigate_to()`.

## Shared Files (Require Cross-Mode Review)

**NOTE**: With 4 modes (Standard, Bug Hunt, Planetfall, Tactics), cross-mode review is distributed. Each gamemode agent reviews for its own mode's safety. The project manager routes shared file changes to ALL affected gamemode agents.

| File | 5PFH | BH | PF | Tactics | Safety Mechanism |
|------|:---:|:---:|:---:|:---:|-----------------|
| `TacticalBattleUI.gd` | Y | Y | Y | Y | Mode detection at battle setup level |
| `BattleResolver.gd` | Y | Y | Y | Y | Static methods, no mode-specific state |
| `BattleCalculations.gd` | Y | Y | Y | Y | Static methods, trait effects via dict |
| `GameState.gd` | Y | Y | Y | Y | `_detect_campaign_type()` handles 4 types |
| `SceneRouter.gd` | Y | Y | Y | Y | Mode-prefixed route keys |
| `GameStateManager.gd` | Y | Y | Y | Y | Key namespacing (mode prefix) |
| `HubFeatureCard.gd` | Y | Y | Y | Y | Pending data pattern (Session 45) |
| `MainMenu.gd` | Y | Y | Y | Y | Mode-specific dialogs + routes |
| `CharacterTransferService.gd` | Y | Y | Y | P2* | Canonical-hub export/import, lossless snapshot |
| `CampaignScreenBase.gd` | Y | Y | Y | Y | Generic pending-transfer pickup (mode dispatch) |

*Tactics individual-character transfer is **planned for P2, not yet built**. Army lists remain species-profile-based; a future P2 imports a character as a **named veteran attachment** (a new `veteran_characters[]` array on TacticsCampaignCore), NOT a squad unit (squad injection would break points validation). Prerequisite: replace the invented `military_backgrounds` list in `convert_to_tactics` (GAME_BALANCE_ESTIMATE / UNVERIFIED) with the real Tactics p.184 table first.

### Temp Data Namespacing (4 Modes)

| Mode | Prefix | Examples |
|------|--------|---------|
| Standard 5PFH | (none) | `world_phase_results`, `return_screen` |
| Bug Hunt | `bug_hunt_*` | `bug_hunt_battle_context`, `bug_hunt_battle_result` |
| Planetfall | `planetfall_*` | `planetfall_battle_context`, `planetfall_expedition` |
| Tactics | `tactics_*` | `tactics_battle_context`, `tactics_army_list` |

### Session 47: BattleResolver Changes Affect Both Modes
`BattleResolver.initialize_battle()` now extracts armor/screen from crew equipment
and enemy special_rules. Bug Hunt uses the same static methods. Safe because:
- `_extract_protective_equipment()` reads generic `equipment` array (both modes have it)
- `_extract_enemy_saving_throw()` reads `special_rules` array (both modes use enemy_types.json)
- `consumed_items` in result dict is ignored if no PostBattleCompletion wired (Bug Hunt has own post-battle)

## Standard Battle Temp Data Cleanup
`CampaignTurnController._on_post_battle_completed()` cleans up standard temp_data.
Bug Hunt temp_data cleaned up in `BugHuntTurnController` equivalents.
