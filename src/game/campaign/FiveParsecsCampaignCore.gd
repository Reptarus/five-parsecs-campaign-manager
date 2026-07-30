class_name FiveParsecsCampaignCore
extends Resource

## Atomic save writer. All four cores share ONE implementation so the write path
## cannot drift between gamemodes again - see src/core/state/SaveFileWriter.gd.
const SaveFileWriterRef = preload("res://src/core/state/SaveFileWriter.gd")

## Five Parsecs Campaign Core Resource
## Framework Bible compliant: Simple data container with validation
## Stores complete campaign data for save/load operations

## Emitted whenever the current world changes. initialize_world() is the SINGLE
## writer of world_data, so this is the one chokepoint for world changes (creation
## and travel). CampaignPhaseManager connects to it (world-arrival handling +
## galaxy-map/PlanetDataManager sync). Per Godot 4.6 best practice the Resource
## only EMITS — the autoload handler does the work; the Resource never touches it.
signal world_changed(world_data: Dictionary)

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var difficulty: int = 0
@export var ironman_mode: bool = false
## Campaign crew size setting (Core Rules p.63): 4, 5, or 6. Controls enemy number
## formula, deployment cap, and reaction dice. NOT the same as roster count.
@export var campaign_crew_size: int = 6
@export var created_at: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0"
@export var game_phase: String = "creation"

# Core campaign data sections
var crew_data: Dictionary = {}
var captain_data: Dictionary = {}
var ship_data: Dictionary = {}
var equipment_data: Dictionary = {}
var world_data: Dictionary = {}
var progress_data: Dictionary = {}

# Campaign resources (accumulated from character creation)
var credits: int = 0
var story_points: int = 0
var supplies: int = 0
var reputation: int = 0
var patrons: Array = []
var rivals: Array = []
var quest_rumors: int = 0
var victory_conditions: Dictionary = {}  # Victory condition configuration
var victory_conditions_locked: bool = false  # Core Rules p.64: "cannot be changed once selected"

# SPRINT 6.1: House rules configuration (persisted from wizard)
var house_rules: Array = []

# SPRINT 6.2: Story track setting (persisted from wizard)
var story_track_enabled: bool = false

# Stars of the Story emergency ability state (Core Rules p.67)
var stars_of_the_story: Dictionary = {}

# Story Point per-turn spending limits (Core Rules pp.66-67)
var story_point_turn_state: Dictionary = {}

# Phase 30: Red Zone Jobs (Core Rules Appendix III)
var red_zone_licensed: bool = false
var red_zone_turns_completed: int = 0

# Galactic War Progress (Core Rules p.126 step 14)
# "If you are tracking any planets that were previously Invaded, roll 2D6."
# GalacticWarProcessor implements that table faithfully but read these four
# fields off the campaign, and NONE of them existed — so `invaded_planets` was
# permanently empty, the step returned at its own is_empty() guard, and the
# 2D6 roll never happened in any campaign. Nothing ever recorded an invaded
# world either; see record_invaded_planet(), called when the invasion resolves.
var invaded_planets: Array = []      # [{id, name, war_modifier}] — actively tracked
var lost_planets: Array = []         # ids: "cannot be visited again"
var liberated_planets: Array = []    # ids: "can now be visited again"
var invasion_modifiers: Dictionary = {}  # planet_id -> int, the p.126 "-2 future Invasion Threat"

# Phase 30: Being Without a Ship (Core Rules p.59)
var has_ship: bool = true
var ship_debt: int = 0  # Remaining loan amount (max financed 70cr)

# DLC dependency tracking — one-way stamp, only grows
var required_dlc_packs: Array[String] = []

# QoL data stored for deferred loading (scene tree not ready during _init)
var _pending_qol_data: Dictionary = {}

func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	last_modified = created_at
	# Progress counters only. Resources (credits/supplies/reputation/story_points)
	# live as top-level @vars on this Resource; duplicating them here created a
	# write-only sync target nobody ever read back (persistence audit, Phase 2.1).
	progress_data = {
		"turns_played": 0,
		"missions_completed": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"suspended_crew": [],  # Suspension Pod (Core Rules p.62)
	}

func get_campaign_id() -> String:
	if campaign_id.is_empty() and not campaign_name.is_empty():
		var ts = str(int(Time.get_unix_time_from_system()))
		campaign_id = campaign_name.to_lower().replace(" ", "_") + "_" + ts
	elif campaign_id.is_empty():
		campaign_id = "campaign_" + str(int(Time.get_unix_time_from_system()))
	return campaign_id

func require_dlc_pack(dlc_id: String) -> void:
	## Stamp this campaign as depending on a DLC pack. One-way: only grows.
	if dlc_id not in required_dlc_packs:
		required_dlc_packs.append(dlc_id)

## Crew index cache for O(1) lookups by character_id.
## Rebuilt on initialize_crew() and invalidated by any mutation that changes
## the crew membership list. See get_crew_member_by_id().
var _crew_id_index: Dictionary = {}  # character_id -> int (index into members)

## Data Initialization Methods

func initialize_crew(data: Dictionary) -> void:
	## Initialize crew data from campaign creation
	crew_data = data.duplicate(true)
	# Also normalise here, not only on load: a crew built from a source that does
	# not go through Character.to_dictionary() would otherwise carry one spelling.
	_normalize_crew_stat_keys()
	_rebuild_crew_id_index()
	_update_modified_time()

