class_name SheetDataContext
extends RefCounted

## Builds the data context the sheet manifests resolve against (T9-09, Aug 9 2026).
##
## WHY THIS EXISTS. The field manifests in `data/sheets/core/*.json` are hand-calibrated
## against the official Modiphius PNGs and describe a clean VIEW-MODEL:
## `campaign.crew[2].weapons[0].damage`, `campaign.ship.hull_current`, `world.danger`.
## Nothing ever built that view-model, so `SheetRenderer._resolve_source()` walked those
## paths against the raw `FiveParsecsCampaignCore` and found `crew_data` / `ship_data` /
## `danger_level` instead. Measured: **154 of 163 sources resolved to null**, i.e. the
## printed sheet came out 94.5% blank against a fully-populated campaign.
##
## The fix is this builder, NOT a rewrite of the manifests: the rects are CV-calibrated
## and the manifest names are the better vocabulary. Keep the view-model matching the
## manifests; do not drift the manifests toward the storage shape.
##
## DATA OWNERSHIP. This is a READ-ONLY projection. It must never mutate the campaign, and
## it is not a place to invent game values — every number here is copied from the
## canonical owner (see CLAUDE.md "Data Ownership"). Ship debt in particular comes from
## `campaign.ship_debt`, the canonical owner, NOT from `ship_data["debt"]`.
##
## BLANK IS A LEGITIMATE VALUE. This is a print form. A field with no backing data must
## resolve to "" so it renders as an empty box for the player to fill by hand — it must
## NOT resolve to null, because null is indistinguishable from a typo'd source path and
## that is exactly how the original bug hid. Anything genuinely absent from the data model
## is listed in _EMPTY_UNTIL_MODELLED below with the reason.

const _EQUIPMENT_DB_PATH := "res://data/equipment_database.json"

## Owner of the Interdiction record the Licensing Required block reads. Preloaded
## by path, not by class_name, per the project's stale-global-cache gotcha.
const InterdictionRuleRef = preload("res://src/core/world/InterdictionRule.gd")

## Trait rows printed on the World Record Sheet (manifest addresses world.traits[0..2]).
const _WORLD_TRAIT_ROWS := 3

## Weapon rows printed per character on the Crew Log. The weapon table is ONE box with
## five columns and TWO writing rows under a single set of captions — measured off
## assets/sheets/core/crew_log.png, not assumed.
const WEAPON_SLOTS := 2

## Sheet fields whose data does not exist anywhere in the campaign model yet. They
## resolve to "" (blank box on the printed form) rather than null. Listed explicitly so
## the next person knows these are DELIBERATE, not missed:
##   campaign.notes           — no free-text campaign note field exists
##   ship.upgrades_text       — ship upgrades are not modelled on ship_data
##   ship.fuel                — fuel is a travel cost, not persisted ship state
##   world.invading_force     — the book never defines this box (it appears ONLY on the
##                              printed sheet, Appendix X, and nowhere in the rules text),
##                              and while p.121 step 6 makes the invader "the enemy you
##                              just battled", record_invaded_planet() persists only
##                              {id, name, war_modifier} and runs a turn later at
##                              flee-time, where the enemy is long gone. Free-text box.
##   world.turns_visited      — PlanetDataManager stores discovered_on_turn, not a count
##   world.notes              — no per-world player note field exists
##   journal.last_battle.credits_earned
##                            — no producer anywhere writes battle credits onto the
##                              result or the journal entry; addressed by no manifest.
##
## world.license_* and world.war_progress USED to be on this list. Both were wrong —
## see _licensing() and _war_progress(), which derive them from persisted state.

static var _weapon_index: Dictionary = {}
static var _index_built: bool = false


