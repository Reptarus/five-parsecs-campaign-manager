# Age of Fantasy Digital - Code Transfer Guide

**Document Version**: 1.0
**Created**: 2024-11-22
**Purpose**: File-by-file guide for transferring code from Five Parsecs Campaign Manager

---

## Transfer Summary

### Reuse Percentage: ~40%

| Category | Reusable | Needs Adaptation | New Implementation |
|----------|----------|------------------|-------------------|
| Core Utilities | 90% | 10% | 0% |
| State Management | 30% | 50% | 20% |
| Data Resources | 40% | 50% | 10% |
| Testing | 80% | 20% | 0% |
| UI | 10% | 20% | 70% |
| Game Logic | 0% | 0% | 100% |

---

## Direct Copy (No Modification)

These files can be copied directly with minimal or no changes.

### 1. DiceSystem.gd

**Source**: `src/core/systems/DiceSystem.gd`
**Target**: `src/core/DiceSystem.gd`

```gdscript
# Copy entire file - dice rolling is universal
# Already has: roll(), roll_multiple(), roll_with_modifier()
# Add for AoF:
static func quality_test(quality: int, modifier: int = 0) -> bool:
    var roll = roll()
    return roll >= (quality + modifier)

static func defense_save(defense: int, ap: int = 0) -> bool:
    var roll = roll()
    var target = defense + ap
    return roll >= target
```

**Reason**: Dice mechanics are identical (D6-based).

### 2. Testing Infrastructure

**Source**: `tests/` directory structure
**Target**: `tests/`

Copy:
- Test directory structure
- gdUnit4 configuration
- Test runner scripts

```
tests/
├── unit/
├── integration/
└── TESTING_GUIDE.md (adapt content)
```

**Critical Constraint**: Never use `--headless` flag (signal 11 crash).

### 3. SignalBus Pattern (Optional)

**Source**: `src/core/SignalBus.gd`
**Target**: Not needed if using manager-based signals

If you want a global signal bus:
```gdscript
# SignalBus.gd - Autoload
extends Node

# Battle signals
signal unit_selected(unit: GameBaseUnit)
signal unit_deselected(unit: GameBaseUnit)
signal movement_completed(unit: GameBaseUnit)
signal combat_resolved(attacker, defender, result)
signal phase_changed(new_phase: int)
```

---

## Adapt with Modifications

These files need significant modification but provide a good starting point.

### 1. State Manager → BattleManager

**Source**: `src/core/state/CampaignCreationStateManager.gd`
**Target**: `src/core/BattleManager.gd`

**What to Keep**:
- State machine pattern
- Phase enum structure
- Transition validation
- Signal emission on state change

**What to Change**:
```gdscript
# FROM (Five Parsecs)
enum Phase {
    TRAVEL,
    WORLD,
    BATTLE,
    POST_BATTLE
}

# TO (Age of Fantasy)
enum BattlePhase {
    SETUP,
    DEPLOYMENT,
    ACTIVATION,
    ACTION,
    END_ROUND,
    GAME_OVER
}
```

**Transfer Pattern**:
```gdscript
# Keep this pattern
func _transition_to(new_phase: BattlePhase) -> void:
    var old_phase = current_phase
    current_phase = new_phase
    phase_changed.emit(new_phase)

# Keep validation pattern
func can_transition_to(phase: BattlePhase) -> bool:
    match current_phase:
        BattlePhase.DEPLOYMENT:
            return phase == BattlePhase.ACTIVATION
        # etc.
```

### 2. GameState → BattleState

**Source**: `src/core/state/GameState.gd`
**Target**: `src/core/BattleState.gd`

**Transform**:
```gdscript
# FROM (Five Parsecs)
var current_campaign: Campaign
var current_turn: int
var credits: int
var story_points: int

# TO (Age of Fantasy)
var current_battle: BattleSaveData
var current_round: int
var current_phase: int
var current_team: int
var teams: Array[Team]
var units: Array[GameBaseUnit]
var objectives: Array[Objective]
```

### 3. Character.gd → UnitProfile.gd

**Source**: `src/core/character/Character.gd`
**Target**: `src/resources/UnitProfile.gd`

**What to Keep**:
- Resource class pattern
- Export decorators
- Serialization approach

