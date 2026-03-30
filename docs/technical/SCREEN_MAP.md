# Five Parsecs Campaign Manager - Comprehensive Screen & UI Flow Map

**Last Updated**: 2026-03-12
**Scope**: All user-facing screens, navigation flows, scene routing, and UI architecture
**Authority**: SceneRouter.gd (SCENE_PATHS dictionary) + phase coordinator systems + screen implementations

---

## 1. SCENE ROUTING AUTHORITY (SceneRouter.gd)

SceneRouter is the **single source of truth** for all scene navigation in the application. All 28 user-facing screens are registered in the SCENE_PATHS dictionary.

### 28 Registered Scene Routes

#### Main Entry Points (2 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `main_menu` | res://src/ui/screens/mainmenu/MainMenu.tscn | Initial launch screen with 8-button menu |
| `main_game` | res://src/scenes/main/MainGameScene.tscn | Fallback / unused primary game container |

#### Campaign Management (7 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `campaign_creation` | res://src/ui/screens/campaign/CampaignCreationUI.tscn | 7-phase wizard for new campaign setup |
| `campaign_setup` | res://src/ui/screens/campaign/CampaignSetupDialog.tscn | Campaign configuration dialog |
| `campaign_turn_controller` | res://src/ui/screens/campaign/CampaignTurnController.tscn | Main campaign turn loop orchestrator (9 phases) |
| `campaign_dashboard` | res://src/ui/screens/campaign/CampaignDashboard.tscn | Campaign overview & quick actions |
| `campaign_turn` | res://src/ui/CampaignTurnUI.tscn | Legacy/supplemental turn UI |
| `main_campaign` | res://src/ui/screens/campaign/MainCampaignScene.tscn | Alternative campaign container |
| `victory_progress` | res://src/ui/screens/campaign/VictoryProgressPanel.tscn | Victory condition progress tracker |

#### Character Management (5 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `character_creator` | res://src/ui/screens/character/SimpleCharacterCreator.tscn | Character creation / modification UI |
| `character_details` | res://src/ui/screens/character/CharacterDetailsScreen.tscn | View/edit character statistics & history |
| `character_progression` | res://src/ui/screens/character/CharacterProgression.tscn | Character advancement & skill upgrades |
| `advancement_manager` | res://src/ui/screens/character/AdvancementManager.tscn | Manage character leveling & experience |
| `crew_management` | res://src/ui/screens/crew/CrewManagementScreen.tscn | Manage crew roster & composition |

#### Equipment & Ship (4 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `equipment_manager` | res://src/ui/screens/equipment/EquipmentManager.tscn | Equipment inventory & modification |
| `equipment_generation` | res://src/ui/screens/equipment/EquipmentGenerationScene.tscn | Generate equipment for new campaigns |
| `ship_manager` | res://src/ui/screens/ships/ShipManager.tscn | Ship selection & customization |
| `ship_inventory` | res://src/ui/screens/ships/ShipInventory.tscn | Ship cargo & stash management |

#### World & Exploration (5 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `world_phase` | res://src/ui/screens/world/WorldPhaseController.tscn | World generation & management |
| `mission_selection` | res://src/ui/screens/world/MissionSelectionUI.tscn | Available missions browser |
| `patron_rival_manager` | res://src/ui/screens/world/PatronRivalManager.tscn | Patron & rival tracking |
| `world_phase_summary` | res://src/ui/screens/world/WorldPhaseSummary.tscn | World phase results summary |
| `travel_phase` | res://src/ui/screens/travel/TravelPhaseUI.tscn | Travel & exploration UI |

#### Battle System (5 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `pre_battle` | res://src/ui/screens/battle/PreBattle.tscn | Battle setup & crew selection |
| `battlefield_main` | res://src/ui/screens/battle/BattlefieldMain.tscn | Main battlefield display |
| `tactical_battle` | res://src/ui/screens/battle/TacticalBattleUI.tscn | Tactical battle companion (text-based rules engine) |
| `post_battle` | res://src/ui/screens/postbattle/PostBattleSequence.tscn | Battle results & casualty handling |
| `post_battle_sequence` | res://src/ui/screens/postbattle/PostBattleSequence.tscn | Alias of post_battle |

#### Events & Story (1 scene)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `campaign_events` | res://src/ui/screens/events/CampaignEventsManager.tscn | Random event system & story triggers |

#### Utility & Dialogs (4 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `save_load` | res://src/ui/screens/utils/SaveLoadUI.tscn | Save/load campaign files dialog |
| `game_over` | res://src/ui/screens/utils/GameOverScreen.tscn | Campaign end screen (victory/defeat) |
| `logbook` | res://src/ui/screens/utils/logbook.tscn | Campaign journal & event log |
| `settings` | res://src/ui/dialogs/SettingsDialog.tscn | Game settings & accessibility options |

#### Tutorial System (2 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `tutorial_selection` | res://src/ui/screens/tutorial/TutorialSelection.tscn | Tutorial mode selection screen |
| `new_campaign_tutorial` | res://src/ui/screens/tutorial/NewCampaignTutorial.tscn | Interactive tutorial for new players |

#### Help & Library (1 scene)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `help` | res://src/ui/help/HelpScreen.tscn | Help documentation & rules reference |

