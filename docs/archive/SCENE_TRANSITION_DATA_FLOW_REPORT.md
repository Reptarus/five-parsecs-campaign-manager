# Scene Transition Data Flow Report: Campaign Creation → MainCampaignScene

**Analysis Date**: 2026-01-02
**Scope**: Data handoff from CampaignCreationUI → MainCampaignScene → CampaignTurnController
**Status**: CRITICAL GAPS IDENTIFIED

---

## Executive Summary

The transition from Campaign Creation Wizard to MainCampaignScene has **significant gaps** in data flow and initialization. Critical campaign data is stored in GameState metadata but **never properly retrieved** by downstream systems.

### Critical Issues Identified
1. **Missing GameState.initialize_new_campaign() implementation**
2. **CampaignPhaseManager has NO campaign reference**
3. **Phase controllers (Travel/World/Battle) never receive campaign data**
4. **Race condition in MainCampaignScene signal connections**
5. **CampaignTurnController initializes with stale state**

---

## Data Flow Trace

### STEP 1: Campaign Creation Completion (CampaignCreationUI.gd)

**Location**: `/src/ui/screens/campaign/CampaignCreationUI.gd`

#### What Happens on Finish

```gdscript
// Line 1760: _on_finish_pressed()
func _on_finish_pressed() -> void:
    // Validation occurs
    var campaign_data = _compile_final_campaign_data()

    // CRITICAL: Data stored in GameState metadata
    // Line 2277 (via _on_campaign_finalization_complete_from_panel)
    if AutoloadManager:
        var game_state = AutoloadManager.get_autoload_safe("GameState")
        if game_state:
            game_state.set_meta("pending_campaign_data", data)

    // CRITICAL: Signal emitted (but likely NO listeners yet)
    campaign_completion_ready.emit(data)

    // CRITICAL: Scene transition initiated
    _transition_to_campaign_scene(data)
        -> get_tree().change_scene_to_file(scene_path)
```

#### Campaign Data Structure
```gdscript
{
    "campaign_name": "Test Campaign",
    "campaign_config": {
        "difficulty": 1,
        "victory_condition": 0,
        "use_story_track": true,
        "house_rules": []
    },
    "captain": {
        "character_data": { /* captain details */ }
    },
    "crew": {
        "members": [ /* crew member data */ ]
    },
    "equipment": {
        "starting_credits": 1000,
        "items": []
    },
    "ship": {
        "name": "Aurora",
        "ship_type": "Light Freighter"
    },
    "world": {
        "name": "New Hope",
        "world_type": 1
    }
}
```

**Data Storage Location**: `GameState.set_meta("pending_campaign_data", campaign_data)`

---

### STEP 2: MainCampaignScene Initialization (MainCampaignScene.gd)

**Location**: `/src/ui/screens/campaign/MainCampaignScene.gd`

#### _ready() Sequence

```gdscript
// Line 27-39: _ready()
func _ready() -> void:
    _initialize_autoloads()           // ✅ Loads autoload references
    _setup_ui_components()            // ✅ Hides error display
    _connect_campaign_signals()       // ⚠️ RACE CONDITION (see below)
    _validate_dependencies()          // ✅ Checks for required nodes
    _check_for_pending_campaign_data() // ❌ CRITICAL GAP
```

#### Race Condition: Signal Connection

```gdscript
// Line 95-96: Attempts to connect to CampaignCreationUI
func _connect_to_campaign_creation_ui() -> void:
    var creation_ui = _find_campaign_creation_ui()
    // ❌ PROBLEM: CampaignCreationUI no longer in scene tree!
    // Scene has already changed via get_tree().change_scene_to_file()
```

**Issue**: By the time MainCampaignScene._ready() runs, CampaignCreationUI has been removed from the scene tree. Signal connection **always fails**.

#### Critical Method: _check_for_pending_campaign_data()