func add_crew_member(member_dict: Dictionary) -> void:
	## Append an imported/transferred character to the crew roster (NOT the captain).
	## The single mutation chokepoint for crew additions made after creation — e.g.
	## a Bug Hunt veteran mustering in (CharacterTransferService). Keeps the
	## _crew_id_index in sync so get_crew_member_by_id() resolves the new member.
	if not crew_data.has("members") or not (crew_data["members"] is Array):
		crew_data["members"] = []
	var safe: Dictionary = member_dict.duplicate(true)
	safe["is_captain"] = false  # only the captain carries is_captain; imports never do
	crew_data["members"].append(safe)
	_rebuild_crew_id_index()
	_update_modified_time()

func record_invaded_planet(planet_id: String, planet_name: String = "") -> bool:
	## Start tracking a world that has been Invaded (Core Rules p.126 step 14:
	## "If you are tracking any planets that were previously Invaded, roll 2D6").
	##
	## The single mutation chokepoint for the Galactic War tracked list. NOTHING
	## called anything like this before — the invasion check set a transient
	## `invasion_pending` flag that TravelPhase consumed to force a flee, and the
	## world was then forgotten. So step 14's own is_empty() guard returned
	## immediately, every campaign, and the 2D6 table never rolled once.
	##
	## Idempotent: a world already tracked, already lost, or already liberated is
	## not re-added (a liberated world can be invaded again only after it leaves
	## the liberated list, which the book does not describe, so we do not invent it).
	if planet_id.is_empty():
		return false
	if planet_id in lost_planets or planet_id in liberated_planets:
		return false
	for tracked in invaded_planets:
		if tracked is Dictionary and str(tracked.get("id", "")) == planet_id:
			return false
	invaded_planets.append({
		"id": planet_id,
		"name": planet_name if not planet_name.is_empty() else planet_id,
		"war_modifier": 0,
	})
	_update_modified_time()
	return true

func get_invasion_threat_modifier(planet_id: String) -> int:
	## The p.126 "Unity Victorious" aftermath: "all future Invasion Threat rolls
	## on this world are at -2". GalacticWarProcessor WROTE this into
	## invasion_modifiers and nothing ever read it, so a liberated world stayed
	## exactly as dangerous as before it was freed.
	if planet_id.is_empty():
		return 0
	return int(invasion_modifiers.get(planet_id, 0))

func remove_crew_member(character_id: String) -> bool:
	## Remove a crew member by id (character_id, or legacy "id"), rebuild the
	## _crew_id_index, and return true if a member was removed. Mutation chokepoint
	## for crew removals made after creation (e.g. the Campaign Editor). Matches ids
	## the same way as _rebuild_crew_id_index() so lookups stay consistent.
	if not crew_data.has("members") or not (crew_data["members"] is Array):
		return false
	var members: Array = crew_data["members"]
	for i in range(members.size()):
		var m = members[i]
		if m is Dictionary and str(m.get("character_id", m.get("id", ""))) == character_id:
			members.remove_at(i)
			_rebuild_crew_id_index()
			_update_modified_time()
			return true
	return false

func update_crew_member(character_id: String, member_dict: Dictionary) -> bool:
	## Replace an existing crew member (matched by id) in place, PRESERVING the
	## current is_captain flag — unlike add_crew_member, which forces is_captain=false.
	## This makes it the correct write-back for editing ANY member, including the
	## captain (who lives in members with is_captain=true). Rebuilds the _crew_id_index
	## and returns true if a member was updated. Mutation chokepoint for crew edits
	## made after creation (e.g. the Campaign Editor).
	if not crew_data.has("members") or not (crew_data["members"] is Array):
		return false
	var members: Array = crew_data["members"]
	for i in range(members.size()):
		var m = members[i]
		if m is Dictionary and str(m.get("character_id", m.get("id", ""))) == character_id:
			# MERGE, do not replace.
			#
			# Editors build member_dict from Character.to_dictionary(), which is a
			# NARROWING projection of a roster entry: the Character class does not
			# model roster-only keys, so they are absent from its output. A wholesale
			# replace therefore DELETED them. Confirmed casualties: in_sick_bay and
			# sick_bay_turns_remaining (written by CrewTaskComponent.gd:2283-2285), so
			# editing any crew member sprang them out of Sick Bay — re-counted for
			# upkeep against Core Rules p.76 and re-eligible for deployment. Same
			# exposure for locked_out_this_turn and injury_recovery_turns.
			#
			# Merging at this chokepoint covers every present and future editor path,
			# which patching one editor would not. Edited values win; keys the editor
			# never knew about survive.
			var merged: Dictionary = m.duplicate(true)
			merged.merge(member_dict.duplicate(true), true)
			# Captaincy comes from the CURRENT roster entry, not the edited dict —
			# the character creator does not carry the roster's is_captain semantics.
			merged["is_captain"] = bool(m.get("is_captain", false))
			members[i] = merged
			_rebuild_crew_id_index()
			_update_modified_time()
			return true
	return false

func set_captain(data: Dictionary) -> void:
	## Set captain data
	captain_data = data.duplicate(true)
	_update_modified_time()

func initialize_ship(data: Dictionary) -> void:
	## Initialize ship data
	ship_data = data.duplicate(true)
	_update_modified_time()

func set_starting_equipment(data: Dictionary) -> void:
	## Set starting equipment data
	equipment_data = data.duplicate(true)
	_update_modified_time()

