extends Node
class_name KeywordSystem

## Keyword System - Tap-to-Reveal Definitions
## Provides instant access to game term definitions through contextual tooltips
## Singleton autoload: KeywordDB

signal keyword_accessed(term: String)
signal bookmark_toggled(term: String, is_bookmarked: bool)
signal search_completed(results: Array)

## Keyword database - loaded from JSON
var keywords: Dictionary = {}  # term -> keyword_data
var categories: Array[String] = []
var bookmarked_keywords: Array[String] = []
var recent_searches: Array[String] = []
var search_history: Array[Dictionary] = []

## Analytics
var access_count: Dictionary = {}  # term -> count
var analytics_enabled: bool = true

## Configuration
const MAX_RECENT_SEARCHES: int = 10
const MAX_SEARCH_HISTORY: int = 100
const DATABASE_PATH: String = "res://data/keywords.json"

func _ready() -> void:
	_load_keyword_database()

## ===== CORE FUNCTIONALITY =====

func get_keyword(term: String) -> Dictionary:
	## Get keyword data by term (case-insensitive)
	var normalized_term = term.to_lower().strip_edges()
	
	if keywords.has(normalized_term):
		_track_access(normalized_term)
		return keywords[normalized_term]
	
	# Try fuzzy match
	for key in keywords.keys():
		if key.contains(normalized_term) or normalized_term.contains(key):
			_track_access(key)
			return keywords[key]
	
	return {}  # Not found

func search_keywords(query: String) -> Array[Dictionary]:
	## Search keywords by term, definition, or tags
	var results: Array[Dictionary] = []
	var normalized_query = query.to_lower().strip_edges()
	
	if normalized_query.is_empty():
		return results
	
	for term in keywords.keys():
		var keyword_data = keywords[term]
		
		# Match term
		if term.contains(normalized_query):
			results.append(keyword_data)
			continue
		
		# Match definition
		if keyword_data.get("definition", "").to_lower().contains(normalized_query):
			results.append(keyword_data)
			continue
		
		# Match category
		if keyword_data.get("category", "").to_lower().contains(normalized_query):
			results.append(keyword_data)
			continue
		
		# Match related keywords
		var related = keyword_data.get("related", [])
		for related_term in related:
			if related_term.to_lower().contains(normalized_query):
				results.append(keyword_data)
				break
	
	_track_search(query)
	search_completed.emit(results)
	return results

func parse_text_for_keywords(text: String) -> String:
	## Convert plain text to BBCode with clickable keyword links
	var parsed_text = text
	
	# Sort keywords by length (longest first) to avoid partial matches
	var sorted_terms = keywords.keys()
	sorted_terms.sort_custom(func(a, b): return a.length() > b.length())
	
	for term in sorted_terms:
		# Use word boundaries to avoid partial matches
		var regex = RegEx.new()
		regex.compile("\\b" + term + "\\b")
		
		var matches = regex.search_all(parsed_text)
		for match_result in matches:
			var matched_text = match_result.get_string()
			var bbcode_link = "[url=keyword:" + term + "]" + matched_text + "[/url]"
			parsed_text = parsed_text.replace(matched_text, bbcode_link)
	
	return parsed_text

## ===== BOOKMARKS =====

func is_bookmarked(term: String) -> bool:
	## Check if keyword is bookmarked
	return bookmarked_keywords.has(term.to_lower())

func toggle_bookmark(term: String) -> void:
	## Toggle bookmark status for keyword
	var normalized_term = term.to_lower()
	
	if is_bookmarked(normalized_term):
		bookmarked_keywords.erase(normalized_term)
		bookmark_toggled.emit(normalized_term, false)
	else:
		bookmarked_keywords.append(normalized_term)
		bookmark_toggled.emit(normalized_term, true)
	
	_save_user_data()

func get_bookmarks() -> Array[String]:
	## Get all bookmarked keywords
	return bookmarked_keywords.duplicate()

func clear_bookmarks() -> void:
	## Remove all bookmarks
	bookmarked_keywords.clear()
	_save_user_data()

## ===== RELATED KEYWORDS =====

func get_related_keywords(term: String) -> Array[String]:
	## Get related keywords for a term
	var keyword_data = get_keyword(term)
	return keyword_data.get("related", [])

## ===== ANALYTICS =====

func get_analytics() -> Dictionary:
	## Get usage analytics
	return {
		"most_accessed": _get_top_accessed_keywords(10),
		"search_queries": recent_searches.duplicate(),
		"total_accesses": _get_total_accesses(),
		"bookmark_count": bookmarked_keywords.size()
	}

func _track_access(term: String) -> void:
	## Track keyword access for analytics
	if not analytics_enabled:
		return
	
	if not access_count.has(term):
		access_count[term] = 0
	access_count[term] += 1
	
	keyword_accessed.emit(term)

