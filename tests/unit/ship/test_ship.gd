@tool
extends GdUnitGameTest

# Mock Ship with realistic behavior
class MockShip extends Resource:
    var ship_name: String = ""
    var description: String = ""
    var components: Array = []
    var stats: Dictionary = {}
    
    func get_ship_name() -> String: return ship_name
    func get_description() -> String: return description
    func get_components() -> Array: return components
    
    func set_ship_name(value: String) -> void: ship_name = value
    func set_description(value: String) -> void: description = value
    
    func add_component(component: Resource) -> bool:
        if component:
            components.append(component)
            return true
        return false
    
    func remove_component(component: Resource) -> bool:
        var index = components.find(component)
        if index >= 0:
            components.remove_at(index)
            return true
        return false
    
    func get_component_by_id(component_id: String) -> Resource:
        for component in components:
            if component.has_meta("component_id") and component.get_meta("component_id") == component_id:
                return component
        return null
    
    func calculate_stats() -> Dictionary:
        var calculated_stats = {"speed": 0, "power": 0, "armor": 0}
        
        for component in components:
            if component.has_meta("speed_bonus"):
                calculated_stats["speed"] += component.get_meta("speed_bonus", 0)
            if component.has_meta("power_bonus"):
                calculated_stats["power"] += component.get_meta("power_bonus", 0)
            if component.has_meta("armor_bonus"):
                calculated_stats["armor"] += component.get_meta("armor_bonus", 0)
        
        return calculated_stats

var ship: MockShip = null

func before_test() -> void:
    super.before_test()
    ship = MockShip.new()
    track_resource(ship)
    await get_tree().process_frame

func after_test() -> void:
    super.after_test()
    ship = null

func test_initialization() -> void:
    assert_that(ship).is_not_null()
    
    assert_that(ship.get_ship_name()).is_equal("")
    assert_that(ship.get_description()).is_equal("")

func test_set_get_properties() -> void:
    var test_name: String = "Test Ship"
    var test_description: String = "Test Description"
    
    ship.set_ship_name(test_name)
    ship.set_description(test_description)
    
    assert_that(ship.get_ship_name()).is_equal(test_name)
    assert_that(ship.get_description()).is_equal(test_description)

func test_add_component() -> void:
    var component: Resource = Resource.new()
    component.set_meta("component_id", "test_component")
    component.set_meta("component_type", "engine")
    
    assert_that(ship.add_component(component)).is_true()
    assert_that(ship.get_components().size()).is_equal(1)

func test_remove_component() -> void:
    var component: Resource = Resource.new()
    component.set_meta("component_id", "test_component")
    component.set_meta("component_type", "engine")
    
    ship.add_component(component)
    assert_that(ship.remove_component(component)).is_true()
    assert_that(ship.get_components().size()).is_equal(0)

func test_get_component_by_id() -> void:
    var component: Resource = Resource.new()
    component.set_meta("component_id", "test_component")
    component.set_meta("component_type", "engine")
    
    ship.add_component(component)
    var retrieved: Resource = ship.get_component_by_id("test_component")
    
    assert_that(retrieved).is_not_null()
    assert_that(retrieved.get_meta("component_id")).is_equal("test_component")

func test_calculate_stats() -> void:
    var component1: Resource = Resource.new()
    component1.set_meta("component_id", "engine1")
    component1.set_meta("component_type", "engine")
    component1.set_meta("speed_bonus", 10)
    
    var component2: Resource = Resource.new()
    component2.set_meta("component_id", "engine2")
    component2.set_meta("component_type", "engine")
    component2.set_meta("speed_bonus", 20)
    
    ship.add_component(component1)
    ship.add_component(component2)
    
    var result: Dictionary = ship.calculate_stats()
    
    assert_that(result.has("speed")).is_true()
    assert_that(result["speed"]).is_equal(30)