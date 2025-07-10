
# tests/game/world/test_factions.gd
extends GutTest

const FactionManager = preload("res://src/game/world/FactionManager.gd") # Assuming this will be created
const GameState = preload("res://src/core/state/GameState.gd") # For DLC check

var faction_manager: FactionManager

func before_each():
    faction_manager = FactionManager.new()
    # Mock GameState for DLC check
    mock_class(GameState)
    GameState.mock_method("is_compendium_dlc_unlocked").returns(true) # Assume DLC is unlocked for testing

func test_faction_manager_initialization():
    assert_not_null(faction_manager.factions, "Factions dictionary should be initialized")
    assert_true(faction_manager.factions.is_empty(), "Factions dictionary should be empty initially")

func test_add_faction():
    faction_manager.add_faction("Unity", 50)
    assert_true(faction_manager.factions.has("Unity"), "Unity faction should be added")
    assert_eq(faction_manager.get_faction_loyalty("Unity"), 50, "Unity loyalty should be 50")

func test_update_faction_loyalty():
    faction_manager.add_faction("Unity", 50)
    faction_manager.update_faction_loyalty("Unity", 10)
    assert_eq(faction_manager.get_faction_loyalty("Unity"), 60, "Unity loyalty should increase")

    faction_manager.update_faction_loyalty("Unity", -20)
    assert_eq(faction_manager.get_faction_loyalty("Unity"), 40, "Unity loyalty should decrease")

func test_get_faction_status():
    faction_manager.add_faction("Unity", 80)
    assert_eq(faction_manager.get_faction_status("Unity"), "Friendly", "Loyalty 80 should be Friendly")

    faction_manager.update_faction_loyalty("Unity", -50)
    assert_eq(faction_manager.get_faction_status("Unity"), "Neutral", "Loyalty 30 should be Neutral")

    faction_manager.update_faction_loyalty("Unity", -50)
    assert_eq(faction_manager.get_faction_status("Unity"), "Hostile", "Loyalty -20 should be Hostile")

func test_faction_jobs():
    faction_manager.add_faction("Unity", 50)
    var job = faction_manager.get_faction_job("Unity")
    assert_not_null(job, "Should get a faction job")
    assert_true(job.has("description"), "Job should have a description")

func test_dlc_gating():
    GameState.mock_method("is_compendium_dlc_unlocked").returns(false)
    var new_manager = FactionManager.new()
    new_manager.add_faction("Unity", 50)
    assert_false(new_manager.factions.has("Unity"), "Faction should not be added if DLC is locked")

# Add tests for Faction Activities, Off-World Factions, Invasion, Faction Events, Faction Destruction