#### Bug Hunt Gamemode (3 scenes)
| SceneRouter Key | File Path | Purpose |
|---|---|---|
| `bug_hunt_creation` | res://src/ui/screens/bug_hunt/BugHuntCreationUI.tscn | Bug Hunt 4-phase creation wizard |
| `bug_hunt_dashboard` | res://src/ui/screens/bug_hunt/BugHuntDashboard.tscn | Bug Hunt campaign overview |
| `bug_hunt_turn_controller` | res://src/ui/screens/bug_hunt/BugHuntTurnController.tscn | Bug Hunt 3-phase turn loop |

---

## 2. SCENE NAVIGATION ARCHITECTURE

### 2.1 SceneRouter Infrastructure

**Location**: `src/ui/screens/SceneRouter.gd` (521 lines, extends Node)
**Type**: Autoload singleton
**Authority**: SCENE_PATHS dictionary (lines 14-85)

#### Navigation Methods
```gdscript
navigate_to(scene_name: String, context: Dictionary = {}, add_to_history: bool = true, with_transition: bool = true)
  → Routes to scene by key name
  → Performs FileAccess validation before transition
  → Integrates TransitionManager for fade effects
  → Caches scene with LRU eviction strategy (max 10 cached scenes)
  → Stores scene_context for data passing between screens
  → Maintains navigation_history (max 20 entries)

navigate_back()
  → Pops last screen from navigation_history
  → Re-navigates without adding to history (prevents circular loops)
  → Uses same TransitionManager fade effect

navigate_to_campaign_phase(phase_key: String, context: Dictionary = {})
  → Specialized navigation for campaign turn phases
  → Routes campaign_turn_controller to appropriate phase panel
```

#### Scene Caching Strategy (LRU - Least Recently Used)
```gdscript
_add_to_cache(scene_path: String, packed_scene: PackedScene)
  → Adds PackedScene to scene_cache Dictionary
  → If cache size exceeds 10 (max_cache_size), evicts oldest entry
  → Optimizes performance for frequently-accessed screens (campaign creation flow)

_transition_to_cached_scene(scene_path: String, context: Dictionary)
  → Instantiates PackedScene from cache
  → Applies scene_context before setting as root child
  → Cleans up previous scene root (queue_free)
```

#### Scene Context Storage
```gdscript
scene_contexts: Dictionary = {}
  → Stores per-scene context data indexed by scene routing key
  → Used for passing state between screens without global singletons
  → Example: campaign_turn_controller context includes current_campaign reference
```

#### Navigation History
```gdscript
navigation_history: Array[String] = []
  → Maintains breadcrumb trail of visited scenes (max 20)
  → Deduplication: consecutive duplicates filtered
  → navigate_back() pops and re-navigates without adding to history
  → Prevents "Back → Forward → Back" loops
```

#### TransitionManager Integration
```gdscript
TransitionManager.create_fade_transition()
  → Called during navigate_to() if with_transition=true
  → Provides smooth fade-in/fade-out effect between scenes
  → Default fade duration: ~0.5 seconds
```

#### Scene Preloading (Context-Aware)
```gdscript
_preload_campaign_flow_scenes()
  → Triggered when entering campaign_setup, campaign_creation, character_creator, 
    equipment_generation, world_phase, or campaign_dashboard
  → Preloads next logical scenes in campaign creation/turn flow
  → Reduces load times for sequential screen transitions
```

#### Scene Validation & Debugging
```gdscript
validate_all_scenes() → Dictionary
  → Returns {"valid": [...], "missing": [...]}
  → Checks FileAccess for each registered scene file
  → Used at startup or for development diagnostics

get_scene_info(scene_name: String) → Dictionary
  → Returns comprehensive scene metadata:
    → "name", "path", "category", "description", "is_cached", "access_time"

get_scenes_by_category(category: String) → Array[String]
  → Groups 28 scenes into 9 categories:
    → "campaign", "character", "equipment", "world", "battle", "events", "phases", "utility", "tutorial"
```

---

## 3. MAIN MENU FLOW

**Controller**: `MainMenu.gd` (335 lines, extends Control)
**Entry Point**: res://src/ui/screens/mainmenu/MainMenu.tscn
**Role**: Initial user decision point for 8 major game modes

### 3.1 Menu Button Mapping

| UI Button | Handler Method | Target Scene | Purpose |
|---|---|---|---|
| Continue | `_on_continue_pressed()` | `campaign_turn_controller` | Resume active campaign |
| New Campaign | `_on_new_campaign_pressed()` | `campaign_creation` | Start campaign creation wizard |
| Load Campaign | `_on_load_campaign_pressed()` | (dynamic) | Browse & load saved campaigns |
| Co-op Campaign | `_on_coop_campaign_pressed()` | (not implemented) | Coming soon |
| Battle Simulator | `_on_battle_simulator_pressed()` | (not implemented) | Coming soon |
| Bug Hunt | `_on_bug_hunt_pressed()` | `bug_hunt_creation` | Start Bug Hunt gamemode |
| Options | `_on_options_pressed()` | `settings` | Accessibility & game settings |
| Library | `_on_library_pressed()` | `help` | Rules reference & help |

