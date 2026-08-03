extends GdUnitTestSuite
## Advanced Training, post-battle Step 10 (Core Rules pp.124-125).
##
## WHAT WAS BROKEN — the step was pure theatre. The player picked a course,
## pressed Roll, read "2D6 Roll: 9 - Training APPROVED!" and "<name> completed
## pilot training" in the log, and:
##   - no XP was spent
##   - no credits were spent
##   - the 1-credit application fee was displayed, gated on, and never charged
##   - no training was recorded on the character
## On top of that:
##   - p.124's "paid using unspent XP, credits or any combination thereof" was
##     XP-only, so the BOOK'S OWN worked example (8 XP + 12 credits for a cost-20
##     course) was impossible and training was unaffordable until very late
##   - "Each crew member can only ever be trained in a single course" read
##     `character.training`, a property Character does not have, so it never held
##   - "Only one attempt is permitted per campaign turn" was unenforced
##   - "Bots ... must be paid in credits exclusively" was unimplemented
##   - an eighth course, "Engineer", was fabricated (p.125 has seven)
##   - the caller filtered crew with `is Resource`, so on a LOADED save (where
##     members are Dictionaries) the character list was empty

const DialogScene = preload(
	"res://src/ui/components/postbattle/TrainingSelectionDialog.tscn")

var _dlg

func before_test() -> void:
	_dlg = auto_free(DialogScene.instantiate())
	add_child(_dlg)

