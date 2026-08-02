extends GdUnitTestSuite
## World Phase crew-task gating (Core Rules p.76, pp.128-130) and the p.59 ship wreck.
##
## THE GAPS THESE PIN
##
## 1. The upkeep lockout and the Character Event task blocks lived in
##    CrewTaskComponent._get_eligible_crew(), which had ZERO callers repo-wide.
##    The two LIVE paths — _populate_crew_list() and _on_assign_task_pressed() —
##    checked Sick Bay only. So p.76's "For each credit you are short, one crew
##    member will refuse to do any jobs for you this campaign turn" showed the
##    player a dialog naming the refusers and then let them be assigned anyway,
##    and a character who had DEPARTED the crew could still be sent to Trade.
##
## 2. p.59's "Once that amount of damage has been accumulated, the ship is a
##    wreck" never fired: apply_ship_damage() clamped the hull at 0 and stopped,
##    ShiplessSystem.apply_ship_destruction() had zero callers, and the free
##    1-HP-per-turn repair floated the hull again next turn. The crew could not
##    lose their ship, and the 1D6+5 scrap was never paid.
##
## The component is deliberately NOT added to the scene tree here: the gating
## helper is pure, and adding the component runs _ready() and builds the whole
## task UI (~95 orphan nodes per run).

const CrewTasks = preload("res://src/ui/screens/world/components/CrewTaskComponent.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _tasks() -> Object:
	return auto_free(CrewTasks.new())


func _gsm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")


var _previous = null
var _swapped := false


func after_test() -> void:
	if not _swapped:
		return
	var gs := _gs()
	if gs:
		gs.current_campaign = _previous
	_previous = null
	_swapped = false


func _install(campaign) -> void:
	var gs := _gs()
	if gs == null:
		return
	_previous = gs.current_campaign
	_swapped = true
	gs.current_campaign = campaign


# --- crew task gating ---------------------------------------------------------

func test_an_unblocked_crew_member_can_take_a_task() -> void:
	var comp: Object = _tasks()
	assert_str(comp._task_block_reason({"character_name": "Rin"})).is_empty()


## p.76 upkeep shortfall. This is the one that let the player ignore upkeep.
func test_upkeep_lockout_blocks_assignment() -> void:
	var comp: Object = _tasks()
	assert_str(comp._task_block_reason({
		"character_name": "Rin", "locked_out_this_turn": true,
	})).is_equal("REFUSING WORK")


func test_sick_bay_blocks_assignment() -> void:
	var comp: Object = _tasks()
	assert_str(comp._task_block_reason({
		"character_name": "Rin", "in_sick_bay": true,
	})).is_equal("SICK BAY")


## Time to Burn (p.130) explicitly grants an extra action, overriding Sick Bay.
func test_time_to_burn_overrides_sick_bay() -> void:
	var comp: Object = _tasks()
	assert_str(comp._task_block_reason({
		"character_name": "Rin",
		"in_sick_bay": true,
		"status_effects": [{"type": "extra_action"}],
	})).is_empty()


## pp.128-130 Character Events. A departed character must not be assignable.
func test_character_event_blocks_are_enforced() -> void:
	var comp: Object = _tasks()
	for pair: Array in [
		["skip_tasks", "UNAVAILABLE"],
		["unavailable", "UNAVAILABLE"],
		["departed", "DEPARTED"],
	]:
		assert_str(comp._task_block_reason({
			"character_name": "Rin",
			"status_effects": [{"type": pair[0]}],
		})).override_failure_message(
			"status effect '%s' did not block task assignment" % pair[0]
		).is_equal(pair[1])


## An unrelated status effect must not block anything.
func test_unrelated_status_effects_do_not_block() -> void:
	var comp: Object = _tasks()
	assert_str(comp._task_block_reason({
		"character_name": "Rin",
		"status_effects": [{"type": "no_xp"}],
	})).is_empty()


func test_eligible_crew_is_built_from_the_same_rule() -> void:
	var comp: Object = _tasks()
	comp.crew_data = [
		{"character_name": "Fit"},
		{"character_name": "Locked", "locked_out_this_turn": true},
		{"character_name": "Hurt", "in_sick_bay": true},
	]
	var eligible: Array = comp._get_eligible_crew()
	assert_int(eligible.size()).is_equal(1)
	assert_str(str(eligible[0].get("character_name", ""))).is_equal("Fit")


# --- p.59 ship wreck ----------------------------------------------------------

## "If this happens on the ground, you can reclaim 1D6+5 credits' worth of scrap
## parts." No credit loss and no item loss — that is the IN SPACE outcome.
func test_a_grounded_wreck_pays_scrap_and_costs_the_ship() -> void:
	var gsm := _gsm()
	if gsm == null:
		return
	var campaign = CampaignCore.new()
	campaign.initialize_ship({"name": "Void Runner", "hull_points": 3, "max_hull": 20})
	campaign.has_ship = true
	campaign.credits = 10
	_install(campaign)

	gsm.apply_ship_damage(5)   # in_space defaults false -> grounded

	assert_bool(bool(campaign.has_ship)).override_failure_message(
		"hull hit 0 and the ship was still usable — p.59 wreck never fired"
	).is_false()
	# 1D6+5 is 6..11 on top of the starting 10.
	assert_int(int(campaign.credits)).is_between(16, 21)


## "you lose all credits and can only retain 2 items per crew member"
func test_a_wreck_in_space_costs_every_credit() -> void:
	var gsm := _gsm()
	if gsm == null:
		return
	var campaign = CampaignCore.new()
	campaign.initialize_ship({"name": "Void Runner", "hull_points": 2, "max_hull": 20})
	campaign.has_ship = true
	campaign.credits = 40
	_install(campaign)

	gsm.apply_ship_damage(9, true)

	assert_bool(bool(campaign.has_ship)).is_false()
	assert_int(int(campaign.credits)).override_failure_message(
		"a ship lost in transit must cost all credits (p.59 'being without a ship')"
	).is_equal(0)


## The consequences must never be applied twice — further damage to an already
## wrecked ship would keep paying out scrap.
func test_wreck_consequences_apply_only_once() -> void:
	var gsm := _gsm()
	if gsm == null:
		return
	var campaign = CampaignCore.new()
	campaign.initialize_ship({"name": "Void Runner", "hull_points": 1, "max_hull": 20})
	campaign.has_ship = true
	campaign.credits = 0
	_install(campaign)

	gsm.apply_ship_damage(4)
	var after_first: int = int(campaign.credits)
	gsm.apply_ship_damage(4)

	assert_int(int(campaign.credits)).override_failure_message(
		"a second hit on a wrecked hull paid scrap again"
	).is_equal(after_first)


## A ship that survives the hit must not be wrecked.
func test_a_surviving_ship_is_not_wrecked() -> void:
	var gsm := _gsm()
	if gsm == null:
		return
	var campaign = CampaignCore.new()
	campaign.initialize_ship({"name": "Void Runner", "hull_points": 12, "max_hull": 20})
	campaign.has_ship = true
	campaign.credits = 5
	_install(campaign)

	gsm.apply_ship_damage(3)

	assert_bool(bool(campaign.has_ship)).is_true()
	assert_int(int(campaign.credits)).is_equal(5)