## Build the full context. `campaign` is a FiveParsecsCampaignCore (or null),
## `world` the current planet Dictionary (or null), `journal_entries` the raw entry array.
static func build(campaign: Object, world: Variant, journal_entries: Array) -> Dictionary:
	return {
		"campaign": _build_campaign(campaign),
		# The World Record Sheet's Licensing and Invasion Status blocks describe
		# THIS world but are stored on the campaign (progress_data["interdiction"],
		# invaded/lost/liberated planet lists), so the world view needs both.
		"world": _build_world(world, campaign),
		"journal": _build_journal(journal_entries),
	}


# ── campaign ───────────────────────────────────────────────────────────────────

static func _build_campaign(campaign: Object) -> Dictionary:
	if campaign == null:
		return _empty_campaign()

	var members: Array = []
	if "crew_data" in campaign and campaign.crew_data is Dictionary:
		var raw: Variant = (campaign.crew_data as Dictionary).get("members", [])
		if raw is Array:
			members = raw

	var captain: Dictionary = {}
	var crew: Array = []
	for m in members:
		if not m is Dictionary:
			continue
		var md: Dictionary = m
		# The captain is identified by the is_captain flag on the member, which is the
		# canonical marker (CLAUDE.md: "captain MUST be in members array"). captain_data
		# is a mirror and is only the fallback.
		if captain.is_empty() and bool(md.get("is_captain", false)):
			captain = _build_character(md)
		else:
			crew.append(_build_character(md))
	if captain.is_empty() and "captain_data" in campaign \
			and campaign.captain_data is Dictionary \
			and not (campaign.captain_data as Dictionary).is_empty():
		captain = _build_character(campaign.captain_data)

	var stash: Array = []
	if "equipment_data" in campaign and campaign.equipment_data is Dictionary:
		var s: Variant = (campaign.equipment_data as Dictionary).get("equipment", [])
		if s is Array:
			stash = s

	var turns: Variant = ""
	if "progress_data" in campaign and campaign.progress_data is Dictionary:
		turns = int((campaign.progress_data as Dictionary).get("turns_played", 0))

	return {
		"campaign_name": str(campaign.get("campaign_name")) if "campaign_name" in campaign else "",
		"credits": int(campaign.get("credits")) if "credits" in campaign else 0,
		"story_points": int(campaign.get("story_points")) if "story_points" in campaign else 0,
		"patrons_count": _array_size(campaign, "patrons"),
		"rivals_count": _array_size(campaign, "rivals"),
		# Three printed blocks each on the World Record Sheet (measured).
		"patron_rows": _contact_rows(
			campaign.get("patrons") if "patrons" in campaign else [], 3, "benefit"),
		"rival_rows": _contact_rows(
			campaign.get("rivals") if "rivals" in campaign else [], 3, "notes"),
		"stash_items_text": _join_names(stash),
		"story_track_label": _story_label(campaign),
		"story_event": _story_event_number(campaign),
		"story_clock": _story_clock(campaign),
		"quest_rumors": int(campaign.get("quest_rumors")) if "quest_rumors" in campaign else 0,
		"notes": "",             # see _EMPTY_UNTIL_MODELLED
		"progress_data": {"turns_played": turns},
		"captain": captain if not captain.is_empty() else _build_character({}),
		"crew": crew,
		"ship": _build_ship(campaign),
	}


static func _empty_campaign() -> Dictionary:
	return {
		"campaign_name": "", "credits": 0, "story_points": 0,
		"patrons_count": 0, "rivals_count": 0, "stash_items_text": "",
		"patron_rows": _contact_rows([], 3, "benefit"),
		"rival_rows": _contact_rows([], 3, "notes"),
		"story_track_label": "", "story_event": "", "story_clock": "",
		"quest_rumors": 0, "notes": "",
		"progress_data": {"turns_played": ""},
		"captain": _build_character({}), "crew": [], "ship": _build_ship(null),
	}


static func _array_size(campaign: Object, prop: String) -> int:
	if not (prop in campaign):
		return 0
	var v: Variant = campaign.get(prop)
	return (v as Array).size() if v is Array else 0


