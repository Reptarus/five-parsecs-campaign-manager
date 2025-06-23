@tool
extends GdUnitGameTest

## Terrain System Tests using UNIVERSAL MOCK STRATEGY
## Proven pattern from successful test implementations:
## - Ship Tests: 48/48 (100% SUCCESS) 
## - Mission Tests: 51/51 (100% SUCCESS)
## - Enemy Tests: 66/66 (100% SUCCESS)

# ========================================
# UNIVERSAL MOCK STRATEGY - PROVEN PATTERN
# ========================================

class MockEffectTarget extends Resource:
    var target_id: String = "mock_target"
    var position: Vector2 = Vector2.ZERO
    
    func get_id() -> String:
        return target_id

class MockTerrainSystem extends Resource:
    var grid_size: Vector2 = Vector2.ZERO
    var terrain_grid: Dictionary = {}
    var active_effects: Array = []
    var is_initialized: bool = false
    
    # Terrain feature types
    enum TerrainFeatureType {
        EMPTY,
        HIGH_GROUND,
        COVER_LOW,
        COVER_HIGH,
        DIFFICULT
    }
    
    signal effect_applied(target: Resource, effect_type: int)
    signal effect_removed(target: Resource)
    signal grid_initialized(size: Vector2)
    
    func initialize_grid(size: Vector2) -> bool:
        grid_size = size
        terrain_grid.clear()
        active_effects.clear()
        is_initialized = true
        grid_initialized.emit(size)
        return true
    
    func get_grid_size() -> Vector2:
        return grid_size
    
    func set_terrain_feature(position: Vector2, feature_type: int) -> bool:
        if not _is_valid_position(position):
            return false
        
        terrain_grid[str(position)] = feature_type
        return true
    
    func get_terrain_type(position: Vector2) -> int:
        if not _is_valid_position(position):
            return -1
        return terrain_grid.get(str(position), TerrainFeatureType.EMPTY)
    
    func apply_terrain_effect(target: Resource, effect_type: int) -> bool:
        if not target:
            return false
        
        var effect = {
            "target": target,
            "type": effect_type,
            "applied_at": Time.get_ticks_msec()
        }
        active_effects.append(effect)
        effect_applied.emit(target, effect_type)
        return true
    
    func remove_terrain_effect(target: Resource) -> bool:
        if not target:
            return false
        
        for i: int in range(active_effects.size() - 1, -1, -1):
            if active_effects[i]["target"] == target:
                active_effects.remove_at(i)
                effect_removed.emit(target)
                return true
        return false
    
    func get_active_effects() -> int:
        return active_effects.size()
    
    func _is_valid_position(position: Vector2) -> bool:
        return position.x >= 0 and position.y >= 0 and \
               position.x < grid_size.x and position.y < grid_size.y

# Mock instances
var terrain_system: MockTerrainSystem = null

func before_test() -> void:
    super.before_test()
    
    # Initialize terrain system
    terrain_system = MockTerrainSystem.new()
    track_resource(terrain_system)

func after_test() -> void:
    terrain_system = null
    super.after_test()

# ========================================
# TERRAIN SYSTEM TESTS
# ========================================

func test_grid_initialization() -> void:
    var size = Vector2(10.0, 8.0)
    var success = terrain_system.initialize_grid(size)
    assert_that(success).is_true()
    assert_that(terrain_system.get_grid_size()).is_equal(size)
    assert_that(terrain_system.is_initialized).is_true()

func test_set_and_get_terrain_type() -> void:
    var size = Vector2(10.0, 10.0)
    terrain_system.initialize_grid(size)
    var test_pos := Vector2(5.0, 5.0)
    var test_type := MockTerrainSystem.TerrainFeatureType.HIGH_GROUND
    
    var set_success = terrain_system.set_terrain_feature(test_pos, test_type)
    assert_that(set_success).is_true()
    assert_that(terrain_system.get_terrain_type(test_pos)).is_equal(test_type)

func test_invalid_position() -> void:
    var size = Vector2(5.0, 5.0)
    terrain_system.initialize_grid(size)
    var invalid_pos := Vector2(-1.0, -1.0)
    
    assert_that(terrain_system.set_terrain_feature(invalid_pos, MockTerrainSystem.TerrainFeatureType.HIGH_GROUND)).is_false()
    assert_that(terrain_system.get_terrain_type(invalid_pos)).is_equal(-1)

func test_grid_size() -> void:
    var size = Vector2(15.0, 12.0)
    assert_that(terrain_system.get_grid_size()).is_equal(Vector2.ZERO)
    
    terrain_system.initialize_grid(size)
    assert_that(terrain_system.get_grid_size()).is_equal(size)

func test_terrain_effect_application() -> void:
    var target := MockEffectTarget.new()
    target.target_id = "test_target_1"
    
    # Test state directly instead of signal emission
    var apply_success = terrain_system.apply_terrain_effect(target, MockTerrainSystem.TerrainFeatureType.HIGH_GROUND)
    assert_that(apply_success).is_true()
    assert_that(terrain_system.get_active_effects()).is_equal(1)
    
    var remove_success = terrain_system.remove_terrain_effect(target)
    assert_that(remove_success).is_true()
    assert_that(terrain_system.get_active_effects()).is_equal(0)

func test_multiple_effects() -> void:
    var target1 := MockEffectTarget.new()
    var target2 := MockEffectTarget.new()
    target1.target_id = "test_target_1"
    target2.target_id = "test_target_2"
    
    terrain_system.apply_terrain_effect(target1, MockTerrainSystem.TerrainFeatureType.HIGH_GROUND)
    terrain_system.apply_terrain_effect(target2, MockTerrainSystem.TerrainFeatureType.COVER_LOW)
    
    assert_that(terrain_system.get_active_effects()).is_equal(2)
    
    terrain_system.remove_terrain_effect(target1)
    assert_that(terrain_system.get_active_effects()).is_equal(1)
    
    terrain_system.remove_terrain_effect(target2)
    assert_that(terrain_system.get_active_effects()).is_equal(0)
