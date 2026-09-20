extends GdUnitTestSuite
## Compendium p.151 Civil War — the ENDING, which had no call site.
##
## THE DEFECT THIS PINS. A Civil War could start and could never end.
## `FringeWorldStrife` recorded it as a persistent effect on the campaign and
## `FactionSystem.process_strife_by_name("civil_war")` set `_factions_gone_to_ground`
## per p.114 ("Factions will go to ground until the war is over"). Nothing ever
## cleared it: `FactionSystem.end_civil_war()` had ZERO callers repo-wide, while
## its own docblock asserted "it is cleared by end_civil_war() rather than by a
## turn tick" — a comment naming a collaboration that never happened.
##
## Neither half was wrong, which is why no census could see it. p.151 settles the
## war with a die the app ALREADY rolls:
##
##   "During the Check for Galactic War Progress step, roll on the table normally
##    (core rules, p.126). A result of 'Unity Victorious' indicates your faction
##    has won the war. You receive 1D6 Credits in bonus pay (not to exceed the
##    number of missions you have done) and due to your war-hero status, you may
##    immediately remove 1 random Rival from your list.
##    A result of 'Lost to Unity' indicates your side lost. You must immediately
##    try to leave next campaign turn, similar to if the world had fallen to
##    invasion."
##
## `GalacticWarProcessor` computed exactly those two outcomes for INVADED planets
## and never told the faction layer — and worse, returned early when no planet was
## invaded, which is the commonest case for a civil war.
##
## gdUnit4 v6.0.3 compatible.

const Processor = preload("res://src/core/campaign/phases/post_battle/GalacticWarProcessor.gd")
const Context = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const Strife = preload("res://src/core/world/FringeWorldStrife.gd")

const PLANET := "civil_war_world"


## Feeds `PostBattleContext.roll_2d6()` / `.roll_d6()` a scripted sequence.
## The context calls `dice_manager.roll_d6()` twice for a 2D6, so a "roll of 10"
## is queued as [5, 5]. Falls back to 1 when the script runs out, which keeps an
## over-consuming test loud rather than random.
class StubDice extends RefCounted:
	var values: Array = []
	var consumed: int = 0

	func roll_d6(_context: String = "") -> int:
		if consumed < values.size():
			var v: int = int(values[consumed])
			consumed += 1
			return v
		return 1


## Records what the processor actually SPENT and REMOVED.
##
## ⚠ Asserting on the returned `civil_war_won` event is NOT enough: its `credits`
## field is computed from the die and the missions cap BEFORE anything is charged,
## so a version that pays nothing still reports the right number. The stub is what
## makes the payment observable — assert where the damage lands.
class StubGSM extends RefCounted:
	var credited: int = 0
	var rival_removed: bool = false
	var has_rivals: bool = true

	func add_credits(amount: int) -> void:
		credited += amount

	func remove_random_rival() -> bool:
		rival_removed = has_rivals
		return rival_removed


func _faction_system() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/FactionSystem")


func _planet_manager() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/PlanetDataManager")


var _saved_planet_id: String = ""


func before_test() -> void:
	# ⚠ PIN the ambient world. `_resolve_civil_war()` compares the war's planet to
	# PlanetDataManager.current_planet_id to honour p.151's "You may leave at any
	# time before the war is over", so a suite that left this to whatever the
	# previous batch saved would take the departure branch at random.
	var pdm := _planet_manager()
	if pdm and "current_planet_id" in pdm:
		_saved_planet_id = str(pdm.current_planet_id)
		pdm.current_planet_id = PLANET


func after_test() -> void:
	var pdm := _planet_manager()
	if pdm and "current_planet_id" in pdm:
		pdm.current_planet_id = _saved_planet_id
	var fs := _faction_system()
	if fs and fs.has_method("end_civil_war"):
		fs.end_civil_war()


## A campaign carrying an active Civil War on PLANET. The storage shape is the one
## PaymentProcessor._apply_strife_event() actually writes (add_active_effect with
## started_on_turn + instruction), not a hand-invented one.
func _campaign(missions_done: int = 5, rivals: int = 3) -> Dictionary:
	var rival_list: Array = []
	for i in range(rivals):
		rival_list.append({"id": "rival_%d" % i, "name": "Rival %d" % i})
	return {
		"progress_data": {
			"missions_completed": missions_done,
			"fringe_strife": {
				PLANET: {
					"planet_id": PLANET,
					"unstable": true,
					"tracking": false,
					"instability": 0,
					"active_effects": [
						{"id": "civil_war", "started_on_turn": 3, "instruction": "..."},
					],
				},
			},
		},
		"rivals": rival_list,
	}


