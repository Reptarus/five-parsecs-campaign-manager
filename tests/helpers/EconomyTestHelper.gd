class_name EconomyTestHelper
## Phase 3A Helper: Economy System Testing
## Provides mock items, transaction validation, and market analysis
## Plain class (no Node inheritance) for gdUnit4 v6.0.1 compatibility

## Mock item creation

func create_mock_item(item_name: String, base_value: int, item_type: String) -> Resource:
	"""Create mock item resource for transaction testing"""
	var item = Resource.new()
	item.set_meta("name", item_name)
	item.set_meta("value", base_value)
	item.set_meta("type", item_type)
	item.set_meta("description", "Test item: %s" % item_name)
	return item

func create_mock_weapon(weapon_name: String = "Test Weapon", value: int = 50) -> Resource:
	"""Create mock weapon for trade testing"""
	var weapon = create_mock_item(weapon_name, value, "WEAPON")
	weapon.set_meta("damage", "1d6")
	weapon.set_meta("range", 12)
	weapon.set_meta("shots", 2)
	return weapon

func create_mock_gear(gear_name: String = "Test Gear", value: int = 30) -> Resource:
	"""Create mock gear item"""
	var gear = create_mock_item(gear_name, value, "GEAR")
	gear.set_meta("gear_type", "UTILITY")
	return gear

func create_mock_consumable(consumable_name: String = "Med Kit", value: int = 15) -> Resource:
	"""Create mock consumable item"""
	var consumable = create_mock_item(consumable_name, value, "CONSUMABLE")
	consumable.set_meta("uses", 1)
	return consumable

func create_restricted_item(item_name: String = "Military Grade Weapon") -> Resource:
	"""Create mock restricted item for trade validation testing"""
	var item = create_mock_item(item_name, 200, "RESTRICTED")
	item.set_meta("restricted", true)
	item.set_meta("military_grade", true)
	return item

## Resource transaction helpers

func create_mock_resource_state(credits: int = 100, ship_parts: int = 5, fuel: int = 10) -> Dictionary:
	"""Create mock resource state for testing"""
	return {
		"CREDITS": credits,
		"SHIP_PARTS": ship_parts,
		"FUEL": fuel,
		"SUPPLIES": 8
	}

func create_transaction_snapshot(economy_system) -> Dictionary:
	"""Create snapshot of economy state for before/after comparison"""
	return {
		"credits": economy_system.get_resource(0),  # Assuming CREDITS = 0
		"market_prices": economy_system.market_prices.duplicate(),
		"supply_demand": economy_system.supply_demand.duplicate(),
		"timestamp": Time.get_ticks_msec()
	}

func compare_transaction_snapshots(before: Dictionary, after: Dictionary) -> Dictionary:
	"""Compare two transaction snapshots"""
	return {
		"credit_change": after.credits - before.credits,
		"prices_changed": before.market_prices != after.market_prices,
		"supply_changed": before.supply_demand != after.supply_demand,
		"time_elapsed_ms": after.timestamp - before.timestamp
	}

## Validation functions

func validate_credits_non_negative(economy_system) -> Dictionary:
	"""Validate that credits cannot go negative"""
	var result = {"valid": true, "errors": []}

	var credits = economy_system.get_resource(0)  # CREDITS = 0
	if credits < 0:
		result.valid = false
		result.errors.append("Credits are negative: %d" % credits)

	return result

func validate_transaction_integrity(economy_system, item: Resource, is_buying: bool, quantity: int) -> Dictionary:
	"""Validate transaction has all required components"""
	var result = {"valid": true, "errors": []}

	# Check item validity
	if not item:
		result.valid = false
		result.errors.append("Item is null")
		return result

	if not item.has_meta("value"):
		result.valid = false
		result.errors.append("Item missing 'value' property")

	if not item.has_meta("type"):
		result.valid = false
		result.errors.append("Item missing 'type' property")

	# Check quantity validity
	if quantity <= 0:
		result.valid = false
		result.errors.append("Quantity must be positive: %d" % quantity)

	# Check credits if buying
	if is_buying:
		var price = economy_system.calculate_item_price(item, true, "") * quantity
		var credits = economy_system.get_resource(0)  # CREDITS = 0

		if credits < price:
			result.valid = false
			result.errors.append("Insufficient credits: have %d, need %d" % [credits, price])

	return result

func validate_market_prices_in_bounds(economy_system) -> Dictionary:
	"""Validate all market prices are within MIN/MAX_PRICE_MULTIPLIER bounds"""
	var result = {"valid": true, "out_of_bounds": []}

	var MIN_PRICE = 0.5
	var MAX_PRICE = 2.0

	for item_type in economy_system.market_prices.keys():
		var price = economy_system.market_prices[item_type]

		if price < MIN_PRICE or price > MAX_PRICE:
			result.valid = false
			result.out_of_bounds.append({
				"item_type": item_type,
				"price": price,
				"below_min": price < MIN_PRICE,
				"above_max": price > MAX_PRICE
			})

	return result

