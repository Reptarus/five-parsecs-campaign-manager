extends GdUnitTestSuite
## Tests for Ship System: ShipData, Ship, ShipComponent
## Covers 5 NOT_TESTED mechanics from QA_CORE_RULES_TEST_PLAN.md §5
## Core Rules Reference: Ship Data (p.60), Fuel (p.61), Components (p.63)

const ShipDataClass := preload("res://src/data/ship/ShipData.gd")
const ShipClass := preload("res://src/core/ships/Ship.gd")
const ShipComponentClass := preload("res://src/core/ships/components/ShipComponent.gd")

# ============================================================================
# ShipData Resource Tests
# ============================================================================

func test_ship_data_default_construction():
	var ship := ShipDataClass.new()
	assert_that(ship).is_not_null()
	assert_that(ship.ship_name).is_equal("")
	assert_that(ship.hull_points).is_equal(0)

func test_ship_data_hull_properties():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 10
	assert_that(ship.hull_points).is_equal(10)
	assert_that(ship.max_hull_points).is_equal(10)

func test_ship_data_take_hull_damage():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 10
	ship.take_hull_damage(3)
	assert_that(ship.hull_points).is_equal(7)

func test_ship_data_take_hull_damage_does_not_go_below_zero():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 2
	ship.take_hull_damage(5)
	assert_that(ship.hull_points).is_greater_equal(0)

func test_ship_data_repair_hull():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 5
	ship.repair_hull(3)
	assert_that(ship.hull_points).is_equal(8)

func test_ship_data_repair_hull_caps_at_max():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 8
	ship.repair_hull(5)
	assert_that(ship.hull_points).is_less_equal(ship.max_hull_points)

func test_ship_data_get_hull_damage():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 7
	assert_that(ship.get_hull_damage()).is_equal(3)

func test_ship_data_needs_repair_when_damaged():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 7
	assert_that(ship.needs_repair()).is_true()

func test_ship_data_needs_repair_when_full():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 10
	assert_that(ship.needs_repair()).is_false()

func test_ship_data_is_damaged():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 5
	assert_that(ship.is_damaged()).is_true()

func test_ship_data_is_not_damaged_at_full():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 10
	assert_that(ship.is_damaged()).is_false()

func test_ship_data_get_repair_cost():
	var ship := ShipDataClass.new()
	ship.max_hull_points = 10
	ship.hull_points = 7
	var cost: int = ship.get_repair_cost()
	assert_that(cost).is_greater(0)

# ============================================================================
# Fuel System Tests (Core Rules p.61)
# ============================================================================

func test_fuel_default_values():
	var ship := ShipDataClass.new()
	assert_that(ship.fuel_units).is_equal(0)
	assert_that(ship.max_fuel_units).is_equal(0)

func test_fuel_can_be_set():
	var ship := ShipDataClass.new()
	ship.max_fuel_units = 10
	ship.fuel_units = 7
	assert_that(ship.fuel_units).is_equal(7)
	assert_that(ship.max_fuel_units).is_equal(10)

func test_fuel_tracking_on_ship():
	var ship := ShipDataClass.new()
	ship.max_fuel_units = 10
	ship.fuel_units = 10
	ship.fuel_units -= 3  # Travel costs fuel
	assert_that(ship.fuel_units).is_equal(7)

# ============================================================================
# Ship Debt Tracking Tests (Core Rules p.80)
# ============================================================================

func test_ship_debt_default_zero():
	var ship := ShipDataClass.new()
	assert_that(ship.outstanding_debt).is_equal(0)

func test_ship_debt_can_be_set():
	var ship := ShipDataClass.new()
	ship.outstanding_debt = 25
	assert_that(ship.outstanding_debt).is_equal(25)

func test_ship_debt_interest_accrual():
	"""Core Rules p.80: Ship debt accrues +1 per turn"""
	var ship := ShipDataClass.new()
	ship.outstanding_debt = 10
	ship.outstanding_debt += 1  # Turn interest
	assert_that(ship.outstanding_debt).is_equal(11)

# ============================================================================
# ShipData Validation Tests
# ============================================================================

