## Planetfall consumer census -- the shape of `test_bug_hunt_consumer_census.gd` and
## `test_final_partial_rows.gd::test_every_world_trait_accessor_has_a_live_consumer`,
## applied to the Planetfall rules modules.
##
## Every PUBLIC method of every Planetfall rules module must have a caller in `src/`.
## The modules are DISCOVERED (every `src/core/systems/Planetfall*.gd`, plus the phase
## manager, the campaign core, the battle guide and the result normalizer), so a module
## or a method added later is policed without anyone remembering to list it.
##
## Measured before this suite existed (2026-10-28): 43 public methods with no caller.
## Two were real rules that never reached a screen -- the p.78 colony weapon-trait text
## and the p.151 enemy weapon-trait text -- and are now printed on the equipment screen
## and the battle card. Twenty-two were deleted, among them a campaign validator that
## enforced a 3-10 roster with one of each class, a rule in neither book. What is left is
## the allowlist below, each row with its reason.
##
## WHAT COUNTS AS A CALLER, AND WHY IT IS THIS WIDE.
##
##   * A call inside the module itself (`name(` that is not its own `func name(`).
##   * A call in any other src file that names the module by path or class_name.
##   * A call in ANY Planetfall file (a path under `/planetfall/` or a file named
##     `Planetfall*`). Planetfall wires its systems by duck typing -- the building system
##     calls `application_for_building()` on a research system it was HANDED -- so
##     requiring an import would report live rules as dead.
##   * A quoted `"name"` anywhere in reach, for `call()` / `has_method()` dispatch.
##
## Comments are stripped and string literals kept (the census note (a) in the Bug Hunt
## suite): a docblock that names a function is not a caller of it.
##
## The allowlist cannot rot: a row whose method has gained a caller, or no longer exists,
## FAILS.

extends GdUnitTestSuite

const SRC_ROOT := "res://src"
const SYSTEMS_DIR := "res://src/core/systems"
const EXTRA_MODULES := [
	"res://src/core/campaign/PlanetfallPhaseManager.gd",
	"res://src/game/campaign/PlanetfallCampaignCore.gd",
	"res://src/core/battle/PlanetfallBattleGuide.gd",
	"res://src/core/battle/PlanetfallBattleResultNormalizer.gd",
]

## "<File>.gd::<method>" -> why it has no caller. "*::<method>" covers every module.
const ALLOWLIST := {
	"*::is_loaded":
		"A loader probe each system carries uniformly (true once its JSON parsed). It" +
		" holds no rule, and test_planetfall_colony_crisis.gd asserts through it.",
	"PlanetfallPhaseManager.gd::is_phase_complete":
		"A read-only query of the turn's step ledger. The turn suites assert where the" +
		" damage lands through it (a step that completed, not where the screen ends up).",
	"PlanetfallCampaignCore.gd::artifacts_carried_by":
		"A read-only query of artifacts_found by holder. The artifact suite asserts" +
		" through it; the screens read artifacts_found directly.",
	"PlanetfallCampaignCore.gd::has_artifact":
		"A read-only query of artifacts_found by id. The artifact suites assert through it.",
	"PlanetfallCalamitySystem.gd::get_calamity_count":
		"A read-only count of get_active_calamities(), which the screens call. The" +
		" calamity suite asserts through it.",
}


# ---------------------------------------------------------------- shared helpers

var _comment_re: RegEx = null


func _code_only(text: String) -> String:
	## Drop every `#` comment, leading or trailing; keep string literals. Strings are
	## matched FIRST, so a `#` inside one never starts a comment.
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


