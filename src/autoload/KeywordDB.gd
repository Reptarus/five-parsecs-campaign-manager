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
	print("KeywordDB: Initialized with %d keywords, %d bookmarks" % [_keywords.size(), _bookmarks.size()])

## Public API
func get_keyword(term: String) -> Dictionary:
	"""Get keyword data by term name (case-insensitive)"""
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
	"""Check if term is bookmarked"""
	var normalized = term.strip_edges().to_lower()
	return _bookmarks.has(normalized)

func toggle_bookmark(term: String) -> void:
	"""Toggle bookmark status for term"""
	var normalized = term.strip_edges().to_lower()
	
	if _bookmarks.has(normalized):
		_bookmarks.erase(normalized)
		bookmark_toggled.emit(term, false)
		print("KeywordDB: Removed bookmark for '%s'" % term)
	else:
		_bookmarks.append(normalized)
		bookmark_toggled.emit(term, true)
		print("KeywordDB: Added bookmark for '%s'" % term)
	
	_save_bookmarks()

func get_bookmarks() -> Array[String]:
	"""Get all bookmarked terms"""
	return _bookmarks.duplicate()

func get_keywords_by_category(category: String) -> Array[Dictionary]:
	"""Get all keywords in a specific category"""
	var results: Array[Dictionary] = []
	
	for keyword_data: KeywordData in _keywords.values():
		if keyword_data.category == category:
			results.append(keyword_data.to_dict())
	
	return results

func search_keywords(query: String) -> Array[Dictionary]:
	"""Search keywords by term or definition (case-insensitive)"""
	var results: Array[Dictionary] = []
	var query_lower = query.to_lower()
	
	for keyword_data: KeywordData in _keywords.values():
		if keyword_data.term.to_lower().contains(query_lower) or \
		   keyword_data.definition.to_lower().contains(query_lower):
			results.append(keyword_data.to_dict())
	
	return results

## Internal methods
func _load_keywords() -> void:
	"""Load keyword definitions from data file or initialize defaults"""
	# TODO: Load from JSON file when data available
	# For now, initialize with common equipment traits
	_initialize_default_keywords()
	keywords_loaded.emit()

func _initialize_default_keywords() -> void:
	"""Initialize common Five Parsecs keywords"""
	# Weapon traits
	_add_keyword("Assault", 
		"Can be fired without penalty while moving at combat speed.",
		["Auto", "Heavy", "Pistol"],
		42,
		"weapon_trait")
	
	_add_keyword("Bulky",
		"Cannot be carried by Soulless. Takes up 2 equipment slots.",
		["Heavy", "Cumbersome"],
		43,
		"weapon_trait")
	
	_add_keyword("Auto",
		"Fires multiple shots per action. +1 shot per activation.",
		["Assault", "Rapid Fire"],
		42,
		"weapon_trait")
	
	_add_keyword("Heavy",
		"Cannot be used after moving at combat speed. Requires setup.",
		["Bulky", "Cumbersome"],
		44,
		"weapon_trait")
	
	_add_keyword("Pistol",
		"Can be fired while engaged in brawling. Easy to conceal.",
		["Assault", "Melee"],
		45,
		"weapon_trait")
	
	_add_keyword("Snap Shot",
		"Can fire as a reaction during enemy movement.",
		["Assault", "Overwatch"],
		46,
		"weapon_trait")
	
	_add_keyword("Melee",
		"Close combat weapon. Used in brawling.",
		["Pistol", "Blade"],
		47,
		"weapon_trait")
	
	# Combat rules
	_add_keyword("Stunned",
		"Cannot activate this round. Move at half speed if activated.",
		["Suppressed", "Pinned"],
		68,
		"status_effect")
	
	_add_keyword("Pinned",
		"Cannot move or shoot. Must pass Savvy test to recover.",
		["Stunned", "Suppressed"],
		69,
		"status_effect")
	
	_add_keyword("Brawling",
		"Close combat between adjacent figures. Roll Combat skill.",
		["Melee", "Combat"],
		70,
		"combat_rule")
	
	print("KeywordDB: Initialized %d default keywords" % _keywords.size())

func _add_keyword(term: String, definition: String, related: Array, rule_page: int, category: String) -> void:
	"""Add keyword to database"""
	var normalized = term.strip_edges().to_lower()
	_keywords[normalized] = KeywordData.new(term, definition, related, rule_page, category)

func _load_bookmarks() -> void:
	"""Load bookmarked terms from user://bookmarks.json"""
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
		_bookmarks = data
		print("KeywordDB: Loaded %d bookmarks" % _bookmarks.size())

func _save_bookmarks() -> void:
	"""Save bookmarked terms to user://bookmarks.json"""
	var file_path = "user://keyword_bookmarks.json"
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("KeywordDB: Could not save bookmarks")
		return
	
	file.store_string(JSON.stringify(_bookmarks, "\t"))
	file.close()
