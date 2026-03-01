# Scene Transition & Data Flow Analysis

**Date**: 2025-12-28
**Purpose**: Comprehensive analysis of scene architecture for data flow consistency
**Status**: Complete

---

## Scene Inventory Summary

| Category | Count | Notes |
|----------|-------|-------|
| Total .tscn files in src/ui/screens | 67 | Core screen scenes |
| Registered in SceneRouter | 35 | Primary navigation targets |
| Campaign Wizard Panels | 8 | All extend FiveParsecsCampaignPanel |
| World Phase Components | 9 | Loaded dynamically by WorldPhaseController |
| Battle Scenes | 11 | Various battle UI elements |
| Orphan Candidates | 5 | Not referenced by any navigation code |

---

## Navigation Architecture

### Primary Navigation: SceneRouter

Location: `src/ui/screens/SceneRouter.gd`

The SceneRouter is the central navigation hub with 35 registered scene paths:

```
Main Menu Flow:
  MainMenu.tscn → CampaignCreationUI.tscn → CampaignDashboard.tscn

Campaign Turn Flow:
  CampaignDashboard.tscn → TravelPhaseUI.tscn → WorldPhaseController.tscn
                        → BattleHUDCoordinator.tscn → PostBattleSequence.tscn
```

### Scene Groups in SceneRouter

| Group | Key | Scene Path |
|-------|-----|------------|
| **Main** | main_menu | MainMenu.tscn |
| | main_game | MainGameScene.tscn |
| **Campaign Creation** | campaign_creation | CampaignCreationUI.tscn |
| | main_campaign | MainCampaignScene.tscn |
| | campaign_dashboard | CampaignDashboard.tscn |
| **Characters** | character_creator | SimpleCharacterCreator.tscn |
| | character_details | CharacterDetailsScreen.tscn |
| | crew_management | CrewManagementScreen.tscn |
| **Equipment/Ships** | equipment_manager | EquipmentManager.tscn |
| | ship_manager | ShipManager.tscn |
| **Campaign Phases** | travel_phase | TravelPhaseUI.tscn |
| | world_phase | WorldPhaseController.tscn |
| | pre_battle | PreBattle.tscn |
| | post_battle | PostBattleSequence.tscn |

---

## Campaign Creation Wizard Flow

### Panel Order (Core Rules SOP Aligned)

| Step | Panel | STEP_NUMBER | Status |
|------|-------|-------------|--------|
| 1 | ExpandedConfigPanel / ConfigPanel | 1 | FIXED |
| 2 | CaptainPanel | 2 | OK |
| 3 | CrewPanel | 3 | OK |
| 4 | EquipmentPanel | 4 | OK |
| 5 | ShipPanel | 5 | OK |
| 6 | WorldInfoPanel | 6 | OK |
| 7 | FinalPanel | 7 | FIXED |

### Style Consistency Check

All campaign wizard panels now:
- Extend `FiveParsecsCampaignPanel` (base class)
- Have `STEP_NUMBER` constant defined
- Use design system spacing constants (SPACING_SM, SPACING_MD, etc.)
- Use design system color constants (COLOR_BASE, COLOR_ACCENT, etc.)

### Fixed Issues (2025-12-28)
- Added `STEP_NUMBER := 1` to ExpandedConfigPanel.gd
- Added `STEP_NUMBER := 1` to ConfigPanel.gd
- Added `STEP_NUMBER := 7` to FinalPanel.gd

---

## Campaign Turn Phase Flow

### Navigation from CampaignDashboard

Source: `src/ui/screens/campaign/CampaignDashboard.gd:1024-1033`

```
Step Index → Scene
0 (Travel)     → TravelPhaseUI.tscn
1,2 (World)    → WorldPhaseController.tscn
3 (Battle)     → BattleHUDCoordinator.tscn
4,5,6 (Post)   → PostBattleSequence.tscn
```

### Return Paths

| From Scene | Return To | Method |
|------------|-----------|--------|
| TravelPhaseUI | CampaignDashboard | SceneRouter.navigate_to("campaign_dashboard") |
| TravelPhaseUI | WorldPhaseController | SceneRouter.navigate_to("world_phase") |
| WorldPhaseController | CampaignDashboard | GameStateManager.navigate_to_screen() |
| WorldPhaseController | PreBattle | SceneRouter.navigate_to("pre_battle") |
| PostBattleSequence | CampaignDashboard | scene_router.navigate_to() |

---

