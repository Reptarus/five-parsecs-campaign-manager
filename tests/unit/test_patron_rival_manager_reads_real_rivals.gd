extends GdUnitTestSuite
## T11-29 — the Patrons & Rivals screen must READ the campaign, never write to it,
## and must render the keys a real Rival has.
##
## THE DEFECT (device, deploy #19). Every field on every Rival card read "Unknown".
## The screen displayed `threat_level`, `relationship` and `status` — three keys
## written by exactly ONE producer: the screen's own _create_rival_from_template(),
## fed by `data/patrons/patron_templates.json`, `data/rivals/rival_templates.json`
## and `data/jobs/job_templates.json`.
##
## ⚠ ALL THREE OF THOSE FILES ARE ABSENT FROM THE REPO. So every value came from
## `_create_*_templates_fallback()` — "Director Johnson", `job_multiplier 1.5`,
## invented `threat_levels` — none of it in either rulebook. And
## `_save_rivals_to_gamestate()` wrote the result INTO `campaign.rivals`. The screen
## was not a bad display of good data; it was a fabricated-data PRODUCER that
## rendered its own invented shape and called every genuine Rival Unknown.
##
## Fix (owner decision, Sep 5): read-only viewer. The generate/job surface is gone,
## the live job path is the World Phase JOB_OFFERS step, and the Campaign Editor
## remains the QA injection route.

const ManagerScene := "res://src/ui/screens/world/PatronRivalManager.tscn"
const ManagerScript = preload("res://src/ui/screens/world/PatronRivalManager.gd")
const CampaignCoreScript = preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _prior_campaign: Resource = null


func before_test() -> void:
	_prior_campaign = GameState.current_campaign
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "prm_t"})
	# The shape RivalPatronResolver._append_rival() and PostBattleContext.add_rival()
	# actually emit — NOT the template shape the screen used to invent.
	campaign.rivals = [{
		"id": "r1",
		"name": "Old nemesis",
		"type": "Gangers",
		"planet_id": "",
		"threat_level": 1,
		"created_turn": 6,
		"origin": "campaign_event",
		"persistent": true,
		"enemy_count_bonus": 1,
	}]
	campaign.patrons = [{
		"id": "p1", "name": "Vex Holdings", "type": "Corporation",
		"status": "Active", "relationship": 2, "jobs_offered": 1,
	}]
	GameState.current_campaign = campaign


func after_test() -> void:
	GameState.current_campaign = _prior_campaign


func _open() -> Node:
	var packed: PackedScene = load(ManagerScene)
	assert_object(packed).is_not_null()
	var screen: Node = auto_free(packed.instantiate())
	add_child(screen)
	await await_idle_frame()
	return screen


func _all_text(node: Node, out: Array[String]) -> void:
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
		_all_text(child, out)


func test_a_real_rival_renders_its_type_origin_and_riders() -> void:
	var screen := await _open()
	var texts: Array[String] = []
	_all_text(screen, texts)
	var joined: String = "\n".join(texts)

	assert_str(joined).override_failure_message(
		"The Rival's enemy type is not on screen. Rendered text was:\n%s" % joined
	).contains("Gangers")
	assert_str(joined).override_failure_message(
		"The Rival's origin is not shown, so the player cannot tell a battle "
		+ "grudge from a campaign event."
	).contains("Campaign event")
	assert_str(joined).contains("since turn 6")
	# The p.126 riders are rules the player must remember at the table.
	assert_str(joined).contains("Follows you")
	assert_str(joined).contains("+1 enemies")


## The finding as it was reported: every field said Unknown.
func test_nothing_on_the_screen_says_unknown() -> void:
	var screen := await _open()
	var texts: Array[String] = []
	_all_text(screen, texts)
	for t in texts:
		assert_str(t).override_failure_message(
			"A control still renders the placeholder 'Unknown' (%s). Blank is the "
			% t + "honest value for a field a real producer does not write."
		).not_contains("Unknown")


## The screen is a RECORD of who you have met. Opening it must not mint contacts,
## and must not rewrite the ones you have — merely opening it used to write four
## invented entries into the save file.
func test_opening_the_screen_does_not_write_to_the_campaign() -> void:
	var before_rivals: String = JSON.stringify(GameState.current_campaign.rivals)
	var before_patrons: String = JSON.stringify(GameState.current_campaign.patrons)

	var _screen := await _open()
	await await_idle_frame()

	assert_str(JSON.stringify(GameState.current_campaign.rivals)) \
		.override_failure_message(
			"campaign.rivals changed just from opening the viewer."
		).is_equal(before_rivals)
	assert_str(JSON.stringify(GameState.current_campaign.patrons)) \
		.override_failure_message(
			"campaign.patrons changed just from opening the viewer."
		).is_equal(before_patrons)


## An empty list is a legitimate state — especially on turn 1 — and must render as
## an empty list rather than being "helpfully" populated.
func test_an_empty_campaign_stays_empty() -> void:
	GameState.current_campaign.rivals = []
	GameState.current_campaign.patrons = []

	var _screen := await _open()
	await await_idle_frame()

	assert_int((GameState.current_campaign.rivals as Array).size()).is_equal(0)
	assert_int((GameState.current_campaign.patrons as Array).size()).is_equal(0)


## Structural guard: the fabricating surface must not come back. Named explicitly
## because "the buttons are gone from the scene" and "the code that fed them is
## gone" are separate facts, and a re-added button with a live handler is exactly
## how this would regress.
func test_the_fabricating_generators_are_gone() -> void:
	for dead: String in [
		"_load_json_templates", "_create_patron_templates_fallback",
		"_create_rival_templates_fallback", "_create_job_templates_fallback",
		"_generate_patrons_from_templates", "_generate_rivals_from_templates",
		"_create_patron_from_template", "_create_rival_from_template",
		"_save_patrons_to_gamestate", "_save_rivals_to_gamestate",
		"_on_generate_patron_pressed", "_on_generate_rival_pressed",
		"_on_manage_jobs_pressed", "_generate_job_offer",
	]:
		assert_bool(ManagerScript.new().has_method(dead)).override_failure_message(
			"%s is back. It generated contacts from three JSON template files that "
			% dead + "do not exist, i.e. from invented fallback data, and wrote them "
			+ "into the campaign."
		).is_false()


func test_no_generate_buttons_remain_in_the_scene() -> void:
	var screen := await _open()
	var texts: Array[String] = []
	_all_text(screen, texts)
	for t in texts:
		var low: String = t.to_lower()
		assert_bool(low.begins_with("generate") or low == "manage jobs") \
			.override_failure_message(
				"A fabricating control is still on screen: '%s'." % t
			).is_false()
