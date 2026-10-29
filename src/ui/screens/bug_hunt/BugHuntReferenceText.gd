extends RefCounted
## What a Bug Hunt screen prints about the squad's kit, read from the data files the game
## reads (Compendium p.172 standard load, p.178 armour, p.179 weapons, p.187 loadout,
## pp.188-189 support, and the grunt profile).
##
## The creation wizard's Equipment and Review steps printed five weapons' profiles, the
## armour save and the free Fire Team as UI literals, while the
## Mission step formatted the same weapons from bug_hunt_weapons.json. They agreed, but
## only by hand: a corrected value would have reached one screen and not the other.
## Profiles go through DisplayText.weapon_profile(), the one line every mode prints a
## weapon with.

const DisplayTextRef := preload("res://src/ui/components/common/DisplayText.gd")

const WEAPONS_PATH := "res://data/bug_hunt/bug_hunt_weapons.json"
const ARMOR_PATH := "res://data/bug_hunt/bug_hunt_armor.json"
const MISSIONS_PATH := "res://data/bug_hunt/bug_hunt_missions.json"
const SUPPORT_PATH := "res://data/bug_hunt/bug_hunt_support_teams.json"
const CREATION_PATH := "res://data/bug_hunt/bug_hunt_character_creation.json"
const SquadPanelScript := preload("res://src/ui/screens/bug_hunt/panels/BugHuntSquadPanel.gd")


## The grunt profile from the creation data, in the squad's own order and format.
static func grunt_profile_line() -> String:
	var stats: Variant = _load(CREATION_PATH).get("grunt_stats", {})
	if not (stats is Dictionary) or (stats as Dictionary).is_empty():
		return ""
	var parts := PackedStringArray()
	for pair in SquadPanelScript.stat_pairs_for(stats, false):
		parts.append("%s %s" % [pair[0], pair[1]])
	return " · ".join(parts)


static func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func weapon(weapon_id: String) -> Dictionary:
	for w in _load(WEAPONS_PATH).get("weapons", []):
		if w is Dictionary and str(w.get("id", "")) == weapon_id:
			return w
	return {}


## The standard-issue weapons (p.172: every trooper carries a Service Pistol).
static func standard_weapons() -> Array:
	var out: Array = []
	for w in _load(WEAPONS_PATH).get("weapons", []):
		if w is Dictionary and bool(w.get("is_standard_issue", false)):
			out.append(w)
	return out


static func standard_armor() -> Array:
	var out: Array = []
	for a in _load(ARMOR_PATH).get("armor", []):
		if a is Dictionary and bool(a.get("is_standard_issue", false)):
			out.append(a)
	return out


## "Pistol: Grants +1 to Brawling rolls." for each of the weapon's traits.
static func trait_lines(w: Dictionary) -> PackedStringArray:
	var traits: Dictionary = _load(WEAPONS_PATH).get("weapon_traits", {})
	var out := PackedStringArray()
	for t in w.get("traits", []):
		var info: Dictionary = traits.get(str(t), {})
		if not info.is_empty():
			out.append("%s: %s" % [str(info.get("name", t)), str(info.get("description", ""))])
	return out


## The profile line, with the trait names the book prints in its Traits column.
static func profile(w: Dictionary) -> String:
	var line: String = DisplayTextRef.weapon_profile(w)
	var traits: Dictionary = _load(WEAPONS_PATH).get("weapon_traits", {})
	var names := PackedStringArray()
	for t in w.get("traits", []):
		names.append(str(traits.get(str(t), {}).get("name", str(t).capitalize())))
	return line if names.is_empty() else "%s · %s" % [line, ", ".join(names)]


## p.178: "a saving throw on 5-6".
static func armor_line(a: Dictionary) -> String:
	return "Saving throw on %d-6" % int(a.get("save_value", 0))


## The p.187 mission loadout block: the three choices and the Hand Cannon swap.
static func loadout() -> Dictionary:
	var block: Variant = _load(MISSIONS_PATH).get("loadout", {})
	return block if block is Dictionary else {}


## The free Fire Team rule, as the support data states it (pp.188-189).
static func free_fire_team_rule() -> String:
	return str(_load(SUPPORT_PATH).get("free_fire_team", ""))


## The free Fire Team's contents, as the support table states them (pp.188-189).
static func fire_team_contents() -> String:
	for opt in _load(SUPPORT_PATH).get("support_options", []):
		if opt is Dictionary and str(opt.get("id", "")) == "fire_team":
			return str(opt.get("contents", ""))
	return ""
