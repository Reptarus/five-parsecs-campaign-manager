extends GdUnitTestSuite
## Patrons and Rivals — audit rows 205, 228, 229.
##
## 205  p.77 Find a Patron GATES whether a Patron job exists at all: "If the
##      result is a 5 or higher, you've found a Patron to hire you for a job",
##      and p.83 opens "IF YOU RECEIVED A JOB OFFER FROM A PATRON, you need to
##      determine the details of the job." JobOfferComponent handed EVERY Patron
##      on the list a fresh job every campaign turn with no roll anywhere, so the
##      task gated nothing and a 4-5 contact list was a permanent wall of work.
##      The task half was wrong too: both branches created NEW Patrons, when
##      p.77 says "If one job is offered, it will always be a random, EXISTING
##      Patron."
##
## 228  p.85 Step 6 — "FIRST, you must check that your Rivals give the
##      opportunity to choose your battle! ... This will prevent you from doing
##      whatever you had wanted to do this campaign turn." The check ran ~160
##      lines AFTER the enemy force, the objective and the Notable Sight had been
##      rolled off the chosen job's tables, then merely overstamped
##      `mission_source`. A Rival ambush was a Patron job wearing a Rival's name,
##      Danger Pay included. Plus p.92: "Once a Rival has been established, they
##      will always be the same type" — the type was re-rolled every encounter.
##
## 229  p.119 Step 1 — the Rival removal roll keyed off scanning
##      `defeated_enemies` for an `is_rival` stamp, i.e. it asked "did we KILL
##      any of them". At LOG_ONLY (the DEFAULT tier) the player tracks casualties
##      on their own table and the app's list is empty, and p.118 Morale can rout
##      a force with zero kills. Either way `fought_existing_rival` was false, so
##      the removal roll never happened AND execution fell through to the
##      new-Rival branch — beating a Rival could hand you a second one.
##
## gdUnit4 v6.0.3 compatible.

const EncounterRef := preload("res://src/core/campaign/RivalEncounterCheck.gd")

const CTC_SRC := "res://src/ui/screens/campaign/CampaignTurnController.gd"
const RESOLVER_SRC := "res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd"
const JOB_SRC := "res://src/ui/screens/world/components/JobOfferComponent.gd"
const TASK_SRC := "res://src/ui/screens/world/components/CrewTaskComponent.gd"


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var t: String = f.get_as_text()
	f.close()
	return t


## Comment-stripped. Every ordering assertion below would otherwise match the
## comment that explains the ordering.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value
	return g


# ── 228: the Rival carries its own type (p.92) ──────────────────────────────

func test_rival_type_rides_along_with_the_encounter() -> void:
	## Without this the battle re-rolled the encounter table, so the Unity troops
	## you made an enemy of last month could turn up as Roving Threats.
	var rivals: Array = [{
		"id": "rival_unity_1", "name": "Unity Vendetta", "type": "Unity Grunts",
	}]
	var found := false
	for s in range(1, 60):
		var r: Dictionary = EncounterRef.check(rivals, 0, _rng(s))
		if not bool(r.get("has_encounter", false)):
			continue
		found = true
		assert_str(str(r.get("rival_type", ""))).is_equal("Unity Grunts")
		assert_str(str(r.get("rival_id", ""))).is_equal("rival_unity_1")
	assert_bool(found).override_failure_message("no encounter in 59 seeds").is_true()


func test_a_legacy_string_rival_pins_no_type() -> void:
	## The canonical list is a MIXED array — older entries are bare Strings with
	## no recorded type. "" is the correct answer, not a guess: the generator
	## reads an empty preset as "roll normally", so a legacy Rival keeps today's
	## behaviour instead of being pinned to an invented type.
	assert_str(EncounterRef.rival_type_of("Some Old Rival")).is_equal("")
	assert_str(EncounterRef.rival_type_of({"name": "X"})).is_equal("")
	assert_str(EncounterRef.rival_type_of({"type": "Gangers"})).is_equal("Gangers")
	assert_str(EncounterRef.rival_type_of({"enemy_type": "Gangers"})).is_equal("Gangers")


func test_elite_flag_rides_along() -> void:
	var elite: Array = [{"id": "r", "name": "R", "type": "T", "is_elite": true}]
	for s in range(1, 40):
		var r: Dictionary = EncounterRef.check(elite, 0, _rng(s))
		if bool(r.get("has_encounter", false)):
			assert_bool(bool(r.get("is_elite", false))).is_true()
			return
	fail("no encounter in 39 seeds")


# ── 228: the check runs FIRST, and the ambush replaces the job ──────────────

