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
			wrong.append("%s -> '%s' (JSON should say '%s')" % [id, got, BOOK_NAMES[id]])
	assert_array(wrong).override_failure_message(
		"data/character_species.json disagrees:\n  " + "\n  ".join(wrong)).is_empty()


func test_the_sheet_prints_the_book_name() -> void:
	var wrong: Array[String] = []
	for id: String in BOOK_NAMES:
		var got: String = SheetDataContext._species_display_name(id)
		if got != BOOK_NAMES[id]:
			wrong.append("%s -> '%s' (expected '%s')" % [id, got, BOOK_NAMES[id]])
	assert_array(wrong).override_failure_message(
		"sheet species names:\n  " + "\n  ".join(wrong)).is_empty()


func test_the_dashboard_crew_pill_prints_the_book_name() -> void:
	var dash: Node = auto_free(DashboardScript.new())
	var wrong: Array[String] = []
	for id: String in BOOK_NAMES:
		# How a post-migration save actually looks: species_id is the id.
		var got: String = dash._species_to_display("Unknown", id)
		if got != BOOK_NAMES[id]:
			wrong.append("%s -> '%s' (expected '%s')" % [id, got, BOOK_NAMES[id]])
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


# ============================================================================
# T11-31 — ONE implementation, shared by every surface
# ============================================================================
#
# THE DEFECT (device, deploy #19). Manage Crew printed raw enum keys — "KERIN",
# "HUMAN", "FERAL", "BOUNTY_HUNTER" — while the Campaign Dashboard, one tap away,
# printed "K'Erin" and "Human" correctly for the same crew member. There were three
# implementations of "the species' display name" and they could not agree, because
# agreeing was nobody's job:
#
#   CampaignDashboard._species_to_display()        correct
#   SheetDataContext._species_display_name()       correct on the id path only
#   CrewManagementScreen._format_origin_display()  returned an underscore-free key
#                                                  VERBATIM, so "KERIN" printed
#
# All three now delegate to SpeciesDataService.display_name(). The cases below
# assert the three surfaces return the IDENTICAL string for every shipped species,
# which is a stronger claim than "each one is right today" — it is the one that
# stays true when a 29th species is added.

const CrewScreenScript := preload("res://src/ui/screens/crew/CrewManagementScreen.gd")


func test_all_three_surfaces_agree_for_every_shipped_species() -> void:
	var species: Array[Dictionary] = SpeciesDataService.get_all_species()
	assert_int(species.size()).override_failure_message(
		"No species loaded — this case would pass vacuously."
	).is_greater(20)

	var dash = auto_free(DashboardScript.new())
	var crew = auto_free(CrewScreenScript.new())

	for entry: Dictionary in species:
		var sid: String = str(entry.get("id", ""))
		var book: String = str(entry.get("name", ""))
		if sid.is_empty() or book.is_empty():
			continue

		assert_str(SpeciesDataService.display_name(sid, sid)).override_failure_message(
			"SSOT returned the wrong name for '%s'." % sid
		).is_equal(book)
		assert_str(SheetDataContext._species_display_name(sid)).override_failure_message(
			"The printable sheet disagrees with the book for '%s'." % sid
		).is_equal(book)
		assert_str(dash._species_to_display(sid, sid)).override_failure_message(
			"The dashboard disagrees with the book for '%s'." % sid
		).is_equal(book)
		# The crew screen receives the stored value, usually with no separate id.
		assert_str(crew._format_origin_display(sid)).override_failure_message(
			"Manage Crew disagrees with the book for '%s'. This is the finding: it "
			% sid + "used to return the raw key untouched."
		).is_equal(book)


## The exact strings the device walk showed. Named individually so a failure says
## which one came back, not just "a species".
func test_manage_crew_prints_the_book_name_for_the_stored_enum_key() -> void:
	var crew = auto_free(CrewScreenScript.new())
	for pair: Array in [
		["KERIN", "K'Erin"], ["HUMAN", "Human"], ["FERAL", "Feral"],
		["DE_CONVERTED", "De-converted"], ["GENETIC_UPLIFT", "Genetic Uplift"],
	]:
		assert_str(crew._format_origin_display(pair[0])).override_failure_message(
			"Manage Crew rendered '%s' as '%s'; the book prints '%s'."
			% [pair[0], crew._format_origin_display(pair[0]), pair[1]]
		).is_equal(pair[1])


## The class column had the same shape of defect: a stored String key returned
## verbatim. "Bounty Hunter" is the Core Rules p.27 spelling.
func test_manage_crew_prints_the_book_class_name() -> void:
	var crew = auto_free(CrewScreenScript.new())
	assert_str(crew._resolve_class_name("BOUNTY_HUNTER")).is_equal("Bounty Hunter")
	assert_str(crew._resolve_class_name("bounty_hunter")).is_equal("Bounty Hunter")


## The trait-parse fallback on a captain card keys on the exact string "Unknown".
## Returning "" instead would disable it silently, which is why the class resolver
## deliberately keeps that word.
func test_an_unresolvable_class_still_returns_the_sentinel_the_caller_expects() -> void:
	var crew = auto_free(CrewScreenScript.new())
	assert_str(crew._resolve_class_name(null)).is_equal("Unknown")


## A legacy numeric origin is 52% of crew records across the 21 real save files, and
## Godot's JSON parser returns every number as float — so `value is int` would be
## permanently false on exactly the data this branch exists for. Both forms asserted.
func test_a_legacy_numeric_origin_resolves_from_either_numeric_type() -> void:
	# GlobalEnums.Origin: NONE=0, HUMAN=1, ENGINEER=2, FERAL=3, KERIN=4
	assert_str(SpeciesDataService.display_name(4)).is_equal("K'Erin")
	assert_str(SpeciesDataService.display_name(4.0)).override_failure_message(
		"A float origin did not resolve. JSON.parse returns numbers as float, so "
		+ "this is the shape that actually arrives from a save file."
	).is_equal("K'Erin")
	assert_str(SpeciesDataService.display_name(1)).is_equal("Human")

	# ...and Manage Crew must route the numeric form through the same resolver. It
	# used to send it to _resolve_background_name(), i.e. GlobalEnums.Background —
	# the wrong enum entirely, so origin 4 rendered as Background[4].
	var crew = auto_free(CrewScreenScript.new())
	assert_str(crew._format_origin_display(4.0)).override_failure_message(
		"Manage Crew resolved a numeric ORIGIN against the wrong enum."
	).is_equal("K'Erin")


## The fallback word is the caller's choice, not the SSOT's: a crew card has always
## shown "Unknown" for an empty value, while a print form must leave the box blank.
func test_the_empty_fallback_is_the_callers_choice() -> void:
	assert_str(SpeciesDataService.display_name("", "", "Unknown")).is_equal("Unknown")
	assert_str(SpeciesDataService.display_name("", "", "")).is_empty()
	assert_str(SheetDataContext._species_display_name("")).override_failure_message(
		"The printable sheet must leave an unknown species BLANK, never 'Unknown'."
	).is_empty()


## An id that is not a species at all must not be mangled into nonsense.
func test_an_unknown_token_is_formatted_not_mangled() -> void:
	assert_str(SpeciesDataService.display_name("not_a_real_species")) \
		.override_failure_message(
			"capitalize() must take the RAW snake_case token. Replacing the "
			+ "underscores first yields 'Not aA rReal sSpecies'."
		).is_equal("Not A Real Species")