### 3.2 Tutorial Popup System

**Trigger**: When starting new campaign (unless "disable_tutorial_popup" is set in settings)
**UI**: Panel with VBoxContainer containing 3 buttons

```
Tutorial Popup
├─ Story Track Button → sets tutorial_state=true → navigates to tutorial_selection
├─ Compendium Button → sets tutorial_state=true → navigates to tutorial_selection
└─ Skip Button → sets tutorial_state=false → starts campaign_creation directly
```

**Signal Flow**:
1. `_on_new_campaign_pressed()` → `_show_tutorial_popup()`
2. User clicks button → `_on_tutorial_popup_button_pressed(choice: String)`
3. `_handle_tutorial_choice(choice)` → calls `game_state_manager.set_tutorial_state(true/false)`
4. Routes to `tutorial_selection` or calls `_start_new_campaign()`

### 3.3 Load Campaign Dialog

**Flow**:
1. `_on_load_campaign_pressed()` creates AcceptDialog dynamically
2. Fetches available campaigns via `GameState.get_available_campaigns()`
3. For each campaign, creates Button with path binding
4. Clicking button → `_load_and_go_to_dashboard(path, dialog)` → navigates to `campaign_turn_controller`

**Optional**: Import from File button → `_on_import_from_file()` → FileDialog → `_on_import_file_selected()` → `campaign_turn_controller`

### 3.4 Screen Continuity

- **Continue Button Visibility**: Only shows if `GameStateManager.has_active_campaign()` returns true
- **Update on Focus**: `update_continue_button_visibility()` called in `_ready()` and via setup()
- **Fallback**: If GameStateManager unavailable, checks `/root/GameState` autoload directly

---

## 4. CAMPAIGN CREATION FLOW (7-Phase Wizard)

**Controller**: `CampaignCreationUI.gd` (220 lines, extends Control)
**Scene**: res://src/ui/screens/campaign/CampaignCreationUI.tscn
**Orchestrator**: `CampaignCreationCoordinator` (manages state transitions)

### 4.1 7-Phase Sequence

| Step # | Phase Name | Panel Type | File Path | Primary Action |
|---|---|---|---|---|
| 1 | CONFIG | ExpandedConfigPanel | campaign/panels/ExpandedConfigPanel.tscn | Set campaign name, difficulty, rules |
| 2 | CAPTAIN_CREATION | CaptainPanel | campaign/panels/CaptainPanel.tscn | Create/customize campaign captain |
| 3 | CREW_SETUP | CrewPanel | campaign/panels/CrewPanel.tscn | Create 3-5 additional crew members |
| 4 | EQUIPMENT_GENERATION | EquipmentPanel | campaign/panels/EquipmentPanel.tscn | Generate starting equipment |
| 5 | SHIP_ASSIGNMENT | ShipPanel | campaign/panels/ShipPanel.tscn | Select & customize starting ship |
| 6 | WORLD_GENERATION | WorldInfoPanel | campaign/panels/WorldInfoPanel.tscn | Generate world/planet system |
| 7 | FINAL_REVIEW | FinalPanel | campaign/panels/FinalPanel.tscn | Review all data & create campaign |

### 4.2 Coordinator State Management

**Coordinator Pattern**:
```gdscript
CampaignCreationCoordinator.new()
  → Manages current_step (0-6)
  → Provides navigation: advance_to_next_phase(), go_back_to_previous_phase()
  → Validates completion: can_advance_to_next_phase(), can_finish_campaign_creation()
  
State Update Pattern (Lambda Adapters):
  panel.signal_emitted.connect(func(typed_data):
    coordinator.update_phase_state(typed_data)
  )
```

**Completion Signals**:
- `step_changed(step: int, total_steps: int)` → Triggers panel show/hide & step label update
- `navigation_updated(can_back: bool, can_fwd: bool, can_finish: bool)` → Updates button visibility/disabled state
- `FinalPanel.campaign_finalization_complete(data: Dictionary)` → Campaign created

### 4.3 Navigation State

**Button Visibility by Step**:

| Step | Back Button | Next Button | Finish Button |
|---|---|---|---|
| 1 (CONFIG) | "Cancel" (visible) | Enabled | Hidden |
| 2-6 | "Back" (visible) | Enabled/Disabled | Hidden |
| 7 (FINAL) | "Back" (visible) | Hidden | Enabled/Disabled |

**Cancel on Step 1**: Back button navigates via `SceneRouter.navigate_back()` → returns to MainMenu

### 4.4 Finalization Flow

**FinalPanel** (`campaign/panels/FinalPanel.tscn`):
1. Validates all prior phases completed
2. Calls `CampaignFinalizationService.finalize_campaign(coordinator.state_data)`
3. Creates `FiveParsecsCampaignCore` Resource
4. Saves to JSON file
5. Emits `campaign_finalization_complete({"campaign": campaign_resource, "save_path": "...", "raw_data": {...}})`

**CampaignCreationUI Handler**:
```gdscript
_on_campaign_finalized(data: Dictionary)
  → Sets campaign via GameState.set_current_campaign(data["campaign"])
  → Navigates to campaign_turn_controller
```

### 4.5 Data Flow Between Phases

