extends GdUnitTestSuite
## Compendium pp.157-160 "Name Generation" — the section has exactly FOUR tables.
##
## `NameGenerationTables.json` carried TWELVE generators. Eight were in neither
## rulebook (Gang, Rival, Faction, Enhanced Ship, Enhanced Planet, Starport,
## Space Station, Sector), and the book's real Corporate PATRON Names Generator
## was absent — a fabricated "Corporate Names Generator" sat in its place sharing
## not one entry with it (book Part 1 opens Interstellar / Agile / Calibrated /
## Synergistic; the fabricated one opened Unity / Stellar / Fringe / Core).
##
## Worse, the fabricated tables were the LIVE ones: CharacterGeneration and
## ContactManager loaded exactly three titles, and all three were fabrications.
## Every corporate patron in every campaign was named off a table that is in no
## rulebook.
##
## Gang and Rival names have no book table at all. They are kept ONLY so those
## NPCs get a readable label, and are tagged `source: APP_FLAVOR` so nobody ever
## cites a page for them.
##
## gdUnit4 v6.0.3 compatible.

const NAME_TABLE_PATH := "res://data/RulesReference/NameGenerationTables.json"

## The four generators the Compendium actually contains, with their pages.
const BOOK_GENERATORS := {
	"World Names Generator": "Compendium p.157",
	"Colony Names Generator": "Compendium p.158",
	"Ship Names Generator": "Compendium p.159",
	"Corporate Patron Names Generator": "Compendium p.160",
}


func _content() -> Array:
	var file := FileAccess.open(NAME_TABLE_PATH, FileAccess.READ)
	assert_object(file).override_failure_message(
		"NameGenerationTables.json is missing").is_not_null()
	var json := JSON.new()
	assert_int(json.parse(file.get_as_text())).is_equal(OK)
	file.close()
	return (json.data as Dictionary).get("NameGenerationTables", {}).get("content", [])


func _by_title(title: String) -> Dictionary:
	for entry in _content():
		if str(entry.get("title", "")) == title:
			return entry
	return {}


func _all_rows(entry: Dictionary) -> Array:
	## Flatten a generator's rows whether it is single-table or two-part.
	var out: Array = []
	if entry.has("table"):
		out.append_array(entry["table"])
	for t in entry.get("tables", []):
		out.append_array(t.get("table", []))
	return out


# ── What may exist at all ───────────────────────────────────────────────────

## Every generator is either one of the book's four, or explicitly tagged as
## app-side flavor. Nothing may sit in this file untagged and unsourced —
## that is exactly how eight invented D100 tables passed as rules.
func test_every_generator_is_sourced_or_tagged_as_flavor() -> void:
	for entry in _content():
		var title: String = str(entry.get("title", ""))
		var source: String = str(entry.get("source", ""))
		assert_str(source).override_failure_message(
			"'%s' has no `source` — tag it with a Compendium page or APP_FLAVOR"
			% title).is_not_empty()
		if BOOK_GENERATORS.has(title):
			assert_str(source).override_failure_message(
				"'%s' cites the wrong page" % title
			).is_equal(BOOK_GENERATORS[title])
		else:
			var msg: String = ("'%s' is not one of the four Compendium generators," % title
				+ " so it MUST be tagged APP_FLAVOR — it cannot claim to be a rule")
			assert_bool(source.begins_with("APP_FLAVOR")).override_failure_message(
				msg).is_true()


## All four of the book's generators are present. Corporate Patron was missing
## entirely while a lookalike answered to a similar name.
func test_all_four_book_generators_are_present() -> void:
	for title in BOOK_GENERATORS:
		assert_bool(not _by_title(title).is_empty()).override_failure_message(
			"the Compendium's '%s' is missing from the data file" % title).is_true()


## The eight fabricated D100 tables are gone.
func test_the_fabricated_generators_are_gone() -> void:
	for title in ["Corporate Names Generator", "Faction Names Generator",
			"Enhanced Ship Names Generator", "Enhanced Planet Names Generator",
			"Starport Names Generator", "Space Station Names Generator",
			"Sector Names Generator"]:
		assert_bool(_by_title(title).is_empty()).override_failure_message(
			"'%s' is in no rulebook and must not be here" % title).is_true()


