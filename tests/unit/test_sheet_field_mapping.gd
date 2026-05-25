extends GdUnitTestSuite
## Tests for the field-coordinate JSON manifests at data/sheets/<book>/.
##
## These manifests are hand-calibrated against the official Modiphius sheet
## PNGs. A silent typo (duplicate field id, rect outside source bounds,
## misspelled source path) renders nothing visible — there's no parser to
## catch it. These tests run schema validation as a CI gate.
##
## Schema contract:
##   - Top-level: sheet_id (str), book (str), source_png (res:// path),
##     source_size [w,h], fields []
##   - Each field: id (unique), type (known), rect [x,y,w,h] within bounds,
##     source (dot-notation, non-empty for non-checkbox), font_size (int>0)

const KNOWN_FIELD_TYPES: Array[String] = [
	"text", "multiline_text", "number", "checkbox", "checkbox_grid",
]

const MANIFEST_PATHS: Array[String] = [
	"res://data/sheets/core/crew_log_fields.json",
	"res://data/sheets/core/encounter_log_fields.json",
	"res://data/sheets/core/world_record_sheet_fields.json",
]


# ============================================================================
# Per-manifest schema validation
# ============================================================================

func test_all_manifests_parse_as_valid_json() -> void:
	for path in MANIFEST_PATHS:
		var data: Dictionary = _load_manifest(path)
		assert_bool(data.is_empty()).is_false() \
			.override_failure_message("Manifest %s failed to parse or is empty" % path)


func test_all_manifests_have_required_top_level_keys() -> void:
	for path in MANIFEST_PATHS:
		var data: Dictionary = _load_manifest(path)
		assert_bool(data.has("sheet_id")).is_true() \
			.override_failure_message("%s missing 'sheet_id'" % path)
		assert_bool(data.has("book")).is_true() \
			.override_failure_message("%s missing 'book'" % path)
		assert_bool(data.has("source_png")).is_true() \
			.override_failure_message("%s missing 'source_png'" % path)
		assert_bool(data.has("source_size")).is_true() \
			.override_failure_message("%s missing 'source_size'" % path)
		assert_bool(data.has("fields")).is_true() \
			.override_failure_message("%s missing 'fields'" % path)


func test_all_manifest_source_pngs_exist() -> void:
	# A missing PNG renders a blank background — the silent-fail trap that
	# motivated the asset-pipeline SOP. Catch it here.
	for path in MANIFEST_PATHS:
		var data: Dictionary = _load_manifest(path)
		var png_path: String = str(data.get("source_png", ""))
		assert_bool(ResourceLoader.exists(png_path)).is_true() \
			.override_failure_message(
				"%s references missing PNG: %s" % [path, png_path])


func test_all_field_ids_are_unique_within_a_manifest() -> void:
	for path in MANIFEST_PATHS:
		var data: Dictionary = _load_manifest(path)
		var fields: Array = data.get("fields", [])
		var seen_ids: Dictionary = {}
		var duplicates: Array[String] = []
		for raw_field in fields:
			if not raw_field is Dictionary:
				continue
			var field: Dictionary = raw_field
			var fid: String = str(field.get("id", ""))
			if fid.is_empty():
				continue
			if seen_ids.has(fid):
				duplicates.append(fid)
			seen_ids[fid] = true
		assert_int(duplicates.size()).is_equal(0) \
			.override_failure_message(
				"%s has duplicate field ids: %s" % [path, str(duplicates)])


func test_all_field_types_are_known() -> void:
	for path in MANIFEST_PATHS:
		var data: Dictionary = _load_manifest(path)
		var fields: Array = data.get("fields", [])
		var unknown_types: Array[String] = []
		for raw_field in fields:
			if not raw_field is Dictionary:
				continue
			var field: Dictionary = raw_field
			var ftype: String = str(field.get("type", ""))
			if not (ftype in KNOWN_FIELD_TYPES):
				unknown_types.append(
					"%s (id=%s)" % [ftype, str(field.get("id", "?"))])
		assert_int(unknown_types.size()).is_equal(0) \
			.override_failure_message(
				"%s has unknown field types: %s. Allowed: %s" \
					% [path, str(unknown_types), str(KNOWN_FIELD_TYPES)])


func test_all_field_rects_are_within_source_bounds() -> void:
	for path in MANIFEST_PATHS:
		var data: Dictionary = _load_manifest(path)
		var src_size_arr: Array = data.get("source_size", [0, 0])
		var src_w: int = int(src_size_arr[0])
		var src_h: int = int(src_size_arr[1])
		assert_int(src_w).is_greater(0) \
			.override_failure_message("%s has zero-width source_size" % path)
		assert_int(src_h).is_greater(0) \
			.override_failure_message("%s has zero-height source_size" % path)
		var fields: Array = data.get("fields", [])
		var out_of_bounds: Array[String] = []
		for raw_field in fields:
			if not raw_field is Dictionary:
				continue
			var field: Dictionary = raw_field
			var rect_arr: Array = field.get("rect", [])
			if rect_arr.size() < 4:
				out_of_bounds.append(
					"%s (rect has %d elements, need 4)" \
						% [str(field.get("id", "?")), rect_arr.size()])
				continue
			var x: int = int(rect_arr[0])
			var y: int = int(rect_arr[1])
			var w: int = int(rect_arr[2])
			var h: int = int(rect_arr[3])
			if x < 0 or y < 0 or x + w > src_w or y + h > src_h:
				out_of_bounds.append(
					"%s rect [%d,%d,%d,%d] outside %dx%d" \
						% [str(field.get("id", "?")), x, y, w, h, src_w, src_h])
		assert_int(out_of_bounds.size()).is_equal(0) \
			.override_failure_message(
				"%s field rects out of bounds: %s" \
					% [path, str(out_of_bounds)])


func test_non_checkbox_fields_have_non_empty_source() -> void:
	# Text/number/multiline fields need a source path to resolve data from.
	# Checkboxes can legitimately have no source (always-off placeholder).
	for path in MANIFEST_PATHS:
		var data: Dictionary = _load_manifest(path)
		var fields: Array = data.get("fields", [])
		var missing_source: Array[String] = []
		for raw_field in fields:
			if not raw_field is Dictionary:
				continue
			var field: Dictionary = raw_field
			var ftype: String = str(field.get("type", ""))
			if ftype == "checkbox" or ftype == "checkbox_grid":
				continue
			var source: String = str(field.get("source", ""))
			if source.is_empty():
				missing_source.append(str(field.get("id", "?")))
		assert_int(missing_source.size()).is_equal(0) \
			.override_failure_message(
				"%s non-checkbox fields missing 'source': %s" \
					% [path, str(missing_source)])


# ============================================================================
# Helpers
# ============================================================================

func _load_manifest(path: String) -> Dictionary:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary
