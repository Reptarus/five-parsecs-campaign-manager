extends GdUnitTestSuite
## The Leader's +1 Luck — Core Rules p.24 (Crew Composition).
##
## BOOK, verbatim (PDF idx 23, printed folio 24):
##   "Once you have created all of your characters, pick one to be the Leader.
##    This character receives 1 Luck point and will never leave the crew through
##    random events, though they can certainly be slain. While you are free to
##    select a Bot as your Leader, they do not receive Luck if you do."
##
## WHAT THIS PINS (2026-09-04). `LuckSystem.apply_leader_luck_bonus()` existed,
## was cited to p.92 (wrong page), omitted the Bot clause entirely, and had ZERO
## CALLERS. `add_luck()` had exactly one caller — that dead function. No other
## site in src/ granted Leader Luck, so no crew in any campaign ever received it.
##
## Not to be confused with the two Luck grants that ARE live and are NOT this
## rule: CharacterGeneration.gd:799 is the HUMAN SPECIES Luck (p.15, every
## Human), and Character.gd:337 is spending XP on the Luck stat.

const LuckSystem = preload("res://src/core/systems/LuckSystem.gd")

const FinalizationRef = preload(
	"res://src/core/campaign/creation/CampaignFinalizationService.gd")


## Crew members are plain Dictionaries by the time finalization grants this, so
## the fixtures are Dictionaries — the shape the live code actually receives.
func _member(overrides: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {
		"character_name": "Leader", "is_captain": true,
		"luck": 0, "species_id": "human", "origin": "HUMAN", "is_bot": false,
	}
	m.merge(overrides, true)
	return m


# --- the grant ------------------------------------------------------------

func test_the_leader_receives_one_luck_point() -> void:
	var leader := _member({"luck": 0})
	assert_bool(LuckSystem.apply_leader_luck_bonus(leader)).is_true()
	assert_int(int(leader["luck"])).override_failure_message(
		"p.24: the Leader receives 1 Luck point"
	).is_equal(1)


func test_a_non_leader_receives_nothing() -> void:
	var grunt := _member({"is_captain": false, "luck": 0})
	assert_bool(LuckSystem.apply_leader_luck_bonus(grunt)).is_false()
	assert_int(int(grunt["luck"])).is_equal(0)


func test_a_human_leader_stacks_on_top_of_the_species_luck() -> void:
	# p.15 gives every Human a Luck point and is applied at generation, so a
	# Human Leader arrives here holding 1 and must end on 2. Humans are the one
	# type that "can exceed 1 point of Luck" (p.15), so the cap does not bite.
	var leader := _member({"luck": 1, "species_id": "human"})
	assert_bool(LuckSystem.apply_leader_luck_bonus(leader)).is_true()
	assert_int(int(leader["luck"])).is_equal(2)


# --- the Bot clause -------------------------------------------------------

func test_a_bot_leader_receives_no_luck() -> void:
	var bot := _member({"is_bot": true, "species_id": "bot", "origin": "BOT"})
	assert_bool(LuckSystem.apply_leader_luck_bonus(bot)).override_failure_message(
		"p.24: 'you are free to select a Bot as your Leader, they do not"
		+ " receive Luck if you do'"
	).is_false()
	assert_int(int(bot["luck"])).is_equal(0)


func test_a_bot_is_recognised_by_any_of_its_three_markers() -> void:
	# Saves in the wild carry the marker in different places, so all three must
	# deny the grant independently — a Bot recognised by only one spelling would
	# be handed Luck the book denies.
	for marker: Dictionary in [
		{"is_bot": true, "species_id": "", "origin": ""},
		{"is_bot": false, "species_id": "bot", "origin": ""},
		{"is_bot": false, "species_id": "", "origin": "BOT"},
	]:
		var bot := _member(marker)
		assert_bool(LuckSystem.apply_leader_luck_bonus(bot)).override_failure_message(
			"a Bot marked via %s was still granted Luck" % [marker]
		).is_false()
		assert_int(int(bot["luck"])).is_equal(0)


# --- species cap ----------------------------------------------------------

func test_a_non_human_leader_is_still_capped_at_one() -> void:
	# p.15: only Humans may exceed 1 point of Luck. A K'Erin Leader starts at 0
	# (no species Luck), so the grant takes them to exactly 1 — their cap.
	var leader := _member({"luck": 0, "species_id": "kerin", "origin": "KERIN"})
	assert_bool(LuckSystem.apply_leader_luck_bonus(leader)).is_true()
	assert_int(int(leader["luck"])).is_equal(1)


# --- dual shape -----------------------------------------------------------

func test_a_dictionary_member_does_not_abort_the_grant() -> void:
	# LuckSystem's helpers used `character.has_method("get")`, which on a
	# Dictionary is an INVALID CALL that unwinds the caller — so the grant would
	# have silently done nothing on exactly the shape finalization passes it.
	var leader: Dictionary = _member({"luck": 0})
	var granted: bool = LuckSystem.apply_leader_luck_bonus(leader)
	assert_bool(granted).override_failure_message(
		"a Dictionary crew member must be handled, not aborted on"
	).is_true()
	assert_int(int(leader["luck"])).is_equal(1)


# --- the wiring, which is the half that was missing ----------------------

func test_finalization_grants_the_bonus_to_the_captain() -> void:
	# The rule being correct was never the problem; having a caller was. Drive
	# the finalization helper over a real crew shape.
	var svc = FinalizationRef.new()
	var crew: Dictionary = {"members": [
		_member({"character_name": "Cap", "is_captain": true, "luck": 1}),
		_member({"character_name": "Grunt", "is_captain": false, "luck": 0}),
	]}
	svc._grant_leader_luck(crew)
	assert_int(int(crew["members"][0]["luck"])).override_failure_message(
		"finalization must grant the Leader their p.24 Luck point"
	).is_equal(2)
	assert_int(int(crew["members"][1]["luck"])).override_failure_message(
		"a non-captain must not receive it"
	).is_equal(0)


func test_finalization_grants_it_only_once_per_crew() -> void:
	# A malformed roster carrying two is_captain flags must not pay out twice.
	var svc = FinalizationRef.new()
	var crew: Dictionary = {"members": [
		_member({"character_name": "A", "is_captain": true, "luck": 0}),
		_member({"character_name": "B", "is_captain": true, "luck": 0}),
	]}
	svc._grant_leader_luck(crew)
	var total: int = int(crew["members"][0]["luck"]) + int(crew["members"][1]["luck"])
	assert_int(total).override_failure_message(
		"exactly one Luck point may be granted per crew"
	).is_equal(1)


func test_finalization_survives_a_crew_with_no_captain() -> void:
	var svc = FinalizationRef.new()
	var crew: Dictionary = {"members": [_member({"is_captain": false, "luck": 0})]}
	svc._grant_leader_luck(crew)
	assert_int(int(crew["members"][0]["luck"])).is_equal(0)
