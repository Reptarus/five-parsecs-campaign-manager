extends SceneTree
## HEADLESS in-battle UI state verification harness (sibling of verify_post_battle.gd).
##
## Run:
##   godot --headless --path <root> --script res://tests/tools/verify_battle_ui.gd
##
## ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
## The battle-phase sprint fixed a family of defects with ONE shape: a component
## that is built and displayed but never SEEDED, so it silently reports nothing.
## Unit tests on the components pass (the components are fine); what was broken is
## the JOIN between TacticalBattleUI and them. So every assertion here reads the
## LIVE COMPONENT STATE back after driving the real UI entry points. Asserting on
## a label, a log line or a return value is forbidden — that is exactly what hid
## these defects in the first place.
##
## Harness constraints inherited from verify_post_battle.gd (do not "simplify"):
##   * All work runs in _process() on frame >= 2, never _initialize(): under
##     --script the autoloads exist but root.is_inside_tree() is false during
##     _initialize(), so every "/root/X" lookup errors.
##   * Nothing is preload()ed — bare autoload identifiers inside those scripts are
##     not registered as GDScript globals when a --script main loop compiles.

const TIER_ASSISTED := 1

var _frame := 0
var _pass := 0
var _fail := 0
var _ui: Node = null

func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, ("  -> " + detail) if detail != "" else ""])

func _crew() -> Array:
	# 5 crew. A fixture smaller than the bug proves nothing, so this is a real
	# campaign-sized squad rather than the 1-2 figures a minimal fixture would use.
	var out: Array = []
	for i in range(5):
		out.append({
			"character_id": "crew_%d" % i,
			"id": "crew_%d" % i,
			"character_name": "Crew %d" % i,
			"name": "Crew %d" % i,
			"combat": 1, "reaction": 2, "speed": 4, "toughness": 3,
			"savvy": 1, "luck": 0, "health": 3, "max_health": 3,
		})
	return out

func _enemies() -> Array:
	# Shaped EXACTLY as EnemyGenerator.generate_enemies_as_dicts() emits them:
	# the role vocabulary is `role` + `is_leader`, NOT `is_lieutenant`. A fixture
	# that modelled the contract the consumer *expected* is precisely what let the
	# lieutenant/specialist flags stay dead — so this one models the producer.
	var out: Array = []
	for i in range(6):
		var role: String = "standard"
		if i == 0:
			role = "lieutenant"
		elif i >= 5:
			role = "specialist"
		out.append({
			"id": "enemy_%d" % i,
			"type": "Gangers",
			"name": "Gangers Lieutenant" if role == "lieutenant" else "Gangers",
			"role": role,
			"is_leader": role == "lieutenant",
			"speed": 4, "combat_skill": 0, "toughness": 3,
			"reactions": 2 if role == "lieutenant" else 1,
			"panic": "1-2", "ai": "A",
			"special_rules": [],
		})
	return out

func _mission() -> Dictionary:
	# Mirrors the enemy_force block CampaignTurnController writes into mission_data.
	return {
		"title": "Harness Battle",
		"mission_source": "opportunity",
		"objective": "Fight Off",
		"enemy_force": {
			"type": "Gangers",
			"count": 6,
			"speed": 4, "combat_skill": 0, "toughness": 3,
			"ai": "A",
			"panic": "1-3",
			"special_rules": [],
			"units": _enemies(),
		},
		"deployment": {"condition_id": "BITTER_STRUGGLE",
			"condition_title": "Bitter Struggle"},
		# The bundle BattleSetupRules computes at scenario setup. Four of its
		# fields shipped with NO consumer at all — panic_range_delta,
		# round_one, hold_rounds and early_leave_is_casualty were computed and
		# read by nothing, which is the exact "built but never seeded" shape
		# this harness exists to catch. These rows pin the joins.
		"setup_rules": {
			"panic_range_delta": -1,
			"hold_rounds": 6,
			"early_leave_is_casualty": true,
			"round_one": {"crew_all_slow": true, "delayed_crew": 2},
			"setup_notes": [], "loss_penalties": [],
		},
		# Shaped as CampaignTurnController writes it. Hardcore is -2 and the crew
		# is outnumbered 6-to-5, so the net modifier is -1 (Core Rules p.112).
		"initiative_context": {
			"highest_savvy": 2,
			"outnumbered": true,
			"hired_muscle": false,
			"difficulty_index": 2,
			"enemy_modifier": 0,
			"enemy_name": "Gangers",
		},
	}

