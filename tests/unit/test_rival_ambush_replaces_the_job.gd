extends GdUnitTestSuite
## T9-44 (tablet, Aug 13 2026) — a Rival attack DECORATED a Patron job instead of
## replacing it.
##
## Core Rules p.85, World Step 6 "Choose Your Battle", verbatim:
##
##   "First, you must check that your Rivals give the opportunity to choose your
##    battle! ... If the roll is equal to or lower than the number of Rivals, one
##    of them has tracked you down, and you will have to fight them. THIS WILL
##    PREVENT YOU FROM DOING WHATEVER YOU HAD WANTED TO DO THIS CAMPAIGN TURN.
##    Quests and Rumors remain, but a Patron job will fail if the time to
##    complete it has expired."
##
##   "Select Your Job — IF YOU ARE NOT ATTACKED BY RIVALS, you may select from
##    any ONE of the options below"
##
## So the Rival battle REPLACES the turn's plan. Observed on device instead: the
## mission reached the battle carrying `mission_source: rival` AND
## `patron: Regional Agent`, `pay: 5`, `title: "Secure Mission"` — briefed as a
## five-credit Secure job, fought against the Patron's Mutants, then scored a
## defeat by p.91's no-win-condition rule.
##
## THE MISSION DICT BELOW IS THE ONE OFF THE TABLET, key for key, read back with
## `adb run-as ... cat files/saves/22222222_*.save` after the battle. The erase
## list this pins is exactly what a hand-written fixture got wrong the first time:
## it named `patron_name`, which no producer writes, while the real key is
## `patron`.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const CampaignTurnControllerScript = preload(
	"res://src/ui/screens/campaign/CampaignTurnController.gd")


## The accepted Patron job as it actually reached the battle on the device.
## Keys verified against JobOfferComponent.gd:688-731, the accepted-job builder.
func _patron_mission() -> Dictionary:
	return {
		"title": "Secure Mission",
		"description": "Secure",
		"objective_description": "Secure",
		"mission_objective": "Move Through",
		"objective": "Secure",
		"job_type": "secure",
		"patron": "Regional Agent",
		"patron_type": "regular",
		"patron_id": "patron_11116",
		"pay": 5,
		"danger_pay": 1,
		"danger_level": 1,
		"benefits": ["Security Team"],
		"hazards": [],
		"conditions": [],
		"time_frame": "This or the following 2 campaign turns",
		"time_frame_turns": 3,
		"offered_on_turn": 2,
		"deadline_turn": 4,
		"requirements": [],
		"double_roll_bonus": false,
		"is_affiliated_patron_job": false,
		"selected_tier": 0,
		# The Patron's own enemy. THIS is the key that made the ambush fight the
		# wrong opposition: EnemyGenerator honours any non-empty preset.
		"enemy_type": "Mutants",
		"enemy_category": "interested_parties",
		"mission_source": "patron",
		"source": "patron",
		"location": "Joffre VI",
	}


## What _check_rival_encounter_backend hands the override. `rival_type` is the
## half that used to be dropped on the floor one function upstream.
func _encounter(rival_type: String = "") -> Dictionary:
	return {
		"has_encounter": true,
		"rival_id": "starting_rival_1775243676_0",
		"rival_name": "Fringe Syndicate",
		"attack_type": "BROUGHT_FRIENDS",
		"attack_description": "Add 1 additional enemy.",
		"roll": 1,
		"rival_count": 1,
		"decoy_bonus": 0,
		"reason": "Rolled 1 against 1 Rival(s) — Fringe Syndicate tracked you down.",
		"rival_type": rival_type,
		"is_elite": false,
	}


func _apply(mission: Dictionary, enc: Dictionary) -> Dictionary:
	var ctc: Node = auto_free(CampaignTurnControllerScript.new())
	ctc._apply_rival_ambush_override(mission, enc)
	return mission


# ── p.85: the job's identity does not survive ────────────────────────────────

