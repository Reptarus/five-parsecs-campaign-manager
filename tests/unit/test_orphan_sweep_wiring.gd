extends GdUnitTestSuite
## The four rules wired (or un-wired) by the 2026-09-10 orphan sweep.
##
## Each one was an accessor that was complete, byte-faithful to the book, and had
## ZERO callers — the "correct code, no call site" shape that closed the Aug 2026
## ledger. A caller census finds them; nothing else does, because both halves
## exist and both halves are right.
##
##   Compendium p.114  invasion recovery   FactionSystem.process_invasion_recovery()
##   Compendium p.115  Dark secrets payoff FactionSystem.resolve_dark_secrets_quest()
##   Core Rules p.151  Black Job prompts   BlackZoneSystem.get_active_passive_rules()
##                                         BlackZoneSystem.get_ending_rules()
##
## The fourth case is a REGRESSION GUARD on a correction rather than a wiring:
## `_end_civil_war()` used to generate two new Factions, citing p.114. That
## sentence belongs to p.114's "Invasion!?" column, not to its Fringe World
## Strife column, and p.151's Civil War row says nothing about Factions at all.
## It was a rule read out of the neighbouring block.
##
## gdUnit4 v6.0.3 compatible.

const Processor = preload("res://src/core/campaign/phases/post_battle/GalacticWarProcessor.gd")
const Context = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const Guide = preload("res://src/core/battle/BattleFlowGuide.gd")
const BlackZone = preload("res://src/core/mission/BlackZoneSystem.gd")

const GUIDE_SRC := "res://src/core/battle/BattleFlowGuide.gd"
const RESOLVER_SRC := "res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd"
const WAR_SRC := "res://src/core/campaign/phases/post_battle/GalacticWarProcessor.gd"
const UPKEEP_SRC := "res://src/ui/screens/world/components/UpkeepPhaseComponent.gd"

const PLANET := "reclaimed_world"


## Feeds PostBattleContext.roll_2d6()/.roll_d6() a scripted sequence. A 2D6 is two
## roll_d6() calls, so "10" is queued as [5, 5]. Falls back to 1 so an
## over-consuming test is loud rather than random.
class StubDice extends RefCounted:
	var values: Array = []
	var consumed: int = 0

	func roll_d6(_context: String = "") -> int:
		if consumed < values.size():
			var v: int = int(values[consumed])
			consumed += 1
			return v
		return 1


## `_get_invaded_planets()` reads ctx.game_state.current_campaign.invaded_planets,
## so the stub has to carry that exact chain — reaching for the campaign directly
## would test a path the processor does not take.
class StubGameState extends RefCounted:
	var current_campaign: Variant = null


func _faction_system() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/FactionSystem")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