```gdscript
// Line 116-125
func _check_for_pending_campaign_data() -> void:
    if GameState and GameState.has_meta("pending_campaign_data"):
        var campaign_data = GameState.get_meta("pending_campaign_data")
        GameState.set_meta("pending_campaign_data", null)

        print("Found pending campaign data, starting new campaign")
        start_new_campaign(campaign_data) // ✅ This DOES run
```

**Status**: ✅ This works - campaign data IS retrieved

---

### STEP 3: start_new_campaign() - Data Initialization

**Location**: `/src/ui/screens/campaign/MainCampaignScene.gd` (Line 189-206)

```gdscript
func start_new_campaign(campaign_data: Dictionary) -> void:
    current_campaign = _create_campaign_resource(campaign_data)
    campaign_active = true

    // ❌ CRITICAL GAP: This method does NOT exist
    _initialize_campaign_systems(campaign_data)

    _show_campaign_interface()

    // ✅ Triggers CampaignTurnController
    if campaign_turn_controller:
        campaign_turn_controller.start_new_campaign_turn()
```

#### _create_campaign_resource() Analysis

```gdscript
// Line 240-248
func _create_campaign_resource(campaign_data: Dictionary) -> Resource:
    var campaign_resource = preload("res://src/core/campaign/Campaign.gd").new()

    // ✅ This method EXISTS and works
    campaign_resource.initialize_from_dict(campaign_data)

    return campaign_resource
```

**Status**: ✅ Campaign resource is created successfully

---

### STEP 4: _initialize_campaign_systems() - THE CRITICAL GAP

**Location**: `/src/ui/screens/campaign/MainCampaignScene.gd` (Line 260-272)

```gdscript
func _initialize_campaign_systems(campaign_data: Dictionary) -> void:
    // ❌ CRITICAL: GameState.initialize_new_campaign() does NOT EXIST
    if GameState:
        GameState.initialize_new_campaign(campaign_data)

    // ❌ CRITICAL: CampaignManager.start_new_campaign() does NOT EXIST
    if CampaignManager:
        CampaignManager.start_new_campaign(campaign_data)

    // ❌ CRITICAL: CharacterManagerAutoload.initialize_for_campaign() does NOT EXIST
    if CharacterManagerAutoload:
        CharacterManagerAutoload.initialize_for_campaign(campaign_data)
```

**Analysis**:

#### GameState.initialize_new_campaign() - MISSING

**Expected Location**: `/src/core/state/GameState.gd`
**Search Result**: Method does NOT exist

**Available Methods**:
- `start_new_campaign(campaign: Variant)` - Exists at line 1064, but signature is WRONG
  - Expected: `start_new_campaign(campaign_data: Dictionary)`
  - Actual: `start_new_campaign(campaign: Variant)`
  - Sets `_current_campaign = campaign` (expects Resource, not Dictionary)

**What Should Happen**:
```gdscript
func initialize_new_campaign(campaign_data: Dictionary) -> void:
    // Create Campaign resource from dictionary
    _current_campaign = FiveParsecsCampaign.new()
    _current_campaign.initialize_from_dict(campaign_data)

    // Initialize turn counter
    turn_number = 1

    // Set initial reputation
    var config = campaign_data.get("campaign_config", {})
    reputation = config.get("starting_reputation", 0)

    // Initialize crew from campaign data
    // Initialize resources
    // Emit signals
```

#### CampaignManager.start_new_campaign() - MISSING

**Expected Location**: `/src/core/managers/CampaignManager.gd`
**Search Result**: Method does NOT exist

**Available Methods** (from GameStateManager.gd):
- `GameStateManager.start_new_campaign(campaign_config: Dictionary)` exists at line 847
  - But MainCampaignScene calls `CampaignManager.start_new_campaign()`
  - **Wrong autoload target**

---

### STEP 5: CampaignTurnController Initialization - STALE STATE

**Location**: `/src/ui/screens/campaign/CampaignTurnController.gd`

#### _ready() Sequence