var _ui2: Node = null

func _process(_delta: float) -> bool:
	## Frame-stepped, not awaited: this is a SceneTree main loop, so an `await`
	## here would let _process return before the assertions ran. The oracle is
	## activated via call_deferred (the panel must finish _ready() first), which
	## is why its assertions live two frames after its setup.
	_frame += 1
	if _frame < 2:
		return false

	match _frame:
		2:
			print("\n=== verify_battle_ui ===\n")
			var packed: PackedScene = load(
				"res://src/ui/screens/battle/TacticalBattleUI.tscn")
			if packed == null:
				print("  FAIL  could not load TacticalBattleUI.tscn")
				return _finish()
			_ui = packed.instantiate()
			root.add_child(_ui)

			# Drive the REAL entry points, in the real order.
			_ui.initialize_battle(_crew(), _enemies(), _mission())
			_ui._on_tier_selected(TIER_ASSISTED)
			# _battle_context (which the phase cards read) is assigned when the
			# round tracker starts the battle — drive the real entry point rather
			# than assigning the field, so the test exercises the production path.
			_ui._on_tracker_battle_started()

			_check_morale_seeding()
			_check_enemy_role_flags()
			_check_casualty_bridge()
			_check_hud_wiring()
			_check_feed_strip()
			_check_ai_reference()
			_check_seize_initiative()
			_check_results_prefill()
			_check_end_phase_checklist()
			_check_glance_chips()
			_check_stun_decrement()

			# FULL_ORACLE is a different UI arrangement — verify it on its own
			# instance so the ASSISTED assertions above are not disturbed.
			var packed2: PackedScene = load(
				"res://src/ui/screens/battle/TacticalBattleUI.tscn")
			_ui2 = packed2.instantiate()
			root.add_child(_ui2)
			_ui2.initialize_battle(_crew(), _enemies(), _mission())
			_ui2._on_tier_selected(2)
		5:
			_check_oracle_tier()
			return _finish()
	return false

func _check_ai_reference() -> void:
	## P0.2 / U7 — the book's AI instructions (Core Rules pp.113-115) were never
	## shown: only a one-line AI_DESCRIPTIONS summary. The base condition, the 1D6
	## behaviour table and the activation order must all reach the player, at every
	## tier, because a LOG_ONLY player runs the enemy entirely by hand.
	var lines: Array = _ui._ai_reference_lines("A")
	var blob: String = "\n".join(PackedStringArray(lines.map(func(l): return str(l))))
	_ok("AI reference resolves the 'A' code to Aggressive data",
		not lines.is_empty(), "no lines returned for code A")
	_ok("base condition text reaches the player",
		blob.to_lower().contains("base condition"), "missing base condition")
	_ok("the 1D6 behaviour table reaches the player",
		blob.contains("1D6") and blob.contains("6"), "missing behaviour table")

	# The card the Enemy Actions phase actually renders.
	_ui._show_enemy_actions_ui()
	var card_text: String = _harvest_text(_ui)
	_ok("enemy action card states the activation order (p.113)",
		card_text.to_lower().contains("nearest your edge first"),
		"activation order line absent from the rendered card")
	_ok("enemy action card carries the behaviour table",
		card_text.to_lower().contains("otherwise roll 1d6"),
		"behaviour table absent from the rendered card")

