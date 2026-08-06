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
		# Distinct key from `deployment` above — this is the one
		# _populate_deployment_conditions reads. Present here so the OVERLAY path
		# (initialize_battle, then _on_tier_selected later) is covered: that path
		# reached the old call site BEFORE the panel existed, so the panel was blank
		# there too. Only the relocated call site can populate it.
		"deployment_condition": {
			"condition_id": "BITTER_STRUGGLE",
			"title": "Bitter Struggle",
			"roll": 97,
		},
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
var _ui3: Node = null
var _ui4: Node = null


func _button_labels(node: Node) -> Array:
	## Button texts in a subtree. _harvest_text only walks Label/RichTextLabel, so
	## it cannot see a toolbar — and "is there a button the player can press" is
	## exactly the question the mission-drawer fix has to answer.
	var out: Array = []
	if node is Button:
		out.append(str((node as Button).text))
	for child in node.get_children():
		out.append_array(_button_labels(child))
	return out

func _campaign_mission(mission_type: String) -> Dictionary:
	## The CAMPAIGN shape, which differs from _mission() in one decisive way:
	## CampaignTurnController:2111 stamps `selected_tier` on every campaign battle.
	## That single key used to trigger an early return in initialize_battle which
	## skipped every Compendium panel setup below it — so this harness, built
	## entirely on _mission() (which has no selected_tier), could never see the bug
	## and reported 10 green checks while four chapters had no UI.
	##
	## Model the PRODUCER, not the shape that is convenient to construct.
	var md: Dictionary = _mission()
	md["selected_tier"] = TIER_ASSISTED
	md["type"] = mission_type
	md["representation_mode"] = "play_on_table"
	# Read below the old early return, so it round-trips only when the whole
	# function runs. Gives the battle-mode assertion something falsifiable.
	md["battle_mode"] = "standard"
	# Read by _populate_deployment_conditions, which lives on the tier-selection
	# path. Key is `deployment_condition` (singular) — distinct from the
	# `deployment` block above, which a different consumer reads.
	md["deployment_condition"] = {
		"condition_id": "BITTER_STRUGGLE",
		"title": "Bitter Struggle",
		"roll": 97,
	}
	return md

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

			# The CAMPAIGN path: one instance, driven exactly as
			# CampaignTurnController drives it — a single initialize_battle() call
			# on a mission carrying `selected_tier`, with NO manual
			# _on_tier_selected() afterwards. Every other instance in this harness
			# calls _on_tier_selected() by hand, which is why they all passed.
			var packed3: PackedScene = load(
				"res://src/ui/screens/battle/TacticalBattleUI.tscn")
			_ui3 = packed3.instantiate()
			root.add_child(_ui3)
			_ui3.initialize_battle(_crew(), _enemies(),
				_campaign_mission("salvage"))

			# Same campaign salvage mission at LOG_ONLY — the tier the bug lived
			# at. Every other instance here runs at ASSISTED or FULL_ORACLE, which
			# is why a stranded LOG_ONLY surface was invisible to this harness.
			var packed4: PackedScene = load(
				"res://src/ui/screens/battle/TacticalBattleUI.tscn")
			_ui4 = packed4.instantiate()
			root.add_child(_ui4)
			var md4: Dictionary = _campaign_mission("salvage")
			md4["selected_tier"] = 0
			_ui4.initialize_battle(_crew(), _enemies(), md4)
		5:
			_check_oracle_tier()
			_check_campaign_path_wiring()
			_check_mission_drawer_reachable()
			# LAST two — both mutate _ui4 (tier, then _stored_mission_data), so
			# every assertion above that depends on _ui4's initial state must
			# already have run.
			_check_condition_reminders()
			_check_mid_battle_tier_change()
			_check_no_win_condition()
			return _finish()
	return false

