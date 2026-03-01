# Age of Fantasy Digital - Scene Implementation Guide

**Document Version**: 1.0
**Created**: 2024-11-22
**Purpose**: Step-by-step instructions for creating all core scenes

---

## Table of Contents
1. [Project Setup](#project-setup)
2. [Battle Scene Creation](#battle-scene-creation)
3. [Unit Scene Creation](#unit-scene-creation)
4. [Camera Rig Setup](#camera-rig-setup)
5. [Terrain Scene Creation](#terrain-scene-creation)
6. [UI Scene Creation](#ui-scene-creation)
7. [Effect Scene Creation](#effect-scene-creation)
8. [Shader Implementations](#shader-implementations)

---

## Project Setup

### Directory Structure

Create the following directories before starting:

```
project_root/
├── src/
│   ├── core/           # Manager scripts
│   ├── units/          # Unit scripts
│   ├── terrain/        # Terrain scripts
│   ├── ai/             # AI scripts
│   ├── ui/             # UI scripts
│   └── utils/          # Utilities
├── scenes/
│   ├── battle/
│   ├── units/
│   ├── terrain/
│   ├── ui/
│   └── effects/
├── resources/
│   ├── units/          # Unit profiles
│   ├── weapons/        # Weapon profiles
│   └── configurations/ # Settings
├── assets/
│   ├── models/
│   ├── textures/
│   ├── materials/
│   ├── shaders/
│   └── audio/
└── tests/
```

### Project Settings Configuration

1. **Open Project → Project Settings**

2. **Layer Names** (3D Physics tab):
```
Layer 1: Ground
Layer 2: Units
Layer 3: Terrain
Layer 4: Areas
Layer 5: Selection
Layer 6: Projectiles
```

3. **Input Map** (add these actions):
```
camera_pan       → Middle Mouse Button
camera_rotate    → Right Mouse Button
camera_zoom_in   → Mouse Wheel Up
camera_zoom_out  → Mouse Wheel Down
select           → Left Mouse Button
cancel           → Escape, Right Mouse Button
confirm          → Enter, Left Mouse Button
```

4. **Rendering Settings**:
```
Rendering → Textures → Canvas Textures → Default Texture Filter: Nearest
Rendering → Anti Aliasing → Quality → MSAA 3D: 4x
```

---

## Battle Scene Creation

### Step 1: Create Base Scene

1. **Scene → New Scene → 3D Scene**
2. **Rename root** to `Battle`
3. **Save as** `res://scenes/battle/Battle.tscn`

### Step 2: Add Environment

1. **Add child nodes** to Battle:
   - `Node3D` → rename to `Environment`

2. **Add to Environment**:
   - `WorldEnvironment`
   - `DirectionalLight3D`

3. **Configure WorldEnvironment**:
   - Create new Environment resource
   - Background → Mode: Sky
   - Background → Sky → Create new Sky
   - Sky Material → Create new ProceduralSkyMaterial
   - Ambient Light → Source: Sky
   - Ambient Light → Energy: 0.5
   - Tonemap → Mode: Filmic
   - SSAO → Enabled: true (optional, performance cost)

4. **Configure DirectionalLight3D**:
   - Transform → Rotation: (-45, 30, 0)
   - Light → Energy: 1.2
   - Light → Color: (255, 252, 245) warm white
   - Shadow → Enabled: true
   - Shadow → Mode: PSSM 4 Splits
   - Shadow → Blur: 1.0

### Step 3: Add Battlefield

1. **Add child** to Battle:
   - `Node3D` → rename to `Battlefield`

2. **Add Ground** to Battlefield:
   ```
   StaticBody3D (Ground)
   ├── MeshInstance3D
   └── CollisionShape3D
   ```

3. **Configure Ground MeshInstance3D**:
   - Mesh: New PlaneMesh
   - Size: (48, 48) - standard 4'x4' table
   - Material: Create new StandardMaterial3D
     - Albedo Color: (34, 139, 34) forest green
     - OR apply grass texture

4. **Configure Ground CollisionShape3D**:
   - Shape: New WorldBoundaryShape3D
   - (This creates infinite ground plane for raycasting)

5. **Set Ground collision**:
   - Collision Layer: 1 (Ground)
   - Collision Mask: (none)

### Step 4: Add Containers

Add these empty containers to Battle:

```gdscript
# Add as children of Battlefield
Node3D → TerrainFeatures
Node3D → DeploymentZones
Node3D → Objectives

# Add as children of Battle
Node3D → Units
  Node3D → Team1
  Node3D → Team2
Node3D → Effects
```

### Step 5: Add UI Layer

1. **Add child** to Battle:
   - `CanvasLayer` → rename to `UI`
   - Layer: 1

2. UI scenes will be instanced here later

### Step 6: Add Managers

1. **Add child** to Battle:
   - `Node` → rename to `Managers`

2. **Create manager scripts** and add as children:
```
Managers/
├── BattleManager.gd
├── TurnManager.gd
├── SelectionManager.gd
├── MovementManager.gd
├── CombatManager.gd
└── MoraleManager.gd
```

### Step 7: Attach Battle Script

Create `res://src/core/Battle.gd`:

```gdscript
# Battle.gd
extends Node3D

@onready var battle_manager: BattleManager = $Managers/BattleManager
@onready var team1_container: Node3D = $Units/Team1
@onready var team2_container: Node3D = $Units/Team2

func _ready() -> void:
    _initialize_battle()

func _initialize_battle() -> void:
    # Load terrain, deploy units, start battle
    pass

func spawn_unit(unit_scene: PackedScene, team: int, position: Vector3) -> GameBaseUnit:
    var unit = unit_scene.instantiate()
    unit.team = team
    unit.position = position

    if team == 1:
        team1_container.add_child(unit)
    else:
        team2_container.add_child(unit)

    return unit
```

---

## Unit Scene Creation

### Step 1: Create Base Scene

1. **Scene → New Scene → 3D Scene**
2. **Rename root** to `BaseUnit`
3. **Save as** `res://scenes/units/BaseUnit.tscn`

### Step 2: Scene Structure

Build this hierarchy:

```
BaseUnit (Node3D)
├── ModelPivot (Node3D)
│   └── Model (MeshInstance3D)
├── CollisionShape3D
├── NavigationAgent3D
├── SelectionIndicator (MeshInstance3D)
├── MovementRangeIndicator (MeshInstance3D)
├── UI (Control)
│   └── HealthBar (ProgressBar)
├── AudioStreamPlayer3D
└── AnimationPlayer
```

### Step 3: Configure Nodes

**ModelPivot**:
- Purpose: Allows rotating model without affecting collision
- Transform: default

**Model (placeholder)**:
- Mesh: New CapsuleMesh
- Radius: 0.3
- Height: 1.8
- Material: New StandardMaterial3D
  - Albedo Color: Team color (will be set via script)

**CollisionShape3D**:
- Shape: New CapsuleShape3D
- Radius: 0.4
- Height: 1.8
- Collision Layer: 2 (Units)
- Collision Mask: 1, 3 (Ground, Terrain)

**NavigationAgent3D**:
- Path Desired Distance: 0.5
- Target Desired Distance: 0.5
- Avoidance Enabled: true
- Radius: 0.5
- Neighbor Distance: 5.0
- Max Speed: 6.0 (matches movement stat)

**SelectionIndicator**:
- Mesh: New TorusMesh
- Inner Radius: 0.4
- Outer Radius: 0.6
- Rings: 16
- Ring Segments: 32
- Visible: false
- Material: New StandardMaterial3D
  - Albedo Color: (0, 255, 0) green
  - Emission Enabled: true
  - Emission Color: (0, 255, 0)
  - Emission Energy: 2.0
- Transform: Position Y = 0.05 (just above ground)

**MovementRangeIndicator**:
- Mesh: New PlaneMesh
- Size: (20, 20) - will be masked by shader
- Visible: false
- Transform: Position Y = 0.02, Rotation X = -90°
- Material: Shader (see Shader section)

**UI (Control)**:
- Anchors: Full rect
- This will be projected to screen space

**HealthBar**:
- Min Value: 0
- Max Value: 1 (will be set by script)
- Custom Minimum Size: (50, 8)
- Show Percentage: false
- Style: Custom (green fill, black background)

### Step 4: Attach Unit Script

Create `res://src/units/GameBaseUnit.gd`:

```gdscript
# GameBaseUnit.gd
class_name GameBaseUnit
extends Node3D

signal selected
signal deselected
signal action_completed
signal took_damage(amount: int)
signal destroyed

# Exported configuration
@export var unit_profile: UnitProfile
@export var team: int = 1
@export var unit_name: String = "Unit"

# Node references
@onready var model_pivot: Node3D = $ModelPivot
@onready var model: MeshInstance3D = $ModelPivot/Model
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var selection_indicator: MeshInstance3D = $SelectionIndicator
@onready var movement_indicator: MeshInstance3D = $MovementRangeIndicator
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Runtime state
var is_selected: bool = false
var is_activated: bool = false
var is_shaken: bool = false
var is_fatigued: bool = false
var is_in_melee: bool = false

var current_wounds: int = 1
var max_wounds: int = 1

func _ready() -> void:
    if unit_profile:
        _apply_profile()
    _update_health_bar()

func _apply_profile() -> void:
    unit_name = unit_profile.unit_name
    max_wounds = unit_profile.wounds
    current_wounds = max_wounds
    nav_agent.max_speed = unit_profile.movement

func select() -> void:
    is_selected = true
    selection_indicator.visible = true
    selected.emit()

func deselect() -> void:
    is_selected = false
    selection_indicator.visible = false
    movement_indicator.visible = false
    deselected.emit()

func show_movement_range() -> void:
    if unit_profile:
        var range_size = unit_profile.movement * 2
        movement_indicator.mesh.size = Vector2(range_size, range_size)
        movement_indicator.visible = true

func hide_movement_range() -> void:
    movement_indicator.visible = false

func take_damage(amount: int) -> void:
    current_wounds -= amount
    took_damage.emit(amount)
    _update_health_bar()

    if current_wounds <= 0:
        _die()

func _update_health_bar() -> void:
    health_bar.max_value = max_wounds
    health_bar.value = current_wounds

func _die() -> void:
    destroyed.emit()
    # Play death animation, then remove
    queue_free()

func set_team_color(color: Color) -> void:
    var material = model.get_active_material(0) as StandardMaterial3D
    if material:
        material.albedo_color = color
```

### Step 5: Create Unit Variants

For each unit type (Infantry, Cavalry, Hero):

1. **Instance BaseUnit.tscn**
2. **Make local** (Scene → Make Local)
3. **Swap Model** mesh for appropriate model
4. **Save as** new scene (e.g., `InfantryUnit.tscn`)

---

## Camera Rig Setup

### Step 1: Create Camera Scene

1. **Scene → New Scene → 3D Scene**
2. **Rename root** to `BattleCamera`
3. **Save as** `res://scenes/battle/BattleCamera.tscn`

### Step 2: Build Rig Structure

```
BattleCamera (Node3D)
├── Pivot (Node3D)
│   └── Arm (Node3D)
│       └── Camera3D
└── [Script: BattleCamera.gd]
```

**Purpose of structure**:
- BattleCamera: Handles pan (XZ movement)
- Pivot: Handles rotation (Y axis)
- Arm: Handles zoom/distance (Z offset)
- Camera3D: Actual view

### Step 3: Configure Nodes

**BattleCamera**:
- Position: (24, 0, 24) - center of 48x48 board

**Pivot**:
- Rotation: Y = 0 (will be rotated by script)

**Arm**:
- Position: Z = -20 (distance from pivot)

**Camera3D**:
- Projection: Perspective
- FOV: 45
- Near: 0.1
- Far: 200
- Rotation: X = -45° (looking down at angle)

### Step 4: Attach Camera Script

Create `res://src/core/BattleCamera.gd`:

```gdscript
# BattleCamera.gd
class_name BattleCamera
extends Node3D

@export var pan_speed: float = 20.0
@export var rotation_speed: float = 2.0
@export var zoom_speed: float = 5.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 40.0

@export var min_pan_x: float = 0.0
@export var max_pan_x: float = 48.0
@export var min_pan_z: float = 0.0
@export var max_pan_z: float = 48.0

@onready var pivot: Node3D = $Pivot
@onready var arm: Node3D = $Pivot/Arm
@onready var camera: Camera3D = $Pivot/Arm/Camera3D

var is_panning: bool = false
var is_rotating: bool = false
var current_zoom: float = 20.0

func _ready() -> void:
    arm.position.z = -current_zoom

func _unhandled_input(event: InputEvent) -> void:
    # Pan with middle mouse
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_MIDDLE:
            is_panning = event.pressed
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            is_rotating = event.pressed

        # Zoom with scroll wheel
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-zoom_speed)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(zoom_speed)

    # Mouse motion for pan/rotate
    if event is InputEventMouseMotion:
        if is_panning:
            _pan(event.relative)
        elif is_rotating:
            _rotate_camera(event.relative)

func _process(delta: float) -> void:
    # Keyboard pan (optional)
    var pan_input = Vector2.ZERO
    if Input.is_action_pressed("ui_left"):
        pan_input.x -= 1
    if Input.is_action_pressed("ui_right"):
        pan_input.x += 1
    if Input.is_action_pressed("ui_up"):
        pan_input.y -= 1
    if Input.is_action_pressed("ui_down"):
        pan_input.y += 1

    if pan_input != Vector2.ZERO:
        var forward = -pivot.global_transform.basis.z
        var right = pivot.global_transform.basis.x
        forward.y = 0
        right.y = 0

        var movement = (right * pan_input.x + forward * pan_input.y).normalized()
        position += movement * pan_speed * delta
        _clamp_position()

func _pan(relative: Vector2) -> void:
    var forward = -pivot.global_transform.basis.z
    var right = pivot.global_transform.basis.x
    forward.y = 0
    right.y = 0

    var movement = (right * -relative.x + forward * relative.y) * pan_speed * 0.01
    position += movement
    _clamp_position()

func _rotate_camera(relative: Vector2) -> void:
    pivot.rotate_y(-relative.x * rotation_speed * 0.01)

func _zoom(amount: float) -> void:
    current_zoom = clamp(current_zoom + amount, min_zoom, max_zoom)
    arm.position.z = -current_zoom

func _clamp_position() -> void:
    position.x = clamp(position.x, min_pan_x, max_pan_x)
    position.z = clamp(position.z, min_pan_z, max_pan_z)

func focus_on(target_position: Vector3) -> void:
    var tween = create_tween()
    tween.tween_property(self, "position",
        Vector3(target_position.x, position.y, target_position.z), 0.5)
```

### Step 5: Instance in Battle

1. Open `Battle.tscn`
2. Instance `BattleCamera.tscn` as child of Environment
3. Configure bounds to match battlefield size

---

## Terrain Scene Creation

### Step 1: Create Base Terrain

1. **Scene → New Scene → 3D Scene**
2. **Change root** to `StaticBody3D`
3. **Rename** to `TerrainFeature`
4. **Save as** `res://scenes/terrain/TerrainFeature.tscn`

### Step 2: Build Structure

```
TerrainFeature (StaticBody3D)
├── Model (Node3D)
├── CollisionShape3D
└── [Script: TerrainFeature.gd]
```

**Collision settings**:
- Collision Layer: 3 (Terrain)
- Collision Mask: (none)

### Step 3: Create Variants

#### Forest (Cover + Difficult)

```
Forest (StaticBody3D)
├── Model
│   └── [Tree meshes]
├── CollisionShape3D (BoxShape3D)
├── CoverArea (Area3D)
│   └── CollisionShape3D (same size)
└── DifficultTerrainArea (Area3D)
    └── CollisionShape3D (same size)
```

- CoverArea Layer: 4
- DifficultTerrainArea Layer: 4

#### Hill (Elevation)

```
Hill (StaticBody3D)
├── Model
│   └── [Raised terrain mesh]
└── CollisionShape3D (ConvexPolygonShape3D)
```

- Hills provide height advantage
- Models should have smooth ramp for movement

#### Building (Hard Cover + LoS Block)

```
Building (StaticBody3D)
├── Model
│   └── [Building mesh]
├── CollisionShape3D (BoxShape3D - full building)
├── CoverArea (Area3D)
│   └── CollisionShape3D (perimeter)
└── [blocks_line_of_sight = true]
```

### Step 4: Terrain Script

Create `res://src/terrain/TerrainFeature.gd`:

```gdscript
# TerrainFeature.gd
class_name TerrainFeature
extends StaticBody3D

@export_enum("None", "Cover", "Difficult", "Dangerous") var terrain_type: String = "None"
@export var blocks_line_of_sight: bool = false
@export var cover_bonus: int = 1
@export var movement_modifier: float = 1.0  # 0.5 for difficult
@export var dangerous_roll: int = 1  # Wound on this D6 roll

@onready var cover_area: Area3D = $CoverArea if has_node("CoverArea") else null
@onready var difficult_area: Area3D = $DifficultTerrainArea if has_node("DifficultTerrainArea") else null
@onready var dangerous_area: Area3D = $DangerousTerrainArea if has_node("DangerousTerrainArea") else null

func _ready() -> void:
    if cover_area:
        cover_area.body_entered.connect(_on_unit_entered_cover)
        cover_area.body_exited.connect(_on_unit_exited_cover)

    if dangerous_area:
        dangerous_area.body_entered.connect(_on_unit_entered_dangerous)

func _on_unit_entered_cover(body: Node3D) -> void:
    if body is GameBaseUnit:
        body.in_cover = true
        body.cover_bonus = cover_bonus

func _on_unit_exited_cover(body: Node3D) -> void:
    if body is GameBaseUnit:
        body.in_cover = false
        body.cover_bonus = 0

func _on_unit_entered_dangerous(body: Node3D) -> void:
    if body is GameBaseUnit:
        # Roll for dangerous terrain
        var roll = randi_range(1, 6)
        if roll <= dangerous_roll:
            body.take_damage(1)
```

---

## UI Scene Creation

### BattleHUD.tscn

```
BattleHUD (Control)
│   anchors_preset = FULL_RECT
│
├── TopBar (HBoxContainer)
│   │   anchor_top = 0
│   │   offset_bottom = 40
│   │
│   ├── RoundLabel
│   ├── PhaseLabel
│   └── PlayerLabel
│
├── LeftPanel (VBoxContainer)
│   │   anchor_right = 0.25
│   │
│   └── UnitCard (instance)
│
├── RightPanel (VBoxContainer)
│   │   anchor_left = 0.75
│   │
│   └── ActionMenu (instance)
│
└── BottomBar (HBoxContainer)
    │   anchor_top = 1
    │   offset_top = -50
    │
    ├── EndTurnButton
    └── MenuButton
```

### ActionMenu.tscn

```
ActionMenu (VBoxContainer)
├── HoldButton (Button)
│   text = "Hold (Shoot)"
├── AdvanceButton (Button)
│   text = "Advance (Move + Shoot)"
├── RushButton (Button)
│   text = "Rush (Fast Move)"
├── ChargeButton (Button)
│   text = "Charge (Melee)"
└── CancelButton (Button)
    text = "Cancel"
```

Script connects button signals to SelectionManager or ActionManager.

### UnitCard.tscn

```
UnitCard (PanelContainer)
├── VBoxContainer
│   ├── UnitName (Label)
│   ├── Portrait (TextureRect)
│   ├── StatsGrid (GridContainer)
│   │   ├── QualityLabel
│   │   ├── QualityValue
│   │   ├── DefenseLabel
│   │   ├── DefenseValue
│   │   ├── WoundsLabel
│   │   └── WoundsValue
│   ├── WeaponsList (VBoxContainer)
│   └── SpecialRules (RichTextLabel)
```

---

## Effect Scene Creation

### SelectionRing.tscn

Already included in BaseUnit. Can be extracted for pooling if needed.

### DamageNumber.tscn

```
DamageNumber (Node3D)
├── Label3D
│   text = "1"
│   font_size = 48
│   modulate = red
│   billboard = BILLBOARD_ENABLED
├── AnimationPlayer
│   # Animations: "popup" (float up + fade)
└── [Script: auto queue_free]
```

Script:
```gdscript
# DamageNumber.gd
extends Node3D

@onready var label: Label3D = $Label3D
@onready var anim: AnimationPlayer = $AnimationPlayer

func show_damage(amount: int, pos: Vector3) -> void:
    label.text = str(amount)
    global_position = pos + Vector3.UP * 2
    anim.play("popup")
    await anim.animation_finished
    queue_free()
```

### MovementPreview.tscn

```
MovementPreview (Node3D)
├── PathLine (MeshInstance3D)
│   mesh = ImmediateMesh (generated in code)
├── DestinationMarker (MeshInstance3D)
│   mesh = SphereMesh
│   radius = 0.3
└── [Script: MovementPreview.gd]
```

---

## Shader Implementations

### Movement Range Shader

Create `res://assets/shaders/movement_range.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float range_radius = 6.0;
uniform vec4 color : source_color = vec4(0.2, 0.5, 1.0, 0.4);
uniform float edge_softness = 0.5;

void fragment() {
    // UV is centered at 0.5, 0.5
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv) * 2.0;  // 0 to 1 for full mesh

    // Soft edge
    float alpha = 1.0 - smoothstep(1.0 - edge_softness, 1.0, dist);

    ALBEDO = color.rgb;
    ALPHA = color.a * alpha;
}
```

Apply to MovementRangeIndicator mesh material.

### Selection Outline Shader

Create `res://assets/shaders/outline.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float outline_width = 0.05;

void vertex() {
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
```

Apply as second material pass on selected units.

### Path Line Shader

Create `res://assets/shaders/path_line.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 0.0, 0.8);
uniform float dash_length = 0.5;
uniform float time_scale = 2.0;

void fragment() {
    float pattern = fract((UV.x + TIME * time_scale) / dash_length);
    float alpha = step(0.5, pattern);

    ALBEDO = line_color.rgb;
    ALPHA = line_color.a * alpha;
}
```

---

## Summary Checklist

### Core Scenes to Create

- [ ] `Battle.tscn` - Main game container
- [ ] `BattleCamera.tscn` - Camera rig with controls
- [ ] `BaseUnit.tscn` - Unit template
- [ ] `TerrainFeature.tscn` - Terrain template
- [ ] `Forest.tscn` - Cover terrain variant
- [ ] `Hill.tscn` - Elevation variant
- [ ] `Building.tscn` - LoS blocking variant
- [ ] `BattleHUD.tscn` - Main UI container
- [ ] `ActionMenu.tscn` - Action buttons
- [ ] `UnitCard.tscn` - Unit info display
- [ ] `DamageNumber.tscn` - Floating damage

### Core Scripts to Create

- [ ] `Battle.gd` - Battle initialization
- [ ] `BattleCamera.gd` - Camera controls
- [ ] `GameBaseUnit.gd` - Unit behavior
- [ ] `TerrainFeature.gd` - Terrain effects
- [ ] `BattleManager.gd` - Phase management
- [ ] `SelectionManager.gd` - Input handling
- [ ] `MovementManager.gd` - Pathfinding
- [ ] `CombatManager.gd` - Attack resolution

### Shaders to Create

- [ ] `movement_range.gdshader` - Range visualization
- [ ] `outline.gdshader` - Selection highlight
- [ ] `path_line.gdshader` - Movement path

### Resources to Create

- [ ] `UnitProfile.gd` - Unit stats resource
- [ ] `WeaponProfile.gd` - Weapon stats resource
- [ ] `AdvancedRulesSettings.gd` - Toggle settings

---

This guide provides all the detailed steps needed to create the core scenes. Follow in order, testing each component before moving to the next.
