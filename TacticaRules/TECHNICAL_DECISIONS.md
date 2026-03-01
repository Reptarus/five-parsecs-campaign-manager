# Age of Fantasy Digital - Technical Decisions

**Document Version**: 1.0
**Created**: 2024-11-22
**Purpose**: Document key technical decisions and rationale

---

## Core Technical Choices

### 1. Scale and Units

**Decision**: 1 Godot unit = 1 inch

**Rationale**:
- Direct mapping to tabletop measurements
- Easy mental math (6" movement = 6 units)
- Familiar to players of the tabletop game

**Implementation**:
```gdscript
const SCALE: float = 1.0  # 1 Godot unit = 1 inch

# Standard table is 48" x 48" = 48 x 48 Godot units
var battlefield_size: Vector2 = Vector2(48, 48)
```

**Trade-offs**:
- ✅ Intuitive measurements
- ✅ Easy rule implementation
- ⚠️ Small numbers (units are ~1.8 units tall)
- ⚠️ May need camera adjustment for good view

---

### 2. Grid System

**Decision**: Invisible 0.25" grid for calculations

**Rationale**:
- Per rules document specification
- Maintains gridless visual feel
- Precise positioning for collision/pathfinding
- Can snap to grid for consistent placement

**Implementation**:
```gdscript
const GRID_SIZE: float = 0.25  # 1/4 inch

func snap_to_grid(pos: Vector3) -> Vector3:
    return Vector3(
        round(pos.x / GRID_SIZE) * GRID_SIZE,
        pos.y,
        round(pos.z / GRID_SIZE) * GRID_SIZE
    )

func measure_distance(a: Vector3, b: Vector3) -> float:
    var dist = Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
    return round(dist / GRID_SIZE) * GRID_SIZE
```

**Trade-offs**:
- ✅ Matches tabletop feel
- ✅ Precise measurements
- ✅ Good for replay consistency
- ⚠️ Slight complexity vs pure gridless

---

### 3. Physics Layers

**Decision**: 6 dedicated collision layers

| Layer | Name | Purpose |
|-------|------|---------|
| 1 | Ground | Battlefield surface |
| 2 | Units | Unit collision shapes |
| 3 | Terrain | Blocking terrain |
| 4 | Areas | Cover/difficult zones |
| 5 | Selection | UI blockers (unused for now) |
| 6 | Projectiles | Attack traces |

**Rationale**:
- Clean separation of physics concerns
- Easy to configure what hits what
- Prevents unintended collisions

**Implementation**:
```gdscript
# Selection raycast - only hits units
query.collision_mask = 1 << (2 - 1)  # Layer 2

# LoS raycast - only hits terrain
query.collision_mask = 1 << (3 - 1)  # Layer 3

# Attack raycast - hits units and terrain
query.collision_mask = (1 << (2 - 1)) | (1 << (3 - 1))  # Layers 2 & 3
```

**Trade-offs**:
- ✅ Clear separation
- ✅ Easy to understand
- ⚠️ Limited to 32 layers (no issue with 6)

---

### 4. Camera Style

**Decision**: Isometric view with limited orbit

**Options Considered**:
1. Fixed isometric (no rotation)
2. Full free camera (FPS-style)
3. Limited orbit (chosen)

**Rationale**:
- Tactical games benefit from consistent viewing angle
- Some rotation helps see around terrain
- Full freedom can be disorienting

**Implementation**:
```gdscript
# Camera rig structure
BattleCamera (pan XZ)
└── Pivot (rotate Y)
    └── Arm (distance Z)
        └── Camera3D (angle X = -45°)

# Orbit limits
var min_orbit_y: float = -45  # degrees
var max_orbit_y: float = 45

# Fixed pitch
var camera_pitch: float = -45  # degrees, looking down
```

**Trade-offs**:
- ✅ Clear battlefield view
- ✅ Consistent visual language
- ✅ Easy to understand positioning
- ⚠️ Some terrain occlusion

---

### 5. Turn Structure

**Decision**: Alternating activation (IGOUGO variant)

**Options Considered**:
1. Full I-Go-You-Go (all units then opponent)
2. Alternating activation (chosen)
3. Simultaneous resolution

**Rationale**:
- Per Age of Fantasy rules
- More engaging than full IGOUGO
- Each player always has something to do
- Easier to implement than simultaneous

**State Machine**:
```gdscript
enum BattlePhase {
    SETUP,        # Initial setup
    DEPLOYMENT,   # Place units
    ACTIVATION,   # Select unit to activate
    ACTION,       # Execute unit action
    END_ROUND,    # Cleanup, check victory
    GAME_OVER     # Battle ended
}
```

**Trade-offs**:
- ✅ Matches tabletop rules
- ✅ Good player engagement
- ✅ Clear game flow
- ⚠️ More state tracking than full IGOUGO

---

### 6. Data Persistence

**Decision**: Godot Resources for all game data

**Rationale**:
- Native serialization (tres/res format)
- Easy editor integration
- Type-safe
- Good for modding (text format)

**Implementation**:
```gdscript
# Unit profile
class_name UnitProfile
extends Resource

@export var unit_name: String
@export var quality: int = 4
@export var defense: int = 4
# ... etc

# Saving
func save_battle(data: BattleSaveData) -> void:
    ResourceSaver.save(data, "user://battle_save.tres")

# Loading
func load_battle() -> BattleSaveData:
    return load("user://battle_save.tres") as BattleSaveData
```

**Trade-offs**:
- ✅ Native Godot support
- ✅ Type safety
- ✅ Editor support
- ⚠️ Larger than JSON
- ⚠️ Version migration needs care

---

### 7. Movement Visualization

**Decision**: Shader-based range indicator

**Options Considered**:
1. Grid cell highlighting (100s of meshes)
2. Decal projection
3. Shader on plane (chosen)

**Rationale**:
- Single draw call
- Smooth gradient looks better
- Easy to customize (color, pattern)
- Good performance with many units

**Implementation**:
```glsl
// movement_range.gdshader
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float range_radius = 6.0;
uniform vec4 color : source_color = vec4(0.2, 0.5, 1.0, 0.4);

void fragment() {
    vec2 centered = UV - vec2(0.5);
    float dist = length(centered) * 2.0;
    float alpha = 1.0 - smoothstep(0.9, 1.0, dist);

    ALBEDO = color.rgb;
    ALPHA = color.a * alpha;
}
```

**Trade-offs**:
- ✅ Great performance
- ✅ Smooth visuals
- ✅ Easy to modify
- ⚠️ Doesn't show terrain blocking

---

### 8. Pathfinding

**Decision**: NavigationServer3D with NavigationAgent3D

**Options Considered**:
1. Custom A* on grid
2. Godot NavigationServer (chosen)
3. Simple line-of-sight movement

**Rationale**:
- Built-in Godot feature
- Handles complex terrain
- Avoidance built-in
- Good performance

**Implementation**:
```gdscript
# In battlefield
NavigationRegion3D
└── NavigationMesh (baked)

# In unit
NavigationAgent3D
├── target_position = destination
├── avoidance_enabled = true
└── radius = 0.5
```

**Trade-offs**:
- ✅ Powerful and flexible
- ✅ Handles complex geometry
- ✅ Multi-agent avoidance
- ⚠️ Requires nav mesh baking
- ⚠️ Can be slow for many units

---

### 9. AI Architecture

**Decision**: Behavior tree with utility scoring

**Options Considered**:
1. Simple state machine
2. Behavior tree (chosen)
3. GOAP (Goal-Oriented Action Planning)

**Rationale**:
- Easy to debug and understand
- Matches decision tree in rules document
- Can be expanded gradually
- Good balance of power/simplicity

**Implementation**:
```gdscript
func decide_action(unit: GameBaseUnit) -> Action:
    # Score all possible actions
    var scored_actions: Array = []

    for target in get_valid_targets(unit):
        var score = evaluate_attack(unit, target)
        scored_actions.append({"action": "attack", "target": target, "score": score})

    for position in get_valid_positions(unit):
        var score = evaluate_move(unit, position)
        scored_actions.append({"action": "move", "position": position, "score": score})

    # Pick highest score
    scored_actions.sort_custom(func(a, b): return a.score > b.score)
    return scored_actions[0]
```

**Trade-offs**:
- ✅ Easy to understand
- ✅ Easy to balance
- ✅ Predictable
- ⚠️ Can feel mechanical
- ⚠️ Needs tuning

---

### 10. Testing Framework

**Decision**: gdUnit4 with PowerShell runner

**Rationale**:
- Most mature Godot 4 testing framework
- Good assertion library
- Active development
- Learned from Five Parsecs that headless mode crashes

**Critical Constraint**:
```
⚠️ NEVER use --headless flag
Signal 11 crash after 8-18 tests
```

**Implementation**:
```powershell
# PowerShell test runner
& $GodotConsole `
    --path $ProjectPath `
    --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
    -a tests/unit/test_combat.gd `
    --quit-after 60
```

**Trade-offs**:
- ✅ Reliable testing
- ✅ Good assertions
- ⚠️ Requires workaround for runner
- ⚠️ GUI opens (minor annoyance)

---

## Performance Targets

### Frame Rate
- **Target**: 60 FPS minimum
- **Hardware**: Mid-range PC (GTX 1060 / RX 580 equivalent)

### Unit Count
- **Target**: 100 units without frame drops
- **Stretch**: 200 units at 30 FPS

### Optimization Strategies
1. Object pooling for effects
2. LOD for distant units
3. Shader-based indicators
4. Batched pathfinding
5. Visibility culling

---

## Future Considerations

### Multiplayer
If adding later:
- Use Godot's MultiplayerAPI
- Host-authoritative model
- Need turn timer
- Consider replay system

### Modding
Resource-based design supports:
- Custom unit profiles
- Custom weapon profiles
- Custom terrain
- Custom rules

### Mobile
May need:
- Touch controls
- Reduced unit count
- Simplified shaders
- Lower texture resolution

---

## Decision Log

| Date | Decision | Rationale | Alternatives |
|------|----------|-----------|--------------|
| 2024-11-22 | 1:1 scale | Direct mapping to rules | 10:1, 100:1 |
| 2024-11-22 | 0.25" grid | Per rules spec | No grid, 1" grid |
| 2024-11-22 | Alternating activation | Per rules | Full IGOUGO |
| 2024-11-22 | Resources for data | Native support | JSON, SQLite |
| 2024-11-22 | Shader movement viz | Performance | Grid cells |
| 2024-11-22 | NavigationServer | Built-in, powerful | Custom A* |
| 2024-11-22 | gdUnit4 UI mode | Avoid crash | GUT, custom |

---

## Open Questions

### To Decide During Development

1. **Formation management UI**
   - How to visualize unit coherency?
   - Auto-arrange vs manual placement?

2. **Combat animations**
   - How much animation is needed?
   - When does it slow down gameplay?

3. **Special rule UI**
   - How to display complex rules?
   - Tooltips vs panel vs log?

4. **Replay system**
   - Worth implementing?
   - What level of detail?

5. **Undo system**
   - Allow undo during turn?
   - How much history?

---

This document captures the key technical decisions. Update as new decisions are made or existing ones are revised based on testing.
