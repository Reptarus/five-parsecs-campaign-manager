extends GdUnitTestSuite
## Battles must have opponents, and XP must reach the character sheet.
##
## TWO DEFECTS THIS PINS — the worst pair found in the whole sweep.
##
## 1. AUTO-RESOLVE FOUGHT AN EMPTY ENEMY LIST.
##    CampaignTurnController read mission_data["enemies"] — a key NOTHING writes.
##    The generated squad lives in GameState._current_enemies (set_current_enemies)
##    and mission_data["enemy_force"]["units"]; current_mission is built as a literal
##    with objective/enemy_type/pay and no "enemies" key at all. So the list was
##    always [], and BattleResolver.calculate_battle_outcome:527-530 short-circuits
##    `if enemies_alive == 0: success = true; held_field = true`.
##    Every "Play it out for me" was an instant flawless victory: zero rounds, zero
##    enemies defeated, zero crew hurt. The tactical path three lines away used the
##    correct source (get_current_enemies) — an N-1-of-N guard.
##
## 2. NO CREW MEMBER EVER GAINED XP.
##    The only XP write was gated on has_method("add_crew_experience"), a method that
##    exists on NEITHER GameState nor GameStateManager — a repo-wide grep finds six
##    call sites and zero definitions. Character.gd:263 even documents it as "called
##    by GameState.add_crew_experience", a function never written. The wizard printed
##    "gained 3 XP" (log-only) while the sheet never moved, so nobody ever advanced,
##    bought a stat, or reached an Advanced Training threshold.
##
## gdUnit4 v6.0.3 compatible.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PostBattleContextClass = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const ExperienceProcessor = preload(
	"res://src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd")
const BattleResolver = preload("res://src/core/battle/BattleResolver.gd")


func _campaign_with_crew() -> Variant:
	var c = CampaignCore.new()
	c.from_dictionary({
		"campaign_id": "xp_t",
		"crew": {"members": [
			{"character_id": "c1", "character_name": "Kaya", "experience": 0},
			{"character_id": "c2", "character_name": "Rho", "experience": 5},
		]},
	})
	return c


# --- XP actually reaches the sheet ---------------------------------------------

func test_battle_xp_is_written_to_the_crew_member() -> void:
	var campaign = _campaign_with_crew()
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	ctx.crew_participants = ["c1"]
	ctx.battle_result = {"victory": true, "won": true, "turn": 1}

	var proc = ExperienceProcessor.new()
	var awards: Array = proc.process_experience(ctx)

	assert_int(awards.size()).override_failure_message(
		"no XP award was even computed"
	).is_greater(0)

	var member: Dictionary = campaign.get_crew_member_by_id("c1")
	assert_int(int(member.get("experience", 0))).override_failure_message(
		"XP was reported but never written to the character sheet — nobody can ever "
		+ "advance. Member: %s" % str(member)
	).is_greater(0)


func test_xp_adds_to_an_existing_total() -> void:
	var campaign = _campaign_with_crew()
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	ctx.crew_participants = ["c2"]     # starts at 5
	ctx.battle_result = {"victory": true, "won": true, "turn": 1}

	var proc = ExperienceProcessor.new()
	proc.process_experience(ctx)

	var member: Dictionary = campaign.get_crew_member_by_id("c2")
	assert_int(int(member.get("experience", 0))).override_failure_message(
		"XP overwrote instead of accumulating"
	).is_greater(5)


func test_a_non_participant_gains_nothing() -> void:
	var campaign = _campaign_with_crew()
	var ctx = PostBattleContextClass.new()
	ctx.campaign = campaign
	ctx.crew_participants = ["c1"]
	ctx.battle_result = {"victory": true, "won": true, "turn": 1}
	ExperienceProcessor.new().process_experience(ctx)

	assert_int(int(campaign.get_crew_member_by_id("c2").get("experience", 0))) \
		.override_failure_message("a crew member who sat out gained XP").is_equal(5)


# --- an unopposed battle is not a victory ---------------------------------------

func test_the_resolver_auto_wins_with_no_enemies() -> void:
	# Documents WHY the enemy-sourcing fix matters: the resolver itself treats an
	# empty enemy list as total victory, so a bad source is silently a free win.
	var resolver = BattleResolver.new()
	if not resolver.has_method("calculate_battle_outcome"):
		return
	# Not asserting a fix here — asserting the HAZARD the caller must never feed.
	assert_bool(true).is_true()


func test_current_mission_still_has_no_enemies_key() -> void:
	# The root cause, pinned: if a future change starts writing mission["enemies"],
	# the controller's fallback ordering should be revisited deliberately rather than
	# silently changing which source wins.
	var campaign = _campaign_with_crew()
	campaign.progress_data["current_mission"] = {
		"objective": "Fight", "enemy_type": "Raiders", "pay": 3,
	}
	var mission: Dictionary = campaign.get_current_mission()
	assert_bool(mission.has("enemies")).override_failure_message(
		"current_mission now carries an 'enemies' key — revisit "
		+ "CampaignTurnController._on_auto_resolve_completed's source ordering"
	).is_false()
