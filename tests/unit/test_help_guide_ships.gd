extends GdUnitTestSuite

## Pins UX-0: the Help screen shipped EMPTY in every exported build. The guide lived in
## res://docs/user_guide/, every export preset excludes `docs/*`, and a `.md` is a
## non-resource file that ships only through a preset's include_filter (godot-docs
## exporting_projects / troubleshooting). It now lives in res://data/user_guide/.
##
## The desk cannot export, so the first case checks what an export decides: every
## preset's filters, for the guide AND its manifest. The second holds manifest.json equal
## to the folder, because the loader reads the manifest first (a DirAccess scan of res:// is
## recorded as failing in exported builds -- TacticsSpeciesBookLoader), so a chapter added
## without a manifest entry would silently never reach a device. The third is the loader
## end to end. The count on the device itself is the Sprint 8 walk's to take.

const Loader := preload("res://src/ui/help/HelpContentLoader.gd")
const PRESETS := "res://export_presets.cfg"
const MIN_CHAPTERS := 16  # 00_index + 15 chapters, counted 2026-10-27


func _filters(raw: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part: String in raw.split(",", false):
		var f := part.strip_edges()
		if not f.is_empty():
			out.append(f)
	return out


## Export filters are wildcards that DO cross `/`; Godot tests each one against the path
## with and without the res:// prefix.
func _matches_any(rel_path: String, filters: PackedStringArray) -> bool:
	for f: String in filters:
		if rel_path.matchn(f) or ("res://" + rel_path).matchn(f):
			return true
	return false


func test_every_export_preset_ships_the_guide_and_its_manifest() -> void:
	var cfg := ConfigFile.new()
	assert_int(cfg.load(PRESETS)).is_equal(OK)
	var shipped: Array[String] = [
		Loader.GUIDE_PATH.trim_prefix("res://") + "01_getting_started.md",
		Loader.MANIFEST_PATH.trim_prefix("res://"),
	]
	var checked := 0
	for section: String in cfg.get_sections():
		if not (section.begins_with("preset.") and section.count(".") == 1):
			continue
		var preset_name := str(cfg.get_value(section, "name", section))
		var inc := _filters(str(cfg.get_value(section, "include_filter", "")))
		var exc := _filters(str(cfg.get_value(section, "exclude_filter", "")))
		for rel: String in shipped:
			assert_bool(_matches_any(rel, inc)) \
				.override_failure_message("preset '%s' does not include %s -- a non-resource "
					% [preset_name, rel] + "file ships only through include_filter").is_true()
			assert_bool(_matches_any(rel, exc)) \
				.override_failure_message("preset '%s' excludes %s" % [preset_name, rel]) \
				.is_false()
		checked += 1
	# Premise: the sections were found, so the loop above was not vacuous.
	assert_int(checked).override_failure_message("no presets parsed").is_greater_equal(3)


func test_the_manifest_lists_exactly_the_chapters_in_the_folder() -> void:
	var manifest := Loader.read_manifest()
	var on_disk := Loader.scan_chapter_files()
	assert_int(on_disk.size()).is_greater_equal(MIN_CHAPTERS)
	assert_array(manifest).override_failure_message(
		"data/user_guide/manifest.json != the .md files in the folder; a chapter missing "
		+ "from the manifest never reaches an exported build").is_equal(on_disk)


func test_the_loader_reads_every_chapter() -> void:
	var loader: RefCounted = Loader.new()
	var order: Array[String] = loader.get_chapter_order()
	assert_int(order.size()).is_greater_equal(MIN_CHAPTERS)
	assert_int(order.size()).is_equal(Loader.read_manifest().size())
	assert_bool("01_getting_started" in order).is_true()