func initialize_world(data: Dictionary) -> void:
	## Initialize world generation data. This is the ONLY writer of world_data;
	## emit world_changed so CampaignPhaseManager can sync the galaxy map + fire
	## the world-arrival event (creation and travel both route through here).
	world_data = data.duplicate(true)
	_update_modified_time()
	world_changed.emit(world_data)

func set_config(data: Dictionary) -> void:
	## Set campaign configuration
	if data.has("name"):
		campaign_name = data.name
	if data.has("difficulty"):
		difficulty = data.difficulty
	if data.has("ironman_mode"):
		ironman_mode = data.ironman_mode
	if data.has("campaign_crew_size"):
		campaign_crew_size = clampi(data.get("campaign_crew_size", 6), 4, 6)
	_update_modified_time()

func initialize_resources(data: Dictionary) -> void:
	## Initialize campaign resources from character creation.
	## Top-level @vars are the single source of truth — no progress_data mirror
	## (persistence audit, Phase 2.1).
	credits = data.get("credits", 0)
	story_points = data.get("story_points", 0)
	supplies = data.get("supplies", 0)
	reputation = data.get("reputation", 0)
	patrons = data.get("patrons", []).duplicate()
	rivals = data.get("rivals", []).duplicate()
	var rumors = data.get("quest_rumors", [])
	quest_rumors = rumors.size() if rumors is Array else rumors
	_update_modified_time()

func get_resources() -> Dictionary:
	## Get campaign resources
	return {
		"credits": credits,
		"story_points": story_points,
		"supplies": supplies,
		"reputation": reputation,
		"patrons": patrons.duplicate(),
		"rivals": rivals.duplicate(),
		"quest_rumors": quest_rumors
	}

## SPRINT 6.1: House Rules Methods

func set_house_rules(rules: Array) -> void:
	## Set house rules configuration from wizard
	house_rules = rules.duplicate()
	_update_modified_time()

func get_house_rules() -> Array:
	## Get house rules configuration
	return house_rules.duplicate()

## SPRINT 6.2: Story Track Methods

func set_story_track_enabled(enabled: bool) -> void:
	## Set story track enabled setting
	story_track_enabled = enabled
	_update_modified_time()

func get_story_track_enabled() -> bool:
	## Get story track enabled setting
	return story_track_enabled

## Victory Conditions Methods

func set_victory_conditions(conditions: Dictionary) -> void:
	## Set victory conditions configuration.
	## Core Rules p.64: "cannot add or change once the campaign starts."
	## After the first turn begins, this setter is locked and rejects changes.
	if victory_conditions_locked:
		push_warning("FiveParsecsCampaignCore: Victory conditions are locked (Core Rules p.64). Cannot modify after campaign starts.")
		return
	victory_conditions = conditions.duplicate(true)
	_update_modified_time()

func lock_victory_conditions() -> void:
	## Lock victory conditions permanently for this campaign.
	## Called when the campaign starts its first turn (CampaignPhaseManager.start_new_turn).
	victory_conditions_locked = true
	_update_modified_time()

func are_victory_conditions_locked() -> bool:
	return victory_conditions_locked

func get_victory_conditions() -> Dictionary:
	## Get victory conditions configuration
	return victory_conditions.duplicate(true)

## Validation Methods

func validate() -> bool:
	## Basic campaign validation
	if campaign_name.is_empty():
		return false
	if crew_data.is_empty():
		return false
	if captain_data.is_empty():
		return false
	return true

func get_validation_errors() -> Array[String]:
	## Get detailed validation errors
	var errors: Array[String] = []
	
	if campaign_name.is_empty():
		errors.append("Pick a name for your campaign. Anything memorable works.")

	if crew_data.is_empty():
		errors.append("Crew setup is empty. Head to the crew step to add members.")
	elif not crew_data.has("members") or crew_data.members.size() == 0:
		errors.append("Add at least one crew member to start the campaign.")

	if captain_data.is_empty():
		errors.append("Captain hasn't been set up yet. Head to the Captain step.")
	elif not captain_data.has("name") or captain_data.name.is_empty():
		errors.append("Give the Captain a name to continue.")
	
	return errors

## Serialization Methods

func to_dictionary() -> Dictionary:
	## Convert campaign to dictionary for saving
	return {
		"campaign_id": get_campaign_id(),
		"meta": {
			"campaign_id": get_campaign_id(),
			"campaign_name": campaign_name,
			"schema_version": schema_version,
			"difficulty": difficulty,
			"ironman_mode": ironman_mode,
			"campaign_crew_size": campaign_crew_size,
			"created_at": created_at,
			"last_modified": last_modified,
			"version": version,
			"game_phase": game_phase
		},
		"config": {
			"name": campaign_name,
			"difficulty": difficulty,
			"ironman_mode": ironman_mode,
			"campaign_crew_size": campaign_crew_size,
			# SPRINT 6.1/6.2: Include house rules and story track in config
			"house_rules": house_rules.duplicate(),
			"story_track_enabled": story_track_enabled
		},
		"crew": crew_data,
		"captain": captain_data,
		"ship": ship_data,
		"equipment": equipment_data,
		"world": world_data,
		"progress": progress_data,
		"resources": {
			"credits": credits,
			"story_points": story_points,
			"supplies": supplies,
			"reputation": reputation,
			"patrons": patrons.duplicate(),
			"rivals": rivals.duplicate(),
			"quest_rumors": quest_rumors
		},
		# SPRINT 6.1/6.2: Top-level for easy access
		"house_rules": house_rules.duplicate(),
		"story_track_enabled": story_track_enabled,
		# Campaign crew size setting (Core Rules p.63)
		"campaign_crew_size": campaign_crew_size,
		# Galactic War Progress (Core Rules p.126 step 14)
		"invaded_planets": invaded_planets.duplicate(true),
		"lost_planets": lost_planets.duplicate(),
		"liberated_planets": liberated_planets.duplicate(),
		"invasion_modifiers": invasion_modifiers.duplicate(),
		# Phase 30: Red Zone Jobs + Shipless State
		"red_zone_licensed": red_zone_licensed,
		"red_zone_turns_completed": red_zone_turns_completed,
		"has_ship": has_ship,
		"ship_debt": ship_debt,
		"victory_conditions": victory_conditions.duplicate(true),
		"victory_conditions_locked": victory_conditions_locked,
		"required_dlc_packs": required_dlc_packs.duplicate(),
		"stars_of_the_story": stars_of_the_story.duplicate(true),
		"story_point_turn_state": story_point_turn_state.duplicate(true),
		"qol_data": _build_qol_data()
	}

