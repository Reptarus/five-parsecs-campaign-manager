@tool
extends GdUnitGameTest

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

#
class MockTerrainTypes:
    enum Type {
        EMPTY,
        WALL,
        COVER_LOW,
        COVER_HIGH,
        DIFFICULT
    }

class MockPositionValidator extends Resource:
    var _bounds: Rect2i
    var _terrain_data: Array = []
    
    func set_bounds(bounds: Rect2i) -> void:
        _bounds = bounds
    
    func set_terrain_data(data: Array) -> void:
        _terrain_data = data
    
    func is_position_valid(pos: Vector2i) -> bool:
        return pos.x >= _bounds.position.x and pos.y >= _bounds.position.y and \
               pos.x < _bounds.position.x + _bounds.size.x and pos.y < _bounds.position.y + _bounds.size.y

    func is_position_walkable(pos: Vector2i) -> bool:
        if not is_position_valid(pos):
            return false

        if pos.x < 0 or pos.y < 0 or pos.x >= _terrain_data.size():
            return false

        if pos.y >= _terrain_data[pos.x].size():
            return false
        
        var cell = _terrain_data[pos.x][pos.y]
        return cell.get("walkable", true)

    func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
        # Simple line of sight check - blocked by walls
        var line_points = _get_line_points(from, to)
        for point in line_points:
            if point == from or point == to:
                continue
            if is_position_valid(point):
                var x = point.x
                var y = point.y
                if x < _terrain_data.size() and y < _terrain_data[x].size():
                    if _terrain_data[x][y].get("blocks_line_of_sight", false):
                        return false
        return true

    func are_positions_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
        var diff = (pos1 - pos2).abs()
        return diff.x <= 1 and diff.y <= 1 and (diff.x + diff.y) > 0

    func get_manhattan_distance(pos1: Vector2i, pos2: Vector2i) -> int:
        return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y)

    func get_euclidean_distance(pos1: Vector2i, pos2: Vector2i) -> float:
        var diff = pos1 - pos2
        return sqrt(diff.x * diff.x + diff.y * diff.y)

    func is_position_in_range(center: Vector2i, target: Vector2i, range_val: int) -> bool:
        return get_manhattan_distance(center, target) <= range_val

    func find_path(start: Vector2i, end: Vector2i) -> Array:
        if not is_position_walkable(start) or not is_position_walkable(end):
            return []
        
        # Simple pathfinding - return direct path if possible
        return [start, end]

    func is_path_valid(path: Array) -> bool:
        if path.is_empty():
            return false

        for pos in path:
            if not is_position_walkable(pos):
                return false
        return true

    func get_area_positions(center: Vector2i, radius: int) -> Array:
        var positions: Array = []
        for x: int in range(center.x - radius, center.x + radius + 1):
            for y: int in range(center.y - radius, center.y + radius + 1):
                var pos = Vector2i(x, y)
                if is_position_valid(pos):
                    if get_manhattan_distance(center, pos) <= radius:
                        positions.append(pos)
        return positions

    func _get_line_points(from: Vector2i, to: Vector2i) -> Array:
        var points: Array = []
        var diff = to - from
        var steps = max(abs(diff.x), abs(diff.y))
        
        if steps == 0:
            return [from]

        for i: int in range(steps + 1):
            var t = float(i) / float(steps)
            var point = Vector2i(
                int(from.x + diff.x * t),
                int(from.y + diff.y * t)
            )
            points.append(point)
        return points

var _validator: Resource = null
var _terrain_data: Array = []

func before_test() -> void:
    super.before_test()
    _validator = MockPositionValidator.new()
    track_resource(_validator)
    _setup_test_terrain()

func after_test() -> void:
    _validator = null
    _terrain_data.clear()
    super.after_test()

func _setup_test_terrain() -> void:
    # Create 5x5 test terrain
    _terrain_data = []
    for x: int in range(5):
        var row: Array = []
        for y: int in range(5):
            var cell = {
                "type": MockTerrainTypes.Type.EMPTY,
                "walkable": true,
                "blocks_line_of_sight": false
            }
            row.append(cell)
        _terrain_data.append(row)
    
    # Add some walls and cover
    _terrain_data[2][2] = {
        "type": MockTerrainTypes.Type.WALL,
        "walkable": false,
        "blocks_line_of_sight": true
    }
    _terrain_data[1][3] = {
        "type": MockTerrainTypes.Type.COVER_HIGH,
        "walkable": true,
        "blocks_line_of_sight": true
    }

func test_position_bounds_validation() -> void:
    var bounds = Rect2i(0, 0, 5, 5)
    _safe_call_method(_validator, "set_bounds", [bounds])
    
    # Test valid positions
    assert_that(_safe_call_method(_validator, "is_position_valid", [Vector2i(0, 0)])).is_true()
    assert_that(_safe_call_method(_validator, "is_position_valid", [Vector2i(4, 4)])).is_true()
    assert_that(_safe_call_method(_validator, "is_position_valid", [Vector2i(2, 3)])).is_true()
    
    # Test invalid positions
    assert_that(_safe_call_method(_validator, "is_position_valid", [Vector2i(-1, 0)])).is_false()
    assert_that(_safe_call_method(_validator, "is_position_valid", [Vector2i(5, 0)])).is_false()
    assert_that(_safe_call_method(_validator, "is_position_valid", [Vector2i(0, 5)])).is_false()

