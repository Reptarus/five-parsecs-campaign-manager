extends SceneTree
## Compile EVERY .gd and .tscn under src/ and report anything that fails.
##
## WHY THIS EXISTS: `--headless --quit` only parses what the boot path touches,
## so a screen nobody opens at startup can be completely broken while the build
## reports clean. Not hypothetical — a desktop walk found THREE dead screens
## that 141 passing unit tests and a clean headless run had all missed:
##   Battle Simulator, twice over:
##     Parser Error: Identifier "SPACING_XS" not declared in the current scope
##     Parse Error: Cannot assign "BoxContainer.AlignmentMode" as
##                  "FlowContainer.AlignmentMode"
##   Planetfall Dashboard:
##     Parser Error: Identifier "SaveFileWriterRef" not declared in the
##                   current scope
## In each case a main-menu button hard-broke into the debugger.
##
## RUN (WITHOUT --headless, per the project's tool-script convention):
##   Godot_console.exe --path <project> --script tests/tools/verify_scripts_parse.gd
##
## Exit code 1 if anything DEFINITELY failed, so it can gate a release build.
##
## ── Two buckets, and why ──────────────────────────────────────────────────
## A `--script` SceneTree has NO autoloads registered, so ~40 scripts that name
## GlobalEnums / TweenFX / SceneRouter / GameState fail here for a reason that
## does not exist in a real run. Those are reported separately as NEEDS REVIEW
## rather than being dropped.
##
## They are NOT filtered out. An earlier version tried exactly that — skipping
## any failure whose source mentioned an autoload name — and the filter
## swallowed the real Battle Simulator failure, turning the tool into a false
## all-clear. A tool whose whole job is detection must never hide a positive.
## Both buckets are printed; only the definite bucket sets the exit code.
##
## Running inside the live project instead is not an option: GDScript.reload()
## errors with "Cannot reload script while instances exist" there.

const ROOTS := ["res://src", "res://tests/tools"]

var _checked: int = 0
var _definite: Array[String] = []
var _needs_review: Array[String] = []
var _autoload_names: Array[String] = []

func _init() -> void:
	_collect_autoload_names()
	# TRIED AND REJECTED: standing the autoloads up by hand here (instantiate
	# each project.godot entry under /root/<Name>) to shrink the NEEDS REVIEW
	# bucket. It made things strictly worse — 40 review entries became 60 plus
	# new definite failures — because an autoload's _ready() runs against a bare
	# SceneTree it was never written for and cascades its own errors. The bucket
	# stays; read it.
	for root in ROOTS:
		_walk(root)

	print("")
	print("=== SCRIPT / SCENE PARSE SWEEP ===")
	print("checked: %d" % _checked)

	if not _needs_review.is_empty():
		print("")
		print("NEEDS REVIEW (%d) — these name an autoload, which cannot resolve" \
			% _needs_review.size())
		print("in --script mode. Expected noise, but read the list: a real break")
		print("in one of these files looks identical from here.")
		for f in _needs_review:
			print("  ?     %s" % f)

	if _definite.is_empty():
		print("")
		print("=== %d checked, 0 definite failures ===" % _checked)
		quit(0)
		return

	print("")
	print("DEFINITE FAILURES (%d) — no autoload involved:" % _definite.size())
	for f in _definite:
		print("  FAIL  %s" % f)
	print("=== %d checked, %d DEFINITE failures ===" % [_checked, _definite.size()])
	quit(1)

func _collect_autoload_names() -> void:
	for prop in ProjectSettings.get_property_list():
		var name: String = str(prop.get("name", ""))
		if name.begins_with("autoload/"):
			_autoload_names.append(name.trim_prefix("autoload/"))


func _mentions_autoload(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var src: String = f.get_as_text()
	for autoload_name in _autoload_names:
		if src.contains(autoload_name):
			return true
	return false

func _record(path: String, reason: String) -> void:
	var line: String = "%s  (%s)" % [path, reason]
	if _mentions_autoload(path):
		_needs_review.append(line)
	else:
		_definite.append(line)

func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_walk(full)
		elif entry.ends_with(".gd"):
			_checked += 1
			_check_script(full)
		elif entry.ends_with(".tscn"):
			_checked += 1
			_check_scene(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _check_script(path: String) -> void:
	# NOT a null check on load(): ResourceLoader hands back the GDScript object
	# even when compilation FAILED, so `res != null` reported a clean sweep while
	# the console printed thirty "Failed to load script" errors. reload() returns
	# the actual compile Error, which is the only reliable signal from GDScript.
	var res: Resource = ResourceLoader.load(path, "GDScript",
		ResourceLoader.CACHE_MODE_REUSE)
	var script := res as GDScript
	if script == null:
		_record(path, "failed to load")
		return
	if script.reload() != OK:
		_record(path, "compile error")

func _check_scene(path: String) -> void:
	var packed: Resource = ResourceLoader.load(path, "PackedScene",
		ResourceLoader.CACHE_MODE_REUSE)
	if packed == null:
		_record(path, "scene failed to load")
