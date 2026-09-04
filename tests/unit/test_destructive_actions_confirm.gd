extends GdUnitTestSuite
## Destructive World Phase actions must ASK before they destroy (tablet QA, Aug 8 2026)
##
## Two findings from the device run turned out to be the same defect class: a single
## tap irreversibly throwing away a turn's work, with no confirm, no indication that
## anything was lost, and no undo.
##
##   W2-04 — "Resolve All Tasks" with three of six crew still unassigned. The step
##           locked to "All Tasks Resolved" and Assign Task went disabled, so Mars
##           Stark, Finn Mendez and Nyx Ward each permanently lost a turn action
##           (Core Rules pp.77-78: one task per crew member per turn).
##
##   W2-02 — Back on World Phase step 1 calls rollback_to_phase(TRAVEL), which is
##           NOT navigation: it runs campaign.from_dictionary() over the whole
##           campaign from the snapshot taken when TRAVEL was entered. That is the
##           mechanism behind the vanished Turn 1 Quest — a snapshot predating step
##           5 explains BOTH the entirely-absent `active_quest` key AND quest_rumors
##           being back at 5(+1) rather than 0.
##
## What is pinned here is the ASKING, not the dialog's appearance. The failure mode
## being guarded is "the destructive path runs synchronously with no gate", which is
## observable: after the call, nothing has been destroyed yet.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const CrewTaskScene = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.tscn")
const WorldPhaseScene = preload("res://src/ui/screens/world/WorldPhaseController.tscn")
const PhaseManagerClass = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const CampaignCoreClass = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _crew(id: String, cname: String) -> Dictionary:
	# Both key spellings — Character.to_dictionary() emits the aliases and consumers
	# read either, so a fixture with only one is not representative.
	return {
		"id": id, "character_id": id,
		"name": cname, "character_name": cname,
		"in_sick_bay": false, "recovery_turns": 0,
		"status_effects": [],
	}


## An assignment as _on_assign_task_pressed() actually builds one. The thin
## {"task_id", "resolved"} fixture I first used is NOT representative:
## _resolve_single_task() reads task_data.crew_member and task_data.task with dot
## access, so a missing key aborts the whole resolution — a harness fault that
## reads exactly like the product bug under test.
func _assignment(id: String, cname: String) -> Dictionary:
	return {
		"crew_member": _crew(id, cname),
		"task": {"id": "trade", "name": "Trade", "dice_target": 4},
		"task_id": "trade",
		"assigned_time": 0.0,
		"resolved": false,
	}


func _task_component() -> Node:
	var c: Node = auto_free(CrewTaskScene.instantiate())
	add_child(c)
	c.crew_data = [
		_crew("c1", "Mars Stark"),
		_crew("c2", "Finn Mendez"),
		_crew("c3", "Nyx Ward"),
	]
	return c


# ------------------------------------------------------------------- W2-04

func test_crew_with_no_task_are_identified_as_about_to_lose_their_turn() -> void:
	var c := _task_component()
	c.assigned_tasks = {"c1": _assignment("c1", "Mars Stark")}

	var stranded: Array[String] = c._unassigned_eligible_crew()

	assert_int(stranded.size()).is_equal(2)
	assert_array(stranded).contains(["Finn Mendez", "Nyx Ward"])
	assert_array(stranded).not_contains(["Mars Stark"])


func test_resolving_with_everyone_assigned_needs_no_confirmation() -> void:
	# The confirm must not become a speed bump on the normal path.
	var c := _task_component()
	c.crew_data = [_crew("c1", "Mars Stark")]
	c.assigned_tasks = {"c1": _assignment("c1", "Mars Stark")}

	assert_array(c._unassigned_eligible_crew()).is_empty()


## Whether a modal is currently gating the action. Asserting on the DIALOG rather
## than on resolution side effects keeps these tests independent of everything
## _resolve_single_task() touches (credits, event queues, the journal) — the
## contract under test is only "does it ask first".
func _pending_confirm(c: Node) -> ConfirmationDialog:
	for child in c.get_children():
		if child is ConfirmationDialog:
			return child
	return null


func test_resolve_all_does_not_burn_unassigned_crew_before_asking() -> void:
	# DETECTION-CRITICAL. Drop the gate and this resolves synchronously — which is
	# exactly what cost three crew their actions on the tablet.
	var c := _task_component()
	c.assigned_tasks = {"c1": _assignment("c1", "Mars Stark")}

	c._on_resolve_all_pressed()

	var dialog := _pending_confirm(c)
	assert_that(dialog).is_not_null()
	assert_bool(c.all_tasks_resolved).is_false()
	assert_bool(bool(c.assigned_tasks["c1"]["resolved"])).is_false()
	if dialog:
		dialog.free()


func test_the_confirmation_names_the_crew_who_would_lose_their_turn() -> void:
	# A confirm that says only "are you sure?" trains people to tap through it. The
	# two crew about to be burned must appear by name.
	var c := _task_component()
	c.assigned_tasks = {"c1": _assignment("c1", "Mars Stark")}

	c._on_resolve_all_pressed()

	var dialog := _pending_confirm(c)
	assert_that(dialog).is_not_null()
	# Searched RECURSIVELY, not over direct children. T9-39 wrapped this Label in
	# a ScrollContainer so a long crew list overflows instead of growing the
	# dialog past the screen edge (which put both buttons off the bottom on the
	# tablet). The Label is now a grandchild, and a direct-child walk found
	# nothing and asserted against "" — a test failing on the dialog's SHAPE
	# while the thing it exists to check, the names, was still correct.
	var text := _all_label_text(dialog)
	assert_str(text).override_failure_message(
		"the confirmation must name the crew about to lose their turn; found: %s"
		% text).contains("Finn Mendez")
	assert_str(text).contains("Nyx Ward")
	dialog.free()


