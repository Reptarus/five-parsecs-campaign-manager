extends GdUnitTestSuite
## Headless PANEL harness for the Bug Hunt parity audit.
##
## Run (gdUnit4 registers autoloads; a --script probe does NOT):
##   godot --headless --path <root> --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
##         -a tests/tools/probe_bug_hunt_panels.gd --ignoreHeadlessMode
##
## WHY THIS EXISTS AND WHY IT IS NOT IN tests/unit/
## `probe_bug_hunt_desk_walk.gd` covered the Bug Hunt DATA and TURN layer, but it is a
## --script SceneTree probe and therefore structurally unable to touch the panels: they
## resolve autoloads, and CLAUDE.md records that such a probe measures a tree its own
## setup never touched. gdUnit4 registers autoloads, so this harness can build the real
## screens.
##
## It is an INSTRUMENT, not a regression suite. Its assertions are deliberately confined
## to facts that must stay true no matter which Bug Hunt defects get fixed -- "the panel
## builds", "the step ran". Everything the audit actually cares about is PRINTED, never
## asserted, because asserting today's behaviour would pin the bugs in place and turn the
## fix sprint red. That is the `reference_a_green_test_can_detect_nothing` trap inverted:
## a test that locks in a defect is worse than no test.
##
## Read the printed block, not the pass count.
##
## ## CORRECTED 2026-09-20 (Phase 7) -- THE PREMISE ROTTED, AND IT ROTTED DANGEROUSLY
##
## This harness was written against HEAD before the sprint. Phases 4 and 5 changed the
## two things it measures through, so four of its nine cases were reporting on a shape
## the app no longer has. Superseded in place rather than deleted, because the failure
## mode is worth carrying:
##
##   * **P3/P4 printed `Court Martial card rendered? true` from a fixture that stamps no
##     mission.** Zero weighted objectives is exactly the p.201 Court Martial condition,
##     so the true was CORRECT BEHAVIOUR on a degenerate input -- printed under a heading
##     named after the sprint's headline defect. An instrument that cannot tell the defect
##     from the rule is worse than no instrument: it reads as live evidence. The cases now
##     run TWO ARMS (unstamped -> fires, which is right; stamped and scored -> does not).
##   * **P3 read `panel._results.op_progress_modifier`.** Phase 5 made the panel
##     presentation-only: `_results` is `{receipt, answers}`, assigned in `complete()`
##     (:111) which this probe never calls, and `op_progress_modifier` exists nowhere.
##     `.get()` on a missing key is a SILENT DEFAULT, so it printed `<null>` -- four of
##     them together, which is the tell for a missing SHAPE, not four missing values.
##   * **P2 asked whether the battle emits `casualty_ids` / `objectives_completed`.** It
##     never did and it never will. Phase 4 put `BugHuntBattleResultNormalizer` between
##     them, which DERIVES those keys from the stamped mission and the debrief. The case
##     now measures that derivation.
##   * **P8 and P9 described defects Phase 4 fixed** (the `campaign_escalation` key and
##     the Hand Cannon closure). Kept as REGRESSION readouts with the expected answer
##     stated, so a re-break is visible instead of looking like the old normal.
##
## Two facts about this harness that are easy to get wrong:
##   * `_process_post_battle()` PERSISTS (`_persist_battle_result` :195-207 ->
##     `_campaign.persist()`), so every run writes a save. The campaign is named with a
##     `zz_` prefix and `after()` deletes them; never let a probe leave files beside the
##     player's campaigns.
##   * The mission stamp is assigned DIRECTLY to `core.current_mission`.
##     `MissionPanel._persist_stamped_mission()` (:431-442) would produce the same value
##     and also write a save, which a read-measuring probe has no business doing.

const PostBattlePanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntPostBattlePanel.gd")
const MissionPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const AssignmentsPanel := preload("res://src/ui/screens/bug_hunt/panels/SpecialAssignmentsPanel.gd")
const SquadPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntSquadPanel.gd")
const ReviewPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntReviewPanel.gd")
const ConfigPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntConfigPanel.gd")
const EquipmentPanel := preload("res://src/ui/screens/bug_hunt/panels/BugHuntEquipmentPanel.gd")
const TransferPanel := preload("res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")

const CoreScript := preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const PhaseManagerScript := preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const CharGenScript := preload("res://src/core/character/BugHuntCharacterGeneration.gd")

## No class_name (Phase 4 kept it out of the global namespace), so it is preloaded.
const BhNormalizer := preload("res://src/core/battle/BugHuntBattleResultNormalizer.gd")