## Market analysis helpers

func calculate_expected_buy_price(base_value: int, planet_economy_status: int = 2) -> int:
	"""Calculate expected buy price with all modifiers"""
	# Per EconomySystem line 416: base * MARKUP * location * market * global
	var BASE_MARKUP = 1.2

	# Economy status modifiers (line 482-488)
	var location_modifier = 1.0
	match planet_economy_status:
		0: location_modifier = 0.5  # DEPRESSION
		1: location_modifier = 0.75  # RECESSION
		2: location_modifier = 1.0  # STABLE
		3: location_modifier = 1.25  # GROWTH
		4: location_modifier = 1.5  # BOOM

	# Assume market and global modifiers = 1.0 for baseline test
	var final_price = int(base_value * BASE_MARKUP * location_modifier * 1.0 * 1.0)

	return max(1, final_price)

func calculate_expected_sell_price(base_value: int, planet_economy_status: int = 2) -> int:
	"""Calculate expected sell price with all modifiers"""
	# Per EconomySystem line 418: base * MARKDOWN * location * market * global
	var BASE_MARKDOWN = 0.8

	var location_modifier = 1.0
	match planet_economy_status:
		0: location_modifier = 0.5  # DEPRESSION
		1: location_modifier = 0.75  # RECESSION
		2: location_modifier = 1.0  # STABLE
		3: location_modifier = 1.25  # GROWTH
		4: location_modifier = 1.5  # BOOM

	var final_price = int(base_value * BASE_MARKDOWN * location_modifier * 1.0 * 1.0)

	return max(1, final_price)

## Supply/demand tracking

func create_supply_demand_state(supply: float, demand: float) -> Dictionary:
	"""Create supply/demand state for market simulation"""
	return {
		"supply": clampf(supply, 0.1, 2.0),
		"demand": clampf(demand, 0.1, 2.0)
	}

func simulate_market_transaction_impact(sd_state: Dictionary, is_buying: bool, quantity: int) -> Dictionary:
	"""Simulate how transaction affects supply/demand"""
	# Per EconomySystem line 448-455
	var new_state = sd_state.duplicate()

	if is_buying:
		new_state.supply = maxf(0.1, new_state.supply - 0.1 * quantity)
		new_state.demand = minf(2.0, new_state.demand + 0.05 * quantity)
	else:
		new_state.supply = minf(2.0, new_state.supply + 0.1 * quantity)
		new_state.demand = maxf(0.1, new_state.demand - 0.05 * quantity)

	return new_state

## Economy state generation

func create_mock_planetary_economy(planet_name: String, status: int = 2) -> Dictionary:
	"""Create mock planetary economy data"""
	return {
		"planet_name": planet_name,
		"status": status,  # EconomyStatus enum value
		"market_conditions": {},
		"trade_routes": [],
		"last_update": Time.get_unix_time_from_system()
	}

func create_trade_route(from_planet: String, to_planet: String) -> Dictionary:
	"""Create mock trade route"""
	return {
		"from": from_planet,
		"to": to_planet,
		"established": Time.get_unix_time_from_system(),
		"active": true
	}

## History validation

func validate_resource_history_bounded(economy_system, resource_type: int, max_entries: int = 100) -> Dictionary:
	"""Validate resource history doesn't exceed bounds"""
	var result = {"valid": true, "errors": []}

	if not economy_system.resource_history.has(resource_type):
		result.valid = false
		result.errors.append("Resource type %d not in history" % resource_type)
		return result

	var history = economy_system.resource_history[resource_type]
	var history_size = history.size()

	if history_size > max_entries:
		result.valid = false
		result.errors.append("History size %d exceeds max %d" % [history_size, max_entries])

	return result

## Test data generators

func generate_random_market_prices(item_count: int = 10) -> Dictionary:
	"""Generate random market prices for testing"""
	var prices = {}

	for i in range(item_count):
		var item_type = "ITEM_%d" % i
		# Random multiplier between MIN (0.5) and MAX (2.0)
		prices[item_type] = randf_range(0.5, 2.0)

	return prices

func generate_extreme_market_prices(include_invalid: bool = true) -> Dictionary:
	"""Generate extreme market prices for boundary testing"""
	var prices = {
		"NORMAL_LOW": 0.5,  # MIN_PRICE_MULTIPLIER
		"NORMAL_HIGH": 2.0,  # MAX_PRICE_MULTIPLIER
		"NORMAL_MID": 1.0
	}

	if include_invalid:
		prices["INVALID_LOW"] = 0.1  # Below MIN
		prices["INVALID_HIGH"] = 5.0  # Above MAX
		prices["INVALID_ZERO"] = 0.0  # Zero price
		prices["INVALID_NEGATIVE"] = -1.0  # Negative price

	return prices
