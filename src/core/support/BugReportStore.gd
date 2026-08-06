extends RefCounted
class_name BugReportStore

## Durable local queue for tester bug reports.
##
## A report is written to disk BEFORE any attempt is made to send it, so a
## failed mail handoff, a dead network, or the app being killed can never lose
## what the tester typed.
##
## Atomic write pattern (`.tmp` then rename) follows PlanetfallDashboard.gd:105-117.
## The directory lives under user://, which LegalConsentManager.delete_all_user_data()
## already recurses, so GDPR deletion is covered without extra work.

const REPORT_DIR := "user://bug_reports/"
const FILE_PREFIX := "report_"
const FILE_EXT := ".json"


## Writes a report atomically. Returns the saved path, or "" on failure.
static func save(report: Dictionary) -> String:
	if not _ensure_dir():
		push_error("BugReportStore: could not create %s" % REPORT_DIR)
		return ""

	var final_path := REPORT_DIR + _make_filename()
	var tmp_path := final_path + ".tmp"

	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("BugReportStore: could not open %s (err %d)" % [tmp_path, FileAccess.get_open_error()])
		return ""
	f.store_string(JSON.stringify(report, "\t"))
	# Godot only auto-closes files on a normal process exit, so flush before the
	# rename or the atomic swap can publish a truncated file.
	f.flush()
	f.close()

	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path),
		ProjectSettings.globalize_path(final_path)
	)
	if err != OK:
		# Leave the .tmp in place rather than losing the report.
		push_error("BugReportStore: rename failed (err %d); report left at %s" % [err, tmp_path])
		return tmp_path
	return final_path


## All saved report paths, oldest first. Excludes unfinished .tmp files.
static func list_pending() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(REPORT_DIR):
		return out
	var names := DirAccess.get_files_at(REPORT_DIR)
	names.sort()
	for n in names:
		if n.begins_with(FILE_PREFIX) and n.ends_with(FILE_EXT):
			out.append(REPORT_DIR + n)
	return out


## Reads one saved report back. Returns {} if unreadable or malformed.
static func load_report(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func delete(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


static func _ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(REPORT_DIR):
		return true
	return DirAccess.make_dir_recursive_absolute(REPORT_DIR) == OK


static func _make_filename() -> String:
	var stamp := int(Time.get_unix_time_from_system())
	var salt := Crypto.new().generate_random_bytes(2).hex_encode()
	return "%s%d_%s%s" % [FILE_PREFIX, stamp, salt, FILE_EXT]


# ── Formatting ───────────────────────────────────────────────────────────────

## The full human-readable report. This is what goes on the clipboard and what
## the developer reads. Deliberately plain text so it survives any mail client.
static func format_as_text(report: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("FIVE PARSECS CAMPAIGN MANAGER — BUG REPORT")
	lines.append("=========================================")
	lines.append("")
	lines.append("Category: %s" % str(report.get("category", "Other")))
	var contact := str(report.get("reporter_contact", ""))
	if not contact.is_empty():
		lines.append("From: %s" % contact)
	lines.append("")
	lines.append("WHAT HAPPENED")
	lines.append("-------------")
	lines.append(str(report.get("what_happened", "")))

	var steps := str(report.get("steps", ""))
	if not steps.strip_edges().is_empty():
		lines.append("")
		lines.append("STEPS TO REPRODUCE")
		lines.append("------------------")
		lines.append(steps)

	lines.append("")
	lines.append("CONTEXT")
	lines.append("-------")
	lines.append(format_context(report.get("context", {})))

	var log_lines: Variant = report.get("log_tail", PackedStringArray())
	if log_lines is PackedStringArray and (log_lines as PackedStringArray).size() > 0:
		lines.append("")
		lines.append("LOG TAIL (last %d lines)" % (log_lines as PackedStringArray).size())
		lines.append("------------------------")
		lines.append("\n".join(log_lines as PackedStringArray))
	elif log_lines is Array and (log_lines as Array).size() > 0:
		lines.append("")
		lines.append("LOG TAIL (last %d lines)" % (log_lines as Array).size())
		lines.append("------------------------")
		for l in (log_lines as Array):
			lines.append(str(l))

	return "\n".join(lines)


## The context block on its own, one "key: value" per line. Used inside the
## full report and in the dialog's "what will be included" preview.
static func format_context(context: Variant) -> String:
	if not (context is Dictionary):
		return "(none)"
	var ctx := context as Dictionary
	var keys := ctx.keys()
	keys.sort()
	var lines := PackedStringArray()
	for k in keys:
		lines.append("%s: %s" % [str(k), str(ctx[k])])
	return "\n".join(lines) if lines.size() > 0 else "(none)"


## Short body for the mailto: URI. Full reports blow past OS and mail-client
## URI length caps, so this is a summary and the full text goes via clipboard.
static func format_email_body(report: Dictionary, saved_path: String) -> String:
	var ctx: Dictionary = report.get("context", {}) if report.get("context") is Dictionary else {}
	var lines := PackedStringArray()
	lines.append("Category: %s" % str(report.get("category", "Other")))
	lines.append("Version: %s (%s) / %s" % [
		str(ctx.get("app_version", "?")),
		str(ctx.get("build_type", "?")),
		str(ctx.get("platform", "?")),
	])
	lines.append("Screen: %s" % str(ctx.get("current_scene", "?")))
	lines.append("Phase: %s / turn %s" % [
		str(ctx.get("phase", "?")),
		str(ctx.get("turn_cpm", "?")),
	])
	lines.append("")
	lines.append(_first_line(str(report.get("what_happened", ""))))
	lines.append("")
	lines.append("-- PASTE THE FULL REPORT BELOW THIS LINE --")
	lines.append("(it is already on your clipboard; saved locally at %s)" % saved_path)
	return "\n".join(lines)


static func _first_line(text: String, limit: int = 300) -> String:
	var stripped := text.strip_edges()
	if stripped.length() <= limit:
		return stripped
	return stripped.substr(0, limit) + "..."
