# SceneRouter Cleanup Summary

## Date: 2025-12-15

## Changes Made

### 1. Documented Duplicate Entries
- **post_battle** and **post_battle_sequence**: Both kept, added comment noting `post_battle` is an alias for `post_battle_sequence`
- **main_campaign** and **campaign_dashboard**: Both kept, added comment noting they may serve same purpose

### 2. Documented Legacy Paths
- **campaign_turn**: Verified path exists (`res://src/ui/CampaignTurnUI.tscn`), added comment noting it's a legacy path not directly accessible from dashboard

### 3. Documented Orphaned Entries
Added comments to all scene registrations that are not directly accessible from CampaignDashboard:

#### Equipment & Ship Management
- `ship_inventory` - ShipInventory.tscn

#### World & Exploration
- `mission_selection` - MissionSelectionUI.tscn (used by WorldPhaseController)
- `patron_rival_manager` - PatronRivalManager.tscn

#### Battle System
- `battlefield_main` - BattlefieldMain.tscn
- `battle_resolution` - BattleResolutionUI.tscn

#### Events
- `campaign_events` - CampaignEventsManager.tscn

#### Utility
- `game_over` - GameOverScreen.tscn

#### Tutorial
- `tutorial_selection` - TutorialSelection.tscn
- `new_campaign_tutorial` - NewCampaignTutorial.tscn

### 4. Path Verification
All paths were verified to exist before adding comments:
- `src/ui/CampaignTurnUI.tscn` ✅
- `src/ui/screens/ships/ShipInventory.tscn` ✅
- `src/ui/screens/world/MissionSelectionUI.tscn` ✅
- `src/ui/screens/world/PatronRivalManager.tscn` ✅
- `src/ui/screens/battle/BattlefieldMain.tscn` ✅
- `src/ui/screens/battle/BattleResolutionUI.tscn` ✅
- `src/ui/screens/events/CampaignEventsManager.tscn` ✅
- `src/ui/screens/utils/GameOverScreen.tscn` ✅

## Rationale

### Why Keep "Orphaned" Entries?
These scenes may be used by:
1. **Direct navigation from other screens** (e.g., `mission_selection` from WorldPhaseController)
2. **Phase transition logic** (e.g., `battlefield_main` from battle phase)
3. **Future features** (e.g., `game_over` screen when campaign ends)
4. **Developer tools** (e.g., DeveloperDashboard may access these directly)

Removing them could break existing workflows that aren't immediately visible from the main dashboard navigation.

### Why Keep Duplicate Entries?
1. **Backward Compatibility**: Code may reference either `post_battle` or `post_battle_sequence`
2. **Semantic Clarity**: `post_battle_sequence` is more descriptive, but `post_battle` is shorter
3. **Minimal Cost**: Dictionary lookup is O(1), no performance penalty

## Next Steps (Optional)

If you want to further clean up in the future:

1. **Consolidate Aliases**: Search codebase for usage of `post_battle` vs `post_battle_sequence`, standardize on one
2. **Verify Orphans**: Check if orphaned scenes are actually used anywhere in codebase
3. **Add Scene Categories**: Consider grouping orphaned scenes into a "internal_only" category
4. **Create Scene Graph**: Document which scenes navigate to which others

## Files Modified

- `src/ui/screens/SceneRouter.gd` - Added inline documentation comments

## Testing Recommendations

1. Load a saved campaign and navigate through all accessible screens
2. Start new campaign creation flow
3. Enter battle phase and verify scene transitions
4. Check WorldPhaseController loads mission_selection correctly
5. Verify no errors in console related to scene loading
