extends GdUnitTestSuite
## No script that extends another PROJECT script may declare a `static var`.
##
## Godot 4.6 has a use-after-free in GDScriptLanguage::finish() at process exit
## (godotengine/godot#117975, fixed by PR #117991 for 4.8 and not backported to
## 4.6 or 4.7 as of 2026-10-29). The exit loop walks the script list, and a base
## script loaded just before its subclass is the next node. A subclass whose
## function touches its own static var can hold the last reference, so clearing it
## frees the base and the loop reads freed memory: 0xC0000005 on Windows, or the
## loop stops early and ~190 scripts are reported "still in use at exit".
##
## Measured 2026-10-30. WorldInfoPanel (extends FiveParsecsCampaignPanel, two
## static vars) crashed every process that loaded its scene, and CrewTaskComponent
## (extends WorldPhaseComponent, one static cache) crashed a 3-suite batch. Every
## case passed and gdUnit4 printed "Exit code: 0" first, so only the process rc
## showed it. Both are instance members now. A static var on a script that extends
## a NATIVE class (RefCounted, Node, Resource...) is fine and common here.
##
## Retire this guard once the project is on an engine with the fix.

const SRC_DIR := "res://src"


func _scripts(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_scripts(dir.path_join(sub), out)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _first_match(re: RegEx, text: String) -> String:
	var m := re.search(text)
	return m.get_string(1) if m else ""


func test_no_script_subclass_declares_a_static_var() -> void:
	var paths: Array[String] = []
	_scripts(SRC_DIR, paths)
	var class_re := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var extends_re := RegEx.create_from_string("(?m)^extends\\s+(\"[^\"]+\"|\\w+)")
	var static_re := RegEx.create_from_string("(?m)^static var ")

	var project_classes := {}
	var texts := {}
	for p in paths:
		var t := _read(p)
		texts[p] = t
		var name := _first_match(class_re, t)
		if not name.is_empty():
			project_classes[name] = p
	# Premise: the scan must see the project, or every check below passes vacuously.
	assert_int(project_classes.size()).override_failure_message(
		"premise: found only %d class_name scripts under %s" % [project_classes.size(), SRC_DIR]
	).is_greater(100)
	assert_bool(project_classes.has("FiveParsecsCampaignPanel")).is_true()

	var offenders: Array[String] = []
	for p in paths:
		var t: String = texts[p]
		if static_re.search(t) == null:
			continue
		var base := _first_match(extends_re, t)
		if base.begins_with("\"") or project_classes.has(base):
			offenders.append("%s (extends %s)" % [p, base])
	assert_array(offenders).override_failure_message(
		"These scripts extend a project script AND declare a static var, which crashes "
		+ "Godot 4.6 at exit (godot#117975). Make the var an instance member, or move "
		+ "the cache to a helper that extends a native class:\n" + "\n".join(offenders)
	).is_empty()
