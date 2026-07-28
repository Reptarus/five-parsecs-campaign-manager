extends RefCounted
## Atomic save-file writer. THE single implementation for writing a campaign save.
##
## WHY THIS EXISTS
## All four campaign cores previously did:
##
##     var file = FileAccess.open(path, FileAccess.WRITE)   # truncates to 0 bytes NOW
##     file.store_string(json_string)                       # ~40 KB
##     file.close()                                         # no flush, no error check
##     return OK                                            # unconditional
##
## FileAccess.WRITE truncates the LIVE save the instant it opens, so from that
## moment until close() the player's campaign exists only in memory. Godot only
## auto-closes files on a NORMAL process exit — an Android background-kill, an OOM
## kill, or a task-swipe inside that window leaves a 0-byte or half-written JSON on
## disk. The next launch gets null from load_from_file() and only push_warning()s,
## so Continue silently does nothing.
##
## That window opened on EVERY phase completion (CampaignTurnController auto-saves
## after each one), plus world-phase checkpoints, the End Phase panel, the dashboard
## Save button and all three clone-mode turn controllers. On Android, being killed
## while backgrounded is routine, not exceptional.
##
## There was no recovery either: CampaignFinalizationService writes a `.backup` once
## at campaign creation, and NOTHING in the codebase ever reads a .backup file — so
## even when it exists it is write-only comfort, and it holds turn-0 state anyway.
##
## THE PATTERN: write to a temp path, flush, close, then rename over the real file.
## A rename is atomic at the filesystem level, so the live save is either the old
## complete one or the new complete one, never a partial. Mirrors
## src/core/support/BugReportStore.gd, which uses the same approach.
##
## Kept as a static RefCounted (not an autoload) so the cores — which are Resources
## and can be constructed outside the tree — can call it without a node lookup.

## Writes `content` to `path` atomically. Returns OK, or an Error.
##
## On failure the ORIGINAL file at `path` is left untouched, which is the whole
## point: a failed save must never destroy the previous good one.
static func write_text_atomic(path: String, content: String) -> Error:
	var tmp_path := path + ".tmp"

	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		var open_err := FileAccess.get_open_error()
		push_error("SaveFileWriter: could not open %s (err %d)" % [tmp_path, open_err])
		return open_err

	f.store_string(content)
	# Flush BEFORE the rename or the "atomic" swap can publish a truncated file.
	f.flush()
	var write_err := f.get_error()
	f.close()

	if write_err != OK:
		# Do not rename a bad temp over a good save. Remove the partial.
		push_error("SaveFileWriter: write failed for %s (err %d); original left intact"
			% [path, write_err])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return write_err

	# Keep the previous good save as a .bak before swapping, so a corrupt write in
	# some future code path still has one generation to fall back to.
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		var copy_err := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(bak)
		)
		if copy_err != OK:
			# Non-fatal: proceed with the save rather than blocking it on the backup.
			push_warning("SaveFileWriter: could not refresh %s (err %d)" % [bak, copy_err])

	var rename_err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path),
		ProjectSettings.globalize_path(path)
	)
	if rename_err != OK:
		push_error("SaveFileWriter: rename failed for %s (err %d); data left at %s"
			% [path, rename_err, tmp_path])
		return rename_err

	return OK


## Reads `path`, falling back to the .bak generation if the primary is missing or
## fails to parse as JSON. Returns the parsed Dictionary, or {} if neither works.
##
## Without this the .bak above would repeat history: a backup nothing ever reads.
static func read_json_with_fallback(path: String) -> Dictionary:
	var parsed := _try_parse(path)
	if not parsed.is_empty():
		return parsed

	var bak := path + ".bak"
	if not FileAccess.file_exists(bak):
		return {}

	var from_bak := _try_parse(bak)
	if from_bak.is_empty():
		return {}

	push_warning("SaveFileWriter: %s was unreadable; recovered from %s" % [path, bak])
	return from_bak


static func _try_parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	if text.strip_edges().is_empty():
		return {}  # the exact 0-byte artefact a truncated write leaves behind
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}