**Transform**:
```gdscript
# FROM (Five Parsecs)
class_name Character
extends Resource

@export var character_name: String
@export var reactions: int
@export var speed: int
@export var combat_skill: int
@export var toughness: int
@export var savvy: int
@export var luck: int
@export var xp: int
@export var equipment: Array[Equipment]

# TO (Age of Fantasy)
class_name UnitProfile
extends Resource

@export var unit_name: String
@export var quality: int = 4      # Roll this or higher to hit
@export var defense: int = 4      # Roll this or higher to save
@export var movement: int = 6     # Inches
@export var wounds: int = 1       # Health points
@export var base_size: int = 1    # 1" round base

@export var weapon_profiles: Array[WeaponProfile]
@export var special_rules: Array[String]
@export var keywords: Array[String]
@export var points_cost: int
```

### 4. Equipment.gd → WeaponProfile.gd

**Source**: `src/core/economy/Equipment.gd` (or similar)
**Target**: `src/resources/WeaponProfile.gd`

```gdscript
# FROM (Five Parsecs)
class_name Equipment
extends Resource

@export var item_name: String
@export var item_type: String
@export var range_stat: int
@export var shots: int
@export var damage: int
@export var traits: Array[String]

# TO (Age of Fantasy)
class_name WeaponProfile
extends Resource

@export var weapon_name: String
@export var weapon_range: int = 0  # 0 = melee
@export var attacks: int = 1
@export var armor_piercing: int = 0
@export var special_rules: Array[String]

func is_melee() -> bool:
    return weapon_range == 0
```

### 5. Save/Load System

**Source**: `src/core/state/` save/load patterns
**Target**: `src/core/BattleSaveSystem.gd`

**What to Keep**:
- Resource serialization pattern
- File I/O approach
- Error handling

**What to Add**:
```gdscript
# Vector3 serialization for positions
func serialize_position(pos: Vector3) -> Dictionary:
    return {"x": pos.x, "y": pos.y, "z": pos.z}

func deserialize_position(data: Dictionary) -> Vector3:
    return Vector3(data.x, data.y, data.z)

# Transform serialization
func serialize_transform(t: Transform3D) -> Dictionary:
    return {
        "origin": serialize_position(t.origin),
        "rotation": t.basis.get_euler()
    }
```

---

## New Implementations (No Equivalent)

These systems don't exist in Five Parsecs and need fresh implementation.

### 1. SelectionManager.gd

**Purpose**: Handle 3D picking and selection state

```gdscript
class_name SelectionManager
extends Node

signal unit_selected(unit: GameBaseUnit)
signal unit_deselected(unit: GameBaseUnit)
signal selection_cleared()
signal target_selected(target: GameBaseUnit)

var selected_unit: GameBaseUnit = null
var is_selecting_target: bool = false

const UNIT_LAYER: int = 2

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            if is_selecting_target:
                _handle_target_selection(event.position)
            else:
                _handle_unit_selection(event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            cancel_selection()

func _handle_unit_selection(screen_pos: Vector2) -> void:
    var unit = _raycast_for_unit(screen_pos)
    if unit:
        select_unit(unit)
    else:
        clear_selection()

func _raycast_for_unit(screen_pos: Vector2) -> GameBaseUnit:
    var camera = get_viewport().get_camera_3d()
    var ray_origin = camera.project_ray_origin(screen_pos)
    var ray_dir = camera.project_ray_normal(screen_pos)
    var ray_end = ray_origin + ray_dir * 1000.0

    var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    query.collision_mask = 1 << (UNIT_LAYER - 1)
    query.collide_with_areas = false

    var result = get_world_3d().direct_space_state.intersect_ray(query)
    if result:
        return result.collider.get_parent() as GameBaseUnit
    return null

func select_unit(unit: GameBaseUnit) -> void:
    if selected_unit == unit:
        return

    clear_selection()
    selected_unit = unit
    selected_unit.select()
    unit_selected.emit(unit)

func clear_selection() -> void:
    if selected_unit:
        selected_unit.deselect()
        unit_deselected.emit(selected_unit)
        selected_unit = null
    selection_cleared.emit()

func start_target_selection() -> void:
    is_selecting_target = true

func cancel_selection() -> void:
    is_selecting_target = false
    clear_selection()
```