```gdscript
// Line 34-44
func _ready() -> void:
    _validate_dependencies()
    _connect_core_signals()
    _initialize_ui_state()

    _initialize_backend_systems()

    // ❌ PROBLEM: game_state.get_campaign_turn() returns 0
    // because GameState was never properly initialized
    if game_state.get_campaign_turn() == 0:
        start_new_campaign_turn()
```

#### _initialize_ui_state() - Uses Stale Data

```gdscript
// Line 102-108
func _initialize_ui_state() -> void:
    var current_phase = campaign_phase_manager.get_current_phase()
    var turn_number = campaign_phase_manager.get_turn_number()

    _update_turn_display(turn_number)
    _show_phase_ui(current_phase)
```

**Problem**: `campaign_phase_manager.get_turn_number()` returns 0 because CampaignPhaseManager was never given campaign data.

---

### STEP 6: CampaignPhaseManager - NO CAMPAIGN REFERENCE

**Expected Location**: `/src/autoload/CampaignPhaseManager.gd` (not analyzed in detail yet)

**Critical Question**: Does CampaignPhaseManager have:
- A `current_campaign` reference?
- A `set_campaign()` method?
- A way to receive campaign data from MainCampaignScene?

**From grep results**: No `set_campaign` or `initialize` methods found.

**Implication**: CampaignPhaseManager operates independently of campaign data, which means:
- Phase transitions work generically
- But no campaign-specific data flows through phases
- Phase handlers (Travel/World/Battle) have no context

---

## Missing Data Handoffs - Complete Chain

### Where Data Gets Lost

```
CampaignCreationUI
    ↓ (stores in GameState metadata) ✅
    ↓
MainCampaignScene._ready()
    ↓ (retrieves from metadata) ✅
    ↓ (_create_campaign_resource) ✅
    ↓
MainCampaignScene._initialize_campaign_systems()
    ↓ (calls GameState.initialize_new_campaign) ❌ METHOD MISSING
    ↓ (calls CampaignManager.start_new_campaign) ❌ METHOD MISSING
    ↓ (calls CharacterManagerAutoload.initialize_for_campaign) ❌ METHOD MISSING
    ↓
CampaignTurnController._ready()
    ↓ (reads game_state.get_campaign_turn()) ❌ RETURNS 0 (stale)
    ↓ (reads campaign_phase_manager.get_current_phase()) ❌ RETURNS 0 (stale)
    ↓
Phase Controllers (Travel/World/Battle)
    ❌ NEVER RECEIVE CAMPAIGN DATA
```

---

## Autoload Dependencies - What's Missing

### GameState (src/core/state/GameState.gd)

**Missing Methods**:
```gdscript
func initialize_new_campaign(campaign_data: Dictionary) -> void
```

**Current Broken Method**:
```gdscript
// Line 1064 - WRONG SIGNATURE
func start_new_campaign(campaign: Variant) -> void:
    _current_campaign = campaign  // Expects Resource, gets Dictionary
```

**Required Fix**:
```gdscript
func initialize_new_campaign(campaign_data: Dictionary) -> void:
    # Create campaign resource
    if FiveParsecsCampaign:
        _current_campaign = FiveParsecsCampaign.new()
        _current_campaign.initialize_from_dict(campaign_data)

    # Initialize game state
    turn_number = 1
    var config = campaign_data.get("campaign_config", {})
    reputation = config.get("starting_reputation", 0)
    difficulty_level = config.get("difficulty", 1)
    use_story_track = config.get("use_story_track", true)

    # Emit signals
    _emit_campaign_loaded(_current_campaign)
    _emit_state_changed()
```

---

### CampaignPhaseManager (src/autoload/CampaignPhaseManager.gd)

**Missing Properties**:
```gdscript
var current_campaign: FiveParsecsCampaign = null
```

**Missing Methods**:
```gdscript
func set_campaign(campaign: FiveParsecsCampaign) -> void
func get_campaign() -> FiveParsecsCampaign
```

