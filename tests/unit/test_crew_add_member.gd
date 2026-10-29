extends GdUnitTestSuite
## Crew Management's "Add Member" must open a creator the player can see, and the
## character it makes must join the campaign's crew.
##
## Measured on the Sprint U 5PFH pass (2026-10-29): the button navigated to
## SimpleCharacterCreator as a whole screen. That script set `visible = false` in
## _ready() and nothing showed it, its `character_created` signal had no listener
## once it was a screen rather than an overlay, and it rolled stats with an invented
## ceil(2D6/3) formula. So Add Member led to a blank page, and its Create button
## added nobody. The layout sweep force-shows hidden roots, so it measured that
## screen shown and green the whole time.
##
## The screen now hosts the creator the wizard and the Campaign Editor use
## (CharacterCreator.tscn) as an overlay, and adds through
## FiveParsecsCampaignCore.add_crew_member(), the crew-addition chokepoint.

const ScreenScene := preload("res://src/ui/screens/crew/CrewManagementScreen.tscn")
const CreatorScript := preload("res://src/core/character/Generation/CharacterCreator.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _gs: Node = null
var _prior_campaign = null
var _snap: Dictionary = {}
var _campaign: FiveParsecsCampaignCore = null


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	_prior_campaign = _gs.current_campaign
	_campaign = FiveParsecsCampaignCore.new()
	var first := Character.new()
	first.character_name = "Existing Hand"
	_campaign.add_crew_member(first.to_dictionary())
	_gs.current_campaign = _campaign


func after_test() -> void:
	_gs.current_campaign = _prior_campaign
	SaveDirGuard.restore(_snap)


func _screen() -> Control:
	var screen: Control = ScreenScene.instantiate()
	add_child(screen)
	auto_free(screen)
	await await_idle_frame()
	await await_idle_frame()
	return screen


func _creator(screen: Node) -> Control:
	for child in screen.get_children():
		if child.get_script() == CreatorScript:
			return child
	return null


func test_add_member_shows_the_real_creator_over_the_roster() -> void:
	var screen := await _screen()
	screen._on_add_member_pressed()
	await await_idle_frame()
	var creator := _creator(screen)
	assert_object(creator).override_failure_message(
		"Add Member must open CharacterCreator on this screen, not navigate away"
	).is_not_null()
	assert_bool(creator.visible).is_true()
	assert_bool(screen.get_node("MarginContainer").visible).override_failure_message(
		"the roster is hidden while the creator is open").is_false()
	assert_str(creator.confirm_btn.text).is_equal("Add to Crew")


func test_a_created_character_joins_the_campaign_crew() -> void:
	var screen := await _screen()
	var before: int = _campaign.get_crew_members().size()
	screen._on_add_member_pressed()
	await await_idle_frame()
	var recruit := Character.new()
	recruit.character_name = "New Recruit"
	_creator(screen).character_created.emit(recruit)
	await await_idle_frame()
	var names: Array = []
	for m in _campaign.get_crew_members():
		names.append(str(m.get("character_name", "")) if m is Dictionary
				else str(m.character_name))
	assert_int(_campaign.get_crew_members().size()).is_equal(before + 1)
	assert_array(names).contains(["New Recruit"])
	assert_bool(screen.get_node("MarginContainer").visible).is_true()
	# Assert where the damage lands: the GRID. Saved crew are Dictionaries, and their
	# cards were never tracked, so the reload this add triggers kept the old cards and
	# stacked a second copy of the roster beneath them.
	await await_idle_frame()
	assert_int(screen.crew_grid.get_child_count()).override_failure_message(
		"the roster must show one card per crew member after the reload, not two"
	).is_equal(before + 1)
	assert_str(screen.crew_count_label.text).contains("Crew: %d" % (before + 1))


func test_a_roster_larger_than_the_deploy_size_can_still_grow() -> void:
	# Core Rules p.85: "You may select no more than 6 crew members to bring into a
	# battle. The rest will wait behind on the ship." No page caps the ROSTER, so
	# Add Member must open the creator however many crew there already are.
	for i in 8:
		var extra := Character.new()
		extra.character_name = "Hand %d" % i
		_campaign.add_crew_member(extra.to_dictionary())
	var screen := await _screen()
	screen._on_add_member_pressed()
	await await_idle_frame()
	assert_object(_creator(screen)).is_not_null()
	assert_bool(_creator(screen).visible).is_true()


func test_cancel_returns_to_an_unchanged_roster() -> void:
	var screen := await _screen()
	var before: int = _campaign.get_crew_members().size()
	screen._on_add_member_pressed()
	await await_idle_frame()
	var creator := _creator(screen)
	creator.creation_cancelled.emit()
	await await_idle_frame()
	assert_bool(creator.visible).is_false()
	assert_bool(screen.get_node("MarginContainer").visible).is_true()
	assert_int(_campaign.get_crew_members().size()).is_equal(before)
