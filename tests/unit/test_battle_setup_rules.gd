extends GdUnitTestSuite
## Scenario setup modifications — Rival attack types (Core Rules pp.91-92),
## Invasion battles (p.92) and deployment conditions (p.88).
##
## THE GAP THESE PIN: all three were rolled, stored and displayed, and none of
## them changed anything about the battle.
##   - `rival_attack_type` reached exactly one label. Ambush never cost a
##     deployment slot or blocked the Seize roll; Brought Friends and Assault
##     never added their enemy; Assault and Raid never charged on a loss.
##   - `DeploymentConditionsSystem.apply_condition()` had ZERO callers, and of
##     the conditions only Small Encounter's ENEMY half was hand-applied at the
##     campaign layer — its crew-sit-out half never was, so the deployment cap
##     was always the full campaign crew size.
##   - Invasion had only the Notable-Sight skip: no extra enemy, no hold clock.

const RULES = preload("res://src/core/battle/BattleSetupRules.gd")

func _rival(attack: String) -> Dictionary:
	return {"rival_attack_type": attack, "mission_source": "rival"}

func _condition(cid: String) -> Dictionary:
	return {"deployment_condition": {"condition_id": cid}}

# ── Rival attack types (p.91 D10 table) ───────────────────────────────────

func test_ambush_costs_a_deployment_slot_and_forbids_the_seize_roll() -> void:
	# p.91: "You can deploy one crew member less than standard (5 in a typical
	# campaign) for this fight, and cannot roll to Seize the Initiative."
	var b: Dictionary = RULES.compute(_rival("AMBUSH"), 5, 6)
	assert_int(b["crew_cap_delta"]).is_equal(-1)
	assert_bool(b["can_seize_initiative"]).is_false()
	assert_int(b["enemy_delta"]).is_equal(0)

func test_brought_friends_adds_one_enemy() -> void:
	# p.91: "Add 1 additional enemy."
	var b: Dictionary = RULES.compute(_rival("BROUGHT_FRIENDS"), 5, 6)
	assert_int(b["enemy_delta"]).is_equal(1)
	assert_int(b["crew_cap_delta"]).is_equal(0)
	assert_bool(b["can_seize_initiative"]).is_true()

func test_showdown_modifies_nothing() -> void:
	# p.91: "A straight-up fight. No modifications."
	var b: Dictionary = RULES.compute(_rival("SHOWDOWN"), 5, 6)
	assert_int(b["enemy_delta"]).is_equal(0)
	assert_int(b["crew_cap_delta"]).is_equal(0)
	assert_bool(b["can_seize_initiative"]).is_true()
	assert_array(b["loss_penalties"]).is_empty()

func test_assault_adds_an_enemy_and_fines_credits_on_a_loss() -> void:
	# p.92: "Add one additional enemy figure. Your crew must all set up in or
	# adjacent to a building. If you fail to Hold the Field, you will lose 1D3
	# credits."
	var b: Dictionary = RULES.compute(_rival("ASSAULT"), 5, 6)
	assert_int(b["enemy_delta"]).is_equal(1)
	assert_int(b["loss_penalties"].size()).is_equal(1)
	assert_str(b["loss_penalties"][0]["type"]).is_equal("credits")
	assert_str(b["loss_penalties"][0]["dice"]).is_equal("1D3")
	# The building requirement is a physical-setup instruction, so it has to
	# reach the player as text — there is nothing else to enforce it with.
	var joined: String = " ".join(PackedStringArray(b["setup_notes"]))
	assert_str(joined.to_lower()).contains("building")

func test_raid_damages_the_ship_on_a_loss_and_adds_no_enemy() -> void:
	# p.92: "If you fail to Hold the Field, your ship will take 1D6+1 points of
	# Hull Point damage." Raid is the one attack type that adds NO enemy.
	var b: Dictionary = RULES.compute(_rival("RAID"), 5, 6)
	assert_int(b["enemy_delta"]).is_equal(0)
	assert_int(b["loss_penalties"].size()).is_equal(1)
	assert_str(b["loss_penalties"][0]["type"]).is_equal("hull")
	assert_str(b["loss_penalties"][0]["dice"]).is_equal("1D6+1")

func test_every_rival_battle_has_no_win_condition_and_a_flee_threshold() -> void:
	# p.91: "There is no Win condition against Rivals" and "If you flee from the
	# battle before 4 rounds are up, a random crew member will lose a random item
	# of equipment carried in your flight."
	for attack in ["AMBUSH", "BROUGHT_FRIENDS", "SHOWDOWN", "ASSAULT", "RAID"]:
		var b: Dictionary = RULES.compute(_rival(attack), 5, 6)
		assert_bool(b["no_win_condition"]).override_failure_message(
			"%s should have no Win condition" % attack).is_true()
		assert_int(b["flee_before_round"]).is_equal(4)

