extends GdUnitTestSuite
## The in-app Compendium's mission pages read the tables the campaign rolls on.
##
## "Mission Types" rendered data/mission_templates.json under a "Core Rules" label:
## credit rewards of 100-1500 (Five Parsecs pays in single digits), a 1-5
## difficulty, Stealth and Social skills, and objectives such as Infiltrate and
## Extract. None of it is in either book. That file now keeps only the Battle
## Simulator's flavour titles, and the Compendium reads data/mission_tables/,
## which MissionTableManager rolls from: the five battle sources (Core Rules p.87)
## and the p.89-91 objective definitions.

const Provider := preload("res://src/core/compendium/CompendiumDataProvider.gd")
const SimSetup := preload("res://src/core/battle/BattleSimulatorSetup.gd")

const INVENTED := ["objectives", "reward_range", "difficulty_range", "required_skills",
	"enemy_types", "description_templates", "deployment_condition_chance",
	"notable_sight_chance"]


func _names(items: Array) -> Array:
	return items.map(func(i: Dictionary) -> String: return str(i.get("name", "")))


func test_mission_types_are_the_five_battle_sources() -> void:
	var p = Provider.new()
	var items: Array = p.get_items("missions")
	assert_array(_names(items)).contains_exactly_in_any_order([
		"Opportunity Mission", "Patron Mission", "Rival Mission", "Quest Mission",
		"Invasion Battle"])
	for item: Dictionary in items:
		for key: String in INVENTED:
			assert_bool(item.has(key)).override_failure_message(
				"%s carries '%s'" % [item.get("name"), key]).is_false()
	assert_str(str(p.get_category("missions").get("source_book", ""))).contains("p.8")


func test_the_objectives_page_lists_the_p89_objectives() -> void:
	var items: Array = Provider.new().get_items("mission_objectives")
	assert_array(_names(items)).contains(["Move Through", "Deliver", "Fight Off", "Secure"])
	for item: Dictionary in items:
		assert_str(str(item.get("victory_condition", ""))).is_not_empty()


func test_the_template_file_keeps_only_flavour() -> void:
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/mission_templates.json"))
	assert_bool(data is Dictionary).is_true()
	assert_str(str(data.get("_source", ""))).contains("Not from either rulebook")
	for template: Dictionary in data.get("mission_templates", []):
		for key: String in INVENTED:
			assert_bool(template.has(key)).is_false()
	# The Battle Simulator still offers the four job sources it builds from.
	assert_int(SimSetup.new().get_mission_types().size()).is_equal(4)


## Every field a player sees on these pages is rules text. The Rival page used to say
## "Use rival_attack_types table from rival_involvement.json"; it now gives p.91's rule.
func test_no_detail_field_names_a_data_file() -> void:
	var p = Provider.new()
	for cat_id: String in ["missions", "mission_objectives"]:
		var fields: Array = p.get_category(cat_id).get("detail_fields", [])
		for item: Dictionary in p.get_items(cat_id):
			for f: String in fields:
				assert_str(str(item.get(f, ""))).override_failure_message(
					"%s.%s names a file" % [item.get("name"), f]).not_contains(".json")
	var rival: Array = p.get_items("missions").filter(
		func(i: Dictionary) -> bool: return i.get("name") == "Rival Mission")
	assert_str(str(rival[0].get("notes", ""))).contains("no Win condition against Rivals")
