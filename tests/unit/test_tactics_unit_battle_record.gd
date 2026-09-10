extends GdUnitTestSuite

## The Tactics per-unit campaign record — a consumer that finally has a producer.
##
## ── THE DEFECT ───────────────────────────────────────────────────────────────
## `TacticsDashboard._create_unit_card()` printed four stats per roster unit —
## Models / Battles / Wins / CP — and **three of the four were permanently 0**:
##
##   * `battles_fought` / `battles_won` were initialised at creation
##     (TacticsCreationCoordinator) and displayed at TacticsDashboard.gd:414/:424,
##     and NOTHING incremented them. Their only writer was
##     `TacticsCampaignUnit.record_battle()`, which had zero callers.
##   * `campaign_points` was never a per-unit quantity at all. **Tactics p.106**:
##     *"Players use Campaign Points (CP) to track their progression"*, and the
##     chapter's own heading *"Are Points Tied to the Player or Army?"* offers exactly
##     two answers, neither of them per-unit. So that column printed a hard 0 beside
##     the dashboard header's real campaign-level CP figure.
##
## ── "WHEN HAS A UNIT FOUGHT?" WAS NOT A PRODUCT CALL ─────────────────────────
## The app already computes the answer and then threw it away.
## `TacticsBattleSetupPanel._campaign_unit_ids()` (:247-257) lists every
## non-destroyed unit at DEPLOYMENT, and `TacticsPhaseManager._apply_phase_results()`
## stamps it onto `campaign.current_battle["deployed_units"]` (:240-241) — where
## nothing read it. Producer with no consumer, one layer above a consumer with no
## producer; joining them is the whole fix.
##
## p.106's *Weakened* result is what makes the record load-bearing rather than
## decorative: *"until the unit can sit out a campaign battle without being deployed,
## it must deploy with one figure fewer than normal."*
##
## ── DETECTION PROOF, one arm at a time ───────────────────────────────────────
##   * delete the `_credit_deployed_units(...)` call in `_apply_battle_results()`
##     -> `test_a_deployed_unit_is_credited_through_the_real_phase_path` FAILS
##   * make `_credit_deployed_units()` credit the whole roster unconditionally
##     -> `test_a_unit_that_did_not_deploy_is_not_credited` FAILS
##   * drop the RETIRED_FIELDS erase from `normalize()`
##     -> `test_normalize_drops_the_retired_per_unit_cp_keys` FAILS
##
## ⚠ gdUnit4 is FAIL-FAST: it aborts a suite at the first failing case, so when
## proving one of these, run that case ALONE (rename the others `func off_*`) or the
## later cases are silently never executed and their silence proves nothing.

const PhaseManager := preload("res://src/core/campaign/TacticsPhaseManager.gd")
const TacticsCore := preload("res://src/game/campaign/TacticsCampaignCore.gd")
const UnitRecord := preload("res://src/data/tactics/TacticsCampaignUnit.gd")


func _campaign_with_two_units() -> Resource:
	var c = TacticsCore.new()
	var a: Dictionary = UnitRecord.new_unit("rifle_squad", "human", "Alpha", 5)
	a["unit_id"] = "u_alpha"
	var b: Dictionary = UnitRecord.new_unit("weapons_team", "human", "Bravo", 3)
	b["unit_id"] = "u_bravo"
	c.initialize_campaign_units([a, b])
	return c


func _manager(campaign: Resource) -> Node:
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(campaign)
	return pm


func _unit(campaign: Resource, unit_id: String) -> Dictionary:
	for u in campaign.campaign_units:
		if u is Dictionary and str((u as Dictionary).get("unit_id", "")) == unit_id:
			return u
	return {}


# ═══════════════════════════════ the real phase path

func test_a_deployed_unit_is_credited_through_the_real_phase_path() -> void:
	## ⭐ Drives DEPLOYMENT then BATTLE through the production manager, not a direct
	## call to the helper. The rule being right is not the thing that was broken —
	## `TacticsCampaignUnit.record_battle()` was already correct and simply never ran.
	var campaign := _campaign_with_two_units()
	var pm := _manager(campaign)

	pm.go_to_phase(PhaseManager.Phase.DEPLOYMENT)
	pm.complete_current_phase({"deployed_units": ["u_alpha", "u_bravo"]})
	pm.complete_current_phase({"battle_result": {"won": true}})

	var alpha := _unit(campaign, "u_alpha")
	assert_int(int(alpha.get("battles_fought", 0))).override_failure_message(
		"A unit deployed into a completed battle still shows 0 battles. The "
		+ "dashboard has printed this number since Tactics shipped; nothing wrote it."
	).is_equal(1)
	assert_int(int(alpha.get("battles_won", 0))).is_equal(1)


func test_a_defeat_counts_as_fought_but_not_won() -> void:
	var campaign := _campaign_with_two_units()
	var pm := _manager(campaign)

	pm.go_to_phase(PhaseManager.Phase.DEPLOYMENT)
	pm.complete_current_phase({"deployed_units": ["u_alpha"]})
	pm.complete_current_phase({"battle_result": {"won": false}})

	var alpha := _unit(campaign, "u_alpha")
	assert_int(int(alpha.get("battles_fought", 0))).is_equal(1)
	assert_int(int(alpha.get("battles_won", 0))).override_failure_message(
		"A lost battle incremented battles_won."
	).is_equal(0)


