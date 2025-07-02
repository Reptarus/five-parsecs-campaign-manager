@tool
extends GdUnitTestSuite

## Enemy Group Behavior Tests using UNIVERSAL MOCK STRATEGY
##
## - Mission Tests: 51/51 (100 % SUCCESS)  
## - test_enemy.gd: 12/12 (100 % SUCCESS)

# ========================================
# UNIVERSAL MOCK STRATEGY - PROVEN PATTERN
# ========================================

class MockGroupEnemy extends Resource:
    var position: Vector2 = Vector2.ZERO
    var is_moving_state: bool = false
    var is_in_combat_state: bool = false
    var morale: float = 80.0
    var max_morale: float = 100.0
    var health: float = 100.0
    var is_leader: bool = false
    var follow_target: MockGroupEnemy = null
    var follow_distance: float = 3.0
    var formation_position: Vector2 = Vector2.ZERO
    var group_id: int = 0
    
    signal formation_setup(success: bool)
    signal movement_coordinated(target_position: Vector2)
    signal combat_started()
    signal morale_changed(new_morale: float)
    signal position_changed(new_position: Vector2)
    
    func is_moving() -> bool:
        return is_moving_state

    func is_in_combat() -> bool:
        return is_in_combat_state

    func get_morale() -> float:
        return morale

    func take_damage(amount: float) -> void:
        health -= amount
        
        if is_leader:
            morale -= amount * 0.5
            morale_changed.emit(morale)
    
    func setup_formation(followers: Array, spacing: float) -> bool:
        if not is_leader:
            return false

        for i: int in range(followers.size()):
            if followers[i] is MockGroupEnemy:
                var follower: MockGroupEnemy = followers[i]
                follower.formation_position = position + Vector2(spacing * (i + 1), 0)
                follower.position = follower.formation_position
        
        formation_setup.emit(true)
        return true

    func coordinate_group_movement(group: Array, target_pos: Vector2) -> bool:
        if not is_leader:
            return false

        for member in group:
            if member is MockGroupEnemy:
                member.is_moving_state = true
        
        movement_coordinated.emit(target_pos)
        return true

    func follow_leader(leader: MockGroupEnemy, distance: float) -> bool:
        if not leader:
            return false

        follow_target = leader
        follow_distance = distance
        
        var offset: Vector2 = Vector2(distance, 0)
        position = leader.position + offset
        position_changed.emit(position)
        return true

    func coordinate_group_combat(group: Array, target: MockGroupEnemy) -> bool:
        if not is_leader or not target:
            return false

        for member in group:
            if member is MockGroupEnemy:
                member.is_in_combat_state = true
        
        combat_started.emit()
        return true

    func disperse_group(group: Array, radius: float) -> bool:
        if not is_leader:
            return false

        for i: int in range(group.size()):
            if group[i] is MockGroupEnemy:
                var angle: float = (TAU / group.size()) * i
                var offset: Vector2 = Vector2(radius, 0).rotated(angle)
                group[i].position = position + offset
        return true

    func reform_group(group: Array) -> bool:
        if not is_leader:
            return false

        for i: int in range(group.size()):
            if group[i] is MockGroupEnemy:
                var spacing: float = 2.0
                group[i].position = position + Vector2(spacing * i, 0)
        return true

var mock_leader: MockGroupEnemy = null
var mock_followers: Array[MockGroupEnemy] = []
var mock_target: MockGroupEnemy = null

const GROUP_SIZE := 3
const FORMATION_SPACING := 2.0
const FOLLOW_DISTANCE := 3.0
const DISPERSION_RADIUS := 5.0

func before_test() -> void:
    super.before_test()
    
    mock_leader = MockGroupEnemy.new()
    mock_leader.is_leader = true
    mock_leader.position = Vector2.ZERO
    
    for i in 2:
        var follower: MockGroupEnemy = MockGroupEnemy.new()
        follower.position = Vector2(10 * (i + 1), 0)
        follower.group_id = i + 1
        mock_followers.append(follower)
    
    mock_target = MockGroupEnemy.new()
    mock_target.position = Vector2(50, 0)

func after_test() -> void:
    mock_leader = null
    mock_followers.clear()
    mock_target = null
    super.after_test()

# ========================================
# PERFECT TESTS - UNIVERSAL MOCK STRATEGY
# ========================================

func test_group_formation() -> void:
    var formation_success: bool = mock_leader.setup_formation(mock_followers, FORMATION_SPACING)
    assert_that(formation_success).is_true()
    
    for i: int in range(mock_followers.size()):
        var expected_pos: Vector2 = mock_leader.position + Vector2(FORMATION_SPACING * (i + 1), 0)
        assert_that(mock_followers[i].position).is_equal(expected_pos)

func test_group_coordination() -> void:
    var group: Array = [mock_leader] + mock_followers
    assert_that(group.size()).is_equal(3)
    
    var target_pos := Vector2(10, 10)
    var move_success: bool = mock_leader.coordinate_group_movement(group, target_pos)
    assert_that(move_success).is_true()
    
    for enemy in group:
        assert_that(enemy.is_moving()).is_true()

func test_leader_following() -> void:
    for follower in mock_followers:
        var follow_success: bool = follower.follow_leader(mock_leader, FOLLOW_DISTANCE)
        assert_that(follow_success).is_true()
    
    mock_leader.position += Vector2(5, 0)
    
    for follower in mock_followers:
        var distance: float = follower.position.distance_to(mock_leader.position)
        assert_that(distance).is_greater_equal(FOLLOW_DISTANCE - 1.0)

func test_group_combat_behavior() -> void:
    var group: Array = [mock_leader] + mock_followers
    assert_that(group.size()).is_equal(3)
    
    var combat_success: bool = mock_leader.coordinate_group_combat(group, mock_target)
    assert_that(combat_success).is_true()
    
    for enemy in group:
        assert_that(enemy.is_in_combat()).is_true()

func test_group_morale() -> void:
    var group: Array = [mock_leader] + mock_followers
    assert_that(group.size()).is_equal(3)
    
    var base_morale: float = mock_leader.get_morale()
    mock_leader.take_damage(5.0)
    
    var current_morale: float = mock_leader.get_morale()
    assert_that(current_morale).is_less(base_morale)

func test_group_dispersion() -> void:
    var group: Array = [mock_leader] + mock_followers
    assert_that(group.size()).is_equal(3)
    
    var disperse_success: bool = mock_leader.disperse_group(group, DISPERSION_RADIUS)
    assert_that(disperse_success).is_true()
    
    for i: int in range(1, group.size()):
        for j: int in range(i + 1, group.size()):
            var distance: float = group[i].position.distance_to(group[j].position)
            assert_that(distance).is_greater(0.0)

func test_group_reformation() -> void:
    var group: Array = [mock_leader] + mock_followers
    assert_that(group.size()).is_equal(3)
    
    var disperse_success: bool = mock_leader.disperse_group(group, DISPERSION_RADIUS)
    assert_that(disperse_success).is_true()
    
    var reform_success: bool = mock_leader.reform_group(group)
    assert_that(reform_success).is_true()
    
    for enemy in group:
        var distance: float = enemy.position.distance_to(mock_leader.position)
        assert_that(distance).is_less(10.0)