## ⚠ THE KEYS HERE MUST MATCH `StoryTrackSystem.serialize()` EXACTLY.
##
## The persisted keys are `story_clock_ticks` and `current_event_index` (see
## StoryTrackSystem.gd:405, written at CampaignPhaseManager.gd:1859 — the single
## write site). This builder originally read `clock` and `current_event_name`,
## which the story track has never written, so both fields resolved to "" on
## every campaign including active ones. That passed the "every source resolves"
## test, because resolving is not the same as being right — the same lesson that
## produced this file in the first place, one level up.
static func _story_label(campaign: Object) -> String:
	var number: int = _story_event_index(campaign)
	if number <= 0:
		return ""
	var title: String = _story_event_title(number)
	return title if not title.is_empty() else "Event %d" % number


## The human-facing story event number (1-7), for the small "Event" box.
static func _story_event_number(campaign: Object) -> Variant:
	var number: int = _story_event_index(campaign)
	return number if number > 0 else ""


## 1-based current event, or 0 when no story track is running.
static func _story_event_index(campaign: Object) -> int:
	if not ("story_track_enabled" in campaign) or not bool(campaign.get("story_track_enabled")):
		return 0
	var st: Dictionary = _story_state(campaign)
	if st.is_empty() or not bool(st.get("is_story_track_active", false)):
		return 0
	# current_event_index is 0-based in StoryTrackSystem; the book numbers the
	# seven events 1-7 and that is what belongs on a printed sheet.
	return int(st.get("current_event_index", 0)) + 1


## Title from the event's own JSON, so the sheet never carries a second copy of
## a name the data files already own.
static func _story_event_title(number: int) -> String:
	var path := "res://data/story_track_missions/"
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return ""
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text: String = FileAccess.get_file_as_string(path + file_name)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and int((parsed as Dictionary).get("event_number", -1)) == number:
			return str((parsed as Dictionary).get("title", ""))
	return ""


static func _story_clock(campaign: Object) -> Variant:
	var st: Dictionary = _story_state(campaign)
	if st.is_empty() or not st.has("story_clock_ticks"):
		return ""
	return int(st.get("story_clock_ticks", 0))


static func _story_state(campaign: Object) -> Dictionary:
	if campaign == null or not ("progress_data" in campaign):
		return {}
	if not (campaign.progress_data is Dictionary):
		return {}
	var st: Variant = (campaign.progress_data as Dictionary).get("story_track", {})
	return st if st is Dictionary else {}


# ── ship ───────────────────────────────────────────────────────────────────────

static func _build_ship(campaign: Object) -> Dictionary:
	var sd: Dictionary = {}
	if campaign != null and "ship_data" in campaign and campaign.ship_data is Dictionary:
		sd = campaign.ship_data
	# Debt reads from campaign.ship_debt — the canonical owner. ship_data["debt"] is a
	# mirror written at save time and is only the fallback.
	var debt: int = 0
	if campaign != null and "ship_debt" in campaign:
		debt = int(campaign.get("ship_debt"))
	elif sd.has("debt"):
		debt = int(sd.get("debt", 0))
	return {
		"name": str(sd.get("name", "")),
		"hull_current": int(sd.get("hull_points", sd.get("hull", 0))),
		"debt": debt,
		"traits_text": _join_names(sd.get("traits", [])),
		"upgrades_text": _join_names(sd.get("upgrades", [])),  # see _EMPTY_UNTIL_MODELLED
		"fuel": "",                                            # see _EMPTY_UNTIL_MODELLED
	}


# ── character ──────────────────────────────────────────────────────────────────

