# Campaign Dashboard Data Integration Specification

**Author**: Campaign Data Architect
**Date**: 2025-11-28
**Version**: 1.0
**Status**: SPECIFICATION

---

## Executive Summary

This specification maps the modernized CampaignDashboard UI (from `screenshot/mockup.html`) to existing data sources in the Five Parsecs Campaign Manager codebase. The goal is to ensure that every UI component has a clear data source, signal connection, and update pattern following the **call-down-signal-up** architecture.

---

## 1. DATA SOURCE INVENTORY

### 1.1 Core State Management

**Primary Data Source**: `GameStateManager` (autoload singleton)
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/managers/GameStateManager.gd`

**Key Methods**:
- `get_campaign_phase() -> int` - Current phase (Travel/World/Battle/Post-Battle)
- `get_campaign_turn() -> int` - Current turn number
- `get_credits() -> int` - Available credits
- `get_story_progress() -> int` - Story points accumulated
- `get_crew_members() -> Array` - Active crew roster
- `get_patrons() -> Array` - Active patrons
- `get_rivals() -> Array` - Active rivals
- `get_quest_rumors() -> int` - Available quest rumors count
- `get_pending_events() -> Array` - Deferred events queue
- `get_player_ship() -> Dictionary` - Ship data (hull, fuel, debt)
- `get_current_location() -> Dictionary` - Current planet/location

**Signals**:
- `campaign_phase_changed(new_phase: int)`
- `credits_changed(new_amount: int)`
- `story_progress_changed(new_amount: int)`
- `state_changed()`

### 1.2 Character Data

**Resource Class**: `Character`
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/character/Character.gd`

**Properties**:
- `name: String` - Character display name
- `background: String` - Origin background (e.g., "MILITARY", "TRADER")
- `motivation: String` - Character motivation (e.g., "WEALTH", "SURVIVAL")
- `character_class: String` - Class type (e.g., "BASELINE", "VETERAN")
- `reactions: int` (REA stat)
- `speed: int` (SPD stat in inches)
- `combat: int` (CBT stat - modifier)
- `toughness: int` (TGH stat)
- `savvy: int` (SAV stat - modifier)
- `luck: int` - Luck modifier
- `experience: int` - XP accumulated
- `equipment: Array[String]` - Equipped items
- `health: int` / `max_health: int` - Current and maximum health

**Methods**:
- `to_dictionary() -> Dictionary` - UI-ready data structure

### 1.3 Mission/Quest Data

**Quest Data Location**: Stored in `GameState.active_quests` (Array[Dictionary])

**Quest Dictionary Structure**:
```gdscript
{
  "id": String,
  "name": String,
  "type": String,
  "progress": int,
  "target": int,
  "description": String
}
```

**Mission Data**: (Future implementation - currently missing)
- No dedicated Mission resource found
- Mission data likely stored as Dictionary in campaign state
- **GAP IDENTIFIED**: Mission objective/reward structure needs definition

### 1.4 World/Location Data

**Resource Class**: `Location`
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/world/Location.gd`

**Expected Properties** (from GameStateManager usage):
- `name: String` - Planet name
- `type: String` - Planet type (e.g., "Frontier World", "Industrial Hub")
- `traits: Array` - World traits (e.g., ["Trade Center", "Pirate Activity"])
- `invasion_threat: int` - Invasion threat level

### 1.5 Story Track Data

**System**: `StoryTrackSystem`
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/core/story/StoryTrackSystem.gd`

**Data**: Managed through GameStateManager
- Active quest progress (via `GameStateManager.get_active_quest()`)
- Story clock ticks (via `GameStateManager.get_story_progress()`)
- Available rumors (via `GameStateManager.get_quest_rumors()`)

---

## 2. UI COMPONENT TO DATA SOURCE MAPPING

### 2.1 Campaign Turn Progress Tracker (7-Step Breadcrumb)

**UI Section**: Top campaign progress bar with 7 phase indicators

**Data Source**:
```gdscript
# Current phase
var current_phase: int = GameStateManager.get_campaign_phase()

# Turn number
var turn_number: int = GameStateManager.get_campaign_turn()
```

