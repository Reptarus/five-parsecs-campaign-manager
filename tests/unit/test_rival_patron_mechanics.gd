extends GdUnitTestSuite
## Rival and Patron Mechanics Tests
## Tests formulas and mechanics for rival/patron systems from Five Parsecs From Home
## gdUnit4 v6.0.1 compatible

# Test data
var test_campaign: Dictionary
var test_crew: Array[Dictionary]

# System under test helpers
var RivalPatronHelper
var helper

func before():
	"""Suite-level setup - runs once before all tests"""
	RivalPatronHelper = load("res://tests/helpers/RivalPatronMechanicsHelper.gd")
	helper = RivalPatronHelper.new()

func after():
	"""Suite-level cleanup - runs once after all tests"""
	helper = null
	RivalPatronHelper = null

func before_test():
	"""Test-level setup - runs before EACH test"""
	# Reset test data for each test
	test_campaign = {
		"rivals": [],
		"patrons": [],
		"decoys": 0,
		"credits": 10,
		"planet_id": "test_planet_01"
	}

	test_crew = [
		{"character_name": "Test Character 1", "savvy": 1},
		{"character_name": "Test Character 2", "savvy": 0}
	]

func after_test():
	"""Test-level cleanup - runs after EACH test"""
	test_campaign = {}
	test_crew = []

# ============================================================================
# Track Task Tests - p.108 Five Parsecs From Home
# Formula: 1D6 + trackers >= 6 = success
# ============================================================================

func test_track_task_formula():
	"""Track task: 1D6 + trackers >= 6 = success"""
	# Success cases
	var result = helper._resolve_track_task(6, 0)  # 6+0=6, success
	assert_bool(result.success).is_true()

	result = helper._resolve_track_task(3, 3)  # 3+3=6, success
	assert_bool(result.success).is_true()

	result = helper._resolve_track_task(1, 5)  # 1+5=6, success
	assert_bool(result.success).is_true()

	# Failure cases
	result = helper._resolve_track_task(5, 0)  # 5+0=5, failure
	assert_bool(result.success).is_false()

	result = helper._resolve_track_task(3, 2)  # 3+2=5, failure
	assert_bool(result.success).is_false()

# ============================================================================
# Decoy Integration Tests - p.82 Five Parsecs From Home
# Each decoy adds +1 to rival attack roll
# ============================================================================

func test_decoy_system():
	"""Decoy system: Each decoy adds +1, attack if original_roll <= num_rivals"""
	# Test decoy modifier calculation
	assert_int(helper._apply_decoy_modifier(4, 0)).is_equal(4)  # No decoys
	assert_int(helper._apply_decoy_modifier(4, 2)).is_equal(6)  # +2 decoys
	assert_int(helper._apply_decoy_modifier(4, 5)).is_equal(9)  # +5 decoys

	# Test rival attack with decoys (2 rivals, 2 decoys)
	test_campaign.rivals = [
		{"name": "Rival 1", "status": "Active"},
		{"name": "Rival 2", "status": "Active"}
	]
	test_campaign.decoys = 2

	# Roll 1 becomes 3, attack triggered (original 1 <= 2 rivals)
	var result = helper._check_rival_attack(1, test_campaign)
	assert_bool(result.attack_triggered).is_true()
	assert_int(result.modified_roll).is_equal(3)

	# Roll 3 becomes 5, no attack (original 3 > 2 rivals)
	result = helper._check_rival_attack(3, test_campaign)
	assert_bool(result.attack_triggered).is_false()

# ============================================================================
# Rival Removal Formula Tests - p.82 Five Parsecs From Home
# Base: 1D6, success on 4+ / Tracked: 1D6+1 / Persistent: 1D6-1
# ============================================================================

func test_rival_removal_formulas():
	"""Rival removal: Base 1D6>=4, Tracked +1, Persistent -1"""
	# Base formula (50% chance)
	assert_bool(helper._attempt_rival_removal(4, false, false).success).is_true()
	assert_bool(helper._attempt_rival_removal(3, false, false).success).is_false()

	# Tracked bonus +1 (67% chance)
	var result = helper._attempt_rival_removal(3, true, false)
	assert_bool(result.success).is_true()  # 3+1=4, success
	assert_int(result.modified_roll).is_equal(4)

	# Persistent penalty -1 (33% chance)
	result = helper._attempt_rival_removal(4, false, true)
	assert_bool(result.success).is_false()  # 4-1=3, failure

	result = helper._attempt_rival_removal(5, false, true)
	assert_bool(result.success).is_true()  # 5-1=4, success