Each panel emits signal → CampaignCreationUI adapter converts to Dict → coordinator.update_*_state(dict)

**Example** (CaptainPanel):
```gdscript
# Panel emits:
captain_updated.emit(captain_character)

# CampaignCreationUI adapter:
captain_panel.captain_updated.connect(func(captain):
  coordinator.update_captain_state({
    "captain": captain,
    "captain_character": captain,
    "is_complete": captain != null
  })
)
```

---

## 5. CAMPAIGN TURN FLOW (9-Phase Loop)

**Controller**: `CampaignTurnController.gd`
**Scene**: res://src/ui/screens/campaign/CampaignTurnController.tscn
**Orchestrator**: `CampaignPhaseManager` (manages turn phase sequence)

### 5.1 Main 9-Phase Sequence

| Phase # | Phase Name | Panel/Controller | Purpose |
|---|---|---|---|
| 0 | STORY | StoryPhasePanel | Campaign narrative & updates |
| 1 | TRAVEL | TravelPhasePanel | Crew movement & exploration |
| 2 | UPKEEP | UpkeepPhasePanel | Maintenance, repairs, recovery |
| 3 | MISSION | MissionPhasePanel | **Includes PRE_MISSION sub-phases** |
| 4 | POST_MISSION | PostMissionPhasePanel | Results, casualties, loot |
| 5 | ADVANCEMENT | AdvancementPhasePanel | Character leveling & upgrades |
| 6 | TRADING | TradingPhasePanel | Equipment sales & purchases |
| 7 | CHARACTER | CharacterPhasePanel | Personal character events |
| 8 | RETIREMENT | RetirementPhasePanel | Campaign-end logic |

### 5.2 MISSION Phase (Phase 3) with 5 Sub-Phases

**Special Structure**: MISSION phase contains 5 nested sub-phases

```
MISSION Phase (3)
├─ PRE_MISSION.WORLD → World/enemy selection
├─ PRE_MISSION.DEPLOYMENT → Deployment grid setup
├─ PRE_MISSION.BRIEFING → Mission briefing
├─ PRE_MISSION.BATTLE → Tactical battle execution
└─ PRE_MISSION.RETREAT → Retreat/abort handling
```

**Navigation**:
```gdscript
navigate_to_campaign_phase("mission")
  → Enters MISSION phase loop
  → PRE_MISSION sub-phases executed sequentially
  → Each sub-phase emits phase_completed signal
  → Final completion returns to main 9-phase loop at POST_MISSION (phase 4)
```

### 5.3 CampaignPhaseManager Infrastructure

**Location**: `src/core/campaign/CampaignPhaseManager.gd`
**Type**: Autoload singleton
**Role**: Orchestrates 9-phase + 5-sub-phase loop

```gdscript
Current Phase Tracking:
  current_phase: FiveParsecsCampaignPhase enum (0-8)
  current_pre_mission_phase: PreMissionPhase sub-enum
  
Phase Completion Signals:
  phase_completed.emit(data: Dictionary)
  campaign_turn_completed.emit(turn_number: int)
  
Navigation Methods:
  advance_to_next_phase(phase_data: Dictionary)
  retreat_from_phase(reason: String)
  restart_current_phase()
```

### 5.4 Phase Panel Architecture

**Base Class**: `BasePhasePanel.gd` (extends FiveParsecsCampaignPanel)
**Shared Pattern**:
```gdscript
signal phase_completed(phase_data: Dictionary)

func _on_phase_complete()
  → Validates phase requirements
  → Emits phase_completed({"phase": ENUM, "turn_data": {...}})
  → CampaignTurnController receives & routes to CampaignPhaseManager
```

**Panel Responsibilities**:
1. Display phase-specific UI & options
2. Handle user interactions
3. Call external systems (battle, character creation, etc.) as needed
4. Emit phase_completed when done

### 5.5 Turn Loop Continuity

```
CampaignTurnController.advance_turn()
  → Sets current_phase = 0 (STORY)
  → Shows StoryPhasePanel
  
StoryPhasePanel.phase_completed(data)
  → CampaignTurnController._on_phase_completed(data)
  → CampaignPhaseManager.advance_to_next_phase(data)
  → current_phase = 1 (TRAVEL)
  → Shows TravelPhasePanel
  
[Loop continues through phases 2-8]

RetirementPhasePanel.phase_completed(data)
  → turn_number += 1
  → Resets to phase 0
  → Continues for next turn (or campaign_over signal)
```

---

## 6. SETTINGS & ACCESSIBILITY SYSTEM

**Controller**: `SettingsScreen.gd` (58 lines, extends Control)
**Scene**: res://src/ui/dialogs/SettingsDialog.tscn (alias: `settings` router key)
**Navigation**: Back button → `SceneRouter.navigate_back()` → previous screen

### 6.1 ThemeManager Autoload

**Location**: `src/ui/managers/ThemeManager.gd`
**Type**: Autoload singleton
**Enum**: `ThemeVariant` with 6 variants

