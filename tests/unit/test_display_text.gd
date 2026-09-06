extends GdUnitTestSuite
## T11-30/32/33/34 — the value-text defects the tablet walk found on four surfaces.
##
## Each one is trivial in isolation, which is exactly why they had been fixed
## per-screen (or not at all) rather than once. `DisplayText` is the one place they
## live now, for the same reason SpeciesDataService.display_name() exists.
##
## ⚠ These cases LOAD each changed screen script rather than only scanning it. A
## text-scanning test cannot see a file that has stopped parsing — a lesson this
## project has already paid for twice (CheatSheetPanel, and PatronRivalManager
## during this very sprint, where `--headless --quit` reported clean against a file
## with a fatal parse error because it only validates STARTUP scripts).

const DisplayText = preload("res://src/ui/components/common/DisplayText.gd")
const SheetDataContext = preload("res://src/core/export/SheetDataContext.gd")
const JournalScreen = preload("res://src/ui/screens/campaign/CampaignJournalScreen.gd")
const ShipManagerScript = preload("res://src/ui/screens/ships/ShipManager.gd")
const CampaignCoreScript = preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")


# ---------------------------------------------------------------------------
# T11-33 / T11-34 — Godot's JSON parser returns EVERY number as a float
# ---------------------------------------------------------------------------

func test_a_whole_float_prints_without_a_decimal_point() -> void:
	# This is the shape that actually arrives from a save file: `35` was written,
	# `35.0` comes back, and str() printed "/ 35.0" on the ship screen.
	assert_str(DisplayText.number(35.0)).is_equal("35")
	assert_str(DisplayText.number(0.0)).is_equal("0")
	assert_str(DisplayText.number(6)).is_equal("6")
	assert_str(DisplayText.number(-3.0)).is_equal("-3")


## A fractional value is legal (a 2.5 ft table size) and must survive — rounding it
## away would trade a cosmetic bug for a data one.
func test_a_genuine_fraction_is_preserved() -> void:
	assert_str(DisplayText.number(2.5)).is_equal("2.5")


func test_a_non_number_is_passed_through() -> void:
	assert_str(DisplayText.number("n/a")).is_equal("n/a")


func test_credits_are_pluralised() -> void:
	assert_str(DisplayText.pluralize(1, "credit")).is_equal("1 credit")
	assert_str(DisplayText.pluralize(1.0, "credit")).is_equal("1 credit")
	assert_str(DisplayText.pluralize(3.0, "credit")).is_equal("3 credits")
	assert_str(DisplayText.pluralize(0, "credit")).is_equal("0 credits")


# ---------------------------------------------------------------------------
# T11-30 — snake_case encounter categories printed verbatim
# ---------------------------------------------------------------------------

func test_a_snake_case_category_becomes_title_case() -> void:
	assert_str(DisplayText.title_case("interested_parties")) \
		.is_equal("Interested Parties")
	assert_str(DisplayText.title_case("roving_threats")).is_equal("Roving Threats")
	assert_str(DisplayText.title_case("criminal_elements")) \
		.is_equal("Criminal Elements")


## A value that is ALREADY spaced prose came from a data file that owns its own
## spelling. Reformatting it is how "Genetic Uplift" became "GeneticUplift"
## elsewhere, so it is handed back untouched.
func test_an_already_spaced_name_is_not_reformatted() -> void:
	assert_str(DisplayText.title_case("Feral Jackals")).is_equal("Feral Jackals")
	assert_str(DisplayText.title_case("K'Erin")).is_equal("K'Erin")


func test_the_encounter_log_prints_a_title_cased_category() -> void:
	var journal: Array = [{
		"type": "battle",
		"stats": {"enemy_category": "interested_parties"},
	}]
	var built: Dictionary = SheetDataContext._build_journal(journal)
	assert_str(str(built["last_battle"]["encounter_type"])).override_failure_message(
		"The Encounter Log's 'Encounter Type' box printed the raw storage token."
	).is_equal("Interested Parties")


func test_join_parts_drops_the_blanks() -> void:
	assert_str(DisplayText.join_parts(["Gangers", "", "since turn 6"])) \
		.override_failure_message(
			"An absent fact must not leave a dangling separator."
		).is_equal("Gangers · since turn 6")
	assert_str(DisplayText.join_parts([])).is_empty()


# ---------------------------------------------------------------------------
# T11-32 — the journal named crew by raw ID
# ---------------------------------------------------------------------------

func test_the_journal_resolves_a_crew_id_to_a_name() -> void:
	var prior = GameState.current_campaign
	var campaign = CampaignCoreScript.new()
	campaign.from_dictionary({
		"campaign_id": "jn_t",
		"crew": {"members": [
			{"character_id": "crew_1758", "character_name": "Bryn Ito"},
		]},
	})
	GameState.current_campaign = campaign

	var screen = auto_free(JournalScreen.new())
	assert_str(screen._crew_name_for_id("crew_1758")).override_failure_message(
		"The journal still shows the raw crew ID on the Characters line."
	).is_equal("Bryn Ito")

	# An entry may legitimately name a character who has since died or left. The ID
	# is a true record of who it was, so it is the fallback rather than a placeholder.
	assert_str(screen._crew_name_for_id("crew_gone")).is_equal("crew_gone")
	assert_str(screen._crew_name_for_id("")).is_empty()

	GameState.current_campaign = prior


