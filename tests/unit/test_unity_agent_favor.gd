extends GdUnitTestSuite

## Unity Agent "Call in a Favor" backend (Core Rules p.20): the three favor outcomes
## (remove a Rival / gain a Quest Rumor / gain a Patron) and the CampaignPhaseManager
## resolver dispatch. Verifies the previously-missing GameStateManager methods that the
## resolver has always dispatched to.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _gs
var _saved

func before_test() -> void:
	_gs = get_node_or_null("/root/GameState")
	_saved = _gs.current_campaign if _gs and "current_campaign" in _gs else null
	if _gs:
		_gs.current_campaign = CampaignCore.new()

func after_test() -> void:
	if _gs:
		_gs.current_campaign = _saved

func _campaign():
	return _gs.get_current_campaign()

func test_add_quest_rumor_increments() -> void:
	var before: int = int(_campaign().quest_rumors)
	GameStateManager.add_quest_rumor()
	assert_int(int(_campaign().quest_rumors)).is_equal(before + 1)

func test_remove_random_rival_removes_one() -> void:
	GameStateManager.set_rivals([{"name": "R1"}, {"name": "R2"}])
	assert_bool(GameStateManager.remove_random_rival()).is_true()
	assert_int(GameStateManager.get_rivals().size()).is_equal(1)

func test_remove_random_rival_empty_returns_false() -> void:
	GameStateManager.set_rivals([])
	assert_bool(GameStateManager.remove_random_rival()).is_false()

func test_add_patron_is_display_safe_and_added() -> void:
	GameStateManager.set_patrons([])
	var p: Dictionary = GameStateManager.add_patron()
	# Every field PatronRivalManager reads via `.` access must be present.
	for key in ["id", "name", "type", "status", "relationship", "jobs_offered"]:
		assert_bool(p.has(key)).override_failure_message("missing key: " + key).is_true()
	assert_int(GameStateManager.get_patrons().size()).is_equal(1)

func test_resolver_dispatch_gain_quest_rumor() -> void:
	# CampaignPhaseManager.resolve_unity_agent_favor dispatches to the GSM methods.
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	assert_object(cpm).is_not_null()
	var before: int = int(_campaign().quest_rumors)
	cpm.resolve_unity_agent_favor("gain_quest_rumor")
	assert_int(int(_campaign().quest_rumors)).is_equal(before + 1)

func test_resolver_dispatch_gain_patron() -> void:
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	GameStateManager.set_patrons([])
	cpm.resolve_unity_agent_favor("gain_patron")
	assert_int(GameStateManager.get_patrons().size()).is_equal(1)
