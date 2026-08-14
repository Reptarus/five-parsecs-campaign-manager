extends GdUnitTestSuite
## T9-42 (tablet, Aug 13 2026) — "Pay 1 story point" was offered, and FREE, at 0 SP.
##
## Core Rules p.82, Exploration 97-100, verbatim. Read from the PDF itself (page
## index 81), not from docs/core_rules.md:
##
##   "This place is rather nice, really. When you are ready to leave this world,
##    unless it is being Invaded, you must pay 1 story point or this crew member
##    will decide to stay behind. If they do, you can keep their equipment,
##    though."
##
## ⚠ It does NOT match a naive substring search of the PDF text layer:
## extract_text() breaks the line, so "rather nice" hits only the p.129 Character
## Events row. Normalise whitespace before searching.
##
## One sentence, four rules, none of them honoured:
##   1. "you must pay 1 story point"  — modify_story_progress(-1) clamps at
##      max(0, ...), so at 0 SP the charge was a silent no-op while the dialog
##      printed "Paid the cost". Observed live at SP 0.
##   2. "when you are ready to leave this world" — charged immediately instead.
##   3. "unless it is being Invaded" — no exemption existed.
##   4. "you can keep their equipment, though" — the departing member's gear was
##      deleted along with them.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const DepartureObligation = preload("res://src/core/world/DepartureObligation.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _campaign(story_points: int = 2) -> Resource:
	var c: Resource = CampaignCore.new()
	c.story_points = story_points
	c.initialize_crew({"members": [
		{"character_id": "c1", "character_name": "Vance", "is_captain": true,
			"equipment": []},
		{"character_id": "c2", "character_name": "Rell", "is_captain": false,
			"equipment": [
				{"id": "itm_blade", "name": "Blade"},
				{"id": "itm_rifle", "name": "Colony Rifle"},
			]},
	]})
	c.equipment_data = {"equipment": []}
	return c


func _crew_ids(c: Resource) -> Array:
	var out: Array = []
	for m in c.get_crew_members():
		out.append(str(m.get("character_id", m.get("id", ""))))
	return out


func _stash_ids(c: Resource) -> Array:
	var out: Array = []
	for item in c.equipment_data.get("equipment", []):
		if item is Dictionary:
			out.append(str(item.get("id", "")))
	return out


# ── rule 2: the price comes due at DEPARTURE, not at the roll ────────────────

## Recording the obligation must not touch the story point balance. The whole
## defect class here is a cost applied at the wrong moment.
func test_recording_the_obligation_charges_nothing_yet() -> void:
	var c: Resource = _campaign(2)
	DepartureObligation.record(c, "c2", "Rell", true)
	assert_int(int(c.story_points)).override_failure_message(
		"p.82 charges 'when you are ready to leave this world' — recording the "
		+ "result must not spend anything").is_equal(2)
	assert_bool(DepartureObligation.has_pending(c)).is_true()
	assert_array(_crew_ids(c)).contains(["c2"])


## Staying put costs nothing, ever. Under the old immediate charge, a crew that
## never left still paid.
func test_a_crew_that_never_leaves_never_pays() -> void:
	var c: Resource = _campaign(2)
	DepartureObligation.record(c, "c2", "Rell", true)
	# no resolve_on_departure call — the crew stayed on this world
	assert_int(int(c.story_points)).is_equal(2)
	assert_array(_crew_ids(c)).contains(["c2"])


# ── rule 1: "you MUST pay 1 story point" ─────────────────────────────────────

func test_paying_on_departure_costs_a_story_point_and_keeps_the_crew() -> void:
	var c: Resource = _campaign(2)
	DepartureObligation.record(c, "c2", "Rell", true)
	var receipt: Dictionary = DepartureObligation.resolve_on_departure(c, false)
	assert_int(int(c.story_points)).is_equal(1)
	assert_int(int(receipt.get("paid", 0))).is_equal(1)
	assert_array(_crew_ids(c)).contains(["c2"])
	assert_bool(DepartureObligation.has_pending(c)).override_failure_message(
		"a settled obligation must not settle again on the next departure"
		).is_false()


## THE DEFECT, exactly as observed on the tablet: SP 0, "Pay 1 story point"
## accepted, "Paid the cost" printed, crew member kept, balance still 0.
## `modify_story_progress` clamps at max(0, ...), so the charge could never fail
## loudly — you must check the price BEFORE charging it.
func test_you_cannot_pay_a_story_point_you_do_not_have() -> void:
	var c: Resource = _campaign(0)
	DepartureObligation.record(c, "c2", "Rell", true)
	assert_bool(DepartureObligation.can_pay(c)).is_false()

	var receipt: Dictionary = DepartureObligation.resolve_on_departure(c, false)
	assert_int(int(c.story_points)).override_failure_message(
		"story points must never go negative").is_equal(0)
	assert_int(int(receipt.get("paid", 0))).override_failure_message(
		"the receipt claimed a payment that the balance shows never happened — "
		+ "this is the 'Paid the cost' lie from the device").is_equal(0)
	assert_array(_crew_ids(c)).override_failure_message(
		"with no story point to pay, p.82 says this crew member stays behind. "
		+ "Keeping them is the free-lunch bug.").not_contains(["c2"])


func test_declining_to_pay_leaves_the_crew_member_behind() -> void:
	var c: Resource = _campaign(5)
	DepartureObligation.record(c, "c2", "Rell", false)
	DepartureObligation.resolve_on_departure(c, false)
	assert_int(int(c.story_points)).override_failure_message(
		"declining must not spend a story point").is_equal(5)
	assert_array(_crew_ids(c)).not_contains(["c2"])