**Required for**:
- Phase handlers to access campaign data
- Turn tracking to sync with campaign state
- World/Battle phases to access crew/ship/resources

---

### Phase Controllers - Initialization Gaps

#### TravelPhaseUI
**Current**: Generic UI panel, no campaign context
**Needed**:
- Campaign destination (current_world)
- Ship data
- Travel events based on campaign state

#### WorldPhaseController
**Current**: Generates missions generically
**Needed**:
- Campaign crew data for mission generation
- Current planet/world type
- Story track progress
- Patron/Rival data

#### BattlePhase
**Current**: Battle system works independently
**Needed**:
- Active crew for deployment
- Ship weapons/hull points
- Mission context from world phase

---

## Race Conditions

### Signal Connection Timing

**Problem**: MainCampaignScene attempts to connect to CampaignCreationUI signals after scene change

```gdscript
// MainCampaignScene.gd Line 129
func _connect_to_campaign_creation_ui() -> void:
    var creation_ui = _find_campaign_creation_ui()
    // ❌ Always returns null - previous scene already freed
```

**Why It Fails**:
1. CampaignCreationUI calls `get_tree().change_scene_to_file()`
2. Godot queues the scene change
3. CampaignCreationUI emits `campaign_completion_ready` signal
4. Scene change executes, freeing CampaignCreationUI
5. MainCampaignScene._ready() runs
6. Attempts to find CampaignCreationUI → not found

**Solution**: Use GameState metadata (already implemented correctly) instead of signals

---

## Initialization Order Issues

### Current Flow
```
1. MainCampaignScene._ready()
2. MainCampaignScene retrieves campaign_data from GameState metadata ✅
3. MainCampaignScene.start_new_campaign(campaign_data) ✅
4. MainCampaignScene._initialize_campaign_systems() ❌ Calls missing methods
5. CampaignTurnController._ready() runs with stale autoload state ❌
6. CampaignTurnController.start_new_campaign_turn() ❌ No campaign context
```

### Required Flow
```
1. MainCampaignScene._ready()
2. MainCampaignScene retrieves campaign_data from GameState metadata ✅
3. MainCampaignScene.start_new_campaign(campaign_data)
4. GameState.initialize_new_campaign(campaign_data) ✅ NEW METHOD
5. CampaignPhaseManager.set_campaign(campaign_resource) ✅ NEW METHOD
6. GameStateManager.initialize_from_campaign_data() ✅ NEW METHOD
7. CampaignTurnController._ready() reads fresh state ✅
8. CampaignTurnController.start_new_campaign_turn() with context ✅
```

---

## Campaign.gd - Data Initialization

**Location**: `/src/core/campaign/Campaign.gd`

### initialize_from_dict() - EXISTS AND WORKS

```gdscript
// Line 404-453
func initialize_from_dict(creation_data: Dictionary) -> void:
    // Basic info
    campaign_name = creation_data.get("campaign_name", "New Campaign")

    // Config
    var config = creation_data.get("campaign_config", {})
    difficulty = config.get("difficulty", 1)
    victory_condition = config.get("victory_condition", 0)
    use_story_track = config.get("use_story_track", true)

    // Crew
    var crew_section = creation_data.get("crew", {})
    if crew_section.has("members"):
        crew_data = crew_section.get("members", [])
        crew_size = crew_data.size()

        // Creates Character resources
        crew_members.clear()
        for member_data in crew_data:
            var character = Character.new()
            character.initialize_from_creation_data(member_data)
            crew_members.append(character)

    // Captain
    var captain_section = creation_data.get("captain", {})
    captain = Character.new()
    captain.initialize_from_creation_data(captain_section.get("character_data", {}))

    // Resources
    var equipment_section = creation_data.get("equipment", {})
    var starting_credits = equipment_section.get("starting_credits", 1000)
    resources = {
        "credits": starting_credits,
        "supplies": 5,
        "story_points": 0
    }

    // World
    var world_section = creation_data.get("world", {})
    current_world = world_section.get("name", "New Hope")
```