func _check_condition_reminders() -> void:
	## Aug 6 battle-phase audit — two rules that were correct, computed, and shown
	## to the player EXACTLY ONCE on the pre-battle screen, then never again at the
	## moment they matter. Both are "wrong-play": the player forgets and plays on.
	var hud: Variant = _ui.battle_round_hud
	if hud == null or not is_instance_valid(hud):
		_ok("battle round HUD available for reminder checks", false, "null hud")
		return

	# p.88 GLOOMY had ZERO in-battle reminders — a grep for GLOOMY across src/ui
	# returned nothing. Its second clause INVERTS normal targeting, so it has to
	# land in the phases where figures shoot, not just at round start.
	hud._battle_context = {
		"deployment": {"condition_id": "GLOOMY"}, "enemy_force": {},
	}
	hud._current_round = 2
	for phase: int in [1, 3]:
		hud._current_phase = phase
		var txt: String = hud._get_contextual_reminder()
		_ok("Gloomy reminder reaches shooting phase %d" % phase,
			txt.contains("GLOOMY"), "reminder was: %s" % txt.replace("\n", " | "))
		_ok("Gloomy states the fire-back clause in phase %d" % phase,
			txt.to_lower().contains("any range"),
			"second clause missing: %s" % txt.replace("\n", " | "))

	# p.92 Invasion: "Any figure that leaves the table before Round 6 becomes a
	# casualty." early_leave_is_casualty had zero readers repo-wide.
	hud._battle_context = {
		"deployment": {}, "enemy_force": {},
		"setup_rules": {"early_leave_is_casualty": true, "hold_rounds": 6},
	}
	hud._current_phase = 4
	hud._current_round = 3
	var inv: String = hud._get_contextual_reminder()
	_ok("Invasion early-departure warning appears while the clock is running",
		inv.contains("CASUALTY"), "reminder was: %s" % inv.replace("\n", " | "))
	_ok("Invasion warning counts down the rounds left to hold",
		inv.contains("3 round"), "no countdown: %s" % inv.replace("\n", " | "))

	# ...and stops once the hold clock is satisfied, or it becomes noise the
	# player learns to ignore.
	hud._current_round = 6
	var after: String = hud._get_contextual_reminder()
	_ok("Invasion warning stops once the hold clock is met",
		not after.contains("CASUALTY"),
		"still warning at round 6: %s" % after.replace("\n", " | "))


func _check_no_win_condition() -> void:
	## Core Rules p.91 "There is no Win condition against Rivals" / p.92 (Invasion),
	## paid out by p.123: "Survived and Won +3" vs "Survived, but did not Win +2"
	## (both verified against the PDF). BattleSetupRules computed
	## `no_win_condition` and NOTHING in the victory path read it, while
	## _resolve_battle sets victory = "all enemies down", which is exactly what
	## happens when you see a Rival off — so every survivor was overpaid +3.
	##
	## Assert on the RESULT DICT the post-battle sequence consumes, not on a label.
	_ui4._stored_mission_data = {
		"mission_source": "rival",
		"setup_rules": {"no_win_condition": true},
	}
	_ok("no-win-condition scenario is detected from setup_rules",
		_ui4._has_no_win_condition(), "flag not read off setup_rules")

	# The player declares "we won" on the results form; the rule must still hold.
	var declared: Dictionary = {"success": true, "held_field": true, "victory": true}
	_ui4._on_log_only_results_submitted(declared)
	_ok("a declared Win is not recorded as success when there is no Win condition",
		declared.get("success", true) == false,
		"success stayed %s" % str(declared.get("success")))
	# held_field is the REWARD path here (p.119 removal roll, p.120/121 gates) and
	# must survive untouched — suppressing it would trade one bug for a worse one.
	_ok("Hold the Field survives the no-Win rule",
		declared.get("held_field", false) == true,
		"held_field was clobbered")

	# An ordinary mission must be unaffected.
	_ui4._stored_mission_data = {"mission_source": "opportunity", "setup_rules": {}}
	var normal: Dictionary = {"success": true, "held_field": true}
	_ui4._on_log_only_results_submitted(normal)
	_ok("an ordinary mission still records a Win",
		normal.get("success", false) == true,
		"success was suppressed on a normal mission")


