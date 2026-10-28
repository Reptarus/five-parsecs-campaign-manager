extends RefCounted

## The Planetfall character roster: who fits on it, and what a new colonist looks like.
## Source: Planetfall pp.14-20 (classes and the standard profiles), p.69 (Step 13
## Replacements: "If you have less than a full roster (8 characters, initially)") and
## p.100 (Expanded living facility: "You may expand your character roster by 2").
##
## Creation built its standard character inline and Step 13 printed "N new
## character(s) added to roster" while adding nobody; both now take the shape from here.

const CLASSES_PATH := "res://data/planetfall/character_classes.json"
const BUILDINGS_PATH := "res://data/planetfall/buildings.json"
## The classes p.69 lets a replacement be ("a trooper / a scientist / a scout").
const REPLACEMENT_CLASSES := ["trooper", "scientist", "scout"]

static var _cache: Dictionary = {}
static var _slots_by_building: Dictionary = {}


static func class_data() -> Dictionary:
	if _cache.is_empty():
		_cache = _read(CLASSES_PATH)
	return _cache


static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Building id -> the roster slots its effect adds, for every building that adds any.
static func _roster_slot_buildings() -> Dictionary:
	if _slots_by_building.is_empty():
		for b in _read(BUILDINGS_PATH).get("buildings", []):
			if b is Dictionary and (b.get("effect", {}) as Dictionary).has("roster_slots"):
				_slots_by_building[str(b.get("id", ""))] = int(b.effect.roster_slots)
	return _slots_by_building


## A character of `cls` with that class's standard profile and abilities, entering
## at Loyalty Committed (p.69 "All characters enter with a Loyalty level of Committed").
static func standard_character(cls: String, id: String, display_name: String) -> Dictionary:
	var entry: Dictionary = class_data().get("classes", {}).get(cls, {})
	var profile: Dictionary = entry.get("profiles", {})
	return {
		"id": id,
		"name": display_name,
		"class": cls,
		"subspecies": "",
		"reactions": profile.get("reactions", 1),
		"speed": profile.get("speed", 4),
		"combat_skill": profile.get("combat_skill", 0),
		"toughness": profile.get("toughness", 3),
		"savvy": profile.get("savvy", 0),
		"xp": 0,
		"kp": 0,
		"loyalty": "committed",
		"motivation": "",
		"prior_experience": "",
		"notable_event": "",
		"abilities": entry.get("abilities", []).duplicate(true),
		"is_imported": false,
		"source_campaign": "",
	}


## A full roster: the initial size (p.69) plus the slots of every constructed building
## that adds them (p.100), read from what stands now, so a reclaimed one gives them back.
static func roster_capacity(campaign: Resource) -> int:
	var capacity: int = int(class_data().get("roster_rules", {}).get("initial_roster_size", 8))
	if campaign and "buildings_data" in campaign and campaign.buildings_data is Dictionary:
		var slots: Dictionary = _roster_slot_buildings()
		for id in campaign.buildings_data.get("constructed", []):
			capacity += int(slots.get(str(id), 0))
	return capacity


## An id no character on the roster already uses.
static func next_character_id(campaign: Resource) -> String:
	var used: Dictionary = {}
	if campaign and "roster" in campaign:
		for c in campaign.roster:
			if c is Dictionary:
				used[str(c.get("id", ""))] = true
	var n: int = used.size()
	while used.has("pf_char_%d" % n):
		n += 1
	return "pf_char_%d" % n
