extends GdUnitTestSuite
## A primary action button must not LEAD with a glyph the app does not own.
##
## T10-02, measured on a Lenovo TB361FU 2026-09-04: the green confirm button that
## STARTS a battle read "✗ Proceed to Battle" on device. The character was
## U+2694 CROSSED SWORDS. A cmap parse of all four bundled .ttf files shows NONE
## of them contains it, so it is drawn by whatever font the platform supplies —
## and at 16px monochrome two crossed blades are indistinguishable from a cancel
## ✗. The one control in the app whose meaning must never be ambiguous was
## rendering as its own opposite.
##
## The rule is deliberately narrow — LEADING character, PRIMARY buttons only.
## Arrows in "← Back" / "Next →" are fine: they are directional affordances that
## agree with the label, and U+2192 is actually present in Montserrat (unlike
## every pictograph checked). A blanket "no non-ASCII" rule would flag 21
## legitimate uses and would be turned off within a week.
##
## Reads the scene through PackedScene.get_state() rather than scanning the file
## as text. A text scan proves the right words are present, never that the scene
## still LOADS — the trap that let CheatSheetPanel's 14-case suite stay green
## against a GDScript the engine could not parse (Sep 3 2026).

const PRIMARY_VARIATIONS: Array[String] = ["ConfirmButton", "PrimaryButton"]


func _scene_files(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			if not entry.begins_with("."):
				_scene_files(full, out)
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


## Candidate scenes are found by text, then ASSERTED against the parsed resource.
func _primary_buttons() -> Array:
	var files: Array = []
	_scene_files("res://src", files)
	var found: Array = []
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var raw := f.get_as_text()
		f.close()
		var is_candidate := false
		for v in PRIMARY_VARIATIONS:
			if raw.contains('theme_type_variation = &"%s"' % v):
				is_candidate = true
		if not is_candidate:
			continue
		var packed = load(path)
		if not (packed is PackedScene):
			continue
		var st := (packed as PackedScene).get_state()
		for i in st.get_node_count():
			var props: Dictionary = {}
			for p in st.get_node_property_count(i):
				var key := str(st.get_node_property_name(i, p))
				props[key] = st.get_node_property_value(i, p)
			var variation := str(props.get("theme_type_variation", ""))
			if not (variation in PRIMARY_VARIATIONS):
				continue
			found.append({
				"scene": path,
				"node": str(st.get_node_name(i)),
				"text": str(props.get("text", "")),
			})
	return found


## Guards against a vacuous pass: if the scan or the variation names ever drift,
## the suite must go RED rather than quietly assert nothing.
func test_the_scan_actually_finds_the_primary_buttons() -> void:
	var buttons := _primary_buttons()
	assert_int(buttons.size()).is_greater_equal(2)


func test_no_primary_cta_leads_with_a_glyph_the_app_does_not_own() -> void:
	var offenders: Array[String] = []
	for b in _primary_buttons():
		var text := str(b["text"]).strip_edges()
		if text.is_empty():
			continue
		var first := text.unicode_at(0)
		var is_ascii_word := (first >= 65 and first <= 90) \
			or (first >= 97 and first <= 122) \
			or (first >= 48 and first <= 57)
		if not is_ascii_word:
			offenders.append("%s/%s text=%s leads with U+%04X" % [
				str(b["scene"]).get_file(), str(b["node"]), text, first])
	assert_array(offenders).override_failure_message(
		"A primary/confirm button leads with a non-word character. On Android "
		+ "these are drawn by the platform font and can invert the control's "
		+ "meaning (U+2694 read as a cancel cross on Proceed to Battle). "
		+ "Offenders: " + ", ".join(offenders)).is_empty()