```gdscript
enum ThemeVariant {
  DARK = 0,                           # Default deep space theme
  LIGHT = 1,                          # Light variant
  HIGH_CONTRAST = 2,                  # High contrast (low vision)
  COLORBLIND_DEUTERANOPIA = 3,        # Red-green colorblind (most common)
  COLORBLIND_PROTANOPIA = 4,          # Red colorblind
  COLORBLIND_TRITANOPIA = 5           # Blue-yellow colorblind (rare)
}
```

### 6.2 AccessibilitySettingsPanel

**File**: `src/ui/screens/settings/AccessibilitySettingsPanel.gd` (212 lines, extends PanelContainer)
**Pattern**: Dynamically created by SettingsScreen._setup_accessibility_panel()

**UI Components**:
1. **Title**: "Accessibility Settings" (24pt font)
2. **Theme Dropdown**: OptionButton with 6 items
   - "Dark (Default)"
   - "Light"
   - "High Contrast"
   - "Colorblind: Red-Green (Deuteranopia)"
   - "Colorblind: Red (Protanopia)"
   - "Colorblind: Blue-Yellow (Tritanopia)"
3. **Description Label**: Auto-wrap text explaining selected theme
4. **Color Preview Grid**: 3-column GridContainer showing key colors
5. **Apply Button**: Commits theme selection

### 6.3 Color Preview System

**Colors Previewed**:
- success (green), warning (orange), danger (red)
- health_full, health_mid, health_low

**Color Swatch Design**:
- 120px × 60px PanelContainer
- Colored background (from theme)
- 2px white border
- 8px rounded corners
- Center-aligned label with contrasting text (auto-calculated luminance)

### 6.4 Theme Descriptions (AccessibilityThemes.gd)

**High Contrast Theme**:
- Designed for low vision users
- Maximum saturation & contrast
- Dark backgrounds with bright text

**Deuteranopia Theme** (Red-Green Colorblind):
- Most common colorblindness type (~1% of population)
- Replaces red/green with blue/yellow contrasts
- Uses cyan, blue, yellow, orange, black

**Protanopia Theme** (Red Colorblind):
- Affects red color perception
- Uses blue/yellow/cyan spectrum
- Orange substitutes for red

**Tritanopia Theme** (Blue-Yellow Colorblind):
- Rarest form
- Uses red/blue spectrum
- Green substitutes for yellow

### 6.5 Settings Persistence

**Storage**: User settings persisted via `GameStateManager.settings` Dictionary

```gdscript
_on_disable_tutorial_toggled(button_pressed: bool)
  → game_state_manager.settings["disable_tutorial_popup"] = button_pressed
  → game_state_manager.save_settings()

_on_theme_selected(theme_variant: int)
  → ThemeManager.apply_theme(theme_variant)
  → theme_selected.emit(theme_variant)
```

---

## 7. HELP & LIBRARY SCREEN

**Controller**: (Unknown - file not yet examined)
**Scene**: res://src/ui/help/HelpScreen.tscn
**Router Key**: `help`
**Navigation**: Accessed from MainMenu via "Library" button

### 7.1 Purpose

- Rules reference & game mechanics documentation
- Tutorial links
- Help resources for new players
- Compendium information (if DLC enabled)

### 7.2 Expected UI Structure

(To be documented after screen examination)

---

## 8. BUG HUNT GAMEMODE (Separate Campaign Type)

**Screens**: 3 dedicated scenes
**Campaign Core**: `BugHuntCampaignCore` (separate Resource from FiveParsecsCampaignCore)
**Phase Structure**: 3-phase turn (vs 9-phase standard campaign)

### 8.1 Bug Hunt Creation Wizard (4 Phases)

**Scene**: res://src/ui/screens/bug_hunt/BugHuntCreationUI.tscn
**Router Key**: `bug_hunt_creation`

| Phase | Panel | Purpose |
|---|---|---|
| 1 | SpecialAssignmentsPanel | Create special assignment squad |
| 2 | CrewSelectionPanel | Select/create crew for mission |
| 3 | EquipmentPanel | Assign equipment to squad |
| 4 | FinalReviewPanel | Review & finalize Bug Hunt campaign |

### 8.2 Bug Hunt Turn Structure (3 Phases)

**Controller**: res://src/ui/screens/bug_hunt/BugHuntTurnController.tscn
**Router Key**: `bug_hunt_turn_controller`

| Phase | Stage | Purpose |
|---|---|---|
| 1 | SPECIAL_ASSIGNMENTS | Run special assignment missions |
| 2 | BATTLE | Execute tactical battle |
| 3 | POST_BATTLE | Resolve battle results & advancement |

### 8.3 Data Model Differences

| Aspect | Standard 5PFH | Bug Hunt |
|---|---|---|
| Campaign Core | FiveParsecsCampaignCore | BugHuntCampaignCore |
| Crew Storage | `crew_data["members"]` (nested) | `main_characters` / `grunts` (flat Arrays) |
| Has Ship | Yes | No |
| Has Patrons/Rivals | Yes | No |
| Turn Phases | 9 + 5 sub-phases | 3 |
| Battle System | TacticalBattleUI (standard) | TacticalBattleUI (bug_hunt mode) |

### 8.4 Safe Cross-Mode Navigation

**Type Detection**:
```gdscript
GameState._detect_campaign_type()
  → Peeks JSON for "main_characters" key
  → Returns "bug_hunt" or "standard"
  → Used by load_campaign() to route to correct loader
```

