## Test Helper: Mock KeywordDB
## Simulates KeywordDB autoload functionality for testing
## Plain class (no Node inheritance) to avoid lifecycle issues in tests

class_name MockKeywordDB

# Mock keyword storage
var keywords: Dictionary = {}
var bookmarked_keywords: Array[String] = []

func clear_keywords() -> void:
	"""Clear all keyword data"""
	keywords.clear()
	bookmarked_keywords.clear()

func add_keyword(term: String, keyword_data: Dictionary) -> void:
	"""Add a keyword to the mock database"""
	keywords[term.to_lower()] = keyword_data

func get_keyword(term: String) -> Dictionary:
	"""Get keyword data by term (mirrors KeywordDB.get_keyword())"""
	return keywords.get(term.to_lower(), {})

func is_bookmarked(term: String) -> bool:
	"""Check if keyword is bookmarked (mirrors KeywordDB.is_bookmarked())"""
	return bookmarked_keywords.has(term.to_lower())

func toggle_bookmark(term: String) -> void:
	"""Toggle bookmark status for keyword (mirrors KeywordDB.toggle_bookmark())"""
	var lower_term = term.to_lower()
	if bookmarked_keywords.has(lower_term):
		bookmarked_keywords.erase(lower_term)
	else:
		bookmarked_keywords.append(lower_term)

func get_all_keywords() -> Array[String]:
	"""Get list of all keyword terms (mirrors KeywordDB.get_all_keywords())"""
	var terms: Array[String] = []
	for term in keywords.keys():
		terms.append(term)
	return terms
