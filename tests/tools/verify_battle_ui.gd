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
			# Core Rules p.46 Luck. Non-zero on purpose: with luck 0 the Luck
			# branch is unreachable and a test of it proves nothing.
			"savvy": 1, "luck": 1, "health": 3, "max_health": 3,
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
		# CampaignTurnController.gd:1404 normalizes this onto EVERY battle before
		# either path is taken: `mission_data["mission_objective"] = ...`. It is
		# the key _init_objective_tracker reads, so a fixture without it silently
		# produces a battle with NO objective tracker — and then every row that
		# depends on the tracker passes for the wrong reason.
		"mission_objective": "Fight Off",
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
## Entry-sequence instance. Driven ONLY through initialize_battle() and the
## modal's own Begin Battle button — no _on_tier_selected() by hand, no
## _on_tracker_battle_started() by hand. Every other instance in this harness
## short-circuits those, which is exactly why none of them could see that the
## campaign path started combat before it showed the pre-battle modal.
var _ui5: Node = null
## Phase-controls instance: driven through initialize_battle() and the modal's
## Begin Battle only, so it sits at Round 1 / REACTION_ROLL exactly as a player
## finds it.
var _ui6: Node = null
## Checkpoint round-trip instances.
var _ui7: Node = null
var _ui8: Node = null

## GameState.current_campaign is untyped, and the only thing the checkpoint
## write-through needs of it is a progress_data Dictionary — the same contract
## GameState.set_battlefield_data() has always used. A full campaign core would
## drag in save/load, planets and the phase manager for no added coverage.
class _StubCampaign:
	extends RefCounted
	var progress_data: Dictionary = {"turns_played": 4}
var _ui5_battle_starts: int = 0
var _ui5_form_before: Object = null


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

			# The ENTRY SEQUENCE instance: one initialize_battle() call on a
			# campaign mission at ASSISTED, then nothing. Whatever state this is
			# in afterwards is what a real player is looking at.
			var packed5: PackedScene = load(
				"res://src/ui/screens/battle/TacticalBattleUI.tscn")
			_ui5 = packed5.instantiate()
			root.add_child(_ui5)
			_ui5.initialize_battle(_crew(), _enemies(),
				_campaign_mission("standard"))

			var packed6: PackedScene = load(
				"res://src/ui/screens/battle/TacticalBattleUI.tscn")
			_ui6 = packed6.instantiate()
			root.add_child(_ui6)
			_ui6.initialize_battle(_crew(), _enemies(),
				_campaign_mission("standard"))
			_ui6._on_checklist_dismissed()
		5:
			_check_oracle_tier()
			_check_campaign_path_wiring()
			_check_mission_drawer_reachable()
			_check_entry_sequence()
			_check_phase_controls()
			_check_hit_resolution()
			_check_touch_ergonomics()
			_check_card_input_and_overlay_order()
			# LAST two — both mutate _ui4 (tier, then _stored_mission_data), so
			# every assertion above that depends on _ui4's initial state must
			# already have run.
			_check_condition_reminders()
			_check_mid_battle_tier_change()
			_check_no_win_condition()
			# LAST: it swaps GameState.current_campaign for a stub and puts it back.
			_check_battle_checkpoint()
			return _finish()
	return false

func _script_path_of(node: Node) -> String:
	## Identify a component by its SCRIPT rather than its class or node name:
	## every panel here is a plain Control/PanelContainer built in code, so the
	## script path is the only thing that says which one it is.
	if node == null:
		return ""
	var s = node.get_script()
	return str(s.resource_path) if s else ""


func _overlay_holds(ui: Node, needle: String) -> Dictionary:
	## {present, doomed} for a script whose path contains `needle`, among the
	## overlay's children. `doomed` matters as much as `present`: queue_free()
	## defers to the end of the frame, so a modal that has ALREADY been replaced
	## is still parented and still reads as present for the rest of this frame.
	##
	## Recursive: the pre-battle modal is a plain VBox wrapper holding a
	## ScrollContainer holding the column that holds the checklist, so a
	## direct-children scan finds a scriptless VBox and reports "absent".
	var out := {"present": false, "doomed": false}
	_scan_for_script(ui.overlay_content, needle, out)
	return out