static func _build_character(m: Dictionary) -> Dictionary:
	var equipment: Array = []
	var raw_eq: Variant = m.get("equipment", [])
	if raw_eq is Array:
		equipment = raw_eq

	# ⚠ The printed weapon table has TWO writing rows under one set of captions
	# (Weapon | Range | Shots | Damage | Traits), i.e. TWO weapon slots per character.
	# Measured off the artwork Aug 9 2026 — the manifest only ever addressed slot 1, so
	# a second weapon was dropped from the sheet entirely: Nyx Ward's Colony Rifle was
	# nowhere on the printed page. It did not reach Gear either, because the gear branch
	# only ever saw NON-weapons.
	#
	# First correction routed the extra weapon into Gear. That was wrong once the second
	# row was found — a weapon belongs in a weapon slot, with its Range/Shots/Damage
	# printed under the right captions. Gear is now the overflow for weapon THREE onward,
	# where a printed record filed in a less specific box still beats losing it.
	var weapons: Array = []
	var gear: Array = []
	for item in equipment:
		var item_name: String = _item_name(item)
		if item_name.is_empty():
			continue
		var w: Dictionary = _lookup_weapon(item_name)
		if w.is_empty():
			gear.append(item_name)
		elif weapons.size() < WEAPON_SLOTS:
			weapons.append(w)
		else:
			gear.append(item_name)
	# The manifest addresses weapons[0] AND weapons[1] unconditionally, so both must
	# resolve. A blank weapon row is the correct printed output for an empty slot.
	while weapons.size() < WEAPON_SLOTS:
		weapons.append(_blank_weapon())

	var species_id: String = str(m.get("species_id", m.get("origin", "")))
	return {
		"character_name": str(m.get("character_name", m.get("name", ""))),
		"species_id": species_id,
		"species": _species_display_name(species_id),
		# JSON numbers arrive as floats; the sheet prints integers.
		"reaction": _stat(m, "reaction"),
		"speed": _stat(m, "speed"),
		"combat": _stat(m, "combat"),
		"toughness": _stat(m, "toughness"),
		"savvy": _stat(m, "savvy"),
		"luck": _stat(m, "luck"),
		"experience": _stat(m, "experience"),
		"notes": str(m.get("player_notes", "")),
		"gear_text": _join_names(gear),
		"weapons": weapons,
	}


## The species' printed name, resolved from the file that owns it.
##
## The sheet used to print the raw storage id — a crew log that read "kerin",
## "genetic_uplift", "de_converted". `data/character_species.json` carries a
## `name` for all 28 ids and is the single source of truth for them, so it is
## read rather than reformatted.
##
## ⚠ Do NOT "simplify" this to `species_id.capitalize()`. Three of the 28 come out
## wrong that way and one of them is a core species:
##     kerin               -> "Kerin"                (book: K'Erin — apostrophe)
##     de_converted        -> "De Converted"         (book: De-converted — hyphen)
##     primitive_character -> "Primitive Character"  (book: Primitive)
## Legacy saves store `origin` as a numeric enum, so a non-matching id is normal
## and must fall back to something printable rather than to "".
static func _species_display_name(species_id: String) -> String:
	if species_id.is_empty():
		return ""
	var species: Dictionary = SpeciesDataService.get_species(species_id)
	var display: String = str(species.get("name", ""))
	if not display.is_empty():
		return display
	# Unknown id (legacy numeric origin, or a species not in the JSON). Printing
	# the raw token beats printing nothing on a form the player reads.
	#
	# ⚠ capitalize() takes the RAW snake_case id — that is the input it is built
	# for ("not_a_real_species" -> "Not A Real Species"). Replacing the
	# underscores FIRST and passing "not a real species" returns
	# "Not aA rReal sSpecies", because it also inserts a space before each
	# interior capital it produces. Observed, not theorised.
	return species_id.capitalize()


static func _stat(m: Dictionary, key: String) -> Variant:
	if not m.has(key):
		return ""
	return int(m.get(key, 0))


static func _item_name(item: Variant) -> String:
	if item is String:
		return item
	if item is Dictionary:
		return str((item as Dictionary).get("name", ""))
	return ""


