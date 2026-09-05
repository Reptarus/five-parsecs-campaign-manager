extends SceneTree
## Load EVERY real 5PFH save through the live load path and report what the
## v1 -> v2 origin migration did to it.
##
## Fixtures cannot prove this. The migration was written against a census of the
## user's actual save directory, and the failure it fixes only exists in files
## written by older builds — so the check that matters is "does every save on
## disk still open, and did the numeric origins become species strings".
##
## READ-ONLY. Nothing is written back; load_from_file() does not save.
##
## Run:
##   godot --headless --path . --script res://tests/tools/probe_save_migration_real_files.gd

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SaveFileMigration = preload("res://src/core/state/SaveFileMigration.gd")

const SAVE_DIR := "user://saves/"


func _init() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		print("PROBE: no save directory at %s" % SAVE_DIR)
		quit(0)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".save"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()

	var loaded := 0
	var failed := 0
	var migrated := 0
	var numeric_before := 0
	var numeric_after := 0

	print("=== %d save files ===" % files.size())
	for name: String in files:
		var path: String = SAVE_DIR + name

		# Raw read first, so we can count what the migration was up against.
		var raw: Dictionary = _read_json(path)
		if raw.is_empty():
			continue
		var is_5pfh: bool = raw.has("crew") and raw.get("crew") is Dictionary
		if not is_5pfh:
			continue
		var before: int = _count_numeric_origins(raw)
		numeric_before += before

		var campaign = CampaignCore.load_from_file(path)
		if campaign == null:
			failed += 1
			print("  FAIL  %-40s did not load" % name)
			continue
		loaded += 1

		var after: int = _count_numeric_origins(campaign.to_dictionary())
		numeric_after += after
		if before > 0:
			migrated += 1
			print("  MIGR  %-40s numeric origins %d -> %d | schema=%d" % [
				name, before, after, campaign.schema_version])
		elif after > 0:
			print("  WARN  %-40s introduced %d numeric origins" % [name, after])

	print()
	print("loaded=%d failed=%d files_with_numeric_origins=%d" % [loaded, failed, migrated])
	print("numeric origin values: before=%d after=%d" % [numeric_before, numeric_after])
	if failed == 0 and numeric_after == 0:
		print("RESULT: PASS — every save loads and no numeric origin survives")
	else:
		print("RESULT: FAIL")
	quit(0 if (failed == 0 and numeric_after == 0) else 1)


func _read_json(path: String) -> Dictionary:
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return {}
	var j := JSON.new()
	if j.parse(fh.get_as_text()) != OK:
		fh.close()
		return {}
	fh.close()
	return j.data if j.data is Dictionary else {}


func _count_numeric_origins(data: Dictionary) -> int:
	var n := 0
	var crew: Variant = data.get("crew", null)
	if crew is Dictionary:
		var members: Variant = (crew as Dictionary).get("members", null)
		if members is Array:
			for m: Variant in (members as Array):
				if m is Dictionary and _is_numeric((m as Dictionary).get("origin", null)):
					n += 1
	var cap: Variant = data.get("captain", null)
	if cap is Dictionary and _is_numeric((cap as Dictionary).get("origin", null)):
		n += 1
	return n


func _is_numeric(v: Variant) -> bool:
	return v is int or v is float