var _gsm: StubGSM = null


func _ctx(campaign: Dictionary, dice: Array) -> Context:
	var ctx: Context = Context.new()
	ctx.campaign = campaign
	var stub := StubDice.new()
	stub.values = dice
	ctx.dice_manager = stub
	_gsm = StubGSM.new()
	ctx.game_state_manager = _gsm
	ctx.battle_result = {}
	return ctx


func _run(campaign: Dictionary, dice: Array) -> Dictionary:
	var proc: Processor = Processor.new()
	return proc.process_galactic_war(_ctx(campaign, dice))


func _civil_row(progress: Dictionary) -> Dictionary:
	for row: Variant in progress.get("planet_results", []):
		if row is Dictionary and bool((row as Dictionary).get("civil_war", false)):
			return row
	return {}


# ---------------------------------------------------------------- premise arms

func test_the_step_no_longer_returns_early_when_nothing_is_invaded() -> void:
	# The premise of every other case. With no invaded planets the processor used
	# to `return progress` before reaching any civil-war code, so if this ever goes
	# back to being an early return the rest of this suite passes vacuously.
	var campaign := _campaign()
	var progress := _run(campaign, [5, 5, 1])
	assert_array(progress.get("planet_results", [])) \
		.override_failure_message(
			"process_galactic_war returned with no civil-war row; the empty" +
			" invaded_planets early return is back.") \
		.is_not_empty()


func test_the_fixture_really_starts_with_the_war_active() -> void:
	var campaign := _campaign()
	assert_bool(Strife.has_active_effect(campaign, PLANET, "civil_war")) \
		.override_failure_message("fixture does not carry an active civil_war") \
		.is_true()


# ------------------------------------------------------------------- outcomes

func test_a_roll_of_ten_or_more_wins_the_war_and_ends_it() -> void:
	var campaign := _campaign()
	var progress := _run(campaign, [5, 5, 1])
	assert_str(str(_civil_row(progress).get("result", ""))).is_equal("victorious")
	assert_bool(Strife.has_active_effect(campaign, PLANET, "civil_war")).is_false()


func test_a_roll_of_four_or_less_loses_the_war_and_ends_it() -> void:
	var campaign := _campaign()
	var progress := _run(campaign, [2, 2])
	assert_str(str(_civil_row(progress).get("result", ""))).is_equal("lost_to_unity")
	assert_bool(Strife.has_active_effect(campaign, PLANET, "civil_war")).is_false()


func test_contested_does_not_end_the_war() -> void:
	var campaign := _campaign()
	var progress := _run(campaign, [3, 3])
	assert_str(str(_civil_row(progress).get("result", ""))).is_equal("contested")
	assert_bool(Strife.has_active_effect(campaign, PLANET, "civil_war")) \
		.override_failure_message("5-7 is not an ending; the war must continue") \
		.is_true()


func test_making_ground_banks_plus_one_for_the_next_roll() -> void:
	# p.126's own 8-9 row: "Making Ground (+1 to future rolls)". Banked on the
	# effect payload so it survives a reload like every other strife fact.
	var campaign := _campaign()
	var progress := _run(campaign, [4, 4])
	assert_str(str(_civil_row(progress).get("result", ""))).is_equal("making_ground")
	var banked: int = 0
	for entry: Variant in Strife.active_effects(campaign, PLANET):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == "civil_war":
			banked = int((entry as Dictionary).get("war_modifier", 0))
	assert_int(banked).is_equal(1)


func test_the_banked_modifier_is_applied_to_the_next_roll() -> void:
	var campaign := _campaign()
	_run(campaign, [4, 4])              # 8 -> making ground, banks +1
	var progress := _run(campaign, [4, 5, 1])  # 9 + 1 = 10 -> victorious
	var row := _civil_row(progress)
	assert_int(int(row.get("modifier", 0))).is_equal(1)
	assert_str(str(row.get("result", ""))).is_equal("victorious")


# --------------------------------------------------------------- consequences

func test_the_p114_faction_suppression_is_lifted_when_the_war_ends() -> void:
	var fs := _faction_system()
	if fs == null:
		return
	fs.process_strife_by_name("civil_war")
	assert_bool(fs._factions_gone_to_ground) \
		.override_failure_message("premise: the strife row should suppress factions") \
		.is_true()
	_run(_campaign(), [5, 5, 1])
	assert_bool(fs._factions_gone_to_ground) \
		.override_failure_message(
			"p.114: factions go to ground 'until the war is over' — the war ended" +
			" and end_civil_war() was never called.") \
		.is_false()