## GlobalEnums.Origin ordinal -> character_species.json id.
##
## Every target below was checked against data/character_species.json — note `kerin`,
## NOT `k_erin`; guessing that would have written an id nothing matches.
##
## The Origin enum conflates SPECIES with human HOMEWORLDS: CORE_WORLDS, FRONTIER,
## DEEP_SPACE, COLONY, HIVE_WORLD, FORGE_WORLD and PRISON_PLANET are all origins a
## HUMAN character can have, so they map to "human".
##
## NONE (0) is deliberately absent: a character saved with no origin has no
## recoverable species and is left untouched rather than guessed at.
const _ORIGIN_TO_SPECIES := {
	1: "human", 2: "engineer", 3: "feral", 4: "kerin", 5: "precursor",
	6: "soulless", 7: "swift", 8: "bot",
	9: "human", 10: "human", 11: "human", 12: "human", 13: "human", 14: "human",
	15: "krag", 16: "skulker", 17: "human",
}


## Re-derive species_id (and the flags that depend on it) for crew members saved by
## the narrowed writer.
##
## THE BUG THIS REPAIRS. Until CampaignCreationCoordinator._character_to_dict() was
## fixed, every NON-CAPTAIN crew member was written through a ~17-field projection
## that dropped species_id, is_bot and is_soulless. Measured across the 30 save files
## on disk: 0 of 73 non-captain members carry species_id. Fixing the writer does
## nothing for files already written, so those campaigns would keep running with all
## 16 Strange Character rules inert.
##
## DERIVED, NOT INVENTED. `origin` survived the projection, and it is the same datum
## the species was chosen from. It arrives as a String display name ("De-converted"),
## an int, or a float (the documented legacy-origin-float trap), so all three are
## handled. Anything that cannot be resolved is LEFT ALONE — an absent species_id is
## honest, a wrong one silently changes which rules fire.
## Give every loaded crew member BOTH spellings of the reaction stat.
##
## Character.to_dictionary() emits "reactions" AND "reaction" (Character.gd:1305-6)
## because the consumers are genuinely split: battle reads the plural
## (NoMinisResolver, BattlefieldTypes) while the crew UI reads the singular
## (CampaignDashboard:621, CrewManagementScreen:146). That fixed everything written
## AFTERWARDS — but every campaign saved before it contains only the plural, and
## nothing normalised it on load.
##
## So on any pre-existing save, CampaignDashboard's `member.get("reaction", 0)`
## missed and EVERY crew card rendered "R: 0". Confirmed on a real save during the
## Jul 30 core-loop walk: 6/6 members had "reactions", 0/6 had "reaction", and the
## dashboard showed R:0 on all six while C/T/S/Sv/L were correct baseline values.
##
## Fixed HERE, at the single load chokepoint, rather than by teaching each consumer
## to try both spellings — that band-aid has to be repeated at every read site and
## one will always be missed. Same reasoning as the `origin` float/String guards,
## which are still per-site and should move here too.
func _normalize_crew_stat_keys() -> void:
	if not (crew_data is Dictionary):
		return
	var members = crew_data.get("members", [])
	if not (members is Array):
		return
	for m in members:
		if not (m is Dictionary):
			continue
		var member: Dictionary = m
		if member.has("reactions") and not member.has("reaction"):
			member["reaction"] = member["reactions"]
		elif member.has("reaction") and not member.has("reactions"):
			member["reactions"] = member["reaction"]


func _backfill_crew_species() -> void:
	if not (crew_data is Dictionary):
		return
	var members = crew_data.get("members", [])
	if not (members is Array):
		return
	for m in members:
		if not (m is Dictionary):
			continue
		var member: Dictionary = m
		if not str(member.get("species_id", "")).is_empty():
			continue  # already correct — a captain, or written post-fix

		var species := ""
		var origin = member.get("origin", null)
		if origin is String and not (origin as String).is_empty():
			# Display name -> id, matching the captains that DID round-trip
			# ("De-converted" -> "de_converted", "Assault Bot" -> "assault_bot").
			species = (origin as String).to_lower().replace(" ", "_").replace("-", "_") \
				.replace("'", "")
		elif origin is int or origin is float:
			species = str(_ORIGIN_TO_SPECIES.get(int(origin), ""))

		if species.is_empty():
			continue
		member["species_id"] = species
		member["species_backfilled"] = true  # auditable: this was derived, not saved

		# Flags that are pure functions of species and were dropped alongside it.
		# is_bot gates the Core Rules p.98 "Bots never gain XP" rule.
		if not member.has("is_bot"):
			member["is_bot"] = species in ["bot", "assault_bot"]
		if not member.has("is_soulless"):
			member["is_soulless"] = species == "soulless"