**Data Isolation**:
- Bug Hunt temp_data keys prefixed: `"bug_hunt_battle_context"`, `"bug_hunt_mission"`, `"bug_hunt_battle_result"`
- Standard campaign keys: `"world_phase_results"`, `"return_screen"`, `"selected_character"`
- No collision between modes

**TacticalBattleUI Dual Mode**:
```gdscript
if battle_mode == "bug_hunt":
  → Hide morale system
  → Add ContactMarkerPanel
  → Suppress standard pre-battle crew selection
else:
  → Standard 5PFH battle UI
```

### 8.5 Character Transfer Between Modes

**CharacterTransferService.gd**:
- Bidirectional transfer between Bug Hunt ↔ Standard 5PFH
- Enlistment rolls determine success
- Experience & advancement carry over

---

## 9. SCENE CATEGORIZATION HELPERS

**Method**: `SceneRouter.get_scenes_by_category(category: String) → Array[String]`

**9 Categories**:

### Campaign Category (7 scenes)
- campaign_creation
- campaign_setup
- campaign_turn_controller
- campaign_dashboard
- campaign_turn
- main_campaign
- victory_progress

### Character Category (5 scenes)
- character_creator
- character_details
- character_progression
- advancement_manager
- crew_management

### Equipment Category (4 scenes)
- equipment_manager
- equipment_generation
- ship_manager
- ship_inventory

### World Category (5 scenes)
- world_phase
- mission_selection
- patron_rival_manager
- world_phase_summary
- travel_phase

### Battle Category (5 scenes)
- pre_battle
- battlefield_main
- tactical_battle
- post_battle
- post_battle_sequence

### Events Category (1 scene)
- campaign_events

### Phases Category (0 scenes)
(Panels live within phase controllers, not separate scenes)

### Utility Category (4 scenes)
- save_load
- game_over
- logbook
- settings

### Tutorial Category (2 scenes)
- tutorial_selection
- new_campaign_tutorial

---

## 10. COMPLETE NAVIGATION GRAPH

```
START
  ↓
main_menu (MainMenu.gd)
  ├─→ campaign_creation [campaign_wizard: 7 steps]
  │    ├─→ Step 1: CONFIG (ExpandedConfigPanel)
  │    ├─→ Step 2: CAPTAIN_CREATION (CaptainPanel)
  │    ├─→ Step 3: CREW_SETUP (CrewPanel)
  │    ├─→ Step 4: EQUIPMENT_GENERATION (EquipmentPanel)
  │    ├─→ Step 5: SHIP_ASSIGNMENT (ShipPanel)
  │    ├─→ Step 6: WORLD_GENERATION (WorldInfoPanel)
  │    └─→ Step 7: FINAL_REVIEW (FinalPanel)
  │         └─→ campaign_turn_controller [turn_phase: 9 steps]
  │
  ├─→ campaign_turn_controller [resume active campaign]
  │    └─→ TURN LOOP [9 phases per turn]
  │         ├─→ Phase 0: STORY (StoryPhasePanel)
  │         ├─→ Phase 1: TRAVEL (TravelPhasePanel)
  │         ├─→ Phase 2: UPKEEP (UpkeepPhasePanel)
  │         ├─→ Phase 3: MISSION (MissionPhasePanel)
  │         │    ├─→ PRE_MISSION.WORLD (WorldSelection)
  │         │    ├─→ PRE_MISSION.DEPLOYMENT (DeploymentPanel)
  │         │    ├─→ PRE_MISSION.BRIEFING (BriefingPanel)
  │         │    ├─→ PRE_MISSION.BATTLE (TacticalBattleUI)
  │         │    └─→ PRE_MISSION.RETREAT (RetreatPanel)
  │         ├─→ Phase 4: POST_MISSION (PostMissionPhasePanel)
  │         ├─→ Phase 5: ADVANCEMENT (AdvancementPhasePanel)
  │         ├─→ Phase 6: TRADING (TradingPhasePanel)
  │         ├─→ Phase 7: CHARACTER (CharacterPhasePanel)
  │         └─→ Phase 8: RETIREMENT (RetirementPhasePanel)
  │              └─→ [Loop back to Phase 0 for next turn OR campaign_over]
  │
  ├─→ bug_hunt_creation [Bug Hunt 4-step wizard]
  │    ├─→ Phase 1: SpecialAssignmentsPanel
  │    ├─→ Phase 2: CrewSelectionPanel
  │    ├─→ Phase 3: EquipmentPanel
  │    └─→ Phase 4: FinalReviewPanel
  │         └─→ bug_hunt_turn_controller [3-phase turn loop]
  │              ├─→ Phase 1: SPECIAL_ASSIGNMENTS
  │              ├─→ Phase 2: BATTLE (TacticalBattleUI in bug_hunt mode)
  │              └─→ Phase 3: POST_BATTLE
  │
  ├─→ help [HelpScreen.tscn]
  │    └─→ navigate_back() → main_menu
  │
  ├─→ settings [SettingsScreen.gd creates AccessibilitySettingsPanel]
  │    ├─→ Theme Selection (6 variants)
  │    ├─→ Color Preview
  │    └─→ navigate_back() → previous_screen
  │
  └─→ [Other entry points: tutorial_selection, save_load, etc.]


Nested Scene Transitions:

campaign_turn_controller
  ├─→ character_creator [within phase panels]
  ├─→ equipment_manager [within phase panels]
  ├─→ character_details [view/edit character]
  ├─→ pre_battle [mission phase entry]
  │    └─→ tactical_battle [battle execution]
  │         └─→ post_battle [results screen]
  └─→ game_over [on retirement phase end]
       └─→ main_menu [campaign complete]


Scene Context Passing:

navigate_to("campaign_turn_controller", {
  "campaign": campaign_resource,
  "turn_number": current_turn,
  "return_screen": "campaign_dashboard"
})

scene_contexts["campaign_turn_controller"] = {...}
  ↓ [accessed by CampaignTurnController._ready()]
```

