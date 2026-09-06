extends SceneTree

## T11-22 — deploy #21 desk pass. Does any printed VALUE cross the closing rule of
## its own box, on the real campaign?
##
## ── THE METHOD IS A ONE-VARIABLE A/B, NOT A JUDGEMENT ───────────────────────
## `set_blank_mode(true)` renders the same sheet with the artwork and NO values.
## Diffing that against the populated render isolates exactly the ink the values
## added, so "is this pixel part of the printed rule or part of a value?" — the
## question that makes a naive dark-pixel scan useless — never has to be answered.
## Any added ink BELOW a field's `rule_offset` is a value on the wrong side of its
## own line, which is the whole of T11-22.
##
## The manifest is the reference for where each rule is, and the manifest half is
## already guarded (test_sheet_field_mapping.gd, rule_offset <= h + 12). This probe
## covers the SECOND-order half: correcting the baked offsets shortened 24 crew-log
## fields below their own line height, and a Control cannot be shorter than its
## minimum — so the Label grew DOWNWARD and put the value back across the border the
## correction had just moved it off. SheetRenderer._populate_fields() grows UPWARD
## instead; this is what proves it, on the campaign the tablet actually holds.
##
## ⚠ Run WITHOUT --headless. This builds a real SheetRenderer, which loads and draws
## the sheet PNGs and needs a rendering device — the same reason
## test_sheet_source_paths_resolve.gd is the project's one NEEDS_DISPLAY suite and
## segfaults headless.
##
##   Godot_console.exe --path <project> --script tests/tools/probe_deploy21_render.gd

const SheetRendererScript = preload("res://src/ui/components/sheet/SheetRenderer.gd")
const SheetDataContextScript = preload("res://src/core/export/SheetDataContext.gd")

const SAVE_PATH := "user://saves/tablet_qa_run_1786210201.save"
const OUT_DIR := "user://t1122/"

## How far BELOW the rule to look. ⚠ The rule sits 3-4px below the manifest box
## bottom, not above it — so a band that stops at `rect.y + rect.h` is EMPTY for
## every field, and the first version of this probe reported "216 fields checked"
## while scanning zero pixels and staying green through a faithful revert. Sized
## a little over the largest crew-log line height (36px), which is how far a value
## drops when the box grows the wrong way.
## SheetRenderer.FIELD_BASELINE_GAP — how far the baseline sits above the rule.
const BASELINE_GAP := 4.0

var _sheets: Array = ["crew_log", "encounter_log", "world_record_sheet"]
var _fail: int = 0
var _checked: int = 0
var _grown: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs == null:
		print("ABORT: no /root/GameState")
		quit(2)
		return
	var res: Dictionary = gs.load_campaign(SAVE_PATH)
	if not bool(res.get("success", false)):
		print("ABORT: %s" % str(res.get("message", "load failed")))
		quit(2)
		return
	await process_frame

	# PrintSheetScreen._build_data_context(), verbatim.
	var campaign: Object = gs.get("current_campaign")
	var world: Variant = null
	var pdm: Node = root.get_node_or_null("/root/PlanetDataManager")
	if pdm and pdm.has_method("get_current_planet"):
		world = pdm.get_current_planet()
	var entries: Array = []
	var journal: Node = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("get_all_entries"):
		entries = journal.get_all_entries()
	var ctx: Dictionary = SheetDataContextScript.build(campaign, world, entries)

	print("=== T11-22  values must not cross their own closing rule ===")
	print("campaign: %s   journal entries: %d" % [
		str(campaign.get("campaign_name")), entries.size()])

	for sid: String in _sheets:
		await _check_sheet(sid, ctx)

	print("")
	print("======================================================")
	print("  T11-22 render probe: %d fields checked, %d offender(s)"
		% [_checked, _fail])
	# ⚠ Instrument the probe's own premise. If NO field had to grow, the invariant
	# was never exercised and a clean run proves nothing — which is exactly how the
	# first two versions of this probe survived a faithful revert.
	print("  fields that had to grow to fit their line height: %d" % _grown)
	if _grown == 0:
		print("  !! NOTHING GREW - the invariant was not exercised, this proves NOTHING")
		_fail = maxi(_fail, 1)
	print("  artifacts in %s" % ProjectSettings.globalize_path(OUT_DIR))
	print("======================================================")
	quit(0 if _fail == 0 else 1)


func _check_sheet(sheet_id: String, ctx: Dictionary) -> void:
	var renderer: Control = SheetRendererScript.new()
	root.add_child(renderer)

	var full_path: String = OUT_DIR + sheet_id + "_full.png"

	renderer.render_sheet(sheet_id, ctx)
	await process_frame
	await process_frame
	renderer.export_to_png(full_path)
	await process_frame


	var manifest: Dictionary = _manifest(sheet_id)
	var by_id: Dictionary = {}
	for raw: Variant in manifest.get("fields", []):
		if raw is Dictionary:
			by_id[str((raw as Dictionary).get("id", ""))] = raw
	# All of this works in SOURCE (2764x1843) coordinates -- the same space the
	# manifest and sheet_src_rect are both expressed in -- so the export scale
	# never enters the comparison.

	var offenders: Array = []
	var grown: int = 0
	var here: int = 0
	for node: Variant in renderer.get("_field_nodes"):
		if not (node is Control) or not (node as Control).has_meta("sheet_src_rect"):
			continue
		var fid: String = str((node as Control).get_meta("sheet_field_id", ""))
		var f: Dictionary = by_id.get(fid, {})
		var rect: Array = f.get("rect", [])
		if rect.size() < 4:
			continue
		var inset: float = float(f.get("label_inset", 0))
		var height: float = float(rect[3])
		if inset >= height:
			inset = 0.0
		var rule: float = float(f.get("rule_offset", 0))
		# What _field_src_rect() ends the box at, BEFORE any minimum-size grow.
		var allowed_bottom: float = float(rect[1]) + height
		if rule > inset + BASELINE_GAP:
			allowed_bottom = float(rect[1]) + rule - BASELINE_GAP
		var got: Rect2 = (node as Control).get_meta("sheet_src_rect")
		var got_bottom: float = got.position.y + got.size.y
		_checked += 1
		here += 1
		if got_bottom > allowed_bottom + 0.5:
			offenders.append("%s bottom %.1f vs rule-line %.1f (+%.1f px past its rule)"
				% [fid, got_bottom, allowed_bottom, got_bottom - allowed_bottom])
		if got.size.y > (allowed_bottom - (float(rect[1]) + inset)) + 0.5:
			grown += 1
	print("  %-20s %d fields, %d grew to fit their line height"
		% [sheet_id, here, grown])
	_grown += grown
	renderer.export_to_png(full_path)
	await process_frame
	renderer.queue_free()

	if offenders.is_empty():
		print("  %-20s clean" % sheet_id)
	else:
		_fail += offenders.size()
		print("  %-20s %d OFFENDER(S):" % [sheet_id, offenders.size()])
		for o: String in offenders:
			print("       %s" % o)


func _load(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var img: Image = Image.new()
	if img.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return img


func _manifest(sheet_id: String) -> Dictionary:
	var path: String = "res://data/sheets/core/%s_fields.json" % sheet_id
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