func test_winning_pays_the_bonus_die_capped_at_missions_completed() -> void:
	# "1D6 Credits in bonus pay (not to exceed the number of missions you have
	# done)". Two missions done, a 6 on the die -> 2 credits, not 6.
	var campaign := _campaign(2)
	_run(campaign, [5, 5, 6])
	assert_int(_gsm.credited) \
		.override_failure_message(
			"the missions cap was not applied to the bonus die, or the credits" +
			" were never actually charged through GameStateManager.") \
		.is_equal(2)


func test_an_uncapped_die_pays_the_whole_roll() -> void:
	# The cap must not fire when the crew has done plenty of missions, or the
	# case above would pass against a version that always paid `missions`.
	var campaign := _campaign(20)
	_run(campaign, [5, 5, 4])
	assert_int(_gsm.credited).is_equal(4)


func test_a_crew_with_no_missions_is_paid_nothing() -> void:
	var campaign := _campaign(0)
	_run(campaign, [5, 5, 6])
	assert_int(_gsm.credited).is_equal(0)


func test_winning_removes_one_random_rival() -> void:
	var campaign := _campaign(5, 3)
	_run(campaign, [5, 5, 1])
	assert_bool(_gsm.rival_removed) \
		.override_failure_message("p.151 war-hero status removes 1 random Rival") \
		.is_true()


func test_losing_pays_nothing_and_removes_no_rival() -> void:
	var campaign := _campaign(5, 3)
	_run(campaign, [2, 2])
	assert_int(_gsm.credited).is_equal(0)
	assert_bool(_gsm.rival_removed).is_false()


func test_losing_forces_the_flight_the_upkeep_step_already_enforces() -> void:
	# "You must immediately try to leave next campaign turn, similar to if the
	# world had fallen to invasion." `invasion_flight_pending` is the flag
	# UpkeepPhaseComponent:1133 already reads to force that flight.
	var campaign := _campaign()
	_run(campaign, [2, 2])
	assert_bool(bool(campaign["progress_data"].get("invasion_flight_pending", false))) \
		.override_failure_message(
			"a lost civil war must force the p.69 flight; nothing set" +
			" invasion_flight_pending.") \
		.is_true()


func test_winning_does_not_force_the_flight() -> void:
	var campaign := _campaign()
	_run(campaign, [5, 5, 1])
	assert_bool(bool(campaign["progress_data"].get("invasion_flight_pending", false))).is_false()


# ------------------------------------------------------- p.151 leaving clause

func test_leaving_the_world_releases_the_crew_without_paying_out() -> void:
	# p.151: "You may leave at any time before the war is over (i.e. you are not
	# conscripted into service)." Departure is not an ending — no bonus pay, no
	# Rival removal, no forced flight — but the suppression must still lift, or
	# the factions stay to ground for a world the crew will never see again.
	var pdm := _planet_manager()
	if pdm == null or not ("current_planet_id" in pdm):
		return
	pdm.current_planet_id = "somewhere_else"
	var fs := _faction_system()
	if fs:
		fs.process_strife_by_name("civil_war")
	var campaign := _campaign()
	var progress := _run(campaign, [5, 5, 6])

	assert_bool(Strife.has_active_effect(campaign, PLANET, "civil_war")).is_false()
	if fs:
		assert_bool(fs._factions_gone_to_ground).is_false()
	assert_bool(bool(campaign["progress_data"].get("invasion_flight_pending", false))) \
		.override_failure_message("leaving is not losing; it must not force the flight") \
		.is_false()
	assert_int(_gsm.credited) \
		.override_failure_message("leaving must not pay the war-hero bonus") \
		.is_equal(0)
	assert_bool(_gsm.rival_removed).is_false()
	var left: bool = false
	for ev: Variant in progress.get("major_events", []):
		if ev is Dictionary and str((ev as Dictionary).get("type", "")) == "civil_war_left":
			left = true
	assert_bool(left).is_true()


func test_no_civil_war_means_no_civil_war_row() -> void:
	var campaign: Dictionary = {"progress_data": {}, "rivals": []}
	var progress := _run(campaign, [5, 5])
	assert_bool(_civil_row(progress).is_empty()).is_true()
