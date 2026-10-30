extends GdUnitTestSuite
## Core Rules p.72: a new world is a name and its World Trait.
##
## New World Arrival is four steps (Rivals follow on 1D6 5+, Patrons stay behind,
## licensing on 1D6 5-6, then one World Trait on the D100 table). Until 2026-10-29
## the app also gave every world a danger level, a tech level, a government, a
## population, "locations" and "special features", citing pp.80-86, which are the
## Trade and Exploration tables and Job Offers. It also rolled a per-turn "world
## event" D6 (Market Surge, Labor Shortage, Pirate Activity, Trade Boom, Civil
## Unrest, Quiet Period). A full-text search of both books finds none of those
## names. The event rows promised modifiers ("Local unrest penalizes all crew tasks
## by -1") that nothing applied, and three screens printed them anyway.
##
## Every case below reads what a player would see or what a save would hold. A save
## written before the change still carries the old keys, so the fixtures are that
## shape: the keys must be dropped on load, never rendered.

const WorldGeneratorScript = preload("res://src/core/campaign/WorldGenerator.gd")
const PDMScript = preload("res://src/core/world/PlanetDataManager.gd")
const PlanetDetailBuilder = preload("res://src/core/world/PlanetDetailBuilder.gd")
const WorldBriefingBuilder = preload("res://src/core/world/WorldBriefingBuilder.gd")
const WorldPhaseControllerScript = preload("res://src/ui/screens/world/WorldPhaseController.gd")
const WorldInfoPanelScene := "res://src/ui/screens/campaign/panels/WorldInfoPanel.tscn"
const PatronRivalScene := "res://src/ui/screens/world/PatronRivalManager.tscn"
const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

## What a save written before 2026-10-29 holds for a world.
const LEGACY_WORLD := {
	"id": "gamma_prime",
	"name": "Gamma Prime",
	"type": "haze",
	"type_name": "Haze",
	"traits": ["haze"],
	"danger_level": 4,
	"locations": [{"name": "Black Market", "type": "underground", "danger_mod": 3}],
	"special_features": ["high_danger"],
	"resources_extracted": 3,
	"world_events": [{"type": "unrest", "name": "Civil Unrest",
		"description": "Local unrest penalizes all crew tasks by -1", "campaign_turn": 2}],
	"temporary_effects": [{"effect_type": "payment", "modifier": 0.3}],
	"market_conditions": {"stability": 3},
	"trade_opportunities": [{"type": "rare_items"}],
	"price_modifiers": {"weapons": 0.8},
	"discovered_on_turn": 0,
	"visit_count": 2,
	"missions_completed": 1,
}

const INVENTED := ["danger_level", "locations", "special_features", "resources_extracted",
	"world_events", "temporary_effects", "active_modifiers", "market_conditions",
	"trade_opportunities", "price_modifiers", "tech_level", "government_type",
	"population_scale"]

## Phrases only the invented fields ever put on screen. Whole phrases, not words: a
## world can really carry the Dangerous trait, and "Danger" alone would then fail
## for the wrong reason.
const INVENTED_TEXT := ["Danger Level", "Civil Unrest", "penalizes all crew tasks",
	"LOCATIONS", "Black Market", "SPECIAL FEATURES", "NOTABLE FEATURES", "high_danger",
	"WORLD EVENTS", "CURRENT EVENT", "Government:", "Tech Level", "THREATS",
	"OPPORTUNITIES", "MARKET & TRADE", "No known threats", "No market data"]

var _pdm_snapshot: Dictionary = {}
var _prior_campaign: Resource = null


func before_test() -> void:
	var pdm: Node = get_node("/root/PlanetDataManager")
	_pdm_snapshot = pdm.serialize_all().duplicate(true)
	_prior_campaign = GameState.current_campaign


func after_test() -> void:
	get_node("/root/PlanetDataManager").deserialize_all(_pdm_snapshot)
	GameState.current_campaign = _prior_campaign


func _legacy_planet() -> Object:
	var p: Object = PDMScript.PlanetData.new()
	p.deserialize(LEGACY_WORLD.duplicate(true))
	return p


func _texts(node: Node, out: Array[String]) -> void:
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is RichTextLabel:
			out.append((child as RichTextLabel).text)
		elif child is Button:
			out.append((child as Button).text)
		_texts(child, out)


func _assert_no_invented_text(joined: String, where: String) -> void:
	for word in INVENTED_TEXT:
		assert_bool(joined.contains(word)).override_failure_message(
			"%s prints '%s', which only an invented world field produced:\n%s"
			% [where, word, joined]).is_false()


func test_a_generated_world_is_a_name_and_a_trait() -> void:
	var gen: Node = WorldGeneratorScript.new()
	var world: Dictionary = gen.generate_world(3)
	gen.free()
	var keys: Array = world.keys()
	keys.sort()
	assert_array(keys).override_failure_message(
		"generate_world() returns more than p.72 gives a world: %s" % str(keys)) \
		.is_equal(["discovered_on_turn", "id", "name", "traits", "type", "type_name"])
	assert_array(world["traits"]).is_not_empty()