**Phase Enum Mapping** (from GameState.gd):
```gdscript
GlobalEnums.FiveParsecsCampaignPhase:
  NONE = 0
  SETUP = 1
  TRAVEL = 2
  WORLD = 3
  BATTLE = 4
  POST_BATTLE = 5
```

**Update Pattern**:
- **Signal**: `GameStateManager.campaign_phase_changed(new_phase: int)`
- **Handler**: `_update_campaign_progress_tracker()`
- **Implementation**: Already exists in `CampaignDashboard.gd` (lines 596-685)

**Status**: ✅ **IMPLEMENTED** (current implementation uses 4 phases, mockup shows 7 - requires expansion)

---

### 2.2 Active Crew Display (Character Cards)

**UI Section**: Horizontal scroll cards showing crew members

**Data Source**:
```gdscript
var crew_members: Array = GameStateManager.get_crew_members()
```

**Character Data Structure** (from Character.to_dictionary()):
```gdscript
{
  "character_name": String,
  "status": String,
  "background": String,
  "reactions": int,  # REA stat
  "speed": int,      # SPD stat (movement in inches)
  "combat": int,     # CBT modifier (+0, +1, +2, etc.)
  "toughness": int,  # TGH stat (3-6)
  "savvy": int,      # SAV modifier
  "luck": int,
  "experience": int,
  "equipment": Array[String],
  "health": int,
  "max_health": int
}
```

**UI Component**: `CharacterCard.tscn`
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/character/CharacterCard.tscn`

**Update Pattern**:
- **Signal**: `GameStateManager.state_changed()`
- **Handler**: `_update_crew_list()`
- **Implementation**: Lines 290-383 in CampaignDashboard.gd

**Status**: ✅ **IMPLEMENTED** (tested in Session 2 - displays crew correctly)

---

### 2.3 Current Mission Card

**UI Section**: Mission panel showing active mission/patron job

**Data Source**:
```gdscript
# Current implementation (from CampaignDashboard.gd)
var active_quest: Dictionary = GameStateManager.get_active_quest()

# Expected mission data structure (CURRENTLY MISSING):
{
  "mission_name": String,
  "patron": String,
  "mission_type": String,  # e.g., "Patrol", "Defense", "Opportunity"
  "objective": String,     # e.g., "Patrol", "Move", "Fight Off"
  "objective_details": String,  # Full objective description
  "rewards": {
    "credits": int,
    "reputation": int,
    "loot_rolls": int,
    "story_points": int
  }
}
```

**Update Pattern**:
- **Signal**: `GameStateManager.state_changed()`
- **Handler**: `_update_quest_info()` (current implementation - line 498)
- **Recommended**: Rename to `_update_mission_info()` for clarity

**Status**: ⚠️ **PARTIAL** (quest system exists, but mission structure incomplete)

**GAP IDENTIFIED**:
- Need dedicated Mission resource class
- Mission objective enum (PATROL, DEFEND, MOVE, etc.)
- Mission reward calculator
- Patron-mission relationship

---

### 2.4 World Status Card

**UI Section**: Current planet info with traits and invasion threat

**Data Source**:
```gdscript
var current_location: Dictionary = GameStateManager.get_current_location()
```

**Expected Data Structure**:
```gdscript
{
  "name": String,           # e.g., "Nexus Prime"
  "type": String,           # e.g., "Frontier World • Industrial Hub"
  "traits": Array[String],  # e.g., ["Trade Center", "Moderate Law", "Pirate Activity"]
  "invasion_threat": int    # 0-10 scale
}
```

**Update Pattern**:
- **Signal**: `GameStateManager.state_changed()`
- **Handler**: `_update_world_info()` (line 479)
- **Implementation**: Already exists

**Status**: ✅ **IMPLEMENTED**

---

### 2.5 Story Track Panel

**UI Section**: Active quest progress + available rumors

**Data Sources**:
```gdscript
# Active quest
var active_quest: Dictionary = GameStateManager.get_active_quest()

# Story clock
var story_clock: int = GameStateManager.get_story_progress()