static func _blank_weapon() -> Dictionary:
	return {"name": "", "range": "", "shots": "", "damage": "", "traits": ""}


# ── weapon stats (canonical: data/equipment_database.json) ─────────────────────

## Weapon stats are NEVER derived here — they are read from equipment_database.json,
## which CLAUDE.md names as the owner of weapon range/shots/damage/traits. An item that
## is not a weapon (armor, gear) returns {} and is routed to gear_text instead.
## Normalised weapon-name key: lowercase, no spaces, no punctuation.
##
## ⚠ THE BOOK SPELLS SOME WEAPONS TWO WAYS, so an exact-name match silently loses
## real weapons. "Handgun" is the spelling on the Low Tech Weapon Table (Core Rules
## p.28) and in the worked example (p.34) — and it is what save data actually
## contains — while the stat table on p.50 prints "Hand gun", which is the form
## `equipment_database.json` carries.
##
## Found on the device's own legacy save: a stash "Handgun" resolved to nothing, so
## the sheet printed it as GEAR with no Range/Shots/Damage instead of as the weapon
## it is (12", 1 shot, 0 damage, Pistol — p.50).
##
## Normalising the key is the right fix here, NOT adding a second database entry:
## the database is complete and book-exact (36 weapons, matching p.50-52), and a
## duplicate row would be a second source of truth for one weapon. This also
## absorbs "Marksman's Rifle" vs "Marksmans Rifle" and similar apostrophe drift.
static func _weapon_key(raw: String) -> String:
	var out: String = raw.strip_edges().to_lower()
	for ch in [" ", "-", "'", "’", "."]:
		out = out.replace(ch, "")
	return out


static func _lookup_weapon(item_name: String) -> Dictionary:
	_ensure_index()
	var key: String = _weapon_key(item_name)
	if not _weapon_index.has(key):
		return {}
	var w: Dictionary = _weapon_index[key]
	return {
		"name": str(w.get("name", item_name)),
		"range": int(w.get("range", 0)),
		"shots": int(w.get("shots", 0)),
		"damage": int(w.get("damage", 0)),
		"traits": _join_names(w.get("traits", [])),
	}