**Status**: ✅ This method works correctly. Campaign resource IS properly initialized.

**Problem**: Campaign resource is created in MainCampaignScene but NEVER passed to:
- GameState._current_campaign
- CampaignPhaseManager
- Phase controllers

---

## Summary of Gaps

### Data That Transfers Successfully
1. ✅ Campaign creation data stored in `GameState.set_meta("pending_campaign_data")`
2. ✅ MainCampaignScene retrieves data from metadata
3. ✅ Campaign resource created via `Campaign.initialize_from_dict()`

### Data That Fails to Transfer
1. ❌ Campaign resource never set in `GameState._current_campaign`
2. ❌ Turn number never initialized in GameState
3. ❌ Reputation/difficulty never set in GameState
4. ❌ CampaignPhaseManager has no campaign reference
5. ❌ Phase controllers (Travel/World/Battle) never receive campaign data
6. ❌ CharacterManagerAutoload never initialized with crew

### Missing Autoload Setup
1. ❌ `GameState.initialize_new_campaign(campaign_data: Dictionary)` - DOES NOT EXIST
2. ❌ `CampaignManager.start_new_campaign(campaign_data: Dictionary)` - DOES NOT EXIST (wrong autoload)
3. ❌ `CharacterManagerAutoload.initialize_for_campaign(campaign_data: Dictionary)` - DOES NOT EXIST
4. ❌ `CampaignPhaseManager.set_campaign(campaign: FiveParsecsCampaign)` - DOES NOT EXIST

### Phase Controller Initialization Gaps
1. ❌ TravelPhaseUI has no campaign destination data
2. ❌ WorldPhaseController has no crew/planet/patron data
3. ❌ BattlePhase has no active crew/ship data
4. ❌ PostBattlePhase has no crew injury/XP context

### Race Conditions
1. ❌ MainCampaignScene attempts to connect to CampaignCreationUI signals after scene freed
2. ⚠️ CampaignTurnController._ready() runs before GameState is initialized

---

## Required Fixes - Priority Order

### Priority 1: Critical Path (BLOCKER)

**Fix 1: Create GameState.initialize_new_campaign()**
```gdscript
// Location: src/core/state/GameState.gd
func initialize_new_campaign(campaign_data: Dictionary) -> void:
    # Create campaign resource from dictionary
    if FiveParsecsCampaign:
        _current_campaign = FiveParsecsCampaign.new()
        _current_campaign.initialize_from_dict(campaign_data)

    # Initialize game state properties
    turn_number = 1
    var config = campaign_data.get("campaign_config", {})
    reputation = config.get("starting_reputation", 0)
    difficulty_level = config.get("difficulty", 1)
    use_story_track = config.get("use_story_track", true)
    enable_permadeath = config.get("permadeath", true)

    # Initialize resources
    var equipment = campaign_data.get("equipment", {})
    credits = equipment.get("starting_credits", 1000)

    # Initialize world
    var world = campaign_data.get("world", {})
    current_world = world.get("name", "New Hope")

    # Emit signals
    _emit_campaign_loaded(_current_campaign)
    _emit_state_changed()
    print("GameState: New campaign initialized - %s" % _current_campaign.campaign_name)
```

**Fix 2: Add CampaignPhaseManager.set_campaign()**
```gdscript
// Location: src/autoload/CampaignPhaseManager.gd
var current_campaign: FiveParsecsCampaign = null

func set_campaign(campaign: FiveParsecsCampaign) -> void:
    current_campaign = campaign
    print("CampaignPhaseManager: Campaign set - %s" % campaign.campaign_name)

func get_campaign() -> FiveParsecsCampaign:
    return current_campaign
```

