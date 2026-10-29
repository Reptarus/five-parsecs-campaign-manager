## Bug Hunt consumer census -- the 5PFH foundation, applied to Bug Hunt.
##
## The precedent is `tests/unit/test_final_partial_rows.gd`, whose
## `test_every_world_trait_accessor_has_a_live_consumer` found eleven byte-faithful
## `WorldTraitEffects` accessors with ZERO callers. That is this project's single most
## common defect shape: correct code, correct data, no call site. A key census is the
## only check that finds the whole class in one pass, because nothing errors -- a
## `.get(key, default)` on a key no producer writes is a silent default, and a resolver
## nobody calls is simply never observed.
##
## TWO CENSUSES LIVE HERE.
##
##   1. Every PUBLIC method of the two Sprint 1 modules must have an external caller.
##      Discovered by parsing the module, not listed by hand -- a hand-written list
##      stops covering a module the moment someone adds a method to it.
##
##   2. Every SECTION-LEVEL key of `data/bug_hunt/*.json` must have a reader, or an
##      allowlist row saying why not.
##
## THREE DECISIONS ARE WORTH STATING, BECAUSE EACH ONE IS THE HONESTY OF THE CENSUS.
##
## (a) COMMENTS ARE STRIPPED AND STRING LITERALS ARE KEPT. That is the inverse of most
##     scans in this repo. A JSON key name reaches the code as a STRING, and it is the
##     docblock that lies -- every one of these keys is named in some comment somewhere,
##     including several that name a key precisely to record that nothing reads it.
##     `lint_orphan_assets.py` learned this the expensive way (2026-09-04): it built its
##     reachability graph from raw source and counted a file's own obituary as a
##     reference, so eleven genuine orphans read as reachable. Comments are stripped
##     with a regex that matches STRING LITERALS FIRST, so a trailing comment goes and
##     a `"#ff9a52"` colour literal survives (the shape lint_orphan_assets.py uses).
##     ⚠ Until 2026-10-27 only LEADING-`#` lines were dropped, so a trailing comment
##     naming a key counted as its reader (DU-7).
##
## (a2) ONLY A READ COUNTS. A hit is `.get("k"`, `.has("k"`, `["k"]` that is not being
##     assigned to, or `"k" in`. ⚠ Until 2026-10-27 any `"k"` counted, so a dict-literal
##     WRITE (`{"k": v}`) or an assignment (`d["k"] = v`) scored a key as consumed: a
##     producer counted as its own consumer, the exact defect this census exists for.
##
## (b) A HIT IS BUCKETED BY PATH, WITH A NAMED OVERRIDE. Several of these key names --
##     `priority`, `objectives`, `deployment`, `evac`, `weapons` -- are generic enough
##     that a repo-wide grep finds a 5PFH hit and scores a dead Bug Hunt key as live. So
##     a hit only counts from a bug-hunt-named file. That heuristic was WRONG once in
##     fifty-two, which is why the override exists rather than the bucket alone:
##     `enemy_table` is genuinely read, by the shared `CompendiumDataProvider`. A
##     scoping rule with no escape hatch would have reported a false defect, and a
##     false defect costs more than the key it names.
##
## (c) THE ALLOWLIST CARRIES A REASON READ OFF THE DATA, NOT OFF THE KEY'S NAME. A key
##     called `eligibility` could be a prose sentence or a live gate; only its VALUE
##     says which, and the difference decides whether it is an allowlist row or a
##     finding. Every reason below was written after opening the file.
##
## THE ALLOWLIST HAS THREE CATEGORIES AND THE DISTINCTION IS LOAD-BEARING.
##
##   DUPLICATED  The mechanic IS live -- and the code carries its own literal copy of
##               the value instead of reading this key. Measured: all six match the data
##               today, so this is drift risk rather than a live defect. It is NOT
##               "unimplemented", and allowlisting it without saying so would bury the
##               project's own documented trap: "never put a mechanic's numbers in a UI
##               literal -- render the reference from the SAME data the mechanic reads."
##   PAYLOAD     Battle payload (Compendium pp.190-201), explicitly out of Sprint 1 by
##               the plan's own scope boundary. Open in the parity audit, not cut.
##   PROSE       An instruction to the player or a restatement of a convention, with no
##               separable value for code to read.
##
## A stale row -- listed here but now read, or listed here but no longer in the data --
## FAILS. An allowlist that cannot rot is the only kind worth having; the dead-guard
## lint prints stale entries for exactly this reason.

extends GdUnitTestSuite

const SRC_ROOT := "res://src"
const DATA_DIR := "res://data/bug_hunt"

const RESOLVER_PATH := "res://src/core/campaign/BugHuntPostBattleResolver.gd"
const NORMALIZER_PATH := "res://src/core/battle/BugHuntBattleResultNormalizer.gd"