# Available rumors
var rumors_count: int = GameStateManager.get_quest_rumors()
```

**Expected Active Quest Structure**:
```gdscript
{
  "id": String,
  "name": String,
  "description": String,
  "progress": int,
  "required_progress": int,
  "type": String  # e.g., "character", "patron", "rival"
}
```

**Rumor Structure** (future implementation):
```gdscript
{
  "id": String,
  "title": String,
  "description": String,
  "type": String  # "quest_lead", "patron_opportunity", "information"
}
```

**Update Pattern**:
- **Signal**: `GameStateManager.story_progress_changed(new_amount: int)`
- **Handler**: `_update_story_track()`

**Status**: ⚠️ **PARTIAL** (quest display exists, rumors display incomplete)

---

### 2.6 Quick Resources (Credits, Story Points, Rumors)

**UI Section**: Top-right resource badges

**Data Sources**:
```gdscript
# Credits
var credits: int = GameStateManager.get_credits()

# Story Points
var story_points: int = GameStateManager.get_story_progress()

# Quest Rumors
var rumors: int = GameStateManager.get_quest_rumors()
```

**Update Pattern**:
- **Signals**:
  - `GameStateManager.credits_changed(new_amount: int)`
  - `GameStateManager.story_progress_changed(new_amount: int)`
  - `GameStateManager.state_changed()`
- **Handlers**:
  - `_update_credits_display()`
  - `_update_story_points_display()`
  - `_update_rumors_display()`

**Status**: ✅ **IMPLEMENTED** (lines 124-191 in CampaignDashboard.gd)

---

## 3. SIGNAL ARCHITECTURE

### 3.1 Call-Down-Signal-Up Pattern

**Principle**: UI components receive data from above (call-down) and emit user actions upward (signal-up).

**Data Flow**:
```
GameStateManager (Source of Truth)
       ↓ (call method)
CampaignDashboard (_update_ui)
       ↓ (call method)
CharacterCard (set_character)
       ↑ (signal)
CampaignDashboard (_on_character_card_tapped)
       ↑ (signal/method call)
GameStateManager (state change)
```

### 3.2 Required Signal Connections

**GameStateManager Signals**:
```gdscript
# Already implemented in GameStateManager.gd
signal campaign_phase_changed(new_phase: int)
signal credits_changed(new_amount: int)
signal story_progress_changed(new_amount: int)
signal state_changed()

# Recommended additions:
signal crew_member_added(character: Character)
signal crew_member_removed(character_id: String)
signal mission_accepted(mission: Dictionary)
signal mission_completed(mission: Dictionary)
signal location_changed(location: Dictionary)
```

**CampaignDashboard Signal Handlers** (to implement):
```gdscript
func _ready() -> void:
    # Connect to GameStateManager signals
    if GameStateManager:
        GameStateManager.campaign_phase_changed.connect(_on_phase_changed)
        GameStateManager.credits_changed.connect(_on_credits_changed)
        GameStateManager.story_progress_changed.connect(_on_story_progress_changed)
        GameStateManager.state_changed.connect(_update_ui)

        # New connections for enhanced reactivity
        GameStateManager.crew_member_added.connect(_on_crew_member_added)
        GameStateManager.mission_accepted.connect(_on_mission_accepted)
        GameStateManager.location_changed.connect(_on_location_changed)
```

---

## 4. DATA GAPS & REQUIRED IMPLEMENTATIONS

### 4.1 Mission System (HIGH PRIORITY)

**Gap**: No dedicated Mission resource class found

**Required**:
```gdscript
# File: src/core/mission/Mission.gd
class_name Mission
extends Resource

@export var mission_id: String
@export var mission_name: String
@export var patron_name: String
@export var mission_type: String  # PATROL, DEFEND, OPPORTUNITY, etc.
@export var objective: Dictionary = {
    "type": String,  # From GlobalEnums.MissionObjective
    "description": String,
    "target": int,  # If applicable (e.g., enemies to defeat)
    "progress": int
}
@export var rewards: Dictionary = {
    "credits": int,
    "reputation": int,
    "loot_rolls": int,
    "story_points": int
}
@export var difficulty: int  # 1-10 scale
@export var status: String  # AVAILABLE, ACTIVE, COMPLETED, FAILED

func to_dictionary() -> Dictionary:
    return {
        "mission_id": mission_id,
        "mission_name": mission_name,
        "patron": patron_name,
        "mission_type": mission_type,
        "objective": objective,
        "rewards": rewards,
        "difficulty": difficulty,
        "status": status
    }
