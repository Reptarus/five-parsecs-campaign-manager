extends SceneTree
## HEADLESS Story Track / Introductory Campaign wiring harness.
##
## Run:
##   godot --headless --path <root> --script res://tests/tools/verify_story_track.gd
##
## Companion to verify_post_battle.gd and bound by the SAME rules:
##  * Drives the REAL production classes end to end. Nothing is reimplemented.
##  * Every assertion reads CAMPAIGN / SYSTEM state back after the real call.
##    Return values and log lines prove nothing — in Godot 4.6 a runtime error
##    aborts only the enclosing function and unwinds silently.
##  * All work runs in _process() on frame >= 2, never in _initialize(): under
##    `--script` the autoloads exist but root.is_inside_tree() is false earlier,
##    so every "/root/X" lookup errors.
##  * NOTHING is preload()ed — production files reference bare autoload
##    identifiers that are not registered as GDScript globals under `--script`.
##
## WHY THIS EXISTS: the Story Clock had not ticked in any campaign since
## e4373e137 (Apr 8 2026) and unit tests never noticed, because the suite that
## claimed to cover it was 8 bodies behind `has_method()` guards on methods with
## zero definitions. These rows drive the real post-battle pipeline instead.

# GlobalEnums.gd FiveParsecsCampaignPhase ordinals (written as literals — bare
# GlobalEnums is unavailable under --script; see verify_post_battle.gd note 3).
## GlobalEnums.gd:13-28 — NONE 0, SETUP 1, STORY 2, TRAVEL 3, PRE_MISSION 4,
## MISSION 5, BATTLE_SETUP 6, BATTLE_RESOLUTION 7, POST_MISSION 8, UPKEEP 9.
const PHASE_STORY := 2
const PHASE_MISSION := 5
const PHASE_POST_MISSION := 8
const DIFF_NORMAL := 2

var _frame := 0
var _pass := 0
var _fail := 0

var _gs: Node = null
var _gsm: Node = null
var _cpm: Node = null

var _core_script: GDScript = null
var _normalizer: GDScript = null
var _setup_done := false
var _seq := 0


func _ok(name: String) -> void:
	_pass += 1
	print("PASS %s" % name)

func _bad(name: String, expected: String, got: String) -> void:
	_fail += 1
	print("FAIL %s: expected %s got %s" % [name, expected, got])

func _check(name: String, cond: bool, expected: String, got: String) -> void:
	if cond:
		_ok(name)
	else:
		_bad(name, expected, got)