## Every key that says "this is a paid Patron contract" must be gone. Each one
## below has a live consumer that cannot tell it is looking at a job the crew
## never carried out — PaymentProcessor reads danger_pay, the briefing screens
## read title/description, and `pay` is what Mission Prep advertised.
func test_no_patron_job_identity_survives_a_rival_ambush() -> void:
	var m: Dictionary = _apply(_patron_mission(), _encounter())
	var survivors: Array[String] = []
	for key: String in [
		"patron", "patron_type", "patron_id", "patron_name",
		"pay", "danger_pay", "benefits", "hazards", "conditions",
		"job_id", "job_type", "objective_description", "mission_objective",
		"objective", "requirements", "double_roll_bonus", "selected_tier",
		"is_affiliated_patron_job",
		"time_frame", "time_frame_turns", "offered_on_turn", "deadline_turn",
	]:
		if m.has(key):
			survivors.append("%s = %s" % [key, str(m[key])])
	assert_array(survivors).override_failure_message(
		"a Rival tracked the crew down, so p.85 says this battle is NOT the job "
		+ "they planned — but the job's payload rode along:\n  "
		+ "\n  ".join(survivors)).is_empty()


## The screens brief from these, so they must state the battle that is actually
## happening. Leaving "Secure Mission" is what let Mission Prep advertise five
## credits for a grudge match.
func test_the_briefing_names_the_rival_not_the_job() -> void:
	var m: Dictionary = _apply(_patron_mission(), _encounter())
	assert_str(str(m.get("title", ""))).contains("Fringe Syndicate")
	assert_str(str(m.get("title", ""))).not_contains("Secure")
	assert_str(str(m.get("description", ""))).contains("Fringe Syndicate")


func test_the_mission_is_sourced_to_the_rival() -> void:
	var m: Dictionary = _apply(_patron_mission(), _encounter())
	assert_str(str(m.get("mission_source", ""))).is_equal("rival")
	assert_str(str(m.get("source", ""))).is_equal("rival")
	assert_str(str(m.get("rival_id", ""))).is_equal("starting_rival_1775243676_0")
	assert_str(str(m.get("rival_attack_type", ""))).is_equal("BROUGHT_FRIENDS")


# ── p.94 / p.92: the right opposition, off the right column ──────────────────

## THE DEFECT, precisely. `enemy_type` is not blank on arrival — the displaced job
## put its own enemy there — and EnemyGenerator honours ANY non-empty preset
## (:576-580), taking the category from that template. So the ambush was fought
## against the Patron's Mutants off Interested Parties, and
## `_roll_encounter_category("rival")` — which already maps correctly to the p.94
## Unknown Rival column — never ran.
##
## p.101 is the other half of why this matters: "Enemies from this list never
## become Rivals", and the Unknown Rival column has no Roving Threats entry at
## all. The columns are genuinely different distributions, not flavour.
func test_the_displaced_jobs_enemy_does_not_fight_the_rival_battle() -> void:
	var m: Dictionary = _apply(_patron_mission(), _encounter())
	assert_bool(m.has("enemy_type")).override_failure_message(
		"the Patron's enemy_type survived, so EnemyGenerator will honour it as a "
		+ "preset and never roll on the p.94 Unknown Rival column").is_false()
	assert_bool(m.has("enemy_category")).override_failure_message(
		"a stale enemy_category leaks the displaced job's encounter table").is_false()


## THE HANDOFF ITSELF, which is where this actually broke.
##
## The two tests above hand `_apply_rival_ambush_override` an encounter dict that
## already contains `rival_type` — so they exercise the CONSUMER and are blind to
## the producer dropping the key. That blindness is the whole defect: an inline
## literal in `_check_rival_encounter_backend` did not name `rival_type`, so the
## value RivalEncounterCheck computed never arrived, and p.92 was unenforceable no
## matter how correct the override was.
##
## Proven: reverting the carry with the consumer tests alone produced 0 failures.
## This drives the real producer against the real check output instead.
func test_the_encounter_handoff_carries_everything_the_override_reads() -> void:
	var RivalCheck = load("res://src/core/campaign/RivalEncounterCheck.gd")
	# Six Rivals so the p.85 D6 ALWAYS lands at or below the count — the encounter
	# is guaranteed by the rule rather than by a lucky seed. All six carry the same
	# established type, so whichever the check picks at random has it. A Rival
	# established in battle records a real enemy type as `type`
	# (RivalPatronResolver._append_rival).
	var rivals: Array = []
	for i in range(6):
		rivals.append({
			"id": "rival_gangers_%d" % i, "name": "Gangers Vendetta %d" % i,
			"type": "Gangers",
		})
	var check: Dictionary = RivalCheck.check(rivals, 0, null, "")
	assert_bool(check.get("has_encounter", false)).override_failure_message(
		"fixture must produce an encounter for this test to mean anything").is_true()
	assert_str(str(check.get("rival_type", ""))).is_equal("Gangers")

	var attack: Dictionary = {"type": "AMBUSH", "description": "Ambushed."}
	var handoff: Dictionary = CampaignTurnControllerScript.build_encounter_data(
		check, attack)

	for key: String in [
		"rival_id", "rival_name", "attack_type", "attack_description",
		"rival_type", "is_elite",
	]:
		assert_bool(handoff.has(key)).override_failure_message(
			"_apply_rival_ambush_override reads '%s', and the handoff dropped it. "
			% key
			+ "A key literal that omits a downstream consumer's input fails "
			+ "silently — nothing errors, the rule just never applies.").is_true()
	assert_str(str(handoff.get("rival_type", ""))).override_failure_message(
		"p.92 needs the established type to survive the handoff").is_equal("Gangers")