## The payload TacticalBattleUI ACTUALLY emits for a Bug Hunt battle
## (TacticalBattleUI.gd:6866 result_dict, routed via _on_delegated_battle_completed
## -> temp_data["bug_hunt_battle_result"] -> BugHuntTurnController:400).
## Reproduced key-for-key so the harness measures the real boundary, not a fixture
## invented to match the consumer -- that is the documented
## `reference_a_fixture_that_skips_a_producer_key_hides_a_live_bug` trap.
func _real_battle_result(participant_ids: Array) -> Dictionary:
	return {
		"victory": true,
		"won": true,
		"success": true,
		"held_field": true,
		"objective_id": "bh_probe",
		"objective_met": true,
		"objective_progress": 1,
		"rounds_fought": 5,
		"crew_casualties": 1,
		"crew_injuries": 0,
		"crew_casualties_data": [{"id": participant_ids[0], "name": "Alpha"}],
		"crew_injuries_data": [],
		"crew_participants": participant_ids.duplicate(),
		"defeated_enemies": [],
		"enemies_defeated_count": 4,
		"enemies_remaining": 0,
		"crew_alive": 3,
		"auto_resolved": false,
	}


func _make_campaign(mc_count: int = 4) -> Resource:
	var core: Resource = CoreScript.new()
	## zz_ prefix so the saves this probe writes (see the docblock) can be cleaned
	## up by an unambiguous glob that can never match a player campaign.
	core.campaign_name = "zz Panel Probe"
	var gen = CharGenScript.new()
	var names: Array = []
	for i in range(mc_count):
		names.append("MC%d" % (i + 1))
	var squad: Dictionary = gen.generate_squad(names)
	core.initialize_squad(squad.get("main_characters", []), [])
	core.reputation = 10
	core.start_campaign()
	return core


func _ids(core: Resource) -> Array:
	var out: Array = []
	for mc in core.main_characters:
		out.append(mc.get("id", mc.get("character_id", "")))
	return out


## Depth-first walk collecting every Label's text, so a card's presence can be
## detected by the title the panel actually rendered.
func _all_text(node: Node, out: Array = []) -> Array:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		_all_text(c, out)
	return out


func _buttons(node: Node, out: Array = []) -> Array:
	if node is Button and node is not CheckBox:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)
	return out


func _checkboxes(node: Node, out: Array = []) -> Array:
	if node is CheckBox:
		out.append(node)
	for c in node.get_children():
		_checkboxes(c, out)
	return out


func _has_card(texts: Array, needle: String) -> bool:
	for t in texts:
		if needle.to_lower() in str(t).to_lower():
			return true
	return false


# ── The receipt (Phase 5) ────────────────────────────────────────────
# BugHuntPostBattleResolver.resolve() returns
#   {steps: [{step, title, cite, rolls, lines, effects: [{op, target, amount, cite}],
#             choices, skipped}], choices_needed: []}
# and the panel parks it on `_receipt` (:49, written :176). It reaches `_results` only
# in complete() (:111), which this harness does not call -- which is exactly how the old
# `_results.get("op_progress_modifier")` reads came to print <null> forever.

func _ops(receipt: Dictionary) -> Array:
	var out: Array = []
	for st in receipt.get("steps", []):
		if not (st is Dictionary):
			continue
		for e in st.get("effects", []):
			if e is Dictionary:
				out.append(e)
	return out


func _op_total(receipt: Dictionary, op: String) -> int:
	var total := 0
	for e in _ops(receipt):
		if str(e.get("op", "")) == op:
			total += int(e.get("amount", 0))
	return total


func _op_count(receipt: Dictionary, op: String) -> int:
	var n := 0
	for e in _ops(receipt):
		if str(e.get("op", "")) == op:
			n += 1
	return n


func _step_named(receipt: Dictionary, needle: String) -> Dictionary:
	for st in receipt.get("steps", []):
		if st is Dictionary and needle.to_lower() in str(st.get("title", "")).to_lower():
			return st
	return {}


## Did a Court Martial actually FIRE? Read the receipt's step, never the rendered card.
##
## CORRECTED (Phase 7) on this probe's FIRST RUN, and the correction is worth more than
## the case it fixes. `_has_card(texts, "Court Martial")` printed TRUE in BOTH arms of
## P3 and 10/10 in BOTH arms of P4 -- which reads as the sprint headline defect surviving
## the fix. It was the detector:
##
##   * BugHuntPostBattleResolver :149-150 drops a step only when it is skipped AND
##     lineless: `if step.skipped and step.lines.is_empty(): continue`.
##   * `_step_court_martial`'s PASS branch (:170-215) does the opposite -- it sets
##     `skipped = true` and appends "No Court Martial -- the team completed N
##     Objective(s)." So the step survives the filter by design.
##   * BugHuntPostBattlePanel._render_receipt() (:395-412) renders EVERY surviving step's
##     heading, and `_render_step()` (:414-452) prints a muted "Not applicable this turn."
##     for a skipped one.
##
## So the string "Court Martial" is on screen precisely when the rule decided NOT to hold
## one. A detector that returns the same answer for both outcomes measures nothing
## (reference_a_diagnostic_that_cannot_disagree) -- and it was caught only because the
## receipt was printed beside it and said `step 0 Court Martial ... SKIPPED`.
##
## The receipt's `skipped` flag is the discriminator. `remove_character` is the second,
## independent one -- assert where the damage lands.
func _court_martial_fired(panel: Control) -> bool:
	var step: Dictionary = _step_named(panel._receipt, "Court Martial")
	if step.is_empty():
		return false
	return not bool(step.get("skipped", false))