func test_walkability_validation() -> void:
    _safe_call_method(_validator, "set_terrain_data", [_terrain_data])
    
    # Test walkable positions
    assert_that(_safe_call_method(_validator, "is_position_walkable", [Vector2i(0, 0)])).is_true()
    assert_that(_safe_call_method(_validator, "is_position_walkable", [Vector2i(1, 1)])).is_true()
    assert_that(_safe_call_method(_validator, "is_position_walkable", [Vector2i(3, 3)])).is_true()
    
    # Test non-walkable positions
    assert_that(_safe_call_method(_validator, "is_position_walkable", [Vector2i(2, 2)])).is_false()

func test_line_of_sight_validation() -> void:
    _safe_call_method(_validator, "set_terrain_data", [_terrain_data])
    
    # Test clear line of sight
    assert_that(_safe_call_method(_validator, "has_line_of_sight", [Vector2i(0, 0), Vector2i(1, 1)])).is_true()
    assert_that(_safe_call_method(_validator, "has_line_of_sight", [Vector2i(3, 3), Vector2i(4, 4)])).is_true()
    
    # Test blocked line of sight
    assert_that(_safe_call_method(_validator, "has_line_of_sight", [Vector2i(0, 0), Vector2i(4, 4)])).is_false()

func test_adjacency_validation() -> void:
    var center = Vector2i(2, 2)
    
    # Test adjacent positions
    assert_that(_safe_call_method(_validator, "are_positions_adjacent", [center, Vector2i(1, 2)])).is_true()
    assert_that(_safe_call_method(_validator, "are_positions_adjacent", [center, Vector2i(3, 2)])).is_true()
    assert_that(_safe_call_method(_validator, "are_positions_adjacent", [center, Vector2i(2, 1)])).is_true()
    assert_that(_safe_call_method(_validator, "are_positions_adjacent", [center, Vector2i(2, 3)])).is_true()
    
    # Test diagonal adjacency if supported
    assert_that(_safe_call_method(_validator, "are_positions_adjacent", [center, Vector2i(1, 1)])).is_true()
    assert_that(_safe_call_method(_validator, "are_positions_adjacent", [center, Vector2i(3, 3)])).is_true()
    
    # Test non-adjacent positions
    assert_that(_safe_call_method(_validator, "are_positions_adjacent", [center, Vector2i(0, 0)])).is_false()

func test_distance_calculations() -> void:
    var pos1 = Vector2i(0, 0)
    var pos2 = Vector2i(3, 4)
    
    # Test Manhattan distance
    var manhattan_distance = _safe_call_method(_validator, "get_manhattan_distance", [pos1, pos2])
    assert_that(manhattan_distance).is_equal(7)
    
    # Test Euclidean distance
    var euclidean_distance = _safe_call_method(_validator, "get_euclidean_distance", [pos1, pos2])
    assert_that(euclidean_distance).is_almost_equal(5.0, 0.1)

func test_range_validation() -> void:
    var center = Vector2i(2, 2)
    var range_2 = 2
    
    # Test positions within range
    assert_that(_safe_call_method(_validator, "is_position_in_range", [center, Vector2i(1, 1), range_2])).is_true()
    assert_that(_safe_call_method(_validator, "is_position_in_range", [center, Vector2i(3, 3), range_2])).is_true()
    assert_that(_safe_call_method(_validator, "is_position_in_range", [center, Vector2i(2, 4), range_2])).is_true()
    
    # Test positions outside range
    assert_that(_safe_call_method(_validator, "is_position_in_range", [center, Vector2i(0, 0), range_2])).is_false()

func test_path_validation() -> void:
    _safe_call_method(_validator, "set_terrain_data", [_terrain_data])
    
    var start = Vector2i(0, 0)
    var end = Vector2i(4, 0)
    
    # Test valid path
    var path = Array(_safe_call_method(_validator, "find_path", [start, end]))
    assert_that(path).is_not_empty()
    assert_that(path[0]).is_equal(start)
    assert_that(path[-1]).is_equal(end)
    
    # Test path validation
    assert_that(_safe_call_method(_validator, "is_path_valid", [path])).is_true()
    
    # Test blocked path
    var blocked_end = Vector2i(2, 2) # Wall position
    var blocked_path = Array(_safe_call_method(_validator, "find_path", [start, blocked_end]))
    assert_that(blocked_path).is_empty()

func test_area_validation() -> void:
    var center = Vector2i(2, 2)
    var radius = 1
    
    # Get area positions
    var area_positions = Array(_safe_call_method(_validator, "get_area_positions", [center, radius]))
    assert_that(area_positions).is_not_empty()
    
    # Verify all positions are within range
    for pos in area_positions:
        assert_that(_safe_call_method(_validator, "get_manhattan_distance", [center, pos])).is_less_equal(radius)

# Helper method for safe method calls
func _safe_call_method(object: Object, method_name: String, args: Array = []) -> Variant:
    if object and object.has_method(method_name):
        return object.callv(method_name, args)
    return null
