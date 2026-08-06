extends GdUnitTestSuite
## Starship Travel Events Table effects (Core Rules pp.70-72).
##
## THE GAP THESE PIN. TravelEventTable.gd says at line 10 that its "effects" are
## "hint tags for the resolving UI (not mechanically applied here)", and no
## resolving UI ever existed — the only consumer built two Labels and stopped.
## A repo-wide grep for the effect tags found no consumer in any live file, so
## travel carried neither risk nor reward for an entire campaign: Navigation
## Trouble never cost a story point, Down-time never granted XP or the free
## repair, Cosmic Phenomenon never granted its once-per-campaign +1 Luck, and
## Accident never injured anyone.

const Resolver = preload("res://src/core/world/TravelEventResolver.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _campaign(members: Array, story_points: int = 3) -> Resource:
	var c = CampaignCore.new()
	c.crew_data = {"members": members}
	c.story_points = story_points
	return c


func _member(name: String, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {"character_name": name, "experience": 0, "luck": 0}
	m.merge(extra, true)
	return m


func _event(title: String) -> Dictionary:
	return {"title": title}


# --- deterministic effects ----------------------------------------------------

## p.72: "Add +1 story point."
func test_time_to_reflect_grants_a_story_point() -> void:
	var c: Resource = _campaign([_member("Rin")], 2)
	Resolver.apply(c, _event("Time to Reflect"))
	assert_int(int(c.story_points)).is_equal(3)


## p.70: "Lose 1 story point ... then roll again on this table."
func test_navigation_trouble_costs_a_story_point_and_rerolls() -> void:
	var c: Resource = _campaign([_member("Rin")], 2)
	var report: Dictionary = Resolver.apply(c, _event("Navigation Trouble"))
	assert_int(int(c.story_points)).is_equal(1)
	assert_bool(bool(report.get("reroll", false))).override_failure_message(
		"the book's 'then roll again on this table' was dropped"
	).is_true()


## Story points must never go negative.
func test_story_points_floor_at_zero() -> void:
	var c: Resource = _campaign([_member("Rin")], 0)
	Resolver.apply(c, _event("Navigation Trouble"))
	assert_int(int(c.story_points)).is_equal(0)


## p.70: with the hull already damaged, "a random crew member must roll on the
## Injury Table, as system failures cause life support malfunctions".
func test_navigation_trouble_injures_when_the_hull_is_damaged() -> void:
	var c: Resource = _campaign([_member("Rin")], 2)
	c.ship_data = {"hull_points": 4, "max_hull": 10}
	Resolver.apply(c, _event("Navigation Trouble"))
	assert_int(int(c.crew_data["members"][0].get("recovery_turns", 0))
		).override_failure_message(
			"a damaged hull must injure a crew member on Navigation Trouble"
		).is_equal(1)


func test_navigation_trouble_spares_the_crew_on_an_intact_hull() -> void:
	var c: Resource = _campaign([_member("Rin")], 2)
	c.ship_data = {"hull_points": 10, "max_hull": 10}
	Resolver.apply(c, _event("Navigation Trouble"))
	assert_int(int(c.crew_data["members"][0].get("recovery_turns", 0))).is_equal(0)


## p.71: "Select a crew member of choice and add +1 XP."
func test_down_time_grants_xp() -> void:
	var c: Resource = _campaign([_member("Rin")])
	Resolver.apply(c, _event("Down-time"))
	assert_int(int(c.crew_data["members"][0]["experience"])).is_equal(1)


## p.71: "+1 Luck (if they are able). This event can only ever happen once in a
## campaign. Treat as nothing happening, if it happens again."
func test_cosmic_phenomenon_grants_luck_exactly_once() -> void:
	var c: Resource = _campaign([_member("Rin")])
	Resolver.apply(c, _event("Cosmic Phenomenon"))
	assert_int(int(c.crew_data["members"][0]["luck"])).is_equal(1)

	Resolver.apply(c, _event("Cosmic Phenomenon"))
	assert_int(int(c.crew_data["members"][0]["luck"])).override_failure_message(
		"the once-per-campaign guard did not hold"
	).is_equal(1)


## p.71: "If you have a Precursor in the crew, they predict it's a good omen.
## Add +1 story point as well."
func test_a_precursor_adds_a_story_point_to_the_phenomenon() -> void:
	var c: Resource = _campaign([
		_member("Rin"), _member("Eshe", {"species_id": "precursor"}),
	], 1)
	Resolver.apply(c, _event("Cosmic Phenomenon"))
	assert_int(int(c.story_points)).is_equal(2)


func test_no_precursor_means_no_extra_story_point() -> void:
	var c: Resource = _campaign([_member("Rin")], 1)
	Resolver.apply(c, _event("Cosmic Phenomenon"))
	assert_int(int(c.story_points)).is_equal(1)


## p.71: "A crew member gets Injured ... rest up for one campaign turn ... and
## one item they carry is damaged." The damage marker must match the shape that
## Repair Your Kit (p.78) looks for.
func test_accident_injures_and_damages_an_item() -> void:
	var c: Resource = _campaign([_member("Rin", {"equipment": ["Auto Rifle"]})])
	Resolver.apply(c, _event("Accident"))
	var m: Dictionary = c.crew_data["members"][0]
	assert_int(int(m.get("recovery_turns", 0))).is_equal(1)
	var marked: bool = false
	for eff in m.get("status_effects", []):
		if str(eff.get("type", "")) == "item_damaged" \
				and str(eff.get("damaged_item", "")) == "Auto Rifle":
			marked = true
	assert_bool(marked).override_failure_message(
		"the damaged item was not recorded where Repair Your Kit can find it"
	).is_true()


## p.72: "Any Injured crew may rest for one campaign turn."
func test_travel_time_reduces_recovery() -> void:
	var c: Resource = _campaign([
		_member("Rin", {"recovery_turns": 2}), _member("Kal"),
	])
	Resolver.apply(c, _event("Travel-time"))
	assert_int(int(c.crew_data["members"][0]["recovery_turns"])).is_equal(1)
	assert_int(int(c.crew_data["members"][1].get("recovery_turns", 0))).is_equal(0)


## p.72: "You can Repair one damaged item." Exactly one, not all of them.
func test_uneventful_trip_repairs_a_single_item() -> void:
	var c: Resource = _campaign([_member("Rin", {"status_effects": [
		{"type": "item_damaged", "damaged_item": "Auto Rifle"},
		{"type": "item_damaged", "damaged_item": "Blade"},
	]})])
	Resolver.apply(c, _event("Uneventful Trip"))
	var left: int = 0
	for eff in c.crew_data["members"][0]["status_effects"]:
		if str(eff.get("type", "")) == "item_damaged":
			left += 1
	assert_int(left).override_failure_message(
		"Uneventful Trip repaired more than the one item the book allows"
	).is_equal(1)


## p.72: 1-2 -> +3 XP to one; 3-4 -> +2 and +1; 5-6 -> +1 to three. Whichever
## branch fires, exactly 3 XP is distributed.
func test_time_to_read_a_book_always_distributes_three_xp() -> void:
	for _i: int in range(25):
		var c: Resource = _campaign([
			_member("A"), _member("B"), _member("C"), _member("D"),
		])
		Resolver.apply(c, _event("Time to Read a Book"))
		var total: int = 0
		for m in c.crew_data["members"]:
			total += int(m["experience"])
		assert_int(total).override_failure_message(
			"every branch of the p.72 table distributes 3 XP in total"
		).is_equal(3)


# --- the interactive events ---------------------------------------------------

## Events that ask the player something must return a pending_choice and change
## NOTHING until it is answered.
func test_choice_events_ask_before_they_act() -> void:
	for title: String in [
		"Asteroids", "Distress Call", "Escape Pod", "Locked in the Library Data",
	]:
		var c: Resource = _campaign([_member("Rin")], 3)
		var report: Dictionary = Resolver.apply(c, _event(title))
		var choice: Dictionary = report.get("pending_choice", {})
		assert_bool(choice.is_empty()).override_failure_message(
			"%s did not ask the player anything" % title).is_false()
		assert_int((choice.get("options", []) as Array).size()
			).override_failure_message("%s offered no options" % title).is_greater(1)
		assert_int(int(c.story_points)).is_equal(3)


## p.70 Asteroids: "roll 1D6, requiring a 5+ to chart a safe path. If successful,
## roll again on this table." A safe path must never damage the hull.
func test_asteroids_avoid_either_rerolls_or_costs_hull() -> void:
	var saw_reroll: bool = false
	var saw_damage: bool = false
	for _i: int in range(40):
		var c: Resource = _campaign([_member("Rin", {"savvy": 1})])
		var r: Dictionary = Resolver.apply(c, _event("Asteroids"), {"Asteroids": "avoid"})
		if bool(r.get("reroll", false)):
			saw_reroll = true
			assert_int(int(r.get("hull_damage", 0))).override_failure_message(
				"a successfully charted path must not damage the hull"
			).is_equal(0)
		elif int(r.get("hull_damage", 0)) > 0:
			saw_damage = true
	assert_bool(saw_reroll).is_true()
	assert_bool(saw_damage).is_true()


## "roll 1D6+Savvy three times, requiring a 4+ ... Each failed roll inflicts 1D6
## Hull Point damage" — so at most three failures, i.e. 3..18, and a very high
## Savvy can never fail.
func test_asteroids_through_damage_stays_within_three_failures() -> void:
	for _i: int in range(40):
		var c: Resource = _campaign([_member("Rin", {"savvy": 0})])
		var r: Dictionary = Resolver.apply(c, _event("Asteroids"), {"Asteroids": "through"})
		assert_int(int(r.get("hull_damage", 0))).is_between(0, 18)

	var safe: Resource = _campaign([_member("Ace", {"savvy": 9})])
	var sr: Dictionary = Resolver.apply(safe, _event("Asteroids"), {"Asteroids": "through"})
	assert_int(int(sr.get("hull_damage", 0))).override_failure_message(
		"1D6+9 can never miss a 4+, so the hull must be untouched"
	).is_equal(0)


## p.70 Raided: a 6+ on 1D6+Savvy avoids the fight entirely.
func test_raided_intimidation_can_avoid_the_battle() -> void:
	var c: Resource = _campaign([_member("Silver", {"savvy": 9})])
	var r: Dictionary = Resolver.apply(c, _event("Raided"))
	assert_bool((r.get("forced_battle", {}) as Dictionary).is_empty()
		).override_failure_message(
			"1D6+9 always beats 6+, so there must be no battle"
		).is_true()


## Failing intimidation sets up the out-of-sequence Criminal Elements fight.
func test_raided_failure_sets_up_an_out_of_sequence_battle() -> void:
	var c: Resource = _campaign([_member("Mute", {"savvy": -9})])
	var r: Dictionary = Resolver.apply(c, _event("Raided"))
	var battle: Dictionary = r.get("forced_battle", {})
	assert_bool(battle.is_empty()).is_false()
	assert_str(str(battle.get("enemy_category", ""))).is_equal("criminal_elements")
	assert_bool(bool(battle.get("out_of_sequence", false))).override_failure_message(
		"p.70: the raid 'does not count as the main Battle stage'"
	).is_true()
	# 3D6 pick highest, +1 extra figure -> 2..7 at crew size 6.
	assert_int(int(battle.get("base_enemy_count", 0))).is_between(2, 7)


## p.70 Drive Trouble: three 1D6+Savvy tests at 6+; each failure grounds you for
## one campaign turn on arrival.
func test_drive_trouble_grounds_you_for_each_failure() -> void:
	var sure: Resource = _campaign([
		_member("A", {"savvy": 9}), _member("B", {"savvy": 9}), _member("C", {"savvy": 9}),
	])
	assert_int(int(Resolver.apply(sure, _event("Drive Trouble")).get("grounded_turns", -1))
		).is_equal(0)

	var doomed: Resource = _campaign([
		_member("A", {"savvy": -9}), _member("B", {"savvy": -9}), _member("C", {"savvy": -9}),
	])
	var r: Dictionary = Resolver.apply(doomed, _event("Drive Trouble"))
	assert_int(int(r.get("grounded_turns", 0))).is_equal(3)
	assert_int(int(doomed.progress_data.get("drive_grounded_turns", 0))).is_equal(3)


## p.71 Patrol Ship: "Roll 1D6-3 twice ... Due to the military presence, the next
## world you visit cannot be Invaded." The flag applies however the dice fall.
func test_patrol_ship_always_blocks_the_next_invasion() -> void:
	var c: Resource = _campaign([_member("Rin")])
	c.equipment_data = {"equipment": ["Blade", "Rifle", "Scanner"]}
	Resolver.apply(c, _event("Patrol Ship"))
	assert_bool(bool(c.progress_data.get("next_world_cannot_be_invaded", false))
		).is_true()


## Confiscation is 1D6-3 twice, so it can never exceed 6 items.
func test_patrol_ship_confiscates_within_the_dice_range() -> void:
	for _i: int in range(30):
		var c: Resource = _campaign([_member("Rin")])
		c.equipment_data = {"equipment": ["a", "b", "c", "d", "e", "f", "g", "h"]}
		Resolver.apply(c, _event("Patrol Ship"))
		var left: int = (c.equipment_data["equipment"] as Array).size()
		assert_int(left).is_between(2, 8)


## Declining a rescue must cost and grant nothing.
func test_declining_the_escape_pod_changes_nothing() -> void:
	var c: Resource = _campaign([_member("Rin")], 2)
	c.credits = 5
	Resolver.apply(c, _event("Escape Pod"), {"Escape Pod": "ignore"})
	assert_int(int(c.story_points)).is_equal(2)
	assert_int(int(c.credits)).is_equal(5)


## Every branch of the p.71 escape-pod subtable must report something and must
## never reduce the crew's credits.
func test_rescuing_the_escape_pod_never_costs_credits() -> void:
	for _i: int in range(30):
		var c: Resource = _campaign([_member("Rin")], 1)
		c.credits = 4
		var r: Dictionary = Resolver.apply(c, _event("Escape Pod"), {"Escape Pod": "rescue"})
		assert_int((r.get("applied", []) as Array).size()).is_greater(0)
		assert_int(int(c.credits)).is_greater_equal(4)


## Ignoring a distress call is free; answering it resolves the p.71 subtable.
func test_distress_call_respects_the_choice() -> void:
	var ignored: Resource = _campaign([_member("Rin")], 2)
	var ir: Dictionary = Resolver.apply(
		ignored, _event("Distress Call"), {"Distress Call": "ignore"})
	assert_int(int(ir.get("hull_damage", 0))).is_equal(0)

	for _i: int in range(30):
		var c: Resource = _campaign([_member("Rin", {"savvy": 2})], 1)
		var r: Dictionary = Resolver.apply(
			c, _event("Distress Call"), {"Distress Call": "aid"})
		assert_int((r.get("applied", []) as Array).size()).is_greater(0)
		# The worst branch is 1D6+1, and 3-4 chains into an Escape Pod that
		# cannot damage the hull at all.
		assert_int(int(r.get("hull_damage", 0))).is_between(0, 7)


func test_an_empty_crew_is_safe() -> void:
	var c: Resource = _campaign([], 2)
	for title: String in [
		"Down-time", "Accident", "Cosmic Phenomenon", "Time to Read a Book",
		"Travel-time", "Uneventful Trip",
	]:
		Resolver.apply(c, _event(title))
	assert_int(int(c.story_points)).is_equal(2)
