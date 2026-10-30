extends GdUnitTestSuite
## Sprint 7b: Navigation trouble rolls the real Injury Table, and every die inside a
## travel event, on arrival and in the Sick Bay column can be forced.
##
## THE DEFECT THIS PINS. With the ship already damaged, Navigation trouble put a
## random crew member in Sick Bay for exactly one turn. Core Rules p.70 says that
## member "must roll on the Injury Table" (p.122), where 1-15 kills and most results
## last longer than a turn. The victim, the Asteroids, Distress call, Escape pod and
## Patrol ship dice, the p.72 arrival rolls and the p.122 recovery dice were raw
## randi() calls no tester could force.

const ResolverScript := preload("res://src/core/world/TravelEventResolver.gd")
const TableScript := preload("res://src/core/world/TravelEventTable.gd")
const ArrivalScript := preload("res://src/core/campaign/NewWorldArrival.gd")
const CampaignScript := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary
var _detailed_was_on: bool


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	DiceManager.clear_forced_results()
	# Compendium p.101 Detailed Injuries replaces the core table when it is on, so
	# the core-table cases below hold it off and put it back afterwards.
	_detailed_was_on = DLCManager.is_feature_enabled(DLCManager.ContentFlag.DETAILED_INJURIES)
	DLCManager.set_feature_enabled(DLCManager.ContentFlag.DETAILED_INJURIES, false)


func after_test() -> void:
	DiceManager.clear_forced_results()
	DLCManager.set_feature_enabled(DLCManager.ContentFlag.DETAILED_INJURIES, _detailed_was_on)
	SaveDirGuard.restore(_user_state)


func _campaign(hull: int, max_hull: int) -> Resource:
	var c: Resource = CampaignScript.new()
	var members: Array = []
	for i in 3:
		members.append({"character_id": "c%d" % i, "character_name": "Crew %d" % i,
			"origin": "HUMAN", "luck": 0, "savvy": 1, "toughness": 3,
			"status": "ACTIVE", "equipment": [], "status_effects": []})
	c.crew_data = {"members": members}
	c.ship_data = {"hull_points": hull, "max_hull": max_hull}
	return c


func _force(key: String, value: int) -> void:
	assert_bool(DiceManager.queue_forced_result(key, value)).override_failure_message(
		"premise: the seam accepts %s" % key).is_true()


func _queued(key: String) -> bool:
	return DiceManager.get_forced_results().has(key.to_lower())


func _event(title: String) -> Dictionary:
	for roll in range(1, 101):
		var e: Dictionary = TableScript.get_event(roll)
		if str(e.get("title", "")) == title:
			return e
	return {}


func test_navigation_trouble_rolls_the_injury_table() -> void:
	var c := _campaign(5, 10)
	_force("Travel Crew Pick", 2)
	_force("Post-Battle Injury", 1)
	var out: Dictionary = ResolverScript.apply(c, _event("Navigation Trouble"))
	var crew: Array = c.crew_data["members"]
	assert_str(str(crew[1].get("status", ""))).override_failure_message(
		"a forced 1 is Gruesome fate (p.122), and the pick lands on crew 1").is_equal("DEAD")
	assert_str(str(crew[0].get("status", ""))).is_equal("ACTIVE")
	assert_str(str(crew[2].get("status", ""))).is_equal("ACTIVE")
	assert_bool(_queued("Post-Battle Injury")).override_failure_message(
		"the roll was made").is_false()
	assert_bool(_queued("Travel Crew Pick")).override_failure_message(
		"the victim was picked through the seam").is_false()
	assert_bool(bool(out.get("reroll", false))).is_true()
	assert_str(" ".join(PackedStringArray(out["applied"]))).contains("Crew 1 was killed")


func test_a_survivable_result_keeps_its_own_recovery() -> void:
	var c := _campaign(5, 10)
	_force("Travel Crew Pick", 1)
	_force("Post-Battle Injury", 50)
	_force("Injury Recovery Time", 6)
	ResolverScript.apply(c, _event("Navigation Trouble"))
	var hurt: Dictionary = c.crew_data["members"][0]
	assert_int(int(hurt.get("recovery_turns", 0))).override_failure_message(
		"Serious injury is 1D3+1 (p.122): a forced 6 is 3, plus 1").is_equal(4)
	assert_bool(_queued("Injury Recovery Time")).is_false()


func test_an_undamaged_ship_rolls_no_injury() -> void:
	var c := _campaign(10, 10)
	_force("Post-Battle Injury", 1)
	var out: Dictionary = ResolverScript.apply(c, _event("Navigation Trouble"))
	assert_bool(out.has("injury")).is_false()
	assert_bool(_queued("Post-Battle Injury")).override_failure_message(
		"no Injury Table roll on an undamaged ship").is_true()
	for m: Dictionary in c.crew_data["members"]:
		assert_int(int(m.get("recovery_turns", 0))).is_equal(0)


func test_the_rolls_inside_a_travel_event_are_forceable() -> void:
	var c := _campaign(10, 10)
	_force("Travel Asteroids Avoid", 5)
	var out: Dictionary = ResolverScript.apply(c, _event("Asteroids"), {"Asteroids": "avoid"})
	assert_bool(bool(out.get("reroll", false))).override_failure_message(
		"p.70: 5+ charts a safe path").is_true()
	assert_bool(_queued("Travel Asteroids Avoid")).is_false()

	_force("Travel Distress Call", 1)
	_force("Travel Hull Damage", 6)
	out = ResolverScript.apply(c, _event("Distress Call"), {"Distress Call": "aid"})
	assert_int(int(out.get("hull_damage", 0))).override_failure_message(
		"p.71: the drive detonates for 1D6+1").is_equal(7)

	_force("Travel Escape Pod", 2)
	_force("Travel Pod Credits", 6)
	out = ResolverScript.apply(c, _event("Escape Pod"), {"Escape Pod": "rescue"})
	assert_str(" ".join(PackedStringArray(out["applied"]))).contains("Rescued for 3 credits")


func test_the_arrival_rolls_are_forceable() -> void:
	var c := _campaign(10, 10)
	c.rivals = [{"name": "Rival A"}]
	_force("New World Rival Follow", 4)
	ArrivalScript.apply(c)
	assert_int(c.rivals.size()).override_failure_message("p.72: a 4 stays behind").is_equal(0)
	assert_bool(_queued("New World Rival Follow")).is_false()

	c.rivals = [{"name": "Rival B"}]
	_force("New World Rival Follow", 5)
	ArrivalScript.apply(c)
	assert_int(c.rivals.size()).override_failure_message("p.72: a 5 follows").is_equal(1)

	_force("New World Licensing", 6)
	_force("New World Licence Fee", 3)
	var req: Dictionary = ArrivalScript.roll_licensing_requirement(c, "planet_x")
	assert_bool(bool(req.get("applies", false))).is_true()
	assert_int(int(req.get("fee", 0))).is_equal(3)
