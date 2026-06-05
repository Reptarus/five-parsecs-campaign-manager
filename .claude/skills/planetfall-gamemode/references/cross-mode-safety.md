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
| Tactics | `"army_lists" in campaign` |

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
| `CharacterTransferService.gd` | Y | Y | Y | Y* | Canonical-hub export/import, lossless snapshot |
| `CampaignScreenBase.gd` | Y | Y | Y | Y | Generic pending-transfer pickup (mode dispatch) |

*Tactics individual-character transfer is **SHIPPED (Jun 4)**. All 4 modes now interconnect any-to-any. An imported character lands as a **named veteran** (an "officer or hero" figure, Tactics p.185) in a serialized `veteran_characters[]` array on TacticsCampaignCore, NOT a squad unit in `campaign_units[]` — so veterans never affect points validation (the book uses "no points cost formula", p.184). The data-integrity prerequisite is DONE: the invented `military_backgrounds` list in `convert_to_tactics` was removed and the conversion verified book-faithful against Tactics p.184; the GAME_BALANCE_ESTIMATE tag is gone.

## Character Transfer Framework (canonical hub)

`CharacterTransferService` (`src/core/character/CharacterTransferService.gd`, `class_name CharacterTransferService`, extends RefCounted) is a single chokepoint built around a **canonical interchange form** — the full 5PFH-standard Character dict. Every mode `export_to_canonical(char, source_mode)` and `import_from_canonical(canonical, target_mode)`; `transfer_character(char, source_mode, target_mode)` composes the source-leg export with the target-leg import. Mode constants: `MODE_5PFH = "five_parsecs"`, `MODE_BUG_HUNT = "bug_hunt"`, `MODE_PLANETFALL = "planetfall"`, `MODE_TACTICS = "tactics"`.

**Route matrix**: of 12 directed routes among the 4 modes, 9 are book-defined. The 3 with no direct book rule (Planetfall→Bug Hunt, Tactics→Bug Hunt, Tactics→Planetfall) are offered ONLY by composing two book-defined legs through the 5PFH canonical — inventing zero values.

**Lossless snapshot**: each imported character embeds a `snapshot` key (its canonical form). A later muster-out restores the original verbatim (`export_to_canonical` short-circuits on the snapshot). `_layer_planetfall_ending` applies ending bonuses on top of a snapshot-restored veteran because bonuses depend on the ending, not on stats.

**Reward-suppression rule**: 5PFH-specific exit rewards (Bug Hunt mustering credits / +1 Story Point / +Sector Government patron; Planetfall ending bonuses) attach ONLY when `target_mode == "five_parsecs"`.

**Transfer mechanism**: direct file-drop via `user://transfers/<id>.json` (NOT a persistent barracks). Envelope keys: `schema_version 2`, `direction`, `source_mode`, `target_mode`, `character`, `snapshot`, `stashed_equipment`, `mustering_credits`, `bonus_story_points`, `add_sector_government_patron`, `transferred_at` (the dashboard muster-out handler also stamps `source_campaign_id` / `source_campaign_name` before writing; `transfer_character()` itself emits only the preceding keys). Static `load_pending_transfers(target_mode)` filters by destination (v1 files predate `target_mode` and always target 5PFH). Static `apply_transfer_rewards(campaign, transfer_data)` applies rewards to the receiving campaign and deletes the file (prevents double-import).

**Generic pickup** lives in `CampaignScreenBase.gd`: `_check_pending_transfers()`, `_apply_pending_transfers()`, `_add_character_to_mode()` dispatch (`five_parsecs` → `add_crew_member`, `bug_hunt` → `add_main_character`, `planetfall` → `add_roster_character`, `tactics` → `add_veteran_character`), `_notify_transfer_result()`, the `_on_transfers_applied()` virtual hook, and `_campaign_mode()`. Each dashboard calls `_check_pending_transfers.call_deferred()` in `_setup_screen` and overrides `_on_transfers_applied()` to rebuild. Wired in CampaignDashboard (5PFH), BugHuntDashboard, and PlanetfallDashboard.

### 5PFH ↔ Bug Hunt (Compendium pp.212-213) — SHIPPED

- Enlistment: 2D6 + Combat >= 7+, equipment stashed, Luck → 0
- Muster Out: Equipment restored, Luck → 1, rewards per missions completed
- Stat mapping: `reaction` ↔ `reactions`, `combat` ↔ `combat_skill`

### 5PFH ↔ Planetfall (Planetfall pp.26-27, 165-166) — SHIPPED (P1)

- Import UI: `src/ui/screens/planetfall/panels/PlanetfallCharacterImportPanel.gd` — select a 5PFH/Bug Hunt source character → preview → **Class Training** D6 aptitude (1-2 fail, 3 random class, 4-6 player choice; max 3 trained, one per class via `attempt_class_training`) → embed snapshot → `add_roster_character`. 5PFH Luck → 1 Kill Point each; Bug Hunt Tech → Savvy; imported characters begin **Loyal**.
- Creation-wizard entry: import button in `PlanetfallRosterPanel.gd` (was disabled "future sprint", now wired). PlanetfallDashboard cards: "Import Veterans" and "Muster Colonists Out".
- Export back via `convert_from_planetfall()` for lossless return. **Ending matrix (corrected, Planetfall pp.165-166)**: loyalty = bonus ship + ship debt 0; independence_won = bonus ship + ship debt prepaid (2D6 *partial* prepayment) + 2 Story Points (the old bug wrongly zeroed the whole debt); independence_lost = add rival (Enforcers or Bounty Hunters) + 2 Story Points; isolation = +1 Luck + `isolation_single_char` flag; ascension = gains psionic. KP→Luck is deliberately NOT converted on Planetfall export (the book is silent; the snapshot restores imported veterans' Luck; born-in-Planetfall keep base Luck).

### Tactics (Tactics pp.184-185) — SHIPPED (Jun 4)

Tactics individual-character transfer is BUILT and tested; all 4 modes interconnect any-to-any (including Planetfall ↔ Tactics, composed through the 5PFH canonical). The army-list / points system is unchanged; an imported character lands as a **named veteran** (an "officer or hero" figure, Tactics p.185) stored in a NEW serialized `veteran_characters[]` array on TacticsCampaignCore via `add_veteran_character()`, NOT a squad unit in `campaign_units[]` — veterans stay OUT of points validation (the book uses "no points cost formula", p.184). The data-integrity prerequisite is DONE: the invented `military_backgrounds` list in `convert_to_tactics` was removed (replaced with a "military"/"war-torn" substring check grounded in the real gear_database.json backgrounds, since Tactics p.184 gives no enumerated list) and the conversion verified book-faithful; the GAME_BALANCE_ESTIMATE tag is gone. UI: TacticsDashboard "Commission Veteran" card (`TacticsVeteranImportPanel.gd`) + "Retire Veteran Out" 3-target overlay. Tests: `tests/unit/test_tactics_transfer.gd` (9 tests; 24/24 total transfer tests pass).

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
| Tactics | `tactics_creation`, `tactics_dashboard`, `tactics_turn_controller` |
