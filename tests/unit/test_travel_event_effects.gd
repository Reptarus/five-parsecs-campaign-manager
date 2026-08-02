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


# --- honest reporting of what is not resolved yet -----------------------------

## The seven events needing a choice, a battle or a sub-table must SAY so rather
## than silently applying nothing, which is what the whole table used to do.
func test_interactive_events_are_flagged_not_silently_skipped() -> void:
	for title: String in [
		"Asteroids", "Raided", "Drive Trouble", "Distress Call",
		"Patrol Ship", "Escape Pod", "Locked in the Library Data",
	]:
		var c: Resource = _campaign([_member("Rin")], 3)
		var report: Dictionary = Resolver.apply(c, _event(title))
		assert_bool(bool(report.get("requires_interaction", false))
			).override_failure_message("%s was not flagged as interactive" % title
			).is_true()
		# and it must not have quietly changed anything
		assert_int(int(c.story_points)).is_equal(3)


func test_an_empty_crew_is_safe() -> void:
	var c: Resource = _campaign([], 2)
	for title: String in [
		"Down-time", "Accident", "Cosmic Phenomenon", "Time to Read a Book",
		"Travel-time", "Uneventful Trip",
	]:
		Resolver.apply(c, _event(title))
	assert_int(int(c.story_points)).is_equal(2)