func _build_qol_data() -> Dictionary:
	## Collect QoL system data for campaign save
	var qol: Dictionary = {}
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return qol
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("save_to_dict"):
		qol["journal"] = journal.save_to_dict()
	var npc_tracker = root.get_node_or_null("/root/NPCTracker")
	if npc_tracker and npc_tracker.has_method("serialize"):
		qol["npc_tracker"] = npc_tracker.serialize()
	var checklist = root.get_node_or_null("/root/TurnPhaseChecklist")
	if checklist and checklist.has_method("save_to_dict"):
		qol["turn_checklist"] = checklist.save_to_dict()
	# WorldEconomyManager: credits + transaction history
	var economy = root.get_node_or_null("/root/WorldEconomyManager")
	if economy and economy.has_method("serialize"):
		qol["world_economy"] = economy.serialize()
	# PlanetDataManager: per-planet progression data
	var planet_mgr = root.get_node_or_null("/root/PlanetDataManager")
	if planet_mgr and planet_mgr.has_method("serialize_all"):
		qol["planet_data"] = planet_mgr.serialize_all()
	# DLCManager: per-campaign ContentFlag toggles
	var dlc_mgr = root.get_node_or_null("/root/DLCManager")
	if dlc_mgr and dlc_mgr.has_method("serialize_campaign_flags"):
		qol["dlc_flags"] = dlc_mgr.serialize_campaign_flags()
	# FactionSystem: faction standings + rival reputations (Compendium pp.110-117)
	var faction_sys = root.get_node_or_null("/root/FactionSystem")
	if faction_sys and faction_sys.has_method("get_data"):
		qol["faction_system"] = faction_sys.get_data()
	return qol