func test_a_unit_that_did_not_deploy_is_not_credited() -> void:
	## ⚠ THE DISCRIMINATING CASE. Without it, a fix that credits the entire roster on
	## every battle passes every other case in this suite.
	var campaign := _campaign_with_two_units()
	var pm := _manager(campaign)

	pm.go_to_phase(PhaseManager.Phase.DEPLOYMENT)
	pm.complete_current_phase({"deployed_units": ["u_alpha"]})
	pm.complete_current_phase({"battle_result": {"won": true}})

	assert_int(int(_unit(campaign, "u_alpha").get("battles_fought", 0))).is_equal(1)
	assert_int(int(_unit(campaign, "u_bravo").get("battles_fought", 0))) \
		.override_failure_message(
			"Bravo was left out of the deployment and was credited anyway. "
			+ "`deployed_units` is the record of who actually fought."
		).is_equal(0)


func test_the_fallback_credits_the_active_roster_when_deployment_said_nothing() -> void:
	## An older save, or a DEPLOYMENT phase completed with an empty payload, carries no
	## `deployed_units`. Crediting nobody there would silently reinstate the defect for
	## exactly those campaigns, so the fallback is the identical set
	## `_campaign_unit_ids()` would have produced: every non-destroyed unit.
	var campaign := _campaign_with_two_units()
	_unit(campaign, "u_bravo")["is_destroyed"] = true
	var pm := _manager(campaign)

	pm.go_to_phase(PhaseManager.Phase.BATTLE)
	pm.complete_current_phase({"battle_result": {"won": true}})

	assert_int(int(_unit(campaign, "u_alpha").get("battles_fought", 0))).is_equal(1)
	assert_int(int(_unit(campaign, "u_bravo").get("battles_fought", 0))) \
		.override_failure_message(
			"A DESTROYED unit was credited by the fallback. "
			+ "_campaign_unit_ids() excludes destroyed units, so the fallback must too."
		).is_equal(0)


# ═══════════════════════════════ the record shape has ONE owner

func test_new_unit_carries_exactly_the_declared_fields() -> void:
	## The creation wizard used to hand-build this dictionary from a literal — a
	## SECOND definition of the record beside the one in TacticsCampaignUnit. That is
	## how the two drifted, and how a cleanup in one left the other loading a script
	## that no longer parsed.
	var u: Dictionary = UnitRecord.new_unit("rifle_squad", "human", "Alpha", 5)
	for key: String in UnitRecord.FIELDS:
		assert_bool(u.has(key)).override_failure_message(
			"new_unit() omitted the declared field '%s'" % key).is_true()
	for key in u.keys():
		assert_bool(UnitRecord.FIELDS.has(str(key))).override_failure_message(
			"new_unit() emitted '%s', which is not in FIELDS. A key outside the "
			% str(key)
			+ "declared set is erased by normalize() on the next load."
		).is_true()


func test_normalize_drops_the_retired_per_unit_cp_keys() -> void:
	## ⚠ These records round-trip verbatim (`campaign_units.duplicate(true)` in both
	## directions), so a key that reaches disk once survives every future save unless
	## something removes it — the same rot that kept `auto_load_last_campaign` alive
	## in settings.cfg for months.
	var legacy := {
		"unit_id": "u_old",
		"base_unit_id": "rifle_squad",
		"campaign_points": 7,
		"campaign_points_spent": 2,
		"objectives_completed": 3,
		"current_models": 4,
	}
	UnitRecord.normalize(legacy)

	assert_bool(legacy.has("campaign_points")).override_failure_message(
		"Per-unit CP survived normalisation. Tactics p.106 makes CP a player-level or "
		+ "army-level pool; a per-unit figure can never be anything but 0."
	).is_false()
	assert_bool(legacy.has("campaign_points_spent")).is_false()
	assert_bool(legacy.has("objectives_completed")).override_failure_message(
		"`objectives_completed` counted a 'secondary objective', which is not a "
		+ "category in this book — it was part of the same fabricated CP block."
	).is_false()

	# ...and the real data is untouched, with the new fields filled in.
	assert_str(str(legacy.get("unit_id", ""))).is_equal("u_old")
	assert_int(int(legacy.get("current_models", 0))).is_equal(4)
	assert_int(int(legacy.get("battles_fought", -1))).is_equal(0)


func test_normalize_never_regenerates_an_existing_unit_id() -> void:
	## `TacticsCampaignCore.veteran_skills` is keyed by unit_id, so a regenerated id
	## would orphan every veteran skill the unit has bought.
	var u := {"unit_id": "u_keep", "base_unit_id": "x"}
	UnitRecord.normalize(u)
	assert_str(str(u.get("unit_id", ""))).is_equal("u_keep")


# ═══════════════════════════════ mutations the phase manager delegates

func test_casualties_destroy_a_unit_that_loses_everyone() -> void:
	var u: Dictionary = UnitRecord.new_unit("rifle_squad", "human", "Alpha", 5)
	UnitRecord.apply_casualties(u, 2)
	assert_int(int(u["current_models"])).is_equal(3)
	assert_int(int(u["models_lost_total"])).is_equal(2)
	assert_bool(bool(u["is_destroyed"])).is_false()

	UnitRecord.apply_casualties(u, 3)
	assert_int(int(u["current_models"])).is_equal(0)
	assert_int(int(u["models_lost_total"])).is_equal(5)
	assert_bool(bool(u["is_destroyed"])).is_true()


func test_reinforcement_stops_at_the_base_size() -> void:
	## ⚠ The inline version in TacticsPhaseManager._reinforce_unit() added the
	## requested figures unconditionally, so a reinforcement could take a squad above
	## the strength its army-list entry pays points for.
	var u: Dictionary = UnitRecord.new_unit("rifle_squad", "human", "Alpha", 5)
	UnitRecord.apply_casualties(u, 3)

	var added: int = UnitRecord.reinforce(u, 10, 5)
	assert_int(added).override_failure_message(
		"reinforce() added more than the unit had lost."
	).is_equal(3)
	assert_int(int(u["current_models"])).is_equal(5)
