extends GdUnitTestSuite
## The creation tables (Core Rules pp.25-27) reach the character, once, under the book's
## names.
##
## Measured on 2026-10-29 before the fix:
##   - a background showed under five different spellings, most of them not the book's
##     ("Giant Overcrowded City", "War Torn Hellhole", "Subjugated Colony");
##   - a rolled background, motivation and class were kept only as trait strings, so the
##     fields kept create_character()'s MILITARY / SURVIVAL / SOLDIER;
##   - the five +2 XP rows granted nothing (folded into the stat bonuses, then written to
##     a property Character does not have);
##   - a recruit was rolled twice, collecting two sets of stat bonuses;
##   - a recruit's rolled credits landed on its career tally, which errata v1.06 forbids.

const CharGen = preload("res://src/core/character/CharacterGeneration.gd")
const BackgroundDataServiceRef = preload("res://src/core/character/BackgroundDataService.gd")
const CreatorScript = preload("res://src/core/character/Generation/CharacterCreator.gd")
const CREATOR_SCENE = preload("res://src/ui/screens/character/CharacterCreator.tscn")
const CrewTaskComponentScript = preload(
	"res://src/ui/screens/world/components/CrewTaskComponent.gd")
const CharacterCardScript = preload("res://src/ui/components/character/CharacterCard.gd")
const FinalPanelScript = preload("res://src/ui/screens/campaign/panels/FinalPanel.gd")

## The oracle is the printed page, Core Rules p.25, read with PyPDF2. Not the data file.
const P25 := [
	["Peaceful, High-Tech Colony", "PEACEFUL_HIGH_TECH_COLONY"],
	["Giant, Overcrowded, Dystopian City", "GIANT_OVERCROWDED_CITY"],
	["Low-Tech Colony", "LOW_TECH_COLONY"],
	["Mining Colony", "MINING_COLONY"],
	["Military Brat", "MILITARY_BRAT"],
	["Space Station", "SPACE_STATION"],
	["Military Outpost", "MILITARY_OUTPOST"],
	["Drifter", "DRIFTER"],
	["Lower Megacity Class", "LOWER_MEGACITY_CLASS"],
	["Wealthy Merchant Family", "WEALTHY_MERCHANT_FAMILY"],
	["Frontier Gang", "FRONTIER_GANG"],
	["Religious Cult", "RELIGIOUS_CULT"],
	["War-Torn Hell-Hole", "WAR_TORN_HELLHOLE"],
	["Tech Guild", "TECH_GUILD"],
	["Subjugated Colony on Alien World", "SUBJUGATED_COLONY"],
	["Long-Term Space Mission", "LONG_TERM_SPACE_MISSION"],
	["Research Outpost", "RESEARCH_OUTPOST"],
	["Primitive or Regressed World", "PRIMITIVE_WORLD"],
	["Orphan Utility Program", "ORPHAN_UTILITY_PROGRAM"],
	["Isolationist Enclave", "ISOLATIONIST_ENCLAVE"],
	["Comfortable Megacity Class", "COMFORTABLE_MEGACITY"],
	["Industrial World", "INDUSTRIAL_WORLD"],
	["Bureaucrat", "BUREAUCRAT"],
	["Wasteland Nomads", "WASTELAND_NOMADS"],
	["Alien Culture", "ALIEN_CULTURE"],
]


func _row(table: Array, roll: int) -> Dictionary:
	for e: Variant in table:
		if int(e["roll_min"]) <= roll and roll <= int(e["roll_max"]):
			return e
	return {}


func test_every_background_reads_its_printed_name() -> void:
	assert_int(P25.size()).is_equal(25)
	for pair: Array in P25:
		var book: String = pair[0]
		var key: String = pair[1]
		var ordinal: int = int(GlobalEnums.Background[key])
		assert_str(BackgroundDataServiceRef.display_name(key)).is_equal(book)
		assert_str(BackgroundDataServiceRef.enum_key(book)).is_equal(key)
		assert_str(GlobalEnums.get_background_display_name(ordinal)).is_equal(book)
		var label: String = ""
		for item: Array in CreatorScript.BACKGROUND_ITEMS:
			if int(item[1]) == ordinal:
				label = item[0]
		assert_str(label).override_failure_message(
			"the creator's dropdown label for %s is '%s'" % [key, label]).is_equal(book)


func test_old_spellings_find_the_printed_name() -> void:
	var cases := {
		"War Torn Hell Hole": "War-Torn Hell-Hole",
		"Giant Overcrowded City": "Giant, Overcrowded, Dystopian City",
		"Giant, Overcrowded City": "Giant, Overcrowded, Dystopian City",
		"Subjugated Colony": "Subjugated Colony on Alien World",
		"primitive_world": "Primitive or Regressed World",
		"Comfortable Megacity": "Comfortable Megacity Class",
		"MILITARY": "Military",
	}
	for raw: String in cases:
		assert_str(BackgroundDataServiceRef.display_name(raw)).is_equal(cases[raw])
	assert_str(BackgroundDataServiceRef.display_name("", "None")).is_equal("None")
	# Two of the screens that used to capitalise the key.
	var card = auto_free(CharacterCardScript.new())
	assert_str(card._get_enum_string(13, "Background")) \
		.is_equal("Giant, Overcrowded, Dystopian City")
	var final_panel = auto_free(FinalPanelScript.new())
	assert_str(final_panel._enum_to_display("WAR_TORN_HELLHOLE", "Background")) \
		.is_equal("War-Torn Hell-Hole")


