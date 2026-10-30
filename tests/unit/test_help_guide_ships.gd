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
const MIN_CHAPTERS := 19  # 00_index + 18 chapters, counted 2026-10-29


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


# ── Context help: every screen a player can reach has a guide entry ────────────────────
#
# data/help_context_map.json is keyed by SceneRouter screen key (plus the campaign turn
# phase keys). A screen with no entry gets no context help, and nothing used to notice:
# the map had no entry for any Planetfall, Tactics or Battle Simulator screen, the
# campaign journal, the editor, the Library or the legal viewer.

const ROUTER := preload("res://src/ui/screens/SceneRouter.gd")
const CONTEXT_MAP_PATH := "res://data/help_context_map.json"

## Router keys that are deliberately NOT required to carry a context entry. A key goes
## here only with a reason a reader can check. Empty today: every router key is a screen
## a player can be on, so every one has an entry. Adding a router key that is only a
## routing alias belongs here, with the reason.
const ROUTER_KEYS_WITHOUT_CONTEXT := {
}

## Context-map keys that are NOT router keys, by exact name, with the reason.
const NON_ROUTER_CONTEXT_KEYS := {
	"victory_progress": "a dashboard card, not a routed scene (its router entry is commented out as unused)",
	"save_load": "the save controls live on the dashboard and main menu; there is no routed save screen",
}

## Context-map key PREFIXES that are not router keys.
const NON_ROUTER_CONTEXT_PREFIXES := {
	"phase_": "CampaignPhaseManager turn phases (STORY, TRAVEL, UPKEEP ...), shown inside the turn controller",
	"campaign_creation_step_": "the seven creation wizard steps, shown inside campaign_creation",
}


func _context_map() -> Dictionary:
	var f := FileAccess.open(CONTEXT_MAP_PATH, FileAccess.READ)
	assert_object(f).override_failure_message("cannot read " + CONTEXT_MAP_PATH).is_not_null()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_bool(parsed is Dictionary).is_true()
	return parsed


func _router_keys() -> Array:
	var keys: Array = (ROUTER.SCENE_PATHS as Dictionary).keys()
	# Premise: the router was read, so the loops below are not vacuous.
	assert_int(keys.size()).is_greater_equal(30)
	assert_bool("main_menu" in keys and "help" in keys).is_true()
	return keys


func test_every_router_screen_has_a_context_entry() -> void:
	var map := _context_map()
	var missing: Array[String] = []
	for key: String in _router_keys():
		if ROUTER_KEYS_WITHOUT_CONTEXT.has(key):
			continue
		if not map.has(key):
			missing.append(key)
	assert_array(missing).override_failure_message(
		"SceneRouter screens with no entry in data/help_context_map.json: %s" % ", ".join(missing)
	).is_empty()


func test_the_exclusion_list_names_real_router_keys_with_reasons() -> void:
	var keys := _router_keys()
	var map := _context_map()
	for key: String in ROUTER_KEYS_WITHOUT_CONTEXT:
		assert_bool(key in keys).override_failure_message(
			"'%s' is excluded but is not a router key" % key).is_true()
		assert_bool(not str(ROUTER_KEYS_WITHOUT_CONTEXT[key]).is_empty()).is_true()
		assert_bool(map.has(key)).override_failure_message(
			"'%s' is excluded but has an entry; delete the exclusion" % key).is_false()
	for key: String in NON_ROUTER_CONTEXT_KEYS:
		assert_bool(key in keys).override_failure_message(
			"'%s' is listed as a non-router key but IS a router key" % key).is_false()
		assert_bool(map.has(key)).override_failure_message(
			"'%s' is listed as a non-router key but is not in the map" % key).is_true()


func test_every_context_key_is_a_screen_or_a_documented_non_screen() -> void:
	var keys := _router_keys()
	var stale: Array[String] = []
	for key: String in _context_map():
		if key in keys or NON_ROUTER_CONTEXT_KEYS.has(key):
			continue
		var prefixed := false
		for prefix: String in NON_ROUTER_CONTEXT_PREFIXES:
			if key.begins_with(prefix):
				prefixed = true
		if not prefixed:
			stale.append(key)
	assert_array(stale).override_failure_message(
		"context-map keys that match no router key and no documented exception (renamed or "
		+ "deleted screen?): %s" % ", ".join(stale)).is_empty()