func _check_end_phase_checklist() -> void:
	## U3/U4 — the End-Phase rows were inert CheckBoxes with no signal and no
	## state, and the enemy give-up roll (Core Rules pp.114-115) did not exist
	## anywhere in the app, so a player who completed their objective had no way
	## to learn the battle could end there.
	var card: Control = _ui._build_end_phase_checklist()
	var text: String = _harvest_text(card)
	_ok("morale row states the actual dice to roll",
		text.to_lower().contains("morale"), "no morale row")
	# One enemy was killed earlier in this run, so the row must name a real count
	# rather than the old unconditional "roll 1D6 per casualty" boilerplate.
	_ok("morale row reflects THIS round's losses",
		text.contains("D6 (enemy lost") or text.contains("no enemy figures lost"),
		"morale row is still generic")
	var buttons: int = _count_buttons(card)
	_ok("checklist rows carry controls that DO the step",
		buttons > 0, "no actionable buttons in the checklist")
	card.queue_free()

	# Give-up roll: absent while the objective is unmet, present once it is met.
	_ok("no give-up prompt before the objective is complete",
		_ui._giveup_check_info().is_empty(),
		"give-up prompt offered with no completed objective")

func _check_stun_decrement() -> void:
	## P1.13 — Core Rules p.118: "Stunned figures may Move OR make a Combat
	## Action. Remove one Stun marker after acting." Nothing removed markers, so a
	## figure Stunned once stayed Stunned for the whole battle.
	var crew: Array = _ui.get("crew_units")
	var unit = crew[0]
	unit.stun_markers = 2
	_ui._on_card_action(unit.node_name, "generic_action", unit)
	_ok("acting removes exactly one Stun marker (p.118)",
		unit.stun_markers == 1, "got %d, expected 1" % unit.stun_markers)
	# An unstunned figure must not go negative.
	unit.stun_markers = 0
	_ui._on_card_action(unit.node_name, "generic_action", unit)
	_ok("an unstunned figure stays at zero markers",
		unit.stun_markers == 0, "got %d" % unit.stun_markers)

func _check_glance_chips() -> void:
	## U5 — round, enemies-left + Panic range, objective and active deployment
	## condition are the numbers a player checks constantly at a physical table.
	## All of them previously required opening a drawer mid-turn.
	_ui._refresh_glance_chips()
	var row: Variant = _ui.get("_glance_row")
	if row == null or not is_instance_valid(row):
		_ok("glance chip strip exists", false, "_glance_row is null")
		return
	var text: String = _harvest_text(row)
	_ok("glance strip shows the round", text.contains("Round"), text)
	# Two enemy figures have been marked down by this point, so the count must be
	# the LIVE one. A stale chip surviving a refresh (queue_free is deferred) read
	# "5 enemy left" here and is exactly what this assertion pins.
	_ok("glance strip shows the live enemies-left count with its Panic range",
		text.contains("4 enemy left") and text.contains("Panic"), text)
	# Bitter Struggle (p.88 + Compendium p.49): improved enemy Morale means a
	# SMALLER Panic range. The fixture ships panic "1-2" and a -1 delta, so a
	# correctly seeded tracker reads "Panic 1" — and "Panic 1-2" here means the
	# delta never reached the tracker.
	_ok("Bitter Struggle narrowed the enemy Panic range (p.88)",
		text.contains("Panic 1-2") and not text.contains("Panic 1-3"), text)
	# Invasion hold clock (p.92). hold_rounds was computed and displayed nowhere.
	_ok("Invasion hold clock is on the glance strip (p.92)",
		text.contains("Hold"), text)

func _count_buttons(node: Node) -> int:
	var n: int = 1 if node is Button else 0
	for child in node.get_children():
		n += _count_buttons(child)
	return n