### 2. MovementManager.gd

**Purpose**: Handle pathfinding and movement validation

```gdscript
class_name MovementManager
extends Node

signal movement_started(unit: GameBaseUnit, path: PackedVector3Array)
signal movement_completed(unit: GameBaseUnit)
signal movement_cancelled(unit: GameBaseUnit)
signal invalid_movement(unit: GameBaseUnit, reason: String)

var moving_unit: GameBaseUnit = null
var current_path: PackedVector3Array

func request_movement(unit: GameBaseUnit, destination: Vector3) -> bool:
    # Validate destination is in range
    var distance = _calculate_distance(unit.global_position, destination)
    var max_range = unit.unit_profile.movement

    if distance > max_range:
        invalid_movement.emit(unit, "Destination out of range")
        return false

    # Get path from NavigationServer
    var path = NavigationServer3D.map_get_path(
        get_world_3d().navigation_map,
        unit.global_position,
        destination,
        true
    )

    if path.is_empty():
        invalid_movement.emit(unit, "No valid path")
        return false

    # Start movement
    moving_unit = unit
    current_path = path
    movement_started.emit(unit, path)
    _execute_movement()
    return true

func _calculate_distance(from: Vector3, to: Vector3) -> float:
    # 2D distance (ignore Y)
    return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _execute_movement() -> void:
    if not moving_unit:
        return

    var nav_agent = moving_unit.nav_agent
    nav_agent.target_position = current_path[-1]

    # Movement handled in unit's _physics_process

func cancel_movement() -> void:
    if moving_unit:
        movement_cancelled.emit(moving_unit)
        moving_unit = null
        current_path.clear()
```

### 3. CombatManager.gd

**Purpose**: Resolve attacks per AoF rules

```gdscript
class_name CombatManager
extends Node

signal attack_declared(attacker: GameBaseUnit, target: GameBaseUnit, weapon: WeaponProfile)
signal dice_rolled(roll_type: String, rolls: Array[int], successes: int)
signal damage_dealt(target: GameBaseUnit, wounds: int)
signal unit_destroyed(unit: GameBaseUnit)

func resolve_shooting(attacker: GameBaseUnit, target: GameBaseUnit, weapon: WeaponProfile) -> Dictionary:
    attack_declared.emit(attacker, target, weapon)

    var result = {
        "hits": 0,
        "wounds": 0,
        "saved": 0,
        "damage": 0
    }

    # Step 1: Roll to hit (quality test)
    var hit_rolls: Array[int] = []
    for i in weapon.attacks:
        hit_rolls.append(DiceSystem.roll())

    var quality = attacker.unit_profile.quality
    var hits = hit_rolls.filter(func(r): return r >= quality).size()
    result.hits = hits
    dice_rolled.emit("Hit", hit_rolls, hits)

    if hits == 0:
        return result

    # Step 2: Defense saves
    var save_rolls: Array[int] = []
    for i in hits:
        save_rolls.append(DiceSystem.roll())

    var defense = target.unit_profile.defense
    var ap = weapon.armor_piercing
    var save_target = defense + ap
    var saves = save_rolls.filter(func(r): return r >= save_target).size()
    result.saved = saves

    var wounds = hits - saves
    result.wounds = wounds
    dice_rolled.emit("Save", save_rolls, saves)

    if wounds == 0:
        return result

    # Step 3: Apply damage
    target.take_damage(wounds)
    result.damage = wounds
    damage_dealt.emit(target, wounds)

    if target.current_wounds <= 0:
        unit_destroyed.emit(target)

    return result

func resolve_melee(attacker: GameBaseUnit, defender: GameBaseUnit) -> Dictionary:
    # Similar to shooting but:
    # - Both sides attack
    # - Apply fatigue
    # - Check for strike back
    pass
```

### 4. TurnManager.gd

**Purpose**: Track activations and turn order

