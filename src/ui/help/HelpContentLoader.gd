## Loads and parses markdown files from res://docs/user_guide/
## Provides chapter lookup, section navigation, and full-text search.
## Used by HelpScreen and HelpOverlayPanel to display user guide content.

const GUIDE_PATH := "res://docs/user_guide/"

# Cached parsed chapters: chapter_id -> {title, quick_start, sections, raw}
var _chapters: Dictionary = {}
# Ordered list of chapter IDs for TOC
var _chapter_order: Array[String] = []
# Flat keyword index for search: word -> [{chapter_id, section_id, line}]
var _search_index: Dictionary = {}

var _loaded: bool = false


func ensure_loaded() -> void:
	if _loaded:
		return
	_load_all_chapters()
	_build_search_index()
	_loaded = true


func _load_all_chapters() -> void:
	_chapters.clear()
	_chapter_order.clear()

	# Discover markdown files in the guide directory
	var dir := DirAccess.open(GUIDE_PATH)
	if not dir:
		push_warning("HelpContentLoader: Could not open %s" % GUIDE_PATH)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".md"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()

	for fname in files:
		var chapter_id := fname.get_basename()  # e.g. "01_getting_started"
		var raw := _read_file(GUIDE_PATH + fname)
		if raw.is_empty():
			continue
		var parsed := _parse_chapter(raw)
		parsed["file"] = fname
		_chapters[chapter_id] = parsed
		_chapter_order.append(chapter_id)


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_warning("HelpContentLoader: Cannot read %s" % path)
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## Parse a markdown file into structured data.
## Returns: {title, quick_start, sections: [{id, heading, level, content}], raw}
func _parse_chapter(raw: String) -> Dictionary:
	var result := {
		"title": "",
		"quick_start": "",
		"sections": [] as Array[Dictionary],
		"raw": raw,
	}

	var lines := raw.split("\n")
	var current_section_id := ""
	var current_section_heading := ""
	var current_section_level := 0
	var current_section_lines: PackedStringArray = PackedStringArray()
	var in_quick_start := false
	var quick_start_lines: PackedStringArray = PackedStringArray()

	for line in lines:
		var stripped: String = line.strip_edges()

		# Detect chapter title (first H1)
		if stripped.begins_with("# ") and result["title"].is_empty():
			result["title"] = stripped.substr(2).strip_edges()
			continue

		# Detect Quick Start block (blockquote starting with "Quick Start")
		if stripped.begins_with("> **Quick Start**") or stripped.begins_with("> **Quick Start**"):
			in_quick_start = true
			quick_start_lines.append(stripped.substr(2).strip_edges())
			continue

		if in_quick_start:
			if stripped.begins_with("> "):
				quick_start_lines.append(stripped.substr(2).strip_edges())
				continue
			elif stripped == ">":
				quick_start_lines.append("")
				continue
			else:
				in_quick_start = false
				result["quick_start"] = "\n".join(quick_start_lines)

		# Detect section headers (## or ###)
		if stripped.begins_with("## ") or stripped.begins_with("### "):
			# Save previous section
			if not current_section_id.is_empty():
				result["sections"].append({
					"id": current_section_id,
					"heading": current_section_heading,
					"level": current_section_level,
					"content": "\n".join(current_section_lines).strip_edges(),
				})

			# Start new section
			if stripped.begins_with("### "):
				current_section_level = 3
				current_section_heading = stripped.substr(4).strip_edges()
			else:
				current_section_level = 2
				current_section_heading = stripped.substr(3).strip_edges()

			current_section_id = _heading_to_id(current_section_heading)
			current_section_lines = PackedStringArray()
			continue

		current_section_lines.append(line)

	# Save final section
	if not current_section_id.is_empty():
		result["sections"].append({
			"id": current_section_id,
			"heading": current_section_heading,
			"level": current_section_level,
			"content": "\n".join(current_section_lines).strip_edges(),
		})

	# If quick_start wasn't terminated by a non-blockquote line
	if in_quick_start and not quick_start_lines.is_empty():
		result["quick_start"] = "\n".join(quick_start_lines)

	return result


## Convert a heading string to a URL-safe section ID.
func _heading_to_id(heading: String) -> String:
	return heading.to_lower().replace(" ", "_").replace("'", "").replace("\"", "") \
		.replace("(", "").replace(")", "").replace(",", "").replace(":", "") \
		.replace("?", "").replace("!", "").replace("/", "_").replace("&", "and")


## Build a flat word index for full-text search.
func _build_search_index() -> void:
	_search_index.clear()
	for chapter_id in _chapter_order:
		var chapter: Dictionary = _chapters[chapter_id]
		_index_text(chapter_id, "_title", chapter.get("title", ""))
		_index_text(chapter_id, "_quick_start", chapter.get("quick_start", ""))
		var sections: Array = chapter.get("sections", [])
		for section in sections:
			var sec: Dictionary = section
			_index_text(chapter_id, sec.get("id", ""), sec.get("heading", ""))
			_index_text(chapter_id, sec.get("id", ""), sec.get("content", ""))