func _check_seize_initiative() -> void:
	## P0.6 — initiative_context had exactly two references repo-wide: written by
	## CampaignTurnController, read by PreBattleUI to draw a probability. It never
	## reached the calculator that rolls, so Hardcore -2 / Insanity -3 / the
	## outnumbered +1 were displayed before the battle and dropped inside it.
	var calc: Variant = _ui.get("initiative_calculator")
	if calc == null or not is_instance_valid(calc):
		_ok("initiative calculator instanced at ASSISTED tier", false, "null")
		return
	_ok("initiative calculator instanced at ASSISTED tier", true)

	var sys: Variant = calc.get("initiative_system")
	if sys == null:
		_ok("initiative system reachable", false, "null system")
		return
	_ok("campaign savvy reached the roller",
		int(sys.highest_savvy) == 2, "got %d" % int(sys.highest_savvy))
	# Core Rules p.112: +1 outnumbered, -2 Hardcore -> net -1 off a 10+ target,
	# i.e. the crew needs 11+ on 2D6+Savvy.
	var required: int = int(calc.initiative_system.calculate_required_roll())
	_ok("difficulty and outnumbered modifiers actually change the target",
		required != 10, "required roll is still the unmodified 10")

	# The outcome must land where the briefing reads it.
	calc._on_roll_pressed()
	var ctx: Dictionary = _ui.get("_battle_context")
	_ok("seize outcome recorded into _battle_context for the briefing",
		ctx.has("seize_initiative_result"),
		"seize_initiative_result still unwritten")

func _check_results_prefill() -> void:
	## P0.4 — Record Result used to open blank. _build_results_prefill read ONLY
	## the objective tracker, never crew_units/enemy_units, so a player who spent
	## the fight marking figures down saw every box unchecked and zero kills.
	## Two enemies and one crew member are already down at this point (the casualty
	## bridge check marked one enemy; mark the rest here through the real chokepoint).
	var crew: Array = _ui.get("crew_units")
	var enemies: Array = _ui.get("enemy_units")
	_ui._mark_casualty(crew[2], true, false)
	_ui._mark_casualty(enemies[3], false, true)

	var prefill: Dictionary = _ui._build_results_prefill()
	_ok("prefill counts the enemies actually marked down",
		int(prefill.get("enemies_defeated", 0)) == 2,
		"got %s" % str(prefill.get("enemies_defeated")))
	_ok("prefill carries per-figure defeated-enemy records (rival stamping)",
		(prefill.get("defeated_enemies", []) as Array).size() == 2,
		"got %d" % (prefill.get("defeated_enemies", []) as Array).size())
	_ok("prefill reports the downed crew member by index",
		prefill.get("downed_crew_indices", []) == [2],
		"got %s" % str(prefill.get("downed_crew_indices")))
	_ok("prefill reports the round actually reached",
		int(prefill.get("rounds", 0)) >= 1, "got %s" % str(prefill.get("rounds")))

	# And it must actually reach the form's controls, not just the dict.
	_ui._ensure_results_form_drawer()
	var form: Variant = _ui.get("_log_only_results_form")
	if form == null or not is_instance_valid(form):
		_ok("results form built", false, "form is null")
		return
	var inj: Array = form.get("_injury_checks")
	_ok("downed crew arrives pre-ticked in the form",
		inj != null and inj.size() > 2 and bool(inj[2].button_pressed),
		"injury checkbox for crew 2 not ticked")
	# Core Rules p.122: going down mid-battle must NOT pre-declare a kill — the
	# post-battle Injury Table roll decides dead / injured / recovered.
	var cas: Array = form.get("_casualty_checks")
	_ok("a downed figure is NOT pre-declared killed (p.122)",
		cas != null and cas.size() > 2 and not bool(cas[2].button_pressed),
		"casualty checkbox for crew 2 was ticked")
	var spin: Variant = form.get("_enemies_defeated_spin")
	_ok("enemies-defeated spinner arrives pre-filled",
		spin != null and int(spin.value) == 2,
		"got %s" % (str(spin.value) if spin else "<null>"))

