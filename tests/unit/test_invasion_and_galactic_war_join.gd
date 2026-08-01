extends GdUnitTestSuite
## Flee Invasion (Core Rules p.69) -> Galactic War Progress (p.126 step 14).
##
## THE JOIN THAT WAS SEVERED. GalacticWarProcessor implements the p.126 2D6
## table faithfully and opens with `if invaded_planets.is_empty(): return`.
## The ONLY thing that ever appended to that list was
## FiveParsecsCampaignCore.record_invaded_planet(), whose ONLY caller lived in
## src/core/campaign/phases/TravelPhase.gd — a file with zero instantiations
## anywhere in src/. So the list was permanently empty, the step returned at its
## own guard every single turn, and the Galactic War table has never rolled in a
## real campaign. Travel actually happens in UpkeepPhaseComponent, which now
## records the world when the p.69 flee roll resolves.

const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const GalacticWarProcessorScript = preload(
	"res://src/core/campaign/phases/post_battle/GalacticWarProcessor.gd")
const ContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

class StubGameState:
	var current_campaign: Resource = null

func _ctx_for(core: Resource) -> ContextClass:
	var c: ContextClass = ContextClass.new()
	c.campaign = core
	var gs := StubGameState.new()
	gs.current_campaign = core
	c.game_state = gs
	c.battle_result = {}
	return c

# ── The recorder ─────────────────────────────────────────────────────────

func test_recording_an_invaded_world_populates_the_tracked_list() -> void:
	var core: Resource = CampaignCoreScript.new()
	assert_array(core.invaded_planets).is_empty()
	assert_bool(core.record_invaded_planet("planet_7", "Kestrel")).is_true()
	assert_int((core.invaded_planets as Array).size()).is_equal(1)
	assert_str(str((core.invaded_planets[0] as Dictionary).get("name", ""))).is_equal("Kestrel")

func test_recording_the_same_world_twice_is_idempotent() -> void:
	# A world is tracked once; a second invasion of the same place must not
	# double its entry (and so double its 2D6 roll).
	var core: Resource = CampaignCoreScript.new()
	core.record_invaded_planet("planet_7", "Kestrel")
	assert_bool(core.record_invaded_planet("planet_7", "Kestrel")).is_false()
	assert_int((core.invaded_planets as Array).size()).is_equal(1)

func test_an_empty_planet_id_is_refused() -> void:
	var core: Resource = CampaignCoreScript.new()
	assert_bool(core.record_invaded_planet("", "")).is_false()
	assert_array(core.invaded_planets).is_empty()

# ── The join itself ──────────────────────────────────────────────────────

func test_galactic_war_returns_nothing_when_no_world_is_tracked() -> void:
	# The state every campaign was permanently stuck in.
	var core: Resource = CampaignCoreScript.new()
	var proc = GalacticWarProcessorScript.new()
	var progress: Dictionary = proc.process_galactic_war(_ctx_for(core))
	assert_int(int(progress.get("conflicts_active", -1))).is_equal(0)

func test_a_recorded_world_makes_the_p126_table_roll() -> void:
	# The whole point: once travel records the invasion, step 14 has something
	# to roll for. Without record_invaded_planet() being called from a LIVE
	# code path, this can never be reached.
	var core: Resource = CampaignCoreScript.new()
	core.record_invaded_planet("planet_7", "Kestrel")
	var proc = GalacticWarProcessorScript.new()
	var progress: Dictionary = proc.process_galactic_war(_ctx_for(core))
	assert_int(int(progress.get("conflicts_active", 0))).override_failure_message(
		"p.126 step 14 must roll for each tracked Invaded world").is_equal(1)
	assert_int((progress.get("planet_results", []) as Array).size()).is_equal(1)

func test_each_tracked_world_gets_its_own_roll() -> void:
	var core: Resource = CampaignCoreScript.new()
	core.record_invaded_planet("planet_7", "Kestrel")
	core.record_invaded_planet("planet_9", "Bishop's Reach")
	var proc = GalacticWarProcessorScript.new()
	var progress: Dictionary = proc.process_galactic_war(_ctx_for(core))
	assert_int(int(progress.get("conflicts_active", 0))).is_equal(2)

# ── The forced-battle hand-off ───────────────────────────────────────────

func test_a_failed_escape_produces_a_mission_the_battle_funnel_recognises() -> void:
	# p.69: a failed flee roll means "you MUST fight an Invasion Battle". The
	# hand-off works only if the mission is shaped so BattleSetupRules.is_invasion()
	# says yes — that one key is what gates no-payment (p.120), no Battlefield
	# Finds (p.120), no Loot (p.121) and the p.119 Rival-status skip.
	var SetupRules = load("res://src/core/battle/BattleSetupRules.gd")
	var forced: Dictionary = {
		"source": "invasion", "mission_source": "invasion", "is_invasion": true,
	}
	assert_bool(SetupRules.is_invasion(forced)).override_failure_message(
		"a forced invasion mission must be recognised as one by the battle funnel"
	).is_true()
	# p.92: Invasion opponents always have one additional enemy.
	var bundle: Dictionary = SetupRules.compute(forced, 5, 5)
	assert_int(int(bundle["enemy_delta"])).is_equal(1)
	assert_int(int(bundle["hold_rounds"])).is_equal(SetupRules.INVASION_HOLD_ROUNDS)
