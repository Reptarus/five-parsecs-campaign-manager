extends SceneTree
## HEADLESS post-battle / campaign-state verification harness.
##
## Run:
##   godot --headless --path <root> --script res://tests/tools/verify_post_battle.gd
##
## ── RULES OF THIS HARNESS ────────────────────────────────────────────────────
##  * Drives the REAL production classes. No logic is reimplemented here.
##  * EVERY assertion reads the CAMPAIGN RESOURCE (or the canonical owner it
##    delegates to) back AFTER the call. Asserting on a log line, a label, a
##    return value or a signal payload is FORBIDDEN — those are exactly what hid
##    the ~33 defects fixed on 2026-07-29. In Godot 4.6 a runtime error (invalid
##    call / bad cast / wrong-typed assign) ABORTS only the enclosing function and
##    unwinds silently, so a populated return value proves nothing.
##  * Every check: capture BEFORE, run the real call, read AFTER, compare.
##
## ── HARNESS CONSTRAINTS (empirically established, do not "simplify") ─────────
##  1. All work runs in _process() on frame >= 2, NEVER in _initialize().
##     Under `--script` the 34 autoloads ARE instantiated, but root.is_inside_tree()
##     is false during _initialize(), so every "/root/X" lookup errors. Frame 2 also
##     lets GameStateManager's call_deferred("_connect_campaign_signals")
##     (GameStateManager.gd:48 -> :56) assign gsm.game_state — without it,
##     set_credits() (GameStateManager.gd:110-116) never writes campaign.credits.
##  2. NOTHING is preload()ed. PostBattlePhase.gd:90 (`DiceManager`),
##     CampaignTurnController.gd:438/1703 (`GameState`) and
##     CampaignFinalizationService.gd:348 (`GameStateManager`) reference bare
##     autoload identifiers, which are NOT registered as GDScript globals when a
##     --script main loop is compiled. preload() there yields an uncompiled
##     GDScript ("Nonexistent function 'new' in base 'GDScript'"). Runtime load()
##     from inside _process() is compiled after registration and works.
##  3. Bare `GlobalEnums.X` is likewise avoided; phase/difficulty ordinals are
##     written as literals with their source citation.

# ── Enum ordinals (GlobalEnums.gd:31-46 FiveParsecsCampaignPhase; ordinal-synced
#    with GameEnums.gd FiveParcsecsCampaignPhase) ──────────────────────────────
## Fixed seed for full-pipeline rows so steps 12/13 (campaign + character
## events) are reproducible. Any value works; this one is pinned so a failure is
## always a real regression and never a dice roll.
const PIPELINE_SEED := 20260729

const PHASE_NONE := 0
const PHASE_SETUP := 1
const PHASE_MISSION := 5
const PHASE_POST_MISSION := 8
const PHASE_UPKEEP := 9
# GlobalEnums.gd:136-146 DifficultyLevel {NONE=0, EASY=1, NORMAL=2, ...}
const DIFF_NONE := 0
const DIFF_NORMAL := 2

var _frame := 0
var _pass := 0
var _fail := 0
var _skip := 0

var _gs: Node = null
var _gsm: Node = null
var _cpm: Node = null
var _journal: Node = null
var _pdm: Node = null
var _equip: Node = null

var _core_script: GDScript = null
var _normalizer: GDScript = null
var _ctx_script: GDScript = null
var _ctc_script: GDScript = null
var _final_script: GDScript = null
var _char_script: GDScript = null

var _setup_done := false
var _campaign_seq := 0

# ═══════════════════════════════════════════════════════════════════════════════
# Result reporting
# ═══════════════════════════════════════════════════════════════════════════════

func _ok(name: String) -> void:
	_pass += 1
	print("PASS %s" % name)

func _bad(name: String, expected: String, got: String) -> void:
	_fail += 1
	print("FAIL %s: expected %s got %s" % [name, expected, got])

func _skipped(name: String, reason: String) -> void:
	_skip += 1
	print("SKIP %s: %s" % [name, reason])

func _check(name: String, cond: bool, expected: String, got: String) -> void:
	if cond:
		_ok(name)
	else:
		_bad(name, expected, got)