static func _ensure_index() -> void:
	if _index_built:
		return
	_index_built = true
	var f: FileAccess = FileAccess.open(_EQUIPMENT_DB_PATH, FileAccess.READ)
	if f == null:
		push_warning("SheetDataContext: cannot open %s" % _EQUIPMENT_DB_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		push_warning("SheetDataContext: %s is not a Dictionary" % _EQUIPMENT_DB_PATH)
		return
	var weapons: Variant = (parsed as Dictionary).get("weapons", [])
	if not weapons is Array:
		return
	for w in weapons:
		if w is Dictionary:
			# Index under the SAME normalisation the lookup uses, or the two
			# disagree and every name with a space stops resolving.
			_weapon_index[_weapon_key(str((w as Dictionary).get("name", "")))] = w


## Test seam — forces a reload of the weapon index.
static func reset_cache() -> void:
	_weapon_index = {}
	_index_built = false


# ── world / journal ────────────────────────────────────────────────────────────

static func _build_world(world: Variant, campaign: Object = null) -> Dictionary:
	var w: Dictionary = _as_dictionary(world)
	var licensing: Dictionary = _licensing(campaign)
	return {
		"name": str(w.get("name", "")),
		"type": str(w.get("type_name", w.get("type", ""))),
		# The planet stores danger_level; the sheet calls the field "danger".
		"danger": int(w.get("danger_level", 0)) if w.has("danger_level") else "",
		# Padded to the printed row count: a world with one trait must still resolve
		# traits[1] and traits[2] to a blank box rather than null. The view-model is
		# allowed to mirror the form here — if the sheet ever gains a fourth trait row,
		# bump _WORLD_TRAIT_ROWS (test_an_empty_campaign_... will catch it if you don't).
		"traits": _string_list(w.get("traits", []), _WORLD_TRAIT_ROWS),
		# The artwork prints ONE multi-line "World Traits" box, not three rows —
		# measured on assets/sheets/core/world_record_sheet.png. `traits[0..2]` is
		# kept because other consumers use it; the sheet reads this.
		"traits_text": _join_names(w.get("traits", [])),
		# Licensing Required prints three octagons — Yes | Obtained | No, left to
		# right on the artwork, with Yes and Obtained joined by a connector rule, so
		# a licensed world ticks BOTH of those and never "No".
		#
		# This block used to be blank-until-modelled on the belief that "p.75
		# Interdiction is a per-roll check, not planet state". That was wrong:
		# InterdictionRule persists {active, until_turn, licensed} in
		# progress_data["interdiction"], rewritten on EVERY arrival precisely so an
		# old world's licence cannot leak forward. It is exactly this world's state.
		"license_required": licensing.get("required", ""),
		"license_obtained": licensing.get("obtained", ""),
		"license_not_required": licensing.get("not_required", ""),
		# p.126 step 14. Blank when this world is not tracked — a world that was
		# never Invaded has no war to report, which is what an empty box says.
		"war_progress": _war_progress(campaign, str(w.get("id", ""))),
		"invading_force": "",  # see _EMPTY_UNTIL_MODELLED
		"turns_visited": "",  # see _EMPTY_UNTIL_MODELLED
		"notes": "",          # see _EMPTY_UNTIL_MODELLED
	}


## Coerce the current world into the Dictionary the view-model reads.
##
## ⚠ `PlanetDataManager.get_current_planet()` returns a **PlanetData OBJECT**, not a
## Dictionary — it is an inner class with property access (`planet.visit_count`),
## which is how CampaignDashboard consumes it. This builder used to say
## `world if world is Dictionary else {}`, so on device the entire World block of
## the World Record Sheet printed blank — World Name and World Traits empty while
## the dashboard, one screen away, showed "Joffre VI / Adventurous Population".
##
## The suite could not see it because its fixture passed a hand-built Dictionary:
## the same fabricated-fixture failure as the journal entry, in the adjacent
## function. `serialize()` emits exactly the keys addressed here (id, name,
## type_name, danger_level, traits), so it IS the conversion — do not re-derive it.
static func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	if value is Object and (value as Object).has_method("serialize"):
		var s: Variant = (value as Object).call("serialize")
		return s if s is Dictionary else {}
	return {}


## The three Licensing Required octagons, as truthy/blank checkbox values.
##
## Returns all three blank when the arrival check has never run for this campaign
## (no "interdiction" record at all): the game does not know whether a licence is
## required here, and ticking "No" would assert something never determined.
## Blank means "player, fill this in" — which is correct for a print form.
static func _licensing(campaign: Object) -> Dictionary:
	var blank := {"required": "", "obtained": "", "not_required": ""}
	if campaign == null or not ("progress_data" in campaign):
		return blank
	var pd: Variant = campaign.get("progress_data")
	if not (pd is Dictionary) or not (pd as Dictionary).has(InterdictionRuleRef.STATE_KEY):
		return blank
	var s: Variant = (pd as Dictionary)[InterdictionRuleRef.STATE_KEY]
	if not (s is Dictionary):
		return blank
	var active: bool = bool((s as Dictionary).get("active", false))
	var licensed: bool = bool((s as Dictionary).get("licensed", false))
	return {
		"required": active,
		"obtained": active and licensed,
		"not_required": not active,
	}


## This world's Galactic War status, in the book's own words (Core Rules p.126).
##
## The 2D6 result is not persisted, but the three tracked lists it maintains are,
## and they are equivalent: a world sits in exactly one of invaded (Contested),
## lost (Lost to Unity) or liberated (Unity Victorious). "Making Ground" leaves no
## separate marker either — its effect IS the accumulated +1, so a tracked world
## carrying a modifier reports it rather than pretending the roll never happened.
static func _war_progress(campaign: Object, world_id: String) -> String:
	if campaign == null or world_id.is_empty():
		return ""
	if world_id in _campaign_array(campaign, "lost_planets"):
		return "Lost to Unity — cannot be visited again."
	if world_id in _campaign_array(campaign, "liberated_planets"):
		return "Unity Victorious — world open again; Invasion Threat rolls here at -2."
	for tracked in _campaign_array(campaign, "invaded_planets"):
		var tid: String = ""
		var modifier: int = 0
		if tracked is Dictionary:
			tid = str((tracked as Dictionary).get("id", ""))
			modifier = int((tracked as Dictionary).get("war_modifier", 0))
		else:
			tid = str(tracked)
		if tid != world_id:
			continue
		if modifier > 0:
			return "Contested — Making Ground (+%d to future rolls)." % modifier
		return "Contested."
	return ""


static func _campaign_array(campaign: Object, prop: String) -> Array:
	if not (prop in campaign):
		return []
	var v: Variant = campaign.get(prop)
	return v if v is Array else []


## Patron / Rival rows for the World Record Sheet.
##
## The artwork prints THREE "Patron + Benefit" blocks and THREE "Rival Type + Notes"
## blocks. Padded to that count so an empty slot resolves to a blank box rather than
## null — a print form is meant to have empty boxes.
static func _contact_rows(source: Variant, rows: int, note_key: String) -> Array:
	var out: Array = []
	var list: Array = source if source is Array else []
	for i in range(rows):
		var entry: Dictionary = {}
		if i < list.size() and list[i] is Dictionary:
			entry = list[i]
		out.append({
			"name": str(entry.get("name", "")),
			# Rivals print a "Type" caption; patrons print "Benefit".
			"detail": str(entry.get(note_key, entry.get("type", ""))),
		})
	return out


static func _build_journal(entries: Array) -> Dictionary:
	var last_battle: Dictionary = {}
	for i in range(entries.size() - 1, -1, -1):
		var e: Variant = entries[i]
		if e is Dictionary and str((e as Dictionary).get("type", "")) == "battle":
			last_battle = e
			break
	# A journal entry's battle facts live in `stats`, NOT at the top level.
	# CampaignJournal.create_entry() assembles every entry from a fixed key set
	# (id/turn_number/timestamp/type/title/description/mood/tags/location/stats/…)
	# and DROPS anything else, so the top-level reads this builder used to do —
	# mission_type, deployment_condition, enemy_count — could never hit. They
	# resolved to "" rather than null, which is a legal blank on a print form, so
	# 28 green tests and the T9-09 non-null sweep all passed while five of the
	# Encounter Log's six boxes printed empty on every real campaign.
	# The top-level fallback is kept only for hand-built dicts; `stats` is truth.
	var raw_stats: Variant = last_battle.get("stats", {})
	var st: Dictionary = raw_stats if raw_stats is Dictionary else {}
	var category: String = _first_non_empty(st, last_battle, ["enemy_category"])
	var enemy_name: String = _first_non_empty(st, last_battle, ["enemy_type", "enemy_faction"])
	var mission_type: String = _first_non_empty(st, last_battle, ["mission_type"])
	var objective: String = _first_non_empty(st, last_battle, ["objective"])
	return {
		"entries": entries,
		"last_battle": {
			"mission_type": mission_type,
			"objective": objective,
			# What the "Mission" box wants: the job, plus the p.89 objective when
			# one is recorded. Composed here (and named as a label) so the sheet
			# does not have to pick between two half-answers.
			"mission_label": _join_parts([mission_type, objective], " — "),
			# The Encounter Log prints a "Deployment Conditions" box (p.88 condition).
			"deployment_condition": _first_non_empty(
				st, last_battle, ["deployment_condition", "condition"]),
			# "Encounter Type" = the Encounter Table the opposition came from
			# (Criminal Elements / Hired Muscle / Interested Parties / Roving
			# Threats, pp.94-103). Falls back to the individual enemy's name when
			# only that was recorded — a real answer beats an empty box.
			"encounter_type": category if not category.is_empty() else enemy_name,
			"enemy_type": enemy_name,
			"enemy_category": category,
			"enemy_count": int(st.get("enemy_count", last_battle.get("enemy_count", 0))) \
				if (st.has("enemy_count") or last_battle.has("enemy_count")) else "",
			"result": _first_non_empty(st, last_battle, ["battle_result", "result"]),
			# p.89 Notable Sight — the "Shiny Bits" box. SHINY_BITS is one of its
			# nine results, and the sheet is named after it.
			"notable_sight": _sight_label(st),
			"credits_earned": int(st.get("credits_earned", 0)) \
				if st.has("credits_earned") else "",  # see _EMPTY_UNTIL_MODELLED
			"xp_earned": int(st.get("xp_gained", last_battle.get("xp_earned", 0))) \
				if (st.has("xp_gained") or last_battle.has("xp_earned")) else "",
			"notes": str(last_battle.get("notes", last_battle.get("description", ""))),
		},
	}


## First non-empty value for any of `keys`, checking `stats` before the entry's
## top level. Returns "" when none is present — never null.
static func _first_non_empty(stats: Dictionary, entry: Dictionary, keys: Array) -> String:
	for k in keys:
		for source in [stats, entry]:
			var v: String = str((source as Dictionary).get(k, ""))
			if not v.is_empty():
				return v
	return ""


## The Notable Sight as one printable line: "Shiny bits — Gain 1 credit."
##
## SENTENCE case, not Title case, because that is how Core Rules p.89 prints all
## nine results: "Nothing special", "Priority target", "Shiny bits", "Really shiny
## bits", "Person of interest", "Peculiar item", "Curious item". capitalize() would
## give "Person Of Interest", which is not the book's text — and the book is the
## dictionary for every game term in this project.
##
## NOTHING is a real rolled outcome, not an absence, so it prints "None" rather
## than an empty box: blank has to keep meaning "not rolled".
static func _sight_label(stats: Dictionary) -> String:
	var raw: String = str(stats.get("notable_sight", ""))
	if raw.is_empty():
		return ""
	if raw.to_upper() == "NOTHING":
		return "None"
	var words: String = raw.to_lower().replace("_", " ").strip_edges()
	if words.is_empty():
		return ""
	var name: String = words.substr(0, 1).to_upper() + words.substr(1)
	return _join_parts([name, str(stats.get("notable_sight_effect", ""))], " — ")


## Joins the non-empty parts with `sep`. Keeps a missing half from leaving a
## dangling separator on the printed sheet.
static func _join_parts(parts: Array, sep: String) -> String:
	var kept: PackedStringArray = []
	for p in parts:
		var s: String = str(p).strip_edges()
		if not s.is_empty():
			kept.append(s)
	return sep.join(kept)


# ── helpers ────────────────────────────────────────────────────────────────────

## Renders a list as one comma-separated line. Accepts Strings or {name: ...} Dicts,
## because equipment arrays are Array[String] on a character but Dictionaries elsewhere.
static func _join_names(value: Variant) -> String:
	if value is String:
		return value
	if not (value is Array):
		return ""
	var out: PackedStringArray = []
	for item in (value as Array):
		var n: String = _item_name(item)
		if not n.is_empty():
			out.append(n)
	return ", ".join(out)


## Always returns an Array of Strings so `world.traits[0]` resolves to printable text
## rather than a Dictionary. Padded with "" up to `min_rows` so a short list still
## resolves every index the printed form addresses.
static func _string_list(value: Variant, min_rows: int = 0) -> Array:
	var out: Array = []
	if value is Array:
		for item in (value as Array):
			out.append(_item_name(item))
	while out.size() < min_rows:
		out.append("")
	return out
