extends RefCounted
class_name QAScenarioLoader

## QA scenario fixtures — jump a live campaign to a state that is expensive to
## reach by playing (Aug 8 2026, tablet sprint).
##
## WHY A DELTA AND NOT A SAVE FILE. The obvious design is to commit whole save
## files and load them. A real save on this project is ~37KB, is coupled to
## `schema_version`, and is opaque — you cannot tell from a diff what makes it
## "the injuries scenario". A fixture here is a small declarative DELTA applied
## to whatever campaign is already loaded, through the SAME owner setters the
## Campaign Editor uses. It stays readable, it survives a schema bump because it
## never touches the serialized shape, and `lint_data_ownership.py` still covers
## the writes because they are the sanctioned ones.
##
## WHAT IT DELIBERATELY DOES NOT DO: jump the phase. Deep-linking into, say,
## post-battle step 8 constructs states the real flow never produces, and then a
## tester spends an hour on a "bug" that is an artifact of the jump. A scenario
## sets CAMPAIGN STATE and hands back; the player then enters through the normal
## turn flow and the app builds the phase itself.
##
## Fixtures live in `data/qa_scenarios/*.json` so they ship in the PCK (a few KB)
## and so `tests/unit/test_qa_scenarios.gd` can load the byte-identical files —
## one definition of "wounded crew at turn 12" shared by device QA and CI rather
## than two that drift.

const SalvageLedgerRef = preload("res://src/core/campaign/SalvageLedger.gd")
const CharacterGenerationRef = preload("res://src/core/character/CharacterGeneration.gd")

const SCENARIO_DIR := "res://data/qa_scenarios"


## Every fixture id found on disk, sorted. Ids are filenames without extension.
static func list_ids() -> Array:
	var ids: Array = []
	var dir := DirAccess.open(SCENARIO_DIR)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			ids.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids


## Load one fixture. Returns {} when missing or malformed — callers must check,
## because a typo'd id must not silently apply an empty (= no-op) scenario.
static func load_scenario(id: String) -> Dictionary:
	var path := "%s/%s.json" % [SCENARIO_DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## All fixtures, loaded, in id order. Used to build the menu.
static func load_all() -> Array:
	var out: Array = []
	for id in list_ids():
		var s := load_scenario(id)
		if s.is_empty():
			continue
		s["id"] = id
		out.append(s)
	return out


## Apply a fixture to `campaign`.
##
## Returns {"applied": Array[String], "warnings": Array[String]} — a human-readable
## receipt, shown in the menu and asserted by the test. It reports what it COULD
## NOT do rather than failing silently: a scenario that quietly skipped half its
## setup is worse than no scenario, because the tester believes they are in a
## state they are not.
##
## `gsm` / `dlc` may be passed explicitly (tests) or left null to resolve the
## autoloads. Resolution uses Engine.get_main_loop().root — this is a RefCounted,
## so a bare get_node_or_null() would error and abort the whole function.
static func apply(scenario: Dictionary, campaign, gsm: Node = null, dlc: Node = null) -> Dictionary:
	var applied: Array = []
	var warnings: Array = []

	if scenario.is_empty():
		warnings.append("Scenario is empty — nothing applied.")
		return {"applied": applied, "warnings": warnings}
	if campaign == null:
		warnings.append("No campaign loaded — load or create a campaign first.")
		return {"applied": applied, "warnings": warnings}

	var root: Node = null
	if Engine.get_main_loop() and Engine.get_main_loop() is SceneTree:
		root = (Engine.get_main_loop() as SceneTree).root
	if gsm == null and root:
		gsm = root.get_node_or_null("/root/GameStateManager")
	if dlc == null and root:
		dlc = root.get_node_or_null("/root/DLCManager")

	_apply_counters(scenario.get("campaign", {}), gsm, applied, warnings)
	_apply_dlc(scenario.get("dlc", {}), dlc, applied, warnings)
	_apply_compendium_progress(scenario.get("compendium_progress", {}), campaign, applied, warnings)
	_apply_crew(scenario.get("crew", []), campaign, applied, warnings)
	_apply_narrative(scenario.get("narrative", {}), campaign, gsm, root, applied, warnings)

	return {"applied": applied, "warnings": warnings}


# --- counters -----------------------------------------------------------------

## Every one of these has a GameStateManager setter that writes through to the
## campaign. The names are taken from CampaignEditorScreen's spin wiring, which is
## the proven path — note "story_points" routes through set_story_progress().
const COUNTER_SETTERS := {
	"turns_played": "set_turns_played",
	"credits": "set_credits",
	"supplies": "set_supplies",
	"story_points": "set_story_progress",
	"reputation": "set_reputation",
	"ship_debt": "set_ship_debt",
}

static func _apply_counters(block: Dictionary, gsm: Node, applied: Array, warnings: Array) -> void:
	if block.is_empty():
		return
	if gsm == null:
		warnings.append("GameStateManager unavailable — no counters applied.")
		return
	for key in block:
		if not COUNTER_SETTERS.has(key):
			warnings.append("Unknown counter '%s' ignored." % key)
			continue
		var method: String = COUNTER_SETTERS[key]
		if not gsm.has_method(method):
			warnings.append("GameStateManager.%s() missing — '%s' skipped." % [method, key])
			continue
		gsm.call(method, int(block[key]))
		applied.append("%s = %d" % [key, int(block[key])])


# --- DLC ----------------------------------------------------------------------

static func _apply_dlc(block: Dictionary, dlc: Node, applied: Array, warnings: Array) -> void:
	if block.is_empty():
		return
	if dlc == null:
		warnings.append("DLCManager unavailable — no DLC enabled.")
		return
	for dlc_id in block.get("own", []):
		if dlc.has_method("set_dlc_owned"):
			dlc.set_dlc_owned(str(dlc_id), true)
		if dlc.has_method("enable_all_for_dlc"):
			dlc.enable_all_for_dlc(str(dlc_id))
		applied.append("DLC owned + all flags on: %s" % dlc_id)


# --- Compendium progress ------------------------------------------------------

static func _apply_compendium_progress(
		block: Dictionary, campaign, applied: Array, warnings: Array) -> void:
	if block.is_empty():
		return

	# Two top-level @export fields with no setter. The live game writes them
	# exactly this way (RedZoneSystem.gd:120, WorldPhaseController.gd:1550), so a
	# direct set is the sanctioned write — same ownership class as `difficulty`.
	if block.has("red_zone_licensed") and "red_zone_licensed" in campaign:
		campaign.red_zone_licensed = bool(block["red_zone_licensed"])
		applied.append("red_zone_licensed = %s" % str(bool(block["red_zone_licensed"])))
	if block.has("red_zone_turns_completed") and "red_zone_turns_completed" in campaign:
		campaign.red_zone_turns_completed = maxi(0, int(block["red_zone_turns_completed"]))
		applied.append("red_zone_turns_completed = %d" % campaign.red_zone_turns_completed)

	# Salvage is NOT the same class. It lives on progress_data and SalvageLedger is
	# its declared owner, so writing the key here would be the raw progress_data
	# write this file's header bans. The ledger API takes a DELTA; a fixture states
	# an ABSOLUTE, so convert rather than reaching past it.
	if block.has("salvage_units"):
		var want: int = maxi(0, int(block["salvage_units"]))
		var delta: int = want - SalvageLedgerRef.get_units(campaign)
		if delta != 0:
			SalvageLedgerRef.add_units(campaign, delta)
		applied.append("salvage_units = %d" % want)


# --- crew ---------------------------------------------------------------------

## Fields a fixture may patch onto a crew member. Restricted on purpose: an open
## merge would let a fixture write `origin` as an int or drop `character_id`, and
## both of those are documented ways to destroy a crew member silently.
const CREW_FIELDS := [
	"in_sick_bay", "recovery_turns", "recovered_this_turn",
	"locked_out_this_turn", "experience", "status_effects",
]

static func _apply_crew(patches: Array, campaign, applied: Array, warnings: Array) -> void:
	if patches.is_empty():
		return
	if not campaign.has_method("get_crew_members") or not campaign.has_method("update_crew_member"):
		warnings.append("Campaign has no crew API — crew patches skipped.")
		return

	var members: Array = campaign.get_crew_members()
	for patch in patches:
		if not (patch is Dictionary):
			continue
		var idx: int = int(patch.get("index", -1))
		if idx < 0 or idx >= members.size():
			warnings.append("Crew index %d out of range (crew size %d) — skipped."
				% [idx, members.size()])
			continue
		var member = members[idx]
		if not (member is Dictionary):
			warnings.append("Crew member %d is not a Dictionary — skipped." % idx)
			continue

		var patched: Dictionary = member.duplicate(true)
		var touched: Array = []
		for field in CREW_FIELDS:
			if patch.has(field):
				patched[field] = patch[field]
				touched.append(field)
		if touched.is_empty():
			continue

		var cid := str(patched.get("character_id", patched.get("id", "")))
		if cid.is_empty():
			warnings.append("Crew member %d has no character_id — skipped." % idx)
			continue
		if campaign.update_crew_member(cid, patched):
			applied.append("%s: %s" % [
				str(patched.get("character_name", "crew %d" % idx)), ", ".join(touched)])
		else:
			warnings.append("update_crew_member failed for %s." % cid)


# --- narrative ----------------------------------------------------------------

static func _apply_narrative(
		block: Dictionary, campaign, gsm: Node, root: Node,
		applied: Array, warnings: Array) -> void:
	if block.is_empty():
		return

	if block.has("quest_rumors") and gsm and gsm.has_method("set_quest_rumors"):
		gsm.set_quest_rumors(maxi(0, int(block["quest_rumors"])))
		applied.append("quest_rumors = %d" % maxi(0, int(block["quest_rumors"])))

	if block.has("story_track_enabled") and gsm and gsm.has_method("set_story_track_enabled"):
		gsm.set_story_track_enabled(bool(block["story_track_enabled"]))
		applied.append("story_track_enabled = %s" % str(bool(block["story_track_enabled"])))

	# Rivals and Patrons are generated rather than declared: a hand-authored dict
	# literal in a fixture drifts from the producer the first time a field is
	# added, and a count keeps the fixture readable.
	#
	# CORRECTED 2026-09-05 (T11-38). This comment used to justify the choice by
	# saying the dicts "have a schema PatronRivalManager reads field-by-field".
	# That is no longer true and naming a stale consumer is worse than naming
	# none: PatronRivalManager was rewritten in the T11-29 fix and now reads
	# `origin` / `planet_id` / `created_turn` (its _rival_provenance, :283-294),
	# which `_create_starting_rival()` does not emit. So a fixture rival renders
	# with an EMPTY provenance line.
	#
	# That is deliberately NOT worked around here. A census of 40 real save files
	# found 25 rival records and ZERO carrying those three keys — every shipped
	# rival has this shape, so the fixture is faithful to production and papering
	# over it in QA would hide the real defect. What it does mean for a device
	# walk: capture the untouched campaign BEFORE applying a fixture, or a blank
	# provenance line cannot be attributed to either source.
	#
	# The canonical producer is RivalPatronResolver._append_rival (:835-845).
	var rivals: int = int(block.get("rivals", 0))
	if rivals > 0 and gsm and gsm.has_method("set_rivals"):
		var built: Array = []
		for i in range(rivals):
			built.append(CharacterGenerationRef._create_starting_rival(i, "QA Scenario"))
		gsm.set_rivals(built)
		applied.append("rivals = %d" % rivals)

	var patrons: int = int(block.get("patrons", 0))
	if patrons > 0 and gsm and gsm.has_method("add_patron"):
		for _i in range(patrons):
			gsm.add_patron()
		applied.append("patrons += %d" % patrons)

	# Core Rules p.126 step 14 only rolls "if you are tracking any planets that
	# were previously Invaded", so the Galactic War table is unreachable without
	# at least one entry here.
	var invaded: Array = block.get("invaded_planets", [])
	if not invaded.is_empty() and campaign.has_method("record_invaded_planet"):
		for p in invaded:
			if p is Dictionary:
				campaign.record_invaded_planet(
					str(p.get("id", "")), str(p.get("name", "")))
		applied.append("invaded_planets += %d" % invaded.size())

	# The active Quest lives in progress_data and GameState owns it. Seeding one
	# is the only way to reach the p.119-120 quest-progress roll without winning a
	# p.85 roll first — and it is how W2-02 (the Turn 1 Quest that did not persist)
	# gets retested deliberately instead of by luck.
	var quest: Dictionary = block.get("active_quest", {})
	if not quest.is_empty() and root:
		var gs: Node = root.get_node_or_null("/root/GameState")
		if gs and gs.has_method("set_active_quest"):
			gs.set_active_quest(quest)
			applied.append("active_quest = %s" % str(quest.get("name", "(unnamed)")))
		else:
			warnings.append("GameState.set_active_quest() unavailable — quest skipped.")
