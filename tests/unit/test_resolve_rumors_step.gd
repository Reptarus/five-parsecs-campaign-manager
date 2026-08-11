extends GdUnitTestSuite
## World Phase step 5 "Resolve any Rumors" (Core Rules p.85) — tablet QA, Aug 8 2026
##
## p.85 verbatim: "You may find Rumors as you play. If you are not currently on a Quest,
## roll a D6 at this stage. If the roll is equal or below the number of Rumors, remove all
## Rumors from your roster. You have now received a Quest which you may pursue immediately.
## Until the Quest is resolved, any time you would receive a Rumor, you receive a Quest
## Rumor instead."
##
## Three defects were found the first time a Quest was ever generated on real hardware.
## All three had been unreachable until the same session, because initialize_world_phase()
## was wiping the rumor list before this component ever saw it (test_world_phase_data_merge).
## Completing that dead gate is what exposed these.
##
##   1. SOFT-LOCK. "If you are NOT currently on a Quest" makes this step a no-op while a
##      Quest runs. is_rumors_resolved() returns rumors_resolved alone, and the
##      has_active_quest branch of _on_roll_pressed() returns without setting it, so a crew
##      on a Quest holding a Quest Rumor could neither roll nor advance.
##   2. STALE DEFERRED EMIT. The 0-rumor auto-complete queues _emit_auto_complete() via
##      call_deferred. The component is initialized twice in a real run (empty aggregate,
##      then real), so the empty pass queued a completion that fired a frame later against
##      a 5-rumor step, marking it done in the controller's checkpointed step_completed.
##   3. STALE LABEL. initialize_rumors_phase() reset every state var but not result_label,
##      so "No rumors to resolve" rendered beside a populated 5-rumor list.
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const RumorsScene := preload(
	"res://src/ui/screens/world/components/ResolveRumorsComponent.tscn")

const RUMORS_5 := [
	{"id": 0, "name": "Rumor 1"}, {"id": 1, "name": "Rumor 2"},
	{"id": 2, "name": "Rumor 3"}, {"id": 3, "name": "Rumor 4"},
	{"id": 4, "name": "Rumor 5"},
]
const QUEST := {"id": "quest_1", "name": "Mysterious Data", "stages_completed": 0}


func _make() -> Node:
	var c: Node = auto_free(RumorsScene.instantiate())
	add_child(c)
	return c


func test_active_quest_completes_the_step_instead_of_locking_it() -> void:
	## THE SOFT-LOCK. p.85 only rolls "if you are not currently on a Quest", so with a
	## Quest running the step has nothing to do. It must report itself DONE — the roll
	## button is already disabled (_update_ui_display), so if the step also refuses to
	## complete, Next Step is dead and the campaign turn cannot continue.
	var c := _make()
	await await_millis(120)

	# A Quest is active AND a Quest Rumor has since been gained — the exact state p.85's
	# last sentence creates, and the one that used to lock the screen.
	c.initialize_rumors_phase([{"id": 0, "name": "Quest Rumor 1"}], QUEST)
	await await_millis(60)

	assert_bool(c.is_rumors_resolved()) \
		.override_failure_message(
			"Step 5 refuses to complete while a Quest is active. p.85 only rolls when you "
			+ "are NOT on a Quest, and the roll button is disabled in this state, so the "
			+ "player can neither roll nor advance — a soft-lock mid-World-Phase.") \
		.is_true()
	assert_str(c.get_blocker_hint()) \
		.override_failure_message("a completed step must not report a blocker") \
		.is_equal("")


## Captured "resolve_rumors" PHASE_COMPLETED payloads, newest last.
var _completions: Array = []


func _on_any_phase_completed(data: Dictionary) -> void:
	if str(data.get("phase_name", "")) == "resolve_rumors":
		_completions.append(data)


