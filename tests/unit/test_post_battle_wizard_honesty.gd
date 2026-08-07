extends GdUnitTestSuite
## The post-battle wizard must not tell the player something happened that did not.
##
## Two defects, both visible to a tester in the first session.
##
## 1. STEP 9 SOLD A MECHANIC THAT DOES NOT EXIST. "Roll Advancement" rolled a D6
##    and printed "Major advancement - gain 2 skill points!" on a 6, "gain 1
##    skill point" on 4-5, "No advancement this time" otherwise — then mutated
##    NOTHING. Five Parsecs has no advancement roll and no "skill point"
##    currency. Core Rules p.123 gives fixed XP COSTS per ability with per-ability
##    maxima, spent by the player. So after every battle the wizard reported an
##    advancement in an invented currency while the character sheet never moved.
##    Project policy on a mechanic in neither book is removal, not repair.
##
## 2. THE EXPANDED MISSIONS BRIEFING PRINTED BARE HEADINGS. "OVERVIEW: ",
##    "SPECIFIC OBJECTIVE: ", "TIME CONSTRAINT: ", "PATRON CONDITION: " and
##    "EXTRACTION: " rendered with nothing after the colon on every job, because
##    the rows in data/compendium/missions_expanded.json carry `id` and
##    `instruction` and have NO `name` key — so every .get("name", "") was "".
##
## gdUnit4 v6.0.3 compatible.

const AdvancementService = preload("res://src/core/services/CharacterAdvancementService.gd")
const AdvancementConstants = preload("res://src/core/systems/CharacterAdvancementConstants.gd")

const WIZARD_SRC := "res://src/ui/screens/postbattle/PostBattleSequence.gd"
const JOB_OFFER_SRC := "res://src/ui/screens/world/components/JobOfferComponent.gd"
const EXPANDED_JSON := "res://data/compendium/missions_expanded.json"


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


# --- 1. The fabricated advancement roll is gone -------------------------------

func test_the_fabricated_advancement_roll_is_gone() -> void:
	var src: String = _src(WIZARD_SRC)
	# The docstring explaining the removal legitimately contains these words, so
	# assert on the CODE constructs rather than the prose.
	assert_bool(src.contains("func _interpret_advancement_roll")).override_failure_message(
		"the D6 advancement interpreter is back — there is no advancement roll in "
		+ "Five Parsecs, and it awarded 'skill points', which do not exist"
	).is_false()
	assert_bool(src.contains("func _on_experience_roll")).override_failure_message(
		"the advancement roll handler is back"
	).is_false()
	# Assert the ASSIGNMENT, not the bare phrase: the docstring above explains the
	# removal and quotes the old button text, so a naive contains() matches the
	# explanation and fails a file that is actually correct.
	assert_bool(src.contains("roll_button.text = \"Roll Advancement\"")).override_failure_message(
		"the 'Roll Advancement' button is back").is_false()


func test_step_nine_spends_xp_through_the_real_service() -> void:
	var src: String = _src(WIZARD_SRC)
	assert_bool(src.contains("AdvancementServiceClass.get_available_advancements")) \
		.override_failure_message(
			"step 9 does not offer the p.123 Ability Increase Table").is_true()
	assert_bool(src.contains("AdvancementServiceClass.advance_stat")) \
		.override_failure_message(
			"step 9 does not actually spend the XP — the same defect as the roll it "
			+ "replaced, just quieter").is_true()


# --- The p.123 costs the wizard now charges -----------------------------------

func test_the_ability_increase_costs_match_the_book() -> void:
	# Core Rules p.123 Ability Increase Table.
	var expected := {
		"reactions": 7, "combat_skill": 7, "speed": 5,
		"savvy": 5, "toughness": 6, "luck": 10,
	}
	for stat in expected:
		assert_int(AdvancementConstants.get_advancement_cost(stat)) \
			.override_failure_message("p.123 cost for %s" % stat) \
			.is_equal(int(expected[stat]))


