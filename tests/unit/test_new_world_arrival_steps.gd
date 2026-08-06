extends GdUnitTestSuite
## New World Arrival steps 1-2 (Core Rules p.72).
##
## THE GAP THESE PIN. Both steps existed ONLY inside
## src/core/campaign/phases/TravelPhase.gd — a file with zero instantiations —
## so neither had ever run in any campaign:
##
##   1. Check for Rivals — "Any Rivals you have will roll 1D6. On a 5+, they opt
##      to follow you, otherwise they remain behind."
##   2. Dismiss Patrons — "All Patrons remain behind unless they are Persistent."
##
## Consequences of the omission: every Rival ever made followed the crew forever,
## which inflates the p.85 "roll a D6 against the number of Rivals" check into a
## near-certain forced Rival battle every turn; and Patrons never lapsed on
## travel, so the p.84 "Persistent" Benefit was a reward for nothing.

const Arrival = preload("res://src/core/campaign/NewWorldArrival.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _campaign(rivals: Array, patrons: Array) -> Resource:
	var c = CampaignCore.new()
	c.rivals = rivals
	c.patrons = patrons
	return c


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- Step 1: Rivals -----------------------------------------------------------

## The rule is a per-Rival 1D6 keeping on 5+, so across a large list the survivors
## must be a strict subset and not empty. Asserting the INVARIANT rather than an
## exact count: a seed fixes the RNG stream, not the value, so any unrelated
## change to how many dice are drawn upstream would break an exact assertion.
func test_rivals_do_not_all_follow_you() -> void:
	var rivals: Array = []
	for i: int in range(300):
		rivals.append({"id": "rival_%d" % i, "name": "Rival %d" % i})
	var campaign: Resource = _campaign(rivals, [])

	Arrival.apply(campaign, _seeded(20260802))

	assert_int(campaign.rivals.size()).override_failure_message(
		"every Rival followed the crew — step 1 did not run"
	).is_less(300)
	assert_int(campaign.rivals.size()).override_failure_message(
		"no Rival followed at all — a 5+ on 1D6 should keep roughly a third"
	).is_greater(0)


## 5+ on 1D6 is 2 outcomes in 6. Over 300 rivals the survivor share must land near
## a third; a wrong comparison (>=4, or >5) would push it far outside this band.
func test_the_follow_threshold_is_five_plus() -> void:
	var rivals: Array = []
	for i: int in range(300):
		rivals.append({"id": "r%d" % i})
	var campaign: Resource = _campaign(rivals, [])

	Arrival.apply(campaign, _seeded(7))

	var share: float = float(campaign.rivals.size()) / 300.0
	assert_bool(share > 0.22 and share < 0.45).override_failure_message(
		"kept %.2f of Rivals; a 1D6 5+ should keep about 0.33" % share
	).is_true()


## The kept entries must be the original objects, not reconstructed ones — a
## Rival carries state (was_unique_individual, was_lieutenant) that p.119 reads.
func test_following_rivals_keep_their_identity() -> void:
	var rivals: Array = []
	for i: int in range(60):
		rivals.append({"id": "r%d" % i, "was_lieutenant": true})
	var campaign: Resource = _campaign(rivals, [])

	Arrival.apply(campaign, _seeded(11))

	for rival: Variant in campaign.rivals:
		assert_bool(rival is Dictionary).is_true()
		assert_bool(bool(rival.get("was_lieutenant", false))).override_failure_message(
			"a following Rival lost the state p.119 needs"
		).is_true()


# --- Step 2: Patrons ----------------------------------------------------------

## No roll here: non-Persistent Patrons always remain behind.
func test_non_persistent_patrons_are_all_dismissed() -> void:
	var campaign: Resource = _campaign([], [
		{"id": "p1", "name": "Corp"},
		{"id": "p2", "name": "Local Gov"},
		"a bare string patron",
	])

	var report: Dictionary = Arrival.apply(campaign, _seeded(3))

	assert_int(campaign.patrons.size()).override_failure_message(
		"Patrons survived travel — step 2 did not run"
	).is_equal(0)
	assert_int((report.get("patrons_left", []) as Array).size()).is_equal(3)


## The flag has three spellings in the wild (is_persistent / persistent /
## type == "persistent") plus NPCTracker's duration_turns == -1. All must count,
## or the p.84 Benefit silently stops working for whichever writer used the
## other spelling.
func test_every_persistent_spelling_survives_travel() -> void:
	var campaign: Resource = _campaign([], [
		{"id": "a", "is_persistent": true},
		{"id": "b", "persistent": true},
		{"id": "c", "type": "persistent"},
		{"id": "d", "duration_turns": -1},
		{"id": "e"},                        # not persistent, must be dropped
	])

	Arrival.apply(campaign, _seeded(5))

	var kept: Array[String] = []
	for patron: Variant in campaign.patrons:
		kept.append(str(patron.get("id", "")))
	assert_array(kept).contains(["a", "b", "c", "d"])
	assert_array(kept).not_contains(["e"])


## A bare String patron carries no benefit data, so it cannot be Persistent.
func test_string_patrons_are_not_persistent() -> void:
	assert_bool(Arrival.is_persistent_patron("Sector Government")).is_false()
	assert_bool(Arrival.is_persistent_patron({"persistent": true})).is_true()


## An empty roster must not error or invent entries.
func test_empty_lists_are_safe() -> void:
	var campaign: Resource = _campaign([], [])
	var report: Dictionary = Arrival.apply(campaign, _seeded(1))
	assert_int(campaign.rivals.size()).is_equal(0)
	assert_int(campaign.patrons.size()).is_equal(0)
	assert_int((report.get("rivals_left", []) as Array).size()).is_equal(0)


# --- Held job offers leave with the Patron who did not follow -----------------

## Job offers persist across campaign turns now (Core Rules p.83 Time Frame), so
## the travel purge has to reach them too. Without this the offer list would keep
## serving jobs from Patrons the crew left a world behind — and a 10+ "Any time"
## offer would outlive its Patron for the rest of the campaign.
func test_offers_from_dismissed_patrons_are_dropped() -> void:
	var campaign: Resource = _campaign([], [
		{"id": "p_stay", "name": "Ordinary Patron"},
		{"id": "p_follow", "name": "Loyal Patron", "is_persistent": true},
	])
	campaign.progress_data["patron_job_offers"] = [
		{"id": "job_a", "patron_id": "p_stay", "deadline_turn": -1},
		{"id": "job_b", "patron_id": "p_follow", "deadline_turn": -1},
	]

	var report: Dictionary = Arrival.apply(campaign, _seeded(7))

	var surviving: Array = campaign.progress_data["patron_job_offers"]
	assert_int(surviving.size()).override_failure_message(
		"only the Persistent Patron's offer should survive travel").is_equal(1)
	assert_str(str(surviving[0]["patron_id"])).is_equal("p_follow")
	assert_int(int(report.get("offers_dropped", 0))).is_equal(1)


## A Patron entry may carry no id at all — campaign.patrons is a MIXED array of
## Strings and Dictionaries — so the offer's patron_id falls back to the name.
## Matching on the wrong key would silently bin every offer on every journey.
func test_offers_match_patrons_that_have_no_id() -> void:
	var campaign: Resource = _campaign([], [
		{"name": "Nameless Benefactor", "persistent": true},
	])
	campaign.progress_data["patron_job_offers"] = [
		{"id": "job_c", "patron_id": "Nameless Benefactor", "deadline_turn": -1},
	]

	Arrival.apply(campaign, _seeded(3))

	assert_int((campaign.progress_data["patron_job_offers"] as Array).size()
		).override_failure_message(
		"an offer keyed by NAME must survive when its Patron does").is_equal(1)


## A campaign that has never generated an offer must not gain a key or error.
func test_no_offers_is_safe() -> void:
	var campaign: Resource = _campaign([], [{"id": "p1", "name": "Someone"}])
	var report: Dictionary = Arrival.apply(campaign, _seeded(2))
	assert_int(int(report.get("offers_dropped", 0))).is_equal(0)