func _scan_for_script(node: Node, needle: String, out: Dictionary) -> void:
	for child in node.get_children():
		if _script_path_of(child).find(needle) >= 0:
			out["present"] = true
			# Any ancestor being freed takes this node with it, so walk up too.
			var n: Node = child
			while n != null and n != node:
				if n.is_queued_for_deletion():
					out["doomed"] = true
				n = n.get_parent()
		_scan_for_script(child, needle, out)


func _check_entry_sequence() -> void:
	## THE BUG THIS PINS (2026-09-03): initialize_battle() used to call
	## _on_auto_deploy_clicked() at its tail, which starts the round machine. So
	## on the campaign path — the ONLY path a real 5PFH battle takes — round 1 was
	## already running before the pre-battle modal was shown. At ASSISTED the
	## REACTION_ROLL handler then raised the Seize the Initiative overlay, and
	## _show_overlay() frees what it replaces, so the Battle Card + checklist were
	## queue_free()d before one frame rendered. At LOG_ONLY the modal survived over
	## a running battle and its Begin Battle button started round 1 AGAIN.
	##
	## Every assertion reads live object state after driving ONLY the real entry
	## points, because the defect lives in the ORDER those entry points run in.
	var checklist := _overlay_holds(_ui5, "PreBattleChecklist")
	_ok("pre-battle modal is shown on the campaign path",
		bool(checklist["present"]))
	_ok("pre-battle modal is not already queued for deletion",
		not bool(checklist["doomed"]),
		"an overlay raised later in the same call stack freed it")
	var seize := _overlay_holds(_ui5, "InitiativeCalculator")
	_ok("Seize the Initiative has NOT pre-empted the modal",
		not bool(seize["present"]))
	_ok("battle has not started before the player pressed Begin Battle",
		int(_ui5.round_tracker.get_current_round()) == 0,
		"round=%d" % int(_ui5.round_tracker.get_current_round()))
	_ok("stage is SETUP while the modal is up",
		int(_ui5.current_stage) == int(_ui5.BattleStage.SETUP),
		"stage=%d" % int(_ui5.current_stage))

	# The objective tracker must exist BEFORE the modal is built: the Battle Card
	# names the objective from it, and falls back to the raw mission keys only
	# when there is none — which is how the card came to print the JOB's name
	# while the log, the glance chip and the results form all tracked the p.89
	# objective instead.
	var tracker_at_modal = _ui5._objective_tracker
	_ok("objective tracker exists while the Battle Card is being built",
		tracker_at_modal != null)

	# Now press Begin Battle, then press a redundant deploy on top of it. Exactly
	# ONE battle_started must come out of the pair.
	_ui5.round_tracker.battle_started.connect(
		func() -> void: _ui5_battle_starts += 1)
	_ui5._on_checklist_dismissed()
	_ui5._on_auto_deploy_clicked()
	_ok("Begin Battle starts the round machine exactly once",
		_ui5_battle_starts == 1, "battle_started x%d" % _ui5_battle_starts)
	_ok("Begin Battle lands on COMBAT, not a dead deployment stage",
		int(_ui5.current_stage) == int(_ui5.BattleStage.COMBAT),
		"stage=%d" % int(_ui5.current_stage))
	_ok("round 1 is running after Begin Battle",
		int(_ui5.round_tracker.get_current_round()) == 1,
		"round=%d" % int(_ui5.round_tracker.get_current_round()))
	_ok("the objective tracker survived the start (not rebuilt mid-fight)",
		_ui5._objective_tracker == tracker_at_modal,
		"a rebuild silently discards every marker and manual toggle recorded")

	# Reuse. This screen is a permanent child of CampaignTurnController.tscn, so
	# battle 2 of a campaign lands on the SAME node as battle 1.
	_ui5._ensure_results_form_drawer()
	_ui5_form_before = _ui5._log_only_results_form
	var crew_before: int = _ui5.crew_units.size()
	_ui5.initialize_battle(_crew(), _enemies(), _campaign_mission("standard"))
	_ok("a second battle does not stack crew on the first",
		_ui5.crew_units.size() == crew_before,
		"before=%d after=%d" % [crew_before, _ui5.crew_units.size()])
	_ok("a second battle does not stack enemies on the first",
		_ui5.enemy_units.size() == 6, "enemies=%d" % _ui5.enemy_units.size())
	_ui5._ensure_results_form_drawer()
	_ok("a second battle gets a FRESH Record Result form",
		_ui5._log_only_results_form != _ui5_form_before,
		"the reused form records battle 2 against battle 1's crew")
	_ok("a second battle resets the round machine to 0",
		int(_ui5.round_tracker.get_current_round()) == 0,
		"round=%d" % int(_ui5.round_tracker.get_current_round()))


