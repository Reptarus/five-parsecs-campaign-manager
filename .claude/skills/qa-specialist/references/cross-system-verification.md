# Cross-System Verification Reference

## A. Key Autoload Signal Contracts

The 22 autoloads communicate via signals. Cross-system bugs often come from broken signal contracts.

### Campaign Phase Flow

| Signal | Emitter | Consumers |
|--------|---------|-----------|
| `phase_completed(phase)` | Phase panels (StoryPhasePanel, UpkeepPhasePanel, etc.) | CampaignPhaseManager, CampaignTurnController |
| `campaign_loaded(campaign)` | GameState | GameStateManager, CampaignDashboard, EquipmentManager |
| `credits_changed(amount)` | GameStateManager | UpkeepPhasePanel, TradePhasePanel, CampaignDashboard |
| `supplies_changed(amount)` | GameStateManager | UpkeepPhasePanel, CampaignDashboard |
| `reputation_changed(amount)` | GameStateManager | CampaignDashboard |
| `story_progress_changed(amount)` | GameStateManager | CampaignDashboard |
| `turn_completed` | CampaignPhaseManager | CampaignTurnController, CampaignJournal |
| `scene_changed(route)` | SceneRouter | Various UI screens |

### Verification Steps

1. **Check signal definitions** — verify signals exist on emitter class
2. **Check emission** — verify signal is emitted at the correct point in the flow
3. **Check consumers** — verify all consumers are connected and handle the signal
4. **Check data shape** — verify signal arguments match consumer expectations

---

## B. GameStateManager Dual-Sync Verification

The most common source of data loss bugs. ALL setters must write to both the campaign property AND `progress_data`.

### Canonical Setter Pattern

```gdscript
func set_X(value):
    # 1. Update campaign property
    campaign.X = value
    # 2. Sync to progress_data
    campaign.progress_data["X"] = value
    # 3. Emit signal
    X_changed.emit(value)
```

### Setters That Must Dual-Sync

| Setter | Campaign Property | progress_data Key |
|--------|------------------|-------------------|
| `set_credits()` | `campaign.credits` | `progress_data["credits"]` |
| `set_supplies()` | `campaign.supplies` | `progress_data["supplies"]` |
| `set_reputation()` | `campaign.reputation` | `progress_data["reputation"]` |
| `set_story_progress()` | `campaign.story_progress` | `progress_data["story_progress"]` |

### Verification Steps

1. Modify credits/supplies/reputation/story_progress via the setter
2. Save campaign to disk
3. Reload campaign from disk
4. Verify ALL values persisted correctly
5. Check `campaign.X == campaign.progress_data["X"]` for all four

### What Can Go Wrong

- New setter added without `progress_data` sync — value lost on reload
- Code bypasses setter and directly assigns `campaign.X = val` — progress_data stale
- `_on_campaign_loaded()` bypasses setters — values not properly synced on load
- `progress_data` missing default keys — null on first access after reload

---

## C. Campaign Creation Data Flow

### 7-Phase Wizard

```
CONFIG → CAPTAIN → CREW → EQUIPMENT → SHIP → WORLD → FINAL
```

CampaignCreationCoordinator + CampaignCreationStateManager hold all state. Panels signal through lambda adapters.

### Verification Steps

1. Walk all 7 phases, filling in data at each step
2. At FINAL, verify all data visible in review panel
3. Create campaign — verify FiveParsecsCampaignCore has all data
4. Save immediately — verify JSON contains all fields
5. Reload — verify all data matches what was entered

### What Can Go Wrong

- Panel signal not adapted to Dict format — coordinator receives wrong shape
- Coordinator state not propagated to FiveParsecsCampaignCore — data lost at creation
- OptionButton index 0 doesn't fire `item_selected` — default values not captured (BUG-030 pattern)
- Untyped variable holds BaseCharacterResource instead of Character — type mismatch crash (BUG-036 pattern)

---

## D. Save/Load Round-Trip Validation

### Key Fields to Compare

| Category | Fields | Common Failure Mode |
|----------|--------|---------------------|
| Progress | credits, supplies, reputation, story_progress | Dual-sync missing (BUG-031) |
| Turn state | turn_number, current_phase | Integer → float conversion |
| Crew | member count, stats, equipment arrays | Dual-key aliases missing |
| Equipment | `equipment_data["equipment"]` | Wrong key `"pool"` (Phase 22 bug) |
| Ship | hull_points, debt, type | Fabricated values (pre-Mar 16) |

