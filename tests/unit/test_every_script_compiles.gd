extends GdUnitTestSuite
## Every shipped GDScript must actually COMPILE — not merely load.
##
## ⭐ WHY THIS EXISTS. On 2026-09-10 a full regression run reported 18 errors across
## THREE unrelated suites. Every one traced to a single line:
##
##   CrewManagementScreen.gd:171 called _create_character_card() with FIVE arguments
##   against a CampaignScreenBase copy that takes four.
##
## GDScript reports that at PARSE time, so the whole screen failed to compile — the
## screen was DEAD in product, not merely untested. And nothing said so. `load()` on a
## parse-broken GDScript still returns a NON-NULL GDScript object, so the failure only
## surfaces at the first `.new()`, as:
##
##   Invalid call. Nonexistent function 'new' in base 'GDScript'.
##
## which reads like a broken test harness rather than a broken screen, and appeared in
## suites that had nothing to do with crew management.
##
## ⚠ THE EXISTING GUARDS CANNOT SEE THIS CLASS.
##   - `--headless --quit` only validates STARTUP scripts.
##   - `godot --check-only` EXITS 0 even when it prints a parse error.
##   - `lint_multiline_statement_breaks.py` finds edits landing inside a statement,
##     which this was not — the call was well-formed, just wrong in arity.
##   - A text-scanning suite reads the file with FileAccess and never compiles it.
##
## ⚠ IT MUST RUN UNDER gdUnit4, NOT A `--script` PROBE. A bare SceneTree probe does not
## register autoloads, so every script naming one as a bare identifier (TweenFX,
## SceneRouter, GameStateManager, ...) reports `Compile Error: Identifier not found`
## and the run drowns in false positives. That mistake was made and caught while
## diagnosing the defect above.
##
## gdUnit4 v6.0.3.

const ROOTS: Array[String] = ["res://src"]

## Directories whose contents are not product scripts.
const SKIP_DIRS: Array[String] = ["res://src/../addons"]


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			_collect(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func test_every_src_script_compiles() -> void:
	var scripts: Array[String] = []
	for root: String in ROOTS:
		_collect(root, scripts)

	# INSTRUMENT THE PREMISE. A walk that finds nothing does not error — it passes,
	# silently, forever. Measured 2026-09-10: 483 .gd files under src/.
	assert_int(scripts.size()).override_failure_message(
		"the script walk found %d files — it is not reaching src/, so this case "
		% scripts.size() + "would pass vacuously").is_greater(400)

	var broken: Array[String] = []
	for path: String in scripts:
		var res: Resource = load(path)
		if res == null:
			broken.append("%s  (load returned null)" % path)
			continue
		if not (res is GDScript):
			continue
		# THE ACTUAL TEST. A parse-broken GDScript loads fine and reports
		# can_instantiate() == false; that is the only cheap signal there is.
		if not (res as GDScript).can_instantiate():
			broken.append("%s  (parse/compile error)" % path)

	assert_array(broken).override_failure_message(
		"%d script(s) do not compile — each one is DEAD in product, and will surface\n"
		% broken.size()
		+ "elsewhere as \"Nonexistent function 'new' in base 'GDScript'\":\n  "
		+ "\n  ".join(broken)).is_empty()