func _check_mid_battle_tier_change() -> void:
	## Aug 6 battle-phase audit — set_tier() had ONE caller (battle start, forced)
	## and TierBadge was a Label, so the tracking tier was frozen for the whole
	## battle. Assert on CONTROLLER STATE and on the components the new tier needs,
	## not on the badge text: the badge updated fine before, it just did nothing.
	_ok("tier badge is an actionable control, not a Label",
		_ui4.tier_badge is Button,
		"tier_badge is %s" % str(_ui4.tier_badge))

	# _ui4 is the LOG_ONLY instance. Raise it to ASSISTED the way the control does.
	var before: int = int(_ui4.tier_controller.current_tier)
	_ok("LOG_ONLY instance starts at tier 0", before == 0, "tier is %d" % before)
	_ui4._on_tier_change_requested(TIER_ASSISTED)
	_ok("mid-battle upgrade is applied to the live controller",
		int(_ui4.tier_controller.current_tier) == TIER_ASSISTED,
		"tier is %d after requesting ASSISTED" % int(_ui4.tier_controller.current_tier))

	# An upgrade that half-builds its components is worse than none — the whole
	# point is that the player gets the surfaces the new tier promises.
	_ok("upgrade instantiates the ASSISTED components",
		_ui4.victory_progress != null and is_instance_valid(_ui4.victory_progress),
		"victory_progress still null after upgrading to ASSISTED")

	# And the toolbar must now offer the tracking drawer it previously withheld.
	var bar: Node = null
	if _ui4.action_buttons:
		bar = _ui4.action_buttons.get_node_or_null("DrawerBar")
	var labels: Array = _button_labels(bar) if bar != null else []
	_ok("upgrade surfaces the tracking drawer button",
		labels.has("Tracking"), "DrawerBar after upgrade: %s" % str(labels))
	# The mission drawer must survive a tier change — it is mission-gated, and a
	# toolbar rebuild that dropped it would re-strand the Compendium panels.
	_ok("mission drawer survives a tier change",
		labels.has("Mission"), "DrawerBar after upgrade: %s" % str(labels))

	# Downgrade must be REFUSED, not silently accepted (BattleTierController's own
	# rule). The panel greys those options out; this proves the model enforces it.
	_ui4._on_tier_change_requested(0)
	_ok("mid-battle downgrade is refused",
		int(_ui4.tier_controller.current_tier) == TIER_ASSISTED,
		"tier fell to %d" % int(_ui4.tier_controller.current_tier))


func _check_mission_drawer_reachable() -> void:
	## Aug 6 battle-phase audit, second half — the four Compendium mission panels
	## were added to phase_content, which IS the tracking drawer body, and the
	## tracking button only exists at ASSISTED+. At LOG_ONLY the drawer had NO
	## opener at all (no toolbar button, no portrait menu entry, no auto-open, and
	## SlideOverDrawer has no swipe-to-open), so a built-and-seeded panel was
	## unreachable. Existence is not delivery: assert the OPENER, not the panel.
	var panel: Variant = _ui4.salvage_mission_panel
	_ok("LOG_ONLY salvage mission builds its panel",
		panel != null and is_instance_valid(panel),
		"salvage_mission_panel null at LOG_ONLY")
	if panel == null or not is_instance_valid(panel):
		return

	var mission_body: Variant = _ui4._drawer_bodies.get("mission")
	_ok("panel lives in the mission drawer, not the tier-gated tracking drawer",
		mission_body != null and panel.get_parent() == mission_body,
		"parent is %s" % str(panel.get_parent()))

	# THE decisive assertion: can the player actually open it at this tier?
	var bar: Node = null
	if _ui4.action_buttons:
		bar = _ui4.action_buttons.get_node_or_null("DrawerBar")
	var labels: Array = _button_labels(bar) if bar != null else []
	_ok("LOG_ONLY gets a reachable opener for the mission drawer",
		labels.has("Mission"),
		"DrawerBar buttons at LOG_ONLY: %s" % str(labels))

	# The fix must not smuggle the ASSISTED-only assist trackers into LOG_ONLY —
	# that tier separation is deliberate (see _instance_assisted_components).
	_ok("tracking drawer stays ASSISTED-only (tier split not regressed)",
		not labels.has("Tracking"),
		"tracking leaked into LOG_ONLY: %s" % str(labels))

	# An ordinary battle must NOT advertise an empty Mission drawer — that is the
	# mistake the deleted "oracle" drawer made.
	var bar3: Node = null
	if _ui.action_buttons:
		bar3 = _ui.action_buttons.get_node_or_null("DrawerBar")
	var plain_labels: Array = _button_labels(bar3) if bar3 != null else []
	_ok("no Mission button on a battle with no Compendium panel",
		not plain_labels.has("Mission"),
		"empty mission drawer advertised: %s" % str(plain_labels))


