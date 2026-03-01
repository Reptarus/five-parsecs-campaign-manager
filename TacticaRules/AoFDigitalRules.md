---
description: Project rules and coding standards for the Age of Fantasy Digital implementation, including game mechanics, file organization, coding standards, state management, and implementation priorities.
globs: ["*.gd", "*.tscn", "*.tres", "*.res", "*.md", "*.json", "*.cfg", "*.import", "src/**/*", "tests/**/*", "assets/**/*", "docs/**/*"]
alwaysApply: true
---

# Age of Fantasy Digital - Project Rules

## Game Mechanics Implementation

### Core Design Philosophy
- **Hybrid Grid/Gridless Approach**:
  - Implement a flexible system that can support both grid-based and gridless movement
  - Use an invisible fine-grained grid (0.25" units) for calculations while rendering without visible grid lines
  - Allow future transition to fully gridless or more pronounced grid-based system based on playtesting
  - Design all systems to be agnostic to the grid/gridless decision where possible

### Core Mechanics
- **Turn-Based System**:
  - Alternating unit activation
  - Each unit takes exactly one action per round
  - Round ends when all units have activated
  - First player alternates each round (player who finished activating units first goes first next round)

- **Actions**:
  - Hold: 0" movement, can shoot
  - Advance: Normal movement, can shoot after moving
  - Rush: 12" movement, can't shoot
  - Charge: 12" movement into melee

- **Unit Stats**:
  - Quality: Used for tests (roll ≥ quality value on D6 for success)
  - Defense: Used to block hits
  - Wounds: Unit's health points
  - Movement: Base movement distance
  - Special Rules: Unit-specific abilities and traits

- **Combat System**:
  - Shooting: Quality test per attack, hits can be blocked with Defense
  - Melee: Similar to shooting but with specific positioning and fatigue rules
  - Morale: Units test morale when reduced to half strength or lose melee
  - Fatigue: After charging or striking back, units hit on 6s only until end of round

### Special Features
- **Terrain Effects**:
  - Cover: +1 to Defense when blocking hits from shooting
  - Difficult Terrain: Max 6" movement
  - Dangerous Terrain: Roll D6, wound on 1

- **Special Rules**:
  - Implement all core special rules (Ambush, AP, Blast, etc.)
  - Command group upgrades (Sergeant, Musician, Banner)

## Directory Structure

- **Source Code Structure**:
  - `src/core/`: Core systems (GameManager, EventBus, StateManager)
  - `src/battle/`: Battle mechanics implementation
    - `src/battle/units/`: Unit functionality and formations
    - `src/battle/actions/`: Action implementations
    - `src/battle/combat/`: Combat resolution and morale
  - `src/ai/`: AI implementation
  - `src/terrain/`: Terrain generation and effects
  - `src/ui/`: User interface components
    - `src/ui/battle_hud/`: In-battle UI
    - `src/ui/unit_info/`: Unit information displays
  - `src/utils/`: Utility functions and helpers
  - `src/debug/`: Debug tools and visualizations
  - `src/scenes/`: Main gameplay scenes
  - `src/resources/`: Data resources and configurations
  - `src/scripts/`: Miscellaneous scripts
  - `src/units/`: Unit implementations and data
  - `src/movement/`: Movement and positioning systems
    - `src/movement/hybrid/`: Hybrid grid/gridless implementation

- **Asset Management**:
  - `assets/models/`: 3D models
  - `assets/textures/`: Textures
  - `assets/materials/`: Materials
  - `assets/audio/`: Sound effects and music
  - `assets/ui/`: UI assets
  - `assets/fonts/`: Font files

- **Documentation**:
  - `docs/implementation_phases.md`: Detailed phase-by-phase implementation plan
  - `docs/prototype_plan.md`: Overall project plan
  - `docs/testing_checklist.md`: Testing procedures
  - `docs/AoFDigitalRules.md`: This file - project standards

## Coding Standards

### GDScript Style
- Use strict typing for all variables and functions:
  ```gdscript
  func resolve_combat(attacker: Unit, defender: Unit, weapon_profile: Dictionary) -> Dictionary:
  ```

- Follow consistent naming conventions:
  - `snake_case` for functions, variables, and filenames
  - `PascalCase` for classes, nodes, and scenes
  - `UPPER_CASE` for constants and enums

- Use enums for state management:
  ```gdscript
  enum BattleState {
      DEPLOYMENT,
      ACTIVATION,
      ACTION,
      END_ROUND
  }
  ```

- Implement proper signal connections with typed callbacks

### Documentation
- Document all classes with class descriptions
- Document all public functions with GDScript doc comments:
  ```gdscript
  ## Resolves combat between two units
  ## @param attacker: The attacking unit
  ## @param defender: The defending unit
  ## @param weapon_profile: Weapon data for attack resolution
  ## @return Dictionary: Combat results including hits, wounds, and morale effects
  func resolve_combat(attacker: Unit, defender: Unit, weapon_profile: Dictionary) -> Dictionary:
  ```

- Include usage examples for complex systems
- Maintain comprehensive README files in major directories

## State Management

### Battle State Machine
- Implement a clear state machine for battle flow:
  1. **SETUP**: Initial setup
  2. **DEPLOYMENT**: Unit deployment
  3. **ACTIVATION**: Unit selection
  4. **ACTION**: Action selection and resolution
  5. **END_ROUND**: Cleanup and objective control

- Track unit states:
  - Activated/Not activated
  - Shaken/Not shaken
  - In melee/Not in melee
  - Fatigued/Not fatigued

- Manage global state:
  - Current round
  - Current player
  - Objective control
  - Victory conditions

### Data Management
- Implement a data-driven approach using Resources for:
  - Unit profiles
  - Weapon stats
  - Special rules
  - Terrain effects

- Use signal-based communication for decoupled systems
- Implement proper save/load functionality for battle states

## UI/UX Standards

### Battle Interface
- Clear indication of:
  - Current phase
  - Current player
  - Active unit
  - Available actions
  - Movement ranges
  - Attack ranges
  - Objective control

- Implement visual feedback for:
  - Unit selection
  - Valid movement areas (shader-based visualization)
  - Valid targets
  - Combat results
  - Terrain effects
  - Distance measurement tools (visual ruler for gridless feel)

### Controls
- Implement hybrid control scheme:
  - Left-click to select units and targets
  - Right-click to cancel selection
  - Drag-and-drop for unit movement with path preview
  - Visual indicators for valid movement distances
  - Toggle for "snap to grid" feature

- Provide keyboard shortcuts for common actions
- Support gamepad input where appropriate

## Grid/Gridless Hybrid Implementation

### Core Principles
- **Invisible Grid**:
  - Use a fine-grained grid (0.25" units) for calculations
  - No visible grid lines in normal gameplay
  - Optional debug visualization for development and testing

- **Measurement System**:
  ```gdscript
  # Use consistent calculation regardless of visual representation
  func measure_distance(point_a: Vector3, point_b: Vector3) -> float:
      # Calculate actual distance in 3D space
      var direct_distance = Vector2(point_a.x, point_a.z).distance_to(Vector2(point_b.x, point_b.z))
      
      # Round to nearest 0.25" for hybrid implementation
      return round(direct_distance * 4) / 4.0
  ```

- **Positioning System**:
  ```gdscript
  # Default approach snaps to invisible grid
  func get_valid_position(desired_position: Vector3) -> Vector3:
      var grid_size = 0.25  # 1/4 inch grid
      
      # Snap to invisible grid
      var snapped = Vector3(
          round(desired_position.x / grid_size) * grid_size,
          desired_position.y,
          round(desired_position.z / grid_size) * grid_size
      )
      
      return snapped
  ```

- **Movement Visualization**:
  - Implement shader-based movement range visualization
  - Show continuous movement area rather than discrete grid cells
  - Display exact distances with visual ruler or measurement lines

- **Formation Management**:
  - Optimize for both grid-based and gridless approaches
  - Use constraint-based system for unit coherency (1" between models, 9" total spread)
  - Provide automated formation templates and manual adjustment options

## Playtesting Infrastructure

### Feedback Collection
- Implement in-game feedback mechanisms:
  - Quick feedback options during play
  - Session surveys at game end
  - Automated metrics collection (time per turn, movement precision, etc.)

### A/B Testing
- Implement options to test both approaches:
  - Toggle for visible grid overlay
  - Toggle between pure grid snapping vs. free movement
  - Track player preference and performance metrics

## Implementation Priorities

### Phase 1: Core Battle Framework
1. **Battlefield Setup**
   - Implement hybrid movement system (invisible grid with gridless visuals)
   - Deployment zone visualization
   - Simple placeholder unit meshes

2. **Unit Deployment**
   - Team-based deployment zones
   - Unit placement validation
   - Basic unit selection

3. **Turn Structure**
   - Alternating activation system
   - Unit state tracking
   - Action selection UI

### Phase 2: Movement System
1. **Unit Movement**
   - Hybrid measurement system
   - Movement range visualization
   - Unit coherency rules
   - Action-based movement restrictions

2. **Formation System**
   - Unit grouping mechanics
   - Formation maintenance
   - Unit spacing rules
   - Auto-arrange and manual adjustment options

### Phase 3: Combat System
1. **Quality Tests**
   - D6-based roll system
   - Success on quality value or higher
   - Modifiers and special rules

2. **Combat Resolution**
   - Shooting mechanics
   - Melee combat
   - Wound allocation
   - Morale system

### Phase 4: Terrain System
1. **Terrain Types**
   - Cover terrain
   - Difficult terrain
   - Dangerous terrain

2. **Terrain Effects**
   - Line of sight blocking
   - Movement modifications
   - Combat modifiers

### Phase 5: Special Rules & Abilities
1. **Special Rule Implementation**
   - Implement all AoF special rules
   - Command group upgrades
   - Unit abilities

2. **Advanced Mechanics**
   - Complex battle scenarios
   - Custom victory conditions
   - Campaign integration

## Testing Strategy

1. **Unit Tests**
   - Combat calculations
   - Movement validation
   - State transitions
   - Grid/gridless measurement accuracy

2. **Integration Tests**
   - Turn sequence
   - Combat resolution
   - Terrain effects
   - Formation management for both approaches

3. **Playtest Scenarios**
   - Deployment phase
   - Basic combat
   - Full game loop
   - A/B testing for grid vs. gridless

## Performance Standards
- Target 60+ FPS on mid-range hardware
- Optimize terrain and unit rendering
- Minimize memory usage for large battles
- Ensure smooth transitions between states
- Implement LOD (Level of Detail) for unit models

## GDScript Implementation References

### Hybrid Positioning System
```gdscript
class_name PositioningSystem
extends Node

var grid_size: float = 0.25  # 1/4 inch grid
var snap_to_grid: bool = true  # Can be toggled for testing

signal position_validated(original_position: Vector3, valid_position: Vector3)

## Get valid position with optional grid snapping
## @param desired_position: Target position to validate
## @param force_snap: Override global setting
## @return Vector3: Valid position (snapped if appropriate)
func get_valid_position(desired_position: Vector3, force_snap: bool = false) -> Vector3:
    var result = desired_position
    
    # Apply grid snapping if enabled
    if snap_to_grid or force_snap:
        result = Vector3(
            round(desired_position.x / grid_size) * grid_size,
            desired_position.y,
            round(desired_position.z / grid_size) * grid_size
        )
    
    emit_signal("position_validated", desired_position, result)
    return result

## Measure distance between two points
## @param point_a: First point
## @param point_b: Second point
## @return float: Distance in inches (rounded to nearest 0.25" if grid-based)
func measure_distance(point_a: Vector3, point_b: Vector3) -> float:
    # Calculate horizontal distance (ignore Y-axis)
    var direct_distance = Vector2(point_a.x, point_a.z).distance_to(Vector2(point_b.x, point_b.z))
    
    # Round to grid size if using grid measurements
    if snap_to_grid:
        return round(direct_distance / grid_size) * grid_size
    else:
        return direct_distance
        
## Toggle between grid-based and gridless positioning
## @param enable_grid: Whether to enable grid snapping
func set_grid_snapping(enable_grid: bool) -> void:
    snap_to_grid = enable_grid
```

### Core Battle Manager
```gdscript
class_name BattleManager
extends Node

signal phase_changed(new_phase: int)
signal round_advanced(new_round: int)
signal unit_activated(unit: Unit)

enum BattlePhase {
    SETUP,
    DEPLOYMENT,
    ACTIVATION,
    ACTION,
    END_ROUND
}

var current_phase: BattlePhase = BattlePhase.SETUP
var current_team: int = 0
var round_number: int = 1

func advance_phase() -> void:
    match current_phase:
        BattlePhase.DEPLOYMENT:
            if _is_deployment_complete():
                current_phase = BattlePhase.ACTIVATION
                emit_signal("phase_changed", current_phase)
        BattlePhase.ACTIVATION:
            if _are_all_units_activated():
                current_phase = BattlePhase.END_ROUND
                emit_signal("phase_changed", current_phase)
        BattlePhase.END_ROUND:
            _resolve_end_round()
            if _should_end_game():
                # Game over logic
                pass
            else:
                current_phase = BattlePhase.ACTIVATION
                round_number += 1
                emit_signal("round_advanced", round_number)
                _reset_unit_activations()
```

### Unit Base Class
```gdscript
class_name Unit
extends Node3D

signal activated
signal action_completed
signal took_damage(amount: int)
signal destroyed

enum ActionType {
    HOLD,
    ADVANCE,
    RUSH,
    CHARGE
}

var stats: Dictionary = {
    "quality": 4,
    "defense": 4,
    "movement": 6,
    "wounds": 1,
    "current_wounds": 1
}

var state: Dictionary = {
    "activated": false,
    "shaken": false,
    "in_melee": false,
    "fatigued": false
}

func perform_action(action_type: ActionType, target_position: Vector3 = Vector3.ZERO, target_unit: Unit = null) -> void:
    # Action resolution logic
    pass

func take_damage(amount: int) -> void:
    stats.current_wounds -= amount
    emit_signal("took_damage", amount)
    
    if stats.current_wounds <= 0:
        emit_signal("destroyed")
``` 