```

**Integration Point**:
```gdscript
# GameStateManager.gd additions
var active_mission: Mission = null

func get_active_mission() -> Dictionary:
    return active_mission.to_dictionary() if active_mission else {}

func accept_mission(mission: Mission) -> void:
    active_mission = mission
    mission_accepted.emit(mission)
    state_changed.emit()
```

### 4.2 Invasion Threat Tracking

**Gap**: World/Location data incomplete (no invasion_threat property confirmed)

**Required**:
```gdscript
# Location.gd enhancement
@export var invasion_threat: int = 0  # 0-10 scale

func increase_invasion_threat(amount: int) -> void:
    invasion_threat = min(10, invasion_threat + amount)

func decrease_invasion_threat(amount: int) -> void:
    invasion_threat = max(0, invasion_threat - amount)
```

### 4.3 Rumor System

**Gap**: Rumors exist as count, but no detailed rumor data structure

**Required**:
```gdscript
# File: src/core/story/Rumor.gd
class_name Rumor
extends Resource

@export var rumor_id: String
@export var title: String
@export var description: String
@export var rumor_type: String  # QUEST_LEAD, PATRON_OPPORTUNITY, INFORMATION
@export var consumed: bool = false

func to_dictionary() -> Dictionary:
    return {
        "rumor_id": rumor_id,
        "title": title,
        "description": description,
        "rumor_type": rumor_type,
        "consumed": consumed
    }
```

---

## 5. RECOMMENDED DATA BINDING PATTERN

### 5.1 Reactive Updates (Preferred)

**Pattern**: Signal-based updates for immediate UI reactivity

**Implementation**:
```gdscript
# CampaignDashboard.gd
func _ready() -> void:
    _connect_signals()
    _update_ui()  # Initial population

func _connect_signals() -> void:
    if GameStateManager:
        GameStateManager.credits_changed.connect(_on_credits_changed)
        GameStateManager.campaign_phase_changed.connect(_on_phase_changed)
        GameStateManager.state_changed.connect(_update_ui)

func _on_credits_changed(new_amount: int) -> void:
    if credits_label:
        credits_label.text = "%d cr" % new_amount
        _update_credit_color(new_amount)

func _update_credit_color(amount: int) -> void:
    if amount < 100:
        credits_label.modulate = Color.RED
    elif amount < 500:
        credits_label.modulate = Color.YELLOW
    else:
        credits_label.modulate = Color.GREEN
```

### 5.2 Polling (Fallback)

**Use Case**: When signals are not practical (e.g., complex derived data)

**Implementation**:
```gdscript
var _update_timer: Timer

func _ready() -> void:
    _setup_update_timer()

func _setup_update_timer() -> void:
    _update_timer = Timer.new()
    _update_timer.wait_time = 1.0  # Update every 1 second
    _update_timer.timeout.connect(_update_ui)
    add_child(_update_timer)
    _update_timer.start()
```

**Recommendation**: Use reactive signals for critical data (credits, phase, crew), polling for derived/complex data (battle statistics, time-based events).

---

## 6. PERFORMANCE CONSIDERATIONS

### 6.1 Character Card Pooling

**Current Implementation**: Already uses object pooling (line 291-310 in CampaignDashboard.gd)

**Pattern**:
```gdscript
var _character_card_pool: Array[Control] = []

func _update_crew_list() -> void:
    # Reuse cards from pool instead of creating new instances
    for i in range(crew_members.size()):
        var card = _get_or_create_card(i)
        card.set_character(crew_members[i])
```

**Performance Benefit**: Reduces GC pressure, improves frame stability

### 6.2 Debounced Updates

**Use Case**: Prevent excessive UI updates during rapid state changes

**Implementation**:
```gdscript
var _update_debounce_timer: Timer
var _pending_update: bool = false

func _on_state_changed() -> void:
    if not _pending_update:
        _pending_update = true
        _update_debounce_timer.start(0.1)  # 100ms debounce

func _on_debounce_timeout() -> void:
    _pending_update = false
    _update_ui()