```gdscript
class_name TurnManager
extends Node

signal turn_started(team: int)
signal unit_activated(unit: GameBaseUnit)
signal unit_turn_ended(unit: GameBaseUnit)
signal all_units_activated()
signal round_ended()

var units: Array[GameBaseUnit] = []
var activated_units: Array[GameBaseUnit] = []
var current_team: int = 1

func start_round() -> void:
    activated_units.clear()
    for unit in units:
        unit.is_activated = false
    current_team = _determine_first_player()
    turn_started.emit(current_team)

func activate_unit(unit: GameBaseUnit) -> void:
    if unit.is_activated:
        return

    unit.is_activated = true
    activated_units.append(unit)
    unit_activated.emit(unit)

func end_unit_turn(unit: GameBaseUnit) -> void:
    unit_turn_ended.emit(unit)

    # Switch to other team
    current_team = 1 if current_team == 2 else 2
    turn_started.emit(current_team)

    # Check if round complete
    if _are_all_units_activated():
        all_units_activated.emit()
        round_ended.emit()

func _are_all_units_activated() -> bool:
    return activated_units.size() == units.size()

func _determine_first_player() -> int:
    # Player who activated all units first last round goes first
    # For prototype: alternate or roll off
    return 1

func get_available_units(team: int) -> Array[GameBaseUnit]:
    return units.filter(func(u): return u.team == team and not u.is_activated)
```

### 5. TargetingManager.gd

**Purpose**: Validate targets for attacks

```gdscript
class_name TargetingManager
extends Node

signal valid_targets_found(targets: Array[GameBaseUnit])
signal no_valid_targets()

const TERRAIN_LAYER: int = 3

func find_valid_targets(attacker: GameBaseUnit, weapon: WeaponProfile) -> Array[GameBaseUnit]:
    var all_enemies = _get_enemy_units(attacker.team)
    var valid: Array[GameBaseUnit] = []

    for enemy in all_enemies:
        if _is_valid_target(attacker, enemy, weapon):
            valid.append(enemy)

    if valid.is_empty():
        no_valid_targets.emit()
    else:
        valid_targets_found.emit(valid)

    return valid

func _is_valid_target(attacker: GameBaseUnit, target: GameBaseUnit, weapon: WeaponProfile) -> bool:
    # Check range
    var distance = attacker.global_position.distance_to(target.global_position)
    if distance > weapon.weapon_range and weapon.weapon_range > 0:
        return false

    # Check line of sight (for shooting)
    if weapon.weapon_range > 0:
        if not _has_line_of_sight(attacker, target):
            return false

    return true

func _has_line_of_sight(attacker: GameBaseUnit, target: GameBaseUnit) -> bool:
    var space_state = attacker.get_world_3d().direct_space_state

    var origin = attacker.global_position + Vector3.UP * 1.0
    var destination = target.global_position + Vector3.UP * 1.0

    var query = PhysicsRayQueryParameters3D.create(origin, destination)
    query.collision_mask = 1 << (TERRAIN_LAYER - 1)
    query.collide_with_areas = false

    var result = space_state.intersect_ray(query)
    return result.is_empty()  # No terrain blocking = has LoS

func _get_enemy_units(team: int) -> Array[GameBaseUnit]:
    # Get all units not on this team
    var battle = get_tree().current_scene
    var all_units = battle.get_node("Units").get_children()
    return all_units.filter(func(u): return u.team != team)
```

---

## Testing Patterns to Transfer

### Test Structure Pattern

```gdscript
# FROM Five Parsecs - Keep this pattern
class_name TestCombatResolution
extends GdUnitTestSuite

var combat_manager: CombatManager
var attacker: GameBaseUnit
var defender: GameBaseUnit

func before_test() -> void:
    combat_manager = CombatManager.new()
    add_child(combat_manager)

    attacker = _create_test_unit(4, 4, 1)  # Q4, D4, 1 wound
    defender = _create_test_unit(4, 4, 1)

func after_test() -> void:
    combat_manager.queue_free()
    attacker.queue_free()
    defender.queue_free()

func test_hit_on_quality_or_higher() -> void:
    # Arrange
    var weapon = _create_weapon(12, 1, 0)  # Range 12, 1 attack, AP 0

    # Act - Mock dice to return 4 (quality value)
    DiceSystem.set_mock_rolls([4])
    var result = combat_manager.resolve_shooting(attacker, defender, weapon)

    # Assert
    assert_int(result.hits).is_equal(1)

func _create_test_unit(quality: int, defense: int, wounds: int) -> GameBaseUnit:
    var unit = GameBaseUnit.new()
    unit.unit_profile = UnitProfile.new()
    unit.unit_profile.quality = quality
    unit.unit_profile.defense = defense
    unit.unit_profile.wounds = wounds
    add_child(unit)
    return unit

func _create_weapon(range_: int, attacks: int, ap: int) -> WeaponProfile:
    var weapon = WeaponProfile.new()
    weapon.weapon_range = range_
    weapon.attacks = attacks
    weapon.armor_piercing = ap
    return weapon
```