func from_dictionary(data: Dictionary) -> void:
	## Load campaign from dictionary
	if data.has("meta"):
		var meta = data.meta
		campaign_id = meta.get("campaign_id", "")
		campaign_name = meta.get("campaign_name", "")
		difficulty = meta.get("difficulty", 0)
		ironman_mode = meta.get("ironman_mode", false)
		created_at = meta.get("created_at", "")
		last_modified = meta.get("last_modified", "")
		version = meta.get("version", "1.0")
		game_phase = meta.get("game_phase", "creation")

	# Top-level campaign_id fallback
	if campaign_id.is_empty() and data.has("campaign_id"):
		campaign_id = data.get("campaign_id", "")

	# Load data sections
	crew_data = data.get("crew", {})
	_normalize_crew_stat_keys()
	_backfill_crew_species()
	_rebuild_crew_id_index()
	captain_data = data.get("captain", {})
	ship_data = data.get("ship", {})
	equipment_data = data.get("equipment", {})
	world_data = data.get("world", {})
	progress_data = data.get("progress", {})
	# BUG-031 FIX: Ensure counter fields have defaults for saves from older versions
	if not progress_data.has("missions_completed"):
		progress_data["missions_completed"] = 0
	if not progress_data.has("battles_won"):
		progress_data["battles_won"] = 0
	if not progress_data.has("battles_lost"):
		progress_data["battles_lost"] = 0

	# Load resources. Resources are owned by top-level @vars on the Resource.
	# Legacy saves (pre-Phase-2.1) also had these mirrored under progress_data;
	# we tolerate that shape by falling back to progress_data values if the
	# "resources" sub-dict is missing or partial, then scrubbing progress_data
	# so future saves are clean.
	if data.has("resources"):
		var res = data.resources
		credits = res.get("credits", 0)
		story_points = res.get("story_points", 0)
		supplies = res.get("supplies", 0)
		reputation = res.get("reputation", 0)
		patrons = res.get("patrons", []).duplicate()
		rivals = res.get("rivals", []).duplicate()
		quest_rumors = res.get("quest_rumors", 0)
	else:
		credits = progress_data.get("credits", 0) if progress_data.get("credits") != null else 0
		supplies = progress_data.get("supplies", 0) if progress_data.get("supplies") != null else 0
		reputation = progress_data.get("reputation", 0) if progress_data.get("reputation") != null else 0
		story_points = progress_data.get("story_points", 0) if progress_data.get("story_points") != null else 0
	# Migration: drop legacy progress_data mirrors of resource values.
	# Keep counter fields (turns_played, missions_completed, battles_*) intact.
	for legacy_key in ["credits", "supplies", "reputation", "story_points"]:
		if progress_data.has(legacy_key):
			progress_data.erase(legacy_key)

	# SPRINT 6.1/6.2: Load house rules, story track, and victory conditions
	# Check top-level first, then config for backwards compatibility
	if data.has("house_rules"):
		house_rules = data.get("house_rules", []).duplicate()
	elif data.has("config") and data.config.has("house_rules"):
		house_rules = data.config.get("house_rules", []).duplicate()

	if data.has("story_track_enabled"):
		story_track_enabled = data.get("story_track_enabled", false)
	elif data.has("config") and data.config.has("story_track_enabled"):
		story_track_enabled = data.config.get("story_track_enabled", false)

	# Campaign crew size setting (Core Rules p.63) — default 6 for legacy saves
	if data.has("campaign_crew_size"):
		campaign_crew_size = clampi(data.get("campaign_crew_size", 6), 4, 6)
	elif data.has("config") and data.config is Dictionary and data.config.has("campaign_crew_size"):
		campaign_crew_size = clampi(data.config.get("campaign_crew_size", 6), 4, 6)
	elif data.has("meta") and data.meta is Dictionary and data.meta.has("campaign_crew_size"):
		campaign_crew_size = clampi(data.meta.get("campaign_crew_size", 6), 4, 6)
	else:
		campaign_crew_size = 6  # Legacy save default

	# Galactic War Progress (Core Rules p.126 step 14). Absent in pre-fix saves.
	if data.has("invaded_planets"):
		invaded_planets = (data.get("invaded_planets", []) as Array).duplicate(true)
	if data.has("lost_planets"):
		lost_planets = (data.get("lost_planets", []) as Array).duplicate()
	if data.has("liberated_planets"):
		liberated_planets = (data.get("liberated_planets", []) as Array).duplicate()
	if data.has("invasion_modifiers"):
		invasion_modifiers = (data.get("invasion_modifiers", {}) as Dictionary).duplicate()

	# Phase 30: Red Zone Jobs + Shipless State
	if data.has("red_zone_licensed"):
		red_zone_licensed = data.get("red_zone_licensed", false)
	if data.has("red_zone_turns_completed"):
		red_zone_turns_completed = data.get("red_zone_turns_completed", 0)
	if data.has("has_ship"):
		has_ship = data.get("has_ship", true)
	if data.has("ship_debt"):
		ship_debt = data.get("ship_debt", 0)

	# MIGRATION: seed the canonical ship_debt from the nested display field.
	#
	# `ship_debt` is the owner — it is what the rules code reads and writes (the
	# Black Zone loan payoff at PaymentProcessor.gd:205-209, the Planetfall
	# independence prepayment). But creation and every ship/trade screen write
	# ship_data["debt"], and the bridge that was meant to join them
	# (CampaignFinalizationService.gd:347-351) called a setter that copied the
	# nested field onto ITSELF. Measured across all 15 real 5PFH saves on disk:
	# ship_debt = 0 in every one while ship.debt ranged 12-36.
	#
	# So every existing save has the player's starting loan in the wrong home. Seed
	# it here rather than shipping a migration script; it is idempotent because it
	# only fires while the owner is still 0.
	if ship_debt == 0 and ship_data is Dictionary and ship_data.has("debt"):
		ship_debt = int(ship_data.get("debt", 0))

	if data.has("victory_conditions"):
		victory_conditions = data.get("victory_conditions", {}).duplicate(true)
	if data.has("victory_conditions_locked"):
		victory_conditions_locked = data.get("victory_conditions_locked", false)
	elif not victory_conditions.is_empty():
		# Legacy save migration: if victory conditions exist but no lock flag,
		# assume campaign has started and lock them
		victory_conditions_locked = true

	# Stars of the Story + Story Point turn state (Core Rules pp.66-67)
	if data.has("stars_of_the_story"):
		stars_of_the_story = data.get(
			"stars_of_the_story", {}).duplicate(true)
	if data.has("story_point_turn_state"):
		story_point_turn_state = data.get(
			"story_point_turn_state", {}).duplicate(true)

	# DLC dependency tracking (backwards compat: empty array for old saves)
	var raw_packs: Array = data.get("required_dlc_packs", [])
	required_dlc_packs.clear()
	for p: Variant in raw_packs:
		required_dlc_packs.append(str(p))

	# Store QoL data for deferred loading by autoloads
	# (from_dictionary runs during GameState._init before scene tree is ready)
	# Only store the qol_data subtree (wrapped for consumer compatibility),
	# not the entire campaign dict — avoids unnecessary memory bloat.
	if data.has("qol_data"):
		_pending_qol_data = {"qol_data": data.get("qol_data", {}).duplicate(true)}

