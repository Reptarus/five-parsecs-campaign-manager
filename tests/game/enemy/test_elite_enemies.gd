
# tests/game/enemy/test_elite_enemies.gd
extends GdUnit4Version

const EliteEnemyForce = preload("res://src/game/enemy/EliteEnemyForce.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

var elite_enemy_force: EliteEnemyForce
var mock_data_manager: DataManager

func before_each():
    elite_enemy_force = EliteEnemyForce.new()

    # Mock DataManager to provide elite enemy data
    mock_data_manager = mock(DataManager).make_double()
    mock_data_manager.get_elite_enemy_types.returns({
        "squad_composition": [
            {"size": 4, "basic": 3, "specialists": 1, "lieutenants": 0, "captain": 0},
            {"size": 5, "basic": 2, "specialists": 2, "lieutenants": 1, "captain": 0},
            {"size": 6, "basic": 3, "specialists": 2, "lieutenants": 1, "captain": 0},
            {"size": "7+", "basic": "3+", "specialists": 2, "lieutenants": 1, "captain": 1}
        ]
    })
    # Replace the global DataManager instance with the mock for testing
    # This assumes DataManager is accessed via get_node("/root/DataManager")
    # In a real project, you might use dependency injection for better testability.
    if Engine.has_singleton("DataManager"):
        Engine.set_singleton("DataManager", mock_data_manager)
    else:
        # If not a singleton, you might need to pass the mock directly
        pass

func after_each():
    # Clean up mock if necessary
    if Engine.has_singleton("DataManager"):
        Engine.set_singleton("DataManager", null) # Restore original or set to null

func test_generate_composition_size_4():
    var composition = elite_enemy_force.generate_composition(4)
    assert_eq(composition.size(), 4, "Composition size for 4 should be 4")
    assert_eq(composition.filter(func(e): return e.type == "basic").size(), 3, "Should have 3 basic enemies")
    assert_eq(composition.filter(func(e): return e.type == "specialist").size(), 1, "Should have 1 specialist")

func test_generate_composition_size_5():
    var composition = elite_enemy_force.generate_composition(5)
    assert_eq(composition.size(), 5, "Composition size for 5 should be 5")
    assert_eq(composition.filter(func(e): return e.type == "basic").size(), 2, "Should have 2 basic enemies")
    assert_eq(composition.filter(func(e): return e.type == "specialist").size(), 2, "Should have 2 specialists")
    assert_eq(composition.filter(func(e): return e.type == "lieutenant").size(), 1, "Should have 1 lieutenant")

func test_generate_composition_size_7_plus():
    var composition = elite_enemy_force.generate_composition(7)
    assert_eq(composition.size(), 7, "Composition size for 7 should be 7")
    assert_eq(composition.filter(func(e): return e.type == "basic").size(), 3, "Should have 3 basic enemies")
    assert_eq(composition.filter(func(e): return e.type == "specialist").size(), 2, "Should have 2 specialists")
    assert_eq(composition.filter(func(e): return e.type == "lieutenant").size(), 1, "Should have 1 lieutenant")
    assert_eq(composition.filter(func(e): return e.type == "captain").size(), 1, "Should have 1 captain")

func test_generate_composition_size_8_plus_basics():
    var composition = elite_enemy_force.generate_composition(8)
    assert_eq(composition.size(), 8, "Composition size for 8 should be 8")
    assert_eq(composition.filter(func(e): return e.type == "basic").size(), 4, "Should have 4 basic enemies (3 + 1 additional)")

func test_build_enemy_force_placeholder():
    # This test is conceptual as build_enemy_force is a placeholder
    var composition = elite_enemy_force.generate_composition(4)
    var enemies = elite_enemy_force.build_enemy_force(composition, "Marauders", 1)
    assert_true(enemies is Array, "build_enemy_force should return an Array")
    # Further tests would involve mocking EnemyGenerator and verifying Character instances

func test_is_compendium_dlc_active():
    # This test depends on the actual implementation of is_compendium_dlc_active
    # For now, it assumes it returns true as per the scaffolding.
    assert_true(EliteEnemyForce.is_compendium_dlc_active(), "DLC should be active for testing")