## Keys whose reader is deliberately NOT a bug-hunt-named file. One entry, measured.
## CompendiumDataProvider registers the key as `"json_key": "<key>"` and resolves it
## with `cat.get("json_key", "")` (:250), so for a named reader that registration form
## counts as the read. It is accepted HERE only, never in the general census.
const NAMED_READERS := {
	"bug_hunt_enemies.json::enemy_table":
		"res://src/core/compendium/CompendiumDataProvider.gd",
}

## "<file>.json::<section key>" -> why nothing reads it. Read off the data, 2026-09-20.
const ALLOWLIST := {
	# --- DUPLICATED: the mechanic is live, from a literal that copies this key ---
	"bug_hunt_character_creation.json::standard_equipment":
		"DUPLICATED. BugHuntCharacterGeneration.gd:150 writes the literal" +
		" [\"service_pistol\", \"trooper_armor\"], which matches this key exactly.",
	"bug_hunt_character_creation.json::combat_operation_commendation":
		"DUPLICATED. _check_commendation() (BugHuntCharacterGeneration.gd:311) hardcodes" +
		" 2D6, trigger 6, +1 XP and +1 Reputation -- every value this key declares.",
	# (2026-10-27) `loadout`, `support_points_rule` and `free_fire_team` left this list:
	# BugHuntMissionPanel now builds the weapon choices from `loadout`, prints the book's
	# support rule from data, and labels the free Fire Team from both support keys.
	"bug_hunt_special_assignments.json::eligibility":
		"DUPLICATED. SpecialAssignmentsPanel.gd:129/:139 reads sick_bay directly and" +
		" :173-187 filters per assignment, so the gate this key describes is enforced.",

	# --- PAYLOAD: battle payload, out of Sprint 1 by the plan's scope boundary ---
	"bug_hunt_alien_leaders.json::detection_rule":
		"PAYLOAD (pp.190-201). Pack-leader detection, 3xD12. The whole file has zero" +
		" loaders repo-wide; nothing in Sprint 1 touches it.",
	"bug_hunt_alien_leaders.json::availability":
		"PAYLOAD. 'Not available in the first two missions' -- gates the same unloaded file.",
	"bug_hunt_alien_leaders.json::leaders":
		"PAYLOAD. The six-row D6 pack-leader table itself. Zero loaders repo-wide.",
	"bug_hunt_alien_subtypes.json::subtypes":
		"PAYLOAD. The six-row D6 subtype table (Spitters and the rest). Zero loaders" +
		" repo-wide -- the enemy-variant generator is listed as Not in Sprint 1.",
	# (2026-10-28) `initial_contacts` and `deployment` left this list, and `setup_steps`
	# left PROSE below: BugHuntBattleGuide.setup_checklist() reads all three into the
	# Bug Hunt pre-battle checklist, which had been the Core Rules one.
	# (2026-10-28) `weapon_traits` left this list: BugHuntReferenceText prints each
	# weapon's traits on the Equipment and Mission steps from these definitions.

	# --- PROSE: an instruction, with no separable value for code to read ---
	"bug_hunt_movie_magic.json::usage_rule":
		"PROSE. 'Once per campaign' -- the enforcement lives with the spend, not here.",
	"bug_hunt_regiment_names.json::generation_rule":
		"PROSE. Restates the [number]/[color] substitution convention that" +
		" BugHuntCharacterGeneration already implements over title_part_1/2 and" +
		" uniform_color, all three of which ARE read.",
}


# ---------------------------------------------------------------- shared helpers

var _comment_re: RegEx = null


func _code_only(text: String) -> String:
	## Drop every `#` comment, leading or trailing, and keep string literals (note (a)).
	## Strings are matched FIRST, so a `#` inside one never starts a comment.
	if _comment_re == null:
		_comment_re = RegEx.create_from_string(
			"\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'|#[^\\n]*")
	var out := ""
	var last := 0
	for m: RegExMatch in _comment_re.search_all(text):
		out += text.substr(last, m.get_start() - last)
		if not m.get_string().begins_with("#"):
			out += m.get_string()
		last = m.get_end()
	return out + text.substr(last)


## A named reader may read through CompendiumDataProvider's `json_key` registration.
func _named_reader_reads(code: String, key: String) -> bool:
	return _reads_key(code, key) or code.contains("\"json_key\": \"%s\"" % key)


## Note (a2): only a READ of the key counts. Keys are JSON identifiers, so no escaping.
func _reads_key(code: String, key: String) -> bool:
	var re := RegEx.create_from_string(
		("(?:\\.(?:get|has|get_or_add)\\(\\s*|\\[\\s*)\"%s\"(?!\\s*\\]\\s*=[^=])"
			+ "|\"%s\"\\s+(?:not\\s+)?in\\b") % [key, key])
	return re.search(code) != null