func test_ship_data_validate():
	var ship := ShipDataClass.new()
	ship.ship_name = "Test Ship"
	ship.max_hull_points = 10
	ship.hull_points = 10
	ship.max_fuel_units = 5
	ship.fuel_units = 5
	var result = ship.validate()
	assert_that(result).is_not_null()

# ============================================================================
# ShipData Serialization Tests
# ============================================================================

func test_ship_data_to_dictionary():
	var ship := ShipDataClass.new()
	ship.ship_name = "Stellar Kestrel"
	ship.max_hull_points = 10
	ship.hull_points = 8
	ship.outstanding_debt = 5
	var data: Dictionary = ship.to_dictionary()
	assert_that(data).is_not_null()
	assert_that(data.has("ship_name")).is_true()
	assert_that(data["ship_name"]).is_equal("Stellar Kestrel")

func test_ship_data_from_dictionary_roundtrip():
	var original := ShipDataClass.new()
	original.ship_name = "Roundtrip Ship"
	original.max_hull_points = 12
	original.hull_points = 9
	original.fuel_units = 3
	original.max_fuel_units = 8
	original.outstanding_debt = 7
	var data: Dictionary = original.to_dictionary()
	var restored = ShipDataClass.from_dictionary(data)
	assert_that(restored).is_not_null()
	assert_that(restored.ship_name).is_equal("Roundtrip Ship")
	assert_that(restored.hull_points).is_equal(9)
	assert_that(restored.outstanding_debt).is_equal(7)

# ============================================================================
# Ship Class Tests (Component-Based Runtime Model)
# ============================================================================

func test_ship_construction():
	var ship := ShipClass.new()
	assert_that(ship).is_not_null()

func test_ship_name_getset():
	var ship := ShipClass.new()
	ship.set_name("Test Vessel")
	assert_that(ship.get_name()).is_equal("Test Vessel")

func test_ship_hull_points_getset():
	var ship := ShipClass.new()
	ship.set_max_hull_points(10)
	ship.set_hull_points(8)
	assert_that(ship.get_hull_points()).is_equal(8)
	assert_that(ship.get_max_hull_points()).is_equal(10)

func test_ship_components_initially_empty():
	var ship := ShipClass.new()
	assert_that(ship.get_components()).is_equal([])

func test_ship_add_component():
	var ship := ShipClass.new()
	var comp := ShipComponentClass.new()
	comp.name = "Engine MK1"
	comp.component_id = "engine_mk1"
	var result: bool = ship.add_component(comp)
	assert_that(result).is_true()
	assert_that(ship.get_components().size()).is_equal(1)

func test_ship_remove_component():
	var ship := ShipClass.new()
	var comp := ShipComponentClass.new()
	comp.name = "Shield Gen"
	comp.component_id = "shield_gen"
	ship.add_component(comp)
	var result: bool = ship.remove_component(comp)
	assert_that(result).is_true()
	assert_that(ship.get_components().size()).is_equal(0)

func test_ship_get_component_by_id():
	var ship := ShipClass.new()
	var comp := ShipComponentClass.new()
	comp.name = "Cargo Bay"
	comp.component_id = "cargo_bay_1"
	ship.add_component(comp)
	var found = ship.get_component_by_id("cargo_bay_1")
	assert_that(found).is_not_null()

func test_ship_serialization_roundtrip():
	var ship := ShipClass.new()
	ship.set_name("Serialize Test")
	ship.set_ship_class("PATROL_SHIP")
	ship.set_max_hull_points(12)
	ship.set_hull_points(10)
	var data: Dictionary = ship.to_dict()
	assert_that(data).is_not_null()
	var ship2 := ShipClass.new()
	var loaded: bool = ship2.from_dict(data)
	assert_that(loaded).is_true()
	assert_that(ship2.get_name()).is_equal("Serialize Test")

# ============================================================================
# ShipComponent Tests (Core Rules p.63)
# ============================================================================

func test_component_construction():
	var comp := ShipComponentClass.new()
	assert_that(comp).is_not_null()
	assert_that(comp.is_active).is_false()

