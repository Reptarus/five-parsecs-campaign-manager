extends GdUnitTestSuite
## Patron jobs stop playing identically (Core Rules pp.83-85).
##
## WHAT WAS BROKEN: all three Benefits/Hazards/Conditions categories were rolled
## with the correct per-patron thresholds, forwarded into mission_data, and
## rendered by TacticalBattleUI as a "PATRON CONDITIONS" block of coloured text
## — then consumed by nothing at all. A "Dangerous Job" fielded the same number
## of enemies as a "Security Team"; a "Small Squad" job still let you deploy six;
## a "Vengeful" patron shrugged off a failed mission; "Demanding" paid Danger Pay
## on a loss; a "One-time Contract" patron was retained like any other. Thirty
## book entries, thirty pieces of flavour text.
##
## Time Frame was worse than display-only: the rolled String had ZERO readers
## anywhere in src/, and offers did not persist between turns at all, so the
## deadline had nothing to count against.

const PJE = preload("res://src/core/patrons/PatronJobEffects.gd")
const SetupRules = preload("res://src/core/battle/BattleSetupRules.gd")
const GEN_PATH := "res://data/patron_generation.json"


func _gen_data() -> Dictionary:
	var file := FileAccess.open(GEN_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()
	return json.data


## A job carrying one named entry, in the shape JobOfferComponent produces.
func _job_with(category: String, entry_id: String) -> Dictionary:
	var entry: Dictionary = PJE.entry_by_id(entry_id)
	assert_dict(entry).override_failure_message(
		"unknown entry id '%s'" % entry_id).is_not_empty()
	var job: Dictionary = {"benefits": [], "hazards": [], "conditions": []}
	job[category].append({
		"id": entry.get("id", ""),
		"name": entry.get("name", ""),
		"effect": entry.get("effect", ""),
	})
	return job


# ── The data covers the whole D10, and only that ────────────────────────────

## Every subtable must tile 1-10 with no gap and no overlap. A gap means a legal
## roll silently produces NO entry, which is indistinguishable from the category
## not applying — the exact failure mode this suite exists to catch.
func test_every_subtable_tiles_the_d10_exactly() -> void:
	var data: Dictionary = _gen_data()
	for category in PJE.CATEGORIES:
		var covered: Dictionary = {}
		for entry in data["%s_subtable" % category]["entries"]:
			var r: Array = entry["roll_range"]
			for roll in range(int(r[0]), int(r[1]) + 1):
				assert_bool(covered.has(roll)).override_failure_message(
					"%s roll %d is claimed twice" % [category, roll]).is_false()
				covered[roll] = entry["id"]
		for roll in range(1, 11):
			assert_bool(covered.has(roll)).override_failure_message(
				"%s roll %d resolves to NOTHING" % [category, roll]).is_true()


## Every entry needs a stable id and a machine-readable effects block. Without
## them a consumer can only string-match the display name, which is how these
## thirty rows stayed decorative in the first place.
func test_every_entry_has_an_id_and_effects() -> void:
	var data: Dictionary = _gen_data()
	var bare: Array = []
	for category in PJE.CATEGORIES:
		for entry in data["%s_subtable" % category]["entries"]:
			if not entry.has("id") or str(entry["id"]).is_empty():
				bare.append("%s/%s (no id)" % [category, entry.get("name", "?")])
			elif not entry.has("effects") or (entry["effects"] as Dictionary).is_empty():
				bare.append("%s/%s (no effects)" % [category, entry["id"]])
	assert_array(bare).override_failure_message(
		"entries a consumer cannot act on: %s" % [bare]).is_empty()


## The p.83 BHC threshold table, verbatim. Corporation Conditions 5+, Wealthy
## Individual Benefits 5+, Secretive Group Hazards 5+, everything else 8+.
func test_bhc_thresholds_match_the_book() -> void:
	assert_int(PJE.threshold("Corporation", "conditions")).is_equal(5)
	assert_int(PJE.threshold("Corporation", "benefits")).is_equal(8)
	assert_int(PJE.threshold("Corporation", "hazards")).is_equal(8)
	assert_int(PJE.threshold("Wealthy Individual", "benefits")).is_equal(5)
	assert_int(PJE.threshold("Wealthy Individual", "hazards")).is_equal(8)
	assert_int(PJE.threshold("Secretive Group", "hazards")).is_equal(5)
	assert_int(PJE.threshold("Secretive Group", "benefits")).is_equal(8)
	assert_int(PJE.threshold("Local Government", "conditions")).is_equal(8)
	assert_int(PJE.threshold("Sector Government", "benefits")).is_equal(8)
	assert_int(PJE.threshold("Private Organization", "conditions")).is_equal(8)
	# An unknown type must not fall through to "always applies".
	assert_int(PJE.threshold("Nobody At All", "benefits")).is_equal(8)


func test_roll_boundaries_resolve_to_the_book_entry() -> void:
	assert_str(PJE.entry_for_roll("benefits", 1).get("id", "")).is_equal("fringe_benefit")
	assert_str(PJE.entry_for_roll("benefits", 7).get("id", "")).is_equal("security_team")
	assert_str(PJE.entry_for_roll("benefits", 10).get("id", "")).is_equal("negotiable")
	assert_str(PJE.entry_for_roll("hazards", 2).get("id", "")).is_equal("dangerous_job")
	assert_str(PJE.entry_for_roll("hazards", 7).get("id", "")).is_equal("low_priority")
	assert_str(PJE.entry_for_roll("hazards", 8).get("id", "")).is_equal("private_transport")
	assert_str(PJE.entry_for_roll("conditions", 1).get("id", "")).is_equal("vengeful")
	assert_str(PJE.entry_for_roll("conditions", 4).get("id", "")).is_equal("small_squad")
	assert_str(PJE.entry_for_roll("conditions", 9).get("id", "")).is_equal("one_time_contract")


## A job saved before ids existed carries only the display name. Resolving it is
## the difference between honouring an old campaign's Conditions and silently
## dropping them.
func test_legacy_name_only_entries_still_resolve() -> void:
	var legacy: Dictionary = {
		"conditions": [{"name": "One-time Contract", "effect": "..."}],
		"hazards": [], "benefits": [],
	}
	assert_bool(PJE.has_effect(legacy, "one_time_contract")).is_true()
	assert_bool(PJE.patron_is_retainable(legacy)).is_false()
	# A bare String entry is the other shape in the wild.
	var bare: Dictionary = {"conditions": ["Small Squad"], "hazards": [], "benefits": []}
	assert_int(PJE.max_deploy_crew(bare)).is_equal(4)


# ── Battle setup ────────────────────────────────────────────────────────────

func test_enemy_count_modifiers() -> void:
	assert_int(PJE.enemy_count_modifier(_job_with("hazards", "dangerous_job"))).is_equal(1)
	assert_int(PJE.enemy_count_modifier(_job_with("hazards", "low_priority"))).is_equal(-1)
	assert_int(PJE.enemy_count_modifier(_job_with("benefits", "security_team"))).is_equal(-1)
	assert_int(PJE.enemy_count_modifier({})).is_equal(0)


## A job can carry a Benefit AND a Hazard that both move the enemy count, and
## the book gives no precedence rule — so they must add rather than one winning.
func test_opposing_enemy_modifiers_cancel() -> void:
	var job: Dictionary = _job_with("hazards", "dangerous_job")
	job["benefits"] = _job_with("benefits", "security_team")["benefits"]
	assert_int(PJE.enemy_count_modifier(job)).is_equal(0)


## "Small Squad — You cannot deploy more than 4 crew" (p.84) is an ABSOLUTE
## ceiling: it holds at 4 whether the campaign crew size is 4, 5 or 6, and it
## must never widen a cap that some other rule already narrowed.
func test_small_squad_caps_deployment_absolutely() -> void:
	var job: Dictionary = _job_with("conditions", "small_squad")
	assert_int(PJE.max_deploy_crew(job)).is_equal(4)
	assert_int(PJE.deploy_cap(job, 6)).is_equal(4)
	assert_int(PJE.deploy_cap(job, 3)).is_equal(3)
	assert_int(PJE.deploy_cap({}, 6)).is_equal(6)


func test_full_squad_requires_six_available_crew() -> void:
	assert_int(PJE.required_available_crew(_job_with("conditions", "full_squad"))).is_equal(6)
	assert_int(PJE.required_available_crew({})).is_equal(0)


func test_requirement_conditions_are_flagged() -> void:
	assert_bool(PJE.forbids_law_enforcement_rivals(
		_job_with("conditions", "clean"))).is_true()
	assert_bool(PJE.forbids_law_enforcement_rivals({})).is_false()
	assert_bool(PJE.requires_prior_patron_job_here(
		_job_with("conditions", "reputation_required"))).is_true()
	assert_bool(PJE.requires_prior_patron_job_here({})).is_false()


## "VIP — A random enemy will have +1 Toughness and a final Combat Skill of +2
## (regardless of current value)" (p.84). The Combat Skill is a SET value, not a
## bonus, which is why it is exposed under a differently-named accessor.
func test_vip_hazard_values() -> void:
	var job: Dictionary = _job_with("hazards", "vip")
	assert_bool(PJE.has_vip_enemy(job)).is_true()
	assert_int(PJE.vip_toughness_bonus(job)).is_equal(1)
	assert_int(PJE.vip_combat_skill_final(job)).is_equal(2)
	assert_bool(PJE.has_vip_enemy({})).is_false()


## "Veteran Opposition — Enemy is -1 to Bail Range" (p.84): a LOWER Bail Range
## means they hold on longer, so this is an enemy buff expressed as a negative.
func test_veteran_opposition_lowers_bail_range() -> void:
	assert_int(PJE.enemy_bail_modifier(
		_job_with("hazards", "veteran_opposition"))).is_equal(-1)
	assert_int(PJE.enemy_bail_modifier({})).is_equal(0)


## The setup bundle is where these actually bite. Proven through the real
## compute() entry point, not the resolver alone.
func test_setup_bundle_applies_patron_conditions() -> void:
	var small: Dictionary = _job_with("conditions", "small_squad")
	var b: Dictionary = SetupRules.compute(small, 5, 6)
	assert_int(b["crew_cap_max"]).is_equal(4)

	var vet: Dictionary = _job_with("hazards", "veteran_opposition")
	var b2: Dictionary = SetupRules.compute(vet, 5, 6)
	assert_int(b2["panic_range_delta"]).is_equal(-1)

	# A job with no Conditions must leave the bundle alone.
	var b3: Dictionary = SetupRules.compute({}, 5, 6)
	assert_int(b3["crew_cap_max"]).is_equal(0)
	assert_int(b3["panic_range_delta"]).is_equal(0)


## The resolver being right proves nothing if the generator never asks it. This
## goes through generate_enemies_as_dicts() — what the campaign actually calls.
##
## "Converted Infiltrators" is a Roving Threat, which p.93 excludes from the
## Unique Individual roll: that isolates the count modifier from every other
## thing that can add a figure to the returned array. Asserting a MINIMUM gap
## rather than exactly 2.0 keeps this an invariant test that survives an
## unrelated change to the base dice.
func test_patron_enemy_modifiers_reach_the_live_generator() -> void:
	var generator := EnemyGenerator.new()
	var iterations := 200
	var sum_security := 0
	var sum_dangerous := 0
	for _i in range(iterations):
		var base: Dictionary = {
			"mission_source": "patron",
			"enemy_type": "Converted Infiltrators",
			"danger_level": 2,
		}
		var with_security: Dictionary = base.duplicate(true)
		with_security.merge(_job_with("benefits", "security_team"))
		var with_dangerous: Dictionary = base.duplicate(true)
		with_dangerous.merge(_job_with("hazards", "dangerous_job"))
		sum_security += generator.generate_enemies_as_dicts(with_security, 5).size()
		sum_dangerous += generator.generate_enemies_as_dicts(with_dangerous, 5).size()
	assert_float(float(sum_dangerous) / iterations).override_failure_message(
		"Dangerous Job (+1) must field more enemies than Security Team (-1)"
	).is_greater(float(sum_security) / iterations + 1.0)


## Red Job Increased Opposition (p.150) is verbatim: a base of 7 "+ any modifier
## from the enemy type encountered. NO OTHER MODIFIERS ARE APPLIED up or down."
## A Patron Hazard is another modifier, so it must not touch a Red Job — the
## same reason the world-trait modifier is held out of numbers_mod.
func test_patron_modifiers_do_not_touch_a_red_job() -> void:
	var generator := EnemyGenerator.new()
	for _i in range(40):
		var red: Dictionary = {
			"mission_source": "patron",
			"enemy_type": "Converted Infiltrators",
			"is_red_zone": true,
		}
		red.merge(_job_with("hazards", "dangerous_job"))
		var plain: Dictionary = {
			"mission_source": "patron",
			"enemy_type": "Converted Infiltrators",
			"is_red_zone": true,
		}
		assert_int(generator.generate_enemies_as_dicts(red, 5).size()).is_equal(
			generator.generate_enemies_as_dicts(plain, 5).size())


# ── Pay, Patron status and Rivals ───────────────────────────────────────────

func test_demanding_withholds_danger_pay_until_success() -> void:
	assert_bool(PJE.danger_pay_on_success_only(
		_job_with("conditions", "demanding"))).is_true()
	# p.83 default is the opposite: paid "even if the mission fails".
	assert_bool(PJE.danger_pay_on_success_only({})).is_false()


func test_negotiable_allows_a_danger_pay_reroll() -> void:
	assert_bool(PJE.danger_pay_rerollable(
		_job_with("benefits", "negotiable"))).is_true()
	assert_bool(PJE.danger_pay_rerollable({})).is_false()


## "Hot Job — After the job, you will earn an enemy on 1-2 instead of the normal
## roll of a 1" (p.84). It composes with the Vendetta system world trait onto the
## same p.119 roll; taking the wider is the only reading that cancels neither.
func test_hot_job_widens_the_rival_roll() -> void:
	var job: Dictionary = _job_with("hazards", "hot_job")
	assert_int(PJE.rival_conversion_threshold(1, job)).is_equal(2)
	# Already widened by a world trait — must not narrow back.
	assert_int(PJE.rival_conversion_threshold(2, job)).is_equal(2)
	assert_int(PJE.rival_conversion_threshold(1, {})).is_equal(1)


func test_patron_status_conditions() -> void:
	assert_bool(PJE.patron_becomes_rival_on_failure(
		_job_with("conditions", "vengeful"))).is_true()
	assert_bool(PJE.patron_becomes_rival_on_failure({})).is_false()
	assert_bool(PJE.patron_persists_on_travel(
		_job_with("benefits", "persistent"))).is_true()
	assert_bool(PJE.patron_persists_on_travel({})).is_false()
	assert_bool(PJE.blocks_rival_tracking(
		_job_with("hazards", "private_transport"))).is_true()
	assert_bool(PJE.blocks_rival_tracking({})).is_false()
	assert_bool(PJE.offers_new_job_on_success(
		_job_with("conditions", "busy"))).is_true()


## p.119 Step 2: "you may add the Patron to your list of contacts on this
## planet, UNLESS the job was a One-time Contract". Retainable by default.
func test_one_time_contract_blocks_retention() -> void:
	assert_bool(PJE.patron_is_retainable(
		_job_with("conditions", "one_time_contract"))).is_false()
	assert_bool(PJE.patron_is_retainable({})).is_true()
	assert_bool(PJE.patron_is_retainable(
		_job_with("conditions", "busy"))).is_true()


## The "Clean" Condition names no enemy list of its own, so the two the book
## calls law enforcement in so many words live in the data file: Enforcers
## (p.96) and Colonial Militia (p.100).
func test_law_enforcement_rival_detection() -> void:
	assert_array(PJE.law_enforcement_names()).contains(["Enforcers"])
	assert_bool(PJE.has_law_enforcement_rival([{"name": "Enforcers"}])).is_true()
	assert_bool(PJE.has_law_enforcement_rival(["Colonial Militia gang"])).is_true()
	assert_bool(PJE.has_law_enforcement_rival([{"name": "Roid-gangers"}])).is_false()
	assert_bool(PJE.has_law_enforcement_rival([])).is_false()


# ── Benefits are paid out ONLY on success (p.83) ────────────────────────────

## Exactly four Benefits are payouts. The other three are structural — Security
## Team shapes the battle, Persistent and Negotiable shape the relationship — so
## listing them as "rewards" would pay a benefit the book never pays.
func test_only_the_four_payout_benefits_are_success_rewards() -> void:
	assert_int(PJE.success_rewards(_job_with("benefits", "fringe_benefit")).size()).is_equal(1)
	assert_str(PJE.success_rewards(
		_job_with("benefits", "fringe_benefit"))[0]["reward"]).is_equal("loot_roll")
	assert_str(PJE.success_rewards(
		_job_with("benefits", "connections"))[0]["reward"]).is_equal("rumor")
	assert_str(PJE.success_rewards(
		_job_with("benefits", "company_store"))[0]["reward"]).is_equal("trade_roll")
	var health: Array = PJE.success_rewards(_job_with("benefits", "health_insurance"))
	assert_str(health[0]["reward"]).is_equal("injury_recovery")
	assert_int(health[0]["recovery_turns"]).is_equal(2)

	assert_array(PJE.success_rewards(_job_with("benefits", "security_team"))).is_empty()
	assert_array(PJE.success_rewards(_job_with("benefits", "persistent"))).is_empty()
	assert_array(PJE.success_rewards(_job_with("benefits", "negotiable"))).is_empty()


# ── Time Frame (p.83) ───────────────────────────────────────────────────────

## D10: 1-5 this turn, 6-7 this or next, 8-9 this or the following 2, 10+ any
## time. The 10+ is open-ended because the Secretive Group's +1 can push past 10.
func test_time_frame_boundaries() -> void:
	assert_int(PJE.time_frame_turns(1)).is_equal(1)
	assert_int(PJE.time_frame_turns(5)).is_equal(1)
	assert_int(PJE.time_frame_turns(6)).is_equal(2)
	assert_int(PJE.time_frame_turns(7)).is_equal(2)
	assert_int(PJE.time_frame_turns(8)).is_equal(3)
	assert_int(PJE.time_frame_turns(9)).is_equal(3)
	assert_int(PJE.time_frame_turns(10)).is_equal(-1)
	assert_int(PJE.time_frame_turns(11)).is_equal(-1)


## "This campaign turn" means the deadline IS the offer turn, not the one after.
## Off by one here and every 1-5 result would survive a turn it should not.
func test_deadline_turn_is_inclusive_of_the_offer_turn() -> void:
	assert_int(PJE.deadline_turn(4, 1)).is_equal(4)
	assert_int(PJE.deadline_turn(4, 2)).is_equal(5)
	assert_int(PJE.deadline_turn(4, 3)).is_equal(6)
	assert_int(PJE.deadline_turn(4, -1)).is_equal(-1)


func test_expiry() -> void:
	var this_turn_only: Dictionary = {"deadline_turn": 4}
	assert_bool(PJE.is_expired(this_turn_only, 4)).is_false()
	assert_bool(PJE.is_expired(this_turn_only, 5)).is_true()
	# "Any time" never expires, however long the crew sits on it.
	assert_bool(PJE.is_expired({"deadline_turn": -1}, 99)).is_false()
	# A job from a save written before deadlines existed must not vanish.
	assert_bool(PJE.is_expired({"time_frame": "This campaign turn"}, 99)).is_false()


## The label is recomputed against the CURRENT turn, so a held offer reads
## "Expires this campaign turn" instead of repeating the wording it was born
## with — which is exactly when a stale label starts costing the player a job.
func test_deadline_label_counts_down() -> void:
	var job: Dictionary = {"deadline_turn": 6}
	assert_str(PJE.deadline_label(job, 4)).is_equal("This or the following 2 campaign turns")
	assert_str(PJE.deadline_label(job, 5)).is_equal("This or the next campaign turn")
	assert_str(PJE.deadline_label(job, 6)).is_equal("Expires this campaign turn")
	assert_str(PJE.deadline_label(job, 7)).is_equal("Expired")
	assert_str(PJE.deadline_label({"deadline_turn": -1}, 7)).is_equal("Any time")
	# Pre-deadline saves fall back to whatever text they carry.
	assert_str(PJE.deadline_label({"time_frame": "Any time"}, 7)).is_equal("Any time")