### Verification Steps

1. Create/load a campaign with known values
2. Save to disk via SaveManager
3. Load from saved JSON
4. Compare all fields (see table above)
5. Re-save and binary compare JSON (after normalization)

### Integer Preservation

JSON stores all numbers as float. After loading:

```gdscript
# Verify int fields survive round-trip
assert(typeof(loaded.turn_number) == TYPE_INT or int(loaded.turn_number) == original_int)
```

### What Can Go Wrong

- `progress_data` missing keys — null values after reload (BUG-031 pattern)
- Equipment restoration unreachable — equipment vanishes on load (BUG-035 pattern)
- Integer fields returned as float — comparison fails without casting
- Dual-key aliases (`id`/`character_id`) missing from manually created dicts

---

## E. Cross-Mode Isolation (Standard vs Bug Hunt)

### Data Model Differences

| Aspect | Standard (FiveParsecsCampaignCore) | Bug Hunt (BugHuntCampaignCore) |
|--------|-----------------------------------|-------------------------------|
| Crew | `crew_data["members"]` (nested) | `main_characters[]` + `grunts[]` (flat) |
| Ship | `ship_data` present | No ship |
| Patrons | `patrons[]`, `rivals[]` | None |
| Stats | `combat`, `reaction` | `combat_skill`, `reactions` |

### Detection Pattern

```gdscript
if "main_characters" in campaign:
    # Bug Hunt campaign
else:
    # Standard 5PFH campaign
```

### Temp Data Namespacing

- Bug Hunt keys: `"bug_hunt_battle_context"`, `"bug_hunt_battle_result"`, `"bug_hunt_mission"`
- Standard keys: `"world_phase_results"`, `"return_screen"`, `"selected_character"`

### Verification Checklist

- [ ] Standard campaign save does NOT contain `main_characters` key
- [ ] Bug Hunt save does NOT contain `crew_data` key
- [ ] Loading a standard save with Bug Hunt loader fails gracefully
- [ ] Loading a Bug Hunt save with standard loader fails gracefully
- [ ] CharacterTransferService correctly maps stat keys between schemas
- [ ] temp_data keys don't leak between modes

### What Can Go Wrong

- Wrong campaign type detection — loader uses wrong schema
- Stat key mismatch — `combat` vs `combat_skill` causes null stats
- TacticalBattleUI changes break one mode while fixing the other
- temp_data key collision between namespaces

---

## F. Three-Enum Sync Verification

### Three Files That Must Align

| System | File | Access Pattern |
|--------|------|---------------|
| GlobalEnums | `src/core/systems/GlobalEnums.gd` | Autoload: `GlobalEnums.EnumName.VALUE` |
| GameEnums | `src/core/enums/GameEnums.gd` | class_name: `GameEnums.EnumName.VALUE` |
| FiveParsecsGameEnums | `src/game/campaign/crew/FiveParsecsGameEnums.gd` | CharacterClass enums |

### Verification Steps

1. Compare `FiveParsecsCampaignPhase` ordinals between GlobalEnums and GameEnums — must be identical
2. Verify `CharacterClass` in FiveParsecsGameEnums is superset of GlobalEnums character classes
3. Check `ContentFlag` count in DLCManager — expect 37 (35 DLC + 2 Bug Hunt)
4. Verify `DifficultyMode` has 9 values in GlobalEnums
5. Verify `VictoryChecker` handles all `VictoryConditionType` values (18+ types)

### What Can Go Wrong

- Value added to one file but not others — enum-to-int mismatch causes silent data corruption
- Ordering changed in one file — serialized enum values decode to wrong constant
- Obsolete enum value referenced in code — crash or wrong behavior at runtime

### Automated Check Script (run_script via MCP)

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    var ge = scene_tree.root.get_node_or_null("/root/GlobalEnums")
    if not ge:
        return {"error": "GlobalEnums not loaded"}
    var dlc = scene_tree.root.get_node_or_null("/root/DLCManager")
    var flag_count: int = 0
    if dlc and "ContentFlag" in dlc:
        flag_count = dlc.ContentFlag.size()
    return {
        "global_enums_loaded": ge != null,
        "dlc_content_flags": flag_count,
        "expected_flags": 37
    }
```
