class_name BackgroundDataService
extends RefCounted
## The one owner of a background's display name: the book's own words, Core Rules p.25,
## read from data/character_creation_tables/background_table.json, the same table the
## creation rolls use. Every screen that shows a background asks here.
##
## It replaced five copies, each wrong somewhere: capitalised enum keys ("Giant
## Overcrowded City", "War Torn Hellhole"), shortened dropdown labels ("Subjugated
## Colony", "Primitive World"), and table names missing the commas p.25 prints.
##
## Any spelling resolves: the enum key (PEACEFUL_HIGH_TECH_COLONY), a snake id
## (primitive_world), the book's name, an old label, or an enum ordinal. Five enum keys
## abbreviate their book names, so the table carries an explicit enum_key and the lookup
## never guesses a key from a label.

const TABLE_PATH := "res://data/character_creation_tables/background_table.json"
const ENUMS_PATH := "res://src/core/systems/GlobalEnums.gd"

static var _name_by_key: Dictionary = {}  # normalised spelling -> book name
static var _enum_by_key: Dictionary = {}  # normalised spelling -> enum key
static var _non_word: RegEx = null


## The book's name for a background, or `fallback` when the value is empty. A legacy enum
## member that is not on the p.25 table (MILITARY, MERCENARY...) reads capitalised.
static func display_name(value: Variant, fallback: String = "Unknown") -> String:
	var raw: String = _as_string(value)
	if raw.is_empty():
		return fallback
	_ensure_loaded()
	var key: String = _normalise(raw)
	if _name_by_key.has(key):
		return str(_name_by_key[key])
	return raw.capitalize()


## The enum key a background in any spelling stands for, or "" when it is not on the
## p.25 table.
static func enum_key(value: Variant) -> String:
	var raw: String = _as_string(value)
	if raw.is_empty():
		return ""
	_ensure_loaded()
	return str(_enum_by_key.get(_normalise(raw), ""))


static func _as_string(value: Variant) -> String:
	if value == null:
		return ""
	if value is int or value is float:
		var ordinal: int = int(value)
		var script: Script = load(ENUMS_PATH)
		var members: Dictionary = script.get_script_constant_map().get("Background", {})
		for member: Variant in members:
			if int(members[member]) == ordinal:
				return str(member)
		return ""
	return str(value).strip_edges()


static func _normalise(raw: String) -> String:
	if _non_word == null:
		_non_word = RegEx.create_from_string("[^A-Z0-9]+")
	return _non_word.sub(raw.to_upper(), "_", true).trim_prefix("_").trim_suffix("_")


static func _ensure_loaded() -> void:
	if not _name_by_key.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if not parsed is Dictionary:
		push_error("BackgroundDataService: cannot read %s" % TABLE_PATH)
		return
	var entries: Dictionary = (parsed as Dictionary).get("entries", {})
	for entry: Variant in entries.values():
		var book_name: String = str((entry as Dictionary).get("name", ""))
		var key: String = str((entry as Dictionary).get("enum_key", ""))
		if book_name.is_empty() or key.is_empty():
			continue
		for spelling: String in [key, book_name]:
			_name_by_key[_normalise(spelling)] = book_name
			_enum_by_key[_normalise(spelling)] = key