func test_stale_auto_complete_cannot_fire_against_a_populated_step() -> void:
	## THE STALE DEFERRED EMIT. Initialize empty (queues the deferred completion), then
	## immediately re-initialize with 5 real rumors — the real two-pass sequence. The
	## queued callback fires during the await below and must NOT publish a completion.
	##
	## THIS MUST ASSERT ON THE EVENT BUS, NOT ON is_rumors_resolved(). The first version of
	## this test checked the component's own flag and passed with the guard fully removed —
	## _emit_auto_complete() publishes an event and never touches that flag, so the
	## assertion was structurally blind to the bug it was written for. The damage happens
	## one object away, in WorldPhaseController._on_phase_completed(), which turns this
	## event into step_completed[RESOLVE_RUMORS] = true — checkpointed to disk, and the
	## source of the green tick seen on step 5 before any D6 was rolled.
	var bus = get_node_or_null("/root/CampaignTurnEventBus")
	assert_object(bus) \
		.override_failure_message(
			"CampaignTurnEventBus autoload missing — without it this test cannot observe "
			+ "the completion at all and would pass vacuously.") \
		.is_not_null()

	_completions.clear()
	bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED,
		_on_any_phase_completed)

	var c := _make()
	await await_millis(120)
	_completions.clear()  # drop anything the component emitted while coming up

	c.initialize_rumors_phase([], {})        # pass 1: empty aggregate, queues auto-complete
	c.initialize_rumors_phase(RUMORS_5, {})  # pass 2: the real data, same frame
	await await_millis(150)                  # deferred callback fires in here

	var leaked: int = _completions.size()
	bus.unsubscribe_from_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED,
		_on_any_phase_completed)

	assert_int(leaked) \
		.override_failure_message(
			"A deferred auto-complete queued while the step was empty fired against a step "
			+ "holding 5 unresolved rumors (%d completion event(s) published). "
			% leaked
			+ "_on_phase_completed() writes that into step_completed[RESOLVE_RUMORS], which "
			+ "is checkpointed to disk and drives the step chips, so step 5 reports done "
			+ "before the D6 is rolled.") \
		.is_equal(0)
	assert_bool(c.is_rumors_resolved()).is_false()
	assert_int((c.rumors as Array).size()).is_equal(5)


func test_result_label_does_not_survive_reinitialization() -> void:
	## THE STALE LABEL. Same two-pass sequence; the sentence written by pass 1 described
	## state that pass 2 replaced, so it must not still be on screen.
	var c := _make()
	await await_millis(120)

	c.initialize_rumors_phase([], {})
	await await_millis(60)
	var empty_text: String = str(c.result_label.text) if c.result_label else ""
	assert_str(empty_text) \
		.override_failure_message("the genuinely-empty case should still explain itself") \
		.is_not_empty()

	c.initialize_rumors_phase(RUMORS_5, {})
	await await_millis(60)

	assert_str(str(c.result_label.text)) \
		.override_failure_message(
			"initialize_rumors_phase() left the previous pass's result text on screen. "
			+ "Observed on the tablet: \"No rumors to resolve\" rendered directly beside a "
			+ "populated 5-rumor list. It resets every state variable, so it must also "
			+ "reset the label that describes them.") \
		.is_equal("")


func test_roll_is_offered_when_rumors_exist_and_no_quest_runs() -> void:
	## The positive control: the ONLY state in which p.85 asks for a D6 must stay live,
	## or the two auto-complete branches above would be free to swallow the whole step.
	var c := _make()
	await await_millis(120)

	c.initialize_rumors_phase(RUMORS_5, {})
	await await_millis(60)

	assert_bool(c.is_rumors_resolved()) \
		.override_failure_message("5 rumors and no Quest is a step the player must ROLL") \
		.is_false()
	assert_bool(c.roll_button.disabled) \
		.override_failure_message("the roll button must be live in the one rollable state") \
		.is_false()
	assert_str(str(c.roll_button.text)).contains("D6")
