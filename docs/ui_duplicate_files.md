# UI Duplicate Files Reference

This document lists all duplicate UI files identified in the Five Parsecs Campaign Manager and provides a resolution strategy for each.

## Responsive Containers

| File | Path | Action |
|------|------|--------|
| ResponsiveContainer.gd | src/ui/components/ | **Remove** |
| ResponsiveContainer.gd | src/ui/components/base/ | **Keep** |
| CampaignResponsiveLayout.gd | src/ui/components/ | **Remove** |
| CampaignResponsiveLayout.gd | src/ui/components/base/ | **Keep** |

### Resolution Steps:
1. Verify that both files have identical functionality
2. Update any imports referencing the removed files
3. Remove the duplicate files

## Phase Panels

| File | Path | Action |
|------|------|--------|
| BasePhasePanel.gd | src/ui/screens/ | **Remove** |
| BasePhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| UpkeepPhasePanel.gd | src/ui/screens/ | **Remove** |
| UpkeepPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| StoryPhasePanel.gd | src/ui/screens/ | **Remove** |
| StoryPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| CampaignPhasePanel.gd | src/ui/screens/ | **Remove** |
| CampaignPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| BattleSetupPhasePanel.gd | src/ui/screens/ | **Remove** |
| BattleSetupPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| BattleResolutionPhasePanel.gd | src/ui/screens/ | **Remove** |
| BattleResolutionPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| AdvancementPhasePanel.gd | src/ui/screens/ | **Remove** |
| AdvancementPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| TradePhasePanel.gd | src/ui/screens/ | **Remove** |
| TradePhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |
| EndPhasePanel.gd | src/ui/screens/ | **Remove** |
| EndPhasePanel.gd | src/ui/screens/campaign/phases/ | **Keep** |

### Resolution Steps:
1. Compare the functionality between duplicate files
2. Merge any unique functionality into the file to keep
3. Update imports to reference the kept file
4. Remove the duplicate files

## Dashboard and UI Files

| File | Path | Action |
|------|------|--------|
| CampaignDashboard.tscn | src/ui/ | **Remove** |
| CampaignDashboard.tscn | src/ui/screens/campaign/ | **Keep** |
| CharacterBox.tscn | src/ui/ | **Remove** |
| CharacterBox.tscn | src/ui/components/character/ | **Keep** |
| CharacterBox.tscn | src/ui/screens/character/ | **Keep** (if different functionality) |

### Resolution Steps:
1. Compare functionality between the files
2. Ensure all features are preserved in the kept files
3. Update any references to the removed files
4. Remove the duplicate files

## Character UI Components

| File | Path | Action |
|------|------|--------|
| CharacterCreator.tscn | src/ui/ | **Remove** |
| CharacterCreator.tscn | src/ui/screens/character/ | **Keep** |
| CharacterSheet.tscn | src/ui/ | **Remove** |
| CharacterSheet.tscn | src/ui/screens/character/ | **Keep** |
| CharacterProgression.tscn | src/ui/ | **Remove** |
| CharacterProgression.tscn | src/ui/screens/character/ | **Keep** |

### Resolution Steps:
1. Verify that the moved files work correctly
2. Update any scene references or script import paths
3. Remove the original files from the root directory

## Tutorial Components

| File | Path | Action |
|------|------|--------|
| TutorialSelection.tscn | src/ui/ | **Remove** |
| TutorialSelection.tscn | src/ui/screens/tutorial/ | **Keep** |
| NewCampaignTutorial.tscn | src/ui/ | **Remove** |
| NewCampaignTutorial.tscn | src/ui/screens/tutorial/ | **Keep** |

### Resolution Steps:
1. Verify that the moved files work correctly
2. Update any references to the tutorial components
3. Remove the original files from the root directory

## Other UI Files

| File | Path | Action |
|------|------|--------|
| VictoryConditionSelection.tscn | src/ui/ | **Remove** |
| VictoryConditionSelection.tscn | src/ui/screens/campaign/setup/ | **Keep** |
| ConnectionsCreation.tscn | src/ui/ | **Remove** |
| ConnectionsCreation.tscn | src/ui/screens/connections/ | **Keep** |

### Resolution Steps:
1. Verify that the moved files work correctly
2. Update any references to these UI components
3. Remove the original files from the root directory

## Testing Checklist

After resolving each set of duplicates:

- [ ] Verify all UI screens load correctly
- [ ] Test all UI functionality
- [ ] Ensure no import errors occur
- [ ] Verify navigation between screens works correctly
- [ ] Test on different screen sizes

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