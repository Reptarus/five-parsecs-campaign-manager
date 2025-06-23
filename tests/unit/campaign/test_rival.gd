## Rival Test Suite
## Tests the functionality of individual rival objects
@tool
extends GdUnitGameTest

#
const Rival: GDScript = preload("res://src/core/rivals/Rival.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

#
class MockRival extends Resource:
    var rival_name: String = "Test Rival"
    var description: String = "A test rival for campaign testing"
    var threat_level: int = 5
    var hostility: int = 10
    var resources: int = 100
    var is_active_state: bool = true
    
    #
    func get_rival_name() -> String: return rival_name
    func get_description() -> String: return description
    func get_threat_level() -> int: return threat_level
    func get_hostility() -> int: return hostility
    func get_resources() -> int: return resources
    func is_active() -> bool: return is_active_state
    
    #
    func set_rival_name(name: String) -> bool:
        rival_name = name
        return true

    func set_description(desc: String) -> bool:
        description = desc
        return true

    func set_threat_level(level: int) -> bool:
        threat_level = clamp(level, 1, 10)
        return true

    func set_hostility(host: int) -> bool:
        hostility = clamp(host, 0, 100)
        return true

    func set_resources(res: int) -> bool:
        resources = max(0, res)
        return true

    func set_active(active: bool) -> bool:
        is_active_state = active
        return true

    #
    func increase_hostility(amount: int) -> bool:
        hostility = min(100, hostility + amount)
        return true

    func decrease_hostility(amount: int) -> bool:
        hostility = max(0, hostility - amount)
        return true

    #
    func increase_threat_level(amount: int) -> bool:
        threat_level = min(10, threat_level + amount)
        return true

    func decrease_threat_level(amount: int) -> bool:
        threat_level = max(1, threat_level - amount)
        return true

    #
    func add_resources(amount: int) -> bool:
        resources += amount
        return true

    func spend_resources(amount: int) -> bool:
        if resources >= amount:
            resources -= amount
            return true
        return false

    #
    func generate_resources() -> bool:
        resources += 25 # Base generation amount
        return true

    func generate_encounter() -> Dictionary:
        return {
            "type": "combat",
            "difficulty": threat_level,
            "enemies": 3,
            "rewards": {"credits": 50},
        }

    #
    func serialize() -> Dictionary:
        return {
            "name": rival_name,
            "description": description,
            "threat_level": threat_level,
            "hostility": hostility,
            "resources": resources,
            "active": is_active_state,
        }

    func deserialize(data: Dictionary) -> bool:
        if data.has("name"):
            rival_name = data["name"]
            description = data.get("description", "")
            threat_level = data.get("threat_level", 5)
            hostility = data.get("hostility", 10)
            resources = data.get("resources", 100)
            is_active_state = data.get("active", true)
            return true
        return false

# Type-safe instance variables
var rival: MockRival = null

# Test constants with expected values
var NEUTRAL_HOSTILITY: int = 0
var MIN_THREAT_LEVEL: int = 1
var MAX_THREAT_LEVEL: int = 10
var MIN_HOSTILITY: int = 0
var MAX_HOSTILITY: int = 100
var MIN_RESOURCES: int = 0
var MAX_RESOURCES: int = 1000
var HOSTILITY_INCREASE_AMOUNT: int = 10
var HOSTILITY_DECREASE_AMOUNT: int = 5
var THREAT_LEVEL_INCREASE: int = 1
var THREAT_LEVEL_DECREASE: int = 1
var RESOURCE_GAIN_AMOUNT: int = 50
var RESOURCE_SPEND_AMOUNT: int = 25
var MIN_ENCOUNTER_DIFFICULTY: int = 1
var DEFAULT_THREAT_LEVEL: int = 5
var DEFAULT_HOSTILITY: int = 10
var DEFAULT_RESOURCES: int = 100

#
func before_test() -> void:
    super.before_test()
    
    rival = MockRival.new()

func after_test() -> void:
    rival = null
    super.after_test()

#
func test_initialization() -> void:
    assert_that(rival).is_not_null()
    
    var name: String = rival.get_rival_name()
    var description: String = rival.get_description()
    var threat_level: int = rival.get_threat_level()
    var hostility: int = rival.get_hostility()
    var resources: int = rival.get_resources()
    var is_active: bool = rival.is_active()
    
    assert_that(name).is_equal("Test Rival")
    assert_that(description).is_not_empty()
    assert_that(threat_level).is_equal(DEFAULT_THREAT_LEVEL)
    assert_that(hostility).is_equal(DEFAULT_HOSTILITY)
    assert_that(resources).is_equal(DEFAULT_RESOURCES)
    assert_that(is_active).is_true()

#
func test_hostility_management() -> void:
    # Test hostility increase
    var success: bool = rival.increase_hostility(HOSTILITY_INCREASE_AMOUNT)
    assert_that(success).is_true()
    var hostility: int = rival.get_hostility()
    assert_that(hostility).is_equal(DEFAULT_HOSTILITY + HOSTILITY_INCREASE_AMOUNT)
    
    # Test hostility decrease
    success = rival.decrease_hostility(HOSTILITY_DECREASE_AMOUNT)
    assert_that(success).is_true()
    hostility = rival.get_hostility()
    assert_that(hostility).is_equal(DEFAULT_HOSTILITY + HOSTILITY_INCREASE_AMOUNT - HOSTILITY_DECREASE_AMOUNT)
    
    # Test hostility cap
    rival.set_hostility(MAX_HOSTILITY)
    success = rival.increase_hostility(HOSTILITY_INCREASE_AMOUNT)
    assert_that(success).is_true()
    hostility = rival.get_hostility()
    assert_that(hostility).is_equal(MAX_HOSTILITY)

#
func test_threat_level_management() -> void:
    # Test threat level increase
    var success: bool = rival.increase_threat_level(THREAT_LEVEL_INCREASE)
    assert_that(success).is_true()
    var threat_level: int = rival.get_threat_level()
    assert_that(threat_level).is_equal(DEFAULT_THREAT_LEVEL + THREAT_LEVEL_INCREASE)
    
    # Test threat level decrease
    success = rival.decrease_threat_level(THREAT_LEVEL_DECREASE)
    assert_that(success).is_true()
    threat_level = rival.get_threat_level()
    assert_that(threat_level).is_equal(DEFAULT_THREAT_LEVEL)
    
    # Test threat level minimum
    rival.set_threat_level(MIN_THREAT_LEVEL)
    success = rival.decrease_threat_level(THREAT_LEVEL_DECREASE)
    assert_that(success).is_true()
    threat_level = rival.get_threat_level()
    assert_that(threat_level).is_equal(MIN_THREAT_LEVEL) # Should not go below minimum

#
func test_resource_management() -> void:
    # Test resource addition
    var success: bool = rival.add_resources(RESOURCE_GAIN_AMOUNT)
    assert_that(success).is_true()
    var resources: int = rival.get_resources()
    assert_that(resources).is_equal(DEFAULT_RESOURCES + RESOURCE_GAIN_AMOUNT)
    
    # Test resource spending
    success = rival.spend_resources(RESOURCE_SPEND_AMOUNT)
    assert_that(success).is_true()
    resources = rival.get_resources()
    assert_that(resources).is_equal(DEFAULT_RESOURCES + RESOURCE_GAIN_AMOUNT - RESOURCE_SPEND_AMOUNT)
    
    # Test spending more than available
    success = rival.spend_resources(resources + 100)
    assert_that(success).is_false()

#
func test_activity_status() -> void:
    # Test initial active state
    var is_active: bool = rival.is_active()
    assert_that(is_active).is_true()
    
    # Test deactivation
    var success: bool = rival.set_active(false)
    assert_that(success).is_true()
    is_active = rival.is_active()
    assert_that(is_active).is_false()
    
    # Test reactivation
    success = rival.set_active(true)
    assert_that(success).is_true()
    is_active = rival.is_active()
    assert_that(is_active).is_true()
    
    # Test resource generation
    var initial_resources = rival.get_resources()
    success = rival.generate_resources()
    assert_that(success).is_true()
    var final_resources: int = rival.get_resources()
    assert_that(final_resources).is_greater(initial_resources)

#
func test_encounter_generation() -> void:
    var encounter: Dictionary = rival.generate_encounter()
    assert_that(encounter).is_not_empty()
    assert_that(encounter).contains_keys(["type", "difficulty", "enemies", "rewards"])

    var difficulty: int = encounter.get("difficulty", 0)
    assert_that(difficulty).is_greater_equal(MIN_ENCOUNTER_DIFFICULTY)

    var encounter_type: String = encounter.get("type", "")
    assert_that(encounter_type).is_not_empty()

    var enemies: int = encounter.get("enemies", 0)
    assert_that(enemies).is_greater(0)

#
func test_serialization() -> void:
    # Test serialization
    var data: Dictionary = rival.serialize()
    assert_that(data).is_not_empty()
    assert_that(data).contains_keys(["name", "description", "threat_level", "hostility", "resources", "active"])
    assert_that(data["name"]).is_equal("Test Rival")
    assert_that(data["threat_level"]).is_equal(DEFAULT_THREAT_LEVEL)
    assert_that(data["hostility"]).is_equal(DEFAULT_HOSTILITY)
    assert_that(data["resources"]).is_equal(DEFAULT_RESOURCES)
    
    # Test deserialization
    var new_rival: MockRival = MockRival.new()
    var success: bool = new_rival.deserialize(data)
    assert_that(success).is_true()
    assert_that(new_rival.get_rival_name()).is_equal("Test Rival")
    assert_that(new_rival.get_threat_level()).is_equal(DEFAULT_THREAT_LEVEL)
    assert_that(new_rival.get_hostility()).is_equal(DEFAULT_HOSTILITY)
    assert_that(new_rival.get_resources()).is_equal(DEFAULT_RESOURCES)
    assert_that(new_rival.is_active()).is_true()
