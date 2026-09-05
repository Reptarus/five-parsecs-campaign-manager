extends GdUnitTestSuite
## The three Advanced Training courses whose effects reached nothing.
##
## Core Rules p.125 lists seven courses. Four were wired (medical,
## bot_technician, broker, merchant). These three were not — the course could be
## bought through a book-faithful, well-tested dialog, recorded on
## Character.acquired_training, and then do absolutely nothing:
##
##   security  "If this crew member is part of your squad when fighting a battle,
##              you may add +1 when rolling to Seize the Initiative."
##   pilot     "If a Starship Travel event calls for a Savvy test, you may roll
##              2D6, pick the better die and add +2 to the score."
##   mechanic  "If your ship is in need of Repairs, you may repair +1 Hull Point
##              damage every campaign turn (meaning 2 points of damage are
##              repaired per campaign turn)."
##
## Verified 2026-09-04: a repo-wide sweep of every Seize-the-Initiative modifier
## source found ten producers and no training among them; TravelEventResolver
## contained no occurrence of "training" at all; and the free hull repair was a
## hardcoded +1.

const SeizeSystem = preload("res://src/core/battle/SeizeInitiativeSystem.gd")
const TravelEventResolverRef = preload("res://src/core/world/TravelEventResolver.gd")
const PhaseManagerScript = preload("res://src/core/campaign/CampaignPhaseManager.gd")


func _member(name: String, savvy: int, training: Array = []) -> Dictionary:
	# Dictionary shape: what a loaded save actually holds.
	return {
		"character_name": name, "savvy": savvy, "origin": "HUMAN",
		"acquired_training": training,
	}


# --- security: +1 Seize the Initiative -----------------------------------

func _seize_total(crew: Array) -> int:
	var sys = SeizeSystem.new()
	sys.set_crew_data(crew)
	return sys._calculate_total_modifiers()


func test_security_training_adds_one_to_seize() -> void:
	var without: int = _seize_total([_member("A", 2)])
	var with_it: int = _seize_total([_member("A", 2, ["security"])])
	assert_int(with_it - without).override_failure_message(
		"p.125 Security Training: '+1 when rolling to Seize the Initiative'"
	).is_equal(1)


func test_security_counts_when_any_squad_member_holds_it() -> void:
	# The book gates on the member being "part of your squad", not on who rolls.
	var crew: Array = [_member("A", 3), _member("B", 1, ["security"])]
	assert_int(_seize_total(crew)).is_equal(1)


func test_two_trained_members_still_give_only_one() -> void:
	# p.124: "you cannot benefit from more than one crew member with the same
	# training."
	var crew: Array = [_member("A", 2, ["security"]), _member("B", 2, ["security"])]
	assert_int(_seize_total(crew)).override_failure_message(
		"a second Security-trained member must add nothing"
	).is_equal(1)


func test_an_untrained_crew_gets_no_seize_bonus() -> void:
	assert_int(_seize_total([_member("A", 4), _member("B", 3)])).is_equal(0)


# --- pilot: 2D6 pick better, +2 ------------------------------------------

func test_pilot_training_changes_the_savvy_test_die() -> void:
	# Untrained is a plain 1D6, so 1..6. Trained is max(1D6,1D6)+2, so 3..8.
	# Sampled rather than seeded because the roll goes through the global RNG;
	# the two RANGES are disjoint below 3, which is what makes this decisive.
	var untrained := _member("U", 0)
	var trained := _member("P", 0, ["pilot"])

	var u_min: int = 99
	var t_min: int = 99
	var t_max: int = -1
	for _i in range(400):
		u_min = mini(u_min, TravelEventResolverRef._savvy_test_die(untrained))
		var t: int = TravelEventResolverRef._savvy_test_die(trained)
		t_min = mini(t_min, t)
		t_max = maxi(t_max, t)

	assert_int(u_min).override_failure_message(
		"an untrained Savvy test is 1D6 and must be able to roll 1"
	).is_equal(1)
	assert_int(t_min).override_failure_message(
		"p.125 Pilot Training is max(2D6)+2, so it can never score below 3"
	).is_greater_equal(3)
	assert_int(t_max).is_less_equal(8)


func test_pilot_training_never_scores_worse_than_the_plain_die() -> void:
	var trained := _member("P", 0, ["pilot"])
	for _i in range(200):
		assert_int(TravelEventResolverRef._savvy_test_die(trained)).is_between(3, 8)


func test_a_pilot_is_selected_for_the_savvy_test_over_raw_savvy() -> void:
	# "Select a crew member" — with the course in play the player would pick the
	# pilot, because max(2D6)+2 beats a point or two of Savvy.
	var crew: Array = [_member("HighSavvy", 5), _member("Pilot", 1, ["pilot"])]
	var chosen: Variant = TravelEventResolverRef._best_savvy(crew)
	assert_str(str(chosen.get("character_name", ""))).override_failure_message(
		"a Pilot-trained crew member should take a Starship Travel Savvy test"
	).is_equal("Pilot")


func test_without_a_pilot_the_highest_savvy_is_still_chosen() -> void:
	var crew: Array = [_member("Low", 1), _member("High", 5)]
	var chosen: Variant = TravelEventResolverRef._best_savvy(crew)
	assert_str(str(chosen.get("character_name", ""))).is_equal("High")


# --- mechanic: +1 Hull Point per campaign turn ---------------------------

class StubCampaign extends Resource:
	var ship_data: Dictionary = {}
	var has_ship: bool = true
	var crew_data: Dictionary = {"members": []}
	func get_crew_members() -> Array:
		return crew_data.get("members", [])


func _repair_once(crew: Array) -> int:
	var pm = PhaseManagerScript.new()
	add_child(pm)
	auto_free(pm)
	var c := StubCampaign.new()
	c.ship_data = {"hull_points": 5, "max_hull": 20}
	c.crew_data = {"members": crew}
	pm._process_free_hull_repair(c)
	return int(c.ship_data["hull_points"]) - 5


func test_the_free_repair_is_one_point_without_a_mechanic() -> void:
	# Core Rules p.59: "Damage is repaired at a rate of 1 Hull Point per campaign
	# turn."
	assert_int(_repair_once([_member("A", 2)])).is_equal(1)


func test_mechanic_training_repairs_two_points() -> void:
	# p.125: "+1 Hull Point damage every campaign turn (meaning 2 points of
	# damage are repaired per campaign turn)."
	assert_int(_repair_once([_member("A", 2, ["mechanic"])])).override_failure_message(
		"a Mechanic-trained crew must repair 2 Hull Points per turn"
	).is_equal(2)


func test_a_second_mechanic_adds_nothing() -> void:
	var crew: Array = [_member("A", 2, ["mechanic"]), _member("B", 2, ["mechanic"])]
	assert_int(_repair_once(crew)).is_equal(2)