func test_a_non_rival_mission_gets_no_rival_modifiers() -> void:
	var b: Dictionary = RULES.compute({"mission_source": "opportunity"}, 5, 6)
	assert_int(b["enemy_delta"]).is_equal(0)
	assert_int(b["crew_cap_delta"]).is_equal(0)
	assert_bool(b["no_win_condition"]).is_false()
	assert_int(b["flee_before_round"]).is_equal(0)

# ── Invasion battles (p.92) ───────────────────────────────────────────────

func test_invasion_adds_an_enemy_and_sets_the_six_round_hold() -> void:
	# p.92: "Invasion opponents always have one additional enemy. You must hold
	# out for 6 rounds... There is no Win condition. Any figure that leaves the
	# table before Round 6 becomes a casualty."
	var b: Dictionary = RULES.compute({"mission_source": "invasion"}, 5, 6)
	assert_int(b["enemy_delta"]).is_equal(1)
	assert_int(b["hold_rounds"]).is_equal(6)
	assert_bool(b["no_win_condition"]).is_true()
	assert_bool(b["early_leave_is_casualty"]).is_true()

func test_invasion_is_recognised_from_either_key() -> void:
	# CampaignTurnController tags it as mission_source; the normalizer passes
	# through an is_invasion bool. Both shapes reach this code.
	assert_int(RULES.compute({"is_invasion": true}, 5, 6)["hold_rounds"]).is_equal(6)
	assert_int(RULES.compute({"mission_source": "invasion"}, 5, 6)["hold_rounds"]) \
		.is_equal(6)

# ── Deployment conditions (p.88) ──────────────────────────────────────────

func test_small_encounter_sits_a_crew_member_out_as_well_as_cutting_enemies() -> void:
	# p.88. The crew half is what was missing: the deployment cap was always the
	# full campaign crew size no matter what condition was rolled.
	var b: Dictionary = RULES.compute(_condition("SMALL_ENCOUNTER"), 4, 6)
	assert_int(b["crew_cap_delta"]).is_equal(-1)
	assert_int(b["enemy_delta"]).is_equal(-1)

func test_small_encounter_removes_two_enemies_when_outnumbered() -> void:
	var b: Dictionary = RULES.compute(_condition("SMALL_ENCOUNTER"), 8, 6)
	assert_int(b["enemy_delta"]).is_equal(-2)

func test_surprise_encounter_stops_the_enemy_acting_in_round_one() -> void:
	var b: Dictionary = RULES.compute(_condition("SURPRISE_ENCOUNTER"), 5, 6)
	assert_bool(b["round_one"].get("enemy_skips", false)).is_true()

func test_caught_off_guard_makes_the_whole_crew_slow_in_round_one() -> void:
	var b: Dictionary = RULES.compute(_condition("CAUGHT_OFF_GUARD"), 5, 6)
	assert_bool(b["round_one"].get("crew_all_slow", false)).is_true()

func test_delayed_starts_two_crew_off_table() -> void:
	var b: Dictionary = RULES.compute(_condition("DELAYED"), 5, 6)
	assert_int(b["round_one"].get("delayed_crew", 0)).is_equal(2)

func test_bitter_struggle_lowers_the_enemy_panic_range() -> void:
	# Core Rules p.88 says only "Enemy Morale is +1", which is ambiguous when
	# enemy morale IS the Panic range. Compendium p.49 settles the vocabulary:
	# its Leadership table is headed "enemy Morale is IMPROVED according to the
	# table below" and every row moves the Panic range DOWN (1-3 -> 1-2), with a
	# note that 0 means Fearless "unless another modifier RAISES the Panic
	# range". Improved Morale = reduced Panic range, so Bitter Struggle makes the
	# enemy HARDER to break — matching the Boss rule "Bosses reduce Bail Range
	# by 1".
	var b: Dictionary = RULES.compute(_condition("BITTER_STRUGGLE"), 5, 6)
	assert_int(b["panic_range_delta"]).is_equal(-1)

func test_no_condition_changes_nothing() -> void:
	for cid in ["NO_CONDITION", ""]:
		var b: Dictionary = RULES.compute(_condition(cid), 5, 6)
		assert_int(b["enemy_delta"]).is_equal(0)
		assert_int(b["crew_cap_delta"]).is_equal(0)
		assert_int(b["panic_range_delta"]).is_equal(0)

func test_persistent_conditions_impose_no_setup_change() -> void:
	# Poor Visibility / Gloomy / Slippery / Toxic / Brief Engagement are
	# in-battle effects the round spine already prompts for. They must not
	# quietly move the enemy count or the deployment cap.
	for cid in ["POOR_VISIBILITY", "GLOOMY", "SLIPPERY_GROUND",
			"TOXIC_ENVIRONMENT", "BRIEF_ENGAGEMENT"]:
		var b: Dictionary = RULES.compute(_condition(cid), 5, 6)
		assert_int(b["enemy_delta"]).override_failure_message(
			"%s moved the enemy count" % cid).is_equal(0)
		assert_int(b["crew_cap_delta"]).override_failure_message(
			"%s moved the deployment cap" % cid).is_equal(0)

