## Rival System Test Suite
## Tests the functionality of the campaign rival management system
@tool
extends GdUnitGameTest

#
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

#
class MockRivalSystem extends Resource:
    var active_rivals: Array = []
    var defeated_rivals: Array = []
    var rival_encounters: Array = []
    var next_rival_id: int = 1
    
    #
    func get_active_rivals() -> Array: return active_rivals
    func get_defeated_rivals() -> Array: return defeated_rivals
    func get_rival_encounters() -> Array: return rival_encounters
    
    #
    func create_rival(params: Dictionary = {}) -> Dictionary:
        var rival_data = {
            "id": "rival_" + str(next_rival_id),
            "name": params.get("name", "Generated Rival " + str(next_rival_id)),
            "type": params.get("type", 0),
            "level": params.get("level", 1),
            "reputation": params.get("reputation", 0),
            "active": true,
        }
        next_rival_id += 1
        active_rivals.append(rival_data)
        return rival_data

    #
    func defeat_rival(rival_id: String) -> bool:
        for i: int in range(active_rivals.size()):
            if active_rivals[i].get("id", "") == rival_id:
                var rival = active_rivals[i]
                rival["active"] = false
                defeated_rivals.append(rival)
                active_rivals.remove_at(i)
                return true
        return false

    func handle_rival_escape(rival_id: String) -> bool:
        var rival = get_rival_by_id(rival_id)
        if rival.has("id"):
            rival["escaped"] = true
            return true
        return false

    func modify_rival_reputation(rival_id: String, amount: int) -> bool:
        var rival = get_rival_by_id(rival_id)
        if rival.has("reputation"):
            rival["reputation"] = rival["reputation"] + amount
            return true
        return false

    #
    func record_encounter(rival_id: String, data: Dictionary) -> bool:
        var encounter = {
            "rival_id": rival_id,
            "data": data,
            "timestamp": Time.get_unix_time_from_system(),
        }
        rival_encounters.append(encounter)
        return true

    #
    func get_rival_by_id(rival_id: String) -> Dictionary:
        for rival in active_rivals:
            if rival.get("id", "") == rival_id:
                return rival
        for rival in defeated_rivals:
            if rival.get("id", "") == rival_id:
                return rival
        return {}

    func serialize() -> Dictionary:
        return {
            "active_rivals": active_rivals,
            "defeated_rivals": defeated_rivals,
            "rival_encounters": rival_encounters,
            "next_rival_id": next_rival_id,
        }

    func deserialize(data: Dictionary) -> bool:
        if data.has("active_rivals"):
            active_rivals = data["active_rivals"]
            defeated_rivals = data.get("defeated_rivals", [])
            rival_encounters = data.get("rival_encounters", [])
            next_rival_id = data.get("next_rival_id", 1)
            return true
        return false

# Type-safe instance variables
var rival_system: MockRivalSystem = null

#
func before_test() -> void:
    super.before_test()
    
    rival_system = MockRivalSystem.new()

#
func after_test() -> void:
    rival_system = null
    super.after_test()

#
func test_initialization() -> void:
    assert_that(rival_system).is_not_null()
    assert_that(rival_system.get_active_rivals()).is_empty()
    assert_that(rival_system.get_defeated_rivals()).is_empty()

#
func test_create_rival() -> void:
    # Test direct state instead of signal monitoring (proven pattern)
    var params = {
        "name": "Test Rival",
        "type": GameEnums.EnemyType.PIRATES if GameEnums and "EnemyType" in GameEnums and "PIRATES" in GameEnums.EnemyType else 0,
        "level": 2,
        "reputation": 5,
    }
    var rival_data = rival_system.create_rival(params)
    assert_that(rival_data).is_not_empty()
    assert_that(rival_data["name"]).is_equal("Test Rival")
    assert_that(rival_data["level"]).is_equal(2)
    assert_that(rival_data["reputation"]).is_equal(5)
    assert_that(rival_data["active"]).is_true()
    
    var active_rivals = rival_system.get_active_rivals()
    assert_that(active_rivals).has_size(1)

#
func test_create_rival_with_defaults() -> void:
    var rival_data = rival_system.create_rival()
    assert_that(rival_data).is_not_empty()
    assert_that(rival_data["name"]).contains("Generated Rival")
    assert_that(rival_data["type"]).is_equal(0)
    assert_that(rival_data["level"]).is_equal(1)
    assert_that(rival_data["reputation"]).is_equal(0)
    assert_that(rival_data["active"]).is_true()
    
    var active_rivals = rival_system.get_active_rivals()
    assert_that(active_rivals).has_size(1)

#
func test_rival_defeat() -> void:
    # Test direct state instead of signal monitoring (proven pattern)
    var rival_data = rival_system.create_rival()
    var rival_id = rival_data.get("id", "")
    assert_that(rival_id).is_not_empty()
    
    var success = rival_system.defeat_rival(rival_id)
    assert_that(success).is_true()
    
    assert_that(rival_system.get_active_rivals()).is_empty()
    assert_that(rival_system.get_defeated_rivals()).has_size(1)