# ── the erase list must track the REAL producer, not my memory of it ─────────

## `mission_data` is NOT built by JobOfferComponent. The accepted job is RESHAPED
## by the flattening literal in `WorldPhaseController._on_world_phase_completed`
## (:1842-1941), which drops some job keys, renames others and adds keys of its
## own. The first version of the erase list was written against the job builder
## and therefore missed four keys the flattener adds — including the two that
## mattered most:
##
##   `type`               → TacticalBattleUI:5073-5080 branches on it to open the
##                          Stealth / Street Fight / Salvage panel, so a displaced
##                          Salvage job opened the salvage panel on the grudge
##                          match.
##   `compendium_mission` → `job_results.duplicate(true)`, i.e. THE ENTIRE JOB
##                          DICT, handed to that panel as its payload. Erasing the
##                          top-level patron/pay keys while leaving this nested
##                          copy would have MOVED the payload, not removed it.
##
## So this test does not hardcode a key list at all. It reads the producer's own
## source, collects every key that literal writes, and requires each one to be
## either erased by the override or named in KEEP with a reason. Add a key to the
## flattener without deciding what a Rival ambush should do with it and this goes
## red — which is the only way a list like this stays honest.
const WPC_PATH := "res://src/ui/screens/world/WorldPhaseController.gd"

## Keys the flattener writes that a Rival ambush KEEPS, each with the reason.
const KEEP := {
	"location": "the world the crew is on, not the job they were offered",
	"source": "overwritten to \"rival\"",
	"mission_source": "overwritten to \"rival\"",
	"title": "overwritten to \"Rival Attack: <name>\"",
	"description": "overwritten to the p.85 line",
	# The zone is a TRAVEL decision taken at World Step 0
	# (UpkeepPhaseComponent.get_selected_zone), not a property of the job — the
	# crew flew into a Red/Black Zone and the Rival found them there. p.149 on the
	# Threat Condition: "applied to the mission, regardless of its type."
	"is_red_zone": "travel decision, not job payload (Core Rules p.149)",
	"is_black_zone": "travel decision, not job payload (Core Rules pp.150-151)",
	# Conditional, and asserted on its own below: pinned from the Rival's record
	# when p.92 has an established type, erased when it does not.
	"enemy_type": "p.92 — pinned or erased by the override, never inherited",
}


## Every `"key":` in the mission_dict literal, plus every `mission_dict["key"]`
## assignment that follows it. Deliberately NOT the zone stampers — they take the
## dict as a parameter named `mission` and are covered by KEEP above.
func _producer_keys() -> Array[String]:
	var file := FileAccess.open(WPC_PATH, FileAccess.READ)
	assert_object(file).override_failure_message(
		"cannot read %s — the test cannot verify the erase list without the "
		% WPC_PATH + "producer").is_not_null()
	var lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()

	var literal_re := RegEx.create_from_string("^\\s*\"([a-z_0-9]+)\"\\s*:")
	var assign_re := RegEx.create_from_string("mission_dict\\[\"([a-z_0-9]+)\"\\]")
	var keys: Array[String] = []
	var in_literal := false
	for line: String in lines:
		if line.contains("var mission_dict: Dictionary = {"):
			in_literal = true
			continue
		if in_literal:
			if line.strip_edges() == "}":
				in_literal = false
			else:
				var m := literal_re.search(line)
				if m and not keys.has(m.get_string(1)):
					keys.append(m.get_string(1))
		var a := assign_re.search(line)
		if a and not keys.has(a.get_string(1)):
			keys.append(a.get_string(1))
	return keys