---

## 11. TRANSITION & CACHING MECHANICS

### 11.1 TransitionManager Integration

**Called During**: Every `navigate_to(... with_transition: true)`

```gdscript
TransitionManager.create_fade_transition()
  → Fade out previous scene (~250ms)
  → Display new scene
  → Fade in new scene (~250ms)
  → Total transition time: ~500ms
```

### 11.2 Scene Caching (LRU Strategy)

**Cache Management**:
```gdscript
scene_cache: Dictionary = {}
max_cache_size: int = 10

When navigating to a scene:
  1. Check if scene_path in scene_cache
  2. If yes: retrieve cached PackedScene
  3. If no: FileAccess.load(scene_path) → new PackedScene
  4. Add to cache via _add_to_cache()
  5. If cache.size() > 10: evict oldest entry
```

**Performance Impact**:
- Cached scenes instantiate ~50ms faster than disk load
- Campaign creation scenes (7 panels) preloaded for sequential wizard flow
- Top-level campaign screens (dashboard, turn controller) remain cached during gameplay

### 11.3 Preloading Strategy

**Triggered When Entering**:
- campaign_setup
- campaign_creation (preloads all 7 wizard panels)
- character_creator
- equipment_generation
- world_phase
- campaign_dashboard

**Context-Aware**:
- From main_menu → preloads campaign_creation panel sequence
- From campaign_turn_controller → preloads mission-related scenes
- From pre_battle → preloads tactical_battle & post_battle

---

## 12. KEY DESIGN PATTERNS

### 12.1 Signal-Based Phase Completion

**Pattern Used Across**:
- Campaign creation (7 phases)
- Campaign turn (9 phases + 5 sub-phases)
- Bug Hunt creation (4 phases)
- Bug Hunt turn (3 phases)

```gdscript
# In panel:
signal phase_completed(phase_data: Dictionary)

func on_complete_clicked():
  emit_signal("phase_completed", {
    "phase": PHASE_ENUM,
    "valid": validate_requirements(),
    "data": collect_phase_data()
  })

# In controller:
panel.phase_completed.connect(_on_phase_complete)

func _on_phase_complete(data: Dictionary):
  if data["valid"]:
    coordinator.advance_to_next_phase(data)
  else:
    show_error_message()
```

### 12.2 Coordinator State Management

**Used For**:
- Campaign creation (CampaignCreationCoordinator)
- Campaign phases (CampaignPhaseManager)
- Bug Hunt (BugHuntPhaseManager)

```gdscript
# Coordinator tracks:
current_phase: int = 0
phase_state: Dictionary = {}

# Provides:
advance_to_next_phase(data)
go_back_to_previous_phase()
can_advance_to_next_phase() → bool
can_go_back_to_previous_phase() → bool

# Emits:
step_changed(step, total)
navigation_updated(can_back, can_fwd, can_finish)
```

### 12.3 Lambda Adapter Pattern

**Used By**: CampaignCreationUI to adapt typed panel signals to Dictionary format

```gdscript
# Panel emits strongly-typed signal:
captain_panel.captain_updated.emit(captain_character)

# CampaignCreationUI adapts to Dict:
captain_panel.captain_updated.connect(func(captain):
  coordinator.update_captain_state({
    "captain": captain,
    "is_complete": captain != null
  })
)
```

### 12.4 Scene Context Storage

**Pattern**:
```gdscript
# Before navigation:
var context = {
  "campaign": campaign_resource,
  "turn_number": 5,
  "selected_character": character_ref
}

# Navigate:
SceneRouter.navigate_to("target_scene", context)

# In target scene _ready():
var context = SceneRouter.scene_contexts.get("target_scene", {})
campaign = context.get("campaign")
```

---

## 13. BUTTON STATE MANAGEMENT

### 13.1 Campaign Creation Navigation

```
Step 1 (CONFIG):
  Back: "Cancel" (visible) → navigate_back() → main_menu
  Next: Enabled → Phase 2
  Finish: Hidden

Step 2-6 (intermediate phases):
  Back: "Back" (visible) → go_back_to_previous_phase()
  Next: Enabled/Disabled based on phase_completed → next phase
  Finish: Hidden

Step 7 (FINAL):
  Back: "Back" (visible) → go_back_to_previous_phase()
  Next: Hidden
  Finish: Enabled/Disabled based on all_phases_valid → creates campaign
```