### Mock Dice for Testing

Add to DiceSystem.gd:
```gdscript
# Testing support
static var mock_rolls: Array[int] = []
static var mock_index: int = 0

static func set_mock_rolls(rolls: Array[int]) -> void:
    mock_rolls = rolls
    mock_index = 0

static func clear_mocks() -> void:
    mock_rolls.clear()
    mock_index = 0

static func roll() -> int:
    if mock_rolls.size() > 0 and mock_index < mock_rolls.size():
        var result = mock_rolls[mock_index]
        mock_index += 1
        return result
    return randi_range(1, 6)
```

---

## Lessons Learned to Apply

### From Five Parsecs Development

1. **Test First, Fix Fast**
   - Tests catch bugs 8x faster than code review
   - Write tests for combat math immediately

2. **Avoid Headless Testing**
   - Signal 11 crash after 8-18 tests
   - Use PowerShell runner with UI mode

3. **State Machine Pattern Works**
   - Phase-based flow is clean
   - Easy to debug and extend

4. **Resource Pattern for Data**
   - Serialization is automatic
   - Easy to create in editor
   - Good for modding later

5. **Surgical Edits Over Rewrites**
   - Desktop Commander edit_block is precise
   - Avoid large file rewrites

6. **Signal Decoupling**
   - Systems can be developed independently
   - Easy to add/remove features

### Avoid These Mistakes

1. **Don't create Manager/Coordinator classes that just delegate**
   - Managers should have logic, not just pass-through

2. **Don't skip testing**
   - Combat math must match tabletop exactly
   - Tests prevent regressions

3. **Don't hardcode values**
   - Use exported properties
   - Data-driven is more flexible

4. **Don't nest scenes too deep**
   - Keep hierarchy manageable
   - Document unusual structures

---

## Migration Checklist

### Phase 1: Foundation
- [ ] Copy DiceSystem.gd
- [ ] Adapt GameState → BattleState
- [ ] Set up test infrastructure
- [ ] Configure project settings

### Phase 2: Data Resources
- [ ] Create UnitProfile.gd (adapt from Character.gd)
- [ ] Create WeaponProfile.gd (adapt from Equipment.gd)
- [ ] Create sample unit profiles
- [ ] Create sample weapon profiles

### Phase 3: Core Systems
- [ ] Create BattleManager (adapt from StateManager)
- [ ] Create SelectionManager (new)
- [ ] Create MovementManager (new)
- [ ] Create TurnManager (new)

### Phase 4: Combat
- [ ] Create CombatManager (new)
- [ ] Create TargetingManager (new)
- [ ] Create MoraleManager (new)
- [ ] Port combat tests

### Phase 5: Save/Load
- [ ] Adapt save/load patterns
- [ ] Add Vector3 serialization
- [ ] Create BattleSaveData resource

---

## File Mapping Quick Reference

| Five Parsecs | Age of Fantasy | Action |
|-------------|----------------|--------|
| DiceSystem.gd | DiceSystem.gd | Copy + add methods |
| GameState.gd | BattleState.gd | Heavy adapt |
| CampaignCreationStateManager.gd | BattleManager.gd | Heavy adapt |
| Character.gd | UnitProfile.gd | Transform properties |
| Equipment.gd | WeaponProfile.gd | Transform properties |
| SignalBus.gd | (Manager signals) | Pattern only |
| tests/ structure | tests/ | Copy structure |
| - | SelectionManager.gd | New |
| - | MovementManager.gd | New |
| - | CombatManager.gd | New |
| - | TurnManager.gd | New |
| - | TargetingManager.gd | New |

---

This guide provides concrete paths for code reuse while highlighting what needs fresh implementation. Focus on adapting patterns rather than copying code verbatim.
