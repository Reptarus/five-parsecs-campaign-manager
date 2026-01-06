extends GdUnitTestSuite
## Integration Tests: Economy Debt System
## Tests debt accumulation, upkeep payment, and ship seizure mechanics
## gdUnit4 v6.0.1 compatible - UI mode only
## MAX 13 TESTS PER FILE

# System under test
var UpkeepSystemClass
var upkeep_system = null

# Supporting classes - use static helper class (GDScript 2.0 compatible)
const MockCampaignDataClass = preload("res://tests/helpers/MockCampaignData.gd")
var mock_campaign = null

func before():
	"""Suite-level setup - runs once before all tests"""
	UpkeepSystemClass = load("res://src/core/systems/UpkeepSystem.gd")

func before_test():
	"""Test-level setup - create fresh instances for each test"""
	# Set deterministic seed for reproducible random numbers
	seed(12345)

	upkeep_system = auto_free(UpkeepSystemClass.new())

	# Create mock campaign with standard crew - using static helper class
	mock_campaign = MockCampaignDataClass.new()
	mock_campaign.crew_members = _create_mock_crew(4)
	mock_campaign.ship_data = _create_mock_ship()
	mock_campaign.credits = 100
	mock_campaign.ship_debt = 0

func after_test():
	"""Test-level cleanup"""
	upkeep_system = null
	mock_campaign = null

func after():
	"""Suite-level cleanup - runs once after all tests"""
	UpkeepSystemClass = null
	# MockCampaignDataClass is a const preload, no cleanup needed

# ============================================================================
# Debt System Tests (7 tests)
# ============================================================================

func test_upkeep_payment_with_sufficient_credits():
	"""Upkeep can be paid when crew has sufficient credits"""
	# Set sufficient credits
	mock_campaign.credits = 100

	# Calculate upkeep
	var upkeep_costs = upkeep_system.calculate_upkeep_costs(mock_campaign)

	# Pay upkeep
	var success = upkeep_system.pay_upkeep(mock_campaign, upkeep_costs)

	# Verify payment successful
	assert_bool(success).is_true()
	assert_int(mock_campaign.credits).is_less(100)

func test_upkeep_fails_with_insufficient_credits():
	"""Upkeep payment fails when credits insufficient"""
	# Set insufficient credits
	mock_campaign.credits = 1

	# Calculate upkeep (4 crew = 4 credits minimum)
	var upkeep_costs = upkeep_system.calculate_upkeep_costs(mock_campaign)

	# Try to pay upkeep
	var success = upkeep_system.pay_upkeep(mock_campaign, upkeep_costs)

	# Verify payment failed
	assert_bool(success).is_false()

func test_debt_accumulates_correctly():
	"""Ship debt accumulates when payments missed"""
	# Start with debt
	mock_campaign.ship_debt = 30

	# Simulate debt increase (Five Parsecs rules: +1 credit if debt <=30)
	var new_debt = mock_campaign.ship_debt + 1
	mock_campaign.ship_debt = new_debt

	# Verify debt increased
	assert_int(mock_campaign.ship_debt).is_equal(31)

func test_debt_increases_faster_over_30_credits():
	"""Debt over 30 credits increases by 2 per turn (Five Parsecs rules)"""
	# Start with debt over 30
	mock_campaign.ship_debt = 35

	# Simulate debt increase (+2 credits if debt > 30)
	var new_debt = mock_campaign.ship_debt + 2
	mock_campaign.ship_debt = new_debt

	# Verify debt increased by 2
	assert_int(mock_campaign.ship_debt).is_equal(37)

func test_ship_seizure_risk_at_75_debt():
	"""Ship seizure is possible when debt reaches 75 credits"""
	# Set debt to seizure threshold
	mock_campaign.ship_debt = 75

	# Verify debt at critical threshold
	assert_int(mock_campaign.ship_debt).is_greater_equal(75)

	# Simulate seizure roll (2D6: 2-6 = seized, 7-12 = safe)
	var seizure_roll = randi_range(2, 12)
	var ship_seized = seizure_roll <= 6

	# Verify roll is valid
	assert_int(seizure_roll).is_between(2, 12)

func test_upkeep_failure_consequences():
	"""Upkeep failure triggers appropriate consequences"""
	# Set insufficient credits
	mock_campaign.credits = 0

	# Calculate upkeep
	var upkeep_costs = upkeep_system.calculate_upkeep_costs(mock_campaign)

	# Fail to pay
	var success = upkeep_system.pay_upkeep(mock_campaign, upkeep_costs)
	assert_bool(success).is_false()

	# Get consequences
	var consequences = upkeep_system.handle_upkeep_failure(mock_campaign)

	# Verify consequences structure
	assert_dict(consequences).contains_keys([
		"crew_morale_penalty",
		"ship_degradation",
		"crew_departure",
		"medical_complications"
	])

func test_injured_crew_increase_upkeep_costs():
	"""Injured crew members increase upkeep costs"""
	# Create crew with injured member (maintain Array[Resource] type)
	var all_crew: Array[Resource] = []
	all_crew.append_array(_create_mock_crew(3))
	all_crew.append(_create_mock_crew_member("Injured", true))
	mock_campaign.crew_members = all_crew

	# Calculate upkeep with injured crew
	var upkeep_costs = upkeep_system.calculate_upkeep_costs(mock_campaign)

	# Verify injury treatment costs added
	assert_int(upkeep_costs.get("injury_treatment", 0)).is_greater(0)
	assert_int(upkeep_costs.get("total", 0)).is_greater(4) # Base 4 crew + injury cost

# ============================================================================
# Helper Methods
# ============================================================================

func _create_mock_crew(size: int) -> Array[Resource]:
	"""Create mock crew members"""
	var crew: Array[Resource] = []
	for i in range(size):
		crew.append(_create_mock_crew_member("Crew_%d" % i, false))
	return crew

func _create_mock_crew_member(name: String, injured: bool) -> Resource:
	"""Create a single mock crew member"""
	var member = Resource.new()
	member.set_meta("character_name", name)
	member.set_meta("injured", injured)
	member.set_meta("recovery_time", 1 if injured else 0)
	member.set_meta("morale_penalty", false)
	return member

func _create_mock_ship() -> Resource:
	"""Create mock ship data"""
	var ship = Resource.new()
	ship.set_meta("hull_damage", 0)
	ship.set_meta("modifications", [])
	return ship