func _index_text(chapter_id: String, section_id: String, text: String) -> void:
	if text.is_empty():
		return
	# Split into words, lowercase, skip short words
	var words := text.to_lower().split(" ", false)
	for word in words:
		# Strip markdown chars
		var clean: String = word.strip_edges()
		clean = clean.replace("*", "").replace("#", "").replace("`", "") \
			.replace("[", "").replace("]", "").replace("(", "").replace(")", "")
		if clean.length() < 3:
			continue
		if not _search_index.has(clean):
			_search_index[clean] = []
		# Avoid duplicate entries for same chapter+section
		var entries: Array = _search_index[clean]
		var already := false
		for entry in entries:
			var e: Dictionary = entry
			if e.get("chapter") == chapter_id and e.get("section") == section_id:
				already = true
				break
		if not already:
			entries.append({"chapter": chapter_id, "section": section_id})


# ── Public API ───────────────────────────────────────────────────────────────

## Get the ordered list of chapter IDs.
func get_chapter_order() -> Array[String]:
	ensure_loaded()
	return _chapter_order.duplicate()


## Get the table of contents: [{id, title, file}]
func get_table_of_contents() -> Array[Dictionary]:
	ensure_loaded()
	var toc: Array[Dictionary] = []
	for chapter_id in _chapter_order:
		var ch: Dictionary = _chapters[chapter_id]
		toc.append({
			"id": chapter_id,
			"title": ch.get("title", chapter_id),
			"file": ch.get("file", ""),
		})
	return toc


## Load a specific chapter by ID. Returns the parsed chapter dict, or empty dict.
func load_chapter(chapter_id: String) -> Dictionary:
	ensure_loaded()
	return _chapters.get(chapter_id, {})


## Get a specific section within a chapter.
## Returns {id, heading, level, content} or empty dict.
func get_section(chapter_id: String, section_id: String) -> Dictionary:
	var chapter := load_chapter(chapter_id)
	if chapter.is_empty():
		return {}
	var sections: Array = chapter.get("sections", [])
	for section in sections:
		var sec: Dictionary = section
		if sec.get("id", "") == section_id:
			return sec
	return {}


## Search all chapters for a query string.
## Returns [{chapter_id, section_id, chapter_title, section_heading, relevance}]
func search(query: String) -> Array[Dictionary]:
	ensure_loaded()
	if query.strip_edges().is_empty():
		return []

	var results: Array[Dictionary] = []
	var seen := {}  # Deduplicate by chapter+section
	var words := query.to_lower().split(" ", false)

	for word in words:
		var clean: String = word.strip_edges().replace("*", "").replace("#", "")
		if clean.length() < 2:
			continue

		# Exact match
		if _search_index.has(clean):
			for entry in _search_index[clean]:
				var e: Dictionary = entry
				var key: String = e.get("chapter", "") + ":" + e.get("section", "")
				if not seen.has(key):
					seen[key] = 0
				seen[key] += 2  # Exact match bonus

		# Prefix match for partial searches
		for indexed_word in _search_index:
			var iw: String = indexed_word
			if iw.begins_with(clean) and iw != clean:
				for entry in _search_index[iw]:
					var e: Dictionary = entry
					var key: String = e.get("chapter", "") + ":" + e.get("section", "")
					if not seen.has(key):
						seen[key] = 0
					seen[key] += 1

	# Build result array sorted by relevance
	for key in seen:
		var parts: PackedStringArray = key.split(":")
		if parts.size() < 2:
			continue
		var ch_id: String = parts[0]
		var sec_id: String = parts[1]
		var chapter: Dictionary = _chapters.get(ch_id, {})
		var sec_heading := ""
		var sections: Array = chapter.get("sections", [])
		for section in sections:
			var sec: Dictionary = section
			if sec.get("id", "") == sec_id:
				sec_heading = sec.get("heading", "")
				break
		results.append({
			"chapter_id": ch_id,
			"section_id": sec_id,
			"chapter_title": chapter.get("title", ch_id),
			"section_heading": sec_heading,
			"relevance": seen[key],
		})

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("relevance", 0) > b.get("relevance", 0)
	)

	# Limit to top 20 results
	if results.size() > 20:
		results.resize(20)

	return results


## Get context-sensitive help for a screen/phase identifier.
## Reads from data/help_context_map.json.
## Returns {chapter_id, section_id} or empty dict.
func get_context_help(screen_id: String) -> Dictionary:
	var map := _load_context_map()
	if map.has(screen_id):
		var entry: Dictionary = map[screen_id]
		return {
			"chapter_id": _resolve_chapter_id(entry.get("chapter", "")),
			"section_id": entry.get("section", ""),
		}
	return {}


var _context_map_cache: Dictionary = {}
var _context_map_loaded: bool = false

func _load_context_map() -> Dictionary:
	if _context_map_loaded:
		return _context_map_cache

	var path := "res://data/help_context_map.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_warning("HelpContentLoader: Cannot read %s" % path)
		_context_map_loaded = true
		return _context_map_cache

	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()

	if err != OK:
		push_warning("HelpContentLoader: JSON parse error in %s: %s" % [path, json.get_error_message()])
		_context_map_loaded = true
		return _context_map_cache

	if json.data is Dictionary:
		_context_map_cache = json.data
	_context_map_loaded = true
	return _context_map_cache


## Resolve a short chapter number ("01") to a full chapter_id ("01_getting_started").
func _resolve_chapter_id(short_id: String) -> String:
	for chapter_id in _chapter_order:
		if chapter_id.begins_with(short_id + "_") or chapter_id == short_id:
			return chapter_id
	return short_id