## Goes through the loader's own lookup, so the chapter id and the section anchor are
## resolved by the code the Help screen uses, not re-derived here.
func test_every_context_entry_resolves_to_a_loaded_chapter_and_section() -> void:
	var loader: RefCounted = Loader.new()
	# get_context_help() resolves "01" to "01_getting_started" through the chapter list and
	# does not load it first: called cold it returns the bare short id.
	loader.ensure_loaded()
	var order: Array[String] = loader.get_chapter_order()
	var map := _context_map()
	assert_int(map.size()).is_greater_equal(55)
	var bad: Array[String] = []
	for key: String in map:
		var hit: Dictionary = loader.get_context_help(key)
		var chapter_id := str(hit.get("chapter_id", ""))
		var section_id := str(hit.get("section_id", ""))
		if not (chapter_id in order):
			bad.append("%s -> chapter '%s' is not loaded" % [key, chapter_id])
		elif section_id.is_empty() or loader.get_section(chapter_id, section_id).is_empty():
			bad.append("%s -> %s has no section '%s'" % [key, chapter_id, section_id])
	assert_array(bad).override_failure_message(
		"context entries that do not land on a real section:\n" + "\n".join(bad)).is_empty()


func test_the_three_mode_chapters_ship_and_are_linked_from_the_index() -> void:
	var order: Array[String] = (Loader.new() as RefCounted).get_chapter_order()
	for id: String in ["16_planetfall", "17_tactics", "18_battle_simulator"]:
		assert_bool(id in order).override_failure_message("%s is not loaded" % id).is_true()
	var index_text := FileAccess.get_file_as_string(Loader.GUIDE_PATH + "00_index.md")
	for n: String in ["16", "17", "18"]:
		assert_bool(index_text.contains("{{chapter:%s}}" % n)).override_failure_message(
			"00_index.md does not link chapter %s" % n).is_true()


## A {{chapter:NN}} link to a chapter that does not exist is a dead link in the app.
func test_every_chapter_cross_reference_points_at_a_real_chapter() -> void:
	var order: Array[String] = (Loader.new() as RefCounted).get_chapter_order()
	var rx := RegEx.new()
	rx.compile("[{][{]chapter:([0-9]+)[}][}]")
	var dead: Array[String] = []
	for file: String in Loader.list_chapter_files():
		var text := FileAccess.get_file_as_string(Loader.GUIDE_PATH + file)
		for m: RegExMatch in rx.search_all(text):
			var n := m.get_string(1)
			var found := false
			for id: String in order:
				if id.begins_with(n + "_"):
					found = true
			if not found:
				dead.append("%s -> {{chapter:%s}}" % [file, n])
	assert_array(dead).override_failure_message(
		"dead chapter links: " + ", ".join(dead)).is_empty()


## Chapter 13 listed what each Compendium pack adds, and the list disagreed with the Store
## screen: it put Skulker and Psionics in the wrong packs and named features ("Loans
## System", "Prison Planet Campaigns") that nothing in the app is called. The Store builds
## its cards from DLCContentCatalog, so the chapter is held to the same catalog, pack by
## pack: a feature the Store sells under a pack must appear under that pack's heading.
func test_the_store_chapter_lists_each_pack_as_the_store_sells_it() -> void:
	var text := FileAccess.get_file_as_string("res://data/user_guide/13_dlc_store.md")
	assert_str(text).override_failure_message("premise: chapter 13 loads").is_not_empty()
	var wrong: Array[String] = []
	var checked := 0
	for pack_id: String in DLCContentCatalog.PACK_CATALOG:
		var pack: Dictionary = DLCContentCatalog.PACK_CATALOG[pack_id]
		var head := "### %s\n" % pack["name"]
		var at := text.find(head)
		if at < 0:
			wrong.append("no heading for %s" % pack["name"])
			continue
		var next := text.find("\n#", at + head.length())
		var block := text.substr(at, (next if next > 0 else text.length()) - at)
		for category: Dictionary in pack.get("categories", []):
			for feature: Dictionary in category.get("features", []):
				checked += 1
				if not block.contains(str(feature.get("label", ""))):
					wrong.append("%s: %s" % [pack["name"], feature.get("label", "")])
	assert_int(checked).override_failure_message(
		"premise: the catalog lists the packs' features").is_greater(20)
	assert_array(wrong).override_failure_message(
		"chapter 13 disagrees with the Store: " + ", ".join(wrong)).is_empty()


