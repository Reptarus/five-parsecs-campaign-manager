# Age of Fantasy Digital - Architecture Deep Dive

**Document Version**: 1.0
**Created**: 2024-11-22
**Purpose**: Comprehensive architectural blueprint for converting tabletop rules to tactical video game

---

## Table of Contents
1. [Architectural Philosophy](#architectural-philosophy)
2. [Scene Hierarchy Overview](#scene-hierarchy-overview)
3. [Core Scene Structures](#core-scene-structures)
4. [Manager Architecture](#manager-architecture)
5. [Physics & Collision System](#physics--collision-system)
6. [Signal Flow Architecture](#signal-flow-architecture)
7. [Data Flow Patterns](#data-flow-patterns)
8. [Comparison: Five Parsecs vs Age of Fantasy](#comparison-five-parsecs-vs-age-of-fantasy)

---

## Architectural Philosophy

### Core Principles

1. **Scene-Based Composition Over Inheritance**
   - Favor composing behavior through child nodes
   - Use scenes as prefabs for instantiation
   - Keep inheritance hierarchies shallow (max 2-3 levels)

2. **Manager Delegation Pattern**
   - Managers orchestrate but don't own game objects
   - Units/terrain exist in scene tree, managers coordinate them
   - Avoid "god object" anti-pattern

3. **Data-Driven Design**
   - Unit stats, weapons, special rules as Resources
   - Easy to balance without code changes
   - Supports modding and custom armies

4. **Signal-Based Decoupling**
   - Systems communicate via signals
   - No direct references between unrelated systems
   - Easy to add/remove features

---

## Scene Hierarchy Overview

### Primary Scene Types

| Scene Type | Root Node | Purpose | Instancing |
|------------|-----------|---------|------------|
| Battle | Node3D | Main game container | Once per battle |
| Unit | Node3D | Individual game piece | Many per battle |
| Terrain | StaticBody3D | Battlefield features | Many per battle |
| UI Panel | Control | HUD elements | Once per type |
| Effect | Node3D | Visual feedback | Pooled, many |

### Complete Project Scene Tree

```
res://
├── scenes/
│   ├── battle/
│   │   ├── Battle.tscn              # Main battle scene
│   │   ├── BattleCamera.tscn        # Camera rig with controls
│   │   └── Battlefield.tscn         # Ground + zones (optional separation)
│   │
│   ├── units/
│   │   ├── BaseUnit.tscn            # Template for all units
│   │   ├── InfantryUnit.tscn        # Infantry variant
│   │   ├── CavalryUnit.tscn         # Cavalry variant
│   │   ├── MonsterUnit.tscn         # Large creature variant
│   │   └── HeroUnit.tscn            # Character variant
│   │
│   ├── terrain/
│   │   ├── TerrainFeature.tscn      # Base terrain template
│   │   ├── Forest.tscn              # Trees, soft cover
│   │   ├── Hill.tscn                # Elevation
│   │   ├── Building.tscn            # Hard cover, LoS block
│   │   ├── Wall.tscn                # Linear obstacle
│   │   ├── Water.tscn               # Dangerous terrain
│   │   └── Ruins.tscn               # Cover + difficult
│   │
│   ├── ui/
│   │   ├── BattleHUD.tscn           # Main HUD container
│   │   ├── ActionMenu.tscn          # Action selection
│   │   ├── UnitCard.tscn            # Selected unit info
│   │   ├── TurnIndicator.tscn       # Phase/player display
│   │   ├── DiceRollDisplay.tscn     # Combat result
│   │   └── VictoryScreen.tscn       # End of battle
│   │
│   └── effects/
│       ├── SelectionRing.tscn       # Unit selection indicator
│       ├── MovementPreview.tscn     # Path + range display
│       ├── DamageNumber.tscn        # Floating damage text
│       ├── AttackLine.tscn          # Targeting indicator
│       └── DeathEffect.tscn         # Unit removal effect
```

---

## Core Scene Structures

### 1. Battle.tscn - Main Container

```
Battle (Node3D)
│
├── Environment/
│   ├── WorldEnvironment
│   │   └── [Environment resource with sky, ambient, fog]
│   │
│   ├── DirectionalLight3D (Sun)
│   │   ├── shadow_enabled = true
│   │   ├── directional_shadow_mode = PARALLEL_4_SPLITS
│   │   └── light_energy = 1.0
│   │
│   └── BattleCamera (from BattleCamera.tscn)
│       └── [Camera3D with orbit/pan controls]
│
├── Battlefield/
│   ├── Ground (StaticBody3D)
│   │   ├── MeshInstance3D (PlaneMesh, 48x48 units)
│   │   ├── CollisionShape3D (WorldBoundaryShape3D)
│   │   └── [Material with grass/dirt texture]
│   │
│   ├── TerrainFeatures/ (Node3D container)
│   │   └── [Instanced terrain scenes]
│   │
│   ├── DeploymentZones/ (Node3D container)
│   │   ├── Team1Zone (Area3D)
│   │   │   ├── CollisionShape3D (BoxShape3D)
│   │   │   └── MeshInstance3D (visual indicator)
│   │   │
│   │   └── Team2Zone (Area3D)
│   │       ├── CollisionShape3D
│   │       └── MeshInstance3D
│   │
│   └── Objectives/ (Node3D container)
│       └── [Objective markers]
│
├── Units/
│   ├── Team1/ (Node3D container)
│   │   └── [Instanced unit scenes]
│   │
│   └── Team2/ (Node3D container)
│       └── [Instanced unit scenes]
│
├── Effects/ (Node3D container)
│   └── [Pooled effect instances]
│
├── UI/ (CanvasLayer)
│   ├── BattleHUD (from BattleHUD.tscn)
│   └── [Other UI scenes]
│
└── Managers/ (Node)
    ├── BattleManager
    ├── TurnManager
    ├── SelectionManager
    ├── MovementManager
    ├── CombatManager
    ├── MoraleManager
    └── AIManager
```

**Why This Structure?**

- **Environment** isolated for easy lighting/atmosphere changes
- **Battlefield** contains all static/semi-static elements
- **Units** separated by team for easy iteration
- **Effects** pooled container for performance
- **UI** on CanvasLayer to overlay 3D
- **Managers** grouped but separate from game objects

### 2. BaseUnit.tscn - Unit Prefab

```
BaseUnit (Node3D)
│   script: GameBaseUnit.gd
│
├── ModelPivot (Node3D)
│   │   # Allows model rotation independent of root
│   │
│   └── Model (Node3D or MeshInstance3D)
│       │   # Imported .glb or placeholder mesh
│       │
│       ├── Skeleton3D (if animated)
│       │   └── AnimationPlayer
│       │
│       └── [Weapon/shield attachment points]
│
├── CollisionShape3D
│   │   shape: CapsuleShape3D (radius: 0.5, height: 1.8)
│   │   # Used for selection raycasting
│   └── collision_layer = 2 (UNIT layer)
│
├── NavigationAgent3D
│   │   path_desired_distance = 0.5
│   │   target_desired_distance = 0.5
│   │   avoidance_enabled = true
│   └── radius = 0.5
│
├── SelectionIndicator (MeshInstance3D)
│   │   mesh: TorusMesh (ring on ground)
│   │   visible = false (shown when selected)
│   └── material: ShaderMaterial (pulsing glow)
│
├── MovementRangeIndicator (MeshInstance3D)
│   │   mesh: PlaneMesh (large, flat)
│   │   visible = false
│   └── material: ShaderMaterial (circular gradient)
│
├── UI (Control)
│   │   # Viewport-space UI attached to unit
│   │
│   ├── HealthBar (ProgressBar)
│   │   └── [Shows current_wounds / max_wounds]
│   │
│   └── StatusIcons (HBoxContainer)
│       └── [Shaken, Fatigued, etc.]
│
├── AudioStreamPlayer3D
│   └── [Combat sounds, movement sounds]
│
└── AnimationPlayer
    └── [Idle, Walk, Attack, Death animations]
```

**Exported Properties (GameBaseUnit.gd)**

```gdscript
@export var unit_profile: UnitProfile  # Resource with stats
@export var team: int = 0
@export var unit_name: String = "Unit"

# Runtime state
var is_activated: bool = false
var is_shaken: bool = false
var is_fatigued: bool = false
var is_in_melee: bool = false
var current_wounds: int
```

### 3. TerrainFeature.tscn - Terrain Base

```
TerrainFeature (StaticBody3D)
│   script: TerrainFeature.gd
│   collision_layer = 4 (TERRAIN layer)
│
├── Model (Node3D)
│   └── [Visual mesh - trees, rocks, building]
│
├── CollisionShape3D
│   └── [Matches visual bounds for blocking]
│
├── CoverArea (Area3D)  [Optional]
│   │   # Units inside get cover bonus
│   ├── CollisionShape3D
│   └── collision_layer = 8 (AREA layer)
│
├── DifficultTerrainArea (Area3D)  [Optional]
│   │   # Units inside have reduced movement
│   ├── CollisionShape3D
│   └── collision_layer = 8
│
└── DangerousTerrainArea (Area3D)  [Optional]
    │   # Units entering roll for damage
    ├── CollisionShape3D
    └── collision_layer = 8
```

**Exported Properties (TerrainFeature.gd)**

```gdscript
@export_enum("Cover", "Difficult", "Dangerous", "Blocking") var terrain_type: String = "Cover"
@export var blocks_line_of_sight: bool = false
@export var cover_bonus: int = 1  # +1 Defense
@export var movement_penalty: float = 0.5  # Max 6" movement
@export var dangerous_roll: int = 1  # Wound on this roll
```

### 4. BattleHUD.tscn - UI Container

```
BattleHUD (Control)
│   anchors_preset = FULL_RECT
│   script: BattleHUD.gd
│
├── TopBar (HBoxContainer)
│   │   anchor_top = 0, anchor_bottom = 0
│   │
│   ├── RoundCounter (Label)
│   │   └── text: "Round 1"
│   │
│   ├── PhaseIndicator (Label)
│   │   └── text: "Deployment Phase"
│   │
│   └── CurrentPlayer (Label)
│       └── text: "Player 1's Turn"
│
├── LeftPanel (VBoxContainer)
│   │   anchor_left = 0, anchor_right = 0
│   │
│   └── UnitCard (from UnitCard.tscn)
│       └── [Selected unit details]
│
├── RightPanel (VBoxContainer)
│   │   anchor_left = 1, anchor_right = 1
│   │
│   └── ActionMenu (from ActionMenu.tscn)
│       └── [Action buttons]
│
├── BottomBar (HBoxContainer)
│   │   anchor_top = 1, anchor_bottom = 1
│   │
│   ├── EndTurnButton (Button)
│   └── MenuButton (Button)
│
└── CenterPopups (Control)
    │   anchor_preset = CENTER
    │
    ├── DiceRollDisplay (from DiceRollDisplay.tscn)
    │   └── visible = false
    │
    └── VictoryScreen (from VictoryScreen.tscn)
        └── visible = false
```

---

## Manager Architecture

### Manager Responsibilities

| Manager | Responsibilities | Signals Emitted |
|---------|-----------------|-----------------|
| BattleManager | Phase transitions, win conditions | phase_changed, battle_ended |
| TurnManager | Activation order, turn tracking | turn_started, turn_ended, unit_activated |
| SelectionManager | Input handling, unit selection | unit_selected, unit_deselected |
| MovementManager | Pathfinding, movement validation | movement_started, movement_completed |
| CombatManager | Attack resolution, damage | attack_declared, damage_dealt, unit_destroyed |
| MoraleManager | Morale tests, shaken status | morale_test_required, unit_shaken, unit_rallied |
| AIManager | AI decision making | ai_action_decided |

### Manager Communication Pattern

```
┌─────────────────┐
│  BattleManager  │ (Orchestrator)
└────────┬────────┘
         │ phase_changed
         ▼
┌─────────────────┐     ┌─────────────────┐
│   TurnManager   │────▶│ SelectionManager │
└────────┬────────┘     └────────┬────────┘
         │ unit_activated        │ unit_selected
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│ MovementManager │     │  CombatManager  │
└────────┬────────┘     └────────┬────────┘
         │ movement_completed    │ damage_dealt
         └──────────┬────────────┘
                    ▼
           ┌─────────────────┐
           │  MoraleManager  │
           └─────────────────┘
```

### Manager Base Pattern

```gdscript
# ManagerBase.gd - Optional base class
class_name ManagerBase
extends Node

var battle_state: BattleState  # Autoload reference

func _ready() -> void:
    # Connect to relevant signals
    _connect_signals()

func _connect_signals() -> void:
    # Override in subclass
    pass

func _on_phase_changed(new_phase: int) -> void:
    # Override in subclass
    pass
```

### BattleManager Implementation

```gdscript
# BattleManager.gd
class_name BattleManager
extends Node

signal phase_changed(new_phase: BattlePhase)
signal round_started(round_number: int)
signal battle_ended(winner_team: int)

enum BattlePhase {
    SETUP,
    DEPLOYMENT,
    ACTIVATION,
    ACTION,
    END_ROUND,
    GAME_OVER
}

var current_phase: BattlePhase = BattlePhase.SETUP
var current_round: int = 0
var teams: Array[Team] = []

func _ready() -> void:
    # Initialize battle
    pass

func start_battle() -> void:
    current_phase = BattlePhase.DEPLOYMENT
    current_round = 1
    phase_changed.emit(current_phase)
    round_started.emit(current_round)

func advance_phase() -> void:
    match current_phase:
        BattlePhase.DEPLOYMENT:
            if _is_deployment_complete():
                _transition_to(BattlePhase.ACTIVATION)

        BattlePhase.ACTIVATION:
            # Player selects a unit
            pass

        BattlePhase.ACTION:
            if _is_action_complete():
                _transition_to(BattlePhase.ACTIVATION)

        BattlePhase.END_ROUND:
            _process_end_round()
            if _check_victory_conditions():
                _transition_to(BattlePhase.GAME_OVER)
            else:
                current_round += 1
                round_started.emit(current_round)
                _transition_to(BattlePhase.ACTIVATION)

func _transition_to(new_phase: BattlePhase) -> void:
    var old_phase = current_phase
    current_phase = new_phase
    phase_changed.emit(new_phase)
    print("[BattleManager] Phase: %s -> %s" % [
        BattlePhase.keys()[old_phase],
        BattlePhase.keys()[new_phase]
    ])

func _is_deployment_complete() -> bool:
    # Check all units deployed
    return true

func _is_action_complete() -> bool:
    # Check current unit finished action
    return true

func _process_end_round() -> void:
    # Reset activations, check objectives
    pass

func _check_victory_conditions() -> bool:
    # Check win conditions
    return false
```

---

## Physics & Collision System

### Physics Layers Configuration

```
Layer 1: GROUND      - Battlefield ground plane
Layer 2: UNITS       - Unit collision shapes
Layer 3: TERRAIN     - Terrain blocking shapes
Layer 4: AREAS       - Cover/difficult/dangerous zones
Layer 5: SELECTION   - Selection blockers (UI elements in 3D)
Layer 6: PROJECTILES - Ranged attack traces
```

### Collision Masks by Object Type

| Object | Collision Layer | Collision Mask |
|--------|----------------|----------------|
| Ground | 1 | None |
| Units | 2 | 1, 3 (ground, terrain) |
| Terrain | 3 | None |
| Areas | 4 | 2 (units) |
| Selection Ray | - | 2 (units only) |
| LoS Ray | - | 3 (terrain only) |
| Projectile Ray | - | 2, 3 (units, terrain) |

### Project Settings Configuration

```
# project.godot

[layer_names]
3d_physics/layer_1="Ground"
3d_physics/layer_2="Units"
3d_physics/layer_3="Terrain"
3d_physics/layer_4="Areas"
3d_physics/layer_5="Selection"
3d_physics/layer_6="Projectiles"
```

### Selection Raycast Implementation

```gdscript
# SelectionManager.gd

const UNIT_LAYER: int = 2

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _handle_selection_click(event.position)

func _handle_selection_click(screen_pos: Vector2) -> void:
    var camera = get_viewport().get_camera_3d()
    var ray_origin = camera.project_ray_origin(screen_pos)
    var ray_dir = camera.project_ray_normal(screen_pos)
    var ray_end = ray_origin + ray_dir * 1000.0

    var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    query.collision_mask = 1 << (UNIT_LAYER - 1)  # Only units
    query.collide_with_areas = false

    var space_state = get_world_3d().direct_space_state
    var result = space_state.intersect_ray(query)

    if result:
        var unit = _get_unit_from_collider(result.collider)
        if unit:
            select_unit(unit)
    else:
        deselect_all()

func _get_unit_from_collider(collider: Node3D) -> GameBaseUnit:
    # CollisionShape3D is child of Unit
    var parent = collider.get_parent()
    if parent is GameBaseUnit:
        return parent
    return null
```

### Line of Sight Check

```gdscript
# CombatManager.gd

const TERRAIN_LAYER: int = 3

func has_line_of_sight(attacker: GameBaseUnit, target: GameBaseUnit) -> bool:
    var space_state = get_world_3d().direct_space_state

    # Ray from attacker center to target center
    var origin = attacker.global_position + Vector3.UP * 1.0  # Eye height
    var destination = target.global_position + Vector3.UP * 1.0

    var query = PhysicsRayQueryParameters3D.create(origin, destination)
    query.collision_mask = 1 << (TERRAIN_LAYER - 1)  # Only terrain
    query.collide_with_areas = false

    var result = space_state.intersect_ray(query)

    # If no hit, we have LoS
    return result.is_empty()
```

---

## Signal Flow Architecture

### Principle: Call Down, Signal Up

- **Parents call methods on children** (direct reference OK)
- **Children emit signals to parents** (decoupled)
- **Siblings communicate via shared parent or autoload**

### Complete Signal Map

#### BattleManager Signals
```gdscript
signal phase_changed(new_phase: BattlePhase)
signal round_started(round_number: int)
signal battle_ended(winner_team: int)
```

#### TurnManager Signals
```gdscript
signal activation_started(team: int)
signal unit_activated(unit: GameBaseUnit)
signal unit_turn_ended(unit: GameBaseUnit)
signal all_units_activated()
```

#### SelectionManager Signals
```gdscript
signal unit_selected(unit: GameBaseUnit)
signal unit_deselected(unit: GameBaseUnit)
signal selection_cleared()
signal target_selected(target: GameBaseUnit)
```

#### MovementManager Signals
```gdscript
signal movement_started(unit: GameBaseUnit, destination: Vector3)
signal movement_completed(unit: GameBaseUnit)
signal movement_cancelled(unit: GameBaseUnit)
signal invalid_movement(unit: GameBaseUnit, reason: String)
```

#### CombatManager Signals
```gdscript
signal attack_declared(attacker: GameBaseUnit, target: GameBaseUnit)
signal dice_rolled(rolls: Array[int], successes: int)
signal damage_dealt(target: GameBaseUnit, wounds: int)
signal unit_destroyed(unit: GameBaseUnit)
signal melee_engaged(attacker: GameBaseUnit, defender: GameBaseUnit)
```

#### MoraleManager Signals
```gdscript
signal morale_test_required(unit: GameBaseUnit, reason: String)
signal morale_test_passed(unit: GameBaseUnit)
signal morale_test_failed(unit: GameBaseUnit)
signal unit_shaken(unit: GameBaseUnit)
signal unit_rallied(unit: GameBaseUnit)
signal unit_routed(unit: GameBaseUnit)
```

### Signal Connection Example

```gdscript
# BattleHUD.gd - Connecting to manager signals

func _ready() -> void:
    var battle_manager = get_node("/root/Battle/Managers/BattleManager")
    var combat_manager = get_node("/root/Battle/Managers/CombatManager")
    var selection_manager = get_node("/root/Battle/Managers/SelectionManager")

    battle_manager.phase_changed.connect(_on_phase_changed)
    battle_manager.round_started.connect(_on_round_started)
    combat_manager.dice_rolled.connect(_on_dice_rolled)
    selection_manager.unit_selected.connect(_on_unit_selected)

func _on_phase_changed(new_phase: int) -> void:
    phase_indicator.text = BattleManager.BattlePhase.keys()[new_phase]

func _on_round_started(round_number: int) -> void:
    round_counter.text = "Round %d" % round_number

func _on_dice_rolled(rolls: Array[int], successes: int) -> void:
    dice_roll_display.show_roll(rolls, successes)

func _on_unit_selected(unit: GameBaseUnit) -> void:
    unit_card.display_unit(unit)
```

---

## Data Flow Patterns

### Resource-Based Unit Data

```gdscript
# UnitProfile.gd
class_name UnitProfile
extends Resource

@export var unit_name: String = "Unit"
@export var quality: int = 4
@export var defense: int = 4
@export var movement: int = 6
@export var wounds: int = 1

@export var weapon_profiles: Array[WeaponProfile] = []
@export var special_rules: Array[String] = []

@export var points_cost: int = 0
```

```gdscript
# WeaponProfile.gd
class_name WeaponProfile
extends Resource

@export var weapon_name: String = "Weapon"
@export var weapon_range: int = 0  # 0 = melee
@export var attacks: int = 1
@export var armor_piercing: int = 0
@export var special_rules: Array[String] = []
```

### Save/Load Pattern

```gdscript
# BattleSaveData.gd
class_name BattleSaveData
extends Resource

@export var round_number: int
@export var current_phase: int
@export var current_team: int

@export var unit_states: Array[UnitSaveState] = []
@export var terrain_placements: Array[TerrainPlacement] = []
@export var objective_states: Array[ObjectiveState] = []


# UnitSaveState.gd
class_name UnitSaveState
extends Resource

@export var unit_id: String
@export var profile_path: String
@export var team: int
@export var position: Vector3
@export var rotation: float

@export var current_wounds: int
@export var is_activated: bool
@export var is_shaken: bool
@export var is_fatigued: bool
```

---

## Comparison: Five Parsecs vs Age of Fantasy

### Architectural Differences

| Aspect | Five Parsecs | Age of Fantasy |
|--------|-------------|----------------|
| **Primary View** | 2D UI screens | 3D battlefield |
| **Scene Depth** | Flat (screens) | Deep (objects) |
| **Root Nodes** | Control | Node3D |
| **Instancing** | Minimal | Heavy (units, terrain) |
| **Real-time** | None | Movement, selection |
| **Physics** | None | Raycasting, collision |

### Transferable Patterns

1. **State Machine Pattern**
   - Five Parsecs: CampaignPhaseManager
   - Age of Fantasy: BattleManager
   - **Transfer**: Same enum-based state transitions

2. **Resource Data Classes**
   - Five Parsecs: Character.gd, Equipment.gd
   - Age of Fantasy: UnitProfile.gd, WeaponProfile.gd
   - **Transfer**: Same Resource pattern, different properties

3. **Signal Architecture**
   - Five Parsecs: SignalBus autoload
   - Age of Fantasy: Manager signals
   - **Transfer**: Same call-down-signal-up principle

4. **Save/Load System**
   - Five Parsecs: Campaign Resources
   - Age of Fantasy: BattleSaveData Resource
   - **Transfer**: Same serialization, add Vector3 handling

5. **Testing Infrastructure**
   - Five Parsecs: gdUnit4, PowerShell runner
   - Age of Fantasy: Same setup
   - **Transfer**: Direct copy, adjust test cases

### New Patterns Required

1. **3D Selection System** - Raycasting, physics layers
2. **Pathfinding** - NavigationServer3D
3. **Camera Controller** - Orbit, pan, zoom
4. **Visual Feedback** - Shaders, 3D indicators
5. **Pooled Effects** - Performance optimization
6. **AI Decision Trees** - Turn-based AI

### Migration Strategy

| Five Parsecs Component | Age of Fantasy Equivalent | Migration Effort |
|-----------------------|--------------------------|------------------|
| DiceSystem.gd | DiceSystem.gd | Copy directly |
| GameState.gd | BattleState.gd | Modify properties |
| CampaignCreationStateManager | BattleManager | Heavy refactor |
| Character.gd | UnitProfile.gd | Rename & modify |
| SignalBus pattern | Manager signals | Adapt pattern |
| Save/Load Resources | BattleSaveData | Add Vector3 |
| gdUnit4 tests | Same framework | New test cases |

---

## Summary

### Key Architectural Takeaways

1. **Scene Composition** - Use scenes as prefabs, instance at runtime
2. **Manager Coordination** - Managers orchestrate, don't own
3. **Physics Layers** - Critical for selection and LoS
4. **Signal Decoupling** - Systems communicate via signals
5. **Data Resources** - Stats in .tres files, not hardcoded

### Implementation Order

1. Core scenes (Battle, BaseUnit)
2. Physics/collision setup
3. Selection system
4. Movement system
5. Turn management
6. Combat resolution
7. UI overlays
8. Effects and polish

### Files to Create First

1. `Battle.tscn` - Main container
2. `BaseUnit.tscn` - Unit prefab
3. `BattleManager.gd` - State machine
4. `SelectionManager.gd` - Input handling
5. `UnitProfile.gd` - Data resource

This architecture provides a solid foundation that can scale to support all the advanced rules while maintaining clean separation of concerns and testability.
