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
const SUBSPECIES_PATH := "res://data/planetfall/human_subspecies.json"
const PRESET_CREW_PATH := "res://data/planetfall/preset_crew.json"
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


## ============================================================================
## THE FOUNDING ROSTER (pp.14-20)
## ============================================================================

static var _subspecies: Dictionary = {}


## The p.19 Human sub-species and the p.20 Soulless emissary, keyed by id.
## A character's profile as the Colony Tracking Sheet lists it (p.18). The roster step,
## the review and the dashboard all print this one line; they carried three copies.
static func profile_line(c: Dictionary) -> String:
	var line: String = "Reactions %d · Speed %d\" · Combat %+d · Toughness %d · Savvy %+d" % [
			int(c.get("reactions", 0)), int(c.get("speed", 0)), int(c.get("combat_skill", 0)),
			int(c.get("toughness", 0)), int(c.get("savvy", 0))]
	if c.has("saving_throw"):
		line += " · Save %d+" % int(c.saving_throw)
	return line


static func subspecies_data() -> Dictionary:
	if _subspecies.is_empty():
		_subspecies = _read(SUBSPECIES_PATH).get("subspecies", {})
	return _subspecies


## The pre-made crew pictured in the Planetfall character spread (preset_crew.json). That
## file is names and portraits only: the book gives the crew no profiles. So a preset never
## touches a class, a sub-species or a stat. It renames the characters built here, in slot
## order, and gives each its picture; an imported character keeps its own name.
## ⚠ Until 2026-10-28 the file and its seven portraits had no reader, and no Planetfall
## screen drew a portrait at all.
static func preset_crews() -> Array:
	return _read(PRESET_CREW_PATH).get("presets", [])


static func with_preset(roster: Array, preset: Dictionary) -> Array:
	var out: Array = roster.duplicate(true)
	var members: Array = preset.get("members", [])
	var m: int = 0
	for i in range(out.size()):
		if m >= members.size():
			break
		if bool(out[i].get("is_imported", false)):
			continue
		var member: Dictionary = members[m]
		m += 1
		out[i]["name"] = str(member.get("character_name", out[i].get("name", "")))
		var art: String = str(member.get("portrait_path", ""))
		if art != "" and ResourceLoader.exists(art):
			out[i]["portrait_path"] = art
	return out


## `character` rebuilt as its class's standard character with `subspecies_id` applied
## ("" for none), keeping its id and name. The profile values are what the character
## BEGINS with, not additions: "Hulkers begin with Toughness 5" (p.19), the Soulless
## "begins the campaign with Toughness 4 and a +1 Savvy score" and "receives a 6+ Saving
## Throw" (p.20). Feral and Stalker change no value (p.19).
static func with_subspecies(character: Dictionary, subspecies_id: String) -> Dictionary:
	var out: Dictionary = standard_character(str(character.get("class", "trooper")),
			str(character.get("id", "")), str(character.get("name", "")))
	# A picture is the character's, like the id and the name (with_preset below).
	if character.has("portrait_path"):
		out["portrait_path"] = character["portrait_path"]
	var entry: Dictionary = subspecies_data().get(subspecies_id, {})
	if entry.is_empty():
		return out
	out["subspecies"] = subspecies_id
	for stat in entry.get("stat_modifications", {}):
		out[stat] = int(entry.stat_modifications[stat])
	if entry.has("saving_throw"):
		out["saving_throw"] = int(entry.saving_throw)
	for ability in entry.get("abilities", []):
		out["abilities"].append((ability as Dictionary).duplicate(true))
	return out


## Every reason `roster` is not yet a legal founding roster, one sentence each with its
## page; [] when it is. p.14: "an initial roster of eight characters", "any combination
## of these three classes, but you must include at least one of each", and imported
## characters "count against your roster limit". p.19: "a maximum of one Feral plus one
## sub-species of choice (Hulker, Stalker, or a second Feral)". p.20: "a single Soulless
## emissary", who "can only occupy the Trooper class".
static func roster_problems(roster: Array) -> Array:
	var problems: Array = []
	var size: int = int(class_data().get("roster_rules", {}).get("initial_roster_size", 8))
	if roster.size() != size:
		problems.append("The founding roster has %d characters, and the colony starts with %d (p.14)."
				% [roster.size(), size])
	var per_class: Dictionary = {}
	var per_kind: Dictionary = {}
	for c in roster:
		if c is Dictionary:
			per_class[str(c.get("class", ""))] = int(per_class.get(str(c.get("class", "")), 0)) + 1
			per_kind[str(c.get("subspecies", ""))] = int(per_kind.get(
					str(c.get("subspecies", "")), 0)) + 1
			if str(c.get("subspecies", "")) == "soulless_emissary" \
					and str(c.get("class", "")) != "trooper":
				problems.append("%s is a Soulless emissary, who can only be a Trooper (p.20)."
						% str(c.get("name", "A character")))
	for cls in REPLACEMENT_CLASSES:
		if int(per_class.get(cls, 0)) < 1:
			problems.append("Add at least one %s (p.14)." % str(cls).capitalize())
	var feral: int = int(per_kind.get("feral", 0))
	var other: int = int(per_kind.get("hulker", 0)) + int(per_kind.get("stalker", 0))
	if feral > 2 or other > 1 or feral + other > 2:
		problems.append("At most one Feral plus one more of Hulker, Stalker or a second Feral "
				+ "(p.19).")
	if int(per_kind.get("soulless_emissary", 0)) > 1:
		problems.append("Only one Soulless emissary may join the colony (p.20).")
	return problems