## Chapter 6 described the tiers as a simulator: Full Oracle "Rolls all dice
## automatically", "Resolves hits, damage, and saves" and "Calculates optimal enemy
## actions", none of which the battle screen does. BattleTierController.TIER_INFO is the
## app's one description of each tier (its docblock records why it was rewritten), so the
## chapter carries each tier's description verbatim under that tier's heading.
func test_the_battle_chapter_describes_each_tier_as_the_app_does() -> void:
	var text := FileAccess.get_file_as_string("res://data/user_guide/06_battle_companion.md")
	assert_str(text).override_failure_message("premise: chapter 6 loads").is_not_empty()
	var info: Dictionary = FPCM_BattleTierController.TIER_INFO
	assert_int(info.size()).override_failure_message("premise: three tiers").is_equal(3)
	var wrong: Array[String] = []
	for tier: int in info:
		var head := "### %s\n" % info[tier]["name"]
		var at := text.find(head)
		if at < 0:
			wrong.append("no heading for %s" % info[tier]["name"])
			continue
		var next := text.find("\n#", at + head.length())
		var block := text.substr(at, (next if next > 0 else text.length()) - at)
		if not block.contains(str(info[tier]["description"])):
			wrong.append("%s does not carry the app's description" % info[tier]["name"])
	assert_array(wrong).override_failure_message(
		"chapter 6 disagrees with the battle screen: " + ", ".join(wrong)).is_empty()


## Chapter 4's turn overview summarised the tiers with the same fiction ("The app
## resolves all mechanics"), so it carries the same three descriptions.
func test_the_turn_overview_describes_each_tier_as_the_app_does() -> void:
	var text := FileAccess.get_file_as_string(
		"res://data/user_guide/04_campaign_turn_overview.md")
	assert_str(text).override_failure_message("premise: chapter 4 loads").is_not_empty()
	var info: Dictionary = FPCM_BattleTierController.TIER_INFO
	for tier: int in info:
		assert_str(text).override_failure_message(
			"chapter 4: %s" % info[tier]["name"]).contains(str(info[tier]["description"]))


## Chapter 7's Galactic War step described tracking "the overall galactic conflict state",
## the war-track system that is in neither book and was deleted on 2026-07-29. Core Rules
## p.126 is a 2D6 roll per previously Invaded planet with four results.
func test_the_post_battle_chapter_gives_the_galactic_war_table() -> void:
	var text := FileAccess.get_file_as_string("res://data/user_guide/07_post_battle.md")
	var at := text.find("### Step 14")
	assert_int(at).override_failure_message("premise: chapter 7 has Step 14").is_greater(0)
	var next := text.find("\n## ", at)
	var block := text.substr(at, (next if next > 0 else text.length()) - at)
	for result: String in ["Lost to Unity", "Contested", "Making Ground", "Unity Victorious"]:
		assert_str(block).contains(result)
	assert_str(block).contains("Core Rules p.126")
	assert_str(block.to_lower()).not_contains("conflict state")


## Chapter 5 said an Invasion came from "a galactic war check" and that a failed escape
## cost crew or equipment. Core Rules p.69: the post-battle Check for Invasion arms it,
## and a failed 2D6 forces an Invasion Battle (p.92). It also offered Patrons on a new
## world, where p.72 leaves them behind unless they are Persistent.
func test_the_travel_chapter_follows_the_flee_and_arrival_rules() -> void:
	var text := FileAccess.get_file_as_string("res://data/user_guide/05_travel_and_world.md")
	assert_str(text).override_failure_message("premise: chapter 5 loads").is_not_empty()
	var at := text.find("### Fleeing an Invasion")
	assert_int(at).override_failure_message("premise: the flee section").is_greater(0)
	var flee := text.substr(at, text.find("\n### ", at + 1) - at)
	assert_str(flee).contains("Core Rules p.92")
	assert_str(flee).contains("Check for Invasion")
	assert_str(text.to_lower()).not_contains("galactic war check")
	assert_str(text.to_lower()).not_contains("for reputation")
	var arrive := text.substr(text.find("### Arriving at a New World"))
	assert_str(arrive).contains("Persistent")
	assert_str(arrive).contains("Core Rules p.72")
