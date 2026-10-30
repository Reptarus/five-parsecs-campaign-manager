extends GdUnitTestSuite
## Core Rules p.83: a Patron is a type rolled on the Patron Table, and nothing else.
##
## Until 2026-10-29 four places made a new Patron and each invented one: five
## made-up names and types with Persistent on a flat 1D6 4+ (post-battle events), an
## influence/credits/"preferences" profile (GameStateManager), and a generated
## person's name with an invented tier and job (both crew-task sites). The job path
## then read `patron_name`/`patron_type` while contacts carry `name`/`type`, so an
## offer from the crew's own Patron re-rolled its type and showed a stranger's name.
## And the p.85 Opportunity mission rolled a 2D6 "contact table" in neither book
## that, on a 5+, turned it into a Patron job from an employer the app made up.
##
## These cases read what a player sees: the contact on the Patrons screen, the offer
## on the job board, and the briefing at Mission Prep.

const PatronContactScript = preload("res://src/core/patrons/PatronContact.gd")
const PatronJobEffectsScript = preload("res://src/core/patrons/PatronJobEffects.gd")
const NewWorldArrivalScript = preload("res://src/core/campaign/NewWorldArrival.gd")
const PostBattleContextScript = preload(
	"res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const JobOfferScene := "res://src/ui/screens/world/components/JobOfferComponent.tscn"
const MissionPrepScene := "res://src/ui/screens/world/components/MissionPrepComponent.tscn"

## Core Rules p.83, Patron Table (D10).
const BOOK_TABLE := {1: "Corporation", 2: "Corporation", 3: "Local Government",
	4: "Local Government", 5: "Sector Government", 6: "Wealthy Individual",
	7: "Wealthy Individual", 8: "Private Organization", 9: "Private Organization",
	10: "Secretive Group"}

var _prior_campaign: Resource = null


func before_test() -> void:
	_prior_campaign = GameState.current_campaign
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "patron_contact_suite"})
	GameState.current_campaign = campaign


func after_test() -> void:
	DiceManager.clear_forced_results("Patron Type")
	GameState.current_campaign = _prior_campaign


func _force_type(roll: int) -> void:
	assert_bool(DiceManager.queue_forced_result("Patron Type", roll)) \
		.override_failure_message("premise: the QA forcing seam accepted the roll").is_true()


func _offers_for(patron_data: Dictionary) -> Array:
	var component: Node = auto_free((load(JobOfferScene) as PackedScene).instantiate())
	add_child(component)
	return component._generate_job_offers(patron_data, "Gamma Prime")


func test_the_patron_table_is_the_book() -> void:
	for roll: int in BOOK_TABLE:
		assert_str(PatronJobEffectsScript.patron_type_for_roll(roll)) \
			.override_failure_message("D10 %d" % roll).is_equal(BOOK_TABLE[roll])


func test_a_new_contact_is_its_rolled_type_and_nothing_else() -> void:
	_force_type(6)
	var p: Dictionary = PatronContactScript.make("event")
	assert_str(str(p["type"])).is_equal("Wealthy Individual")
	assert_str(str(p["name"])).override_failure_message(
		"the book names no Patron, so the type is the name").is_equal("Wealthy Individual")
	var keys: Array = p.keys()
	keys.sort()
	assert_array(keys).is_equal(["id", "jobs_offered", "name", "source", "status", "type"])
	# p.84: Persistent is a Benefit a JOB carries (8-9), never rolled on meeting someone.
	assert_bool(NewWorldArrivalScript.is_persistent_patron(p)).is_false()


func test_a_forced_type_skips_the_roll() -> void:
	## p.74 Corporate State: "Patrons are always Corporations".
	_force_type(10)
	var p: Dictionary = PatronContactScript.make("crew_task", "Corporation")
	assert_str(str(p["name"])).is_equal("Corporation")
	assert_bool(DiceManager.get_forced_results().is_empty()).override_failure_message(
		"a forced type must not spend the Patron Table roll").is_false()


func test_a_post_battle_event_patron_comes_from_the_table() -> void:
	_force_type(5)
	var ctx = PostBattleContextScript.new()
	ctx.campaign = {"patrons": []}
	ctx.add_patron()
	var patrons: Array = ctx.campaign["patrons"]
	assert_int(patrons.size()).is_equal(1)
	assert_str(str(patrons[0]["name"])).is_equal("Sector Government")
	assert_bool(NewWorldArrivalScript.is_persistent_patron(patrons[0])).is_false()


func test_the_gain_a_patron_favor_comes_from_the_table() -> void:
	_force_type(1)
	GameStateManager.set_patrons([])
	var p: Dictionary = GameStateManager.add_patron()
	assert_str(str(p["type"])).is_equal("Corporation")
	for key in ["influence", "resources", "preferences", "relationship", "tier"]:
		assert_bool(p.has(key)).override_failure_message("invented key: " + key).is_false()