## With no campaign loaded the resolver must return the ID, not error — the journal
## is reachable from the main menu.
func test_the_journal_resolver_is_safe_with_no_campaign() -> void:
	var prior = GameState.current_campaign
	GameState.current_campaign = null
	var screen = auto_free(JournalScreen.new())
	assert_str(screen._crew_name_for_id("crew_1")).is_equal("crew_1")
	GameState.current_campaign = prior


# ---------------------------------------------------------------------------
# The scripts still LOAD — see the docblock
# ---------------------------------------------------------------------------

func test_every_changed_screen_still_instantiates() -> void:
	for pair: Array in [
		["CampaignJournalScreen", JournalScreen],
		["ShipManagerUI", ShipManagerScript],
	]:
		var inst = pair[1].new()
		assert_object(inst).override_failure_message(
			"%s failed to instantiate — the script does not parse. A source-scan "
			% pair[0] + "test cannot see this, and `--headless --quit` does not "
			+ "catch it either: it only validates STARTUP scripts."
		).is_not_null()
		if inst is Node:
			auto_free(inst)


# ---------------------------------------------------------------------------
# T11-34 (second half) — the journal printed the strings raw beside fixed numbers
# ---------------------------------------------------------------------------
#
# Found on deploy #21's DESK pass, by asserting the Details block against the save
# pulled off the tablet instead of a fixture. The sheet had been fixed and the
# journal had not: `number()` corrects a number and returns a String UNCHANGED, so
# one entry rendered `Enemy count: 6` correctly next to `Enemy category:
# interested_parties` and `Notable sight: DOCUMENTATION`.
#
# ⚠ The suite already covered title_case() and the SHEET's encounter_type, and was
# green throughout. Neither touches the journal's own Details block — the surface
# the finding actually named.

func test_a_screaming_snake_token_becomes_sentence_case() -> void:
	# The p.89 Notable Sights are stored this way
	# (data/mission_tables/reward_items.json) and the book prints them in SENTENCE
	# case, which is why title_case() is the wrong transform for them.
	assert_str(DisplayText.sentence_case("DOCUMENTATION")).is_equal("Documentation")
	assert_str(DisplayText.sentence_case("SHINY_BITS")).is_equal("Shiny bits")
	assert_str(DisplayText.sentence_case("PERSON_OF_INTEREST")) \
		.is_equal("Person of interest")


## The generic stats renderer cannot know which key it is holding, so one function
## has to route all three storage shapes correctly.
func test_stat_value_routes_all_three_storage_shapes() -> void:
	# lower_snake -> Title Case (an encounter table, pp.94-103)
	assert_str(DisplayText.stat_value("interested_parties")) \
		.is_equal("Interested Parties")
	# UPPER_SNAKE -> sentence case (a p.89 sight)
	assert_str(DisplayText.stat_value("DOCUMENTATION")).is_equal("Documentation")
	# numbers still go through number() — this half was already fixed
	assert_str(DisplayText.stat_value(6.0)).is_equal("6")
	assert_str(DisplayText.stat_value(2.5)).is_equal("2.5")


## Mixed case means the value owns its spelling. Reformatting these is how
## "Genetic Uplift" became "GeneticUplift" elsewhere, and it would wreck a
## sentence-shaped value like a Notable Sight's effect text.
func test_stat_value_leaves_real_names_and_prose_alone() -> void:
	for owned: String in ["Salvage Team", "Move Through", "Delayed", "K'Erin",
			"Gain 1 Quest Rumor."]:
		assert_str(DisplayText.stat_value(owned)).override_failure_message(
			"stat_value() reformatted '%s', which owns its own spelling." % owned
		).is_equal(owned)
	# A value with no cased letters at all must fall through untouched — the
	# to_upper()/to_lower() round trip is what protects "1-3" and "+0".
	assert_str(DisplayText.stat_value("1-3")).is_equal("1-3")
	assert_str(DisplayText.stat_value("+0")).is_equal("+0")


## ⚠ The helper was never the missing piece on this class — the CALL was (T11-05).
## The pre-fix journal called number() at this exact line, which is precisely why
## its numbers were right and its strings were not, so a test of the helper alone
## stays green through the real defect.
func test_the_journal_details_block_routes_through_stat_value() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://src/ui/screens/campaign/CampaignJournalScreen.gd")
	assert_str(src).override_failure_message(
		"CampaignJournalScreen's Details block no longer calls stat_value(). "
		+ "number() returns a String unchanged, so every storage token in the "
		+ "block prints raw beside correctly-formatted numbers."
	).contains("DisplayTextRef.stat_value(stats[k])")


## Both surfaces must share the sight transform, or they drift again — which is
## the state the finding was filed in.
func test_the_sheet_and_the_journal_share_one_sight_transform() -> void:
	assert_str(FileAccess.get_file_as_string(
		"res://src/core/export/SheetDataContext.gd")).override_failure_message(
		"SheetDataContext._sight_label() has its own copy of the transform again."
	).contains("DisplayTextRef.sentence_case(raw)")
	# And the shared one still produces what the sheet used to produce locally.
	var built: Dictionary = SheetDataContext._build_journal([{
		"type": "battle",
		"stats": {"notable_sight": "DOCUMENTATION",
			"notable_sight_effect": "Gain 1 Quest Rumor."},
	}])
	assert_str(str(built["last_battle"]["notable_sight"])) \
		.is_equal("Documentation — Gain 1 Quest Rumor.")