func _gd_files(root: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := "%s/%s" % [root, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_gd_files(full, into)
		elif entry.ends_with(".gd"):
			into.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _src_index() -> Dictionary:
	## path -> comment-stripped source, for every .gd under res://src.
	var paths: PackedStringArray = []
	_gd_files(SRC_ROOT, paths)
	var index: Dictionary = {}
	for p: String in paths:
		index[p] = _code_only(_read(p))
	return index


func _public_methods(path: String) -> PackedStringArray:
	## Discovered, never listed: `func name(` / `static func name(` at column 0, with a
	## lowercase initial (so `_private` is excluded by construction). `_init` cannot
	## match that rule, so it needs no special case.
	var found: PackedStringArray = []
	for line in _code_only(_read(path)).split("\n"):
		var decl := ""
		if line.begins_with("func "):
			decl = line.substr(5)
		elif line.begins_with("static func "):
			decl = line.substr(12)
		else:
			continue
		var paren := decl.find("(")
		if paren <= 0:
			continue
		var name := decl.substr(0, paren).strip_edges()
		if name.is_empty() or name.begins_with("_"):
			continue
		if not found.has(name):
			found.append(name)
	return found


# ---------------------------------------------------------------- premise instruments

func test_the_method_scan_finds_the_surface_it_is_meant_to_police() -> void:
	## Without this, a regex that silently stops matching turns the census below into a
	## loop over an empty array -- which PASSES, and reports nothing forever.
	var resolver := _public_methods(RESOLVER_PATH)
	var normalizer := _public_methods(NORMALIZER_PATH)

	assert_array(resolver).is_not_empty()
	assert_array(normalizer).is_not_empty()
	assert_array(resolver).contains(["resolve", "apply_choices"])
	assert_array(normalizer).contains(["normalize"])

	# The surface is deliberately tiny -- everything else on both modules is private.
	# If this grows, the census below starts policing the new method automatically, and
	# this assertion is the reminder to check that was intended.
	assert_int(resolver.size()).is_equal(2)
	assert_int(normalizer.size()).is_equal(1)


func test_the_source_index_and_the_data_directory_are_both_populated() -> void:
	## Both censuses below iterate what these two produce. An empty walk is a vacuous
	## pass, and a vacuous pass is indistinguishable from a clean one.
	var index := _src_index()
	assert_int(index.size()).is_greater(400)

	var files := _bug_hunt_data_files()
	assert_int(files.size()).is_equal(15)

	# Comment stripping must remove comments and KEEP strings, or note (a) is not true
	# of the code that implements it. Proven on a line that is both.
	var probe := "# \"decoy_key\" named only in a comment\nvar x := \"kept_key\"\n" \
		+ "var y := 1  # \"trailing_key\" in a trailing comment\nvar c := \"#ff9a52\"\n"
	var stripped := _code_only(probe)
	assert_str(stripped).not_contains("decoy_key")
	assert_str(stripped).contains("kept_key")
	assert_str(stripped).not_contains("trailing_key")
	assert_str(stripped).contains("\"#ff9a52\"")

	# Note (a2): reads count, writes do not.
	assert_bool(_reads_key("x = d.get(\"k\", 0)", "k")).is_true()
	assert_bool(_reads_key("if d.has(\"k\"):", "k")).is_true()
	assert_bool(_reads_key("x = d[\"k\"]", "k")).is_true()
	assert_bool(_reads_key("if d[\"k\"] == 1:", "k")).is_true()
	assert_bool(_reads_key("if \"k\" in d:", "k")).is_true()
	assert_bool(_reads_key("return {\"k\": 1}", "k")).is_false()
	assert_bool(_reads_key("d[\"k\"] = 1", "k")).is_false()
	assert_bool(_reads_key("x = d.get(\"kk\", 0)", "k")).is_false()


func _bug_hunt_data_files() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


# ---------------------------------------------------------------- census 1: methods

func test_every_public_method_of_the_sprint_modules_has_an_external_caller() -> void:
	## The `test_every_world_trait_accessor_has_a_live_consumer` shape, discovered
	## rather than listed.
	##
	## A caller is external only if it is a DIFFERENT file that also references the
	## module by path. Requiring the path reference is what keeps `normalize(` from
	## matching the twelve 5PFH callers of the OTHER normalizer -- a bare name grep
	## would score this green on somebody else's call site.
	var index := _src_index()

	for module_path: String in [RESOLVER_PATH, NORMALIZER_PATH]:
		var importers: PackedStringArray = []
		for path: String in index.keys():
			if path == module_path:
				continue
			if str(index[path]).contains(module_path):
				importers.append(path)

		assert_array(importers) \
			.override_failure_message(
				"No file outside %s references it by path, so nothing can call it."
				% module_path) \
			.is_not_empty()

		for method: String in _public_methods(module_path):
			var callers: PackedStringArray = []
			for path: String in importers:
				if str(index[path]).contains("%s(" % method):
					callers.append(path)
			assert_array(callers) \
				.override_failure_message(
					("%s.%s() has NO external caller. Either wire it, or delete it -- " +
					 "a correct zero-caller function is this project's most common " +
					 "defect, and it reads as a finished feature.")
					% [module_path.get_file(), method]) \
				.is_not_empty()


# ---------------------------------------------------------------- census 2: data keys

func _section_keys(file_name: String) -> PackedStringArray:
	var parsed: Variant = JSON.parse_string(_read("%s/%s" % [DATA_DIR, file_name]))
	var out: PackedStringArray = []
	if parsed is not Dictionary:
		return out
	for k: String in (parsed as Dictionary).keys():
		# `_source` and `_provenance_warning` are provenance, not content; `description`
		# is prose on every file by convention.
		if k.begins_with("_") or k == "description":
			continue
		out.append(k)
	return out


func _reader_paths(key: String, index: Dictionary) -> PackedStringArray:
	var hits: PackedStringArray = []
	for path: String in index.keys():
		if not _reads_key(str(index[path]), key):
			continue
		if path.to_lower().contains("bug_hunt") or path.to_lower().contains("bughunt"):
			hits.append(path)
	return hits


func test_every_bug_hunt_data_section_key_has_a_reader_or_a_stated_reason() -> void:
	var index := _src_index()
	var unread: PackedStringArray = []

	for file_name: String in _bug_hunt_data_files():
		for key: String in _section_keys(file_name):
			var row := "%s::%s" % [file_name, key]
			if not _reader_paths(key, index).is_empty():
				continue
			var override: String = str(NAMED_READERS.get(row, ""))
			if not override.is_empty() \
					and _named_reader_reads(str(index.get(override, "")), key):
				continue
			if ALLOWLIST.has(row):
				continue
			unread.append(row)

	assert_array(unread) \
		.override_failure_message(
			("These data/bug_hunt section keys have no reader and no allowlist row:\n" +
			 "  %s\n" +
			 "Each is either a rule nobody applies, or a key whose reason belongs in " +
			 "ALLOWLIST above -- written after opening the file, never guessed from " +
			 "the key's name.") % "\n  ".join(unread)) \
		.is_empty()


func test_the_allowlist_has_no_stale_rows() -> void:
	## An allowlist that cannot rot is the only kind worth having. Two ways to rot:
	## the key gained a reader (so the row now hides a live consumer from the census),
	## or the key left the data (so the row describes nothing).
	var index := _src_index()
	var now_read: PackedStringArray = []
	var gone: PackedStringArray = []

	for row: String in ALLOWLIST.keys():
		var parts := row.split("::")
		assert_int(parts.size()).is_equal(2)
		var file_name := parts[0]
		var key := parts[1]

		if not _section_keys(file_name).has(key):
			gone.append(row)
			continue
		if not _reader_paths(key, index).is_empty():
			now_read.append(row)

	assert_array(now_read) \
		.override_failure_message(
			("These allowlist rows are STALE -- the key now HAS a bug-hunt reader, so " +
			 "the row is hiding a live consumer:\n  %s\nDelete the row.")
			% "\n  ".join(now_read)) \
		.is_empty()

	assert_array(gone) \
		.override_failure_message(
			("These allowlist rows name a key that is no longer in the data:\n  %s\n" +
			 "Delete the row -- it documents nothing, and it will outlive anyone who " +
			 "remembers what it meant.") % "\n  ".join(gone)) \
		.is_empty()


func test_the_named_reader_override_is_not_load_bearing_by_accident() -> void:
	## The override exists for ONE measured case. It is the census's escape hatch, and
	## an escape hatch nobody watches becomes the place defects go to hide -- so each
	## entry must still be true: the file exists, and it really does read the key.
	var index := _src_index()
	for row: String in NAMED_READERS.keys():
		var parts := row.split("::")
		var key := parts[1]
		var reader: String = str(NAMED_READERS[row])

		assert_bool(index.has(reader)) \
			.override_failure_message("Named reader %s does not exist." % reader) \
			.is_true()
		assert_bool(_named_reader_reads(str(index[reader]), key)) \
			.override_failure_message(
				"Named reader %s no longer reads \"%s\" -- the override is stale."
				% [reader, key]) \
			.is_true()

		# And the override must still be NEEDED: if a bug-hunt file has started reading
		# the key, the plain bucket covers it and this entry should go.
		assert_array(_reader_paths(key, index)) \
			.override_failure_message(
				("\"%s\" now has a bug-hunt reader, so the %s override is redundant. " +
				 "Delete it -- a rule with an unnecessary exception is read as a rule " +
				 "with exceptions.") % [key, reader.get_file()]) \
			.is_empty()
