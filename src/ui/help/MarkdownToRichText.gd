## Converts markdown text to Godot BBCode for display in RichTextLabel.
## Handles headers, bold, italic, lists, blockquotes, tables, code blocks,
## links, and {{chapter:NN}} cross-reference tags.

# Color constants matching CampaignScreenBase / UIColors
const COLOR_HEADING := "#E0E0E0"
const COLOR_SUBHEADING := "#B0B0B0"
const COLOR_BODY := "#C0C0C0"
const COLOR_ACCENT := "#4FC3F7"  # Cyan for links and highlights
const COLOR_QUICK_START_BG := "#2D5A7B"
const COLOR_QUICK_START_TEXT := "#E0E0E0"
const COLOR_CODE_BG := "#1E1E36"
const COLOR_CODE_TEXT := "#10B981"
const COLOR_BLOCKQUOTE := "#4FC3F7"
const COLOR_TABLE_HEADER := "#2D5A7B"
const COLOR_TABLE_BORDER := "#3A3A5C"
const COLOR_MUTED := "#808080"

# Font sizes
const SIZE_H1 := 28
const SIZE_H2 := 22
const SIZE_H3 := 18
const SIZE_BODY := 16
const SIZE_SMALL := 14

# Signal emitted when a chapter cross-reference is clicked
# HelpScreen connects to this to navigate between chapters
signal chapter_link_clicked(chapter_id: String, section_id: String)


## Convert a full markdown string to BBCode.
func convert(markdown: String) -> String:
	var lines := markdown.split("\n")
	var bbcode := PackedStringArray()
	var in_code_block := false
	var in_table := false
	var table_rows: Array[PackedStringArray] = []

	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		var stripped := line.strip_edges()

		# Code blocks (```)
		if stripped.begins_with("```"):
			if in_code_block:
				in_code_block = false
				bbcode.append("[/bgcolor][/color]\n")
			else:
				in_code_block = true
				bbcode.append("\n[color=%s][bgcolor=%s]" % [COLOR_CODE_TEXT, COLOR_CODE_BG])
			i += 1
			continue

		if in_code_block:
			bbcode.append(line + "\n")
			i += 1
			continue

		# Table rows
		if stripped.begins_with("|") and stripped.ends_with("|"):
			# Check if it's a separator row (|---|---|)
			if stripped.replace("|", "").replace("-", "").replace(":", "").replace(" ", "").is_empty():
				i += 1
				continue

			var cells := _parse_table_row(stripped)
			if not in_table:
				in_table = true
				table_rows.clear()
			table_rows.append(cells)
			i += 1
			continue
		elif in_table:
			# End of table
			bbcode.append(_render_table(table_rows))
			in_table = false
			table_rows.clear()
			# Don't skip — process this line normally

		# Horizontal rule (---)
		if stripped == "---" or stripped == "***" or stripped == "___":
			bbcode.append("\n[color=%s]────────────────────────────────────[/color]\n\n" % COLOR_MUTED)
			i += 1
			continue

		# Empty line
		if stripped.is_empty():
			bbcode.append("\n")
			i += 1
			continue

		# Headers
		if stripped.begins_with("### "):
			var text := _process_inline(stripped.substr(4))
			bbcode.append("\n[font_size=%d][color=%s]%s[/color][/font_size]\n" % [SIZE_H3, COLOR_SUBHEADING, text])
			i += 1
			continue

		if stripped.begins_with("## "):
			var text := _process_inline(stripped.substr(3))
			bbcode.append("\n[font_size=%d][color=%s][b]%s[/b][/color][/font_size]\n" % [SIZE_H2, COLOR_HEADING, text])
			i += 1
			continue

		if stripped.begins_with("# "):
			var text := _process_inline(stripped.substr(2))
			bbcode.append("\n[font_size=%d][color=%s][b]%s[/b][/color][/font_size]\n" % [SIZE_H1, COLOR_HEADING, text])
			i += 1
			continue

		# Blockquote (>) — styled as Quick Start callout if first line matches
		if stripped.begins_with("> "):
			var quote_lines: PackedStringArray = PackedStringArray()
			while i < lines.size():
				var ql: String = lines[i].strip_edges()
				if ql.begins_with("> "):
					quote_lines.append(ql.substr(2))
				elif ql == ">":
					quote_lines.append("")
				else:
					break
				i += 1

			var quote_text := "\n".join(quote_lines)
			var is_quick_start := quote_text.begins_with("**Quick Start**")

			if is_quick_start:
				bbcode.append("\n[indent][color=%s]%s[/color][/indent]\n" % [
					COLOR_BLOCKQUOTE, _process_inline(quote_text)])
			else:
				bbcode.append("\n[indent][color=%s]%s[/color][/indent]\n" % [
					COLOR_MUTED, _process_inline(quote_text)])
			continue

		# Unordered list items (- or *)
		if stripped.begins_with("- ") or stripped.begins_with("* "):
			var item_text := _process_inline(stripped.substr(2))
			bbcode.append("  [color=%s]>[/color] %s\n" % [COLOR_ACCENT, item_text])
			i += 1
			continue

		# Ordered list items (1. 2. etc.)
		var num_match := _match_ordered_list(stripped)
		if not num_match.is_empty():
			var item_text := _process_inline(num_match)
			bbcode.append("  %s\n" % item_text)
			i += 1
			continue

		# Regular paragraph
		bbcode.append(_process_inline(stripped) + "\n")
		i += 1

	# Close any open table
	if in_table and not table_rows.is_empty():
		bbcode.append(_render_table(table_rows))

	return "\n".join(bbcode)


