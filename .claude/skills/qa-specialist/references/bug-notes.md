# Bug Notes — Five Parsecs Campaign Manager

Canonical bug tracker for QA reference. Updated after each fix sprint.

## Fixed

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| BUG-029 | Victory cards — `mouse_filter` blocked `gui_input` | Fixed mouse filter property |
| BUG-030 | Default Origin "None" — OptionButton index 0 doesn't fire `item_selected` | Added explicit `_on_origin_changed(0)` handler call |
| BUG-031 | Save/reload loses progress — only `set_credits()` synced to `progress_data` | Added dual-sync to `set_supplies()`, `set_reputation()`, `set_story_progress()` |
| BUG-032 | `get_campaign_config_data()` crash on partial dict | Added `.get()` defaults + `.merge()` |
| BUG-035 | Equipment not carried to Mission Prep — restoration code in `@tool` GameSystemManager, unreachable at runtime | Added `_restore_equipment_from_campaign()` in GameState.gd with deferred call |
| BUG-036 | Edit Captain crash — untyped variable could hold BaseCharacterResource | Typed `current_captain: Character` in CaptainPanel.gd |
| BUG-037 | Crew creation crash — nil stat bonus from WEALTH motivation | Added null guard in CrewPanel.gd |
| BUG-038 | Battlefield theme always "Wilderness" — terrain data at top level vs `terrain` sub-dict | Merged `terrain_guide` into `terrain` sub-dict in CampaignTurnController.gd |
| BUG-039 | Trading credits not persisted — sell path never called `GameStateManager.add_credits()` | Added setter call to PurchaseItemsComponent sell handler |
| BUG-040 | Terrain feature count exceeded ~15+ vs 13-feature Core Rules cap | Added `is_scatter` flag in BattlefieldShapeLibrary.gd, skip scatter in rendering |
| BUG-041 | Missing terrain size prefixes (LARGE/SMALL/LINEAR) | Added `size_category` property in BattlefieldShapeLibrary.gd |
| BUG-042 | Phantom equipment modifiers in initiative calculator | Added `_auto_detect_equipment()` validation in InitiativeCalculator.gd |
| BUG-043 | Initiative roll crash — `result.seized` property doesn't exist | Changed to `result.success` in TacticalBattleUI.gd |
| BUG-033 | Victory counter not persisted — `_on_post_battle_completed` read from post-battle results dict which lacks victory flag | BUG-033 FIX: Read from `self.battle_results` (stored by `_on_tactical_battle_completed`) instead of post-battle `results` param. Fix already in CampaignTurnController.gd:705 |
| BUG-034 | VC card description text low contrast (#808080 on #244862 ≈ 3.2:1) | Updated `_set_card_selected_state()` to swap desc text to COLOR_TEXT_PRIMARY and target to COLOR_FOCUS when selected. ExpandedConfigPanel.gd |
| UX-091 | Mission Prep shows "READY" with 0/4 crew equipped — no equipment check in readiness | Added `equipped_crew == 0` guard in `check_crew_readiness()`. MissionPrepComponent.gd |
| UX-092 | Assign Equipment buttons grayed out — crew selection lost on list rebuild, no auto-select | Preserve crew selection across `_update_crew_list()` rebuilds, reset stale equipment index, auto-select first crew in AssignEquipmentComponent. MissionPrepComponent.gd + AssignEquipmentComponent.gd |
| WEALTH-FIX | WEALTH motivation silently failed — `_apply_stat_bonus("CREDITS", 100)` tried to set `credits` on Character (no such property). Credits are campaign-level. | Removed CREDITS from STAT_PROPERTY_MAP. Now applies +1D6 credits at campaign finalization in CampaignFinalizationService.gd. CharacterCreator.gd + CampaignFinalizationService.gd |
| FAME-FIX | FAME motivation never granted story point — same pattern as WEALTH | Added FAME check in CampaignFinalizationService.gd, applies +1 story point. CampaignFinalizationService.gd |
| SHADOW-FIX | `const Character := preload(Base/Character.gd)` in 7 files shadowed global `class_name Character` — could cause wrong type annotations | Removed all 7 shadowing consts. Global class_name Character now resolves correctly. 7 files |

## Open / Needs Investigation

| Bug | Severity | Notes |
|-----|----------|-------|
| ~~BUG-036~~ | **NOT A BUG** | Precursor ability is "roll 2 Character Events, pick 1" (p.17), NOT psionic power. EquipmentItems.json reference was wrong. Stats now correct: S+1, T-1. |
| ~~BUG-037~~ | **FIXED** | Swift now +2 Speed (was +1 Speed +1 Reactions). Matched Core Rules p.50. |
| ~~BUG-038~~ | **FIXED** | Soulless now +1 Toughness only (removed extra +1 Reactions). Matched Core Rules p.50. |
| ~~Character bonus coverage~~ | **FIXED** | KNOWLEDGE +1 savvy added, game-specific CharacterCreator synced (Mar 21) |
| ~~Equipment table names~~ | **FIXED** | All weapon data rewritten from Core Rules p.50 (weapons.json + equipment_database.json). Invented weapons removed. |
| Victory condition metric tracking | Deferred | Feature addition: counters for enemies/credits/worlds |

## Patterns to Watch

- **GameStateManager dual-sync**: All setters that modify campaign state MUST also write to `progress_data`. If a new setter is added, check that both paths sync. Root cause of BUG-031.
- **Equipment restoration timing**: `_restore_equipment_from_campaign()` uses deferred call for `_init` timing. If equipment disappears after load, check the deferred call chain.
- **TacticalBattleUI shared mode**: Any changes must be tested in both Standard and Bug Hunt modes. Bug Hunt detection via `"bug_hunt_*"` temp_data keys.
- **MCP `pressed.emit()` on InitiativeCalculator**: Causes 30-second timeout + crash. Use alternative interaction for automated testing.
- **Multiple RandomizeButton nodes**: Exist across CaptainPanel + CrewPanel. Use scoped `find_child()` to avoid targeting the wrong one.
- **Difficulty field is now INT**: Stored values are `GlobalEnums.DifficultyLevel` enum values (1,2,4,6,8). Old saves with values 1-5 map incorrectly.
- **Ship values**: Pre-Mar 16 saves have fabricated hull 20-35 / debt 12-38. Corrected to Core Rules: hull 6-14, debt 0-5.