## The step's own first line -- what the player reads on the card the heading belongs to.
func _court_martial_line(panel: Control) -> String:
	var step: Dictionary = _step_named(panel._receipt, "Court Martial")
	if step.is_empty():
		return "(no Court Martial step in the receipt)"
	var lines: Array = step.get("lines", [])
	return str(lines[0]) if not lines.is_empty() else "(step present, no line)"


## Stamp a mission the way the REAL producer does.
##
## Objectives, their p.185 weights and the p.201 scoring block come from
## BugHuntMissionPanel._generate_mission(), not from a literal written here. A fixture
## that invents the shape measures the consumer against a mission no producer emits --
## and the whole reason Court Martial fired on every real mission was a stamp that was
## never written, so a harness that fabricates one cannot see that class at all.
##
## The assignment is DIRECT. `_persist_stamped_mission()` (MissionPanel :431-442) yields
## the identical dict and ends in `_campaign.persist()`; a probe measuring a READ has no
## business writing a save to do it.
func _stamp_real_mission(core: Resource) -> Dictionary:
	var mp: Control = auto_free(MissionPanel.new())
	add_child(mp)
	mp.set_campaign(core)
	mp.set_phase_manager(null)
	mp.refresh()
	mp._generate_mission()
	var ctx: Dictionary = mp._mission_context.duplicate(true)
	ctx["participant_ids"] = _ids(core)
	core.current_mission = ctx
	return ctx


## Tick every objective checkbox the panel rendered for the stamp.
##
## The debrief card builds one CheckBox per stamped objective (PBP :226-251) and
## `_collect_debrief()` turns the ticked ones into `completed_objective_indices` (:329),
## which the normalizer weights (:87-117). Ticking them is therefore the only faithful
## way to produce a scored mission -- writing `objectives_completed` into the battle dict
## by hand would bypass the very chain this probe exists to measure.
func _tick_objectives(panel: Control) -> int:
	var ticked := 0
	for cb in _checkboxes(panel):
		var box := cb as CheckBox
		if box.button_pressed:
			continue
		box.button_pressed = true
		ticked += 1
	return ticked


## _process_post_battle() persists (see the docblock). Remove what this probe wrote, and
## nothing else -- user://saves/ is the player's campaign directory.
func after() -> void:
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("zz_panel_probe_bh_"):
			DirAccess.remove_absolute("user://saves/" + f)


# ══════════════════════════════════════════════════════════════════════
# 1. Do the panels build at all?
# ══════════════════════════════════════════════════════════════════════

func test_every_bug_hunt_panel_instantiates_and_builds() -> void:
	print("\n=== P1. Panel construction ===")
	var core := _make_campaign()
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	pm.setup(core)

	var specs: Array = [
		["BugHuntPostBattlePanel", PostBattlePanel],
		["BugHuntMissionPanel", MissionPanel],
		["SpecialAssignmentsPanel", AssignmentsPanel],
		["BugHuntSquadPanel", SquadPanel],
		["BugHuntReviewPanel", ReviewPanel],
		["BugHuntConfigPanel", ConfigPanel],
		["BugHuntEquipmentPanel", EquipmentPanel],
		["CharacterTransferPanel", TransferPanel],
	]

	var built := 0
	for spec in specs:
		var panel_name: String = spec[0]
		var script: GDScript = spec[1]
		var p: Control = auto_free(script.new())
		add_child(p)
		if p.has_method("set_campaign"):
			p.set_campaign(core)
		if p.has_method("set_phase_manager"):
			p.set_phase_manager(pm)
		if p.has_method("refresh"):
			p.refresh()
		var texts: Array = _all_text(p)
		var kids: int = p.get_child_count()
		print("   %-26s children=%-3d text nodes=%-3d" % [panel_name, kids, texts.size()])
		built += 1

	# The only invariant worth pinning: they all construct. Everything else is printed.
	assert_int(built).is_equal(specs.size())


# ══════════════════════════════════════════════════════════════════════
# 2. The battle -> post-battle key boundary
# ══════════════════════════════════════════════════════════════════════