func test_an_opportunity_offer_has_no_patron() -> void:
	## p.85: "Carry out an Opportunity mission — always available". One mission, no
	## Patron, so none of the p.83 Patron tables.
	var jobs: Array = _offers_for({})
	assert_int(jobs.size()).is_equal(1)
	var job: Dictionary = jobs[0]
	assert_str(str(job["mission_source"])).is_equal("opportunity")
	assert_str(str(job["patron_name"])).is_equal("Open Market")
	assert_int(int(job["danger_pay"])).is_equal(0)
	assert_int(int(job["pay"])).is_equal(0)
	assert_bool(job.has("danger_level")).is_false()
	for cat in ["benefits", "hazards", "conditions"]:
		assert_int((job[cat] as Array).size()).override_failure_message(
			"an Opportunity mission rolled the p.83 %s table" % cat).is_equal(0)


func test_the_patron_tables_are_never_rolled_for_a_non_patron_offer() -> void:
	## p.83 opens "If you received a job offer from a Patron". One offer is a weak
	## sample: a type with no threshold row uses 8, so an ungated roll still leaves all
	## three tables empty about a third of the time. Thirty draws per source make a
	## pass by chance negligible.
	var component: Node = auto_free((load(JobOfferScene) as PackedScene).instantiate())
	add_child(component)
	var rolled_for_a_patron := 0
	for _i in 30:
		var bhc: Dictionary = component._patron_bhc(DiceManager, "Corporation", "patron")
		for cat in ["benefits", "hazards", "conditions"]:
			rolled_for_a_patron += (bhc[cat] as Array).size()
	assert_int(rolled_for_a_patron).override_failure_message(
		"premise: the p.83 tables roll for a Patron job").is_greater(0)
	for source in ["opportunity", "rival", "quest"]:
		for _i in 30:
			var bhc: Dictionary = component._patron_bhc(DiceManager, "Corporation", source)
			for cat in ["benefits", "hazards", "conditions"]:
				assert_int((bhc[cat] as Array).size()).override_failure_message(
					"a %s offer rolled the p.83 %s table" % [source, cat]).is_equal(0)


func test_an_offer_from_your_own_patron_keeps_who_they_are() -> void:
	## A contact saved by an older build: `name` and `type`, the shape every producer
	## writes, which the job builder used to miss.
	var jobs: Array = _offers_for({"id": "p_old", "name": "Old Sal", "type": "Corporation"})
	assert_int(jobs.size()).override_failure_message(
		"one job per Patron offer (p.77)").is_equal(1)
	var job: Dictionary = jobs[0]
	assert_str(str(job["patron_name"])).is_equal("Old Sal")
	assert_str(str(job["patron_type"])).is_equal("Corporation")
	assert_str(str(job["patron_id"])).is_equal("p_old")
	assert_str(str(job["mission_source"])).is_equal("patron")
	assert_int(int(job["pay"])).is_equal(int(job["danger_pay"]))


func test_a_bare_name_contact_rolls_a_book_type_and_stays_a_patron() -> void:
	## Creation tables store a Patron as a bare name. Its empty type used to read as
	## an Opportunity mission.
	_force_type(10)
	var job: Dictionary = _offers_for({"patron_name": "Bryn"})[0]
	assert_str(str(job["patron_type"])).is_equal("Secretive Group")
	assert_str(str(job["patron_name"])).is_equal("Bryn")
	assert_str(str(job["mission_source"])).is_equal("patron")


func test_the_licence_never_blocks_the_opportunity_mission() -> void:
	## p.72: a licence is needed "to perform Patron jobs". The Open Market offer always
	## had a patron_name, so the old name test called it a Patron job.
	var component: Node = auto_free((load(JobOfferScene) as PackedScene).instantiate())
	add_child(component)
	var opportunity: Dictionary = component._generate_job_offers({}, "Gamma Prime")[0]
	assert_bool(component._is_patron_job(opportunity)).is_false()
	assert_bool(component._is_patron_job({"patron_name": "Open Market"})).is_false()
	assert_bool(component._is_patron_job({"patron_name": "Old Sal"})).is_true()
	assert_bool(component._is_patron_job({"mission_source": "faction"})).is_true()


func test_mission_prep_prints_the_pay_rule_not_a_danger_level() -> void:
	var prep: Node = auto_free((load(MissionPrepScene) as PackedScene).instantiate())
	add_child(prep)
	await await_idle_frame()
	prep.mission_data = {"enemy_type": "Gangers", "location": "Gamma Prime",
		"danger_level": 3, "danger_pay": 2, "pay": 2}
	prep._update_mission_briefing()
	var text: String = prep.mission_briefing_label.text
	assert_str(text).override_failure_message("premise: the briefing rendered:\n" + text) \
		.contains("Gangers")
	assert_str(text).not_contains("Danger Level")
	assert_str(text).contains("1D6 credits + 2 Danger Pay")


func test_the_invented_generators_are_gone() -> void:
	for path in ["res://src/core/managers/PatronManager.gd",
			"res://src/core/systems/PatronSystem.gd",
			"res://src/core/campaign/PatronJobManager.gd",
			"res://src/core/rivals/RivalSystem.gd"]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			path + " is back").is_false()