# ── Conditions and attack types stack ─────────────────────────────────────

func test_an_ambush_during_a_small_encounter_stacks_both_crew_reductions() -> void:
	var md: Dictionary = _rival("AMBUSH")
	md["deployment_condition"] = {"condition_id": "SMALL_ENCOUNTER"}
	var b: Dictionary = RULES.compute(md, 4, 6)
	assert_int(b["crew_cap_delta"]).is_equal(-2)
	assert_bool(b["can_seize_initiative"]).is_false()

func test_an_invasion_with_brought_friends_adds_both_enemies() -> void:
	var md: Dictionary = _rival("BROUGHT_FRIENDS")
	md["mission_source"] = "invasion"
	md["is_invasion"] = true
	var b: Dictionary = RULES.compute(md, 5, 6)
	assert_int(b["enemy_delta"]).is_equal(2)

# ── apply_enemy_delta keeps the roster sane ───────────────────────────────

func _roster() -> Array:
	return [
		{"name": "Ganger Lieutenant", "role": "lieutenant", "is_leader": true},
		{"name": "Ganger", "role": "standard", "is_leader": false},
		{"name": "Ganger Specialist", "role": "specialist", "is_leader": false},
	]

func test_added_enemies_are_rank_and_file_not_clones_of_a_leader() -> void:
	# A duplicated figure must not clone a unique role — the book adds a body,
	# not a second Lieutenant or a second Unique Individual.
	var out: Array = RULES.apply_enemy_delta(_roster(), 1)
	assert_int(out.size()).is_equal(4)
	assert_str(out[-1]["role"]).is_equal("standard")
	assert_bool(out[-1]["is_leader"]).is_false()
	assert_bool(out[-1]["is_unique_individual"]).is_false()
	assert_str(out[-1]["name"]).contains("Reinforcement")

func test_removing_enemies_never_empties_the_force() -> void:
	var out: Array = RULES.apply_enemy_delta(_roster(), -5)
	assert_int(out.size()).is_equal(1)

func test_a_zero_delta_returns_the_roster_untouched() -> void:
	assert_int(RULES.apply_enemy_delta(_roster(), 0).size()).is_equal(3)

func test_apply_enemy_delta_does_not_mutate_the_input_array() -> void:
	var original: Array = _roster()
	RULES.apply_enemy_delta(original, 2)
	assert_int(original.size()).is_equal(3)


# ── p.88 Deployment Conditions: the columns ─────────────────────────────────

## "For Quest, Patron, Rival, and Opportunity missions, roll D100 and consult
## THE APPROPRIATE COLUMN." Every column must tile 1-100 exactly — a gap means a
## legal roll silently yields no condition, which is indistinguishable from
## rolling No Condition and hides the bug forever.
func test_every_deployment_column_tiles_the_d100() -> void:
	var file := FileAccess.open("res://data/deployment_conditions.json", FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()

	for column in ["opportunity", "patron", "rival", "quest"]:
		var covered: Dictionary = {}
		for cond in json.data["conditions"]:
			var r: Variant = (cond.get("roll_ranges", {}) as Dictionary).get(column, null)
			if not (r is Array) or (r as Array).size() < 2:
				continue
			for roll in range(int(r[0]), int(r[1]) + 1):
				assert_bool(covered.has(roll)).override_failure_message(
					"%s roll %d is claimed by both %s and %s"
					% [column, roll, covered.get(roll, "?"), cond["id"]]).is_false()
				covered[roll] = cond["id"]
		for roll in range(1, 101):
			assert_bool(covered.has(roll)).override_failure_message(
				"%s roll %d resolves to NOTHING" % [column, roll]).is_true()


## The Rival column is far harsher than Opportunity/Patron, which is the entire
## reason consulting the right one matters: No Condition is 1-40 on
## Opportunity/Patron and only 1-10 on Rival, and 1-5 on Quest. A Rival battle
## routed to the wrong column arrived with no complication 40% of the time where
## the book allows 10%.
func test_no_condition_bands_match_the_book() -> void:
	var file := FileAccess.open("res://data/deployment_conditions.json", FileAccess.READ)
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()

	for cond in json.data["conditions"]:
		if str(cond.get("id", "")) != "NO_CONDITION":
			continue
		var ranges: Dictionary = cond["roll_ranges"]
		assert_int(int((ranges["opportunity"] as Array)[1])).is_equal(40)
		assert_int(int((ranges["patron"] as Array)[1])).is_equal(40)
		assert_int(int((ranges["rival"] as Array)[1])).is_equal(10)
		assert_int(int((ranges["quest"] as Array)[1])).is_equal(5)
		return
	assert_bool(false).override_failure_message(
		"NO_CONDITION row is missing from deployment_conditions.json").is_true()