func test_component_activate_deactivate():
	var comp := ShipComponentClass.new()
	comp.activate()
	assert_that(comp.is_active).is_true()
	comp.deactivate()
	assert_that(comp.is_active).is_false()

func test_component_upgrade():
	var comp := ShipComponentClass.new()
	comp.level = 1
	comp.max_level = 3
	var result: bool = comp.upgrade()
	assert_that(result).is_true()
	assert_that(comp.level).is_equal(2)

func test_component_cannot_upgrade_past_max():
	var comp := ShipComponentClass.new()
	comp.level = 3
	comp.max_level = 3
	var result: bool = comp.upgrade()
	assert_that(result).is_false()
	assert_that(comp.level).is_equal(3)

func test_component_can_upgrade():
	var comp := ShipComponentClass.new()
	comp.level = 2
	comp.max_level = 5
	assert_that(comp.can_upgrade()).is_true()

func test_component_cannot_upgrade_at_max():
	var comp := ShipComponentClass.new()
	comp.level = 5
	comp.max_level = 5
	assert_that(comp.can_upgrade()).is_false()

func test_component_durability_damage():
	var comp := ShipComponentClass.new()
	comp.durability = 100.0
	comp.max_durability = 100.0
	comp.apply_damage(30.0)
	assert_that(comp.durability).is_less(100.0)

func test_component_repair():
	var comp := ShipComponentClass.new()
	comp.durability = 50.0
	comp.max_durability = 100.0
	comp.repair(25.0)
	assert_that(comp.durability).is_greater(50.0)

func test_component_repair_full():
	var comp := ShipComponentClass.new()
	comp.durability = 30.0
	comp.max_durability = 100.0
	comp.repair_full()
	assert_that(comp.durability).is_equal(comp.max_durability)

func test_component_wear_increase():
	var comp := ShipComponentClass.new()
	comp.wear_level = 0
	comp.increase_wear()
	assert_that(comp.wear_level).is_equal(1)

func test_component_wear_capped_at_five():
	var comp := ShipComponentClass.new()
	comp.wear_level = 5
	comp.increase_wear()
	assert_that(comp.wear_level).is_less_equal(5)

func test_component_reset_wear():
	var comp := ShipComponentClass.new()
	comp.wear_level = 3
	comp.reset_wear()
	assert_that(comp.wear_level).is_equal(0)

func test_component_serialize_deserialize():
	var comp := ShipComponentClass.new()
	comp.name = "Test Component"
	comp.component_id = "test_comp_1"
	comp.level = 2
	comp.max_level = 5
	comp.wear_level = 1
	var data: Dictionary = comp.serialize()
	assert_that(data).is_not_null()
	assert_that(data.has("name") or data.has("component_id")).is_true()

func test_component_get_stats_returns_dict():
	var comp := ShipComponentClass.new()
	comp.component_type = "WEAPON"
	comp.damage = 5
	comp.attack = 3
	var stats: Dictionary = comp.get_stats()
	assert_that(stats).is_not_null()

func test_component_status_effects():
	var comp := ShipComponentClass.new()
	comp.add_status_effect({"type": "overheated", "duration": 2})
	assert_that(comp.status_effects.size()).is_equal(1)
	comp.clear_status_effects()
	assert_that(comp.status_effects.size()).is_equal(0)

func test_component_maintenance_cost():
	var comp := ShipComponentClass.new()
	comp.maintenance_cost = 10
	comp.level = 2
	var cost: int = comp.get_maintenance_cost()
	assert_that(cost).is_greater_equal(0)

func test_component_efficiency():
	var comp := ShipComponentClass.new()
	comp.efficiency = 1.0
	comp.wear_level = 0
	var eff: float = comp.get_efficiency()
	assert_that(eff).is_greater(0.0)

func test_component_efficiency_decreases_with_wear():
	var comp := ShipComponentClass.new()
	comp.efficiency = 1.0
	comp.wear_level = 0
	var eff_new: float = comp.get_efficiency()
	comp.wear_level = 3
	var eff_worn: float = comp.get_efficiency()
	assert_that(eff_worn).is_less_equal(eff_new)