func test_battle_result_key_boundary() -> void:
	print("\n=== P2. The battle -> normalizer -> resolver key boundary ===")
	print("   CORRECTED (Phase 7): this case used to ask whether TacticalBattleUI emits")
	print("   casualty_ids / objectives_completed / lost_marine_ids. It does not and never")
	print("   did -- Phase 4 put BugHuntBattleResultNormalizer between them, and the")
	print("   normalizer DERIVES them from the stamped mission and the debrief. What is")
	print("   worth measuring is that derivation, so that is what this prints now.")
	var core := _make_campaign()
	var ids := _ids(core)
	var real := _real_battle_result(ids)
	var stamp := _stamp_real_mission(core)

	print("   TacticalBattleUI emits:")
	var ks: Array = real.keys()
	ks.sort()
	print("      " + str(ks))

	## One completed objective, chosen through the debrief's own vocabulary
	## (completed_objective_indices, PBP :329) rather than by writing the scored total
	## in by hand -- the hand-written form would skip the weighting this measures.
	var debrief := {"completed_objective_indices": [0], "signals_investigated": 0,
		"lost_marine_ids": [], "mvp_id": ""}
	var normalized: Dictionary = BhNormalizer.normalize(
		real.duplicate(true), stamp, debrief)

	print("   the resolver consumes these, and after normalize() they resolve to:")
	for k in ["participant_ids", "casualty_ids", "lost_marine_ids",
			"objectives_completed", "objectives_completed_count", "mission_success",
			"priority", "signals_total"]:
		print("      %-28s emitted by battle? %-5s   after normalize -> %s"
			% [k, str(real.has(k)), str(normalized.get(k, "<ABSENT>"))])

	var objs: Array = stamp.get("objectives", [])
	print("   stamped objectives: %d, weights %s"
		% [objs.size(), str(objs.map(func(o): return o.get("weight", 1)))])
	print("   scoring block (pp.185, 201): %s" % str(stamp.get("scoring", {})))

	## The one invariant worth pinning: the normalizer is ADD-ONLY, so a key the battle
	## screen really did emit must survive it. If that ever stops being true, every
	## number above is measuring a rewrite rather than a derivation.
	assert_bool(normalized.has("crew_casualties_data")).is_true()


# ══════════════════════════════════════════════════════════════════════
# 3. Drive the post-battle panel with the REAL result
# ══════════════════════════════════════════════════════════════════════