func _track_search(query: String) -> void:
	## Track search query
	if not analytics_enabled:
		return
	
	# Add to recent searches (FIFO)
	if recent_searches.has(query):
		recent_searches.erase(query)
	recent_searches.push_front(query)
	
	if recent_searches.size() > MAX_RECENT_SEARCHES:
		recent_searches.resize(MAX_RECENT_SEARCHES)
	
	# Add to search history
	search_history.append({
		"query": query,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	if search_history.size() > MAX_SEARCH_HISTORY:
		search_history.pop_front()
	
	_save_user_data()

func _get_top_accessed_keywords(count: int) -> Array:
	## Get most accessed keywords
	var sorted_terms = access_count.keys()
	sorted_terms.sort_custom(func(a, b): return access_count[a] > access_count[b])
	
	var top_keywords = []
	for i in min(count, sorted_terms.size()):
		top_keywords.append({
			"term": sorted_terms[i],
			"count": access_count[sorted_terms[i]]
		})
	
	return top_keywords

func _get_total_accesses() -> int:
	## Get total keyword accesses
	var total = 0
	for count in access_count.values():
		total += count
	return total

## ===== DATA PERSISTENCE =====

func _load_keyword_database() -> void:
	## Load keyword database from JSON
	if not FileAccess.file_exists(DATABASE_PATH):
		push_error("Keyword database not found: " + DATABASE_PATH)
		_create_default_database()
		return
	
	var file = FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open keyword database")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Failed to parse keyword database JSON")
		return
	
	var data = json.get_data()
	
	# Load keywords
	if data.has("keywords"):
		for keyword_entry in data.keywords:
			var term = keyword_entry.get("term", "").to_lower()
			keywords[term] = keyword_entry
	
	# Load categories
	if data.has("categories"):
		categories = data.categories
	
	print("Loaded %d keywords in %d categories" % [keywords.size(), categories.size()])

func _create_default_database() -> void:
	## Create minimal default keyword database
	keywords = {
		"reactions": {
			"term": "Reactions",
			"category": "stat",
			"definition": "Determines initiative order in combat.",
			"extended": "Higher Reactions means acting earlier in the combat round.",
			"related": ["Initiative", "Combat Sequence"],
			"examples": ["Reactions 5 beats Reactions 3"]
		},
		"toughness": {
			"term": "Toughness",
			"category": "stat",
			"definition": "Determines damage resistance and survivability.",
			"extended": "Used to resist injuries and survive wounds.",
			"related": ["Injury", "Damage", "Health"],
			"examples": ["Toughness 4 survives more hits than Toughness 2"]
		},
		"story points": {
			"term": "Story Points",
			"category": "mechanic",
			"definition": "Campaign victory points earned through narrative milestones.",
			"extended": "Reach 5 Story Points to win the campaign.",
			"related": ["Story Track", "Victory Conditions"],
			"examples": []
		}
	}
	categories = ["stat", "trait", "equipment", "weapon", "armor", "enemy", "mission", "phase", "mechanic", "condition"]

func _save_user_data() -> void:
	## Save user preferences (bookmarks, searches)
	var user_data = {
		"bookmarked_keywords": bookmarked_keywords,
		"recent_searches": recent_searches,
		"search_history": search_history,
		"access_count": access_count
	}
	
	var file = FileAccess.open("user://keyword_user_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(user_data, "\t"))
		file.close()

func _load_user_data() -> void:
	## Load user preferences
	if not FileAccess.file_exists("user://keyword_user_data.json"):
		return
	
	var file = FileAccess.open("user://keyword_user_data.json", FileAccess.READ)
	if not file:
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) == OK:
		var data = json.get_data()
		bookmarked_keywords = data.get("bookmarked_keywords", [])
		recent_searches = data.get("recent_searches", [])
		search_history = data.get("search_history", [])
		access_count = data.get("access_count", {})

## ===== INTEGRATION HELPERS =====

func get_keyword_for_stat(stat_name: String) -> Dictionary:
	## Helper to get keyword for character stat
	return get_keyword(stat_name)

func get_keyword_for_equipment(equipment_name: String) -> Dictionary:
	## Helper to get keyword for equipment
	return get_keyword(equipment_name)

func get_keyword_for_condition(condition_name: String) -> Dictionary:
	## Helper to get keyword for status condition
	return get_keyword(condition_name)

## Called from GameState on campaign load
func load_from_save(save_data: Dictionary) -> void:
	## Load keyword system state from campaign save
	if save_data.has("qol_data") and save_data.qol_data.has("keywords"):
		var keyword_data = save_data.qol_data.keywords
		bookmarked_keywords = keyword_data.get("bookmarked", [])
		recent_searches = keyword_data.get("recent_searches", [])

## Called from GameState on campaign save
func save_to_dict() -> Dictionary:
	## Save keyword system state to campaign save
	return {
		"bookmarked": bookmarked_keywords,
		"recent_searches": recent_searches
	}
