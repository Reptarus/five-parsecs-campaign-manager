extends GdUnitTestSuite
## The World Phase "?" help text a player can open (Upkeep, Crew Tasks).
##
## RulesHelpText held 35 topics; only two were ever shown, and nine topics carried
## a literal "pass" line inside the text, the Crew Tasks one among them. These cases
## hold every key a screen asks for to real text, and no topic to a stray statement.

const HelpText = preload("res://src/data/rules_help_text.gd")
const MISSING := "[i]No help text available[/i]"


func _code_files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir.path_join(entry)
		if d.current_is_dir():
			if not entry.begins_with("."):
				_code_files(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func test_every_key_a_screen_asks_for_has_text() -> void:
	var files: Array = []
	_code_files("res://src", files)
	var keys: Array = []
	var re := RegEx.create_from_string("RulesHelpText\\.get_tooltip\\(\"([a-z_]+)\"\\)")
	for path: String in files:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			keys.append(m.get_string(1))
	assert_array(keys).override_failure_message(
		"found no get_tooltip() callers, so the scan is broken").is_not_empty()
	for key: String in keys:
		assert_str(HelpText.get_tooltip(key)).override_failure_message(
			"a screen asks for help topic '%s' and gets nothing" % key).is_not_equal(MISSING)


func test_no_topic_carries_a_stray_statement() -> void:
	for text: String in [HelpText.UPKEEP_PHASE, HelpText.CREW_TASKS_OVERVIEW]:
		for line: String in text.split("\n"):
			assert_str(line.strip_edges()).override_failure_message(
				"help text shows a bare 'pass' line to the player").is_not_equal("pass")


func test_the_topics_state_the_book_rule_and_cite_it() -> void:
	# Core Rules p.76: "Upkeep costs 1 credit if you have 4-6 crew, +1 additional
	# credit per crew member past 6."
	assert_str(HelpText.UPKEEP_PHASE).contains("4-6 crew").contains("past 6") \
		.contains("p.76")
	# p.76: "You may assign up to two characters to any one task."
	assert_str(HelpText.CREW_TASKS_OVERVIEW).contains("up to two characters") \
		.contains("pp.76-78")