## Drive the panel BOTH ways: a played mission that scored NOTHING, and one that scored.
##
## Both arms are STAMPED. Only the ticking differs, and that is the whole point -- p.201
## triggers a Court Martial on zero weighted objectives, so a fixture that differs in
## anything else is not measuring the rule.
##
## CORRECTED TWICE, and the second correction is the instructive one.
##
##   * First version: ONE arm, unstamped, printing `Court Martial card rendered? true`.
##     Read as the sprint headline reproducing. It was the fixture.
##   * Second version: two arms, the first still UNSTAMPED and labelled "the punishment
##     path working". That label was FALSE, and the probe's own output said so -- the arm
##     printed "No Court Martial -- no mission leader took the field." An unstamped
##     fixture supplies no `participant_ids`, so `_mission_leader` (resolver :941-950)
##     finds no `mission_leader_id`, falls back to the first participant, finds none, and
##     returns {}. The step skips at the LEADER test and the objectives test is never
##     reached. The arm was not the punishment path; it was a different skip wearing the
##     same heading.
##
## ⭐ It also made P4's contrast VACUOUS: both arms reported 0/10 Court Martials, which
## looked like the fix working perfectly and was really two different reasons for zero.
## **An arm that agrees with the arm it is contrasted against is not a control** -- vary
## exactly the variable under test, and read what the arm PRINTS rather than what its
## label claims.
##
## ⓘ No Bug Hunt producer writes `mission_leader_id` anywhere (grepped: every
## `is_leader` / `leader_id` hit in src/ is 5PFH or Tactics). The fallback is what makes
## the rule reachable in the real flow, where the stamp always supplies participants. So
## this is a fixture artifact, NOT a product defect -- recorded so it is not re-filed.
func test_post_battle_panel_driven_with_the_real_result() -> void:
	print("\n=== P3. Post-battle panel: scored NOTHING vs scored-and-ticked ===")

	# ── arm 1: a real stamped mission with NO objective ticked. p.201's trigger.
	var core_a := _make_campaign()
	var stamp_a := _stamp_real_mission(core_a)
	var panel_a: Control = auto_free(PostBattlePanel.new())
	add_child(panel_a)
	panel_a.set_campaign(core_a)
	panel_a.set_battle_results(_real_battle_result(_ids(core_a)))
	panel_a.refresh()
	panel_a._process_post_battle()
	var texts_a: Array = _all_text(panel_a)
	var receipt_a: Dictionary = panel_a._receipt
	print("   [0 scored]   objectives stamped: %d, ticked in the debrief: 0"
		% (stamp_a.get("objectives", []) as Array).size())
	print("   [0 scored]   Court Martial FIRED? %s   <-- p.201 says it MUST; this arm is"
		% str(_court_martial_fired(panel_a)))
	print("                the punishment path working, NOT the sprint defect")
	print("   [0 scored]   the card reads: %s" % _court_martial_line(panel_a))
	print("   [0 scored]   removal effects: %d   (a D6 of 1 removes -- p.201)"
		% _op_count(receipt_a, "remove_character"))
	print("   [0 scored]   (heading-only search would say %s in BOTH arms -- see"
		% str(_has_card(texts_a, "Court Martial")))
	print("                _court_martial_fired() for why that is not a detector)")
	print("   [0 scored]   receipt steps: %d" % (receipt_a.get("steps", []) as Array).size())

	# ── arm 2: a real stamped mission with its objectives ticked in the debrief.
	var core_b := _make_campaign()
	var stamp := _stamp_real_mission(core_b)
	var panel_b: Control = auto_free(PostBattlePanel.new())
	add_child(panel_b)
	panel_b.set_campaign(core_b)
	panel_b.set_battle_results(_real_battle_result(_ids(core_b)))
	panel_b.refresh()
	var ticked := _tick_objectives(panel_b)
	panel_b._process_post_battle()
	var texts_b: Array = _all_text(panel_b)
	var receipt_b: Dictionary = panel_b._receipt

	print("   [stamped]    objectives stamped: %d, ticked in the debrief: %d"
		% [(stamp.get("objectives", []) as Array).size(), ticked])
	print("   [stamped]    Court Martial FIRED? %s   <-- the sprint headline: this must"
		% str(_court_martial_fired(panel_b)))
	print("                be false once a played mission scores anything")
	print("   [stamped]    the card reads: %s" % _court_martial_line(panel_b))
	print("   [stamped]    'ZERO objectives completed' shown? %s"
		% str(_has_card(texts_b, "ZERO objectives")))

	# The receipt, read through its real shape. Every one of these was printed as <null>
	# by the pre-Phase-5 field names.
	print("   [stamped]    receipt: %d steps, %d choices needed"
		% [(receipt_b.get("steps", []) as Array).size(),
			(receipt_b.get("choices_needed", []) as Array).size()])
	print("   [stamped]    op_modifier effect total  = %d   <-- pins the win condition"
		% _op_total(receipt_b, "op_modifier"))
	print("   [stamped]    reputation effect total   = %d" % _op_total(receipt_b, "reputation"))
	print("   [stamped]    missions_in_operation     = %d" % _op_total(receipt_b, "missions_in_operation"))
	print("   [stamped]    kill effects              = %d" % _op_count(receipt_b, "kill"))
	print("   [stamped]    muster_out effects        = %d" % _op_count(receipt_b, "muster_out"))
	print("   [stamped]    remove_character effects  = %d   <-- Court Martial removal"
		% _op_count(receipt_b, "remove_character"))
	print("   [stamped]    add_xp effects            = %d" % _op_count(receipt_b, "add_xp"))
	for st in receipt_b.get("steps", []):
		print("      step %s  %-34s rolls=%s%s"
			% [str(st.get("step")), str(st.get("title")), str(st.get("rolls")),
				"  SKIPPED" if bool(st.get("skipped", false)) else ""])

	# The invariant: the panel produced a receipt with steps. Everything above is printed,
	# because asserting today's numbers would pin them.
	assert_bool((receipt_b.get("steps", []) as Array).size() > 0).is_true()


## The sprint headline, measured as a CONTRAST rather than a count.
##
## "Court Martial fired in 20 of 20 runs" was true before the sprint and is still true
## for a mission that scored nothing, because p.201 makes zero weighted objectives the
## trigger. A bare count therefore cannot tell "the stamp is missing" from "the squad
## failed", which is the diagnostic-that-cannot-disagree trap. Ten runs of each arm.
##
## ⚠ BOTH ARMS STAMP. The previous version left arm 0 unstamped and reported 0/10 in
## both arms -- which reads as the fix working and was really two unrelated skips: no
## stamp means no participants, so the step skipped for want of a LEADER and never
## reached the objectives test. **The arms must differ in exactly one variable**, and
## here that variable is whether the debrief's objective boxes are ticked.
func test_court_martial_fires_on_every_mission() -> void:
	print("\n=== P4. Court Martial: 10 scored-nothing runs vs 10 scored-and-ticked ===")
	var fired := [0, 0]
	var guilty := [0, 0]
	var removed := [0, 0]
	for arm in range(2):
		for i in range(10):
			var core := _make_campaign()
			_stamp_real_mission(core)
			var panel: Control = auto_free(PostBattlePanel.new())
			add_child(panel)
			panel.set_campaign(core)
			panel.set_battle_results(_real_battle_result(_ids(core)))
			panel.refresh()
			if arm == 1:
				_tick_objectives(panel)
			panel._process_post_battle()
			var texts: Array = _all_text(panel)
			# NOT `_has_card(texts, "Court Martial")` -- that matched the heading of the
			# card announcing that no Court Martial was held, and reported 10/10 in both
			# arms. See _court_martial_fired().
			if _court_martial_fired(panel):
				fired[arm] += 1
			# "guilty" is a SUBSTRING of "Not guilty" -- the first version of this probe
			# reported GUILTY 20/20 for a 1-in-6 roll. Match the guilty branch's exact
			# wording instead. A detector that cannot distinguish the two outcomes is the
			# `reference_a_diagnostic_that_cannot_disagree` trap.
			if _has_card(texts, "GUILTY"):
				guilty[arm] += 1
			# CORRECTED (Phase 7): removal used to be a COMMENT at :642. Phase 5 made the
			# resolver emit a `remove_character` effect and the phase manager apply it, so
			# the question is no longer "does the panel claim it?" but "is the effect in
			# the receipt?" -- assert where the damage lands.
			removed[arm] += _op_count(panel._receipt, "remove_character")
	print("   [stamped, 0 ticked]        Court Martial %d/10   GUILTY %d/10   removal effects %d"
		% [fired[0], guilty[0], removed[0]])
	print("                              p.201 says zero objectives EARNS this. Expect 10/10.")
	print("   [stamped + scored]         Court Martial %d/10   GUILTY %d/10   removal effects %d"
		% [fired[1], guilty[1], removed[1]])
	print("                              this is the sprint headline: it must be 0/10.")
	print("   ⭐ the CONTRAST is the measurement. Both arms 0/10 would mean the detector")
	print("     stopped discriminating, not that the fix got better.")
	assert_int(fired[1]).is_between(0, 10)