### 13.2 Campaign Turn Navigation

(Top-level control: Phase buttons + advance/retreat controls)

```
Each phase:
  Advance Button: Enabled when phase_completed
  Retreat Button: Always visible (allows campaign abort)
  Pause/Save: Always available
  Back to Dashboard: Always available
```

---

## 14. DIALOG & OVERLAY PATTERNS

### 14.1 Dynamic Dialog Creation (MainMenu Pattern)

**Load Campaign Dialog**:
```gdscript
func _on_load_campaign_pressed():
  var dialog = AcceptDialog.new()  # Dynamic creation
  var vbox = VBoxContainer.new()
  
  for campaign in GameState.get_available_campaigns():
    var btn = Button.new()
    btn.text = campaign["name"]
    btn.pressed.connect(_load_campaign.bind(campaign["path"], dialog))
    vbox.add_child(btn)
  
  dialog.add_child(vbox)
  add_child(dialog)
  _active_dialogs.append(dialog)
  dialog.popup_centered()
```

**Cleanup Pattern**:
```gdscript
func _cleanup_dialogs():
  for dialog in _active_dialogs:
    if is_instance_valid(dialog):
      dialog.queue_free()
  _active_dialogs.clear()

func _exit_tree():
  _cleanup_dialogs()
```

### 14.2 FileDialog (Import Campaign)

```gdscript
func _on_import_from_file():
  var file_dialog = FileDialog.new()
  file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
  file_dialog.filters = PackedStringArray([
    "*.save ; Campaign Save Files",
    "*.json ; JSON Files"
  ])
  file_dialog.file_selected.connect(_on_import_file_selected.bind(file_dialog))
  file_dialog.canceled.connect(func(): file_dialog.queue_free())
  
  add_child(file_dialog)
  file_dialog.popup_centered()
```

---

## 15. ERROR HANDLING & FALLBACKS

### 15.1 Null-Safe Navigation

```gdscript
func request_scene_change(scene_name: String):
  var router = get_node_or_null("/root/SceneRouter")
  if not router:
    show_message("Navigation error")
    return
  
  router.navigate_to(scene_map.get(scene_name))
```

### 15.2 Manager Availability

```gdscript
# Check before use:
if is_instance_valid(game_state_manager) and game_state_manager.has_method("method_name"):
  game_state_manager.method_name()

# Fallback to autoload:
var gs = get_node_or_null("/root/GameState")
if gs:
  # Use GameState directly
```

### 15.3 Scene Validation

```gdscript
var missing = SceneRouter.validate_all_scenes()
if missing["missing"].size() > 0:
  push_error("Missing scenes: %s" % missing["missing"])
```

---

## SAVE / RELOAD BEHAVIOR

### Save File Format & Location

- **Extension**: `.fpcs` (JSON)
- **Location**: `user://campaigns/` (resolves to `%APPDATA%/Godot/app_userdata/Five Parsecs Campaign Manager/campaigns/`)
- **Auto-save**: Triggers at turn end via `GameState.save_campaign()`

### Turn Number Persistence (B69/B70 Fix — Mar 12, 2026)

Three-level turn number management:

| Layer | Property | Role |
|-------|----------|------|
| `GameState._turn_number` | Always 1 (unused legacy) | Do not rely on |
| `CampaignPhaseManager.turn_number` | Shadow copy, used by EndPhasePanel for display | Synced from canonical on load |
| `FiveParsecsCampaignCore.progress_data["turns_played"]` | **Canonical** — persisted to save file | Incremented at turn end |

On save: `progress_data["turns_played"]` is written to JSON.
On load: `CampaignTurnController` reads `progress_data["turns_played"]` and syncs it to `CampaignPhaseManager.turn_number`.

### Phase Resume Logic

When a campaign is loaded and `current_phase == NONE`, the system starts a new turn automatically. This ensures that mid-save loads (e.g., saved at turn end) correctly resume at the beginning of the next turn rather than getting stuck in an undefined phase state.

### MCP Testing Workarounds

- **Load Campaign UI**: Dialog does not respond reliably to MCP click events. Use `GameState.load_campaign(path)` programmatically.
- **WorldPhaseController**: Next button sometimes doesn't advance via MCP clicks. Use `_debug_complete_current_step()` + `_advance_to_next_step()`.
- **Save file path**: Campaign saves at `user://campaigns/Campaign_<timestamp>.fpcs`.

---

## SUMMARY

This screen map documents **28 user-facing scenes** across **10 major flow categories**, with detailed information on:

✓ Scene routing authority (SceneRouter.gd SCENE_PATHS)
✓ Navigation infrastructure (history, caching, context storage)
✓ Campaign creation 7-phase wizard
✓ Campaign turn 9-phase + 5-sub-phase loop
✓ Settings & 6-variant accessibility themes
✓ Help/library access
✓ Bug Hunt 3-phase separate gamemode
✓ Complete navigation graph
✓ Signal patterns & coordinator architecture
✓ Transition & caching mechanics
✓ Error handling & null-safety patterns
✓ Save/reload behavior & turn number persistence

All screen transitions flow through **SceneRouter.navigate_to()** with integrated TransitionManager fade effects, LRU scene caching, and per-scene context storage for state management.
