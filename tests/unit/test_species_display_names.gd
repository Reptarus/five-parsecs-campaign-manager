extends GdUnitTestSuite
## A species' name must PRINT the way the book prints it, everywhere it appears.
##
## `data/character_species.json` carries a `name` for all 28 species ids and is
## their canonical owner. Two independent display paths were reformatting the id
## instead of reading it, and both got the same three species wrong:
##
##     kerin               "Kerin"           book: K'Erin       (apostrophe)
##     de_converted        "De Converted"    book: De-converted (hyphen, lowercase)
##     primitive_character "Primitive Char…" book: Primitive    (shorter than the id)
##
## The dashboard had a fourth failure mode of its own: on a post-migration save
## `origin` already holds "Genetic Uplift", and `to_pascal_case()` ATE the space,
## producing "GeneticUplift" from a value that was already correct.
##
## These ids are used deliberately — every one of them defeats string formatting,
## so the suite cannot pass by accident if someone "simplifies" the JSON lookup away.

const SheetDataContext := preload("res://src/core/export/SheetDataContext.gd")
const DashboardScript := preload("res://src/ui/screens/campaign/CampaignDashboard.gd")

const BOOK_NAMES := {
	"kerin": "K'Erin",
	"de_converted": "De-converted",
	"primitive_character": "Primitive",
	"genetic_uplift": "Genetic Uplift",
	"human": "Human",
	"soulless": "Soulless",
}


func test_the_species_json_is_still_the_owner_of_these_names() -> void:
	# If the JSON ever stops carrying these, every assertion below is vacuous.
	var wrong: Array[String] = []
	for id: String in BOOK_NAMES:
		var got: String = str(SpeciesDataService.get_species(id).get("name", ""))
		if got != BOOK_NAMES[id]:
			wrong.append("%s -> %r (JSON should say %r)" % [id, got, BOOK_NAMES[id]])
	assert_array(wrong).override_failure_message(
		"data/character_species.json disagrees:\n  " + "\n  ".join(wrong)).is_empty()


func test_the_sheet_prints_the_book_name() -> void:
	var wrong: Array[String] = []
	for id: String in BOOK_NAMES:
		var got: String = SheetDataContext._species_display_name(id)
		if got != BOOK_NAMES[id]:
			wrong.append("%s -> %r (expected %r)" % [id, got, BOOK_NAMES[id]])
	assert_array(wrong).override_failure_message(
		"sheet species names:\n  " + "\n  ".join(wrong)).is_empty()


func test_the_dashboard_crew_pill_prints_the_book_name() -> void:
	var dash: Node = auto_free(DashboardScript.new())
	var wrong: Array[String] = []
	for id: String in BOOK_NAMES:
		# How a post-migration save actually looks: species_id is the id.
		var got: String = dash._species_to_display("Unknown", id)
		if got != BOOK_NAMES[id]:
			wrong.append("%s -> %r (expected %r)" % [id, got, BOOK_NAMES[id]])
	assert_array(wrong).override_failure_message(
		"dashboard species pills:\n  " + "\n  ".join(wrong)).is_empty()


func test_the_dashboard_does_not_mangle_an_already_correct_display_string() -> void:
	# Post-migration saves put "Genetic Uplift" in `origin`. to_pascal_case() used
	# to collapse it to "GeneticUplift" — reformatting a correct value.
	var dash: Node = auto_free(DashboardScript.new())
	assert_str(dash._species_to_display("Genetic Uplift", null)).is_equal("Genetic Uplift")
	assert_str(dash._species_to_display("K'Erin", null)).is_equal("K'Erin")


func test_the_dashboard_still_reads_a_legacy_numeric_origin() -> void:
	# Pre-migration saves store `origin` as a numeric enum, and as a FLOAT
	# (observed on device: origin=7.0). Only the enum path can read that, so the
	# JSON lookup must fall through rather than swallow it.
	var dash: Node = auto_free(DashboardScript.new())
	var got: String = dash._species_to_display(7.0, null)
	assert_str(got).is_not_empty()
	assert_str(got).is_not_equal("Unknown") \
		.override_failure_message("legacy float origin 7.0 no longer resolves to a species")