func test_spending_xp_raises_the_stat_and_deducts_the_cost() -> void:
	var character := {
		"character_id": "c1", "character_name": "Kaya",
		"reactions": 2, "combat_skill": 1, "speed": 4,
		"savvy": 1, "toughness": 3, "luck": 0,
		"experience": 6, "origin": "human",
	}
	var before_speed: int = int(character["speed"])
	var result: Dictionary = AdvancementService.advance_stat(character, "speed")

	assert_bool(result.get("success", false)).override_failure_message(
		"6 XP should buy a 5-XP Speed increase. Result: %s" % str(result)).is_true()
	assert_int(int(character["speed"])).override_failure_message(
		"advance_stat must mutate the character dictionary in place — the wizard "
		+ "relies on that to write through to the live crew entry"
	).is_equal(before_speed + 1)
	assert_int(int(character["experience"])).is_equal(1)


func test_an_unaffordable_ability_is_refused_not_silently_granted() -> void:
	var character := {
		"character_id": "c2", "character_name": "Rho",
		"reactions": 2, "combat_skill": 1, "speed": 4,
		"savvy": 1, "toughness": 3, "luck": 0,
		"experience": 1, "origin": "human",
	}
	var result: Dictionary = AdvancementService.advance_stat(character, "luck")
	assert_bool(result.get("success", true)).is_false()
	assert_int(int(character["experience"])).override_failure_message(
		"a refused advancement must not charge XP").is_equal(1)


func test_only_affordable_advancements_are_offered() -> void:
	var character := {
		"character_id": "c3", "character_name": "Zed",
		"reactions": 2, "combat_skill": 1, "speed": 4,
		"savvy": 1, "toughness": 3, "luck": 0,
		"experience": 5, "origin": "human",
	}
	for opt in AdvancementService.get_available_advancements(character):
		assert_int(int(opt.get("cost", 999))).override_failure_message(
			"offered an advancement costing more XP than the character has — the "
			+ "picker would let the player choose it and be refused"
		).is_less_equal(5)


# --- 2. The briefing renders the book's line, not an empty heading ------------

func test_the_expanded_mission_rows_have_no_name_key() -> void:
	# This is WHY the headings were empty, and it is the thing that would make
	# them empty again if someone re-introduced a .get("name") read.
	var f := FileAccess.open(EXPANDED_JSON, FileAccess.READ)
	assert_object(f).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_bool(parsed is Dictionary).is_true()

	for table in ["objective_overview", "specific_objectives", "time_constraints",
			"patron_conditions", "extraction"]:
		var rows: Array = parsed.get(table, [])
		assert_int(rows.size()).override_failure_message(
			"%s table is empty" % table).is_greater(0)
		for row in rows:
			assert_bool(row.has("instruction")).override_failure_message(
				"%s row has no `instruction` — that IS the display text" % table
			).is_true()
			assert_str(str(row.get("instruction", "")).strip_edges()) \
				.override_failure_message("%s row has a blank instruction" % table) \
				.is_not_empty()


func test_the_briefing_renders_instructions_not_bare_headings() -> void:
	var src: String = _src(JOB_OFFER_SRC)
	for heading in ["\"OVERVIEW: %s", "\"SPECIFIC OBJECTIVE: %s",
			"\"TIME CONSTRAINT: %s", "\"PATRON CONDITION: %s", "\"EXTRACTION: %s"]:
		assert_bool(src.contains(heading)).override_failure_message(
			"the briefing is formatting a heading with a value the table does not "
			+ "have (%s) — it will print the label and nothing else" % heading
		).is_false()
	assert_bool(src.contains("dlc_objective_instruction")).override_failure_message(
		"the briefing no longer renders the book's instruction line").is_true()