func test_an_old_save_loads_and_drops_the_invented_fields() -> void:
	var saved: Dictionary = _legacy_planet().serialize()
	for key: String in INVENTED:
		assert_bool(saved.has(key)).override_failure_message(
			"a reloaded world still saves '%s'" % key).is_false()
	# The real fields survive the round trip.
	assert_str(str(saved["name"])).is_equal("Gamma Prime")
	assert_array(saved["traits"]).is_equal(["haze"])
	assert_int(int(saved["visit_count"])).is_equal(2)
	assert_int(int(saved["missions_completed"])).is_equal(1)


func test_upserting_an_old_world_keeps_only_the_book_fields() -> void:
	var pdm: Node = get_node("/root/PlanetDataManager")
	var pid: String = pdm.upsert_current_world(LEGACY_WORLD.duplicate(true), 2)
	assert_str(pid).is_equal("gamma_prime")
	var saved: Dictionary = pdm.get_current_planet().serialize()
	for key: String in INVENTED:
		assert_bool(saved.has(key)).override_failure_message(
			"upsert_current_world() copied '%s' from the old save" % key).is_false()


func test_the_planet_detail_prints_the_trait_and_nothing_invented() -> void:
	var vbox: VBoxContainer = auto_free(VBoxContainer.new())
	add_child(vbox)
	PlanetDetailBuilder.build_into(vbox, _legacy_planet())
	var texts: Array[String] = []
	_texts(vbox, texts)
	var joined := "\n".join(texts)
	assert_str(joined).override_failure_message(
		"premise: the detail rendered the world at all:\n" + joined).contains("Gamma Prime")
	assert_str(joined).contains("Traits")
	_assert_no_invented_text(joined, "PlanetDetailBuilder")


func test_the_world_briefing_prints_the_trait_and_nothing_invented() -> void:
	var vbox: VBoxContainer = auto_free(VBoxContainer.new())
	add_child(vbox)
	WorldBriefingBuilder.build_into(vbox, _legacy_planet())
	var texts: Array[String] = []
	_texts(vbox, texts)
	var joined := "\n".join(texts)
	assert_str(joined).override_failure_message(
		"premise: the briefing rendered the world at all:\n" + joined).contains("WORLD TRAITS")
	_assert_no_invented_text(joined, "WorldBriefingBuilder")


func test_no_turn_rolls_a_world_event() -> void:
	## The D6 "world event" was rolled by WorldPhaseController every turn and stored
	## by PlanetDataManager. Both halves are gone; neither book has the table.
	var pdm: Node = get_node("/root/PlanetDataManager")
	for gone in ["generate_world_event", "add_world_event", "has_world_event_for_turn",
			"process_turn_effects", "get_planet_modifier", "get_exploration_opportunities"]:
		assert_bool(pdm.has_method(gone)).override_failure_message(
			"PlanetDataManager.%s() is back" % gone).is_false()
	var controller: Node = auto_free(WorldPhaseControllerScript.new())
	assert_bool(controller.has_method("_generate_turn_world_event")).is_false()


func test_creation_step_six_shows_the_world_and_its_trait_only() -> void:
	var panel: Node = auto_free((load(WorldInfoPanelScene) as PackedScene).instantiate())
	add_child(panel)
	await await_idle_frame()
	await await_idle_frame()
	panel._display_world_data({"name": "Gamma Prime", "traits": ["haze"]})
	await await_idle_frame()
	var texts: Array[String] = []
	_texts(panel, texts)
	var joined := "\n".join(texts)
	assert_str(joined).override_failure_message(
		"premise: step 6 rendered the world:\n" + joined).contains("Gamma Prime")
	assert_str(joined).contains("WORLD TRAITS")
	_assert_no_invented_text(joined, "WorldInfoPanel")
	var data: Dictionary = panel.get_panel_data()
	for key in ["opportunities", "threats", "selected_opportunity"]:
		assert_bool(data.has(key)).is_false()


func test_a_contacts_home_world_has_a_name() -> void:
	## PatronRivalManager._planet_name() read get_planet_stats()["name"], and
	## get_planet_stats() never returned a name, so "on <world>" was always blank.
	var pdm: Node = get_node("/root/PlanetDataManager")
	pdm.upsert_current_world(LEGACY_WORLD.duplicate(true), 2)
	assert_str(str(pdm.get_planet_stats("gamma_prime").get("name", ""))).is_equal("Gamma Prime")

	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({"campaign_id": "world_is_trait"})
	campaign.rivals = [{"id": "r1", "name": "Old nemesis", "type": "Gangers",
		"planet_id": "gamma_prime", "created_turn": 2, "origin": "campaign_event"}]
	GameState.current_campaign = campaign
	var screen: Node = auto_free((load(PatronRivalScene) as PackedScene).instantiate())
	add_child(screen)
	await await_idle_frame()
	var texts: Array[String] = []
	_texts(screen, texts)
	var joined := "\n".join(texts)
	assert_str(joined).override_failure_message(
		"premise: the Rival rendered:\n" + joined).contains("Old nemesis")
	assert_str(joined).override_failure_message(
		"the Rival's home world printed blank:\n" + joined).contains("on Gamma Prime")