# ═══════════════════════════════════════════════════════════════════════════════
# Entry
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	print("== verify_post_battle: campaign-state harness ==")

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false

	_gs = root.get_node_or_null("/root/GameState")
	_gsm = root.get_node_or_null("/root/GameStateManager")
	_cpm = root.get_node_or_null("/root/CampaignPhaseManager")
	_journal = root.get_node_or_null("/root/CampaignJournal")
	_pdm = root.get_node_or_null("/root/PlanetDataManager")
	_equip = root.get_node_or_null("/root/EquipmentManager")

	if _gs == null or _cpm == null or _gsm == null:
		print("FAIL harness_bootstrap: expected GameState+GameStateManager+"
			+ "CampaignPhaseManager autoloads got gs=%s gsm=%s cpm=%s"
			% [str(_gs), str(_gsm), str(_cpm)])
		quit(2)
		return true

	_core_script = load("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	_normalizer = load("res://src/core/battle/BattleResultNormalizer.gd")
	_ctx_script = load(
		"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
	_ctc_script = load("res://src/ui/screens/campaign/CampaignTurnController.gd")
	_final_script = load(
		"res://src/core/campaign/creation/CampaignFinalizationService.gd")
	_char_script = load("res://src/core/character/Character.gd")

	# Seed a current world so journal location resolution has an authority.
	if _pdm and _pdm.has_method("upsert_current_world"):
		_pdm.upsert_current_world({
			"id": "world_harness", "name": "Kepler Reach",
			"traits": [], "locations": [],
		}, 3)

	_row_crew_xp()
	_row_xp_index_shift()
	_row_casualty_outcome()
	_row_loot_to_stash()
	_row_payment_credits()
	_row_journal_battle_entry()
	_row_journal_casualties_array_direct()
	_row_journal_chokepoint_fallback()
	_row_router_derives_defeated_enemies()
	_row_rival_removed()
	_row_auto_resolve()
	_row_black_zone_casualty_pay()
	_row_bitter_day_story_point()
	_row_crew_dict_dual_reaction_key()
	_row_difficulty_none_fallback()
	_row_campaign_event_effect_reaches_campaign()
	_row_luck_death_save()
	_row_turn_rollover_mechanics()
	_row_save_load_round_trip()

	print("\n================ RESULT ================")
	print("passed=%d failed=%d skipped=%d" % [_pass, _fail, _skip])
	if _fail > 0:
		print("HARNESS RESULT: FAIL")
		quit(1)
	elif _skip > 0:
		print("HARNESS RESULT: PASS (with %d SKIP — a SKIP is NOT a pass)" % _skip)
		quit(0)
	else:
		print("HARNESS RESULT: PASS")
		quit(0)
	return true

# ═══════════════════════════════════════════════════════════════════════════════
# Fixture — crew members are DICTIONARIES (the canonical crew_data["members"]
# shape per the data-ownership table, and the shape every one of these bugs hid
# behind). Keys mirror Character.to_dictionary() (Character.gd:1281-1326) dual
# id/name aliases plus every key the post-battle chain reads.
# ═══════════════════════════════════════════════════════════════════════════════

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
		"weapon": {"name": "Hand Gun", "range": 12, "shots": 1,
			"damage": 1, "traits": []},
	}

func _make_campaign(tag: String, crew_n: int) -> Resource:
	_campaign_seq += 1
	var c: Resource = _core_script.new()
	c.campaign_name = "Harness " + tag
	# UNIQUE per fixture: bind_campaign early-returns on a matching id
	# (CampaignPhaseManager.gd:125-127).
	c.campaign_id = "harness_%s_%d" % [tag, _campaign_seq]
	c.difficulty = DIFF_NORMAL
	c.campaign_crew_size = 6
	c.credits = 0
	c.story_points = 0
	c.equipment_data = {"equipment": []}
	var members: Array = []
	for i in range(crew_n):
		members.append(_member(i + 1))
	c.initialize_crew({"members": members})
	c.progress_data["turns_played"] = 3
	return c

func _bind(campaign: Resource) -> void:
	# set_current_campaign (GameState.gd:270) also emits campaign_loaded, which
	# resyncs the GameStateManager credit mirror from the campaign owner.
	_gs.set_current_campaign(campaign)
	if not _setup_done:
		# setup() is what constructs AND add_child()s the PostBattlePhase handler
		# (CampaignPhaseManager.gd:79-87). Without it start_phase(POST_MISSION)
		# silently no-ops at :1079.
		_cpm.setup(_gs)
		_setup_done = true
	_cpm.bind_campaign(campaign)

func _members(campaign: Resource) -> Array:
	return campaign.crew_data["members"]

func _find(campaign: Resource, cid: String) -> Dictionary:
	for m in _members(campaign):
		if m is Dictionary and str(m.get("character_id", "")) == cid:
			return m
	return {}

func _participants(campaign: Resource, idxs: Array) -> Array:
	# ExperienceTrainingProcessor.gd:62-67 has NO Object branch — a Character
	# Resource participant yields an empty crew_id and is skipped at :69-70.
	var out: Array = []
	for i in idxs:
		var m: Dictionary = _members(campaign)[i]
		out.append({"character_id": m["character_id"], "id": m["id"]})
	return out

## The exact production call chain: normalize -> set_battle_results -> start_phase.
## (CampaignTurnController.gd:953/974-975 then :996.)
func _run_pipeline(campaign: Resource, raw: Dictionary, mission: Dictionary,
		rng_seed: int = 0) -> bool:
	# OPT-IN seeding (0 = leave the RNG alone).
	#
	# The full pipeline runs steps 12/13 (campaign event and character event) as
	# free-running D100 rolls, and some outcomes grant XP — Core Rules p.126 event
	# 64-66 is "Every crew member receives +1 XP". Unseeded, a row expecting
	# exactly +3 flaked ~1 run in 5 when that event came up. A flaky harness is
	# worse than none: it trains you to re-run until green, which is exactly how a
	# real regression gets waved through.
	#
	# It must be OPT-IN, not a default: the injury and rival rows deliberately
	# SWEEP seeds to force both the fatal and the Sick Bay branch, and an
	# unconditional seed here clobbered their sweep and made 5 rows fail
	# deterministically. Only rows asserting an exact value pass a seed.
	if rng_seed != 0:
		seed(rng_seed)
	var turn: int = int(campaign.progress_data.get("turns_played", 0)) + 1
	var normalized: Dictionary = _normalizer.normalize(raw, mission, turn)
	_gs.set_battle_results(normalized)
	# _can_transition_to_phase gates POST_MISSION on {BATTLE_RESOLUTION, MISSION}
	# (CampaignPhaseManager.gd:958-960).
	_cpm.current_phase = PHASE_MISSION
	return bool(_cpm.start_phase(PHASE_POST_MISSION))

## Handler for the ISOLATED sub-step entrypoints. Reuses the SAME real objects the
## orchestrator builds (CampaignPhaseManager.gd:1098 get_phase_handler).
func _handler_with(campaign: Resource, raw: Dictionary, mission: Dictionary,
		participants: Array) -> Node:
	var h: Node = _cpm.get_phase_handler("post_battle")
	if h == null:
		return null
	var turn: int = int(campaign.progress_data.get("turns_played", 0)) + 1
	var normalized: Dictionary = _normalizer.normalize(raw, mission, turn)
	h._ensure_subsystems()
	h.set_campaign(campaign)
	h.battle_result = normalized
	h.mission_successful = bool(normalized.get("success", false))
	h.crew_participants = participants
	h.defeated_enemies = normalized.get("defeated_enemies", [])
	h.injuries_sustained = normalized.get("injuries_sustained", [])
	h.loot_earned = []
	h.enemies_defeated = int(normalized.get("enemies_defeated_count", 0))
	h._sync_context()
	return h

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 1 — crew XP increases after a battle
#   Write path under test: ExperienceTrainingProcessor.gd:136 ->
#   PostBattleContext.gd:494-508. Exact +3 = xp_awards.survived_won_battle
#   (data/injury_results.json, consumed at ExperienceTrainingProcessor.gd:275)
#   plus difficulty xp_bonus 0 at NORMAL.
# ═══════════════════════════════════════════════════════════════════════════════

func _row_crew_xp() -> void:
	var name := "crew_xp_all_participants_gained_3"
	var campaign: Resource = _make_campaign("xp", 5)
	_bind(campaign)

	var before: Array[int] = []
	for m in _members(campaign):
		before.append(int(m["experience"]))

	var ok: bool = _run_pipeline(campaign, {
		"success": true, "victory": true, "won": true, "held_field": true,
		"crew_participants": _participants(campaign, [0, 1, 2, 3, 4]),
		"crew_injuries_data": [], "crew_casualties_data": [],
		"enemies_defeated_count": 3, "defeated_enemies": [],
		"enemy_type": "Raiders",
	}, {"mission_source": "opportunity"}, PIPELINE_SEED)
	if not ok:
		_bad(name, "start_phase(POST_MISSION) accepted", "transition refused")
		return

	# STATE ASSERTION — read the campaign Resource back.
	var bad: Array[String] = []
	for i in range(_members(campaign).size()):
		var m: Dictionary = _members(campaign)[i]
		var after: int = int(m["experience"])
		if after != before[i] + 3:
			bad.append("%s %d->%d" % [str(m["character_id"]), before[i], after])
	_check(name, bad.is_empty(),
		"every one of 5 crew +3 XP on campaign.crew_data[members]",
		"deviations: " + str(bad))

## Index-shift guard: a NON-participant must not gain XP, and the participants
## must still land on the RIGHT members (crew_3 skipped deliberately).
func _row_xp_index_shift() -> void:
	var name := "crew_xp_non_participant_untouched"
	var campaign: Resource = _make_campaign("xpshift", 5)
	_bind(campaign)

	var ok: bool = _run_pipeline(campaign, {
		"success": true, "victory": true, "won": true, "held_field": true,
		"crew_participants": _participants(campaign, [0, 1, 3, 4]),  # index 2 skipped
		"crew_injuries_data": [], "crew_casualties_data": [],
		"enemies_defeated_count": 1, "defeated_enemies": [],
		"enemy_type": "Raiders",
	}, {"mission_source": "opportunity"}, PIPELINE_SEED)
	if not ok:
		_bad(name, "start_phase(POST_MISSION) accepted", "transition refused")
		return

	var got: Array[int] = []
	for m in _members(campaign):
		got.append(int(m["experience"]))
	var want: Array[int] = [3, 3, 0, 3, 3]
	_check(name, got == want, "[3,3,0,3,3] (index 2 never fought)", str(got))

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 2 — a casualty actually enters Sick Bay or dies
#   InjuryProcessor.gd:82-84 only looks the crew member UP when the injury element
#   carries NO origin. Both element shapes are producible by the real normalizer
#   (BattleResultNormalizer.gd:99 emits "" when the producer character has neither
#   origin nor species), and ONLY the origin-absent shape exercises the
#   crew-member branch at InjuryProcessor.gd:84-106. Drive both or be blind to half.
#   Injury roll is randi_range(1,100) on the GLOBAL rng (InjuryProcessor.gd:119),
#   so seed(n) makes each trial reproducible.
#   Bands (data/injury_results.json via InjurySystemConstants.gd:326-331):
#     1-15 fatal | 31-80 recovery>0 (Sick Bay) | 16-30 + 81-100 recovery 0.
# ═══════════════════════════════════════════════════════════════════════════════

func _row_casualty_outcome() -> void:
	_casualty_variant("casualty_outcome_origin_present", true)
	_casualty_variant("casualty_outcome_origin_absent", false)

func _casualty_variant(name: String, with_origin: bool) -> void:
	var trials := 40
	var dead := 0
	var sickbay := 0
	var logged_only := 0
	var nothing: Array[String] = []

	for s in range(1, trials + 1):
		seed(s * 7919)
		var campaign: Resource = _make_campaign(
			"inj_%s_%d" % [str(with_origin), s], 5)
		_bind(campaign)
		var victim: Dictionary = _members(campaign)[2]  # middle of 5
		var producer: Dictionary = {
			"character_id": victim["character_id"], "id": victim["id"],
			"character_name": victim["character_name"], "name": victim["name"],
		}
		if with_origin:
			producer["origin"] = "human"
			producer["species_id"] = "human"

		var ok: bool = _run_pipeline(campaign, {
			"success": false, "victory": false, "won": false, "held_field": true,
			"crew_participants": _participants(campaign, [0, 1, 2, 3, 4]),
			"crew_injuries_data": [producer], "crew_casualties_data": [],
			"defeated_enemies": [], "enemy_type": "Raiders",
		}, {"mission_source": "opportunity"})
		if not ok:
			nothing.append("seed %d: transition refused" % s)
			continue

		var m: Dictionary = _find(campaign, str(victim["character_id"]))
		if m.is_empty():
			nothing.append("seed %d: crew member vanished" % s)
			continue
		var is_dead: bool = str(m.get("status", "")) == "DEAD" \
			and bool(m.get("is_dead", false))
		var in_bay: bool = bool(m.get("in_sick_bay", false)) \
			and int(m.get("recovery_turns", 0)) > 0
		var has_injury: bool = (m.get("injuries", []) as Array).size() > 0
		if is_dead:
			dead += 1
		elif in_bay and has_injury:
			sickbay += 1
		elif has_injury:
			logged_only += 1
		else:
			nothing.append("seed %d: status=%s sick=%s rec=%s injuries=%d"
				% [s, str(m.get("status")), str(m.get("in_sick_bay")),
					str(m.get("recovery_turns")),
					(m.get("injuries", []) as Array).size()])

	print("  [%s] dead=%d sick_bay=%d injury_logged=%d NOTHING=%d"
		% [name, dead, sickbay, logged_only, nothing.size()])
	_check(name + "_no_silent_noop", nothing.is_empty(),
		"0 of %d injury rolls leave the crew member unmutated" % trials,
		"%d unmutated (%s)" % [nothing.size(), str(nothing.slice(0, 3))])
	_check(name + "_fatal_branch_live", dead > 0,
		"at least 1 fatal roll writes status=DEAD across %d seeds (~15%%)" % trials,
		"dead=%d" % dead)
	_check(name + "_sickbay_branch_live", sickbay > 0,
		"at least 1 roll sets in_sick_bay + recovery_turns (~50%%)",
		"sick_bay=%d" % sickbay)

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 3 — loot reaches the ship stash (Core Rules p.120)
#   ISOLATED sub-step: the full pipeline's payment step also grants credits and the
#   REWARDS loot branch feeds credits, so isolate the loot step to keep the stash
#   read exact. Same real objects the orchestrator built.
#   FORBIDDEN: asserting on the Array returned by process_loot_gathering() or on
#   loot_gathered — the original defect returned a fully populated array while
#   nothing reached the stash (LootProcessor.gd:83-96).
# ═══════════════════════════════════════════════════════════════════════════════

func _loot_trial(tag: String, s: int, extra: Dictionary) -> Array:
	## Returns [stash_size, campaign, stash_array]
	if _equip and _equip.has_method("clear_all_equipment"):
		_equip.clear_all_equipment()
	var campaign: Resource = _make_campaign("%s_%d" % [tag, s], 5)
	_bind(campaign)
	if _equip and _equip.has_method("clear_all_equipment"):
		_equip.clear_all_equipment()  # also clears the now-current campaign stash
	campaign.equipment_data["equipment"] = []
	var raw: Dictionary = {
		"success": true, "victory": true, "won": true, "held_field": true,
		"crew_participants": _participants(campaign, [0, 1, 2, 3, 4]),
		"crew_injuries_data": [], "crew_casualties_data": [],
		"defeated_enemies": [], "enemy_type": "Raiders",
	}
	raw.merge(extra, true)
	var h: Node = _handler_with(campaign, raw, {"mission_source": "opportunity"},
		_participants(campaign, [0, 1, 2, 3, 4]))
	if h == null:
		return []
	seed(s * 104729)
	h._loot.process_loot_gathering(h._ctx)
	var stash: Array = campaign.equipment_data["equipment"]
	return [stash.size(), campaign, stash]

func _row_loot_to_stash() -> void:
	if _equip == null:
		_skipped("loot_reaches_ship_stash", "EquipmentManager autoload missing")
		return
	if _cpm.get_phase_handler("post_battle") == null:
		_skipped("loot_reaches_ship_stash", "post_battle handler unavailable")
		return

	var seeds := 30
	var total := 0
	var shape_errors: Array[String] = []
	var last_campaign: Resource = null
	for s in range(1000, 1000 + seeds):
		var r: Array = _loot_trial("loot", s, {})
		if r.is_empty():
			continue
		total += int(r[0])
		last_campaign = r[1]
		var stash: Array = r[2]
		var ids: Dictionary = {}
		for item in stash:
			if not (item is Dictionary):
				shape_errors.append("seed %d: non-dict stash element" % s)
				continue
			var iid: String = str(item.get("id", ""))
			if iid.is_empty():
				shape_errors.append("seed %d: item with empty id" % s)
			if ids.has(iid):
				shape_errors.append("seed %d: duplicate id %s" % [s, iid])
			ids[iid] = true
			if str(item.get("name", "")).is_empty():
				shape_errors.append("seed %d: item with empty name" % s)
			if str(item.get("location", "")) != "ship_stash":
				shape_errors.append("seed %d: location=%s"
					% [s, str(item.get("location", ""))])

	print("  [loot] %d seeds produced %d stashed items" % [seeds, total])
	# REWARDS is the only non-stash outcome (20%% of the p.130 D100 main table,
	# data/loot_tables.json roll_range [81,100]); >= 20 over 30 rolls is a very
	# loose lower bound that still fails hard if the write path is dead.
	_check("loot_reaches_ship_stash", total >= 20,
		">=20 items in campaign.equipment_data[equipment] over 30 loot rolls",
		"total=%d" % total)
	_check("loot_item_shape_one_item_one_home", shape_errors.is_empty(),
		"every stashed item has non-empty id+name and location=ship_stash, ids unique",
		str(shape_errors.slice(0, 3)))

	# Owner and manager must agree (EquipmentManager.gd:387-393 is owner-backed).
	if last_campaign != null:
		var owner_n: int = (last_campaign.equipment_data["equipment"] as Array).size()
		var mgr_n: int = (_equip.get_ship_stash() as Array).size()
		_check("loot_owner_and_manager_agree", owner_n == mgr_n,
			"EquipmentManager.get_ship_stash().size() == campaign stash size",
			"manager=%d campaign=%d" % [mgr_n, owner_n])

	# Invasion control — Core Rules p.120: "no Loot" (LootProcessor.gd:22-23).
	var inv_total := 0
	for s in range(2000, 2020):
		var r: Array = _loot_trial("lootinv", s, {"is_invasion": true})
		if not r.is_empty():
			inv_total += int(r[0])
	_check("loot_invasion_grants_nothing", inv_total == 0,
		"0 stashed items across 20 invasion battles", "total=%d" % inv_total)

	# Quest finale = 3 rolls (LootProcessor.gd:24-25).
	var fin_total := 0
	var base_total := 0
	for s in range(3000, 3020):
		var rf: Array = _loot_trial("lootfin", s, {"is_quest_finale": true})
		if not rf.is_empty():
			fin_total += int(rf[0])
		var rb: Array = _loot_trial("lootbase", s, {})
		if not rb.is_empty():
			base_total += int(rb[0])
	_check("loot_quest_finale_rolls_three_times", fin_total > base_total,
		"quest-finale stash total > single-roll total over the same 20 seeds",
		"finale=%d single=%d" % [fin_total, base_total])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 4 — payment / credits are applied (Core Rules p.120 "Get Paid")
#   ISOLATED sub-step (loot REWARDS also add credits through the same fallback,
#   LootProcessor.gd:98-106). Write path: PaymentProcessor.gd:66-70 ->
#   GameStateManager.add_credits (:326) -> set_credits (:110) ->
#   game_state.current_campaign.credits (:113).
#   NEVER assert on the returned int or the payment_received signal.
# ═══════════════════════════════════════════════════════════════════════════════

func _payment_trial(tag: String, s: int, danger_pay: int, extra: Dictionary) -> Array:
	## Returns [credits_delta, campaign]
	var campaign: Resource = _make_campaign("%s_%d" % [tag, s], 5)
	campaign.credits = 0
	_bind(campaign)
	if _gsm.has_method("set_credits"):
		_gsm.set_credits(0)
	campaign.credits = 0
	var raw: Dictionary = {
		"success": true, "victory": true, "won": true, "held_field": true,
		"crew_participants": _participants(campaign, [0, 1, 2, 3, 4]),
		"crew_injuries_data": [], "crew_casualties_data": [],
		"defeated_enemies": [], "enemy_type": "Raiders",
	}
	raw.merge(extra, true)
	var mission: Dictionary = {"mission_source": "opportunity",
		"danger_pay": danger_pay}
	var h: Node = _handler_with(campaign, raw, mission,
		_participants(campaign, [0, 1, 2, 3, 4]))
	if h == null:
		return []
	var before: int = int(campaign.credits)
	seed(s * 15485863)
	h._payment.process_payment(h._ctx)
	return [int(campaign.credits) - before, campaign]

func _row_payment_credits() -> void:
	if _cpm.get_phase_handler("post_battle") == null:
		_skipped("payment_credits_applied", "post_battle handler unavailable")
		return
	if int(_gsm.get_difficulty()) == 1:  # EASY would add +1 (PaymentProcessor.gd:45-47)
		_skipped("payment_credits_applied", "GameStateManager difficulty is EASY")
		return

	# The airtight danger-pay proof, purely on campaign state: for the SAME seed
	# the random 1D6 component cancels, so the difference IS the danger pay.
	# Pins BattleResultNormalizer.gd:25-28 -> PaymentProcessor.gd:58-59 -> the write.
	var deltas_ok := true
	var detail: Array[String] = []
	for s in [11, 22, 33]:
		var a: Array = _payment_trial("pay0", s, 0, {})
		var b: Array = _payment_trial("pay10", s, 10, {})
		if a.is_empty() or b.is_empty():
			deltas_ok = false
			detail.append("seed %d: no handler" % s)
			continue
		var d0: int = int(a[0])
		var d10: int = int(b[0])
		if d10 - d0 != 10:
			deltas_ok = false
			detail.append("seed %d: d0=%d d10=%d" % [s, d0, d10])
		# Won objective, non-rival, non-invasion: 1D6 floored at 3 (p.120), so 3..6.
		if d0 < 3 or d0 > 6:
			deltas_ok = false
			detail.append("seed %d: base %d outside 3..6" % [s, d0])
	_check("payment_credits_applied_and_danger_pay_propagates", deltas_ok,
		"campaign.credits(danger_pay=10) - campaign.credits(danger_pay=0) == 10 "
		+ "at the same seed, base within 3..6", str(detail))

	# Invasion: Core Rules p.120 grants no payment (PaymentProcessor.gd:21-22).
	var inv_bad: Array[String] = []
	for s in [11, 22, 33]:
		var r: Array = _payment_trial("payinv", s, 4, {"is_invasion": true})
		if r.is_empty() or int(r[0]) != 0:
			inv_bad.append("seed %d delta=%s" % [s, str(r[0]) if not r.is_empty() else "?"])
	_check("payment_invasion_pays_nothing", inv_bad.is_empty(),
		"campaign.credits unchanged on an invasion battle", str(inv_bad))

	# Owner/mirror agreement — a divergence means only the cache moved.
	var last: Array = _payment_trial("paymirror", 77, 0, {})
	if last.is_empty():
		_skipped("payment_owner_and_mirror_agree", "no handler")
	else:
		var campaign: Resource = last[1]
		_check("payment_owner_and_mirror_agree",
			int(_gsm.get_credits()) == int(campaign.credits),
			"GameStateManager.get_credits() == campaign.credits",
			"mirror=%d owner=%d" % [int(_gsm.get_credits()), int(campaign.credits)])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 5 — battle journal entry has description / mood / location / turn_number,
#   driven through the REAL post-battle pipeline, then re-read off the CAMPAIGN
#   save payload (campaign.to_dictionary()["qol_data"]["journal"]["entries"],
#   FiveParsecsCampaignCore.gd:437 -> :510-519 -> CampaignJournal.save_to_dict).
#   Locate by ID-DIFF: create_entry INSERTS IN TURN ORDER (CampaignJournal.gd:102-106),
#   so entries[-1] can be a stale higher-turn entry.
# ═══════════════════════════════════════════════════════════════════════════════

func _journal_ids() -> Dictionary:
	var out: Dictionary = {}
	if _journal == null:
		return out
	for e in _journal.entries:
		out[str(e.get("id", ""))] = true
	return out

func _new_entries_since(before_ids: Dictionary, want_type: String) -> Array:
	var out: Array = []
	if _journal == null:
		return out
	for e in _journal.entries:
		if before_ids.has(str(e.get("id", ""))):
			continue
		if want_type.is_empty() or str(e.get("type", "")) == want_type:
			out.append(e)
	return out

func _row_journal_battle_entry() -> void:
	if _journal == null:
		_skipped("journal_battle_entry_populated", "CampaignJournal autoload missing")
		return
	var expected_loc := ""
	if _pdm and _pdm.has_method("get_current_planet"):
		var planet: Variant = _pdm.get_current_planet()
		if planet != null and "name" in planet:
			expected_loc = str(planet.name)
	if expected_loc.is_empty():
		_skipped("journal_battle_entry_populated",
			"PlanetDataManager has no current planet to resolve location against")
		return

	_journal_variant("journal_battle_entry_clean_victory", 0, "triumph", expected_loc)
	_journal_variant("journal_battle_entry_costly_victory", 1, "neutral", expected_loc)

func _journal_variant(name: String, n_injured: int, want_mood: String,
		want_loc: String) -> void:
	var campaign: Resource = _make_campaign("journal_%d" % n_injured, 5)
	_bind(campaign)
	var want_turn: int = int(campaign.progress_data["turns_played"]) + 1

	var injured: Array = []
	for i in range(n_injured):
		var m: Dictionary = _members(campaign)[i]
		injured.append({"character_id": m["character_id"], "id": m["id"],
			"character_name": m["character_name"], "name": m["name"],
			"origin": "human", "species_id": "human"})

	var before_ids: Dictionary = _journal_ids()
	var ok: bool = _run_pipeline(campaign, {
		"success": true, "victory": true, "won": true, "held_field": true,
		"crew_participants": _participants(campaign, [0, 1, 2, 3, 4]),
		"crew_injuries_data": injured, "crew_casualties_data": [],
		"defeated_enemies": [], "enemy_type": "Raiders",
		"xp_earned": 3,
	}, {"mission_source": "opportunity"})
	if not ok:
		_bad(name, "start_phase(POST_MISSION) accepted", "transition refused")
		return

	var fresh: Array = _new_entries_since(before_ids, "battle")
	if fresh.size() != 1:
		_bad(name, "exactly 1 new type=battle journal entry",
			"%d new battle entries" % fresh.size())
		return
	var e: Dictionary = fresh[0]

	var problems: Array[String] = []
	var desc: String = str(e.get("description", ""))
	if desc.is_empty():
		problems.append("description EMPTY (=> _generate_battle_description aborted)")
	elif not desc.begins_with("Battle vs Raiders"):
		problems.append("description=%s" % desc.substr(0, 40))
	var mood: String = str(e.get("mood", ""))
	if mood.is_empty():
		problems.append("mood EMPTY (=> _determine_battle_mood aborted)")
	elif mood != want_mood:
		problems.append("mood=%s want=%s" % [mood, want_mood])
	if str(e.get("location", "")) != want_loc:
		problems.append("location=%s want=%s" % [str(e.get("location", "")), want_loc])
	var tn: int = int(e.get("turn_number", -1))
	if tn != want_turn:
		problems.append("turn_number=%d want=%d (turns_played+1)" % [tn, want_turn])
	if tn == 0:
		problems.append("turn_number 0 => the normalizer turn stamp never landed")
	var stats: Dictionary = e.get("stats", {})
	var cas: Variant = stats.get("casualties", null)
	if typeof(cas) != TYPE_INT:
		problems.append("stats.casualties is %s not int" % type_string(typeof(cas)))
	elif int(cas) != n_injured:
		problems.append("stats.casualties=%d want=%d" % [int(cas), n_injured])
	if n_injured > 0 and not desc.contains("%d crew casualties" % n_injured):
		problems.append("description omits the casualty line")
	_check(name, problems.is_empty(),
		"non-empty description+mood, location=%s, turn_number=%d, stats.casualties=%d (int)"
		% [want_loc, want_turn, n_injured], str(problems))

	# CAMPAIGN-RESOURCE ROUND TRIP — the strongest read: it must survive into the
	# save payload, not just the autoload's in-memory array.
	var saved: Variant = campaign.to_dictionary()
	var round_ok := false
	if saved is Dictionary:
		var qol: Dictionary = (saved as Dictionary).get("qol_data", {})
		var jr: Dictionary = qol.get("journal", {})
		for se in jr.get("entries", []):
			if str(se.get("id", "")) == str(e.get("id", "")):
				round_ok = (not str(se.get("description", "")).is_empty()) \
					and (not str(se.get("mood", "")).is_empty()) \
					and str(se.get("location", "")) == want_loc \
					and int(se.get("turn_number", -1)) == want_turn
				break
	_check(name + "_survives_campaign_save",
		round_ok,
		"the same entry in campaign.to_dictionary()[qol_data][journal][entries] "
		+ "keeps description/mood/location/turn_number",
		"round_trip_ok=%s" % str(round_ok))

## SUB-ROW (REQUIRED — the pipeline CANNOT detect this). The pipeline producer
## writes stats.casualties as an INT (PostBattleCompletion.gd:133
## ctx.injuries_sustained.size()), so the pipeline never carries the Array shape.
## Bug Hunt / Planetfall / legacy saves still call the public API with the
## normalized Array-of-dicts shape (BattleResultNormalizer.gd:49-57).
func _row_journal_casualties_array_direct() -> void:
	var name := "journal_direct_api_survives_array_casualties"
	if _journal == null:
		_skipped(name, "CampaignJournal autoload missing")
		return
	var campaign: Resource = _make_campaign("jdirect", 5)
	_bind(campaign)

	var before_ids: Dictionary = _journal_ids()
	_journal.auto_create_battle_entry({
		"turn": 9, "outcome": "victory", "enemy_type": "Converted",
		"casualties": [{"crew_id": "crew_1", "name": "Crew 1", "type": "killed"}],
		"loot": 0, "xp": 0, "crew_ids": [], "location": "Kepler Reach",
	})
	var fresh: Array = _new_entries_since(before_ids, "battle")
	if fresh.size() != 1:
		_bad(name, "exactly 1 new battle entry", "%d" % fresh.size())
		return
	var e: Dictionary = fresh[0]
	var problems: Array[String] = []
	if str(e.get("description", "")).is_empty():
		problems.append("description EMPTY (_generate_battle_description aborted)")
	elif not str(e.get("description", "")).begins_with("Battle vs Converted - Victory"):
		problems.append("description=%s" % str(e.get("description", "")).substr(0, 40))
	if str(e.get("mood", "")).is_empty():
		problems.append("mood EMPTY (_determine_battle_mood aborted)")
	elif str(e.get("mood", "")) != "neutral":
		problems.append("mood=%s" % str(e.get("mood", "")))
	var cas: Variant = (e.get("stats", {}) as Dictionary).get("casualties", null)
	if typeof(cas) != TYPE_INT or int(cas) != 1:
		problems.append("stats.casualties=%s (want int 1)" % str(cas))
	_check(name, problems.is_empty(),
		"description+mood non-empty and stats.casualties == int 1 from an "
		+ "Array-shaped casualties payload", str(problems))

## The create_entry() chokepoint fallbacks (CampaignJournal.gd:59-64, 114-136).
## The battle path never reaches them (auto_create_battle_entry always passes an
## explicit turn_number, defaulting to 0, and the guard is `< 0`), so they need a
## direct probe.
func _row_journal_chokepoint_fallback() -> void:
	var name := "journal_chokepoint_resolves_turn_and_location"
	if _journal == null:
		_skipped(name, "CampaignJournal autoload missing")
		return
	var campaign: Resource = _make_campaign("jfallback", 5)
	_bind(campaign)
	var want_turn: int = int(campaign.progress_data["turns_played"])
	var want_loc := ""
	if _pdm and _pdm.has_method("get_current_planet"):
		var p: Variant = _pdm.get_current_planet()
		if p != null and "name" in p:
			want_loc = str(p.name)
	if want_loc.is_empty():
		_skipped(name, "no current planet to resolve against")
		return

	var eid: String = _journal.create_entry({
		"type": "story", "title": "Harness probe",
		"description": "probe",
	})
	var e: Dictionary = _journal.entries_by_id.get(eid, {})
	var got_turn: int = int(e.get("turn_number", -999))
	var got_loc: String = str(e.get("location", ""))
	_check(name, got_turn == want_turn and got_loc == want_loc,
		"turn_number=%d (campaign.progress_data.turns_played) location=%s"
		% [want_turn, want_loc],
		"turn_number=%d location=%s" % [got_turn, got_loc])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 6 — a defeated Rival is removed from campaign.rivals
#   Assert on PRESENCE OF THE SEEDED ID, never on rivals.size(): CampaignEventEffects
#   /CharacterEventEffects APPEND new event rivals mid-pipeline, so size can stay 1
#   while the seeded rival was correctly removed and a new one added.
#   _roll_rival_removal (RivalPatronResolver.gd:161-176) is a bare randi_range(1,6)
#   needing >= 4; is_unique adds +1, so base >= 3 (~66%). Run N trials.
# ═══════════════════════════════════════════════════════════════════════════════

func _rival_ids(campaign: Resource) -> Array[String]:
	var out: Array[String] = []
	for r in campaign.rivals:
		if r is Dictionary:
			out.append(str(r.get("id", "")))
		else:
			out.append(str(r))
	return out

func _rival_trial(tag: String, s: int, with_enemy: bool) -> bool:
	## Returns true when the SEEDED rival is gone from campaign.rivals.
	seed(s * 32452843)
	var campaign: Resource = _make_campaign("%s_%d" % [tag, s], 5)
	campaign.rivals = [{"id": "rival_test_1", "name": "Test Rival", "type": "Gang"}]
	_bind(campaign)
	var enemies: Array = []
	if with_enemy:
		enemies = [{"name": "Test Rival", "type": "Gang", "is_unique": true}]
	var ok: bool = _run_pipeline(campaign, {
		"success": true, "victory": true, "won": true, "held_field": true,
		"crew_participants": _participants(campaign, [0, 1, 2, 3, 4]),
		"crew_injuries_data": [], "crew_casualties_data": [],
		"defeated_enemies": enemies,
		"enemies_defeated_count": enemies.size(),
		"enemy_type": "Gang",
	}, {"mission_source": "opportunity", "rival_id": "rival_test_1"})
	if not ok:
		return false
	return not ("rival_test_1" in _rival_ids(campaign))

## ROW 6b — the ROUTER must DERIVE defeated_enemies from per-unit end state.
##
## WHY THIS EXISTS: _rival_trial() above hands "defeated_enemies" to the pipeline
## ready-made, so it proves RivalPatronResolver consumes the list — but it passes
## even with BattleResolverRouter._with_defeated_enemies() deleted, which is the
## actual fix. Verified empirically: reverting BattleResolverRouter.gd to its
## pre-fix version left every other row green. Without this row the harness would
## report PASS while the original defect was fully reintroduced.
##
## The real defect: no resolver produces `defeated_enemies` (they report
## `enemies_defeated` as a COUNT and return `enemy_units_final`). That list is what
## PostBattlePhase reads and RivalPatronResolver iterates for `is_rival`, so on
## every auto-resolved battle it was empty — a defeated Rival was never removed,
## and `fought_existing_rival` stayed false so the "gain a NEW rival on a 1" branch
## fired for the fight you just won.
func _row_router_derives_defeated_enemies() -> void:
	var name := "router_derives_defeated_enemies_from_unit_end_state"
	var router: GDScript = load("res://src/core/battle/BattleResolverRouter.gd")
	if router == null:
		_skipped(name, "BattleResolverRouter.gd did not load")
		return
	seed(20260729)
	var crew: Array = []
	for i in range(5):
		crew.append({
			"character_id": "rc_%d" % i, "character_name": "RC %d" % i,
			"combat": 2, "reactions": 3, "toughness": 4, "speed": 4, "savvy": 0,
			"weapons": [{"name": "Handgun", "range": 12, "shots": 1, "damage": 1}],
		})
	var enemies: Array = []
	for i in range(3):
		enemies.append({
			"name": "Raider %d" % i, "type": "Pirates", "combat": 0,
			"toughness": 3, "speed": 4, "special_rules": [],
			"weapons": [{"name": "Scrap Pistol", "range": 9, "shots": 1, "damage": 0}],
		})
	var res: Dictionary = router.resolve(
		crew, enemies, {}, {}, func() -> int: return randi_range(1, 6), null)

	if not res.has("defeated_enemies"):
		_bad(name, "resolver result carries a defeated_enemies LIST",
			"key absent — the derivation is gone")
		return
	var lst: Array = res["defeated_enemies"]
	var cnt: int = int(res.get("enemies_defeated", -1))
	# The derived list must agree with the count the resolver itself reported, and
	# must contain only units the resolver marked dead.
	var only_dead := true
	for u in lst:
		if not (u is Dictionary) or bool((u as Dictionary).get("is_alive", true)):
			only_dead = false
			break
	_check(name, lst.size() == cnt and cnt > 0 and only_dead,
		"defeated_enemies.size() == enemies_defeated > 0, all is_alive=false",
		"list=%d count=%d only_dead=%s" % [lst.size(), cnt, str(only_dead)])

func _row_rival_removed() -> void:
	var trials := 20
	var removed := 0
	for s in range(1, trials + 1):
		if _rival_trial("rival", s, true):
			removed += 1
	print("  [rival] removed in %d/%d trials (expect ~66%%)" % [removed, trials])
	# P(false failure) with a true 2/3 rate over 20 trials = (1/3)^20 ~ 3e-10.
	_check("defeated_rival_removed_from_campaign", removed >= 1,
		">=1 of %d defeated-rival battles removes 'rival_test_1' from campaign.rivals"
		% trials, "removed=%d" % removed)

	# MUTATION CONTROL — no defeated_enemies means fought_existing_rival stays false
	# (RivalPatronResolver.gd:24-26), so the seeded rival must NEVER be removed.
	var wrong := 0
	for s in range(100, 100 + trials):
		if _rival_trial("rivalctl", s, false):
			wrong += 1
	_check("rival_not_removed_without_defeating_it", wrong == 0,
		"0 of %d battles with no defeated enemies remove the rival" % trials,
		"removed=%d" % wrong)

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 7 — auto-resolve fights a real enemy force (not an empty list)
#   Real entrypoint: CampaignTurnController._on_auto_resolve_completed (:998), on a
#   DETACHED Control (never add_child'd — CampaignTurnController.gd:106 asserts on
#   %WorldPhaseController in _ready()) with the two @onready deps injected by hand.
# ═══════════════════════════════════════════════════════════════════════════════

func _auto_resolve_run(tag: String, s: int, with_enemy: bool) -> Resource:
	seed(s * 49979687)
	var campaign: Resource = _make_campaign("%s_%d" % [tag, s], 5)
	campaign.credits = 20
	campaign.rivals = [{"id": "rival_test_1", "name": "Test Rival", "type": "Gang"}]
	campaign.progress_data["current_mission"] = {
		"type": "Fight Off", "objective": "Fight Off",
		"mission_source": "opportunity", "pay": 0, "danger_pay": 0,
		"force_narrative_wrap": false,
	}
	_bind(campaign)
	if _gsm.has_method("set_credits"):
		_gsm.set_credits(20)
	campaign.credits = 20

	if _gs.has_method("set_current_enemies"):
		if with_enemy:
			_gs.set_current_enemies([{
				"name": "Gang Thug", "enemy_type": "Gang", "type": "Gang",
				"toughness": 3, "combat_skill": 0, "luck": 0,
				"special_rules": [], "is_unique": true,
			}])
		else:
			_gs.set_current_enemies([])
	if _gs.has_method("clear_battle_results"):
		_gs.clear_battle_results()

	var ctc = _ctc_script.new()
	ctc.game_state = _gs
	ctc.campaign_phase_manager = _cpm
	_cpm.current_phase = PHASE_MISSION
	ctc._on_auto_resolve_completed({})
	ctc.free()
	return campaign

func _row_auto_resolve() -> void:
	if _ctc_script == null:
		_skipped("auto_resolve_refuses_empty_enemy_force",
			"CampaignTurnController.gd could not be loaded")
		return

	# GUARD ARM — no enemies at all. The campaign must be COMPLETELY unmutated.
	# Pre-fix, mission_data["enemies"] was always [] and
	# BattleResolver.calculate_battle_outcome:527-530 short-circuited to a flawless
	# free victory that ran the whole post-battle chain.
	var guard_bad: Array[String] = []
	for s in [1, 2, 3]:
		var c: Resource = _auto_resolve_run("arguard", s, false)
		if int(c.credits) != 20:
			guard_bad.append("seed %d credits %d (want 20)" % [s, int(c.credits)])
		var xp_total := 0
		for m in _members(c):
			xp_total += int(m["experience"])
		if xp_total != 0:
			guard_bad.append("seed %d crew XP total %d (want 0)" % [s, xp_total])
		if not ("rival_test_1" in _rival_ids(c)):
			guard_bad.append("seed %d seeded rival was removed" % s)
	_check("auto_resolve_refuses_empty_enemy_force", guard_bad.is_empty(),
		"campaign.credits==20, total crew XP==0 and the rival survives when no "
		+ "enemy force exists", str(guard_bad))

	# POSITIVE ARM — one real enemy: the campaign really moves.
	var pos_paid := 0
	var pos_xp := 0
	for s in [11, 12, 13]:
		var c: Resource = _auto_resolve_run("arpos", s, true)
		if int(c.credits) > 20:
			pos_paid += 1
		var xp_total := 0
		for m in _members(c):
			xp_total += int(m["experience"])
		if xp_total > 0:
			pos_xp += 1
	_check("auto_resolve_with_real_enemy_mutates_campaign",
		pos_paid == 3 and pos_xp == 3,
		"3/3 runs raise campaign.credits above 20 AND award crew XP",
		"credits_raised=%d/3 xp_awarded=%d/3" % [pos_paid, pos_xp])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 8 — casualties as an Array: the NUMERIC consumer reaches campaign credits.
#   PaymentProcessor.process_black_zone_rewards (:175) is the only casualty_count()
#   call site whose result becomes a campaign write with EXACT arithmetic and no
#   dice (BlackZoneSystem.gd:172-176 -> PaymentProcessor.gd:257-265).
#   Both shapes must pay: normalize() guarantees the Array, but Bug Hunt /
#   Planetfall / legacy saves can still carry the int (BattleResultNormalizer.gd:85-90).
# ═══════════════════════════════════════════════════════════════════════════════

func _bz_trial(tag: String, casualties: Variant) -> int:
	var campaign: Resource = _make_campaign(tag, 5)
	campaign.credits = 0
	_bind(campaign)
	if _gsm.has_method("set_credits"):
		_gsm.set_credits(0)
	campaign.credits = 0
	var h: Node = _cpm.get_phase_handler("post_battle")
	if h == null:
		return -1
	h._ensure_subsystems()
	h.set_campaign(campaign)
	# NOT run through normalize() on purpose — the point is shape tolerance.
	h.battle_result = {
		"is_black_zone": true, "success": false, "turn": 4,
		"casualties": casualties,
	}
	h.mission_successful = false
	h.crew_participants = []
	h.defeated_enemies = []
	h.injuries_sustained = []
	h.loot_earned = []
	h._sync_context()
	var before: int = int(campaign.credits)
	h._payment.process_black_zone_rewards(h._ctx)
	return int(campaign.credits) - before

func _row_black_zone_casualty_pay() -> void:
	if _cpm.get_phase_handler("post_battle") == null:
		_skipped("black_zone_casualty_pay_array_shape", "post_battle handler unavailable")
		return
	var arr: Array = [
		{"crew_id": "crew_1", "name": "Crew 1", "type": "killed"},
		{"crew_id": "crew_2", "name": "Crew 2", "type": "killed"},
	]
	var d_arr: int = _bz_trial("bzarr", arr)
	_check("black_zone_casualty_pay_array_shape", d_arr == 2,
		"campaign.credits +2 (1cr per casualty, Array of 2)", "delta=%d" % d_arr)
	var d_int: int = _bz_trial("bzint", 2)
	_check("black_zone_casualty_pay_int_shape", d_int == 2,
		"campaign.credits +2 from the legacy int casualties shape", "delta=%d" % d_int)
	_row_black_zone_victory_reward()

## ROW 8b — Black Zone VICTORY reward reaches the CANONICAL owners.
##
## WHY THIS EXISTS: the two rows above cover the casualty PAY only. Verified
## empirically that reverting PaymentProcessor.gd to its pre-fix version left the
## whole harness green — the ownership defect was completely uncovered.
##
## The real defect (Core Rules Appendix III, "Clear ALL Rivals, +2 Patrons"):
## both writes targeted campaign.crew_data["rivals"] / ["patrons"] — a location
## NOTHING reads — and the rival clear was additionally gated on `cd.has("rivals")`,
## a key crew_data never carries. So a Black Zone victory cleared no rivals and
## added no patrons, while the journal entry reported both as done.
func _row_black_zone_victory_reward() -> void:
	var name := "black_zone_victory_clears_rivals_and_adds_patrons"
	var h: Node = _cpm.get_phase_handler("post_battle")
	if h == null:
		_skipped(name, "post_battle handler unavailable")
		return
	var campaign: Resource = _make_campaign("bzwin", 5)
	campaign.rivals = [
		{"id": "bz_r1", "name": "Rival One", "type": "Gang"},
		{"id": "bz_r2", "name": "Rival Two", "type": "Gang"},
	]
	campaign.patrons = []
	_bind(campaign)
	h._ensure_subsystems()
	h.set_campaign(campaign)
	h.battle_result = {"is_black_zone": true, "success": true, "turn": 4,
		"casualties": []}
	h.mission_successful = true
	h.crew_participants = []
	h.defeated_enemies = []
	h.injuries_sustained = []
	h.loot_earned = []
	h._sync_context()
	h._payment.process_black_zone_rewards(h._ctx)

	# STATE ASSERTION — read the CANONICAL owners back off the campaign Resource.
	var rivals_left: int = (campaign.rivals as Array).size()
	var patrons_now: int = (campaign.patrons as Array).size()
	_check(name, rivals_left == 0 and patrons_now >= 2,
		"campaign.rivals emptied (0) and campaign.patrons >= 2",
		"rivals=%d patrons=%d" % [rivals_left, patrons_now])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 9 — casualties as an Array: the ITERATION consumer survives it.
#   PostBattlePhase._check_bitter_day_story_point (:471-499) iterates
#   battle_result["casualties"] at :483 and writes campaign.story_points += 1 at
#   :497 — a campaign write DOWNSTREAM of the risky read IN THE SAME FUNCTION,
#   which is exactly what proves no abort occurred.
#   Isolated (no RNG, no other SP source) so the delta is exact.
# ═══════════════════════════════════════════════════════════════════════════════

func _bitter_trial(tag: String, casualties: Variant) -> int:
	var campaign: Resource = _make_campaign(tag, 5)
	campaign.story_points = 0
	campaign.difficulty = DIFF_NORMAL  # Insanity would disable SP (:519)
	_bind(campaign)
	campaign.story_points = 0
	var h: Node = _cpm.get_phase_handler("post_battle")
	if h == null:
		return -999
	h._ensure_subsystems()
	h.set_campaign(campaign)
	h.battle_result = {"held_field": true, "casualties": casualties, "turn": 4}
	h._processed_injuries = []
	h._sync_context()
	var before: int = int(campaign.story_points)
	h._check_bitter_day_story_point()
	return int(campaign.story_points) - before

func _row_bitter_day_story_point() -> void:
	if _cpm.get_phase_handler("post_battle") == null:
		_skipped("bitter_day_story_point_array_shape", "post_battle handler unavailable")
		return
	var arr: Array = [{"crew_id": "crew_1", "type": "killed"}]
	var d_arr: int = _bitter_trial("bitterarr", arr)
	_check("bitter_day_story_point_array_shape", d_arr == 1,
		"campaign.story_points +1 (Core Rules p.67 held field + a death)",
		"delta=%d" % d_arr)
	# int shape: `for casualty in 2` yields ints and casualty.get() is an invalid
	# call that aborts before the +1 at :497.
	var d_int: int = _bitter_trial("bitterint", 2)
	_check("bitter_day_story_point_int_shape", d_int == 1,
		"campaign.story_points +1 from the legacy int casualties shape too",
		"delta=%d" % d_int)

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 10 — crew dicts carry BOTH "reaction" and "reactions", and crew members land
#   in crew_data["members"] as DICTIONARIES (CampaignFinalizationService.gd:807-824
#   is the only thing stopping Character Resources from getting in, which re-triggers
#   the 2-arg .get() abort class).
# ═══════════════════════════════════════════════════════════════════════════════

func _row_crew_dict_dual_reaction_key() -> void:
	var name := "crew_dicts_carry_reaction_and_reactions"
	if _final_script == null or _char_script == null:
		_skipped(name, "CampaignFinalizationService/Character could not be loaded")
		return
	var svc = _final_script.new()
	if not svc.has_method("_create_campaign_resource"):
		_skipped(name, "_create_campaign_resource missing on the finalization service")
		return

	var c = _char_script.new()
	c.character_name = "Cap"
	c.reactions = 3
	c.is_captain = true
	# Six required sections (CampaignFinalizationService.gd:80-87); ship {} skips
	# the GameStateManager debt branch at :348.
	var campaign: Resource = svc._create_campaign_resource({
		"config": {"campaign_name": "Probe", "difficulty": DIFF_NORMAL},
		"crew": {"members": [c]},
		"captain": {}, "ship": {}, "equipment": {}, "world": {},
	})
	if campaign == null:
		_bad(name, "a FiveParsecsCampaignCore", "null")
		return
	var members: Array = campaign.crew_data.get("members", [])
	if members.is_empty():
		_bad(name, "1 crew member in campaign.crew_data[members]", "0")
		return
	var m0: Variant = members[0]
	var problems: Array[String] = []
	if not (m0 is Dictionary):
		problems.append("member is %s not Dictionary" % type_string(typeof(m0)))
	else:
		var d: Dictionary = m0
		if not d.has("reaction"):
			problems.append("missing key 'reaction'")
		if not d.has("reactions"):
			problems.append("missing key 'reactions'")
		if d.has("reaction") and int(d["reaction"]) != 3:
			problems.append("reaction=%d want 3" % int(d["reaction"]))
		if d.has("reactions") and int(d["reactions"]) != 3:
			problems.append("reactions=%d want 3" % int(d["reactions"]))
	_check(name, problems.is_empty(),
		"crew_data[members][0] is a Dictionary with reaction==reactions==3",
		str(problems))

	# Second entrypoint: the post-creation crew-addition chokepoint.
	var c2 = _char_script.new()
	c2.character_name = "Recruit"
	c2.reactions = 4
	campaign.add_crew_member(c2.to_dictionary())
	var last: Variant = campaign.crew_data["members"][-1]
	var ok2: bool = last is Dictionary \
		and int((last as Dictionary).get("reaction", -1)) == 4 \
		and int((last as Dictionary).get("reactions", -1)) == 4
	_check("crew_dicts_dual_reaction_key_via_add_crew_member", ok2,
		"add_crew_member() appends a Dictionary with reaction==reactions==4",
		str(last) if not (last is Dictionary) else "reaction=%s reactions=%s"
			% [str((last as Dictionary).get("reaction")),
				str((last as Dictionary).get("reactions"))])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 11 — PostBattleContext.get_campaign_difficulty() NONE-vs-EASY fallback.
#   The fallback (PostBattleContext.gd:113-131) only fires when game_state_manager
#   is null, so this row uses a DETACHED RefCounted context and the one consumer
#   whose effect still lands on the campaign without a gsm: the XP path.
#   difficulty_levels.NONE.xp_bonus == 0 and EASY.xp_bonus == 1 in
#   data/difficulty_modifiers.json, so `== 3` (not `>= 3`) discriminates the fix.
# ═══════════════════════════════════════════════════════════════════════════════

func _row_difficulty_none_fallback() -> void:
	var name := "difficulty_fallback_is_NONE_not_EASY"
	if _ctx_script == null:
		_skipped(name, "PostBattleContext.gd could not be loaded")
		return
	var _xp_script: GDScript = load(
		"res://src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd")
	if _xp_script == null:
		_skipped(name, "ExperienceTrainingProcessor.gd could not be loaded")
		return

	var campaign: Resource = _make_campaign("diffnone", 5)
	var ctx = _ctx_script.new()
	ctx.game_state_manager = null
	ctx.game_state = null
	ctx.campaign = campaign
	ctx.mission_successful = true
	ctx.crew_participants = _participants(campaign, [0])
	ctx.battle_result = {"turn": 1, "casualties": [], "injuries_sustained": []}
	ctx.injuries_sustained = []
	ctx.loot_earned = []

	var d: int = int(ctx.get_campaign_difficulty())
	_check(name + "_returns_NONE", d == DIFF_NONE,
		"get_campaign_difficulty() == GlobalEnums.DifficultyLevel.NONE (0)",
		"got %d" % d)

	var xp = _xp_script.new()
	xp.process_experience(ctx)
	var got: int = int(_members(campaign)[0]["experience"])
	_check(name + "_no_easy_xp_bonus", got == 3,
		"campaign.crew_data[members][0].experience == 3 "
		+ "(survived_won_battle 3 + NONE xp_bonus 0; EASY would give 4)",
		"experience=%d" % got)

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 12 — a Campaign Event effect actually reaches the campaign.
#   Step 12 of the orchestrator (PostBattlePhase.gd:218-234) routes every D100
#   Campaign Event through CampaignEventEffects.apply_effect (:100). "Settle Old
#   Business" (Core Rules pp.126-128) with no rivals calls
#   ctx.award_xp_to_captain(1) at CampaignEventEffects.gd:162 — a method that does
#   NOT exist on PostBattleContext (it defines add_character_xp:494,
#   award_xp_to_random_crew:515, award_xp_to_all_crew:520 and nothing else).
#   That invalid call aborts apply_effect, so the event silently does nothing.
#   Asserted on total crew XP read off the campaign Resource, NOT on the returned
#   effect string — the abort means the string is never returned either, but a
#   string is exactly the kind of evidence that hid this class of bug.
# ═══════════════════════════════════════════════════════════════════════════════

func _row_campaign_event_effect_reaches_campaign() -> void:
	var name := "campaign_event_settle_old_business_awards_captain_xp"
	var cee_script: GDScript = load(
		"res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd")
	if cee_script == null:
		_skipped(name, "CampaignEventEffects.gd could not be loaded")
		return
	var h: Node = _cpm.get_phase_handler("post_battle")
	if h == null:
		_skipped(name, "post_battle handler unavailable")
		return

	var campaign: Resource = _make_campaign("cee", 5)
	# No rivals -> the else branch at CampaignEventEffects.gd:159-163 (gsm.get_rivals()
	# reads campaign.rivals, GameStateManager.gd:652-656).
	campaign.rivals = []
	_members(campaign)[0]["is_captain"] = true
	_bind(campaign)

	h._ensure_subsystems()
	h.set_campaign(campaign)
	h.battle_result = {"turn": 4}
	h.mission_successful = true
	h.crew_participants = []
	h.defeated_enemies = []
	h.injuries_sustained = []
	h.loot_earned = []
	h._sync_context()

	var before := 0
	for m in _members(campaign):
		before += int(m["experience"])
	cee_script.new().apply_effect("Settle Old Business", h._ctx)
	var after := 0
	for m in _members(campaign):
		after += int(m["experience"])
	_check(name, after == before + 1,
		"total crew XP on campaign.crew_data[members] +1 (the captain gains 1 XP)",
		"%d -> %d" % [before, after])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 17 — the post-battle Luck death-save (Core Rules p.121)
#
#   Book, verbatim (step 8, Determine Injuries and Recovery): "If a character with
#   Luck would be slain through a roll on this table, they miraculously survive, but
#   immediately lose ALL Luck points. They can earn additional points as normal in
#   the future."
#
#   NOT IMPLEMENTED on the live path. InjuryProcessor's fatal branch went straight to
#   ctx.apply_crew_death() with no Luck check, so a crew member holding Luck was
#   killed outright by a 1-15 roll — permanent character loss the book prevents.
#   (An older non-live processor did implement it: PostBattleProcessor.gd:186-202,
#   reachable only from a comment in FPCM_BattleManager.gd:401 plus one test.)
#
#   Same 40-seed harness as ROW 2 so the fatal band (1-15) is genuinely hit.
#   The luck=0 CONTROL is the point of this row: a "nobody died" assertion passes
#   just as happily when the injury step is broken and rolls nothing at all. Only
#   the control proves the fatal branch still reaches death when Luck cannot save.
# ═══════════════════════════════════════════════════════════════════════════════

func _luck_save_trial(tag: String, luck: int) -> Dictionary:
	var trials := 40
	var out := {"dead": 0, "saved": 0, "luck_kept": 0}
	for s in range(1, trials + 1):
		seed(s * 7919)
		var campaign: Resource = _make_campaign("luck_%s_%d" % [tag, s], 5)
		_bind(campaign)
		var victim: Dictionary = _members(campaign)[2]
		victim["luck"] = luck
		var producer: Dictionary = {
			"character_id": victim["character_id"], "id": victim["id"],
			"character_name": victim["character_name"], "name": victim["name"],
		}
		var ok: bool = _run_pipeline(campaign, {
			"success": false, "victory": false, "won": false, "held_field": true,
			"crew_participants": _participants(campaign, [0, 1, 2, 3, 4]),
			"crew_injuries_data": [producer], "crew_casualties_data": [],
			"defeated_enemies": [], "enemy_type": "Raiders",
		}, {"mission_source": "opportunity"})
		if not ok:
			continue
		var m: Dictionary = _find(campaign, str(victim["character_id"]))
		if m.is_empty():
			continue
		if str(m.get("status", "")) == "DEAD" and bool(m.get("is_dead", false)):
			out["dead"] += 1
		elif luck > 0 and int(m.get("luck", -1)) == 0:
			# Survived a roll that would otherwise have killed them, Luck now zero.
			out["saved"] += 1
		if luck > 0 and int(m.get("luck", 0)) > 0:
			out["luck_kept"] += 1
	return out

func _row_luck_death_save() -> void:
	var with_luck: Dictionary = _luck_save_trial("has_luck", 1)
	var control: Dictionary = _luck_save_trial("no_luck", 0)
	print("  [luck_death_save] luck=1 dead=%d saved=%d | control luck=0 dead=%d"
		% [with_luck["dead"], with_luck["saved"], control["dead"]])

	# The control MUST still kill — otherwise "nobody died" proves nothing.
	_check("luck_death_save_control_still_kills", int(control["dead"]) > 0,
		"a crew member with luck=0 still dies on a 1-15 roll across 40 seeds",
		"dead=%d" % control["dead"])
	_check("luck_death_save_prevents_death", int(with_luck["dead"]) == 0,
		"0 deaths when the victim holds 1 Luck (Core Rules p.121)",
		"dead=%d" % with_luck["dead"])
	_check("luck_death_save_fires_and_zeroes_luck", int(with_luck["saved"]) > 0,
		"at least 1 save writes luck=0 on the campaign crew member",
		"saved=%d" % with_luck["saved"])

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 18 — turn rollover mutates the campaign (Core Rules p.76 / p.99 / pp.128-130)
#
#   CampaignPhaseManager.start_new_turn() -> _process_turn_rollover(). Every one of
#   these mechanics reads and writes DICTIONARY crew members, which is the canonical
#   crew shape — and a Dictionary-vs-Resource branch gap is exactly how the deleted
#   _restore_crew_luck() managed to be a no-op for years.
# ═══════════════════════════════════════════════════════════════════════════════

func _row_turn_rollover_mechanics() -> void:
	var campaign: Resource = _make_campaign("rollover", 4)
	# p.76: an upkeep lockout lasts one campaign turn.
	_members(campaign)[0]["locked_out_this_turn"] = true
	# p.99: Sick Bay recovery counts down each turn.
	_members(campaign)[1]["in_sick_bay"] = true
	_members(campaign)[1]["recovery_turns"] = 2
	_members(campaign)[1]["injuries"] = [
		{"type": "Serious injury", "recovery_turns": 2}]
	# pp.128-130: a Character Event status effect expires when duration hits 0.
	_members(campaign)[2]["status_effects"] = [
		{"type": "skip_next_battle", "name": "Shaken", "duration": 1},
		{"type": "no_xp", "name": "Distracted", "duration": 3},
	]
	_bind(campaign)

	var turns_before: int = int(campaign.progress_data.get("turns_played", 0))
	_cpm.start_new_turn()

	var m0: Dictionary = _members(campaign)[0]
	_check("rollover_clears_upkeep_lockout",
		not m0.has("locked_out_this_turn"),
		"locked_out_this_turn erased from the crew member (p.76)",
		"still present=%s" % str(m0.get("locked_out_this_turn")))

	var m1: Dictionary = _members(campaign)[1]
	var inj: Array = m1.get("injuries", [])
	var rec: int = int(inj[0].get("recovery_turns", -1)) if inj.size() > 0 else -1
	_check("rollover_counts_down_sick_bay", rec == 1,
		"injury recovery_turns 2 -> 1 (p.99)", "recovery_turns=%d" % rec)

	var effects: Array = _members(campaign)[2].get("status_effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(str(e.get("type", "")))
	var durations: Array[int] = []
	for e in effects:
		durations.append(int(e.get("duration", -1)))
	_check("rollover_expires_finished_status_effect",
		effects.size() == 1 and types == ["no_xp"] and durations == [2],
		"duration-1 effect removed, duration-3 decremented to 2 (pp.128-130)",
		"remaining=%s durations=%s" % [str(types), str(durations)])

	# turns_played is owned by GameState.advance_turn()/CampaignTurnController, both of
	# which are MONOTONIC guards. Rollover must never lower it (the loaded-save freeze).
	var turns_after: int = int(campaign.progress_data.get("turns_played", 0))
	_check("rollover_never_lowers_turns_played", turns_after >= turns_before,
		"turns_played >= %d after rollover" % turns_before, str(turns_after))

# ═══════════════════════════════════════════════════════════════════════════════
# ROW 19 — save/load round-trip preserves campaign state
#
#   to_dictionary() -> from_dictionary() on a fresh core. Compared field by field on
#   the CANONICAL owners named in the data-ownership table (CLAUDE.md), not on a UI
#   read. Includes the reaction/reactions dual key, which is what rendered "R: 0" on
#   every crew card of every pre-existing save.
# ═══════════════════════════════════════════════════════════════════════════════

func _row_save_load_round_trip() -> void:
	var campaign: Resource = _make_campaign("roundtrip", 4)
	campaign.credits = 37
	campaign.story_points = 4
	campaign.equipment_data = {"equipment": [
		{"id": "itm_1", "name": "Blade", "type": "weapon"},
		{"id": "itm_2", "name": "Stim-pack", "type": "gear"},
	]}
	_members(campaign)[0]["is_captain"] = true
	_members(campaign)[1]["experience"] = 9
	campaign.progress_data["turns_played"] = 6

	var restored: Resource = _core_script.new()
	restored.from_dictionary(campaign.to_dictionary())

	var problems: Array[String] = []
	if int(restored.credits) != 37:
		problems.append("credits %d != 37" % int(restored.credits))
	if int(restored.story_points) != 4:
		problems.append("story_points %d != 4" % int(restored.story_points))
	if int(restored.progress_data.get("turns_played", -1)) != 6:
		problems.append("turns_played %s != 6"
			% str(restored.progress_data.get("turns_played")))
	var stash: Array = restored.equipment_data.get("equipment", [])
	if stash.size() != 2:
		problems.append("ship stash size %d != 2" % stash.size())
	var rm: Array = _members(restored)
	if rm.size() != 4:
		problems.append("crew size %d != 4" % rm.size())
	else:
		if not bool(rm[0].get("is_captain", false)):
			problems.append("captain flag lost")
		if int(rm[1].get("experience", -1)) != 9:
			problems.append("crew XP %s != 9" % str(rm[1].get("experience")))
		for i in range(rm.size()):
			var m: Dictionary = rm[i]
			# Both spellings must survive: battle reads the plural, the crew UI the
			# singular (CampaignDashboard.gd:621 renders "R:" from "reaction").
			if int(m.get("reaction", -1)) != 2 or int(m.get("reactions", -1)) != 2:
				problems.append("member %d reaction=%s reactions=%s (want 2/2)"
					% [i, str(m.get("reaction")), str(m.get("reactions"))])
	_check("save_load_round_trip_preserves_campaign_state", problems.is_empty(),
		"credits/story points/turn/stash/crew/captain/XP/reaction keys all survive",
		str(problems))