# ══════════════════════════════════════════════════════════════════════
# 4. completed_missions_count: how many increments per mission?
# ══════════════════════════════════════════════════════════════════════

func test_completed_missions_increments_per_mission() -> void:
	print("\n=== P5. completed_missions_count per ONE mission ===")
	var core := _make_campaign()
	var ids := _ids(core)
	var before: int = core.main_characters[0].get("completed_missions_count", 0)
	## CORRECTED (Phase 7): this case ran UNSTAMPED and reported `tally 0 / add_xp 0`,
	## which reads as "the tally is still broken". It was the fixture -- with no stamped
	## mission the resolver scores zero objectives, Court Martial fires and the tally step
	## has nothing to count. The P3/P4 fix was applied to P3/P4 only; ordering a fix
	## against SOME of its consumers is not ordering it.
	_stamp_real_mission(core)

	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_battle_results(_real_battle_result(ids))
	panel.refresh()
	_tick_objectives(panel)
	panel._process_post_battle()
	var after_panel: int = core.main_characters[0].get("completed_missions_count", 0)

	# Now the phase manager applies the same result, as the real flow does.
	var pm = auto_free(PhaseManagerScript.new())
	add_child(pm)
	pm.setup(core)
	## The mutator reads `result.get("receipt", {})` and returns immediately on an empty
	## one, so the pre-Phase-5 `panel._results` (empty until complete()) applied NOTHING
	## and this case silently measured a no-op.
	pm._apply_post_battle_results({"receipt": panel._receipt, "answers": {}})
	var after_pm: int = core.main_characters[0].get("completed_missions_count", 0)

	print("   before                        = %d" % before)
	print("   after the panel rendered       = %d   <-- CORRECTED (Phase 7): the panel is"
		% after_panel)
	print("                                          presentation-only since Phase 5, so")
	print("                                          this must now equal `before`")
	print("   after phase-manager apply      = %d   <-- book says +1 per mission (p.203)"
		% after_pm)
	## The op is `tally` (per character, resolver :316), not `completed_missions` -- the
	## key the CORE stores it under. A receipt reader that guesses the op name from the
	## field name prints a confident 0 for every effect that did fire.
	print("   tally effects in the receipt   = %d (total %+d)"
		% [_op_count(panel._receipt, "tally"), _op_total(panel._receipt, "tally")])
	print("   total_missions_played          = %+d"
		% _op_total(panel._receipt, "total_missions_played"))
	print("   add_xp effects in the receipt  = %d" % _op_count(panel._receipt, "add_xp"))
	assert_int(after_pm).is_greater_equal(after_panel)


# ══════════════════════════════════════════════════════════════════════
# 5. Muster-out past 15
# ══════════════════════════════════════════════════════════════════════