func test_the_erase_list_covers_the_real_producer() -> void:
	var produced: Array[String] = _producer_keys()
	# Guard against a vacuous pass: if the regex or the block markers ever stop
	# matching, this test would silently assert nothing at all.
	assert_int(produced.size()).override_failure_message(
		"only found %d keys in the WorldPhaseController mission literal — the "
		% produced.size()
		+ "scan broke, so this test is not checking anything").is_greater(15)
	assert_array(produced).contains(["patron", "pay", "compendium_mission", "type"])

	# Build a mission carrying EVERY key the producer writes, then run the real
	# override on it.
	var mission: Dictionary = {}
	for key: String in produced:
		mission[key] = "PRODUCED::%s" % key
	var m: Dictionary = _apply(mission, _encounter())

	var leaked: Array[String] = []
	for key: String in produced:
		if KEEP.has(key):
			continue
		if m.has(key):
			leaked.append(key)
	assert_array(leaked).override_failure_message(
		"WorldPhaseController writes these onto mission_data and the p.85 override "
		+ "neither erases them nor names them in KEEP:\n  " + "\n  ".join(leaked)
		+ "\nEach one is a decision: does a Rival ambush inherit it, or not? "
		+ "Erase it in _apply_rival_ambush_override, or add it to KEEP with the "
		+ "reason.").is_empty()

	# And the reverse, so the list cannot be "fixed" by erasing everything: the
	# keys KEEP claims survive must actually survive.
	for key: String in KEEP:
		if key == "enemy_type":
			continue  # conditional — asserted by its own two tests
		if produced.has(key):
			assert_bool(m.has(key)).override_failure_message(
				"KEEP says %s survives a Rival ambush (%s) but the override "
				% [key, KEEP[key]] + "removed it").is_true()


## The Fixer's Guidebook pair, called out on its own because the nested copy is
## the subtle half: `compendium_mission` is a DEEP COPY of the whole job, so a
## perfect top-level erase list still leaks the entire Patron payload through it.
func test_a_displaced_compendium_job_does_not_bring_its_panel_or_its_payload() -> void:
	var mission: Dictionary = _patron_mission()
	mission["type"] = "salvage"
	mission["compendium_mission"] = _patron_mission()
	var m: Dictionary = _apply(mission, _encounter())
	assert_bool(m.has("type")).override_failure_message(
		"TacticalBattleUI:5073-5080 branches on `type`, so this opens the salvage "
		+ "panel on a Rival grudge match").is_false()
	assert_bool(m.has("compendium_mission")).override_failure_message(
		"the nested job payload survived — erasing the top-level patron/pay keys "
		+ "only MOVED it").is_false()


## p.92, verbatim: "Once a Rival has been established, they will always be the
## same type." A Rival created by a battle records a real enemy type, and THAT
## must be pinned rather than re-rolled.
func test_an_established_rival_keeps_its_own_enemy_type() -> void:
	var m: Dictionary = _apply(_patron_mission(), _encounter("Gangers"))
	assert_str(str(m.get("enemy_type", ""))).override_failure_message(
		"p.92 pins an established Rival's type; this is the value that "
		+ "_check_rival_encounter_backend used to drop before the override could "
		+ "read it").is_equal("Gangers")