func _check_oracle_tier() -> void:
	## The tier-2 Oracle drawer body was created and NOTHING was ever added to it,
	## and activate_oracle() had zero callers — so the button opened a blank panel
	## and the whole oracle subsystem was unreachable.
	if _ui2 == null or not is_instance_valid(_ui2):
		_ok("FULL_ORACLE instance built", false, "_ui2 is null")
		return
	var panel: Variant = _ui2.get("enemy_intent_panel")
	if panel == null or not is_instance_valid(panel):
		_ok("oracle panel instanced at FULL_ORACLE tier", false, "null panel")
		return
	_ok("oracle panel instanced at FULL_ORACLE tier", true)

	var bodies: Dictionary = _ui2.get("_drawer_bodies")
	# The panel is created in the stable tracking host and moved onto the enemy
	# cards by _populate_unit_drawer. Creating it in the enemies body directly
	# gets it queue_free()d on the next repopulate — verified the hard way.
	_ok("oracle panel survives with a live parent",
		panel.get_parent() != null,
		"panel is orphaned")
	_ok("no blank Oracle drawer is left behind",
		not bodies.has("oracle"), "an empty 'oracle' drawer still exists")
	_ok("oracle mode is actually activated",
		bool(panel.get("_oracle_active")), "activate_oracle() never took effect")
	_ok("oracle router built",
		panel.get_oracle_router() != null, "router is null")
	_ok("oracle seeded with the battle's real AI type",
		str(panel.get("_ai_behavior_type")) == "Aggressive",
		"got '%s'" % str(panel.get("_ai_behavior_type")))

func _harvest_text(node: Node) -> String:
	## Concatenate every Label/RichTextLabel string in a subtree. Used only to
	## confirm required RULES TEXT reached a rendered control — the state
	## assertions elsewhere are what prove behaviour.
	var out: String = ""
	if node is RichTextLabel:
		out += (node as RichTextLabel).text + "\n"
	elif node is Label:
		out += (node as Label).text + "\n"
	for child in node.get_children():
		out += _harvest_text(child)
	return out

func _check_morale_seeding() -> void:
	## P0.1 — set_enemy_count / setup_from_enemy_data had ZERO callers, so the
	## End-Phase Morale check could never remove a figure (Core Rules p.114).
	var mt: Variant = _ui.get("morale_tracker")
	if mt == null or not is_instance_valid(mt):
		_ok("morale tracker instanced at ASSISTED tier", false, "morale_tracker is null")
		return
	_ok("morale tracker instanced at ASSISTED tier", true)
	_ok("enemies_remaining seeded from the real force",
		int(mt.enemies_remaining) == 6,
		"got %d, expected 6" % int(mt.enemies_remaining))
	_ok("total_enemies seeded",
		int(mt.total_enemies) == 6, "got %d" % int(mt.total_enemies))
	# Fixture panic is "1-3" and setup_rules carries a -1 Bitter Struggle delta,
	# so a correct seed lands on 2. That single number proves BOTH halves: the
	# hardcoded 1-2 default would have given 1, and a dropped delta would have
	# left 3. Neither mistake can produce 2.
	_ok("panic range read from the enemy entry (1-3) and then narrowed by Bitter Struggle",
		int(mt.panic_range_max) == 2,
		"got %d, expected 2 (entry 3, minus 1 for Bitter Struggle)" % int(mt.panic_range_max))
	_ok("enemy type name reached the panel",
		str(mt.enemy_type_name) == "Gangers", "got '%s'" % str(mt.enemy_type_name))
	_ok("lieutenant counted as Fearless (p.114)",
		int(mt.lieutenant_count) == 1, "got %d" % int(mt.lieutenant_count))

