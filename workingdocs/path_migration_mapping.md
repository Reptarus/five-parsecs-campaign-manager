# Path Migration Mapping

This document tracks the migration of files from their original locations to their new locations in the reorganized project structure.

## Core Files
| Original Path | New Path | Status |
|--------------|----------|---------|
| `/StateMachines/*` | `/src/core/state_machines/*` | Completed |
| `/Resources/*` | `/src/data/resources/*` | Completed |
| `/ui/*` | `/src/ui/screens/*` | Completed |
| `/data/*` | `/src/data/*` | Completed |

## Assets
| Original Path | New Path | Status |
|--------------|----------|---------|
| `/images/*` | `/assets/images/*` | Completed |
| `/global-plugin.png` | `/assets/images/global-plugin.png` | Completed |
| `/icon.svg` | `/assets/images/icon.svg` | Completed |

## Documentation
| Original Path | New Path | Status |
|--------------|----------|---------|
| `/README/*` | `/docs/rules/*` | Completed |
| `/Core Rules.md` | `/docs/rules/core_rules.md` | Completed |
| `/01 - Core Rulebook.txt` | `/docs/rules/core_rulebook.txt` | Completed |
| `/README.md` | `/docs/README.md` | Completed |

## Configuration Files
| Original Path | New Path | Status |
|--------------|----------|---------|
| `/project.godot` | `/project.godot` (unchanged) | N/A |
| `/export_presets.cfg` | `/export_presets.cfg` (unchanged) | N/A |
| `/override.cfg` | `/src/data/configs/override.cfg` | Completed |

## Test Files
| Original Path | New Path | Status |
|--------------|----------|---------|
| `/BattlefieldGeneratorTest.gd` | `/tests/battlefield_generator_test.gd` | Completed |

## Remaining Files
| Original Path | Status | Notes |
|--------------|---------|-------|
| `/.gitattributes` | Keep in root | Version control file |
| `/.gitignore` | Keep in root | Version control file |
| `/export_presets.cfg` | Keep in root | Godot config file |
| `/project.godot` | Keep in root | Godot project file |
| `/five-parsecs-campaign-manager.code-workspace` | Keep in root | VS Code workspace file |
| `/FiveParsecsTest.apk` | Consider moving to /builds | Build artifact |
| `/FiveParsecsTest.apk.idsig` | Consider moving to /builds | Build artifact |
| `/sdf.char` | Review if needed | Empty file |

## Notes
- Files marked as "unchanged" will remain in their original location
- Status "Completed" indicates files have been moved
- All moves have been tracked for version control
- Import files (.import) have been moved with their corresponding assets

# UI Path Migration Mapping

This document tracks the migration of UI files from their old locations to their new locations.

## Script Files (.gd)

Old Path | New Path
---------|----------
src/data/resources/UI/Panels/RewardsPanel.gd | src/ui/components/rewards/RewardsPanel.gd
src/data/resources/UI/Panels/MissionSummaryPanel.gd | src/ui/components/mission/MissionSummaryPanel.gd
src/data/resources/UI/Panels/MissionInfoPanel.gd | src/ui/components/mission/MissionInfoPanel.gd
src/data/resources/UI/Panels/EnemyInfoPanel.gd | src/ui/components/mission/EnemyInfoPanel.gd
src/data/resources/UI/BaseContainer.gd | src/ui/components/base/BaseContainer.gd
src/data/resources/UI/ResponsiveContainer.gd | src/ui/components/base/ResponsiveContainer.gd
src/data/resources/UI/CampaignResponsiveLayout.gd | src/ui/components/base/CampaignResponsiveLayout.gd
src/data/resources/UI/GestureManager.gd | src/ui/components/gesture/GestureManager.gd
src/data/resources/UI/TooltipManager.gd | src/ui/components/tooltip/TooltipManager.gd
src/data/resources/UI/TutorialOverlay.gd | src/ui/components/tutorial/TutorialOverlay.gd
src/data/resources/UI/TutorialUI.gd | src/ui/components/tutorial/TutorialUI.gd
src/data/resources/UI/AppOptions.gd | src/ui/components/options/AppOptions.gd
src/data/resources/UI/DifficultyOption.gd | src/ui/components/difficulty/DifficultyOption.gd
src/data/resources/UI/VictoryOption.gd | src/ui/components/victory/VictoryOption.gd
src/data/resources/UI/CharacterSheet.gd | src/ui/components/character/CharacterSheet.gd
src/data/resources/UI/TestPreBattle.gd | src/ui/screens/battle/TestPreBattle.gd

## Scene Files (.tscn)

Old Path | New Path
---------|----------
src/data/resources/UI/Panels/RewardsPanel.tscn | src/ui/components/rewards/RewardsPanel.tscn
src/data/resources/UI/Panels/MissionSummaryPanel.tscn | src/ui/components/mission/MissionSummaryPanel.tscn
src/data/resources/UI/Panels/MissionInfoPanel.tscn | src/ui/components/mission/MissionInfoPanel.tscn
src/data/resources/UI/Panels/EnemyInfoPanel.tscn | src/ui/components/mission/EnemyInfoPanel.tscn
src/data/resources/UI/TestPreBattle.tscn | src/ui/screens/battle/TestPreBattle.tscn
src/data/resources/UI/PreBattle.tscn | src/ui/screens/battle/PreBattle.tscn
src/data/resources/UI/PostBattle.tscn | src/ui/screens/battle/PostBattle.tscn
src/data/resources/UI/Scenes/TutorialOverlay.tscn | src/ui/components/tutorial/TutorialOverlay.tscn
src/data/resources/UI/Scenes/TutorialMain.tscn | src/ui/components/tutorial/TutorialMain.tscn
src/data/resources/UI/Scenes/TutorialContent.tscn | src/ui/components/tutorial/TutorialContent.tscn
src/data/resources/UI/Scenes/TutorialUI.tscn | src/ui/components/tutorial/TutorialUI.tscn

## Next Steps

1. Move all .gd files to their new locations (DONE)
2. Move all .tscn files to their new locations
3. Update script paths in .tscn files to point to new locations
4. Update any references to these files in other parts of the codebase