func test_every_table_row_names_an_enum_member() -> void:
	CharGen._ensure_creation_tables_loaded()
	var tables := {"background_result": CharGen.BACKGROUND_TABLE,
		"motivation_result": CharGen.MOTIVATION_TABLE, "class_result": CharGen.CLASS_TABLE}
	for result_key: String in tables:
		assert_int((tables[result_key] as Array).size()).is_greater(0)
		for e: Variant in tables[result_key]:
			assert_str(CharGen._enum_key_for(result_key, e)).override_failure_message(
				"%s row '%s' names no enum member" % [result_key, e.get("name", "")]
			).is_not_empty()


func test_a_rolled_row_becomes_the_characters_fields_and_xp() -> void:
	CharGen._ensure_creation_tables_loaded()
	var bg: Dictionary = _row(CharGen.BACKGROUND_TABLE, 5)
	var mot: Dictionary = _row(CharGen.MOTIVATION_TABLE, 64)
	var cls: Dictionary = _row(CharGen.CLASS_TABLE, 89)
	# p.26 Revenge and p.27 Explorer are +2 XP each, carried as xp, not a stat.
	assert_int(int(mot.get("xp", 0))).is_equal(2)
	assert_int(int(cls.get("xp", 0))).is_equal(2)
	assert_bool((mot.get("stat_bonus", {}) as Dictionary).has("xp")).is_false()

	var c: Character = Character.new()
	CharGen.apply_table_results_to_character(c, {
		"background_result": bg, "motivation_result": mot, "class_result": cls,
		"resources": {"xp": 4, "bonus_credits": 9}})
	assert_str(c.background).is_equal("GIANT_OVERCROWDED_CITY")
	assert_str(c.motivation).is_equal("REVENGE")
	assert_str(c.character_class).is_equal("EXPLORER")
	assert_int(c.experience).is_equal(4)
	assert_int(c.credits_earned).is_equal(0)


func test_a_recruit_is_rolled_once() -> void:
	var comp = auto_free(CrewTaskComponentScript.new())
	add_child(comp)
	var saw_xp := false
	for i in 40:
		var c = CharGen.create_character({})
		comp._apply_recruit_creation_tables(c)
		var bg_traits: Array = (c.traits as Array).filter(
			func(t: String) -> bool: return t.begins_with("Background: "))
		assert_int(bg_traits.size()).override_failure_message(
			"recruit %d carries %s" % [i, str(bg_traits)]).is_equal(1)
		assert_str(c.background).is_equal(
			BackgroundDataServiceRef.enum_key(str(bg_traits[0]).substr(12)))
		var xp: int = int(c.get_meta("creation_table_results").get("resources", {}).get("xp", 0))
		saw_xp = saw_xp or xp > 0
		assert_int(c.experience).override_failure_message(
			"recruit %d: the tables gave %d XP and it has %d" % [i, xp, c.experience]
		).is_equal(xp)
		assert_int(c.credits_earned).is_equal(0)
	# Premise: at least one recruit rolled an XP row, so the XP check could see a double.
	assert_bool(saw_xp).is_true()


func test_the_creator_matches_a_roll_by_key() -> void:
	var c: Node = CREATOR_SCENE.instantiate()
	add_child(c)
	auto_free(c)
	var spellings: Array = []
	for pair: Array in P25:
		spellings.append([pair[0], pair[1]])
	spellings.append_array([["lower_megacity_class", "LOWER_MEGACITY_CLASS"],
		["bureaucrat", "BUREAUCRAT"], ["primitive_world", "PRIMITIVE_WORLD"]])
	for s: Array in spellings:
		var idx: int = c._background_item_index(s[0])
		assert_int(idx).override_failure_message("'%s' found no row" % s[0]).is_greater(-1)
		assert_int(int(CreatorScript.BACKGROUND_ITEMS[idx][1])) \
			.is_equal(int(GlobalEnums.Background[s[1]]))
	var btn: OptionButton = c.background_options
	assert_int(btn.item_count).is_equal(25)
	for i in btn.item_count:
		assert_str(btn.get_item_text(i)).is_equal(
			BackgroundDataServiceRef.display_name(btn.get_item_id(i)))
	var src: String = FileAccess.get_file_as_string(
		"res://src/core/character/Generation/CharacterCreator.gd")
	assert_bool(src.contains("BACKGROUND_ITEMS, bg_")).override_failure_message(
		"a background is matched by label text again").is_false()