## Source with whole-line comments stripped. A `contains()` assertion against raw
## source is satisfied by a file's own OBITUARY for the symbol — the lesson that
## made lint_orphan_assets strip comments before its edge scan.
func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _read(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# ══════════════════════════════════════════════════════════════════════════════
# Core Rules p.151 — the Black Job round prompts render from data
# ══════════════════════════════════════════════════════════════════════════════

func test_the_black_job_prompts_carry_the_books_own_numbers() -> void:
	var prompts: Array = Guide.build_black_job_round_prompts(2, true, false)
	assert_array(prompts).override_failure_message(
		"a Black Job round produced no prompts at all").is_not_empty()

	var joined := ""
	for p: Variant in prompts:
		if p is Dictionary:
			joined += str((p as Dictionary).get("text", "")) + "\n"

	# Straight from p.151: teams of 4, entrance 2D6" down the edge, figures 1D6"
	# onto the table, 1D6 activation, 8" proximity wake.
	for clause: String in ["4-figure", "2D6", "1D6", "8\""]:
		assert_str(joined).override_failure_message(
			"the p.151 round prompt no longer states '%s'" % clause
		).contains(clause)


func test_those_numbers_come_from_the_json_and_not_from_a_literal() -> void:
	## ⚠ THIS IS THE CASE THAT MATTERS, and the one above cannot replace it.
	## The prompts were already byte-faithful to p.151 — they were simply spelled
	## out as literals, while `get_active_passive_rules()` and `get_ending_rules()`
	## sat at zero callers reading the SAME rules from black_zone_jobs.json. Two
	## copies of one mechanic, one of them the text the player acts on. The
	## previous case passes happily against either.
	var data_team_size: int = int(
		BlackZone.get_opposition_rules().get("team_size", -1))
	var data_die: String = str(
		BlackZone.get_active_passive_rules().get("activation_die", ""))
	var data_reach: int = int(
		BlackZone.get_active_passive_rules().get("proximity_activation_inches", -1))

	assert_int(data_team_size).override_failure_message(
		"black_zone_jobs.json lost opposition.team_size").is_equal(4)
	assert_str(data_die).override_failure_message(
		"black_zone_jobs.json lost active_passive_rules.activation_die"
	).is_equal("1D6")
	assert_int(data_reach).override_failure_message(
		"black_zone_jobs.json lost active_passive_rules.proximity_activation_inches"
	).is_equal(8)

	# The guide must READ them, not restate them.
	var src: String = _code_only(GUIDE_SRC)
	assert_bool(src.contains("get_active_passive_rules()")).override_failure_message(
		"BattleFlowGuide does not call get_active_passive_rules(); the p.151"
		+ " numbers are being restated instead of read").is_true()
	assert_bool(src.contains("get_ending_rules()")).override_failure_message(
		"BattleFlowGuide does not call get_ending_rules()").is_true()

	# And the literals must be GONE from the prompt strings. A surviving
	# `"4-figure team"` would mean the data read is decorative.
	assert_bool(src.contains("another 4-figure team")).override_failure_message(
		"a hardcoded '4-figure team' literal is still in the prompt text"
	).is_false()
	assert_bool(src.contains("within 8\\\".")).override_failure_message(
		"a hardcoded 8\" proximity literal is still in the prompt text").is_false()


func test_a_non_black_job_round_produces_no_black_job_prompts() -> void:
	# The guard that keeps p.151 off every other battle in the game.
	assert_array(Guide.build_black_job_round_prompts(2, false, false)).is_empty()


func test_the_evac_prompt_names_the_round_the_player_must_survive() -> void:
	# p.151: "If you have Won, you will be evac'ed out at the end of the FOLLOWING
	# round. Hang in there!" — a round to survive, not a formality. The delay is
	# `ending.win_evac_delay`, so the prompt can say WHICH round rather than
	# leaving the player to add one.
	var delay: int = int(BlackZone.get_ending_rules().get("win_evac_delay", 1))
	assert_int(delay).is_equal(1)

	var prompts: Array = Guide.build_black_job_round_prompts(3, true, true)
	var evac := ""
	for p: Variant in prompts:
		if p is Dictionary and str((p as Dictionary).get("id", "")) == "black_job_evac":
			evac = str((p as Dictionary).get("text", ""))
	assert_str(evac).override_failure_message(
		"winning a Black Job produced no evac prompt").is_not_empty()
	assert_str(evac).override_failure_message(
		"the evac prompt does not name round %d" % (3 + delay)
	).contains(str(3 + delay))

	# ...and it must NOT appear before the objective is met.
	var unwon: Array = Guide.build_black_job_round_prompts(3, true, false)
	for p: Variant in unwon:
		if p is Dictionary:
			assert_str(str((p as Dictionary).get("id", ""))).is_not_equal("black_job_evac")


# ══════════════════════════════════════════════════════════════════════════════
# Compendium p.114 — reclaiming an invaded world pays its defenders
# ══════════════════════════════════════════════════════════════════════════════

func _war_ctx(invaded: Array, dice: Array) -> Context:
	var ctx: Context = Context.new()
	ctx.campaign = {"progress_data": {}}
	var gs := StubGameState.new()
	gs.current_campaign = {"invaded_planets": invaded}
	ctx.game_state = gs
	var stub := StubDice.new()
	stub.values = dice
	ctx.dice_manager = stub
	ctx.battle_result = {}
	return ctx


func test_the_defenders_are_recorded_where_the_war_modifier_is_recorded() -> void:
	## p.114's recovery names the Power 5+ factions that stayed to fight, a whole
	## campaign turn after the invasion — by which time `active_factions` has moved
	## on, so recomputing "who is Power 5+" NOW would pay the wrong factions. The
	## ids therefore have to be banked at invasion time, beside the +1-each war
	## modifier they earned, and in the SAME write so the two cannot disagree.
	var src: String = _code_only(UPKEEP_SRC)
	assert_bool(src.contains("defending_faction_ids")).override_failure_message(
		"UpkeepPhaseComponent never records which factions stayed to fight, so"
		+ " p.114's recovery clause has nothing to act on").is_true()
	assert_bool(src.contains("tracked[\"war_modifier\"]")).override_failure_message(
		"the war modifier write moved away from the defender-id write; they must"
		+ " stay in one pass").is_true()


func test_a_reclaimed_world_pays_its_defenders_and_a_contested_one_does_not() -> void:
	var src: String = _code_only(WAR_SRC)
	# The call must sit in the VICTORIOUS branch — "if the world is reclaimed".
	assert_bool(src.contains("_apply_invasion_recovery(planet)")).override_failure_message(
		"GalacticWarProcessor never applies the p.114 recovery").is_true()
	assert_bool(src.contains("process_invasion_recovery")).override_failure_message(
		"nothing calls FactionSystem.process_invasion_recovery()").is_true()

	var victorious_at := src.find("outcome[\"result\"] = \"victorious\"")
	var recovery_at := src.find("_apply_invasion_recovery(planet)")
	var contested_at := src.find("outcome[\"result\"] = \"contested\"")
	assert_int(victorious_at).override_failure_message(
		"no victorious branch found").is_greater(-1)
	assert_int(recovery_at).override_failure_message(
		"the recovery call is not after the victorious branch — p.114 pays only"
		+ " when the world is RECLAIMED").is_greater(victorious_at)
	assert_bool(contested_at < victorious_at).override_failure_message(
		"branch order changed; this case's position check is no longer valid"
	).is_true()


func test_the_recovery_is_a_no_op_when_nobody_stayed_to_fight() -> void:
	# A world nobody defended is reclaimed by Unity alone. Silent, not a crash —
	# and the p.126 roll itself must still produce its row.
	var planet := {"id": PLANET, "name": "Reclaimed", "war_modifier": 0}
	var proc: Processor = Processor.new()
	var progress: Dictionary = proc.process_galactic_war(
		_war_ctx([planet], [5, 5]))  # 2D6 = 10 -> victorious
	var rows: Array = progress.get("planet_results", [])
	assert_array(rows).override_failure_message(
		"the invaded-planet loop produced no row").is_not_empty()
	assert_str(str((rows[0] as Dictionary).get("result", ""))).override_failure_message(
		"a 2D6 of 10 is Unity Victorious (Core Rules p.126)").is_equal("victorious")


# ══════════════════════════════════════════════════════════════════════════════
# Compendium p.115 — the Dark Secrets Quest can now pay off
# ══════════════════════════════════════════════════════════════════════════════

func test_the_dark_secrets_quest_is_resolved_where_a_quest_concludes() -> void:
	## ⚠ THE PRODUCER WAS LIVE AND THE CONSUMER WAS NOT — the most convincing
	## false positive in this codebase, because every census passes it.
	## `_record_dark_secrets_quest()` is reached from the live D100 faction-event
	## handler and has always stamped `progress_data["dark_secrets_quest"]`;
	## `resolve_dark_secrets_quest()` had ZERO callers. A player could be sent on
	## the Quest and the payoff could never land.
	var fs := _faction_system()
	if fs == null:
		return
	assert_bool(fs.has_method("resolve_dark_secrets_quest")).override_failure_message(
		"FactionSystem lost resolve_dark_secrets_quest()").is_true()
	assert_bool(fs.has_method("_record_dark_secrets_quest")).override_failure_message(
		"the producer is gone; if the quest is no longer handed out, the consumer"
		+ " below should go too").is_true()

	var src: String = _code_only(RESOLVER_SRC)
	assert_bool(src.contains("resolve_dark_secrets_quest(")).override_failure_message(
		"nothing calls resolve_dark_secrets_quest(), so a Dark Secrets Quest is"
		+ " still handed out and can never pay off (Compendium p.115)").is_true()


func test_the_payoff_is_gated_on_actually_winning_the_finale() -> void:
	# p.115 pays "if you complete it successfully". `held_field` is that signal,
	# and it is what every other post-battle reward in this file keys on — a
	# hardcoded `true` would pay a crew that fled.
	var src: String = _code_only(RESOLVER_SRC)
	var at := src.find("resolve_dark_secrets_quest(")
	assert_int(at).is_greater(-1)
	var window := src.substr(at, 160)
	assert_bool(window.contains("held_field")).override_failure_message(
		"the Dark Secrets payoff is not conditioned on winning the finale"
	).is_true()
	assert_bool(window.contains("true)")).override_failure_message(
		"the payoff passes a hardcoded success; p.115 says 'if you complete it"
		+ " successfully'").is_false()


# ══════════════════════════════════════════════════════════════════════════════
# Regression guard — the civil war must NOT generate factions
# ══════════════════════════════════════════════════════════════════════════════

func test_the_civil_war_ending_does_not_generate_new_factions() -> void:
	## ⚠ THIS GUARDS A CORRECTION TO THIS PROJECT'S OWN WORK (2026-09-10).
	##
	## Compendium p.114 carries two independent blocks in two columns. The
	## left/middle one is "Invasion!?" and ends "Generate two new Factions when the
	## war ends" — "the war" there is the INVASION, settled by the p.126 roll. The
	## right-hand block is "Fringe World Strife", whose Civil War clause says only
	## "Factions will go to ground until the war is over". p.151's Civil War row
	## says nothing about Factions at all.
	##
	## `_end_civil_war()` called generate_world_factions() citing p.114 — a rule
	## read out of the neighbouring column, and nothing asserted it either way.
	var src: String = _code_only(WAR_SRC)
	var at := src.find("func _end_civil_war")
	assert_int(at).override_failure_message("_end_civil_war is gone").is_greater(-1)
	var body := src.substr(at, 1400)
	assert_bool(body.contains("generate_world_factions")).override_failure_message(
		"the civil-war ending generates new Factions again. That sentence is in"
		+ " p.114's Invasion column, not its Fringe World Strife column, and"
		+ " p.151 does not mention Factions — it belongs in the p.126 victorious"
		+ " branch, where _apply_invasion_recovery() now puts it.").is_false()

	# The suppression lift is the one thing that DOES belong there.
	assert_bool(body.contains("_lift_civil_war")).override_failure_message(
		"the civil-war ending no longer lifts p.114's faction suppression, so the"
		+ " factions stay gone to ground forever").is_true()