func apply_pending_qol_data() -> void:
	## Called after scene tree is ready to load QoL data into autoloads
	if _pending_qol_data.is_empty():
		return
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return
	var qol: Dictionary = _pending_qol_data.get("qol_data", {})
	var journal = root.get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("load_from_save"):
		journal.load_from_save(_pending_qol_data)
	# NPCTracker: restore patrons/rivals/locations UNCONDITIONALLY.
	# deserialize() assigns every field from data.get(key, {}), so an empty dict
	# clears cleanly — the old `if not npc_data.is_empty()` guard meant a campaign
	# with no contacts inherited the PREVIOUS campaign's patrons and rivals from the
	# shared autoload, and _build_qol_data() then baked them into its first save.
	# (Same defect PlanetDataManager and FactionSystem were each fixed for below.)
	var npc_tracker = root.get_node_or_null("/root/NPCTracker")
	if npc_tracker and npc_tracker.has_method("deserialize"):
		npc_tracker.deserialize(qol.get("npc_tracker", {}))
	var checklist = root.get_node_or_null("/root/TurnPhaseChecklist")
	if checklist and checklist.has_method("load_from_save"):
		checklist.load_from_save(_pending_qol_data)
	# WorldEconomyManager: restore credits + transaction history UNCONDITIONALLY.
	# deserialize() reads data.get("current_credits", 0) / ("transaction_history", []),
	# so an empty dict clears. Guarded, a fresh campaign inherited the previous one's
	# transaction ledger.
	var economy = root.get_node_or_null("/root/WorldEconomyManager")
	if economy and economy.has_method("deserialize"):
		economy.deserialize(qol.get("world_economy", {}))
	# PlanetDataManager: restore per-planet progression.
	# Call deserialize_all() UNCONDITIONALLY (empty dict cleanly clears via the
	# clear() at top of deserialize_all). Without this, loading a save without
	# planet_data left stale state from the previous session/mode in the
	# autoload (Opus 4.8 audit B4 — Galaxy Log plan, 2026-06-01).
	var planet_mgr = root.get_node_or_null("/root/PlanetDataManager")
	if planet_mgr and planet_mgr.has_method("deserialize_all"):
		var planet_data: Dictionary = qol.get("planet_data", {})
		planet_mgr.deserialize_all(planet_data)
		# BACKFILL + HEAL: load sets world_data via from_dictionary (NOT
		# initialize_world), so world_changed never fired. Always upsert the
		# current world: it SEEDS PDM when the world is missing (legacy saves, or
		# empty planet_data) AND HEALS a stale name when PDM has the world under
		# the current id but with a drifted/fabricated name (pre-fix saves whose
		# old finalization seeded a random planet). world_data is authoritative.
		if planet_mgr.has_method("upsert_current_world") \
				and world_data is Dictionary and not world_data.is_empty():
			var turns: int = int(progress_data.get("turns_played", 0)) \
				if progress_data is Dictionary else 0
			planet_mgr.upsert_current_world(world_data, turns)
	# DLCManager: restore per-campaign ContentFlag toggles UNCONDITIONALLY.
	# deserialize_campaign_flags() opens with _enabled_flags.clear(), so {} clears.
	# This is the highest-impact of the four: a campaign that enables NO expansions
	# serializes {} — the normal case for vanilla 5PFH — so the guard fired on the
	# most common load and left the previous campaign's Compendium rules live, which
	# _build_qol_data() then persisted into the vanilla campaign's own save.
	var dlc_mgr = root.get_node_or_null("/root/DLCManager")
	if dlc_mgr and dlc_mgr.has_method("deserialize_campaign_flags"):
		dlc_mgr.deserialize_campaign_flags(qol.get("dlc_flags", {}))
	# FactionSystem: restore faction standings + rival reputations.
	# ALWAYS clear first so stale faction/rival state from a PRIOR campaign can't
	# bleed in via the shared autoload. update_data() early-returns on empty data
	# and only conditionally replaces present fields, so without this an empty or
	# partial save would inherit the previously-loaded campaign's factions
	# (mirrors the PlanetDataManager unconditional-clear fix, Jun 1).
	var faction_sys = root.get_node_or_null("/root/FactionSystem")
	if faction_sys:
		if faction_sys.has_method("cleanup"):
			faction_sys.cleanup()
		var fs_data: Dictionary = qol.get("faction_system", {})
		if faction_sys.has_method("update_data") and not fs_data.is_empty():
			faction_sys.update_data(fs_data)
	_pending_qol_data = {}

## Campaign Management Methods

func start_campaign() -> void:
	## Mark campaign as started (move from creation to active play)
	game_phase = "active"
	_update_modified_time()

func get_campaign_summary() -> Dictionary:
	## Get campaign summary for UI display
	var crew_count = crew_data.get("members", []).size()
	var captain_name = captain_data.get("name", "Unknown")
	var ship_name = ship_data.get("name", "Unnamed Ship")
	
	return {
		"name": campaign_name,
		"difficulty": difficulty,
		"crew_size": crew_count,
		"captain": captain_name,
		"ship": ship_name,
		"created": created_at,
		"status": game_phase,
		"ironman": ironman_mode
	}

func get_crew_members() -> Array:
	## Get crew members array
	return crew_data.get("members", [])

## Returns the crew size for travel cost calculations (GameState compatibility)
func get_crew_size() -> int:
	var members = crew_data.get("members", [])
	if members is Array:
		return members.size()
	return 0

## Returns the campaign crew size SETTING (4, 5, or 6). This is the fixed value
## chosen at campaign creation (Core Rules p.63) used for enemy numbers, deployment
## limits, and reaction dice. NOT the current roster count — use get_crew_size() for that.
func get_campaign_crew_size() -> int:
	return campaign_crew_size

## Returns a crew member by their character_id (or legacy "id" key).
## Uses a cached index for O(1) lookups. Falls back to linear scan if
## the cache is stale (e.g. after external mutation of crew_data).
func get_crew_member_by_id(character_id: String) -> Variant:
	var members = crew_data.get("members", [])
	if not (members is Array):
		return null
	# Try cached index first — but VALIDATE the hit.
	#
	# THE BUG THIS FIXES: this used to return members[idx] after checking only that
	# idx was in range. The docblock above promised a fallback "if the cache is
	# stale", but the fallback fired on a cache MISS, never on a stale HIT — and a
	# stale-but-in-range hit is exactly what remove_at() of a non-final member
	# produces. UpkeepPhaseComponent._execute_crew_dismissal() did precisely that
	# (:1725), shifting every later member down one while leaving the index untouched
	# and the dismissed member's own id still in it.
	#
	# The result was a silent wrong-member lookup: CrewTaskComponent:1443-1457 credits
	# World Phase task XP to whatever get_crew_member_by_id returns and RETURNS before
	# reaching its own linear-scan fallback, so the XP landed on a different character
	# sheet with no error. Upkeep offers dismissal and crew tasks resolve later in the
	# SAME World Phase, so it is a same-turn bug.
	#
	# GameState.verify_consistency CHECK 3 could not see it either: it flags only
	# out-of-range entries, and this case is in range and wrong.
	if _crew_id_index.has(character_id):
		var idx: int = _crew_id_index[character_id]
		if idx >= 0 and idx < members.size() and _member_has_id(members[idx], character_id):
			return members[idx]
	# Cache miss OR a stale hit — full scan. Rebuild the cache as a side effect.
	_rebuild_crew_id_index()
	if _crew_id_index.has(character_id):
		var idx: int = _crew_id_index[character_id]
		if idx < members.size():
			return members[idx]
	return null

