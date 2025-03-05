# UI Duplicate Files Reference

This document lists all duplicate UI files identified in the Five Parsecs Campaign Manager and provides a resolution strategy for each.

## Responsive Containers

| File | Path | Action | Status |
|------|------|--------|--------|
| ResponsiveContainer.gd | src/ui/components/ | **Remove** | ✅ **RESOLVED** |
| ResponsiveContainer.gd | src/ui/components/base/ | **Keep** | ✅ **KEPT** |
| CampaignResponsiveLayout.gd | src/ui/components/ | **Remove** | ✅ **RESOLVED** |
| CampaignResponsiveLayout.gd | src/ui/components/base/ | **Keep** | ✅ **KEPT** |

### Resolution Steps:
1. ✅ Verify that both files have identical functionality
2. ✅ Update any imports referencing the removed files
3. ✅ Remove the duplicate files

## Phase Panels

| File | Path | Action | Status |
|------|------|--------|--------|
| BasePhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| BasePhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| UpkeepPhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| UpkeepPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| StoryPhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| StoryPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| CampaignPhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| CampaignPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| BattleSetupPhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| BattleSetupPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| BattleResolutionPhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| BattleResolutionPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| AdvancementPhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| AdvancementPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| TradePhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| TradePhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |
| EndPhasePanel.gd | src/ui/screens/ | **Remove** | ✅ **RESOLVED** |
| EndPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** | ✅ **KEPT** |

### Resolution Steps:
1. ✅ Compare the functionality between duplicate files
2. ✅ Merge any unique functionality into the file to keep
3. ✅ Update imports to reference the kept file
4. ✅ Remove the duplicate files

## Dashboard and UI Files

| File | Path | Action | Status |
|------|------|--------|--------|
| CampaignDashboard.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| CampaignDashboard.tscn | src/ui/screens/campaign/ | **Keep** | ✅ **KEPT** |
| CharacterBox.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| CharacterBox.tscn | src/ui/components/character/ | **Keep** | ✅ **KEPT** |
| CharacterBox.tscn | src/ui/screens/character/ | **Keep** (different functionality) | ✅ **KEPT** |

**Note:** The two versions of CharacterBox.tscn serve different purposes:
- The version in `src/ui/components/character/` serves as a reusable component
- The version in `src/ui/screens/character/` is a full-screen variant with different UI layout and functionality

## Special Case: Campaign UI Files

| File | Path | Action | Status |
|------|------|--------|--------|
| CampaignUI.tscn | src/scenes/campaign/ | **Keep** | ✅ **DISTINCT** |
| CampaignDashboard.tscn | src/ui/screens/campaign/ | **Keep** | ✅ **DISTINCT** |

**Note:** These files serve different purposes:
- `CampaignUI.tscn` features a tab-based interface with a sidebar for campaign navigation
- `CampaignDashboard.tscn` has a panel-based layout with sections for displaying specific campaign details

### Resolution Steps:
1. ✅ Compare functionality between the files
2. ✅ Ensure all features are preserved in the kept files
3. ✅ Update any references to the removed files
4. ✅ Remove the duplicate files

## Character UI Components

| File | Path | Action | Status |
|------|------|--------|--------|
| CharacterCreator.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| CharacterCreator.tscn | src/ui/screens/character/ | **Keep** | ✅ **KEPT** |
| CharacterSheet.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| CharacterSheet.tscn | src/ui/screens/character/ | **Keep** | ✅ **KEPT** |
| CharacterProgression.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| CharacterProgression.tscn | src/ui/screens/character/ | **Keep** | ✅ **KEPT** |

### Resolution Steps:
1. ✅ Verify that the moved files work correctly
2. ✅ Update any scene references or script import paths
3. ✅ Remove the original files from the root directory

## Tutorial Components

| File | Path | Action | Status |
|------|------|--------|--------|
| TutorialSelection.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| TutorialSelection.tscn | src/ui/screens/tutorial/ | **Keep** | ✅ **KEPT** |
| NewCampaignTutorial.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| NewCampaignTutorial.tscn | src/ui/screens/tutorial/ | **Keep** | ✅ **KEPT** |

### Resolution Steps:
1. ✅ Verify that the moved files work correctly
2. ✅ Update any references to the tutorial components
3. ✅ Remove the original files from the root directory

## Other UI Files

| File | Path | Action | Status |
|------|------|--------|--------|
| VictoryConditionSelection.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| VictoryConditionSelection.tscn | src/ui/screens/campaign/setup/ | **Keep** | ✅ **KEPT** |
| ConnectionsCreation.tscn | src/ui/ | **Remove** | ✅ **RESOLVED** |
| ConnectionsCreation.tscn | src/ui/screens/connections/ | **Keep** | ✅ **KEPT** |

### Resolution Steps:
1. ✅ Verify that the moved files work correctly
2. ✅ Update any references to these UI components
3. ✅ Remove the original files from the root directory

## Testing Checklist

After resolving each set of duplicates:

- [x] Verify all UI screens load correctly
- [x] Test all UI functionality
- [x] Ensure no import errors occur
- [x] Verify navigation between screens works correctly
- [x] Test on different screen sizes

## Notes on GDScript References

When updating GDScript references, you'll need to modify:

1. Script `preload()` and `load()` calls
2. Scene instance references
3. Type annotations
4. `class_name` references

Example:
```gdscript
# Old reference
const BasePhasePanel = preload("res://src/ui/screens/BasePhasePanel.gd")

# New reference 
const BasePhasePanel = preload("res://src/ui/screens/campaign/phases/BasePhasePanel.gd")
```

## Overall Status

All duplicate files have been resolved according to the plan above:

- ✅ All responsive container duplicates resolved
- ✅ All phase panel duplicates resolved
- ✅ All dashboard and UI file duplicates resolved
- ✅ All character UI component duplicates resolved
- ✅ All tutorial component duplicates resolved
- ✅ All other UI file duplicates resolved

**Special cases:**
1. The two CharacterBox.tscn files serve different purposes and have been kept
2. CampaignUI.tscn and CampaignDashboard.tscn are distinct interfaces and both have been kept 