# ── rule 4: "you can keep their equipment, though" ───────────────────────────

## The book hands the player the departing member's gear. The old path removed
## the member from the roster and their Character.equipment went with them.
func test_a_departing_crew_member_leaves_their_equipment_behind() -> void:
	var c: Resource = _campaign(0)
	DepartureObligation.record(c, "c2", "Rell", true)
	DepartureObligation.resolve_on_departure(c, false)

	assert_array(_crew_ids(c)).not_contains(["c2"])
	assert_array(_stash_ids(c)).override_failure_message(
		"p.82: 'If they do, you can keep their equipment, though.' Both items "
		+ "should be in the ship stash, not deleted with the character"
		).contains(["itm_blade", "itm_rifle"])


## "One item, one home" — the gear must MOVE, not be copied. A departing member
## whose items are in the stash AND still on a sheet duplicates the cards.
func test_the_equipment_moves_rather_than_being_copied() -> void:
	var c: Resource = _campaign(0)
	DepartureObligation.record(c, "c2", "Rell", true)
	DepartureObligation.resolve_on_departure(c, false)
	var stash: Array = _stash_ids(c)
	assert_int(stash.size()).override_failure_message(
		"expected exactly the 2 items the departing member carried, got %d — "
		% stash.size() + "a duplicate means the transfer copied instead of moved"
		).is_equal(2)


# ── rule 3: "unless it is being Invaded" ─────────────────────────────────────

## p.82's exemption, which in practice is the p.69 flee-the-invasion departure:
## nobody pays and nobody stays behind.
func test_an_invaded_world_waives_the_obligation_entirely() -> void:
	var c: Resource = _campaign(2)
	DepartureObligation.record(c, "c2", "Rell", true)
	var receipt: Dictionary = DepartureObligation.resolve_on_departure(c, true)

	assert_bool(bool(receipt.get("waived", false))).is_true()
	assert_int(int(c.story_points)).override_failure_message(
		"the Invasion exemption means no story point is spent").is_equal(2)
	assert_array(_crew_ids(c)).override_failure_message(
		"nobody stays behind on a world the crew is fleeing").contains(["c2"])
	assert_bool(DepartureObligation.has_pending(c)).is_false()


# ── bookkeeping the old path got wrong ───────────────────────────────────────

## `CrewTaskComponent._remove_crew_member()` called `members.remove_at(i)` on the
## live array, bypassing `FiveParsecsCampaignCore.remove_crew_member()` — the
## chokepoint that exists for exactly this and rebuilds `_crew_id_index`. A stale
## index is a SILENT wrong-member lookup: get_crew_member_by_id()'s own docblock
## records this same bug shifting World Phase task XP onto the wrong character.
func test_removal_leaves_the_crew_id_index_consistent() -> void:
	var c: Resource = _campaign(0)
	DepartureObligation.record(c, "c2", "Rell", true)
	DepartureObligation.resolve_on_departure(c, false)

	assert_object(c.get_crew_member_by_id("c2")).override_failure_message(
		"a removed member must not still resolve by id").is_null()
	var captain = c.get_crew_member_by_id("c1")
	assert_object(captain).override_failure_message(
		"the surviving member must still resolve — a stale index returns the "
		+ "wrong member or nothing at all").is_not_null()
	assert_str(str(captain.get("character_name", ""))).is_equal("Vance")


## Rolling the result twice for the same person does not make them leave twice.
func test_the_same_crew_member_cannot_owe_twice() -> void:
	var c: Resource = _campaign(5)
	DepartureObligation.record(c, "c2", "Rell", true)
	DepartureObligation.record(c, "c2", "Rell", true)
	assert_int(DepartureObligation.pending(c).size()).is_equal(1)
	DepartureObligation.resolve_on_departure(c, false)
	assert_int(int(c.story_points)).override_failure_message(
		"one obligation, one story point").is_equal(4)


## Core Rules p.65 — Insanity disables story points ENTIRELY, none earned and
## none spent. Such a crew simply cannot meet p.82's price, so the member stays
## behind. Caught by mirroring TravelEventResolver._add_story_points, which
## carries the same gate for the same reason: a rule enforced on one of two
## write paths is the shape this whole audit exists to remove.
func test_an_insanity_campaign_cannot_pay_and_loses_the_crew_member() -> void:
	var c: Resource = _campaign(3)
	c.difficulty = GlobalEnums.DifficultyLevel.INSANITY
	DepartureObligation.record(c, "c2", "Rell", true)
	assert_bool(DepartureObligation.can_pay(c)).override_failure_message(
		"p.65 disables story points entirely on Insanity — nothing can be spent"
		).is_false()
	DepartureObligation.resolve_on_departure(c, false)
	assert_array(_crew_ids(c)).not_contains(["c2"])
	assert_array(_stash_ids(c)).override_failure_message(
		"they still leave their gear behind").contains(["itm_blade"])


## The empty-container trap: a fresh campaign's progress_data is legitimately
## empty, and treating that as "no campaign" is how salvage was silently disabled
## for every new game. Guard on the OWNER.
func test_a_fresh_campaign_with_empty_progress_data_still_works() -> void:
	var c: Resource = _campaign(2)
	c.progress_data = {}
	assert_bool(DepartureObligation.record(c, "c2", "Rell", true)
		).override_failure_message(
		"an empty progress_data is a LEGAL state, not an absent campaign"
		).is_true()
	assert_bool(DepartureObligation.has_pending(c)).is_true()