func _init() -> void:
	print("== verify_story_track: Story Track + Intro Campaign harness ==")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false

	_gs = root.get_node_or_null("/root/GameState")
	_gsm = root.get_node_or_null("/root/GameStateManager")
	_cpm = root.get_node_or_null("/root/CampaignPhaseManager")
	if _gs == null or _gsm == null or _cpm == null:
		print("FAIL harness_bootstrap: missing autoloads gs=%s gsm=%s cpm=%s"
			% [str(_gs), str(_gsm), str(_cpm)])
		quit(2)
		return true

	_core_script = load("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	_normalizer = load("res://src/core/battle/BattleResultNormalizer.gd")

	_row_track_initialises()
	_row_clock_ticks_on_a_win()
	_row_clock_frozen_on_a_story_event_turn()
	_row_story_event_completes_and_resets_clock()
	_row_evidence_reaches_the_track()
	_row_intro_turn_advances()
	_row_training_battle_has_no_consequences()
	_row_bind_campaign_reinitialises()

	print("== verify_story_track: %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
	return true


# ═══════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════

func _member(idx: int) -> Dictionary:
	var cid := "crew_%d" % idx
	var nm := "Crew %d" % idx
	return {
		"character_id": cid, "id": cid,
		"character_name": nm, "name": nm,
		"origin": "human", "species_id": "human",
		"character_class": "Soldier",
		"experience": 0, "level": 1,
		"is_bot": false, "is_dead": false, "is_wounded": false,
		"in_sick_bay": false, "recovery_turns": 0,
		"status": "ACTIVE", "injuries": [], "status_effects": [],
		"combat": 1, "combat_skill": 1,
		"reaction": 2, "reactions": 2,
		"toughness": 4, "speed": 4, "savvy": 0, "luck": 0,
		"equipment": [],
	}


func _make_campaign(tag: String, story_on: bool, intro_on: bool) -> Resource:
	_seq += 1
	var c: Resource = _core_script.new()
	c.campaign_name = "Story Harness " + tag
	# UNIQUE per fixture — bind_campaign early-returns on a matching id
	# (CampaignPhaseManager.gd bind_campaign identity check).
	c.campaign_id = "story_harness_%s_%d" % [tag, _seq]
	c.difficulty = DIFF_NORMAL
	c.campaign_crew_size = 4
	c.credits = 0
	c.story_points = 0
	c.equipment_data = {"equipment": []}
	c.story_track_enabled = story_on
	var members: Array = []
	for i in range(4):
		members.append(_member(i + 1))
	c.initialize_crew({"members": members})
	c.progress_data["turns_played"] = 3
	if intro_on:
		c.progress_data["introductory_campaign"] = true
	return c


func _bind(campaign: Resource) -> void:
	_gs.set_current_campaign(campaign)
	if not _setup_done:
		_cpm.setup(_gs)
		_setup_done = true
	_cpm.bind_campaign(campaign)


## The exact production chain: normalize -> set_battle_results -> start_phase.
func _run_pipeline(campaign: Resource, raw: Dictionary, mission: Dictionary) -> bool:
	var turn: int = int(campaign.progress_data.get("turns_played", 0)) + 1
	var normalized: Dictionary = _normalizer.normalize(raw, mission, turn)
	_gs.set_battle_results(normalized)
	_cpm.current_phase = PHASE_MISSION
	return bool(_cpm.start_phase(PHASE_POST_MISSION))


func _won_battle() -> Dictionary:
	return {
		"success": true, "victory": true, "held_field": true,
		"enemies_defeated_count": 2,
		"crew_participants": [],
		"casualties": [], "injuries_sustained": [],
	}


# ═══════════════════════════════════════════════════════════════════════════
# ROW 1 — the track initialises and persists
#   CampaignPhaseManager._init_story_track() -> save_story_track_state()
# ═══════════════════════════════════════════════════════════════════════════

func _row_track_initialises() -> void:
	var c: Resource = _make_campaign("init", true, false)
	_bind(c)
	var st: Variant = _cpm.story_track
	if st == null:
		_bad("story_track_initialises", "a live StoryTrackSystem", "null")
		return
	var persisted: Dictionary = c.progress_data.get("story_track", {})
	_check("story_track_initialises",
		bool(st.is_story_track_active)
			and int(st.story_clock_ticks) == 5
			and int(persisted.get("story_clock_ticks", -1)) == 5,
		"active track at 5 ticks, persisted to progress_data",
		"active=%s ticks=%d persisted=%s"
			% [str(st.is_story_track_active), int(st.story_clock_ticks),
				str(persisted.get("story_clock_ticks"))])


# ═══════════════════════════════════════════════════════════════════════════
# ROW 2 — the clock counts down after a won battle (Core Rules p.153)
#   THE headline regression: StoryTrackProcessor is the restored caller of
#   advance_clock_end_of_turn(), which had zero callers for four months.
# ═══════════════════════════════════════════════════════════════════════════

func _row_clock_ticks_on_a_win() -> void:
	var c: Resource = _make_campaign("tick", true, false)
	_bind(c)
	var st: Variant = _cpm.story_track
	if st == null:
		_bad("clock_ticks_on_a_win", "a live track", "null")
		return
	var before: int = int(st.story_clock_ticks)
	_run_pipeline(c, _won_battle(), {"mission_source": "opportunity"})
	var after: int = int(st.story_clock_ticks)
	var persisted: int = int(
		c.progress_data.get("story_track", {}).get("story_clock_ticks", -1))
	_check("clock_ticks_on_a_win",
		after == before - 1 and persisted == after,
		"clock %d -> %d and persisted" % [before, before - 1],
		"after=%d persisted=%d" % [after, persisted])


# ═══════════════════════════════════════════════════════════════════════════
# ROW 3 — the clock does NOT tick on a Story Event turn (p.153)
#   Guards the if/else in StoryTrackProcessor: apply_post_battle() clears
#   is_story_event_turn internally, so running both paths would tick illegally.
# ═══════════════════════════════════════════════════════════════════════════

func _row_clock_frozen_on_a_story_event_turn() -> void:
	var c: Resource = _make_campaign("frozen", true, false)
	_bind(c)
	var st: Variant = _cpm.story_track
	if st == null:
		_bad("clock_frozen_on_a_story_event_turn", "a live track", "null")
		return
	st.is_story_event_turn = true
	_run_pipeline(c, _won_battle(), {
		"mission_source": "story_track",
		"is_story_battle": true,
		"story_event_id": "foiled",
		"story_event_number": 1,
	})
	# EXACT value, not "!= before - 1". The weaker form was a FALSE PASS: it also
	# held when the whole step no-opped, which is exactly what was happening while
	# this harness used the wrong phase ordinals.
	#
	# On a Story Event turn apply_post_battle() runs and SETS the clock from the
	# event (event_01_foiled.json -> 3). If the orchestrator wrongly ran the tick
	# path too, apply_post_battle() would have cleared is_story_event_turn first
	# and advance_clock_end_of_turn() would knock that 3 down to 2. So 3 proves
	# the if/else; 2 proves the p.153 violation.
	_check("clock_frozen_on_a_story_event_turn",
		int(st.story_clock_ticks) == 3,
		"clock set to the event's 3 ticks and NOT also decremented (p.153)",
		str(int(st.story_clock_ticks)))


# ═══════════════════════════════════════════════════════════════════════════
# ROW 4 — a Story Event battle completes the event and resets the clock
#   Also proves the JSON float fix: next_clock_ticks parsed as float meant
#   `clock_val is int` was always false and every event set the clock to 0.
# ═══════════════════════════════════════════════════════════════════════════

func _row_story_event_completes_and_resets_clock() -> void:
	var c: Resource = _make_campaign("advance", true, false)
	_bind(c)
	var st: Variant = _cpm.story_track
	if st == null:
		_bad("story_event_completes_and_resets_clock", "a live track", "null")
		return
	st.is_story_event_turn = true
	var first_id: String = str(st.get_current_event().event_id)
	_run_pipeline(c, _won_battle(), {
		"mission_source": "story_track",
		"is_story_battle": true,
		"story_event_id": first_id,
		"story_event_number": 1,
	})
	var persisted: Dictionary = c.progress_data.get("story_track", {})
	_check("story_event_completes_and_resets_clock",
		int(st.current_event_index) == 1
			and first_id in st.completed_event_ids
			and int(st.story_clock_ticks) == 3
			and int(persisted.get("current_event_index", -1)) == 1,
		"event 1 completed, index 1, clock reset to 3 (p.153), persisted",
		"index=%d completed=%s ticks=%d persisted_index=%s"
			% [int(st.current_event_index), str(st.completed_event_ids),
				int(st.story_clock_ticks),
				str(persisted.get("current_event_index"))])


# ═══════════════════════════════════════════════════════════════════════════
# ROW 5 — Event 5 Evidence survives the battle boundary (p.157)
#   StoryMarkerPanel -> mission_data -> BattleResultNormalizer ->
#   StoryTrackProcessor -> StoryTrackSystem.add_evidence().
# ═══════════════════════════════════════════════════════════════════════════

func _row_evidence_reaches_the_track() -> void:
	var c: Resource = _make_campaign("evidence", true, false)
	_bind(c)
	var st: Variant = _cpm.story_track
	if st == null:
		_bad("evidence_reaches_the_track", "a live track", "null")
		return
	var before: int = int(st.evidence_pieces)
	_run_pipeline(c, _won_battle(), {
		"mission_source": "story_track",
		"story_evidence_found": 2,
	})
	_check("evidence_reaches_the_track",
		int(st.evidence_pieces) == before + 2,
		"evidence %d -> %d" % [before, before + 2],
		str(int(st.evidence_pieces)))


# ═══════════════════════════════════════════════════════════════════════════
# ROW 6 — the Introductory Campaign turn advances (Compendium pp.104-109)
#   advance_turn() had zero callers, so the intro sat on turn 0 forever and
#   its `pre_battle_enabled: []` skipped every World Phase step but MISSION_PREP.
# ═══════════════════════════════════════════════════════════════════════════

func _row_intro_turn_advances() -> void:
	# The Introductory Campaign sits behind ContentFlag.INTRODUCTORY_CAMPAIGN
	# (Fixer's Guidebook). Grant it for the harness, otherwise this row silently
	# skips and the P0 it guards — the intro frozen on turn 0, which strips every
	# World Phase step but MISSION_PREP — goes unverified.
	var dlc: Node = root.get_node_or_null("/root/DLCManager")
	if dlc and dlc.has_method("set_feature_enabled"):
		dlc.set_feature_enabled(dlc.ContentFlag.INTRODUCTORY_CAMPAIGN, true)

	var c: Resource = _make_campaign("intro", false, true)
	_bind(c)
	var intro: Variant = _cpm.intro_campaign
	if intro == null:
		_bad("intro_turn_advances",
			"an active intro campaign after granting the DLC flag", "null")
		return
	var before: int = int(intro.current_intro_turn)
	_run_pipeline(c, _won_battle(), {"mission_source": "introductory"})
	var persisted: Dictionary = c.progress_data.get("intro_campaign_state", {})
	_check("intro_turn_advances",
		int(intro.current_intro_turn) == before + 1
			and int(persisted.get("current_intro_turn",
				persisted.get("current_turn", -1))) == before + 1,
		"intro turn %d -> %d and persisted" % [before, before + 1],
		"turn=%d persisted=%s"
			% [int(intro.current_intro_turn), str(persisted)])


# ═══════════════════════════════════════════════════════════════════════════
# ROW 7 — the Training Battle really has no consequences (Compendium p.104)
#   "No experience points or other post-battle functions are carried out."
#   `post_battle_enabled: []` on intro turn 0 was authored from that line and
#   read by NOTHING, so a tutorial crew took full pay, loot, injuries and XP on
#   the one battle the book says costs and grants nothing.
# ═══════════════════════════════════════════════════════════════════════════

func _row_training_battle_has_no_consequences() -> void:
	var dlc: Node = root.get_node_or_null("/root/DLCManager")
	if dlc and dlc.has_method("set_feature_enabled"):
		dlc.set_feature_enabled(dlc.ContentFlag.INTRODUCTORY_CAMPAIGN, true)

	var c: Resource = _make_campaign("training", false, true)
	_bind(c)
	if _cpm.intro_campaign == null:
		_bad("training_battle_has_no_consequences", "an active intro", "null")
		return
	# Fresh intro starts on turn 0 — the Training Battle.
	_check("training_battle_starts_on_turn_0",
		int(_cpm.intro_campaign.current_intro_turn) == 0,
		"intro turn 0", str(int(_cpm.intro_campaign.current_intro_turn)))

	var credits_before: int = int(c.credits)
	var xp_before: int = int(c.crew_data["members"][0].get("experience", 0))

	var raw: Dictionary = _won_battle()
	raw["crew_participants"] = [{
		"character_id": c.crew_data["members"][0]["character_id"],
		"id": c.crew_data["members"][0]["id"],
	}]
	_run_pipeline(c, raw, {"mission_source": "introductory"})

	var xp_after: int = int(c.crew_data["members"][0].get("experience", 0))
	_check("training_battle_has_no_consequences",
		int(c.credits) == credits_before and xp_after == xp_before,
		"no credits and no XP from the Training Battle (Compendium p.104)",
		"credits %d->%d xp %d->%d"
			% [credits_before, int(c.credits), xp_before, xp_after])


# ═══════════════════════════════════════════════════════════════════════════
# ROW 8 — loading a second campaign re-initialises the track
#   CampaignPhaseManager is an AUTOLOAD; _init_story_track() used to run only
#   from setup() (once per app session), so campaign B inherited campaign A's
#   story_track object — or A's null.
# ═══════════════════════════════════════════════════════════════════════════

func _row_bind_campaign_reinitialises() -> void:
	var a: Resource = _make_campaign("switch_on", true, false)
	_bind(a)
	var had_track: bool = _cpm.story_track != null

	var b: Resource = _make_campaign("switch_off", false, false)
	_bind(b)
	var cleared: bool = _cpm.story_track == null

	var d: Resource = _make_campaign("switch_back_on", true, false)
	_bind(d)
	var restored: bool = _cpm.story_track != null \
		and bool(_cpm.story_track.is_story_track_active)

	_check("bind_campaign_reinitialises",
		had_track and cleared and restored,
		"track present for A, null for story-off B, live again for C",
		"A=%s B_cleared=%s C=%s" % [str(had_track), str(cleared), str(restored)])
