extends GdUnitTestSuite
## Phase 3A: Backend Integration Tests - Economy Consistency
## Tests EconomySystem resource validation, transaction integrity, and market pricing
## gdUnit4 v6.0.1 compatible
## HIGH BUG DISCOVERY PROBABILITY

# System under test
var EconomySystemClass
var economy_system = null

# Test helper
var HelperClass
var helper = null

# Mock GlobalEnums for resource types
# Must match actual GlobalEnums.ResourceType values (NONE=0, CREDITS=1, SUPPLIES=2, TECH_PARTS=3, PATRON=4, FUEL=5)
var mock_resource_enum = {
	"CREDITS": 1,
	"SUPPLIES": 2,
	"TECH_PARTS": 3,
	"FUEL": 5
}

var mock_market_state = {
	"NORMAL": 0,
	"BOOM": 1,
	"CRISIS": 2
}

func before():
	"""Suite-level setup - runs once before all tests"""
	EconomySystemClass = load("res://src/core/systems/EconomySystem.gd")
	HelperClass = load("res://tests/helpers/EconomyTestHelper.gd")
	helper = HelperClass.new()

func before_test():
	"""Test-level setup - create fresh economy instance for each test"""
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	economy_system = auto_free(EconomySystemClass.new())

	# Mock GlobalEnums for testing without autoload
	economy_system.resources = {
		mock_resource_enum.CREDITS: 100,
		mock_resource_enum.TECH_PARTS: 5,
		mock_resource_enum.FUEL: 10
	}
	economy_system._initialized = true

func after_test():
	"""Test-level cleanup"""
	economy_system = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	HelperClass = null
	EconomySystemClass = null

# ============================================================================
# Resource Validation Tests (3 tests)
# ============================================================================

func test_prevent_negative_credits():
	"""🐛 BUG DISCOVERY: Credits should never go negative"""
	# EXPECTED: set_resource() should reject negative values
	# ACTUAL: Currently allows negative values (line 319 no validation)

	economy_system.resources[mock_resource_enum.CREDITS] = 100

	# Try to set credits to negative value
	economy_system.set_resource(mock_resource_enum.CREDITS, -50, "test")

	# EXPECTED: Should prevent negative, keep at 0 or reject
	# ACTUAL: Will set to -50 (BUG!)
	var credits = economy_system.get_resource(mock_resource_enum.CREDITS)

	# This test will FAIL if negative prevention is missing
	assert_that(credits).is_greater_equal(0)

func test_resource_modification_overflow_prevention():
	"""🐛 BUG DISCOVERY: Resource modification should prevent integer overflow"""
	# EXPECTED: Should prevent overflow when adding large amounts
	# ACTUAL: May allow overflow to negative

	economy_system.resources[mock_resource_enum.CREDITS] = 2000000000  # Near INT32_MAX

	# Try to add more (would overflow)
	var large_amount = 1000000000
	economy_system.modify_resource(mock_resource_enum.CREDITS, large_amount, "test")

	var final_credits = economy_system.get_resource(mock_resource_enum.CREDITS)

	# Should either cap at MAX or reject transaction
	# This test documents expected overflow protection
	assert_that(final_credits).is_greater(0)  # Should not overflow to negative

func test_resource_history_bounded():
	"""Resource history should be bounded to MAX_HISTORY_ENTRIES (100)"""
	# Per line 67: MAX_HISTORY_ENTRIES = 100
	# Per line 68: HISTORY_PRUNE_THRESHOLD = 120

	# Initialize history array
	economy_system.resource_history[mock_resource_enum.CREDITS] = []

	# Add 150 transactions (exceeds MAX_HISTORY_ENTRIES)
	for i in range(150):
		var transaction = EconomySystemClass.ResourceTransaction.new(
			mock_resource_enum.CREDITS,
			i,
			i + 1,
			"test_transaction_%d" % i,
			i
		)
		economy_system.resource_history[mock_resource_enum.CREDITS].append(transaction)

	# Trigger pruning check (normally called by _add_history_entry)
	economy_system._prune_history_if_needed(mock_resource_enum.CREDITS)

	# After pruning, should not exceed HISTORY_PRUNE_THRESHOLD
	var history_size = economy_system.resource_history[mock_resource_enum.CREDITS].size()

	# Should be pruned to MAX_HISTORY_ENTRIES (100)
	# This test will FAIL if history pruning is not implemented
	assert_that(history_size).is_less_equal(120)  # HISTORY_PRUNE_THRESHOLD

# ============================================================================
# Transaction Validation Tests (3 tests)
# ============================================================================