func _check_phase_controls() -> void:
	## Core Rules p.113: the Reaction Roll is the round's first act and the
	## player makes it. p.112: Seizing the Initiative happens ONCE, before round 1.
	##
	## What these rows pin, all measured on the live scene before the fix:
	##  * the pool was rolled TWICE — silently on entering phase 0, and again by
	##    the button, so the rail showed one assignment and the log another;
	##  * FOUR controls advanced the round, three of them straight past the roll;
	##  * the Seize overlay reappeared every round, and its modifiers were
	##    dropped by the panel's own _ready() the first time it was displayed.
	var tracker = _ui6.round_tracker
	_ok("battle opens on Round 1 / Reaction Roll",
		int(tracker.get_current_round()) == 1
			and int(tracker.get_current_phase()) == 0,
		"round=%d phase=%d" % [int(tracker.get_current_round()),
			int(tracker.get_current_phase())])

	# Nobody has pressed anything yet, so no figure may carry a slot.
	var pre_assigned: int = 0
	for unit in _ui6.crew_units:
		if int(unit.react_slot) != 0:
			pre_assigned += 1
	_ok("no Reaction Roll is made before the player asks for one",
		pre_assigned == 0, "%d/5 figures already had a Quick/Slow slot"
			% pre_assigned)

	var labels: Array = _button_labels(_ui6.action_buttons)
	_ok("the Reaction Roll phase offers exactly one Roll Reactions button",
		labels.count("Roll Reactions") == 1, str(labels))
	_ok("End Turn is not a second way to advance during combat",
		not _ui6.end_turn_button.visible,
		"a generic End Turn beside the phase's own action skipped the roll")

	# The HUD's five phase chips emitted phase_clicked, which nothing consumed.
	var phase_chip: Node = _ui6.battle_round_hud.get_node_or_null(
		"MainVBox/PhaseContainer/Phase_0")
	if phase_chip == null:
		phase_chip = _find_child_named(_ui6.battle_round_hud, "Phase_0")
	_ok("HUD phase chips are inert indicators, not dead touch targets",
		phase_chip != null
			and phase_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Phase_0 still accepts a press that goes nowhere")

	# Roll. The phase must NOT advance on the same press — the assignment is the
	# one thing this phase exists to show.
	_ui6._on_roll_reactions_pressed()
	var assigned: int = 0
	for unit in _ui6.crew_units:
		if int(unit.react_slot) == 1 or int(unit.react_slot) == 2:
			assigned += 1
	_ok("the roll assigns every living figure a Quick or Slow slot",
		assigned == 5, "assigned=%d/5" % assigned)
	_ok("rolling does not also advance the phase",
		int(tracker.get_current_phase()) == 0,
		"phase=%d — the result was replaced in the same frame it appeared"
			% int(tracker.get_current_phase()))
	_ok("the button becomes the continue affordance once rolled",
		_button_labels(_ui6.action_buttons).has("Continue to Quick Actions"),
		str(_button_labels(_ui6.action_buttons)))

	# A second press continues. Re-rolling here would produce a third answer.
	var dice_before: Array = []
	for unit in _ui6.crew_units:
		dice_before.append(int(unit.initiative_roll))
	_ui6._on_roll_reactions_pressed()
	var dice_after: Array = []
	for unit in _ui6.crew_units:
		dice_after.append(int(unit.initiative_roll))
	_ok("a second press continues instead of re-rolling",
		dice_before == dice_after and int(tracker.get_current_phase()) == 1,
		"before=%s after=%s phase=%d" % [str(dice_before), str(dice_after),
			int(tracker.get_current_phase())])

	# Seize the Initiative: shown once, and its campaign modifiers must survive
	# the panel's own _ready(), which runs on first display and used to rebuild
	# the whole SeizeInitiativeSystem from scratch.
	var sys = _ui6.initiative_calculator.initiative_system
	_ok("Seize modifiers survive the panel entering the tree",
		int(sys.highest_savvy) == 2 and int(sys.calculate_required_roll()) != 10,
		"savvy=%d required=%d" % [int(sys.highest_savvy),
			int(sys.calculate_required_roll())])

	# Round 2 must not re-offer the roll (Core Rules p.112: once, before round 1).
	_ui6._hide_overlay()
	for _i in range(4):
		tracker.advance_phase()
	_ok("round 2 has begun", int(tracker.get_current_round()) == 2,
		"round=%d" % int(tracker.get_current_round()))
	var seize_again := _overlay_holds(_ui6, "InitiativeCalculator")
	_ok("Seize the Initiative is not offered again in round 2",
		not bool(seize_again["present"]),
		"p.112 allows the roll once, before the first round")
	_ok("a new round clears the Reaction Roll so it can be made again",
		not bool(_ui6._reaction_rolled_this_round))

	# T5-05: the log kept its own round counter and drifted off the tracker.
	_ok("the battle log tags lines with the tracker's round",
		int(_ui6.unified_log.current_round)
			== int(tracker.get_current_round()),
		"log=%d tracker=%d" % [int(_ui6.unified_log.current_round),
			int(tracker.get_current_round())])


func _find_child_named(node: Node, nm: String) -> Node:
	for child in node.get_children():
		if child.name == nm:
			return child
		var found := _find_child_named(child, nm)
		if found != null:
			return found
	return null


func _check_hit_resolution() -> void:
	## Core Rules p.46: a Hit is resolved with ONE die — 1D6 + Damage against
	## Toughness, natural 6 always fatal — and the figure is either removed or
	## Stunned. There is no hit-point pool, and there was one: the card's Damage
	## button decremented a current_health seeded to Toughness, so a Toughness 5
	## figure took five presses and the card showed a "4 / 5 HP" the rules never
	## mention. These rows use _ui6, which is mid-battle at Round 2.
	var enemy = _ui6.enemy_units[0]
	var crew0 = _ui6.crew_units[0]

	# Luck is seeded per battle and never written back (p.46: "All Luck is
	# regained automatically after each battle").
	_ok("crew Luck is carried into the battle",
		int(crew0.luck_remaining) == 1,
		"luck_remaining=%d" % int(crew0.luck_remaining))

	# A Stun outcome must not remove the figure.
	var stun_before: int = int(enemy.stun_markers)
	_ui6._on_hit_resolved({"result": "stun", "declared": true}, enemy, false)
	_ok("a Stunned result marks the figure, it does not remove it",
		int(enemy.stun_markers) == stun_before + 1 and not enemy.is_dead,
		"stun=%d dead=%s" % [int(enemy.stun_markers), str(enemy.is_dead)])

	# A casualty on an enemy removes it AND records who is credited (p.123).
	_ui6._on_hit_resolved({"result": "down", "declared": true,
		"credited_to": str(crew0.node_name)}, enemy, false)
	_ok("a casualty result removes the enemy figure", enemy.is_dead)
	_ok("the kill is credited to a crew figure",
		str(enemy.killed_by) == str(crew0.node_name),
		"killed_by=%s" % str(enemy.killed_by))

	# p.46 Luck: a crew figure with Luck cannot be removed while it has any.
	_ui6._on_hit_resolved({"result": "down", "declared": true}, crew0, true)
	_ok("Luck absorbs the casualty instead of removing the figure",
		not crew0.is_dead and int(crew0.luck_remaining) == 0,
		"dead=%s luck=%d" % [str(crew0.is_dead), int(crew0.luck_remaining)])
	_ui6._on_hit_resolved({"result": "down", "declared": true}, crew0, true)
	_ok("once Luck is spent the next casualty removes the figure",
		crew0.is_dead)

	# The p.123 XP keys. kills_by_character had NO producer anywhere in src/
	# before this, and first_casualty_by only had the manual form's picker.
	var prefill: Dictionary = _ui6._build_results_prefill()
	var kills: Dictionary = prefill.get("kills_by_character", {})
	# A LIST of what that figure killed, not a count -- see the shape row
	# at the end of this function for why the type is load-bearing.
	var credited: Array = kills.get("crew_0", [])
	_ok("per-character kill credit reaches the results prefill",
		credited.size() >= 1, str(kills))
	_ok("the battle's first casualty is attributed (p.123)",
		str(prefill.get("first_casualty_by", "")) == "crew_0",
		"first_casualty_by=%s" % str(prefill.get("first_casualty_by", "")))

	# The card must not advertise hit points any more.
	var card_scene: PackedScene = load(
		"res://src/ui/components/battle/CharacterStatusCard.tscn")
	var card = card_scene.instantiate()
	root.add_child(card)
	card.set_character_data({"character_name": "Probe", "toughness": 3,
		"combat": 1, "reactions": 2, "speed": 4, "savvy": 1})
	# OBSERVE THE BUTTON, not the signal's existence. Asserting
	# has_signal("hit_requested") passed just as happily with the handler
	# reverted to apply_damage(1) — the signal is declared either way, so the
	# row detected nothing. Press it and watch what changes.
	var hit_asks: Array = []
	if card.has_signal("hit_requested"):
		card.hit_requested.connect(func(n: String) -> void: hit_asks.append(n))
	var hp_before: int = int(card.current_health)
	card.damage_button.pressed.emit()
	_ok("the card's Hit button asks the host to resolve p.46",
		hit_asks.size() == 1, "emitted %d times" % hit_asks.size())
	_ok("pressing Hit does not tick a hit-point pool",
		int(card.current_health) == hp_before,
		"health %d -> %d; Five Parsecs has no hit points (p.46)"
			% [hp_before, int(card.current_health)])
	var hp_section: Node = card.health_bar.get_parent() if card.health_bar else null
	_ok("the figure card shows no hit-point bar",
		hp_section != null and not hp_section.visible)
	card.queue_free()

	# The kill credit must be a LIST per crew id, never a count.
	# PostBattleCompletion does `var kills: Array = kills_by_character.get(id, [])`
	# and then kills.size(); an int there is an invalid assignment to a
	# typed Array, which ABORTS that function and takes every other
	# lifetime counter and the per-character journal event with it.
	var attribution: Dictionary = _ui6._attribution_prefill()
	var kbc: Dictionary = attribution.get("kills_by_character", {})
	var all_lists: bool = true
	for k in kbc.keys():
		if not (kbc[k] is Array):
			all_lists = false
	_ok("kill credit is a list per crew id, not a count",
		all_lists, "kills_by_character = %s" % str(kbc))


func _checkpoint_mission() -> Dictionary:
	## The campaign shape MINUS `battle_mode`. Nothing in production stamps that
	## key for a standard 5PFH battle — only Bug Hunt, Planetfall and Tactics do —
	## and a non-empty value makes _is_standalone_battle() true, which correctly
	## disables checkpointing for the modes that own their own persistence.
	var md: Dictionary = _campaign_mission("standard")
	md.erase("battle_mode")
	return md


func _check_battle_checkpoint() -> void:
	## A battle is 30-60 minutes at a physical table and NOTHING about one in
	## progress was written anywhere. Worse than losing the notes: on relaunch the
	## turn walks back into MISSION and _initiate_battle_sequence() re-rolls the
	## encounter from a fresh seed, so the app ends up describing a different
	## battle from the one on the table.
	##
	## Driven through the real entry points on two SEPARATE screen instances —
	## one plays and saves, the other is what a relaunch builds.
	var gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		_ok("GameState reachable for the checkpoint round trip", false)
		return
	var previous = gs.current_campaign
	var stub := _StubCampaign.new()
	gs.current_campaign = stub

	var packed: PackedScene = load(
		"res://src/ui/screens/battle/TacticalBattleUI.tscn")
	_ui7 = packed.instantiate()
	root.add_child(_ui7)
	_ui7.initialize_battle(_crew(), _enemies(), _checkpoint_mission())
	_ui7._on_checklist_dismissed()

	# Play a little: an enemy down, a crew figure Stunned and activated.
	_ui7._checkpoint_save_queued = false
	_ui7._mark_casualty(_ui7.enemy_units[0], false)
	# Observed BEFORE the forced write below, or the assertion would be
	# satisfied by the forced write itself and detect nothing.
	var queued_by_mutation: bool = _ui7._checkpoint_save_queued
	_ui7._on_card_stun(str(_ui7.crew_units[1].node_name), _ui7.crew_units[1])
	_ui7.crew_units[1].is_activated = true
	_ui7.round_tracker.advance_phase()
	# Force the write rather than waiting on the debounce — the queue is proven
	# separately below.
	_ui7._write_battle_checkpoint()

	var saved: Dictionary = gs.get_active_battle()
	_ok("an in-progress battle is written to the campaign",
		not saved.is_empty() and int(saved.get("turn", -1)) == 4,
		"nothing about a fight in progress was persisted at all")
	_ok("the checkpoint carries the mission, so a resume cannot re-roll it",
		(saved.get("mission_data", {}) as Dictionary).has("enemy_force"),
		"without it the campaign regenerates different enemies and terrain")
	_ok("marking a figure down queues a save on its own",
		queued_by_mutation,
		"_refresh_unit_rails did not request a checkpoint, so a real battle "
		+ "would only ever be saved if something else happened to ask")

	# What a relaunch builds: a fresh screen, same mission, fresh figures.
	_ui8 = packed.instantiate()
	root.add_child(_ui8)
	_ui8.initialize_battle(_crew(), _enemies(), _checkpoint_mission())

	_ok("a resumed battle skips the pre-battle modal",
		not bool(_overlay_holds(_ui8, "PreBattleChecklist")["present"]),
		"the player deployed those figures 40 minutes ago")
	_ok("the resumed battle is on the round it was left",
		int(_ui8.round_tracker.get_current_round()) == 1
			and int(_ui8.round_tracker.get_current_phase()) == 1,
		"round=%d phase=%d" % [int(_ui8.round_tracker.get_current_round()),
			int(_ui8.round_tracker.get_current_phase())])
	_ok("the enemy that was removed is still removed",
		_ui8.enemy_units[0].is_dead)
	_ok("an enemy that was still standing is still standing",
		not _ui8.enemy_units[1].is_dead)
	_ok("Stun markers survive the interruption",
		int(_ui8.crew_units[1].stun_markers) == 1,
		"stun=%d" % int(_ui8.crew_units[1].stun_markers))
	_ok("activation survives the interruption",
		_ui8.crew_units[1].is_activated,
		"the player would have to remember who had already acted")
	_ok("the resumed screen is in COMBAT, not back at setup",
		int(_ui8.current_stage) == int(_ui8.BattleStage.COMBAT),
		"stage=%d" % int(_ui8.current_stage))

	# A recorded result must retire the checkpoint, or the next battle resumes
	# this one.
	_ui8._clear_battle_checkpoint()
	_ok("finishing the battle clears the checkpoint",
		gs.get_active_battle().is_empty())

	gs.current_campaign = previous


func _count_stop_controls(node: Node) -> int:
	## Controls that would swallow a touch-drag before the drawer's ScrollContainer
	## sees it. MOUSE_FILTER_STOP marks an event HANDLED whether or not the control
	## does anything with it, and CheckBox / SpinBox / OptionButton / Button all
	## default to STOP.
	var n := 0
	if node is Button or node is CheckBox or node is SpinBox \
			or node is OptionButton:
		if (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			n += 1
	for child in node.get_children():
		n += _count_stop_controls(child)
	return n


func _check_touch_ergonomics() -> void:
	## T9-45 on hardware: a drawer scrolls by dragging the thin scrollbar and does
	## nothing at all when dragged in the middle. SlideOverDrawer runs the
	## TouchScrollOpener sweep once, from set_content(), on the EMPTY body — every
	## card and form is added afterwards, so the sweep never reached the Crew, Enemy
	## or Record Result drawers. Those are the three the F9/F10 device findings were
	## about: with several enemies marked down, the last live figure's Mark Down
	## button fell below an unreachable fold.
	var enemy_body = _ui6._drawer_bodies.get("enemies")
	_ok("the enemy drawer accepts a touch-drag after it is populated",
		enemy_body != null and _count_stop_controls(enemy_body) == 0,
		"%d controls still swallow the gesture"
			% (_count_stop_controls(enemy_body) if enemy_body else -1))
	var crew_body = _ui6._drawer_bodies.get("crew")
	_ok("the crew drawer accepts a touch-drag after it is populated",
		crew_body != null and _count_stop_controls(crew_body) == 0,
		"%d controls still swallow the gesture"
			% (_count_stop_controls(crew_body) if crew_body else -1))

	# Portrait hides the TopBar AND the bottom drawer bar, so Record Result — the
	# control that ends a played battle — lived two taps deep in a popup menu.
	var bar = _ui6._mobile_app_bar
	_ok("Record Result is a persistent control in portrait, not a menu entry",
		bar != null and _ui6._record_action_btn != null
			and is_instance_valid(_ui6._record_action_btn)
			and _ui6._record_action_btn.get_parent() != null,
		"the single most important control on the screen was inside ≡ Panels")
	_ok("the portrait Record Result control is touch-sized",
		_ui6._record_action_btn != null
			and _ui6._record_action_btn.custom_minimum_size.y >= 44.0,
		"height=%d" % (int(_ui6._record_action_btn.custom_minimum_size.y)
			if _ui6._record_action_btn else -1))


func _collect_by_class(node: Node, cls: String, out: Array) -> Array:
	for child in node.get_children():
		if child.get_class() == cls or (child.get_script() != null \
				and str(child.get_script().resource_path).ends_with(cls + ".gd")):
			out.append(child)
		_collect_by_class(child, cls, out)
	return out


func _check_card_input_and_overlay_order() -> void:
	## TWO device defects from the 2026-09-04 tablet walk, both invisible to any
	## desktop check that does not look at hit-testing and layer order.
	##
	## T10-05: every button INSIDE a CharacterStatusCard was dead to touch in a
	## drawer — Stun, Hit, Action, Aim, Snap and "?" — while "Mark Down", a SIBLING
	## of the card in the drawer body, worked. The card's root is a PanelContainer,
	## which stretches every visible child across its whole rect, and
	## _ensure_keyword_tooltip_attached() add_child()s a bare KeywordTooltip LAST.
	## So an invisible Control covered the card and was picked for every tap. PASS
	## does not help: per the Godot 4.6 docs an unhandled event on a PASS control
	## propagates UP the hierarchy, never down to what is drawn beneath it.
	var tooltips: Array = []
	var enemy_body = _ui6._drawer_bodies.get("enemies")
	if enemy_body != null:
		_collect_by_class(enemy_body, "KeywordTooltip", tooltips)
	var covering: int = 0
	for t in tooltips:
		if t is Control and (t as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			covering += 1
	_ok("keyword tooltips in a populated card do not intercept taps",
		tooltips.size() > 0 and covering == 0,
		"%d of %d tooltips are still hit-tested and sit over the card's buttons"
			% [covering, tooltips.size()])

	## T10-04: _show_overlay() parents into OverlayLayer, which was layer 10 while
	## DrawerLayer is 92. Both callers reachable from an open drawer — the p.46 Hit
	## sheet and the Mark Down confirm — therefore opened UNDERNEATH the drawer that
	## raised them, along with the 85% scrim. On device that read as a dimmed screen
	## with nothing to tap.
	var drawer_layer = _ui6.get_node_or_null("DrawerLayer")
	var overlay_layer = _ui6.get_node_or_null("OverlayLayer")
	_ok("a modal raised from a drawer renders ABOVE that drawer",
		drawer_layer != null and overlay_layer != null \
			and int(overlay_layer.layer) > int(drawer_layer.layer),
		"OverlayLayer=%d DrawerLayer=%d" % [
			int(overlay_layer.layer) if overlay_layer else -1,
			int(drawer_layer.layer) if drawer_layer else -1])


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
	## P0.2 / U7 — the book's AI instructions were never shown: only a one-line
	## AI_DESCRIPTIONS summary. The routine and the activation order must reach the
	## player at every tier, because a LOG_ONLY player runs the enemy by hand.
	##
	## ⚠ REWRITTEN Sep 2026. This check used to require "base condition" and
	## "1D6" on the DEFAULT card, and it passed — because
	## data/RulesReference/EnemyAI.json held the COMPENDIUM pp.42-43 AI Variations
	## option (base conditions + dice tables) mislabelled as core, and the card
	## printed it whether or not the player owned the DLC. The Core Rules AI is
	## DICELESS (p.42). So the assertions invert: the default card carries the
	## pp.42-43 BULLETS and no dice, and the dice appear only behind the flag.
	var lines: Array = _ui._ai_reference_lines("A")
	var blob: String = "\n".join(PackedStringArray(lines.map(func(l): return str(l))))
	_ok("AI reference resolves the 'A' code to Aggressive data",
		not lines.is_empty(), "no lines returned for code A")
	_ok("the core Aggressive routine reaches the player (Core Rules p.43)",
		blob.contains("advance at least half a move"),
		"core pp.42-43 bullets absent: %s" % blob.substr(0, 160))
	_ok("the core card cites the Core Rules, not a Compendium option",
		blob.contains("Core Rules p."), "no core page cite on the card")

	var dlc: Node = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")
	var variations_on: bool = false
	if dlc and dlc.has_method("is_feature_enabled"):
		var flag: int = int(dlc.ContentFlag.get("AI_VARIATIONS", -1))
		variations_on = flag >= 0 and dlc.is_feature_enabled(flag)
	if variations_on:
		_ok("with AI Variations ON the 1D6 table reaches the player",
			blob.contains("1D6"), "variation table absent with the flag on")
	else:
		_ok("with AI Variations OFF the card offers no dice roll",
			not blob.contains("Otherwise roll 1D6"),
			"the card told a non-DLC player to roll 1D6 for enemy actions")

	# The card the Enemy Actions phase actually renders.
	_ui._show_enemy_actions_ui()
	var card_text: String = _harvest_text(_ui)
	_ok("enemy action card states the activation order (p.113)",
		card_text.to_lower().contains("nearest your edge first"),
		"activation order line absent from the rendered card")
	_ok("enemy action card carries the enemy's AI routine",
		card_text.to_lower().contains("core rules p."),
		"AI routine absent from the rendered card")

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