# --- 3. The wizard must not let the player roll loot the backend already rolled ---
#
# Core Rules p.120 Step 7: ONE roll on the Loot Table per battle (3 at a Quest
# finale, 0 after an Invasion). Two things roll it: the backend orchestrator
# (PostBattlePhase step 7 -> LootProcessor) and the wizard's own "Roll on Loot
# Table (D100)" button. Both run on the live campaign path -- CampaignTurnController
# calls start_phase(POST_MISSION), which shows the wizard on `phase_changed` and
# THEN runs all 14 backend steps in _execute_phase_start().
#
# What stops the double roll is an ordering contract, not a guard on the roll
# itself: PostBattlePhase emits post_battle_substep_changed(GATHER_LOOT) BEFORE
# loot_gathered, the wizard maps substep -> `current_step = substep - 1` = 6, and
# _on_backend_loot_generated's `if current_step == 6` arm then disables the button
# and auto-satisfies the inline roll. Break any link -- reorder the emits, renumber
# PostBattleSubPhase, reorder the wizard's step list -- and the button is live when
# the player arrives, for two independent Loot results on every battle.
#
# These assertions are the links. They are cheap and they are the only thing
# standing between the book's one roll and two.

const PB_PHASE_SRC := "res://src/core/campaign/phases/PostBattlePhase.gd"

func test_gather_loot_substep_maps_to_the_wizard_loot_step() -> void:
	# The wizard's step list is built in _initialize_steps(); "7. Gather the Loot"
	# must sit at index GATHER_LOOT - 1, because that is the arithmetic
	# _on_backend_substep_changed does.
	var expected_index: int = GlobalEnums.PostBattleSubPhase.GATHER_LOOT - 1
	assert_int(expected_index).override_failure_message(
		"PostBattleSubPhase.GATHER_LOOT moved; the wizard's `substep - 1` mapping"
		+ " no longer lands on the loot card").is_equal(6)

	var src: String = _src(WIZARD_SRC)
	var step_names: PackedStringArray = []
	for line in src.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("{\"name\":"):
			var start: int = t.find("\"", 8) + 1
			step_names.append(t.substr(start, t.find("\"", start) - start))
	assert_int(step_names.size()).override_failure_message(
		"could not read the wizard step list out of %s" % WIZARD_SRC).is_greater(6)
	assert_str(step_names[expected_index]).override_failure_message(
		"wizard step %d is '%s', not the loot step — the backend will sync the UI"
		% [expected_index, step_names[expected_index]]
		+ " to the wrong card and leave the loot button live"
	).contains("Gather the Loot")


func test_backend_announces_the_loot_substep_before_it_emits_the_loot() -> void:
	var src: String = _src(PB_PHASE_SRC)
	var substep_at: int = src.find("PostBattleSubPhase.GATHER_LOOT")
	var emit_at: int = src.find("loot_gathered.emit")
	assert_int(substep_at).override_failure_message(
		"PostBattlePhase no longer announces the GATHER_LOOT substep").is_greater(-1)
	assert_int(emit_at).override_failure_message(
		"PostBattlePhase no longer emits loot_gathered").is_greater(-1)
	assert_bool(substep_at < emit_at).override_failure_message(
		"loot_gathered is emitted BEFORE the GATHER_LOOT substep is announced, so"
		+ " the wizard is still on an earlier card when the loot lands: its"
		+ " `current_step == 6` arm never runs and the manual roll button stays"
		+ " enabled. Two Loot Table results per battle (Core Rules p.120: one)."
	).is_true()


func test_the_wizard_disables_its_manual_roll_when_the_backend_rolls() -> void:
	var src: String = _src(WIZARD_SRC)
	assert_bool(src.contains("func _on_backend_loot_generated")).override_failure_message(
		"the wizard no longer listens for backend loot").is_true()
	# The handler must both satisfy the inline-roll gate and kill the button;
	# doing only the first leaves a live button the player will press.
	var handler_start: int = src.find("func _on_backend_loot_generated")
	var handler_end: int = src.find("\nfunc ", handler_start + 10)
	var body: String = src.substr(handler_start, handler_end - handler_start)
	assert_bool(body.contains("_increment_inline_roll")).override_failure_message(
		"backend loot no longer satisfies the step's inline-roll gate").is_true()
	assert_bool(body.contains("disabled = true")).override_failure_message(
		"backend loot no longer disables the manual 'Roll on Loot Table' button —"
		+ " the player can roll a second, independent result").is_true()
