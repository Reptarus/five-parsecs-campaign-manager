extends "res://addons/gut/test.gd"

const ShipCreation = preload("res://src/core/ships/ShipCreation.gd")
const Ship = preload("res://src/core/ships/Ship.gd")

var creator: ShipCreation

func before_each() -> void:
    creator = ShipCreation.new()

func after_each() -> void:
    creator = null

func test_create_basic_ship() -> void:
    var ship = creator.create_basic_ship()
    
    assert_not_null(ship, "Should create a ship instance")
    assert_eq(ship.name, "Basic Ship", "Should set basic ship name")
    assert_eq(ship.description, "A basic starter ship", "Should set basic ship description")
    assert_eq(ship.credits, 1000, "Should set starting credits")
    
    # Verify basic components
    assert_not_null(ship.get_component("engine"), "Should have engine component")
    assert_not_null(ship.get_component("hull"), "Should have hull component")
    assert_not_null(ship.get_component("weapons"), "Should have weapons component")
    assert_eq(ship.components.size(), 3, "Should have three basic components")

func test_create_advanced_ship() -> void:
    var ship = creator.create_advanced_ship()
    
    assert_not_null(ship, "Should create a ship instance")
    assert_eq(ship.name, "Advanced Ship", "Should set advanced ship name")
    assert_eq(ship.description, "An advanced ship with enhanced capabilities", "Should set advanced ship description")
    assert_eq(ship.credits, 2000, "Should set higher starting credits")
    
    # Verify advanced components
    assert_not_null(ship.get_component("engine"), "Should have engine component")
    assert_not_null(ship.get_component("hull"), "Should have hull component")
    assert_not_null(ship.get_component("weapons"), "Should have weapons component")
    assert_not_null(ship.get_component("medical"), "Should have medical bay component")
    assert_eq(ship.components.size(), 4, "Should have four advanced components")
    
    # Verify component levels
    assert_eq(ship.get_component("engine").level, 2, "Should have upgraded engine")
    assert_eq(ship.get_component("weapons").level, 2, "Should have upgraded weapons")

func test_create_custom_ship() -> void:
    var config = {
        "name": "Custom Ship",
        "description": "A custom configured ship",
        "credits": 3000,
        "components": {
            "engine": {"level": 3},
            "hull": {"level": 2},
            "weapons": {"level": 2},
            "medical": {"level": 1}
        }
    }
    
    var ship = creator.create_custom_ship(config)
    
    assert_not_null(ship, "Should create a ship instance")
    assert_eq(ship.name, config.name, "Should set custom ship name")
    assert_eq(ship.description, config.description, "Should set custom ship description")
    assert_eq(ship.credits, config.credits, "Should set custom starting credits")
    
    # Verify custom components
    assert_not_null(ship.get_component("engine"), "Should have engine component")
    assert_eq(ship.get_component("engine").level, 3, "Should set custom engine level")
    assert_not_null(ship.get_component("hull"), "Should have hull component")
    assert_eq(ship.get_component("hull").level, 2, "Should set custom hull level")
    assert_not_null(ship.get_component("weapons"), "Should have weapons component")
    assert_eq(ship.get_component("weapons").level, 2, "Should set custom weapons level")
    assert_not_null(ship.get_component("medical"), "Should have medical bay component")
    assert_eq(ship.get_component("medical").level, 1, "Should set custom medical bay level")

func test_create_from_template() -> void:
    var template = {
        "type": "scout",
        "name": "Scout Ship",
        "description": "Fast and agile scout ship",
        "credits": 1500,
        "power": 15,
        "components": {
            "engine": {"level": 2, "thrust": 1.5},
            "hull": {"level": 1, "armor": 8},
            "weapons": {"level": 1, "damage": 8}
        }
    }
    
    var ship = creator.create_from_template(template)
    
    assert_not_null(ship, "Should create a ship instance")
    assert_eq(ship.name, template.name, "Should set template ship name")
    assert_eq(ship.description, template.description, "Should set template ship description")
    assert_eq(ship.credits, template.credits, "Should set template starting credits")
    assert_eq(ship.power_available, template.power, "Should set template power capacity")
    
    # Verify template components
    var engine = ship.get_component("engine")
    assert_not_null(engine, "Should have engine component")
    assert_eq(engine.level, 2, "Should set template engine level")
    assert_eq(engine.thrust, 1.5, "Should set template engine thrust")
    
    var hull = ship.get_component("hull")
    assert_not_null(hull, "Should have hull component")
    assert_eq(hull.level, 1, "Should set template hull level")
    assert_eq(hull.armor, 8, "Should set template hull armor")
    
    var weapons = ship.get_component("weapons")
    assert_not_null(weapons, "Should have weapons component")
    assert_eq(weapons.level, 1, "Should set template weapons level")
    assert_eq(weapons.damage, 8, "Should set template weapons damage")

func test_validate_configuration() -> void:
    # Test valid configuration
    var valid_config = {
        "name": "Test Ship",
        "description": "Test Description",
        "credits": 1000,
        "components": {
            "engine": {"level": 1},
            "hull": {"level": 1}
        }
    }
    assert_true(creator.validate_configuration(valid_config), "Should accept valid configuration")
    
    # Test invalid configurations
    var no_name = valid_config.duplicate()
    no_name.erase("name")
    assert_false(creator.validate_configuration(no_name), "Should reject configuration without name")
    
    var invalid_credits = valid_config.duplicate()
    invalid_credits.credits = -100
    assert_false(creator.validate_configuration(invalid_credits), "Should reject negative credits")
    
    var invalid_level = valid_config.duplicate()
    invalid_level.components.engine.level = 0
    assert_false(creator.validate_configuration(invalid_level), "Should reject invalid component level")

func test_component_initialization() -> void:
    var config = {
        "engine": {
            "level": 2,
            "thrust": 1.5,
            "fuel_efficiency": 1.2
        }
    }
    
    var engine = creator.create_component("engine", config.engine)
    
    assert_not_null(engine, "Should create component instance")
    assert_eq(engine.level, 2, "Should set component level")
    assert_eq(engine.thrust, 1.5, "Should set custom properties")
    assert_eq(engine.fuel_efficiency, 1.2, "Should set custom properties")

func test_error_handling() -> void:
    # Test invalid ship type
    assert_null(creator.create_from_template({"type": "invalid"}), "Should return null for invalid ship type")
    
    # Test invalid component type
    assert_null(creator.create_component("invalid", {}), "Should return null for invalid component type")
    
    # Test invalid configuration
    var invalid_config = {
        "name": "Test Ship",
        "components": {
            "engine": {"level": - 1} # Invalid level
        }
    }
    assert_null(creator.create_custom_ship(invalid_config), "Should return null for invalid configuration")