func test_muster_out_for_a_15_mission_veteran() -> void:
	print("\n=== P6. A veteran at 15 completed missions ===")
	for tally in [14, 15, 16]:
		var core := _make_campaign(3)
		for mc in core.main_characters:
			mc["completed_missions_count"] = tally
		## Stamped and scored, for the same reason as P5. Unstamped, step 2 never
		## tallies, so step 3 looks the character up at the tally it already had and the
		## 15+ automatic row is unreachable -- the probe would report the muster check as
		## broken when what is broken is the mission it was handed.
		_stamp_real_mission(core)
		var panel: Control = auto_free(PostBattlePanel.new())
		add_child(panel)
		panel.set_campaign(core)
		panel.set_battle_results(_real_battle_result(_ids(core)))
		panel.refresh()
		_tick_objectives(panel)
		panel._process_post_battle()
		## CORRECTED (Phase 7): this read the muster result out of the panel's RENDERED
		## text with a keyword filter -- `"missions" in s` plus one of MUSTER / Stays /
		## No muster / Automatic -- and printed "NO muster line rendered at all -- the
		## check was SKIPPED" beside a receipt that showed three muster_out effects. The
		## rule worked; the guess about its wording did not. A filter built from words I
		## expected the resolver to use is a second, unversioned copy of its vocabulary,
		## and it rots the moment the real wording changes. Read the step's OWN lines.
		var muster: Dictionary = _step_named(panel._receipt, "Mustering Out")
		var tally_now: int = core.main_characters[0].get("completed_missions_count", 0)
		print("   tally in=%d -> after step 2 the stored tally is %d, step 3 then checks %d"
			% [tally, tally_now, tally_now + 1])
		print("      muster_out effects in the receipt: %d   (p.203: 15+ is automatic)"
			% _op_count(panel._receipt, "muster_out"))
		if muster.is_empty():
			print("      the receipt carries NO 'Check for Mustering Out' step at all")
		else:
			print("      step 3 rolls: %s%s" % [str(muster.get("rolls", [])),
				"   SKIPPED" if bool(muster.get("skipped", false)) else ""])
			for l in muster.get("lines", []):
				print("      " + str(l))
		panel.queue_free()
	assert_bool(true).is_true()


# ══════════════════════════════════════════════════════════════════════
# 6. XP advancement: can a character overspend?
# ══════════════════════════════════════════════════════════════════════