## Everything the dialog SAYS, wherever it lives: AcceptDialog.dialog_text plus
## any Label anywhere beneath it. Structure-agnostic on purpose — this suite
## cares what the dialog says, not how it is nested.
##
## Widened twice now, both times because the SHAPE changed while the names it
## checks stayed correct:
##   T9-39  wrapped the text in a ScrollContainer, making the Label a grandchild,
##          so a direct-child walk found nothing and asserted against "".
##   T10-01 deleted that wrapper and moved the text to `dialog_text`. A Control
##          add_child()'d into a Window gets no layout pass while
##          Window.wrap_controls is false (the default) — measured on the tablet,
##          the dialog rendered completely EMPTY. dialog_text uses AcceptDialog's
##          BUILT-IN label, which is an *internal* child and therefore invisible
##          to get_children().
##
## The lesson both times: widen the observation, never relax the assertion it
## feeds. The crew names must still appear.
func _all_label_text(node: Node) -> String:
	var out: String = ""
	if node is AcceptDialog:
		out += (node as AcceptDialog).dialog_text + "\n"
	for child in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		out += _all_label_text(child)
	return out


func test_an_automated_resolve_is_never_gated_by_a_modal() -> void:
	# Asserted on the decision seam, not by driving the handler: in auto mode the
	# handler correctly proceeds to the real resolution, and standing that pipeline
	# up in a fixture would test everything EXCEPT the gate.
	#
	# Both automated callers set _auto_resolve_mode, call the handler, and clear it
	# on the NEXT line. A dialog there would return immediately, the flag would be
	# false again by the time anyone answered, and the eventual resolution would run
	# in interactive mode picking different outcomes.
	var CrewTask: GDScript = load(
		"res://src/ui/screens/world/components/CrewTaskComponent.gd")

	assert_bool(CrewTask.should_confirm_resolve_all(true, 3)).is_false()
	assert_bool(CrewTask.should_confirm_resolve_all(true, 0)).is_false()


func test_an_interactive_resolve_with_stranded_crew_is_gated() -> void:
	var CrewTask: GDScript = load(
		"res://src/ui/screens/world/components/CrewTaskComponent.gd")

	assert_bool(CrewTask.should_confirm_resolve_all(false, 3)).is_true()
	# ...and not otherwise, so the confirm never becomes a speed bump.
	assert_bool(CrewTask.should_confirm_resolve_all(false, 0)).is_false()


# ------------------------------------------------------------------- W2-02

func test_the_phase_manager_can_be_asked_whether_a_rollback_would_destroy_state() -> void:
	# A caller cannot distinguish harmless navigation from a full-campaign restore
	# without this, and rollback_to_phase() gives no way to find out afterwards.
	var pm: Node = auto_free(PhaseManagerClass.new())
	add_child(pm)

	assert_bool(pm.has_method("has_phase_checkpoint")).is_true()
	assert_bool(pm.has_phase_checkpoint(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)).is_false()


func test_a_stored_checkpoint_is_reported_as_destructive() -> void:
	var pm: Node = auto_free(PhaseManagerClass.new())
	add_child(pm)
	var travel: int = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL

	pm._phase_checkpoints[travel] = {"progress": {}}

	assert_bool(pm.has_phase_checkpoint(travel)).is_true()


func test_rollback_restores_the_whole_campaign_which_is_why_it_must_ask() -> void:
	# Documents the blast radius the confirm exists for, so nobody later decides the
	# dialog is noise. A Quest generated at step 5 is simply not in a snapshot taken
	# at TRAVEL entry — and it comes back ABSENT, not empty, which is precisely how
	# the device save was told apart from a p.120 clear_active_quest().
	var pm: Node = auto_free(PhaseManagerClass.new())
	add_child(pm)
	var prior = GameState.current_campaign
	GameState.current_campaign = CampaignCoreClass.new()
	GameState.current_campaign.quest_rumors = 5
	pm.game_state = GameState
	var travel: int = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL

	pm._store_phase_checkpoint(travel)          # snapshot BEFORE the world phase
	GameState.set_active_quest({"id": "q1", "name": "Mysterious Data"})
	GameState.current_campaign.quest_rumors = 0  # p.85 spends the rumors
	assert_bool(GameState.has_active_quest()).is_true()

	pm.current_phase = GlobalEnums.FiveParsecsCampaignPhase.UPKEEP
	pm.rollback_to_phase(travel)

	assert_bool(GameState.current_campaign.progress_data.has("active_quest")).is_false()
	assert_int(int(GameState.current_campaign.quest_rumors)).is_equal(5)

	GameState.current_campaign = prior


func test_back_on_step_one_does_not_roll_back_before_asking() -> void:
	# DETECTION-CRITICAL. The pre-fix code called rollback_to_phase() inline from the
	# button handler.
	var wp := auto_free(WorldPhaseScene.instantiate())
	add_child(wp)
	var pm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if pm == null or not pm.has_method("has_phase_checkpoint"):
		return
	var travel: int = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	var prior = GameState.current_campaign
	GameState.current_campaign = CampaignCoreClass.new()
	GameState.current_campaign.quest_rumors = 7
	pm._phase_checkpoints[travel] = GameState.current_campaign.to_dictionary()
	GameState.current_campaign.quest_rumors = 0

	wp.current_step = 0  # UPKEEP
	wp._on_back_button_pressed()

	# Still 0: the confirm is up, nothing has been restored yet.
	assert_int(int(GameState.current_campaign.quest_rumors)).is_equal(0)

	pm._phase_checkpoints.erase(travel)
	GameState.current_campaign = prior