func test_the_rival_check_precedes_mission_generation() -> void:
	## p.85's word "First" IS the mechanic. Asserted by ORDER in the source,
	## because that is exactly what was wrong — both halves existed and were
	## correct, and only their sequence made the rule fail.
	var src: String = _code_only(CTC_SRC)
	var check_call: int = src.find("_check_rival_encounter_backend(current_planet_id, current_turn)")
	var enemy_gen: int = src.find("enemy_gen.generate_enemies_as_dicts(")
	var objective_roll: int = src.find("mtm.roll_mission_objective(")
	var sight_roll: int = src.find("mtm.roll_notable_sight(")

	assert_int(check_call).override_failure_message("Rival check call not found").is_greater(0)
	assert_int(check_call).override_failure_message(
		"the Rival check runs AFTER the enemy force is generated — the ambush"
		+ " would fight the displaced job's enemy").is_less(enemy_gen)
	assert_int(check_call).override_failure_message(
		"the Rival check runs AFTER the objective is rolled — the ambush would"
		+ " use the Patron/Quest objective table").is_less(objective_roll)
	assert_int(check_call).override_failure_message(
		"the Rival check runs AFTER the Notable Sight is rolled — p.89 uses a"
		+ " different column per mission type").is_less(sight_roll)
	# It must not roll twice in one turn — but the guarantee is now in the CALLEE,
	# not in a call-site count.
	#
	# Sep 3 2026 added a SECOND legitimate caller: errata v1.06 "Lay Low" has to
	# "check for Rival attacks normally" BEFORE the player pays to stay in town,
	# and the battle path then calls it again. Counting call sites was always a
	# proxy for the real property, and it is the weaker one — the T9-50 lesson is
	# that a fix ordered against SOME callers is not a fix, so
	# `_check_rival_encounter_backend()` stamps the turn and early-returns on a
	# repeat. That holds however many callers there are.
	assert_str(src).override_failure_message(
		"the Rival check has no per-turn guard, so two callers would roll it twice"
		+ " and an ambushed crew could be told it was clear"
	).contains('battle_results["rival_check_turn"] = _turn_number')
	assert_str(src).override_failure_message(
		"the guard must EARLY-RETURN on a repeat, not merely record the turn"
	).contains('if checked_turn == _turn_number and battle_results.has("rival_encounter"):')
	# Both callers are accounted for: the battle path and the Lay Low path.
	assert_int(src.count("_check_rival_encounter_backend(")).override_failure_message(
		"unexpected number of Rival-check references — a new caller must be"
		+ " deliberate, and must rely on the callee guard above"
	).is_equal(3)  # 1 def + battle path + Lay Low


func test_the_ambush_clears_the_displaced_jobs_payload() -> void:
	## p.85: "This will prevent you from doing whatever you had wanted to do this
	## campaign turn." Danger Pay is the sharpest case — PaymentProcessor reads it
	## straight off the battle result, so leaving it behind pays a Patron's bonus
	## for a grudge match the crew never took a job for.
	var src: String = _code_only(CTC_SRC)
	assert_bool(src.contains("func _apply_rival_ambush_override")).is_true()
	for key in ["\"danger_pay\"", "\"benefits\"", "\"hazards\"", "\"conditions\"",
			"\"objective_details\"", "\"notable_sight\"", "\"time_frame\"",
			"\"patron_id\""]:
		assert_bool(src.contains(key)) \
			.override_failure_message(
				"the ambush override does not clear %s from the displaced job" % key) \
			.is_true()
	assert_bool(src.contains("mission_data[\"mission_source\"] = \"rival\"")).is_true()


# ── 229: the removal roll reads the MISSION, not the corpses ────────────────

func test_rival_identity_comes_from_the_mission_not_the_kill_list() -> void:
	var src: String = _code_only(RESOLVER_SRC)
	assert_bool(src.contains("ctx.battle_result.get(\"is_rival_mission\", false)")) \
		.override_failure_message(
			"process_rival_status must decide it fought a Rival from the mission."
			+ " Deriving it from defeated_enemies asks 'did we kill any', which is"
			+ " false at LOG_ONLY and after a morale rout.").is_true()
	assert_bool(src.contains("var mission_rival_id: String = str(ctx.battle_result.get(\"rival_id\", \"\"))")) \
		.is_true()
	# The removal roll must no longer be nested inside the corpse loop.
	var loop_pos: int = src.find("for enemy in ctx.defeated_enemies:")
	var roll_pos: int = src.find("_roll_rival_removal(ctx, rival_id)")
	assert_int(roll_pos).override_failure_message("removal roll missing").is_greater(0)
	assert_int(roll_pos).override_failure_message(
		"the removal roll is still inside the defeated-enemies loop").is_greater(loop_pos)
	assert_bool(src.contains("if held_field:\n\t\tfor rival_id in rival_ids:")) \
		.override_failure_message(
			"the removal roll should iterate collected rival ids under a single"
			+ " held_field gate").is_true()


func test_a_rival_battle_cannot_also_mint_a_new_rival() -> void:
	## The compounding half of 229: with `fought_existing_rival` false, execution
	## reached `held_field and not fought_existing_rival` and rolled for a NEW
	## Rival — so beating one could give you two.
	var src: String = _code_only(RESOLVER_SRC)
	var flag_from_mission: int = src.find("var fought_existing_rival: bool = bool(")
	var new_rival_branch: int = src.find("if held_field and not fought_existing_rival")
	assert_int(flag_from_mission).is_greater(0)
	assert_int(new_rival_branch).is_greater(0)
	assert_int(flag_from_mission).override_failure_message(
		"fought_existing_rival must be established before the new-Rival branch") \
		.is_less(new_rival_branch)