func test_transaction_requires_sufficient_credits():
	"""🐛 BUG DISCOVERY: Buying should fail without sufficient credits"""
	# EXPECTED: process_transaction() should check credits before buying
	# ACTUAL: Currently NO credit validation (line 437-458)

	economy_system.resources[mock_resource_enum.CREDITS] = 10

	# Create mock item costing 100 credits
	var expensive_item = helper.create_mock_item("Expensive Weapon", 100, "WEAPON")

	# Try to buy item without enough credits (should fail)
	var result = economy_system.process_transaction(expensive_item, true, 1, "")

	# EXPECTED: Should return false (insufficient credits)
	# ACTUAL: Returns true, no credit check (BUG!)
	# This test will FAIL showing critical economy bug
	assert_that(result).is_false()

func test_transaction_prevents_negative_quantity():
	"""🐛 BUG DISCOVERY: Transaction quantity must be positive"""
	# EXPECTED: Should reject quantity <= 0
	# ACTUAL: May allow negative quantities

	economy_system.resources[mock_resource_enum.CREDITS] = 1000
	var item = helper.create_mock_item("Test Item", 10, "CONSUMABLE")

	# Try to buy -5 items (should fail)
	var result = economy_system.process_transaction(item, true, -5, "")

	# EXPECTED: Should return false or validate quantity > 0
	assert_that(result).is_false()

func test_transaction_updates_credits_atomically():
	"""🐛 BUG DISCOVERY: Credits should update atomically with transaction"""
	# EXPECTED: Credits deducted when buying, added when selling, in same frame
	# ACTUAL: process_transaction() doesn't modify credits at all (line 437-458)

	economy_system.resources[mock_resource_enum.CREDITS] = 100
	var item = helper.create_mock_item("Test Item", 10, "WEAPON")

	var initial_credits = economy_system.get_resource(mock_resource_enum.CREDITS)

	# Buy item (should deduct credits)
	economy_system.process_transaction(item, true, 1, "")

	var final_credits = economy_system.get_resource(mock_resource_enum.CREDITS)

	# EXPECTED: Credits should decrease when buying
	# ACTUAL: Credits unchanged (process_transaction doesn't update credits - BUG!)
	# This test will FAIL revealing transaction doesn't modify credits
	assert_that(final_credits).is_less(initial_credits)

# ============================================================================
# Market Price Validation Tests (2 tests)
# ============================================================================

func test_market_prices_within_bounds():
	"""Market prices should be clamped to MIN/MAX_PRICE_MULTIPLIER"""
	# Per line 73-74: MIN_PRICE_MULTIPLIER = 0.5, MAX_PRICE_MULTIPLIER = 2.0

	# Set extreme market modifier
	economy_system.market_prices["WEAPON"] = 5.0  # Exceeds MAX (2.0)

	# Validate state should flag this
	var validation = economy_system.validate_state()

	# Should warn about price outside bounds (line 293-294)
	assert_that(validation["warnings"].size()).is_greater(0)
	assert_that(validation["warnings"][0]).contains("Price")

func test_item_price_minimum_enforced():
	"""Item prices should have minimum value of 1 credit"""
	# Per line 420: max(1, base_price) ensures min price

	var item = helper.create_mock_item("Worthless Junk", 0, "JUNK")

	# Calculate price for selling (markdown applied)
	var price = economy_system.calculate_item_price(item, false, "")

	# Even with 0 base value and markdowns, should be at least 1
	assert_that(price).is_greater_equal(1)

# ============================================================================
# Economy State Consistency Tests (2 tests)
# ============================================================================

func test_economy_status_transitions_bounded():
	"""Economy status should stay within DEPRESSION to BOOM range"""
	var planet = "Test Planet"

	# Set to BOOM (highest)
	economy_system.set_economy_status(planet, EconomySystemClass.EconomyStatus.BOOM)

	# Try to increase beyond BOOM (should clamp)
	economy_system.update_economy(planet, 5)  # Huge positive change

	var status = economy_system.get_economy_status(planet)

	# Should stay at BOOM (line 476 clamps to range)
	assert_that(status).is_equal(EconomySystemClass.EconomyStatus.BOOM)

func test_trade_modifier_calculations():
	"""Trade modifiers should match Five Parsecs rulebook values"""
	# Per line 482-488: DEPRESSION=0.5, RECESSION=0.75, STABLE=1.0, GROWTH=1.25, BOOM=1.5

	var planet = "Test Planet"

	# Test each economy state
	economy_system.set_economy_status(planet, EconomySystemClass.EconomyStatus.DEPRESSION)
	assert_that(economy_system.get_trade_modifier(planet)).is_equal(0.5)

	economy_system.set_economy_status(planet, EconomySystemClass.EconomyStatus.STABLE)
	assert_that(economy_system.get_trade_modifier(planet)).is_equal(1.0)

	economy_system.set_economy_status(planet, EconomySystemClass.EconomyStatus.BOOM)
	assert_that(economy_system.get_trade_modifier(planet)).is_equal(1.5)