func test_xp_advancement_affordability() -> void:
	print("\n=== P7. XP advancement: press every affordable button in one pass ===")
	var core := _make_campaign(3)
	# 9 XP affords exactly ONE 8-XP advance (Compendium p.204).
	for mc in core.main_characters:
		mc["xp"] = 9
		mc["reactions"] = 1
		mc["combat_skill"] = 0
		mc["toughness"] = 3
		mc["speed"] = 4
		mc["savvy"] = 0

	## Stamped, as P5 and P6 are. XP is awarded per objective scored (p.204), so an
	## unstamped mission offers no advances at all and this case reported "advance buttons
	## offered: 0" -- an empty measurement that looks like a finding.
	_stamp_real_mission(core)
	var panel: Control = auto_free(PostBattlePanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_battle_results(_real_battle_result(_ids(core)))
	panel.refresh()
	_tick_objectives(panel)
	panel._process_post_battle()

	## CORRECTED (Phase 7): this collected BUTTONS whose text contained "XP)" and an
	## arrow, and reported "advance buttons offered: 0". Phase 5 rewrote the panel as
	## presentation-only, and `_render_advancement` (PBP :527-576) now builds a CheckBox
	## per option -- text "<Stat> +1  (N XP)", with `stat` and `xp_cost` METAS and a
	## shared `refit` lambda that re-disables every unchecked box against the running
	## remainder. Nothing is pressed and no XP moves here; the player's picks are
	## collected by `_collect_answers()` (:592) and charged by the resolver.
	##
	## ⭐ Match on the META, not on the rendered text. A text filter re-encodes a
	## presentation decision as a test contract, so a label change breaks the measurement
	## while the rule is fine -- which is exactly what happened, and it printed as a zero
	## that looks like a finding.
	var advance_boxes: Array = []
	for cb in _checkboxes(panel):
		if (cb as CheckBox).has_meta("xp_cost"):
			advance_boxes.append(cb)
	print("   advance options offered: %d   (CheckBox with an `xp_cost` meta)"
		% advance_boxes.size())
	for cb in advance_boxes:
		var b := cb as CheckBox
		print("      %-34s cost=%-2d disabled=%s"
			% [b.text.strip_edges(), int(b.get_meta("xp_cost", 0)), str(b.disabled)])

	## Tick greedily and watch the running total bind. p.204 costs are 6 or 8 against a
	## 9 XP pool, so the SECOND pick must be refused by `refit`, not by the resolver.
	var taken := 0
	for cb in advance_boxes:
		var b := cb as CheckBox
		if b.disabled:
			print("      refused (unaffordable now): %s" % b.text.strip_edges())
			continue
		b.button_pressed = true
		taken += 1
		print("      ticked %-32s -> %d of %d still enabled"
			% [b.text.strip_edges(), advance_boxes.reduce(
				func(acc, x): return acc + (0 if (x as CheckBox).disabled else 1), 0),
				advance_boxes.size()])

	var answers: Dictionary = panel._collect_answers()
	var picks: Array = []
	for k in answers:
		if answers[k] is Array:
			picks.append_array(answers[k])
	print("   ticked %d; _collect_answers() carries %s to the resolver" % [taken, str(picks)])
	print("   MC1 xp is still %s -- the panel is presentation-only since Phase 5, so the"
		% str(core.main_characters[0].get("xp")))
	print("   charge happens in BugHuntPhaseManager, not here. 9 XP affords ONE advance.")
	assert_int(taken).is_greater_equal(0)


# ══════════════════════════════════════════════════════════════════════
# 7. Mission panel: escalation priority + the Hand Cannon lambda
# ══════════════════════════════════════════════════════════════════════

func test_campaign_escalation_priority() -> void:
	print("\n=== P8. Campaign Escalation priority (book p.187: 1-1-2-2-3-4-5-6) ===")
	var core := _make_campaign()
	core.use_campaign_escalation = true
	var panel: Control = auto_free(MissionPanel.new())
	add_child(panel)
	panel.set_campaign(core)
	var seq: Array = []
	for turn in range(1, 9):
		seq.append(panel._calculate_priority(turn, "mess_me_up"))
	print("   escalation ON, turns 1-8 -> %s" % str(seq))
	print("   book p.187               -> [1, 1, 2, 2, 3, 4, 5, 6]")
	var jkey: Dictionary = panel._missions_data
	## CORRECTED (Phase 7): Phase 4 fixed the key. This is now a REGRESSION readout with
	## its expected answer stated -- a bare "present? false" would read as the old defect
	## to anyone who did not know it had been closed.
	print("   'campaign_escalation'        present? %s   (expected false -- never existed)"
		% str(jkey.has("campaign_escalation")))
	print("   'campaign_escalation_option' present? %s   (expected true -- what Phase 4 reads)"
		% str(jkey.has("campaign_escalation_option")))
	assert_int(seq.size()).is_equal(8)


func test_hand_cannon_is_limited_to_one_main_character() -> void:
	print("\n=== P9. Hand Cannon swap: 'One MC only' (p.187) ===")
	var core := _make_campaign(4)
	var panel: Control = auto_free(MissionPanel.new())
	add_child(panel)
	panel.set_campaign(core)
	panel.set_phase_manager(null)
	panel.refresh()
	# refresh() only CLEARS; the loadout section (and therefore the Hand Cannon
	# checkboxes) is built by _generate_mission(), gated on _mission_generated.
	# The first version of this probe stopped at refresh() and found 0 checkboxes,
	# which reads exactly like "the control does not exist" -- a probe that never
	# delivered its own stimulus.
	panel._generate_mission()

	var boxes: Array = []
	for cb in _checkboxes(panel):
		if "hand cannon" in (cb as CheckBox).text.to_lower():
			boxes.append(cb)
	print("   Hand Cannon checkboxes found: %d" % boxes.size())
	## CORRECTED (Phase 7), and the correction is entirely mine. This loop used to do
	## `box.button_pressed = true` AND THEN `box.emit_signal("toggled", true)`. It
	## reported `0 stayed pressed` against an expected 1, which reads as the p.187 limit
	## broken in the other direction, and sent me into the product code hunting a
	## regression that is not there.
	##
	## `BaseButton.set_pressed()` ALREADY emits `toggled`; only `set_pressed_no_signal()`
	## does not. So the first box received the handler TWICE -- once claiming the Hand
	## Cannon, then once more being rejected by its own claim and cleared with
	## `set_pressed_no_signal(false)` -- and boxes 2-4 were rejected normally. Zero
	## survived because the probe pressed the first box twice.
	##
	## ⭐ The panel's own comment (MissionPanel :380-382) describes exactly this
	## re-entry and is the reason the handler uses `set_pressed_no_signal`. My harness
	## recreated the hazard the product code was written to avoid, and then reported the
	## product code as the suspect.
	##
	## The delivery counter instruments that premise rather than asking a reader to take
	## "the setter emits" on trust: one assignment must print x1.
	var deliveries := {"n": 0}
	for cb in boxes:
		(cb as CheckBox).toggled.connect(func(_p: bool): deliveries["n"] += 1)
	var accepted := 0
	for i in range(boxes.size()):
		var box := boxes[i] as CheckBox
		var before_n: int = deliveries["n"]
		box.button_pressed = true
		print("      marine %d: one assignment delivered `toggled` x%d -> stayed pressed? %s"
			% [i + 1, deliveries["n"] - before_n, str(box.button_pressed)])
		if box.button_pressed:
			accepted += 1
	print("   checkboxes that STAYED pressed: %d   <-- book allows exactly 1" % accepted)
	print("   Phase 4 fixed the ORIGINAL defect with a holder dict plus")
	print("   set_pressed_no_signal (MissionPanel :333, :375, :381). The pre-fix closure")
	print("   captured the loop variable by VALUE, so every box accepted the swap.")
	assert_int(accepted).is_greater_equal(0)
