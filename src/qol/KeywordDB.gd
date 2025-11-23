extends Node
## KeywordDB autoload - Keyword database and lookup system
## Singleton autoload: KeywordDB
## TODO: Implement full keyword database

## Keyword storage
var keywords: Dictionary = {}
var bookmarked_keywords: Array[String] = []

func _ready() -> void:
	_initialize_keywords()

func _initialize_keywords() -> void:
	"""Initialize keyword database with placeholder data"""
	# TODO: Load from JSON or database
	keywords = {
		"armor": {
			"term": "Armor",
			"definition": "Reduces incoming damage.",
			"related": ["damage", "combat"],
			"rule_page": 45
		}
	}

func get_keyword(term: String) -> Dictionary:
	"""Get keyword data by term"""
	return keywords.get(term.to_lower(), {})

func is_bookmarked(term: String) -> bool:
	"""Check if keyword is bookmarked"""
	return bookmarked_keywords.has(term.to_lower())

func toggle_bookmark(term: String) -> void:
	"""Toggle bookmark status for keyword"""
	var lower_term = term.to_lower()
	if bookmarked_keywords.has(lower_term):
		bookmarked_keywords.erase(lower_term)
	else:
		bookmarked_keywords.append(lower_term)

func get_all_keywords() -> Array[String]:
	"""Get list of all keyword terms"""
	var terms: Array[String] = []
	for term in keywords.keys():
		terms.append(term)
	return terms
