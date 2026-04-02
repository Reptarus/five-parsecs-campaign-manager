extends Node
class_name AutoloadKeywordDatabase

## KeywordDB - Game Term Dictionary & Bookmark System
## Provides definitions for equipment traits, battle rules, and game terminology
## Supports bookmarking for quick reference during gameplay

## Signals
signal bookmark_toggled(term: String, is_bookmarked: bool)
signal keywords_loaded()

## Internal storage
var _keywords: Dictionary = {}  # term → KeywordData
var _bookmarks: Array[String] = []  # Bookmarked terms

## Keyword data structure
class KeywordData:
	var term: String = ""
	var definition: String = ""
	var related: Array[String] = []
	var rule_page: int = 0
	var category: String = ""  # "weapon_trait", "rule", "equipment", etc.
	
	func _init(p_term: String, p_definition: String, p_related: Array = [], p_rule_page: int = 0, p_category: String = "") -> void:
		term = p_term
		definition = p_definition
		# Convert Array to Array[String] explicitly
		related.clear()
		for value in p_related:
			if value is String:
				related.append(value)
		rule_page = p_rule_page
		category = p_category
	
	func to_dict() -> Dictionary:
		return {
			"term": term,
			"definition": definition,
			"related": related,
			"rule_page": rule_page,
			"category": category
		}

func _ready() -> void:
	_load_keywords()
	_load_bookmarks()

## Public API
func get_keyword(term: String) -> Dictionary:
	## Get keyword data by term name (case-insensitive)
	var normalized = term.strip_edges().to_lower()
	
	if not _keywords.has(normalized):
		return {
			"term": term,
			"definition": "Unknown term",
			"related": [],
			"rule_page": 0,
			"category": "unknown"
		}
	
	var keyword: KeywordData = _keywords[normalized]
	return keyword.to_dict()

func is_bookmarked(term: String) -> bool:
	## Check if term is bookmarked
	var normalized = term.strip_edges().to_lower()
	return _bookmarks.has(normalized)

func toggle_bookmark(term: String) -> void:
	## Toggle bookmark status for term
	var normalized = term.strip_edges().to_lower()
	
	if _bookmarks.has(normalized):
		_bookmarks.erase(normalized)
		bookmark_toggled.emit(term, false)
	else:
		_bookmarks.append(normalized)
		bookmark_toggled.emit(term, true)
	
	_save_bookmarks()

func get_bookmarks() -> Array[String]:
	## Get all bookmarked terms
	return _bookmarks.duplicate()

func get_keywords_by_category(category: String) -> Array[Dictionary]:
	## Get all keywords in a specific category
	var results: Array[Dictionary] = []
	
	for keyword_data: KeywordData in _keywords.values():
		if keyword_data.category == category:
			results.append(keyword_data.to_dict())
	
	return results

func search_keywords(query: String) -> Array[Dictionary]:
	## Search keywords by term or definition (case-insensitive)
	var results: Array[Dictionary] = []
	var query_lower = query.to_lower()
	
	for keyword_data: KeywordData in _keywords.values():
		if keyword_data.term.to_lower().contains(query_lower) or \
		   keyword_data.definition.to_lower().contains(query_lower):
			results.append(keyword_data.to_dict())
	
	return results

## Internal methods
func _load_keywords() -> void:
	## Load keyword definitions from data/keywords.json, fall back to hardcoded defaults
	var loaded := _load_keywords_from_json("res://data/keywords.json")
	if not loaded:
		push_warning("KeywordDB: Could not load keywords.json, using hardcoded defaults")
		_initialize_default_keywords()
	keywords_loaded.emit()

func _load_keywords_from_json(path: String) -> bool:
	## Parse data/keywords.json and populate _keywords dictionary
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_warning("KeywordDB: Failed to parse keywords.json: %s" % json.get_error_message())
		return false

	var data: Variant = json.get_data()
	if not data is Dictionary or not data.has("keywords"):
		push_warning("KeywordDB: keywords.json missing 'keywords' key")
		return false

	var keywords_dict: Dictionary = data["keywords"]
	for key in keywords_dict:
		var entry: Dictionary = keywords_dict[key]
		var term: String = entry.get("term", key)
		var definition: String = entry.get("definition", "")
		var related: Array = entry.get("related", [])
		var rule_page: int = int(entry.get("rule_page", 0))
		var category: String = entry.get("category", "")
		_add_keyword(term, definition, related, rule_page, category)

	return _keywords.size() > 0

func _initialize_default_keywords() -> void:
	## Minimal fallback — all keywords should be in data/keywords.json
	## This only runs if JSON loading completely fails
	push_warning("KeywordDB: Using minimal fallback — keywords.json failed to load")

func _add_keyword(term: String, definition: String, related: Array, rule_page: int, category: String) -> void:
	## Add keyword to database
	var normalized = term.strip_edges().to_lower()
	_keywords[normalized] = KeywordData.new(term, definition, related, rule_page, category)

func _load_bookmarks() -> void:
	## Load bookmarked terms from user://bookmarks.json
	var file_path = "user://keyword_bookmarks.json"
	
	if not FileAccess.file_exists(file_path):
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("KeywordDB: Could not open bookmarks file")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_warning("KeywordDB: Failed to parse bookmarks JSON")
		return
	
	var data = json.get_data()
	if data is Array:
		# Convert untyped Array to Array[String]
		_bookmarks.clear()
		for item in data:
			_bookmarks.append(str(item))
		pass

## Public property aliases for test compatibility
var keywords: Dictionary:
	get: return _keywords
	set(value): _keywords = value

var bookmarked_keywords: Array[String]:
	get: return _bookmarks
	set(value): _bookmarks = value

func get_all_keywords() -> Array[String]:
	## Get list of all keyword terms
	var terms: Array[String] = []
	for key in _keywords:
		terms.append(key)
	return terms

func parse_text_for_keywords(text: String) -> String:
	## Parse text and wrap recognized keywords in BBCode links
	var result := text
	for keyword_key in _keywords:
		var keyword_data: KeywordData = _keywords[keyword_key]
		var term := keyword_data.term
		# Case-insensitive replacement with BBCode link
		var regex := RegEx.new()
		regex.compile("(?i)\\b" + term.replace(" ", "\\s+") + "\\b")
		result = regex.sub(result, "[url=%s]%s[/url]" % [term.to_lower(), term], true)
	return result

func _save_bookmarks() -> void:
	## Save bookmarked terms to user://bookmarks.json
	var file_path = "user://keyword_bookmarks.json"
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("KeywordDB: Could not save bookmarks")
		return
	
	file.store_string(JSON.stringify(_bookmarks, "\t"))
	file.close()