## Process inline markdown: bold, italic, code, links, cross-references.
func _process_inline(text: String) -> String:
	var result := text

	# Cross-reference tags: {{chapter:NN}}
	var cross_ref_regex := RegEx.new()
	cross_ref_regex.compile("\\{\\{chapter:(\\d+)\\}\\}")
	var matches := cross_ref_regex.search_all(result)
	# Process matches in reverse order to preserve positions
	for idx in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[idx]
		var ch_num: String = m.get_string(1)
		var full_match: String = m.get_string(0)
		result = result.substr(0, m.get_start()) + \
			"[color=%s][url=chapter:%s]Ch. %s[/url][/color]" % [COLOR_ACCENT, ch_num, ch_num] + \
			result.substr(m.get_end())

	# Inline code: `text`
	var code_regex := RegEx.new()
	code_regex.compile("`([^`]+)`")
	matches = code_regex.search_all(result)
	for idx in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[idx]
		var code_text: String = m.get_string(1)
		result = result.substr(0, m.get_start()) + \
			"[color=%s]%s[/color]" % [COLOR_CODE_TEXT, code_text] + \
			result.substr(m.get_end())

	# Bold+italic: ***text*** or ___text___
	var bold_italic_regex := RegEx.new()
	bold_italic_regex.compile("\\*\\*\\*(.+?)\\*\\*\\*")
	matches = bold_italic_regex.search_all(result)
	for idx in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[idx]
		result = result.substr(0, m.get_start()) + \
			"[b][i]%s[/i][/b]" % m.get_string(1) + \
			result.substr(m.get_end())

	# Bold: **text**
	var bold_regex := RegEx.new()
	bold_regex.compile("\\*\\*(.+?)\\*\\*")
	matches = bold_regex.search_all(result)
	for idx in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[idx]
		result = result.substr(0, m.get_start()) + \
			"[b]%s[/b]" % m.get_string(1) + \
			result.substr(m.get_end())

	# Italic: *text*
	var italic_regex := RegEx.new()
	italic_regex.compile("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)")
	matches = italic_regex.search_all(result)
	for idx in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[idx]
		result = result.substr(0, m.get_start()) + \
			"[i]%s[/i]" % m.get_string(1) + \
			result.substr(m.get_end())

	# Links: [text](url) — keep display text, make clickable
	var link_regex := RegEx.new()
	link_regex.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	matches = link_regex.search_all(result)
	for idx in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[idx]
		var link_text: String = m.get_string(1)
		var link_url: String = m.get_string(2)
		# Internal links to other chapters
		if link_url.ends_with(".md"):
			var ch_id := link_url.get_file().get_basename()
			result = result.substr(0, m.get_start()) + \
				"[color=%s][url=chapter:%s]%s[/url][/color]" % [COLOR_ACCENT, ch_id, link_text] + \
				result.substr(m.get_end())
		else:
			result = result.substr(0, m.get_start()) + \
				"[color=%s]%s[/color]" % [COLOR_ACCENT, link_text] + \
				result.substr(m.get_end())

	return result


## Parse a table row like "| A | B | C |" into a PackedStringArray of cell contents.
func _parse_table_row(line: String) -> PackedStringArray:
	var cells := PackedStringArray()
	var parts := line.split("|")
	for part in parts:
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			cells.append(trimmed)
	return cells


## Render a table as BBCode. First row is treated as header.
func _render_table(rows: Array[PackedStringArray]) -> String:
	if rows.is_empty():
		return ""

	var bbcode := "\n"

	for row_idx in rows.size():
		var row: PackedStringArray = rows[row_idx]
		var line := ""
		for cell_idx in row.size():
			var cell: String = row[cell_idx]
			if row_idx == 0:
				# Header row
				line += "[b]%s[/b]" % _process_inline(cell)
			else:
				line += _process_inline(cell)
			if cell_idx < row.size() - 1:
				line += "  [color=%s]|[/color]  " % COLOR_TABLE_BORDER
		if row_idx == 0:
			bbcode += "[color=%s]%s[/color]\n" % [COLOR_HEADING, line]
			bbcode += "[color=%s]────────────────────────────[/color]\n" % COLOR_TABLE_BORDER
		else:
			bbcode += "%s\n" % line

	bbcode += "\n"
	return bbcode


## Check if a line starts with an ordered list number (e.g., "1. text").
## Returns the text after the number, or empty string if not a list item.
func _match_ordered_list(line: String) -> String:
	var regex := RegEx.new()
	regex.compile("^(\\d+)\\.\\s+(.+)")
	var m := regex.search(line)
	if m:
		return "[color=%s]%s.[/color] %s" % [COLOR_ACCENT, m.get_string(1), m.get_string(2)]
	return ""