# ── The tables themselves ───────────────────────────────────────────────────

## Every D100 table is 25 rows of 4, so a uniform pick over rows IS a D100 roll —
## which is what _pick_from_table() does. If a table ever gains unequal ranges,
## that equivalence breaks silently and the distribution goes wrong.
func test_every_table_is_twenty_five_even_rows() -> void:
	for entry in _content():
		var title: String = str(entry.get("title", ""))
		for t in entry.get("tables", [{"name": "table", "table": entry.get("table", [])}]):
			var rows: Array = t.get("table", [])
			if rows.is_empty():
				continue
			assert_int(rows.size()).override_failure_message(
				"%s / %s has %d rows; the book's tables are 25x4"
				% [title, t.get("name", "?"), rows.size()]).is_equal(25)
			for row in rows:
				var parts: PackedStringArray = str(row.get("roll", "")).split("-")
				assert_int(parts.size()).is_equal(2)
				var lo: int = int(parts[0])
				var hi: int = int(parts[1])
				if hi == 0:
					hi = 100
				assert_int(hi - lo).override_failure_message(
					"%s row %s is not a 4-wide band" % [title, row.get("roll", "")]
				).is_equal(3)


## Compendium p.160, verbatim. The example in the book — "A roll of 11 and 47
## means we will be working for Calibrated Acquisitions" — is the check: 11 lands
## on 09-12 and 47 lands on 45-48.
func test_corporate_patron_matches_the_books_worked_example() -> void:
	var entry: Dictionary = _by_title("Corporate Patron Names Generator")
	assert_bool(entry.is_empty()).is_false()
	var tables: Array = entry.get("tables", [])
	assert_int(tables.size()).is_equal(2)

	var part1: Array = tables[0].get("table", [])
	var part2: Array = tables[1].get("table", [])
	assert_str(str(part1[2].get("roll", ""))).is_equal("09-12")
	assert_str(str(part1[2].get("name", ""))).override_failure_message(
		"p.160: a roll of 11 must give 'Calibrated'").is_equal("Calibrated")
	assert_str(str(part2[11].get("roll", ""))).is_equal("45-48")
	assert_str(str(part2[11].get("name", ""))).override_failure_message(
		"p.160: a roll of 47 must give 'Acquisitions'").is_equal("Acquisitions")


## The opening rows, which are what proved the old table was invented.
func test_corporate_patron_opens_with_the_books_entries() -> void:
	var part1: Array = _by_title(
		"Corporate Patron Names Generator").get("tables", [])[0].get("table", [])
	var expected := ["Interstellar", "Agile", "Calibrated", "Synergistic", "Customized"]
	for i in expected.size():
		assert_str(str(part1[i].get("name", ""))).override_failure_message(
			"p.160 Part 1 row %d" % (i + 1)).is_equal(expected[i])


## Compendium p.157's worked example: "43 and 3 would mean we are on the world of
## Gough III" — 43 lands on 41-44.
func test_world_names_matches_the_books_worked_example() -> void:
	var rows: Array = _all_rows(_by_title("World Names Generator"))
	assert_int(rows.size()).is_equal(25)
	assert_str(str(rows[10].get("roll", ""))).is_equal("41-44")
	assert_str(str(rows[10].get("name", ""))).override_failure_message(
		"p.157: a roll of 43 must give 'Gough'").is_equal("Gough")
	assert_str(str(rows[0].get("name", ""))).is_equal("Samsonov")


## The three titles the live loaders look for must all resolve, or a name
## generator silently returns "Unknown" forever.
func test_the_titles_the_live_loaders_request_all_exist() -> void:
	for title in ["Corporate Patron Names Generator", "Gang Names Generator",
			"Rival Names Generator"]:
		var entry: Dictionary = _by_title(title)
		assert_bool(entry.is_empty()).override_failure_message(
			"CharacterGeneration/ContactManager load '%s' by exact title" % title
		).is_false()
		assert_bool(_all_rows(entry).is_empty()).override_failure_message(
			"'%s' resolves but has no rows" % title).is_false()