## A STARTING Rival's `type` is a faction category, not an enemy type — that crew
## has never been fought, so there is nothing established to keep the same.
##
## ⚠ THIS FIXTURE WAS WRONG AND THE DEVICE CAUGHT IT (Aug 13 2026). It used to
## pass an EMPTY rival_type, assuming a starting Rival carries none. The tablet's
## save says otherwise — verbatim, from
## `adb run-as … cat files/saves/22222222_*.save`:
##
##   {"hostility": 5.0, "id": "starting_rival_1775243676_0",
##    "is_starting_rival": true, "name": "Fringe Syndicate",
##    "source_character": "Zephyr Flynn", "strength": 1.0, "type": "Corporate"}
##
## `RivalEncounterCheck.rival_type_of()` forwards `type` verbatim, so the override
## received "Corporate" — non-empty, and therefore PINNED as the mission's enemy.
## "Corporate" is not one of the 60 names in data/enemy_types.json, so the fight
## itself was still correct (EnemyGenerator finds no template and falls through to
## the p.94 column roll) while the RECORD named an enemy that does not exist.
##
## The guard is now `EnemyGenerator.is_known_enemy_type()`, and the fixture below
## uses the real shape rather than the one I imagined.
func test_a_starting_rivals_faction_category_is_not_pinned_as_an_enemy() -> void:
	var m: Dictionary = _apply(_patron_mission(), _encounter("Corporate"))
	assert_bool(m.has("enemy_type")).override_failure_message(
		"\"Corporate\" is a faction category, not an enemy type — pinning it as a "
		+ "preset makes the briefing and the Encounter Log name an enemy that is "
		+ "not in enemy_types.json").is_false()


## The other half of the same guard: a legacy String-shaped Rival carries no type
## at all, which must also roll normally rather than pin "".
func test_a_rival_with_no_type_at_all_rolls_normally() -> void:
	var m: Dictionary = _apply(_patron_mission(), _encounter())
	assert_bool(m.has("enemy_type")).is_false()


## And the validator itself, against the real data file. If enemy_types.json ever
## stops carrying these names the pin above silently stops working.
func test_the_enemy_type_validator_matches_the_data_file() -> void:
	assert_bool(EnemyGenerator.is_known_enemy_type("Gangers")).override_failure_message(
		"Gangers is one of the 60 enemy names and must validate").is_true()
	assert_bool(EnemyGenerator.is_known_enemy_type("Mutants")).is_true()
	assert_bool(EnemyGenerator.is_known_enemy_type("Corporate")).override_failure_message(
		"Corporate is a FACTION category and must not validate as an enemy"
		).is_false()
	assert_bool(EnemyGenerator.is_known_enemy_type("")).is_false()
	assert_bool(EnemyGenerator.is_known_enemy_type("   ")).is_false()


# ── p.85: what the book says REMAINS ─────────────────────────────────────────

## "Quests and Rumors remain, but a Patron job will fail if the time to complete
## it has expired." Detaching this BATTLE from the job must not cancel the offer,
## which lives in progress_data["patron_job_offers"] and expires on its own.
## Asserting the override does not reach outside the mission dict.
func test_the_override_only_touches_the_mission_dict() -> void:
	var m: Dictionary = _patron_mission()
	var before: int = m.size()
	_apply(m, _encounter())
	assert_int(m.size()).override_failure_message(
		"the override should shrink the mission, not grow it").is_less(before)
	# The battle keys it is responsible for, and nothing that belongs to the offer
	# store or the campaign.
	assert_bool(m.has("rival_encounter")).is_true()
	assert_bool(m.has("location")).override_failure_message(
		"location is the world, not the job — it must survive").is_true()


# ── The record has to name what was FOUGHT ───────────────────────────────────
#
# Erasing "Corporate" is only half a fix. `enemy_type` is also what
# CampaignJournal.create_battle_journal_entry reads —
#   var enemy_type: String = battle_result.get("enemy_type", "Unknown")
#   var desc: String = "Battle vs %s - %s\n" % [enemy_type, ...]
# (CampaignJournal.gd:768-772) — and what the Encounter Log prints. With the key
# erased and nothing put back, the permanent record said "Battle vs Unknown".
#
# ⚠ MEASURED ON THE TABLET, Aug 13 2026, deploy #10. A Corporate Rival ambush
# correctly generated Skulker Brigands (the battle card, the enemy roster and
# all 7 unit names said so) and the journal entry for that exact battle read
#   "description": "Battle vs Unknown - Defeat\n | Objective: Access (achieved)"
# while the same campaign's PREVIOUS battle, written by the build before the
# guard landed, read "Battle vs Mutants". So this was a regression introduced by
# the guard, not a pre-existing gap — which is why it is fixed here rather than
# filed.
#
# The lesson worth keeping: REMOVING A WRONG VALUE IS NOT THE SAME AS SUPPLYING
# THE RIGHT ONE. A guard that erases a key has to answer "who else reads it?"