```

---

## 7. IMPLEMENTATION PRIORITY

### Phase 1: Critical Data Flow (Week 4 - Immediate)
1. ✅ Fix crew member display (COMPLETED - Session 2)
2. ⚠️ Implement Mission resource class
3. ⚠️ Add mission display to dashboard
4. ✅ Test phase progression signals (COMPLETED)

### Phase 2: Enhanced Reactivity (Week 5)
1. Add granular signals (crew_member_added, mission_accepted, etc.)
2. Implement debounced updates for performance
3. Add invasion threat display
4. Implement rumor detail panel

### Phase 3: Polish & Optimization (Week 6)
1. Optimize character card pooling
2. Add loading states for async data
3. Implement error states for missing data
4. Add data validation layer

---

## 8. DATA INTEGRITY VALIDATIONS

### 8.1 Required Validations

**Before UI Update**:
```gdscript
func _update_ui() -> void:
    # Validate GameStateManager exists
    if not GameStateManager:
        _show_error_state("GameStateManager not available")
        return

    # Validate crew data integrity
    var crew = GameStateManager.get_crew_members()
    if not _validate_crew_data(crew):
        push_warning("CampaignDashboard: Invalid crew data detected")
        crew = []  # Fallback to empty array

    # Proceed with updates
    _update_crew_list()
    _update_resources()
    _update_mission()

func _validate_crew_data(crew: Array) -> bool:
    for member in crew:
        if not member is Character and not member is Dictionary:
            return false
        if member is Dictionary and not member.has("character_name"):
            return false
    return true
```

### 8.2 Graceful Degradation

**Pattern**: Show partial UI when data is incomplete

```gdscript
func _update_mission_info() -> void:
    var mission = GameStateManager.get_active_mission()

    if mission.is_empty():
        mission_panel.hide()  # Hide entire panel if no mission
        return

    mission_panel.show()
    mission_name_label.text = mission.get("mission_name", "Unknown Mission")

    # Gracefully handle missing rewards
    var rewards = mission.get("rewards", {})
    if rewards.has("credits"):
        credits_reward_label.text = "%d cr" % rewards.credits
    else:
        credits_reward_label.text = "Unknown"
```

---

## 9. TESTING RECOMMENDATIONS

### 9.1 Data Flow Tests

**Test**: Verify data flows from GameStateManager to UI

```gdscript
# tests/integration/test_campaign_dashboard_data_flow.gd
func test_crew_display_updates_on_state_change():
    var dashboard = CampaignDashboard.new()
    add_child(dashboard)

    # Simulate state change
    GameStateManager.add_crew_member(Character.new())
    await get_tree().process_frame

    # Verify UI updated
    assert_eq(dashboard.crew_card_container.get_child_count(), 1)
```

### 9.2 Signal Integration Tests

**Test**: Verify signals propagate correctly

```gdscript
func test_credits_changed_signal_updates_ui():
    var dashboard = CampaignDashboard.new()
    add_child(dashboard)

    # Emit signal
    GameStateManager.credits = 500
    GameStateManager.credits_changed.emit(500)
    await get_tree().process_frame

    # Verify UI updated
    assert_eq(dashboard.credits_label.text, "500 cr")
```

---

## 10. CONCLUSION

### Summary

The CampaignDashboard UI mockup can be fully supported by existing data sources with the following work:

**Strengths**:
- ✅ Core state management (GameStateManager) exists
- ✅ Character data model complete and tested
- ✅ Signal architecture foundation in place
- ✅ Crew display working (validated Session 2)

**Critical Gaps**:
- ⚠️ Mission resource class missing (HIGH PRIORITY)
- ⚠️ Rumor detail structure incomplete
- ⚠️ Invasion threat tracking not confirmed

**Recommended Approach**:
1. Implement Mission resource class first (blocks mission card display)
2. Add granular signals to GameStateManager (enables reactive UI)
3. Test data flow with integration tests
4. Optimize performance with pooling and debouncing

### Next Steps

1. **UI Designer**: Use this spec to build dashboard components
2. **Godot Specialist**: Implement Mission resource class
3. **QA Specialist**: Create data flow integration tests
4. **Data Architect**: Review signal architecture and validate patterns

**Estimated Effort**: 4-6 hours for Phase 1 (Mission system + signal wiring)