func _modules() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(SYSTEMS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.begins_with("Planetfall") \
					and entry.ends_with(".gd"):
				out.append("%s/%s" % [SYSTEMS_DIR, entry])
			entry = dir.get_next()
		dir.list_dir_end()
	for p: String in EXTRA_MODULES:
		out.append(p)
	out.sort()
	return out


func _public_methods(code: String) -> PackedStringArray:
	## `func name(` / `static func name(` at column 0 with a lowercase initial, so
	## `_private` and `_init` are excluded by construction.
	var found: PackedStringArray = []
	var re := RegEx.create_from_string("(?m)^(?:static )?func ([a-z]\\w*)\\(")
	for m: RegExMatch in re.search_all(code):
		if not found.has(m.get_string(1)):
			found.append(m.get_string(1))
	return found


func _is_planetfall_file(path: String) -> bool:
	return path.to_lower().contains("/planetfall/") or path.get_file().begins_with("Planetfall")


func _reach(module_path: String, index: Dictionary) -> String:
	## Every OTHER src file that can call into the module, comment-stripped and joined.
	var names: Array = [module_path]
	var cn := RegEx.create_from_string("(?m)^class_name (\\w+)").search(str(index[module_path]))
	if cn != null:
		names.append(cn.get_string(1))
	var out: Array = []
	for path: String in index.keys():
		if path == module_path:
			continue
		var text: String = index[path]
		var reaches := _is_planetfall_file(path)
		for n: String in names:
			if text.contains(n):
				reaches = true
		if reaches:
			out.append(text)
	return "\n".join(PackedStringArray(out))


func _has_caller(method: String, module_code: String, reach: String) -> bool:
	var re := RegEx.create_from_string(
		"(?<!func )(?<![\\w])%s\\(|\"%s\"" % [method, method])
	return re.search(module_code) != null or re.search(reach) != null


func _dead_methods(index: Dictionary) -> PackedStringArray:
	var dead: PackedStringArray = []
	for module_path: String in _modules():
		var code: String = index.get(module_path, "")
		var reach: String = _reach(module_path, index)
		for method: String in _public_methods(code):
			if not _has_caller(method, code, reach):
				dead.append("%s::%s" % [module_path.get_file(), method])
	return dead


func _allowlisted(entry: String) -> bool:
	return ALLOWLIST.has(entry) or ALLOWLIST.has("*::" + entry.get_slice("::", 1))


# ---------------------------------------------------------------- premise instruments

func test_the_census_finds_the_surface_it_polices() -> void:
	## Without this, a regex that silently stops matching turns the census into a loop
	## over nothing -- which PASSES, and reports nothing forever.
	var modules := _modules()
	assert_int(modules.size()).is_greater_equal(24)
	assert_array(Array(modules)).contains([
		"res://src/core/systems/PlanetfallMap.gd",
		"res://src/core/campaign/PlanetfallPhaseManager.gd",
		"res://src/game/campaign/PlanetfallCampaignCore.gd"])
	var pm := _public_methods(_code_only(_read(EXTRA_MODULES[0])))
	assert_array(Array(pm)).contains(["resolve_enemy_activity", "complete_current_phase"])
	for m in pm:
		assert_bool(str(m).begins_with("_")) \
			.override_failure_message("a private method leaked: %s" % m).is_false()

	# The caller test: a definition is not a call, a comment is not a call, an internal
	# call and a quoted dispatch name both are.
	var dead_module := "func zz_probe() -> void:\n\tpass\n# zz_probe() named in a comment\n"
	assert_bool(_has_caller("zz_probe", _code_only(dead_module), "")).is_false()
	assert_bool(_has_caller("zz_probe", "func zz_probe():\n\tpass\nfunc b():\n\tzz_probe()\n",
		"")).is_true()
	assert_bool(_has_caller("zz_probe", "", "x.call(\"zz_probe\")")).is_true()
	assert_bool(_has_caller("zz_probe", "", "x.not_zz_probe()")).is_false()
	assert_bool(_has_caller("zz_probe", "", "static func zz_probe():")).is_false()

	# Duck typing is in reach: the building system calls this on a research system it
	# was handed, with no import of the research module.
	var index := _src_index()
	assert_int(index.size()).is_greater(400)
	var research := "res://src/core/systems/PlanetfallResearchSystem.gd"
	assert_bool(_has_caller("application_for_building", str(index[research]),
		_reach(research, index))).is_true()


# ---------------------------------------------------------------- the census

func test_every_public_method_of_the_planetfall_rules_modules_has_a_caller() -> void:
	var unexplained: Array = []
	for entry: String in _dead_methods(_src_index()):
		if not _allowlisted(entry):
			unexplained.append(entry)
	assert_array(unexplained) \
		.override_failure_message(("No caller in src/ for: %s. Wire it to the step that " +
			"owns its rule, or delete it -- a correct zero-caller function reads as a " +
			"finished feature. An allowlist row needs a reason read off the code.")
			% [unexplained]) \
		.is_empty()


func test_the_allowlist_has_no_stale_rows() -> void:
	var dead := _dead_methods(_src_index())
	for row: String in ALLOWLIST.keys():
		var method: String = row.get_slice("::", 1)
		var matched := false
		for entry: String in dead:
			if entry == row or (row.begins_with("*::") and entry.ends_with("::" + method)):
				matched = true
		assert_bool(matched) \
			.override_failure_message(("Allowlist row %s matches nothing the census reports" +
				" -- the method gained a caller or was removed. Delete the row.") % row) \
			.is_true()
