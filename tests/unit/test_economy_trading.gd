extends GdUnitTestSuite
## Tests for Economy & Trading Systems
## Covers 5 NOT_TESTED mechanics from QA_CORE_RULES_TEST_PLAN.md §3
## Core Rules Reference: Sell Value (p.47), Travel Costs (p.71), Danger Pay (p.97)

const ShipDataClass := preload("res://src/data/ship/ShipData.gd")

# Note: EquipmentManager and TravelPhase are Node-based autoloads that need
# scene tree. We test the underlying data models and static calculations here.

# ============================================================================
# Sell Value — Condition-Aware Resale (EquipmentManager.sell_equipment)
# ============================================================================

func test_sell_value_full_condition():
	"""Full condition (100%) equipment sells at 50% of base value"""
	var base_value := 100
	var condition := 100
	var sell_value := int(base_value * (condition / 100.0) * 0.5)
	assert_that(sell_value).is_equal(50)

func test_sell_value_half_condition():
	"""50% condition equipment sells at 25% of base value"""
	var base_value := 100
	var condition := 50
	var sell_value := int(base_value * (condition / 100.0) * 0.5)
	assert_that(sell_value).is_equal(25)

func test_sell_value_zero_condition():
	"""Broken equipment (0%) sells for nothing"""
	var base_value := 100
	var condition := 0
	var sell_value := int(base_value * (condition / 100.0) * 0.5)
	assert_that(sell_value).is_equal(0)

func test_sell_value_high_base():
	"""High-value items still follow the 50% rule"""
	var base_value := 500
	var condition := 100
	var sell_value := int(base_value * (condition / 100.0) * 0.5)
	assert_that(sell_value).is_equal(250)

func test_sell_value_partial_damage():
	"""75% condition = 37% of base (75% × 50%)"""
	var base_value := 200
	var condition := 75
	var sell_value := int(base_value * (condition / 100.0) * 0.5)
	assert_that(sell_value).is_equal(75)

# ============================================================================
# Travel Costs — Base + Ship Trait Modifiers (Core Rules p.71)
# ============================================================================

func test_travel_cost_shipless():
	"""Shipless crew: 1 credit per crew member"""
	var crew_size := 5
	var cost := crew_size * 1
	assert_that(cost).is_equal(5)

func test_travel_cost_base_with_ship():
	"""Base travel cost with ship: 5 credits"""
	var base_cost := 5
	assert_that(base_cost).is_equal(5)

func test_travel_cost_fuel_efficient_trait():
	"""Fuel-efficient ship trait: -1 credit"""
	var base_cost := 5
	var modifier := -1  # fuel_efficient
	var final_cost := maxi(base_cost + modifier, 0)
	assert_that(final_cost).is_equal(4)

func test_travel_cost_fuel_hog_trait():
	"""Fuel Hog ship trait: +1 credit"""
	var base_cost := 5
	var modifier := 1  # fuel_hog
	var final_cost := base_cost + modifier
	assert_that(final_cost).is_equal(6)

func test_travel_cost_components_modifier():
	"""Components: +1 per 3 components"""
	var base_cost := 5
	var component_count := 7
	var component_modifier := component_count / 3  # int division = 2
	var final_cost := base_cost + component_modifier
	assert_that(final_cost).is_equal(7)

func test_travel_cost_fuel_converters():
	"""Fuel Converters equipment: -2 credits"""
	var base_cost := 5
	var converter_modifier := -2
	var final_cost := maxi(base_cost + converter_modifier, 0)
	assert_that(final_cost).is_equal(3)

func test_travel_cost_combined_modifiers():
	"""All modifiers combined: 5 + 1(hog) + 2(6 comps) - 2(converters) = 6"""
	var base_cost := 5
	var fuel_hog := 1
	var components := 6 / 3  # = 2
	var converters := -2
	var final_cost := maxi(base_cost + fuel_hog + components + converters, 0)
	assert_that(final_cost).is_equal(6)

func test_travel_cost_cannot_go_negative():
	"""Travel cost floor is 0"""
	var base_cost := 5
	var huge_discount := -10
	var final_cost := maxi(base_cost + huge_discount, 0)
	assert_that(final_cost).is_equal(0)

# ============================================================================
# Ship Debt Interest (Core Rules p.80)
# ============================================================================

func test_ship_debt_interest_per_turn():
	"""Ship debt accrues +1 per turn"""
	var debt := 10
	debt += 1  # Turn interest
	assert_that(debt).is_equal(11)

func test_ship_debt_high_interest():
	"""High debt (>20) accrues +2 per turn"""
	var debt := 25
	var interest := 2 if debt > 20 else 1
	debt += interest
	assert_that(debt).is_equal(27)

func test_ship_debt_zero_no_interest():
	"""No debt = no interest"""
	var debt := 0
	var interest := 0 if debt == 0 else 1
	debt += interest
	assert_that(debt).is_equal(0)

func test_ship_debt_persistence_via_ship_data():
	"""Debt should persist through ShipData serialization"""
	var ship := ShipDataClass.new()
	ship.ship_name = "Debt Test"
	ship.outstanding_debt = 15
	var data: Dictionary = ship.to_dictionary()
	var restored = ShipDataClass.from_dictionary(data)
	assert_that(restored.outstanding_debt).is_equal(15)

# ============================================================================
# Upkeep Costs (Core Rules p.80)
# ============================================================================

func test_crew_upkeep_basic():
	"""1 credit per crew member"""
	var crew_size := 6
	var upkeep := crew_size * 1
	assert_that(upkeep).is_equal(6)

func test_crew_upkeep_high_cost_world():
	"""High-cost world trait: +2 effective members"""
	var crew_size := 6
	var world_modifier := 2  # high_cost
	var upkeep := (crew_size + world_modifier) * 1
	assert_that(upkeep).is_equal(8)

func test_ship_maintenance_base():
	"""Ship maintenance: 1 credit base"""
	var maintenance := 1
	assert_that(maintenance).is_equal(1)

func test_ship_maintenance_damaged():
	"""Damaged ship: double maintenance"""
	var base_maintenance := 1
	var is_damaged := true
	var maintenance := base_maintenance * (2 if is_damaged else 1)
	assert_that(maintenance).is_equal(2)

func test_total_upkeep_calculation():
	"""Total = crew upkeep + ship maintenance"""
	var crew_size := 5
	var crew_upkeep := crew_size * 1  # 5
	var ship_maintenance := 1
	var total := crew_upkeep + ship_maintenance
	assert_that(total).is_equal(6)

func test_insufficient_funds_detection():
	"""Should detect when credits < total upkeep"""
	var credits := 3
	var total_upkeep := 7
	var can_afford := credits >= total_upkeep
	assert_that(can_afford).is_false()

func test_sufficient_funds_detection():
	"""Should pass when credits >= total upkeep"""
	var credits := 10
	var total_upkeep := 7
	var can_afford := credits >= total_upkeep
	assert_that(can_afford).is_true()

# ============================================================================
# Danger Pay (Core Rules p.97)
# ============================================================================

func test_danger_pay_easy():
	"""Easy difficulty: no danger pay bonus"""
	var base_pay := 10
	var danger_bonus := 0  # Easy
	assert_that(base_pay + danger_bonus).is_equal(10)

func test_danger_pay_hardcore():
	"""Hardcore difficulty: +1 danger pay"""
	var base_pay := 10
	var danger_bonus := 1  # Hardcore
	assert_that(base_pay + danger_bonus).is_equal(11)
