@tool
extends GdUnitGameTest

# Mock Ship Creation System with realistic behavior
class MockShipCreation extends Resource:
	enum ComponentType {WEAPON = 0, ENGINE = 1, SHIELD = 2, ARMOR = 3}
	
	func create_ship(ship_data: Dictionary) -> Resource:
		# Validate required fields
		if not ship_data.has("name") or not ship_data.has("ship_class"):
			return null
		if not ship_data.has("hull_points") or not ship_data.has("shield_points"):
			return null
			
		# Validate ship class
		var valid_classes = ["Frigate", "Destroyer", "Cruiser", "Battleship"]
		if not ship_data["ship_class"] in valid_classes:
			return null
			
		# Validate values
		if ship_data.get("hull_points", 0) < 0 or ship_data.get("shield_points", 0) < 0:
			return null
			
		# Create ship
		var ship = MockShip.new()
		ship.name = ship_data["name"]
		ship.ship_class = ship_data["ship_class"]
		ship.hull_points = ship_data["hull_points"]
		ship.shield_points = ship_data["shield_points"]
		
		# Add components if provided
		if ship_data.has("components"):
			for component_data in ship_data["components"]:
				var component = create_component(component_data)
				if component:
					ship.add_component(component)
		
		return ship
	
	func create_component(component_data: Dictionary) -> Resource:
		# Validate required fields
		if not component_data.has("type") or not component_data.has("name"):
			return null
			
		# Validate component type
		var type_value = component_data["type"]
		if type_value < 0 or type_value > 3:
			return null
			
		# Validate values (no negative values allowed)
		if component_data.get("damage", 0) < 0 or component_data.get("range", 0) < 0:
			return null
			
		# Create component
		var component = MockComponent.new()
		component.type = type_value
		component.name = component_data["name"]
		component.damage = component_data.get("damage", 0)
		component.range = component_data.get("range", 0)
		
		return component

class MockShip extends Resource:
	var name: String = ""
	var ship_class: String = ""
	var hull_points: int = 0
	var shield_points: int = 0
	var components: Array = []
	
	func add_component(component: Resource) -> bool:
		if component:
			components.append(component)
			return true
		return false
	
	func get_components() -> Array:
		return components

class MockComponent extends Resource:
	var type: int = 0
	var name: String = ""
	var damage: int = 0
	var range: int = 0

# Test variables with correct types
var creator: MockShipCreation = null

func before_test() -> void:
	super.before_test()
	creator = MockShipCreation.new()
	track_resource(creator)
	await get_tree().process_frame

func after_test() -> void:
	super.after_test()
	creator = null

func test_initial_setup() -> void:
	assert_that(creator).is_not_null()
	assert_that(creator.has_method("create_ship")).is_true()
	assert_that(creator.has_method("create_component")).is_true()

func test_ship_creation() -> void:
	var ship_data: Dictionary = {
		"name": "Test Ship",
		"ship_class": "Frigate",
		"hull_points": 100,
		"shield_points": 50,
		"components": []
	}
	
	var ship: Resource = creator.create_ship(ship_data)
	assert_that(ship).is_not_null()
	
	assert_that(ship.name).is_equal("Test Ship")
	assert_that(ship.ship_class).is_equal("Frigate")
	assert_that(ship.hull_points).is_equal(100)
	assert_that(ship.shield_points).is_equal(50)

func test_component_creation() -> void:
	var component_data: Dictionary = {
		"type": MockShipCreation.ComponentType.WEAPON,
		"name": "Test Weapon",
		"damage": 25,
		"range": 100
	}
	
	var component: Resource = creator.create_component(component_data)
	assert_that(component).is_not_null()
	
	assert_that(component.type).is_equal(MockShipCreation.ComponentType.WEAPON)
	assert_that(component.name).is_equal("Test Weapon")
	assert_that(component.damage).is_equal(25)
	assert_that(component.range).is_equal(100)

func test_ship_with_components() -> void:
	var component_data: Dictionary = {
		"type": MockShipCreation.ComponentType.WEAPON,
		"name": "Test Weapon",
		"damage": 25,
		"range": 100
	}
	
	var ship_data: Dictionary = {
		"name": "Armed Ship",
		"ship_class": "Destroyer",
		"hull_points": 150,
		"shield_points": 75,
		"components": [component_data]
	}
	
	var ship: Resource = creator.create_ship(ship_data)
	assert_that(ship).is_not_null()
	
	var components: Array = ship.get_components()
	assert_that(components.size()).is_equal(1)
	
	var component: Resource = components[0]
	assert_that(component.type).is_equal(MockShipCreation.ComponentType.WEAPON)
	assert_that(component.name).is_equal("Test Weapon")

func test_invalid_ship_data() -> void:
	var invalid_data: Dictionary = {
		"name": "Invalid Ship"
		# Missing required fields
	}
	
	var ship: Resource = creator.create_ship(invalid_data)
	assert_that(ship).is_null()

func test_invalid_component_data() -> void:
	var invalid_data: Dictionary = {
		"name": "Invalid Component"
		# Missing required type field
	}
	
	var component: Resource = creator.create_component(invalid_data)
	assert_that(component).is_null()

func test_component_validation() -> void:
	var invalid_type_data: Dictionary = {
		"type": 999, # Invalid type
		"name": "Invalid Component"
	}
	
	var component: Resource = creator.create_component(invalid_type_data)
	assert_that(component).is_null()
	
	var invalid_values_data: Dictionary = {
		"type": MockShipCreation.ComponentType.WEAPON,
		"name": "Invalid Values",
		"damage": - 25, # Negative damage
		"range": - 100 # Negative range
	}
	
	component = creator.create_component(invalid_values_data)
	assert_that(component).is_null()

func test_ship_validation() -> void:
	var invalid_class_data: Dictionary = {
		"name": "Invalid Class Ship",
		"ship_class": "Invalid", # Unknown ship class
		"hull_points": 100,
		"shield_points": 50
	}
	
	var ship: Resource = creator.create_ship(invalid_class_data)
	assert_that(ship).is_null()
	
	var invalid_values_data: Dictionary = {
		"name": "Invalid Values Ship",
		"ship_class": "Frigate",
		"hull_points": - 100, # Negative hull points
		"shield_points": - 50 # Negative shield points
	}
	
	ship = creator.create_ship(invalid_values_data)
	assert_that(ship).is_null()

func test_component_limits() -> void:
	var component_data: Dictionary = {
		"type": MockShipCreation.ComponentType.WEAPON,
		"name": "Test Weapon",
		"damage": 25,
		"range": 100
	}
	
	var ship_data: Dictionary = {
		"name": "Component Test Ship",
		"ship_class": "Cruiser",
		"hull_points": 200,
		"shield_points": 100,
		"components": [component_data, component_data, component_data] # Multiple components
	}
	
	var ship: Resource = creator.create_ship(ship_data)
	assert_that(ship).is_not_null()
	
	var components: Array = ship.get_components()
	assert_that(components.size()).is_equal(3)