func _check_enemy_role_flags() -> void:
	## The generator marks roles with `role`/`is_leader`; TacticalUnit carried
	## neither, so every `"is_lieutenant" in unit` guard in this file was false and
	## the post-battle defeated-enemy list recorded type "" for every kill.
	var enemies: Array = _ui.get("enemy_units")
	if enemies == null or enemies.is_empty():
		return
	_ok("enemy type carried onto the figure",
		str(enemies[0].enemy_type) == "Gangers",
		"got '%s'" % str(enemies[0].enemy_type))
	_ok("lieutenant role carried onto the figure",
		bool(enemies[0].is_lieutenant), "figure 0 should be the Lieutenant")
	_ok("specialist role carried onto the figure",
		bool(enemies[5].is_specialist), "figure 5 should be the Specialist")
	_ok("rank-and-file figures are neither",
		not bool(enemies[2].is_lieutenant) and not bool(enemies[2].is_specialist))

func _check_casualty_bridge() -> void:
	## A killed enemy must feed BOTH the per-round morale count and the survivor
	## count, exactly once.
	var mt: Variant = _ui.get("morale_tracker")
	if mt == null or not is_instance_valid(mt):
		return
	var enemies: Array = _ui.get("enemy_units")
	if enemies == null or enemies.is_empty():
		_ok("enemy units built", false, "enemy_units empty")
		return
	var before_cas: int = int(mt.casualties_this_round)
	var before_rem: int = int(mt.enemies_remaining)

	_ui._mark_casualty(enemies[1], false, true)

	_ok("killed enemy feeds casualties_this_round",
		int(mt.casualties_this_round) == before_cas + 1,
		"%d -> %d" % [before_cas, int(mt.casualties_this_round)])
	_ok("killed enemy decrements enemies_remaining once",
		int(mt.enemies_remaining) == before_rem - 1,
		"%d -> %d" % [before_rem, int(mt.enemies_remaining)])

	# Re-marking the same figure is idempotent (the chokepoint returns early).
	_ui._mark_casualty(enemies[1], false, true)
	_ok("re-marking the same figure does not double-count",
		int(mt.enemies_remaining) == before_rem - 1,
		"got %d" % int(mt.enemies_remaining))

func _check_hud_wiring() -> void:
	## P0.8 — set_display_tier() and reset_round_tracking() had zero callers, so
	## the End-Phase auto-prompt was suppressed at EVERY tier and the per-round
	## casualty count accumulated across the whole battle.
	var hud: Variant = _ui.get("battle_round_hud")
	if hud == null or not is_instance_valid(hud):
		_ok("battle round HUD instanced", false, "battle_round_hud is null")
		return
	_ok("battle round HUD instanced", true)
	_ok("HUD display tier received from _apply_tier_visibility",
		int(hud.get("_display_tier")) == TIER_ASSISTED,
		"got %d, expected %d" % [int(hud.get("_display_tier")), TIER_ASSISTED])

	# Round rollover must clear the HUD's own per-round casualty tally.
	hud.report_casualty()
	var seeded: int = int(hud.get("_casualties_this_round"))
	_ui._on_round_started(2)
	_ok("round start clears the HUD per-round casualty count",
		seeded > 0 and int(hud.get("_casualties_this_round")) == 0,
		"seeded %d, after round start %d" % [seeded, int(hud.get("_casualties_this_round"))])

func _check_feed_strip() -> void:
	## P0.5 — a second UnifiedBattleLog used to overwrite the var, orphaning the
	## instance parented in the always-visible FeedStrip.
	var log_node: Variant = _ui.get("unified_log")
	if log_node == null or not is_instance_valid(log_node):
		_ok("unified log exists", false, "unified_log is null")
		return
	var host: Node = log_node.get_parent()
	_ok("the live battle log is the one inside the visible FeedStrip",
		host != null and host.name == "FeedHost",
		"parent is '%s'" % (host.name if host else "<none>"))

func _finish() -> bool:
	if _ui and is_instance_valid(_ui):
		_ui.queue_free()
	if _ui2 and is_instance_valid(_ui2):
		_ui2.queue_free()
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
	return true