## True if `member` actually carries `character_id`.
##
## Used to validate a cached-index hit before trusting it. Extracts the id exactly the
## way _rebuild_crew_id_index() below does — both spellings, Dictionary and Object —
## so validation can never disagree with the index it is checking.
func _member_has_id(member, character_id: String) -> bool:
	if member is Dictionary:
		var d: Dictionary = member
		return str(d.get("character_id", d.get("id", ""))) == character_id
	if member is Object:
		if "character_id" in member:
			return str(member.character_id) == character_id
		if "id" in member:
			return str(member.id) == character_id
	return false


func _rebuild_crew_id_index() -> void:
	_crew_id_index.clear()
	var members = crew_data.get("members", [])
	if not (members is Array):
		return
	for i in range(members.size()):
		var member = members[i]
		var cid: String = ""
		if member is Dictionary:
			cid = str(member.get("character_id", member.get("id", "")))
		elif member is Object:
			if "character_id" in member:
				cid = str(member.character_id)
			elif "id" in member:
				cid = str(member.id)
		if not cid.is_empty():
			_crew_id_index[cid] = i

func get_current_mission() -> Dictionary:
	## Get current mission data from progress_data (set during world phase)
	return progress_data.get("current_mission", {})

func get_all_equipment() -> Array:
	## Get all equipment items as a flat array, regardless of storage format.
	## Handles both split format (weapons/armor/gear keys) and flat format (equipment key).
	var items: Array = []
	if equipment_data.has("equipment"):
		var eq_list = equipment_data.get("equipment", [])
		if eq_list is Array:
			items.append_array(eq_list)
	for key in ["weapons", "armor", "gear"]:
		var category_items = equipment_data.get(key, [])
		if category_items is Array:
			items.append_array(category_items)
	return items

func get_captain() -> Dictionary:
	## Get captain data
	return captain_data

func get_ship() -> Dictionary:
	## Get ship data
	return ship_data

## Private Methods

func _update_modified_time() -> void:
	## Update last modified timestamp
	last_modified = Time.get_datetime_string_from_system()

## Static Factory Methods

static func create_new_campaign(name: String, difficulty: int = 0) -> FiveParsecsCampaignCore:
	## Create a new campaign with basic settings
	var _Self = load("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	var campaign = _Self.new()
	campaign.campaign_name = name
	campaign.difficulty = difficulty
	return campaign

static func load_from_file(path: String) -> FiveParsecsCampaignCore:
	## Load campaign from save file, falling back to the .bak generation.
	##
	## Reading through SaveFileWriter is what makes the backup real: save_to_file()
	## keeps the prior generation as <path>.bak on every write, but reading the
	## primary directly (as this did) meant a truncated or half-written save was
	## simply unloadable and the intact backup sitting beside it was never opened.
	var data := SaveFileWriterRef.read_json_with_fallback(path)
	if data.is_empty():
		return null

	var _Self = load("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	var campaign = _Self.new()
	campaign.from_dictionary(data)
	return campaign

## JSON-based save (consistent with load_from_file)

func save_to_file(path: String) -> Error:
	## Save campaign to JSON file.
	_update_modified_time()
	var data = to_dictionary()

	# Strip non-serializable Resource references from crew members.
	# CampaignCreationCoordinator stores "character" (Resource ref) on member
	# dicts; JSON.stringify calls str() on Resources producing garbage like
	# "():<Resource#12345>".  Also strip "character_object" (legacy alias).
	if data.has("crew") and data["crew"] is Dictionary and data["crew"].has("members"):
		var clean_members: Array = []
		for member in data["crew"]["members"]:
			if member is Dictionary:
				var clean = member.duplicate(true)
				clean.erase("character_object")
				clean.erase("character")
				clean_members.append(clean)
			elif member is Resource and member.has_method("to_dictionary"):
				clean_members.append(member.to_dictionary())
			else:
				clean_members.append(member)
		data["crew"]["members"] = clean_members
	# Same for captain_data
	if data.has("captain") and data["captain"] is Dictionary:
		data["captain"] = data["captain"].duplicate(true)
		data["captain"].erase("character_object")
		data["captain"].erase("character")

	# Compact, not pretty-printed. Tab indentation cost a MEASURED 24-27% on the
	# real save files, and save_campaign() runs ~8x per campaign turn, so that is
	# a quarter of every write on a phone spent on whitespace. Nothing parses the
	# indentation; to read a save by hand: py -m json.tool <file>
	var json_string = JSON.stringify(data)

	# ATOMIC write. FileAccess.WRITE on the live path truncates it to 0 bytes
	# immediately, so an Android background-kill between the truncate and the close
	# destroyed the campaign outright — and that window opened on every phase
	# completion. SaveFileWriter writes a temp, flushes, then renames over the real
	# file, so the save on disk is always either the previous complete one or the new
	# complete one. See src/core/state/SaveFileWriter.gd.
	var write_err: Error = SaveFileWriterRef.write_text_atomic(path, json_string)
	if write_err != OK:
		push_error("FiveParsecsCampaignCore: Failed to save: %s (error: %d)"
			% [path, write_err])
	return write_err