# ── 205: the p.77 gate ──────────────────────────────────────────────────────

func test_job_offers_are_gated_on_the_find_a_patron_roll() -> void:
	var src: String = _code_only(JOB_SRC)
	# THE CALL SITE, not the bare name. The first version of this assertion used
	# `src.contains("_consume_patron_offers_owed()")`, which the function's own
	# DEFINITION satisfies — so replacing the call with `var owed: int = 99`
	# (i.e. removing the gate entirely) still passed. A test that cannot fail is
	# not evidence; the detection revert is what exposed it.
	assert_bool(src.contains("var owed: int = _consume_patron_offers_owed()")) \
		.override_failure_message("JobOfferComponent does not consult the p.77 roll") \
		.is_true()
	# And `owed` must actually BOUND the offers generated, not just be computed.
	assert_bool(src.contains("for i in range(mini(owed, eligible_patrons.size())):")) \
		.override_failure_message(
			"the p.77 entitlement is read but does not limit how many Patron jobs"
			+ " are generated").is_true()
	# The unconditional per-Patron job loop must be gone.
	assert_bool(src.contains("for patron in patrons:\n\t\tvar p_data: Dictionary = patron if patron is Dictionary else {\"patron_name\": str(patron)}\n\t\tvar pid: String = _patron_identity(p_data, str(p_data.get(\"patron_name\", \"\")))\n\t\tif pid in patrons_with_live_offers:\n\t\t\tcontinue\n\t\tvar patron_jobs")) \
		.override_failure_message(
			"every Patron is being handed a job again — the p.77 roll gates nothing") \
		.is_false()
	# "a RANDOM, existing Patron" — not first-in-list.
	assert_bool(src.contains("eligible_patrons.shuffle()")).is_true()


func test_the_opportunity_fallback_survives_the_gate() -> void:
	## p.85: "Carry out an Opportunity mission — ALWAYS AVAILABLE". This is what
	## makes gating Patron work safe instead of a soft-lock: a crew that finds no
	## Patron this turn still has a battle to fight.
	var src: String = _code_only(JOB_SRC)
	assert_bool(src.contains("if patron_offers.is_empty():")).is_true()
	assert_bool(src.contains("_generate_job_offers({}, location)")).is_true()


func test_the_entitlement_is_spent_not_merely_read() -> void:
	## The World Phase wizard allows back-navigation, so a counter that survived
	## reading would mint a fresh job on every re-entry — the same unlimited-work
	## bug, triggered differently.
	var src: String = _code_only(JOB_SRC)
	var fn: int = src.find("func _consume_patron_offers_owed")
	assert_int(fn).is_greater(0)
	var body: String = src.substr(fn, 700)
	assert_bool(body.contains("campaign.progress_data[\"patron_offers_owed\"] = 0")) \
		.override_failure_message("the entitlement is read without being cleared").is_true()


func test_five_plus_draws_an_existing_patron_and_six_plus_adds_one_new() -> void:
	## p.77: "If ONE job is offered, it will always be a random, EXISTING Patron.
	## If TWO jobs are offered, one will be a random, existing Patron, the other
	## will be from a NEW Patron." Both branches used to create new Patrons.
	var src: String = _code_only(TASK_SRC)
	assert_bool(src.contains("_grant_patron_job_offers(2)")).is_true()
	assert_bool(src.contains("_grant_patron_job_offers(1)")).is_true()
	var fn: int = src.find("func _grant_patron_job_offers")
	assert_int(fn).is_greater(0)
	var body: String = src.substr(fn, 1600)
	assert_bool(body.contains("if count >= 2:")).is_true()
	assert_bool(body.contains("new_patrons_needed = 1")).is_true()
	assert_bool(body.contains("patron_offers_owed")).is_true()


func test_gain_patron_table_results_add_a_contact_not_a_job() -> void:
	## The Trade/Exploration "gain a Patron" results grant a CONTACT. Routing them
	## through the p.77 job-offer path would hand out free jobs through the back
	## door and undo the gate — so they get their own helper.
	var src: String = _code_only(TASK_SRC)
	assert_bool(src.contains("func _add_patron_contact")).is_true()
	# 3 = the `func _add_patron_contact()` definition + the two GAIN_PATRON call
	# sites (the interactive event queue and the auto-resolve path). Counting the
	# bare name catches the definition too, which is why this is 3 and not 2.
	assert_int(src.count("_add_patron_contact()")).is_equal(3)
	assert_bool(src.contains("_generate_and_add_patron")) \
		.override_failure_message(
			"the old contact-adding function is back; it created a Patron for a"
			+ " 5+ roll, which p.77 says draws on an EXISTING one").is_false()
