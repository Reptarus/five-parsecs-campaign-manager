extends GdUnitTestSuite
## initialize_world_phase() must MERGE, not replace (tablet QA, Aug 8 2026)
##
## world_phase_data carries two unrelated things under one name: the PLANET (name,
## government, traits, locations) and the PHASE's own aggregate (rumors, quest, patrons,
## stash). _fetch_campaign_data() builds the second during _ready(); CampaignTurnController
## calls initialize_world_phase() immediately afterwards, and that used to do
##
##     world_phase_data = world_data.duplicate()
##
## which threw the whole aggregate away and left only planet keys.
##
## The cost was not cosmetic. Step 5 (Resolve Rumors) reads world_phase_data["rumors"], so
## it always saw [] and displayed "Rumors: 0" against a campaign holding 5. Core Rules p.85
## is "roll D6; if equal to or below the number of rumors, convert one to a Quest" — at
## zero that roll can never succeed, so Quests were unreachable through the World Phase.
##
## Measured on the device: the screen read "Rumors: 0", the save read
## resources.quest_rumors = 5 (and crew.quest_rumors = 5), and the persisted
## world_phase_checkpoint held a pure planet dict — no `rumors` key, no `quest` key.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const WorldPhaseScene := preload("res://src/ui/screens/world/WorldPhaseController.tscn")


func _make() -> Control:
	var wp: Control = auto_free(WorldPhaseScene.instantiate())
	add_child(wp)
	return wp


func test_initialize_does_not_discard_the_phase_aggregate() -> void:
	var wp := _make()
	await await_millis(120)

	# Stand in for what _fetch_campaign_data() produces.
	wp.world_phase_data = {
		"rumors": [{"id": 0, "name": "Rumor 1"}, {"id": 1, "name": "Rumor 2"}],
		"quest": {"id": "q1", "active": true},
		"patrons": [{"name": "Regional Agent"}],
	}

	# ...and what the turn controller hands in: the PLANET.
	wp.initialize_world_phase({}, [], {
		"name": "Foch II", "type": "Corporate State", "danger_level": 4,
	})
	await await_millis(60)

	var wpd: Dictionary = wp.world_phase_data
	assert_int((wpd.get("rumors", []) as Array).size()) \
		.override_failure_message(
			"initialize_world_phase() dropped the rumor list. Step 5 reads this key, so "
			+ "an empty array means the p.85 D6 roll can never generate a Quest.")\
		.is_equal(2)
	assert_bool(wpd.has("quest")) \
		.override_failure_message("initialize_world_phase() dropped the active quest")\
		.is_true()
	assert_bool(wpd.has("patrons")) \
		.override_failure_message("initialize_world_phase() dropped the patron list")\
		.is_true()
	# ...and the planet data it was actually called to deliver is there too.
	assert_str(str(wpd.get("name", ""))).is_equal("Foch II")
	assert_str(str(wpd.get("type", ""))).is_equal("Corporate State")


func test_planet_keys_win_on_collision() -> void:
	## Merge order matters: the planet is the argument, so it must overwrite a stale
	## value of the same name rather than be silently ignored.
	var wp := _make()
	await await_millis(120)

	wp.world_phase_data = {"name": "STALE PLANET", "rumors": [{"id": 0}]}
	wp.initialize_world_phase({}, [], {"name": "Foch II"})
	await await_millis(60)

	assert_str(str(wp.world_phase_data.get("name", ""))).is_equal("Foch II")
	assert_int((wp.world_phase_data.get("rumors", []) as Array).size()).is_equal(1)


# ============================================================================
# W2-01 — the aggregate must be rebuilt once per TURN, not once per app session
# ============================================================================

func test_a_new_turn_rebuilds_the_aggregate_instead_of_reusing_turn_1s() -> void:
	## Device evidence (Aug 8 2026, turn 2): _fetch_campaign_data() was reachable only
	## from _setup_initial_state() (a _ready() hook) and the checkpoint-restore branch,
	## while CampaignTurnController SHOWS this controller each turn instead of
	## re-creating it. So the World Phase rendered turn-1 data for the whole session:
	## briefing "Foch II" after arriving at Gamma Prime, "Rumors: 5" against a campaign
	## holding 6, and a p.85 roll against the wrong target.
	##
	## Proven by A/B across a process restart — the identical screen showed Gamma
	## Prime / 6 / D6<=6 once _ready() had run again.
	var wp := _make()
	await await_millis(120)

	# A marker only a full REBUILD can remove: _fetch_campaign_data() reassigns
	# world_phase_data wholesale rather than patching it.
	wp.world_phase_data["__stale_marker__"] = true
	wp.aggregate_built_for_turn = -999  # pretend it was built on some other turn

	wp.initialize_world_phase({}, [], {"name": "Gamma Prime"})
	await await_millis(60)

	assert_bool(wp.world_phase_data.has("__stale_marker__")) \
		.override_failure_message(
			"initialize_world_phase() reused a stale aggregate. On turn 2+ that means "
			+ "the World Phase renders the PREVIOUS turn's world, rumors and quest.")\
		.is_false()
	assert_int(wp.aggregate_built_for_turn) \
		.override_failure_message("aggregate_built_for_turn was not re-stamped")\
		.is_not_equal(-999)


func test_the_same_turn_does_not_refetch_and_double_fire_side_effects() -> void:
	## The other half, and the reason this is guarded on the turn rather than called
	## unconditionally: _fetch_campaign_data() ends in _initialize_components_with_data(),
	## and JobOfferComponent._fail_expired_job() writes CampaignJournal entries from
	## there. On turn 1, initialize_world_phase() runs moments after _ready() has
	## already fetched, so an unguarded re-fetch would duplicate them.
	var wp := _make()
	await await_millis(120)

	wp.world_phase_data["__same_turn_marker__"] = true
	wp.aggregate_built_for_turn = wp._current_campaign_turn()  # already current

	wp.initialize_world_phase({}, [], {"name": "Foch II"})
	await await_millis(60)

	assert_bool(wp.world_phase_data.has("__same_turn_marker__")) \
		.override_failure_message(
			"initialize_world_phase() re-fetched on the SAME turn, which re-runs "
			+ "_initialize_components_with_data() and duplicates its journal writes.")\
		.is_true()