func test_the_rolled_enemy_is_stamped_back_for_the_record() -> void:
	# Exactly the tablet case: the guard has just erased the faction category,
	# and the generator rolled a real enemy.
	var mission: Dictionary = {"location": "Joffre VI"}
	CampaignTurnControllerScript.stamp_rolled_enemy_type(
		mission, {"type": "Skulker Brigands"})
	assert_str(str(mission.get("enemy_type", ""))).override_failure_message(
		"the journal reads mission enemy_type (CampaignJournal.gd:768); with it "
		+ "absent every Rival-ambush battle records 'Battle vs Unknown'"
		).is_equal("Skulker Brigands")


func test_the_journal_never_falls_back_to_unknown_after_an_ambush() -> void:
	# End to end through the two halves in order: override erases the faction
	# category, then the stamp supplies what the generator actually rolled.
	var mission: Dictionary = _apply(_patron_mission(), _encounter("Corporate"))
	assert_bool(mission.has("enemy_type")).override_failure_message(
		"the guard must not pin a faction category").is_false()

	CampaignTurnControllerScript.stamp_rolled_enemy_type(
		mission, {"type": "Colonial Militia"})

	var journalled: String = str(mission.get("enemy_type", "Unknown"))
	assert_str(journalled).override_failure_message(
		"this is the exact expression CampaignJournal uses; 'Unknown' here is "
		+ "the defect measured on the tablet").is_not_equal("Unknown")
	assert_str(journalled).is_equal("Colonial Militia")
	assert_str(journalled).override_failure_message(
		"and it must never be the faction category either").is_not_equal("Corporate")


func test_a_mission_that_already_names_its_enemy_is_not_overwritten() -> void:
	# A Patron job, or a Rival whose type IS a real enemy name and so survived
	# the guard. The generator honoured that preset, so the roll agrees anyway --
	# but the stamp must not be the thing deciding it.
	var mission: Dictionary = {"enemy_type": "Gangers"}
	CampaignTurnControllerScript.stamp_rolled_enemy_type(
		mission, {"type": "Skulker Brigands"})
	assert_str(str(mission.get("enemy_type", ""))).override_failure_message(
		"an established Rival keeps its own type (p.92) — the stamp only FILLS"
		).is_equal("Gangers")


func test_a_blank_enemy_type_is_treated_as_absent() -> void:
	# has() is true for an empty value, so guarding on has() alone would leave
	# "" in place and the journal would print nothing at all instead of a name.
	for blank: String in ["", "   "]:
		var mission: Dictionary = {"enemy_type": blank}
		CampaignTurnControllerScript.stamp_rolled_enemy_type(
			mission, {"type": "Colonial Militia"})
		assert_str(str(mission.get("enemy_type", ""))).override_failure_message(
			"a blank enemy_type must be filled, not preserved").is_equal(
			"Colonial Militia")


func test_no_enemies_rolled_leaves_the_mission_alone() -> void:
	# enemies.is_empty() gives first_enemy == {}. Stamping "" would be worse than
	# leaving the key absent: the journal's own "Unknown" fallback is at least
	# readable.
	var mission: Dictionary = {"location": "Joffre VI"}
	CampaignTurnControllerScript.stamp_rolled_enemy_type(mission, {})
	assert_bool(mission.has("enemy_type")).is_false()
	CampaignTurnControllerScript.stamp_rolled_enemy_type(mission, {"type": "  "})
	assert_bool(mission.has("enemy_type")).is_false()


func test_the_stamp_is_wired_into_the_battle_path() -> void:
	# The two halves are in different functions; a passing pure test says nothing
	# about whether the live path calls the second one. Anchor on the call site.
	var src: String = FileAccess.get_file_as_string(
		"res://src/ui/screens/campaign/CampaignTurnController.gd")
	assert_bool(src.contains("stamp_rolled_enemy_type(mission_data, first_enemy)")
		).override_failure_message(
		"the rolled enemy is only recorded if _initiate_battle_sequence actually "
		+ "calls the stamp after generate_enemies_as_dicts()").is_true()