## Orphaned Scenes (Candidates for Deletion)

These scenes are only self-referenced and not reachable via any navigation path:

| Scene | Location | Status | Notes |
|-------|----------|--------|-------|
| **TestMainMenu.tscn** | mainmenu/ | DELETE | Test file, not for production |
| **ConnectionsCreation.tscn** | connections/ | REVIEW | Character connections feature (incomplete?) |
| **NewCampaignFlow.tscn** | utils/ | DELETE | Legacy flow, replaced by CampaignCreationUI |
| **UpkeepPhaseUI.tscn** | campaign/ | REVIEW | May be merged into WorldPhaseController |
| **CharacterCustomizationScreen.tscn** | campaign/ | REVIEW | Feature complete but not wired |

### Verification Commands Used

```bash
# Check for references (returns empty = orphan)
grep -rn "ConnectionsCreation" --include="*.gd" --include="*.tscn" | grep -v "ConnectionsCreation"
grep -rn "NewCampaignFlow" --include="*.gd" --include="*.tscn" | grep -v "NewCampaignFlow"
grep -rn "UpkeepPhaseUI" --include="*.gd" --include="*.tscn" | grep -v "UpkeepPhaseUI"
```

---

## Navigation Patterns Used

### Pattern 1: SceneRouter.navigate_to() (Preferred)
```gdscript
if SceneRouter and SceneRouter.has_method("navigate_to"):
    SceneRouter.navigate_to("campaign_dashboard")
```

### Pattern 2: GameStateManager.navigate_to_screen()
```gdscript
GameStateManager.navigate_to_screen("crew_management")
```

### Pattern 3: Direct change_scene_to_file() (Fallback)
```gdscript
get_tree().call_deferred("change_scene_to_file", "res://path/to/scene.tscn")
```

### Recommendation
- Use SceneRouter.navigate_to() for all navigation
- Only use direct change_scene_to_file() as fallback when SceneRouter unavailable
- Avoid GameStateManager.navigate_to_screen() in new code (redundant layer)

---

## Data Flow Points

### Campaign Creation → Dashboard

| Step | Component | Data Passed |
|------|-----------|-------------|
| 1 | FinalPanel | Emits `campaign_creation_requested(campaign_data)` |
| 2 | CampaignCreationUI | Receives, forwards to CampaignFactory |
| 3 | CampaignFactory | Creates GameState, persists to SaveManager |
| 4 | SceneRouter | Navigates to CampaignDashboard |
| 5 | CampaignDashboard | Loads from GameState |

### Phase Transitions

| From Phase | Data Stored | To Phase | Data Read |
|------------|-------------|----------|-----------|
| Travel | destination_data | World | GameStateManager.get_current_destination() |
| World | mission_data | Battle | GameStateManager.get_active_mission() |
| Battle | battle_results | PostBattle | GameStateManager.get_last_battle_results() |
| PostBattle | turn_complete | Dashboard | GameStateManager.get_campaign_turn() |

---

## Component Scenes (Not Orphans)

These scenes are loaded dynamically as children, not via navigation:

| Scene | Parent | Load Method |
|-------|--------|-------------|
| WorldPhaseController components | WorldPhaseController | load() + add_child() |
| CharacterCard.tscn | Multiple | preload() + instantiate() |
| VictoryProgressPanel.tscn | CampaignDashboard | scene node |
| PreBattleEquipmentUI.tscn | PreBattle | scene node |

---

## Action Items

### Immediate (Safe to Delete)
- [ ] `TestMainMenu.tscn` - Test file
- [ ] `NewCampaignFlow.tscn` - Legacy, replaced

### Review Before Deletion
- [ ] `ConnectionsCreation.tscn` - Check if feature planned
- [ ] `UpkeepPhaseUI.tscn` - May be component of WorldPhase
- [ ] `CharacterCustomizationScreen.tscn` - Check feature status

### Already Fixed
- [x] Added STEP_NUMBER to ExpandedConfigPanel.gd
- [x] Added STEP_NUMBER to ConfigPanel.gd
- [x] Added STEP_NUMBER to FinalPanel.gd

---

## Next Steps for Data Flow Work

1. **Backend Agent**: Focus on GameStateManager data persistence
2. **UI Agent (this analysis)**: Scene transitions are properly wired
3. **Integration**: Verify data handoffs at phase transitions
4. **Testing**: Create E2E tests for complete turn loop

---

**Document Status**: Complete
**Last Updated**: 2025-12-28