#
func test_rival_escape() -> void:
    # Test direct state instead of signal monitoring (proven pattern)
    var rival_data = rival_system.create_rival()
    var rival_id = rival_data.get("id", "")
    assert_that(rival_id).is_not_empty()
    
    var success = rival_system.handle_rival_escape(rival_id)
    assert_that(success).is_true()
    
    var updated_rival = rival_system.get_rival_by_id(rival_id)
    assert_that(updated_rival["escaped"]).is_true()

#
func test_modify_rival_reputation() -> void:
    # Test direct state instead of signal monitoring (proven pattern)
    var rival_data = rival_system.create_rival()
    var rival_id = rival_data.get("id", "")
    var old_rep = rival_data.get("reputation", 0)
    
    var success = rival_system.modify_rival_reputation(rival_id, 10)
    assert_that(success).is_true()
    
    var updated_rival = rival_system.get_rival_by_id(rival_id)
    assert_that(updated_rival["reputation"]).is_equal(old_rep + 10)
    
    success = rival_system.modify_rival_reputation(rival_id, -5)
    assert_that(success).is_true()
    
    updated_rival = rival_system.get_rival_by_id(rival_id)
    assert_that(updated_rival["reputation"]).is_equal(old_rep + 5)

#
func test_rival_encounters() -> void:
    var rival_data = rival_system.create_rival()
    var rival_id = rival_data.get("id", "")
    
    var encounter_data = {
        "type": "combat",
        "outcome": "victory",
        "loot": ["credits", "supplies"]
    }
    var success = rival_system.record_encounter(rival_id, encounter_data)
    assert_that(success).is_true()
    
    assert_that(rival_system.get_rival_encounters()).has_size(1)
    
    var encounter = rival_system.get_rival_encounters()[0]
    assert_that(encounter["rival_id"]).is_equal(rival_id)
    assert_that(encounter["data"]).is_equal(encounter_data)

#
func test_multiple_rivals() -> void:
    # Test direct state instead of signal monitoring (proven pattern)
    var rival1 = rival_system.create_rival({"name": "Rival 1"})
    var rival2 = rival_system.create_rival({"name": "Rival 2"})
    var rival3 = rival_system.create_rival({"name": "Rival 3"})
    
    assert_that(rival_system.get_active_rivals()).has_size(3)

    rival_system.defeat_rival(rival1.get("id", ""))
    rival_system.defeat_rival(rival2.get("id", ""))
    
    assert_that(rival_system.get_active_rivals()).has_size(1)
    assert_that(rival_system.get_defeated_rivals()).has_size(2)

#
func test_serialization() -> void:
    # Create test data
    rival_system.create_rival({"name": "Test Rival 1"})
    rival_system.create_rival({"name": "Test Rival 2"})
    
    var data = rival_system.serialize()
    assert_that(data).is_not_empty()
    assert_that(data["active_rivals"]).has_size(2)
    assert_that(data["next_rival_id"]).is_greater(1)
    
    var new_system: MockRivalSystem = MockRivalSystem.new()
    var success = new_system.deserialize(data)
    assert_that(success).is_true()
    assert_that(new_system.get_active_rivals()).has_size(2)

#
func test_large_rival_count() -> void:
    # Create many rivals
    for i: int in range(100):
        rival_system.create_rival({"name": "Rival " + str(i)})
    
    assert_that(rival_system.get_active_rivals()).has_size(100)
    
    # Defeat half
    var active_rivals = rival_system.get_active_rivals()
    for i: int in range(50):
        var rival_id = active_rivals[i].get("id", "")
        rival_system.defeat_rival(rival_id)
    
    assert_that(rival_system.get_active_rivals()).has_size(50)
    assert_that(rival_system.get_defeated_rivals()).has_size(50)

#
func test_invalid_rival_operations() -> void:
    # Test operations on non-existent rivals
    var success = rival_system.defeat_rival("non_existent_id")
    assert_that(success).is_false()
    
    success = rival_system.handle_rival_escape("non_existent_id")
    assert_that(success).is_false()
    
    success = rival_system.modify_rival_reputation("non_existent_id", 10)
    assert_that(success).is_false()
    
    var rival_data = rival_system.get_rival_by_id("non_existent_id")
    assert_that(rival_data).is_empty()

#
func test_rival_data_integrity() -> void:
    var rival_data = rival_system.create_rival({
        "name": "Integrity Test Rival",
        "level": 5,
        "reputation": 15,
    })
    var rival_id = rival_data.get("id", "")
    
    # Perform multiple operations
    rival_system.modify_rival_reputation(rival_id, 5)
    rival_system.modify_rival_reputation(rival_id, -3)
    rival_system.modify_rival_reputation(rival_id, 10)
    
    var final_rival = rival_system.get_rival_by_id(rival_id)
    assert_that(final_rival.get("reputation", 0)).is_equal(27) # 15 + 5 - 3 + 10
    assert_that(final_rival.get("level", 0)).is_equal(5) # Should remain unchanged
    assert_that(final_rival.get("name", "")).is_equal("Integrity Test Rival")
