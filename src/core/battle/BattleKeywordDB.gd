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
	_populate_battle_keywords()

## Populate all Five Parsecs battle combat terms.
func _populate_battle_keywords() -> void:
	# Turn Sequence (Core Rules p.38)
	_add("Reaction Roll", "Roll 1d6 per crew member. Result <= Reactions stat = Quick Action this round.", 38, "turn_sequence")
	_add("Quick Actions", "Crew members who passed their Reaction Roll act first. Each can Move + Act.", 38, "turn_sequence")
	_add("Slow Actions", "Crew members who failed their Reaction Roll act after enemies. Each can Move + Act.", 38, "turn_sequence")
	_add("Enemy Actions", "All enemy figures act between Quick and Slow Actions. See AI behavior type.", 38, "turn_sequence")
	_add("End Phase", "Check morale (if casualties this round), resolve conditions, check battle events.", 38, "turn_sequence")

	# Movement (Core Rules p.39)
	_add("Dash", "Move up to full Speed in inches. Cannot fire weapons this activation.", 39, "movement")
	_add("Combat Speed", "Move up to half Speed (round up). Can fire weapons after moving.", 39, "movement")
	_add("Bail", "Move 1\" in any direction as a free action when enemy enters brawling range. Cannot Bail if Stunned.", 39, "movement")

	# Shooting (Core Rules p.40-41)
	_add("Aim", "+1 to Hit. Requires not moving this activation. Stacks with other modifiers.", 40, "shooting")
	_add("Snap Fire", "Fire at an enemy that moves through line of sight during their activation. -1 to Hit.", 40, "shooting")
	_add("Focused Fire", "When 2+ crew fire at same target in one round, second and subsequent shots get +1 to Hit.", 40, "shooting")
	_add("Cover", "Target in cover: -1 to Hit. Must be behind terrain that blocks at least 50% of the figure.", 41, "shooting")
	_add("Line of Sight", "Draw imaginary line from firing figure's head to any part of target. If unobstructed, target is visible.", 41, "shooting")

	# Combat Resolution (Core Rules p.42-44)
	_add("Brawl", "Close combat when figures are within 1\". Both roll 1d6 + Combat Skill. Highest wins. Loser takes a hit.", 42, "combat")
	_add("Hit", "When a figure is hit: roll weapon Damage vs target Toughness. If Damage >= Toughness, figure is a casualty.", 43, "combat")
	_add("Casualty", "Figure removed from play. Crew casualties roll on Injury Table after battle.", 44, "combat")
	_add("Stun", "Figure is Stunned: cannot act next activation. If Stunned again while Stunned, becomes a casualty.", 44, "combat")
	_add("Armor Save", "Some armor grants a save roll. Roll 1d6: if result >= save value, hit is negated.", 44, "combat")

	# Morale (Core Rules p.114)
	_add("Morale Check", "When first casualty occurs each round, enemy checks morale. Roll 2d6 vs Morale value.", 114, "morale")
	_add("Panic", "Failed morale: 1d3 enemies flee the battlefield immediately. Remove from play.", 114, "morale")

	# Initiative (Core Rules p.38)
	_add("Seize Initiative", "At battle start, roll 1d6. On 6 (modified by crew size), crew acts before deployment.", 38, "initiative")

	# Weapons (Core Rules p.45-47)
	_add("Range", "Maximum distance in inches a weapon can fire. Targets beyond range cannot be hit.", 45, "weapons")
	_add("Shots", "Number of attack rolls per activation with this weapon. Each shot is resolved separately.", 45, "weapons")
	_add("Damage", "Roll this value vs target Toughness when a hit is scored. Damage >= Toughness = casualty.", 45, "weapons")

	# Status Effects
	_add("Suppressed", "Cannot advance toward enemy. Can only fire at -1 to Hit or take cover.", 44, "status")
	_add("Wounded", "Crew member injured in battle. Roll on Injury Table after battle to determine severity.", 44, "status")

	# Battle Events (Core Rules p.116-118)
	_add("Battle Event", "Random event on rounds 2 and 4. Roll d100 on the Battle Events Table.", 116, "events")
	_add("Escalation", "After round 4: roll d6 each round. On 1-2 battle ends. On 6 escalation event occurs.", 118, "events")
	_add("Reinforcements", "Additional enemies arrive at table edge. Place d6 figures at a random board edge.", 118, "events")

	# Deployment (Core Rules p.36-37)
	_add("Deployment Zone", "Area where figures are initially placed. Standard: 6\" from your table edge.", 36, "deployment")
	_add("Notable Sighting", "Roll d100 before battle. May encounter unique enemies or situations.", 37, "deployment")

	# Objectives
	_add("Objective", "Mission goal on the battlefield. Must be reached and held to complete mission objectives.", 60, "objectives")

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
	var keyword_db := Engine.get_singleton("KeywordDB") if Engine.has_singleton("KeywordDB") else null
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
