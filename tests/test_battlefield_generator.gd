extends "res://addons/gut/test.gd"

const BattlefieldGenerator := preload("res://src/core/battle/BattlefieldGenerator.gd")
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes := preload("res://src/core/battle/TerrainTypes.gd")

# Test variables
var generator: BattlefieldGenerator

func before_all() -> void:
    super.before_all()
    generator = BattlefieldGenerator.new()
    add_child(generator)

func after_all() -> void:
    super.after_all()
    generator.queue_free()

# Basic Generation Tests
func test_battlefield_generation() -> void:
    var battlefield := generator.generate_battlefield()
    assert_not_null(battlefield, "Battlefield should be generated")
    assert_true(battlefield.has("terrain"), "Battlefield should have terrain")
    assert_true(battlefield.has("size"), "Battlefield should have size defined")
    assert_true(battlefield.has("deployment_zones"), "Battlefield should have deployment zones")
    assert_true(battlefield.has("objectives"), "Battlefield should have objectives")

func test_battlefield_size() -> void:
    var battlefield := generator.generate_battlefield()
    assert_gt(battlefield.size.x, generator.MIN_BATTLEFIELD_SIZE.x - 1, "Battlefield width should be within minimum")
    assert_gt(battlefield.size.y, generator.MIN_BATTLEFIELD_SIZE.y - 1, "Battlefield height should be within minimum")
    assert_lt(battlefield.size.x, generator.MAX_BATTLEFIELD_SIZE.x + 1, "Battlefield width should be within maximum")
    assert_lt(battlefield.size.y, generator.MAX_BATTLEFIELD_SIZE.y + 1, "Battlefield height should be within maximum")

# Terrain Generation Tests
func test_terrain_generation() -> void:
    var battlefield := generator.generate_battlefield()
    var terrain_data: Array = battlefield.terrain
    assert_not_null(terrain_data, "Terrain data should be generated")
    assert_gt(terrain_data.size(), 0, "Should have terrain data")

# Cover Generation Tests
func test_cover_density() -> void:
    var battlefield := generator.generate_battlefield()
    var cover_count := 0
    for row in battlefield.terrain:
        for cell in row.row:
            if cell.cover:
                cover_count += 1
    
    var total_cells: int = battlefield.size.x * battlefield.size.y
    var density := float(cover_count) / float(total_cells)
    assert_between(density, generator.MIN_COVER_DENSITY, generator.MAX_COVER_DENSITY,
        "Cover density should be within acceptable range")

# Deployment Zone Tests
func test_deployment_zones() -> void:
    var battlefield := generator.generate_battlefield()
    assert_has(battlefield, "deployment_zones", "Battlefield should have deployment zones")
    var zones: Dictionary = battlefield.deployment_zones
    assert_has(zones, "player", "Should have player deployment zone")
    assert_has(zones, "enemy", "Should have enemy deployment zone")
    
    var player_zone: Array = zones.player
    var enemy_zone: Array = zones.enemy
    assert_gt(player_zone.size(), 0, "Player deployment zone should not be empty")
    assert_gt(enemy_zone.size(), 0, "Enemy deployment zone should not be empty")

# Objective Tests
func test_objectives() -> void:
    var config := {"objective_count": 3}
    var battlefield := generator.generate_battlefield(config)
    assert_has(battlefield, "objectives", "Battlefield should have objectives")
    var objectives: Array = battlefield.objectives
    assert_eq(objectives.size(), 3, "Should have requested number of objectives")
    
    for objective in objectives:
        assert_has(objective, "position", "Objective should have position")
        assert_has(objective, "type", "Objective should have type")

# Validation Tests
func test_battlefield_validation() -> void:
    var battlefield := generator.generate_battlefield()
    var validation := generator.validate_battlefield()
    assert_true(validation.valid, "Generated battlefield should be valid")
    assert_eq(validation.errors.size(), 0, "Should have no validation errors")

func test_invalid_config_validation() -> void:
    generator.config.size = Vector2i(-1, -1)
    var validation := generator.validate_battlefield()
    assert_false(validation.valid, "Should fail validation with invalid size")
    assert_gt(validation.errors.size(), 0, "Should have validation errors")

# Utility Tests
func test_terrain_at_position() -> void:
    var battlefield := generator.generate_battlefield()
    var pos := Vector2i(0, 0)
    var terrain := generator.get_terrain_at(pos)
    assert_not_null(terrain, "Should get terrain at valid position")
    assert_has(terrain, "type", "Terrain should have type")
    assert_has(terrain, "walkable", "Terrain should have walkable property")

func test_deployment_zone_access() -> void:
    var battlefield := generator.generate_battlefield()
    var player_zone := generator.get_deployment_zone("player")
    var enemy_zone := generator.get_deployment_zone("enemy")
    assert_not_null(player_zone, "Should get player deployment zone")
    assert_not_null(enemy_zone, "Should get enemy deployment zone")
    assert_gt(player_zone.size(), 0, "Player zone should not be empty")
    assert_gt(enemy_zone.size(), 0, "Enemy zone should not be empty")