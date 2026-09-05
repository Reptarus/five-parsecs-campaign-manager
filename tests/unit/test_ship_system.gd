extends GdUnitTestSuite
## Ship runtime model (src/core/ships/Ship.gd) — component management + serialization.
##
## Trimmed 2026-09-04. This suite used to carry 47 cases; 39 of them drove
## src/data/ship/ShipData.gd (21) and src/core/ships/components/ShipComponent.gd (18),
## both production-dead and deleted — the live ship path reads data/ships.json through
## ShiplessSystem.roll_ship_table() and ShipPanel._generate_ship(). The 8 cases here
## exercise the live Ship class and stay.

const ShipClass := preload("res://src/core/ships/Ship.gd")


## Duck-typed stand-in for the deleted ShipComponent.
##
## Ship.add_component / remove_component / get_component_by_id are duck-typed
## (Ship.gd:80-112) and never name a component class, so a stub is faithful here.
## `component_id` is DELIBERATE, not a shortcut: it exercises the third branch of
## get_component_by_id (Ship.gd:109-111), which exists precisely because
## ShipComponent exposed component_id with no get_id()/id and the lookup could not
## otherwise find one. A stub with get_id() would silently move these cases onto a
## different branch and stop covering that fix.
class StubComponent extends Resource:
	var name: String = ""
	var component_id: String = ""

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
	var comp := StubComponent.new()
	comp.name = "Engine MK1"
	comp.component_id = "engine_mk1"
	var result: bool = ship.add_component(comp)
	assert_that(result).is_true()
	assert_that(ship.get_components().size()).is_equal(1)

func test_ship_remove_component():
	var ship := ShipClass.new()
	var comp := StubComponent.new()
	comp.name = "Shield Gen"
	comp.component_id = "shield_gen"
	ship.add_component(comp)
	var result: bool = ship.remove_component(comp)
	assert_that(result).is_true()
	assert_that(ship.get_components().size()).is_equal(0)

func test_ship_get_component_by_id():
	var ship := ShipClass.new()
	var comp := StubComponent.new()
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