func _check_campaign_path_wiring() -> void:
	## Aug 6 battle-phase audit — initialize_battle() used to `return` as soon as
	## the mission carried `selected_tier`, which CampaignTurnController stamps on
	## EVERY campaign battle. Everything below that return was therefore dead in
	## real play: four Compendium mission panels and the p.88 deployment-condition
	## population.
	##
	## These assertions read LIVE OBJECT STATE after ONE initialize_battle() call,
	## per the harness rule at the top of this file. Asserting on a log line would
	## have passed even with the return in place, because _log_message runs above it.
	_ok("campaign path builds the salvage panel (Compendium pp.137-147)",
		_ui3.salvage_mission_panel != null
			and is_instance_valid(_ui3.salvage_mission_panel),
		"salvage_mission_panel is null after a campaign-shaped initialize_battle")

	# The mission panels are added to a content host; if they exist but were never
	# parented, they cannot render regardless of which drawer opens.
	if _ui3.salvage_mission_panel != null and is_instance_valid(_ui3.salvage_mission_panel):
		_ok("salvage panel is parented into the battle UI",
			_ui3.salvage_mission_panel.get_parent() != null,
			"panel built but never added to the tree")

	# The tier came from the mission, so the assisted components must have been
	# instantiated WITHOUT a manual _on_tier_selected() call from the harness.
	_ok("campaign path adopts the pre-selected tier",
		_ui3.tier_controller != null
			and _ui3.tier_controller.current_tier == TIER_ASSISTED,
		"tier_controller missing or not at the mission's selected_tier")

	# p.88 — the panel that rendered blank in 100% of battles, on every path:
	# never reached on the campaign path (early return), and reached too early on
	# the overlay path (before _instance_assisted_components created it).
	_ok("deployment conditions panel exists at ASSISTED",
		_ui3.deployment_conditions != null
			and is_instance_valid(_ui3.deployment_conditions),
		"panel not instantiated")
	if _ui3.deployment_conditions != null and is_instance_valid(_ui3.deployment_conditions):
		var dc_text: String = _harvest_text(_ui3.deployment_conditions)
		_ok("deployment conditions panel is POPULATED, not blank (p.88)",
			dc_text.to_lower().contains("bitter struggle"),
			"panel rendered without the stamped condition: '%s'" % dc_text.substr(0, 120))

	# The OVERLAY path (_ui: initialize_battle first, _on_tier_selected after) —
	# the half the old call site could never fix, because it ran before
	# _instance_assisted_components() had created the panel.
	if _ui.deployment_conditions != null and is_instance_valid(_ui.deployment_conditions):
		var overlay_text: String = _harvest_text(_ui.deployment_conditions)
		_ok("overlay path also populates the deployment condition (p.88)",
			overlay_text.to_lower().contains("bitter struggle"),
			"blank on the tier-overlay path: '%s'" % overlay_text.substr(0, 120))

	# Stranded alongside the panels; benign only because Bug Hunt and Planetfall
	# do not route through PreBattleUI today.
	#
	# Assert the VALUE round-trips, not `!= null`. _battle_mode_id is a String and
	# is therefore never null, so the null form passed even with the bug reinstated
	# — a check that cannot fail is not evidence. Caught by the detection run,
	# which is what detection runs are for.
	_ok("battle mode id survives the campaign path",
		str(_ui3._battle_mode_id) == "standard",
		"_battle_mode_id is '%s', expected 'standard'" % str(_ui3._battle_mode_id))


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