func _crew_member(overrides: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {
		"character_name": "Kaya",
		"experience": 0,
		"acquired_training": [],
		"is_bot": false,
		"species_id": "human",
		"character_class": "soldier",
	}
	m.merge(overrides, true)
	return m

# ── p.125: the course list ─────────────────────────────────────────────────

## Seven courses, and the costs are the book's.
func test_the_seven_courses_match_the_book() -> void:
	var expected := {
		"pilot": 20, "mechanic": 15, "medical": 20, "merchant": 10,
		"security": 10, "broker": 15, "bot_tech": 10,
	}
	assert_int(_dlg.TRAINING_TYPES.size()).is_equal(7)
	for key in expected:
		assert_bool(_dlg.TRAINING_TYPES.has(key)).override_failure_message(
			"missing p.125 course '%s'" % key).is_true()
		assert_int(int(_dlg.TRAINING_TYPES[key]["cost"])).is_equal(expected[key])

## "Engineer" is a character CLASS mentioned inside the Mechanic entry, not a
## course. It was an invented eighth row.
func test_the_fabricated_engineer_course_is_gone() -> void:
	assert_bool(_dlg.TRAINING_TYPES.has("engineer")).is_false()

# ── p.124: "unspent XP, credits or any combination thereof" ────────────────

## The book's worked example, verbatim: "I want to send a crew member to get
## Pilot Training with a cost of 20. The character has 8 unspent XP I can use,
## so I'd have to pay the rest as an additional 12 credits."
func test_the_books_worked_example_is_affordable() -> void:
	# 12 for the course + 1 for the application fee.
	_dlg.setup([_crew_member({"experience": 8})], 13)
	var plan: Dictionary = _dlg._payment_plan(_dlg.available_crew[0], "pilot")
	assert_int(int(plan["cost"])).is_equal(20)
	assert_int(int(plan["xp_spent"])).is_equal(8)
	assert_int(int(plan["credits_spent"])).is_equal(12)
	assert_bool(plan["affordable"]).is_true()

## One credit short — the fee must still be reserved, not double-spent.
func test_the_application_fee_is_reserved_out_of_the_course_budget() -> void:
	_dlg.setup([_crew_member({"experience": 8})], 12)
	var plan: Dictionary = _dlg._payment_plan(_dlg.available_crew[0], "pilot")
	assert_bool(plan["affordable"]).is_false()

## Enough XP alone pays the whole course.
func test_full_xp_payment_costs_no_credits() -> void:
	_dlg.setup([_crew_member({"experience": 25})], 1)
	var plan: Dictionary = _dlg._payment_plan(_dlg.available_crew[0], "pilot")
	assert_int(int(plan["xp_spent"])).is_equal(20)
	assert_int(int(plan["credits_spent"])).is_equal(0)
	assert_bool(plan["affordable"]).is_true()

## p.124: "Bots can have a training module installed, but the cost must be paid
## in credits exclusively." A Bot with plenty of XP still pays full credits.
func test_a_bot_pays_in_credits_only() -> void:
	_dlg.setup([_crew_member({"experience": 40, "is_bot": true})], 21)
	var plan: Dictionary = _dlg._payment_plan(_dlg.available_crew[0], "pilot")
	assert_int(int(plan["xp_spent"])).is_equal(0)
	assert_int(int(plan["credits_spent"])).is_equal(20)
	assert_bool(plan["affordable"]).is_true()

func test_a_bot_without_credits_cannot_train() -> void:
	_dlg.setup([_crew_member({"experience": 40, "is_bot": true})], 5)
	assert_bool(_dlg._payment_plan(_dlg.available_crew[0], "pilot")["affordable"]).is_false()

# ── p.125 per-character cost modifiers ─────────────────────────────────────

## "Ferals can obtain this training at -2 Cost" (Security training only).
func test_ferals_pay_two_less_for_security_training() -> void:
	var feral: Dictionary = _crew_member({"species_id": "feral"})
	var human: Dictionary = _crew_member()
	assert_int(_dlg._course_cost_for(feral, "security")).is_equal(8)
	assert_int(_dlg._course_cost_for(human, "security")).is_equal(10)
	# ...and only for that course.
	assert_int(_dlg._course_cost_for(feral, "pilot")).is_equal(20)

## "Engineers count any XP spent as double value for obtaining this" (Mechanic).
func test_engineers_get_double_xp_value_on_mechanic_training() -> void:
	_dlg.setup([_crew_member({"experience": 8, "character_class": "engineer"})], 21)
	var plan: Dictionary = _dlg._payment_plan(_dlg.available_crew[0], "mechanic")
	# 8 XP counts as 16 against a cost of 15, so no credits are owed.
	assert_int(int(plan["credits_spent"])).is_equal(0)
	# ...and only for that course: 8 XP is 8 against Pilot's 20.
	var pilot: Dictionary = _dlg._payment_plan(_dlg.available_crew[0], "pilot")
	assert_int(int(pilot["credits_spent"])).is_equal(12)

# ── p.124: one course per crew member, read off the right property ─────────

## The canonical field is `acquired_training`. The old check read `training`,
## which Character does not have, so this always saw an empty list.
func test_an_already_trained_character_is_recognised() -> void:
	var trained: Dictionary = _crew_member({"acquired_training": ["pilot"]})
	assert_array(_dlg._char_training(trained)).contains(["pilot"])
	assert_array(_dlg._char_training(_crew_member())).is_empty()

# ── The application actually happens ───────────────────────────────────────

## Spends the XP and records the course on the character.
func test_applying_training_spends_xp_and_records_the_course() -> void:
	var member: Dictionary = _crew_member({"experience": 25})
	_dlg.setup([member], 5)
	_dlg.selected_character = _dlg.available_crew[0]
	_dlg.selected_training_type = "pilot"
	_dlg._apply_training(_dlg._payment_plan(_dlg.selected_character, "pilot"))
	assert_int(int(_dlg.available_crew[0]["experience"])).is_equal(5)
	assert_array(_dlg.available_crew[0]["acquired_training"]).contains(["pilot"])

## A Dictionary-shaped crew member is the LOADED-SAVE shape, and it must be
## visible in the first place — the caller used to filter these out entirely.
func test_dictionary_crew_members_are_readable() -> void:
	_dlg.setup([_crew_member({"character_name": "Vale", "experience": 12})], 5)
	assert_str(_dlg._char_name(_dlg.available_crew[0])).is_equal("Vale")
	assert_int(_dlg._char_xp(_dlg.available_crew[0])).is_equal(12)
