class_name FPCM_BattleKeywordDB
extends Resource

## Battle Keyword Database - Five Parsecs Combat Term Reference
##
## Pre-populated with ~35 Five Parsecs combat terms and page references.
## Used by BattleJournal and CheatSheetPanel for auto-linking terms.
## Extends the existing KeywordDB autoload with battle-specific entries.

signal keywords_registered(count: int)

## Keyword entry structure: { term, definition, page, category, related }
var _battle_keywords: Dictionary = {}

func _init() -> void:
	_load_battle_keywords()

## Load battle keywords from res://data/battle_keywords.json
func _load_battle_keywords() -> void:
	var file := FileAccess.open("res://data/battle_keywords.json", FileAccess.READ)
	if not file:
		push_warning("BattleKeywordDB: Failed to open battle_keywords.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_warning("BattleKeywordDB: Failed to parse battle_keywords.json")
		file.close()
		return
	file.close()
	var keywords: Array = json.data.get("keywords", [])
	for entry in keywords:
		if entry is Dictionary and entry.has("term"):
			_add(
				entry.get("term", ""),
				entry.get("definition", ""),
				int(entry.get("page", 0)),
				entry.get("category", "unknown"),
			)

## Look up a keyword by term (case-insensitive).
func lookup(term: String) -> Dictionary:
	var key := term.strip_edges().to_lower()
	if _battle_keywords.has(key):
		return _battle_keywords[key]
	return {"term": term, "definition": "Unknown term.", "page": 0, "category": "unknown"}

## Get all keywords.
func get_all_keywords() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _battle_keywords.values():
		result.append(entry)
	return result

## Get keywords by category.
func get_keywords_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _battle_keywords.values():
		if entry.category == category:
			result.append(entry)
	return result

## Get all category names.
func get_categories() -> Array[String]:
	var cats: Array[String] = []
	for entry: Dictionary in _battle_keywords.values():
		if not cats.has(entry.category):
			cats.append(entry.category)
	return cats

## Parse text and wrap known keywords with BBCode hint tags.
## Returns text with [hint=definition (p.XX)]keyword[/hint] tags.
func parse_text_for_keywords(text: String) -> String:
	var result := text
	# Sort keywords by length descending to avoid partial matches
	var sorted_terms: Array[String] = []
	for key: String in _battle_keywords:
		sorted_terms.append(_battle_keywords[key].term)
	sorted_terms.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())

	for term: String in sorted_terms:
		var key := term.to_lower()
		var entry: Dictionary = _battle_keywords[key]
		var hint_text := "%s (p.%d)" % [entry.definition, entry.page]
		# Case-insensitive find and replace (preserve original case)
		var idx := result.to_lower().find(key)
		while idx >= 0:
			var original := result.substr(idx, term.length())
			# Skip if already inside a BBCode tag
			var before := result.substr(0, idx)
			if before.count("[hint=") > before.count("[/hint]"):
				idx = result.to_lower().find(key, idx + term.length())
				continue
			var replacement := "[hint=%s]%s[/hint]" % [hint_text, original]
			result = result.substr(0, idx) + replacement + result.substr(idx + term.length())
			# Skip past the replacement to avoid infinite loop
			idx = result.to_lower().find(key, idx + replacement.length())
	return result

## Register all battle keywords into the existing KeywordDB autoload.
func register_with_keyword_db() -> void:
	var keyword_db = Engine.get_singleton("KeywordDB") if Engine.has_singleton("KeywordDB") else null
	if not keyword_db:
		keyword_db = _get_autoload("KeywordDB")
	if not keyword_db:
		return

	var count := 0
	for key: String in _battle_keywords:
		var entry: Dictionary = _battle_keywords[key]
		if keyword_db.has_method("_add_keyword"):
			keyword_db._add_keyword(entry.term, entry.definition, [], entry.page, entry.category)
			count += 1
		elif keyword_db.has_method("get_keyword"):
			# Check if already exists
			var existing: Dictionary = keyword_db.get_keyword(entry.term)
			if existing.get("category", "") == "unknown":
				keyword_db._add_keyword(entry.term, entry.definition, [], entry.page, entry.category)
				count += 1

	keywords_registered.emit(count)

func _get_autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return tree.root.get_node_or_null("/root/%s" % autoload_name)
	return null

func _add(term: String, definition: String, page: int, category: String) -> void:
	var key := term.strip_edges().to_lower()
	_battle_keywords[key] = {
		"term": term,
		"definition": definition,
		"page": page,
		"category": category,
	}

## Serialize for save/load.
func serialize() -> Dictionary:
	return {"keyword_count": _battle_keywords.size()}

## Deserialize (keywords are static, no need to restore).
func deserialize(_data: Dictionary) -> void:
	pass
