@tool
extends GdUnitGameTest

# Mock enemy state class for testing
class MockEnemyState extends Resource:
    var position: Vector2 = Vector2(10, 10)
    var health: float = 100.0
    var max_health: float = 100.0
    var behavior: int = 0
    var movement_range: float = 4.0
    var weapon_range: float = 6.0
    var stance: int = 0
    var status_effects: Dictionary = {}
    var target: Resource = null
    var equipment: Dictionary = {"weapon": "rifle", "armor": "light"}
    
    func get_position() -> Vector2:
        return position
    
    func set_position(pos: Vector2) -> void:
        position = pos
    
    func get_health() -> float:
        return health
    
    func set_health(test_value: float) -> void:
        health = clamp(test_value, 0.0, max_health)
    
    func take_damage(amount: float) -> void:
        health = max(0.0, health - amount)
    
    func get_behavior() -> int:
        return behavior
    
    func set_behavior(test_value: int) -> void:
        behavior = test_value
    
    func get_movement_range() -> float:
        return movement_range
    
    func get_weapon_range() -> float:
        return weapon_range
    
    func get_stance() -> int:
        return stance
    
    func set_stance(test_value: int) -> void:
        stance = test_value
    
    func apply_status_effect(effect: String, duration: int) -> void:
        status_effects[effect] = duration
    
    func get_status_effects() -> Dictionary:
        return status_effects
    
    func set_target(new_target: Resource) -> void:
        target = new_target
    
    func get_target() -> Resource:
        return target
    
    func get_equipment() -> Dictionary:
        return equipment
    
    func set_equipment(new_equipment: Dictionary) -> void:
        equipment = new_equipment
    
    func get_state() -> Dictionary:
        return {
            "position": position,
            "health": health,
            "behavior": behavior,
            "stance": stance,
            "status_effects": status_effects,
            "equipment": equipment,
        }
    
    func save() -> Dictionary:
        return get_state()
    
    func load(state: Dictionary) -> void:
        if state.has("position"):
            position = state.position
        if state.has("health"):
            health = state.health
        if state.has("behavior"):
            behavior = state.behavior
        if state.has("stance"):
            stance = state.stance
        if state.has("status_effects"):
            status_effects = state.status_effects
        if state.has("equipment"):
            equipment = state.equipment

# Test variables
var _enemies: Array[MockEnemyState] = []

# Setup and teardown
func before_test() -> void:
    super.before_test()
    
    # Create test enemies
    for i: int in range(3):
        var enemy := MockEnemyState.new()
        enemy.set_position(Vector2(i * 10, i * 10))
        _enemies.append(enemy)

func after_test() -> void:
    _enemies.clear()
    super.after_test()

# Helper methods
func _create_test_enemy() -> MockEnemyState:
    var enemy := MockEnemyState.new()
    enemy.set_position(Vector2(50, 50))
    return enemy

func _create_test_group(size: int = 3) -> Array[MockEnemyState]:
    var group: Array[MockEnemyState] = []
    for i: int in range(size):
        var enemy := _create_test_enemy()
        enemy.set_position(Vector2(i * 20, i * 20))
        group.append(enemy)
    return group

# Basic state tests
func test_basic_state() -> void:
    var enemy := _create_test_enemy()
    
    # Set initial state
    var health := 100.0
    var position := Vector2(100, 100)
    enemy.set_health(health)
    enemy.set_position(position)
    enemy.set_stance(0) # AGGRESSIVE
    
    # Verify state was set
    assert_that(enemy.get_health()).is_equal(health)
    assert_that(enemy.get_position()).is_equal(position)
    assert_that(enemy.get_stance()).is_equal(0)

# State persistence tests
func test_state_persistence() -> void:
    var enemy := _create_test_enemy()
    
    # Modify state
    enemy.take_damage(20)
    enemy.set_position(Vector2(100, 100))
    
    # Save state
    var saved_state: Dictionary = enemy.save()
    
    # Create new enemy and load state
    var new_enemy := MockEnemyState.new()
    new_enemy.load(saved_state)
    
    # Verify state restoration
    assert_that(new_enemy.get_health()).is_equal(enemy.get_health())
    assert_that(new_enemy.get_position()).is_equal(enemy.get_position())

# Group state persistence tests
func test_group_state_persistence() -> void:
    var group := _create_test_group()
    
    # Modify group states
    for enemy in group:
        enemy.take_damage(10)
        var current_pos = enemy.get_position()
        enemy.set_position(current_pos + Vector2(50, 50))
    
    # Save group states
    var saved_states: Array = []
    for enemy in group:
        saved_states.append(enemy.save())
    
    # Create new group and restore states
    var new_group := _create_test_group()
    for i: int in range(new_group.size()):
        if i < saved_states.size():
            new_group[i].load(saved_states[i])
    
    # Verify group state restoration
    for i: int in range(group.size()):
        if i < new_group.size():
            assert_that(new_group[i].get_health()).is_equal(group[i].get_health())

# Combat state persistence tests
func test_combat_state_persistence() -> void:
    var enemy := _create_test_enemy()
    var target := _create_test_enemy()
    
    # Setup combat state
    enemy.take_damage(20)
    enemy.apply_status_effect("poison", 3)
    enemy.set_target(target)
    
    # Save combat state
    var saved_state: Dictionary = enemy.save()
    
    # Create new enemy and load state
    var new_enemy := MockEnemyState.new()
    new_enemy.load(saved_state)
    
    # Verify combat state restoration
    assert_that(new_enemy.get_health()).is_equal(enemy.get_health())
    assert_that(new_enemy.get_status_effects()).has("poison")
    # Note: Target restoration would need special handling in real implementation

# AI state persistence tests
func test_ai_state_persistence() -> void:
    var enemy := _create_test_enemy()
    
    # Setup AI state
    enemy.set_behavior(1) # DEFENSIVE
    enemy.set_stance(2) # COVER
    
    # Save and restore
    var saved_state := enemy.save()
    var new_enemy := MockEnemyState.new()
    new_enemy.load(saved_state)
    
    # Verify AI state
    assert_that(new_enemy.get_behavior()).is_equal(enemy.get_behavior())
    assert_that(new_enemy.get_stance()).is_equal(enemy.get_stance())

# Equipment persistence tests
func test_equipment_persistence() -> void:
    var enemy := _create_test_enemy()
    
    # Set equipment
    var equipment := {"weapon": "plasma_rifle", "armor": "heavy", "accessory": "scope"}
    enemy.set_equipment(equipment)
    
    # Save and restore
    var saved_state := enemy.save()
    var new_enemy := MockEnemyState.new()
    new_enemy.load(saved_state)
    
    # Verify equipment
    assert_that(new_enemy.get_equipment()).is_equal(equipment)

# Error handling tests
func test_invalid_state_handling() -> void:
    var enemy := _create_test_enemy()
    
    # Test invalid state loading
    var invalid_state := {"invalid_key": "invalid_value"}
    enemy.load(invalid_state)
    
    # Enemy should remain in valid state
    assert_that(enemy.get_health()).is_greater(0.0)
    assert_that(enemy.get_position()).is_not_null()