# ============================================================================
# Find Patron Formula Tests - p.50 Five Parsecs From Home
# 1D6 + existing_patrons + credits_spent: >=5 = 1 patron, >=6 = 2 patrons
# ============================================================================

func test_find_patron_formulas():
	"""Find patron: 1D6+patrons+credits, >=5 = 1 patron, >=6 = 2 patrons"""
	# Thresholds
	assert_int(helper._find_patron(5, 0, 0).patrons_found).is_equal(1)  # 5 = 1 patron
	assert_int(helper._find_patron(6, 0, 0).patrons_found).is_equal(2)  # 6 = 2 patrons

	# Existing patron bonus (+1 per patron)
	assert_int(helper._find_patron(3, 2, 0).patrons_found).is_equal(1)  # 3+2=5, 1 patron
	assert_int(helper._find_patron(4, 2, 0).patrons_found).is_equal(2)  # 4+2=6, 2 patrons

	# Credits bonus (+1 per credit)
	assert_int(helper._find_patron(3, 0, 2).patrons_found).is_equal(1)  # 3+2=5, 1 patron
	assert_int(helper._find_patron(3, 0, 3).patrons_found).is_equal(2)  # 3+3=6, 2 patrons

# ============================================================================
# Freelancer License Tests - p.51 Five Parsecs From Home
# D6 roll of 5-6 = license required, Cost is 1D6 credits
# ============================================================================

func test_freelancer_license():
	"""Freelancer license: 1D6>=5 required (33%), cost 1D6 credits"""
	# License requirement
	assert_bool(helper._check_freelancer_license_requirement(5).license_required).is_true()
	assert_bool(helper._check_freelancer_license_requirement(6).license_required).is_true()
	assert_bool(helper._check_freelancer_license_requirement(4).license_required).is_false()
	assert_bool(helper._check_freelancer_license_requirement(1).license_required).is_false()

	# License cost (1-6 credits)
	assert_int(helper._calculate_freelancer_license_cost(1)).is_equal(1)
	assert_int(helper._calculate_freelancer_license_cost(3)).is_equal(3)
	assert_int(helper._calculate_freelancer_license_cost(6)).is_equal(6)

# ============================================================================
# Criminal 2D6 Rule Tests - p.81 Five Parsecs From Home
# 2D6: Any 1 = becomes rival, Both 1s = "hates" modifier
# ============================================================================

func test_criminal_rival_status():
	"""Criminal rival: 2D6 any 1 = rival (31%), both 1s = hates (3%)"""
	# Any 1 on either die = becomes rival
	var result = helper._check_criminal_rival_status(1, 4)
	assert_bool(result.becomes_rival).is_true()
	assert_bool(result.hates_crew).is_false()

	result = helper._check_criminal_rival_status(5, 1)
	assert_bool(result.becomes_rival).is_true()

	# No 1 = no rival
	result = helper._check_criminal_rival_status(3, 5)
	assert_bool(result.becomes_rival).is_false()

	# Both 1s = hates crew
	result = helper._check_criminal_rival_status(1, 1)
	assert_bool(result.becomes_rival).is_true()
	assert_bool(result.hates_crew).is_true()

# ============================================================================
# Persistent Patron Tests - p.51 Five Parsecs From Home
# Patrons with "Persistent" characteristic follow to new planet
# ============================================================================

func test_persistent_patron_travel():
	"""Persistent patron travel: "Persistent" = follows, no trait = dismissed"""
	# Persistent patron follows crew
	var persistent_patron = {
		"name": "Persistent Contact",
		"type": "CORPORATION",
		"characteristics": ["Persistent"],
		"planet_id": "old_planet"
	}
	var result = helper._apply_planet_travel(persistent_patron, "new_planet")
	assert_bool(result.retained).is_true()
	assert_str(result.new_planet_id).is_equal("new_planet")

	# Non-persistent patron dismissed
	var regular_patron = {
		"name": "Local Contact",
		"type": "LOCAL_GOVERNMENT",
		"characteristics": [],
		"planet_id": "old_planet"
	}
	result = helper._apply_planet_travel(regular_patron, "new_planet")
	assert_bool(result.retained).is_false()
