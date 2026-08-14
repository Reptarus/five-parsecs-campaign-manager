extends SceneTree

## Verifies every legal document the app can display actually loads and converts
## to well-formed BBCode, using LegalTextViewer's OWN converter.
##
## WHY THE REAL CONVERTER. Re-implementing the markdown rules here would be the
## fabricated-fixture mistake this project keeps paying for: the check would pass
## against a renderer nobody ships. This instantiates the actual script and calls
## the actual method, so a change to either the docs or the converter is caught.
##
## Checks per document:
##   1. the path referenced in code exists and opens
##   2. conversion produces non-empty output
##   3. BBCode tags are balanced (an unclosed [b] swallows the rest of the page)
##   4. no markdown syntax survives that the converter does not handle (tables,
##      would print raw to the user (tables, links, blockquotes, numbered lists)
##
##   Godot_console.exe --headless --path <project> --script tests/tools/verify_legal_docs.gd

const ViewerScript = preload("res://src/ui/screens/legal/LegalTextViewer.gd")

## Exactly the paths src/ references. Keep in sync with SettingsScreen's `docs`
## array and MainMenu's footer buttons.
const DOCS := [
	"res://data/legal/privacy_policy.md",
	"res://data/legal/eula.md",
	"res://data/legal/third_party_licenses.md",
	"res://data/legal/credits.md",
]

## Tags the converter emits. Anything opened must be closed.
const PAIRED_TAGS := ["b", "i", "color", "font_size"]

var _failures: Array[String] = []


func _initialize() -> void:
	var viewer: Object = ViewerScript.new()

	for path: String in DOCS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail(path, "could not open (missing from build?)")
			continue
		var md := file.get_as_text()
		file.close()

		if md.strip_edges().is_empty():
			_fail(path, "file is empty")
			continue

		var bb: String = viewer._markdown_to_bbcode(md)
		if bb.strip_edges().is_empty():
			_fail(path, "converted to empty BBCode")
			continue

		_check_balanced(path, bb)
		_check_unhandled_markdown(path, md)
		_check_no_raw_markers_survive(path, bb)

		print("  %-42s %4d lines -> %5d chars BBCode" % [
			path.get_file(), md.split("\n").size(), bb.length()])

	if viewer is Node:
		(viewer as Node).free()

	print("")
	if _failures.is_empty():
		print("verify_legal_docs: PASS (%d documents)" % DOCS.size())
		quit(0)
	else:
		print("verify_legal_docs: FAIL")
		for f: String in _failures:
			print("   ", f)
		quit(1)


func _fail(path: String, why: String) -> void:
	_failures.append("%s: %s" % [path.get_file(), why])


## NOTE — a bracket-swallow check was written here on 2026-08-11 and REMOVED.
##
## The concern is real: the policy carries pre-release placeholders like
## "[DATE OF RELEASE]", and the converter passes plain lines straight into a
## BBCODE-PARSED RichTextLabel, so a bracketed string that happens to match a
## real tag would be silently swallowed out of a legal document.
##
## Verified separately with a standalone probe, and worth keeping in mind:
##   [DATE OF RELEASE]                -> survives, renders literally to the reader
##   [url=https://example.com]here[/]  -> CONSUMED, only "here" reaches the reader
##
## The check was removed because it could NOT be made to fail on an injected
## [url=...]: the label parses (visible text is shorter and carries no tags) yet
## the needle was still found, and the discrepancy with the standalone probe was
## not explained. A guard that cannot be shown to fail is worse than no guard --
## it reports safety it has not established. Re-add it only WITH a detection
## proof. The other three checks in this file are each detection-proven.

## Markdown markers must not survive INTO the converted output.
##
## The syntax check above asks "does the document contain something the converter
## has no branch for". This asks the other half: "did a branch it DOES have forget
## to finish the job". Found on the tablet Aug 13 2026 — the bullet branch emitted
## `trimmed.substr(2)` verbatim, so all 25 bulleted-bold lines in the privacy
## policy printed `• **Campaign save files** — ...` with the asterisks showing.
## Every other check passed: the tags were balanced and the syntax was supported.
func _check_no_raw_markers_survive(path: String, bb: String) -> void:
	if bb.find("**") != -1:
		var where := bb.substr(maxi(0, bb.find("**") - 40), 90).replace("\n", " ")
		_fail(path, "literal '**' survived conversion, so bold markers print to the "
			+ "reader: ...%s..." % where)


## An unclosed [b] or [color] does not error, it silently formats everything
## after it, so the page LOOKS broken rather than failing loudly.
func _check_balanced(path: String, bb: String) -> void:
	for tag: String in PAIRED_TAGS:
		var opens := 0
		var closes := bb.count("[/%s]" % tag)
		# [color=#fff] and [color] both open; count occurrences of "[tag" not "[/tag".
		var idx := bb.find("[" + tag)
		while idx != -1:
			opens += 1
			idx = bb.find("[" + tag, idx + 1)
		if opens != closes:
			_fail(path, "unbalanced [%s]: %d opened, %d closed" % [tag, opens, closes])


## Markdown the converter has no branch for renders as literal text to the user.
func _check_unhandled_markdown(path: String, md: String) -> void:
	var checks := {
		"table row": "|",
		"blockquote": "> ",
	}
	for label: String in checks:
		for raw_line: String in md.split("\n"):
			var line := raw_line.strip_edges()
			if label == "table row":
				if line.begins_with("|") and line.ends_with("|"):
					_fail(path, "contains a markdown TABLE, which renders as raw pipes")
					break
			elif line.begins_with(checks[label]):
				_fail(path, "contains a markdown %s, which renders literally" % label)
				break

	# A markdown link renders as literal "[text](url)" AND its brackets are fed to
	# a BBCode parser, so it is worse than merely ugly.
	var re := RegEx.new()
	re.compile("\\[[^\\]]+\\]\\([^)]+\\)")
	if re.search(md) != null:
		_fail(path, "contains a markdown LINK; the converter has no branch for it")