**Fix 3: Update MainCampaignScene._initialize_campaign_systems()**
```gdscript
// Location: src/ui/screens/campaign/MainCampaignScene.gd
func _initialize_campaign_systems(campaign_data: Dictionary) -> void:
    # Initialize GameState with campaign data
    if GameState:
        GameState.initialize_new_campaign(campaign_data)

    # Pass campaign resource to CampaignPhaseManager
    var campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")
    if campaign_phase_manager and current_campaign:
        campaign_phase_manager.set_campaign(current_campaign)

    # Initialize CharacterManagerAutoload if needed
    if CharacterManagerAutoload and CharacterManagerAutoload.has_method("initialize_from_campaign"):
        CharacterManagerAutoload.initialize_from_campaign(current_campaign)
```

### Priority 2: Phase Controller Data Flow

**Fix 4: CampaignTurnController - Defer initialization**
```gdscript
// Location: src/ui/screens/campaign/CampaignTurnController.gd
func _ready() -> void:
    _validate_dependencies()
    _connect_core_signals()

    # Defer initialization to ensure GameState is ready
    call_deferred("_initialize_after_campaign_load")

func _initialize_after_campaign_load() -> void:
    await get_tree().process_frame  # Wait for autoloads to sync

    _initialize_ui_state()
    _initialize_backend_systems()

    # Only start turn if campaign is actually new
    if game_state.get_campaign_turn() == 0:
        start_new_campaign_turn()
```

### Priority 3: Phase Handler Context

**Fix 5: Pass campaign data to phase controllers**
```gdscript
// Location: src/ui/screens/campaign/CampaignTurnController.gd
func _show_phase_ui(phase: int) -> void:
    _hide_all_phase_uis()

    # Get campaign from CampaignPhaseManager
    var campaign = campaign_phase_manager.get_campaign()

    match phase:
        GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
            travel_phase_ui.show()
            if travel_phase_ui.has_method("initialize_with_campaign"):
                travel_phase_ui.initialize_with_campaign(campaign)
            current_ui_phase = travel_phase_ui

        GlobalEnums.FiveParsecsCampaignPhase.WORLD:
            world_phase_controller.show()
            if world_phase_controller.has_method("initialize_with_campaign"):
                world_phase_controller.initialize_with_campaign(campaign)
            current_ui_phase = world_phase_controller
            _trigger_world_phase_backend_integration()
```

---

## Testing Checklist

### Verify Data Transfer
- [ ] Campaign data reaches GameState._current_campaign
- [ ] Turn number initialized to 1
- [ ] Credits match starting_credits from creation
- [ ] Crew members loaded into GameState
- [ ] Captain set correctly
- [ ] World name set from creation data

### Verify Autoload Setup
- [ ] CampaignPhaseManager has campaign reference
- [ ] Phase controllers can access campaign data
- [ ] Battle system receives active crew
- [ ] World phase has patron/rival data

### Verify Phase Flow
- [ ] Travel phase shows correct destination
- [ ] World phase generates missions with crew context
- [ ] Battle phase loads active crew for deployment
- [ ] Post-battle XP awards apply to correct characters

---

## Architectural Recommendation

**Current Architecture** (broken):
```
CampaignCreationUI → (metadata) → MainCampaignScene → (missing methods) → autoloads
```

**Recommended Architecture**:
```
CampaignCreationUI
    ↓ (metadata)
GameState.initialize_new_campaign()
    ↓ (campaign resource)
CampaignPhaseManager.set_campaign()
    ↓ (campaign context)
CampaignTurnController (reads from autoloads)
    ↓ (campaign context)
Phase Controllers
```

**Key Principle**: Autoloads are the source of truth. UI retrieves data from autoloads, never stores critical state locally.

---

**Next Steps**:
1. Implement `GameState.initialize_new_campaign(campaign_data: Dictionary)`
2. Add `CampaignPhaseManager.set_campaign(campaign: FiveParsecsCampaign)`
3. Update `MainCampaignScene._initialize_campaign_systems()` to call new methods
4. Defer `CampaignTurnController` initialization to avoid race conditions
5. Add `initialize_with_campaign()` methods to phase controllers

**Estimated Effort**: 4-6 hours to implement all fixes + 2 hours testing
