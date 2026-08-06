class_name FringeWorldStrife
extends RefCounted
## Fringe World Strife — Compendium pp.148-151.
##
## WHAT WAS THERE BEFORE. The 10-row D100 strife table has been complete and
## correct in data/compendium/world_options.json since it was written, and the
## chapter still never ran, for four independent reasons at the one live call
## site (`WorldPhaseController._check_compendium_world_strife`):
##
##   1. it gated on `world_phase_data["is_fringe_world"]`, a key NO producer
##      anywhere in the repository writes — permanently false;
##   2. `should_check_strife()` re-rolled the ARRIVAL 1D6 every campaign turn.
##      The book rolls it once, on arrival, to decide whether the world is
##      Unstable at all;
##   3. it then fired the D100 immediately. The book fires it only when the
##      Instability score REACHES OR EXCEEDS 10;
##   4. it read `strife_event["instability_mod"]`, and the rows carry
##      `instability_reduction` — and the local it read into was never used
##      anyway.
##
## Fixing 1-4 would still not have produced the chapter, because the engine of
## the whole thing — a per-world Instability score that accumulates — did not
## exist in any form. `roll_instability_delta()` had exactly one caller, in
## `phases/WorldPhase.gd`, a file with zero instantiations.
##
## THE BOOK, verbatim (p.148):
##
##   "If using this system, when arriving on a new world, roll 1D6. A roll of 4+
##    indicates the world is Unstable. You may opt to use a 5+ roll if you prefer
##    a less chaotic environment."
##
##   "An Unstable world always maintains an Instability score which is tracked by
##    the player. When you arrive on the world, it begins at +1 Instability.
##    During the Invasion step of every campaign turn, add 1D6 to the total.
##    Adjust the total by an additional +1 for every active Rival on this world.
##    Subtract -1 if you completed a Patron job this campaign turn.
##    Subtract -1 if you Held the Field against a Roving Threat this campaign
##    turn. If this causes Instability to reach or exceed 10, make a D100 roll on
##    the table below, reduce the Instability score by the amount listed, and
##    apply the listed effect."
##
##   (p.151) "Any result of 'NA' means Instability is no longer tracked: The
##    world has bigger problems to worry about!"
##
## STATE lives on the campaign, keyed by planet id, at
## `campaign.progress_data["fringe_strife"]`. It is deliberately NOT a new field
## on `PlanetData`: that Resource is core-campaign shape shared by all four
## gamemodes, and this is one optional Compendium chapter. progress_data is
## already serialized, so this persists for free.

const FLAG := "FRINGE_WORLD_STRIFE"
const STATE_KEY := "fringe_strife"

## "If this causes Instability to reach or exceed 10" (p.148).
const THRESHOLD := 10

## "When you arrive on the world, it begins at +1 Instability" (p.148).
const STARTING_INSTABILITY := 1

const WorldOptionsRef = preload("res://src/data/compendium_world_options.gd")
const EliteEnemiesRef = preload("res://src/data/compendium_elite_enemies.gd")


## ============================================================================
## GATING
## ============================================================================

static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func is_enabled() -> bool:
	var dlc := _get_dlc_manager()
	if not dlc:
		return false
	var flag_value: int = dlc.ContentFlag.get(FLAG, -1)
	if flag_value < 0:
		return false
	return dlc.is_feature_enabled(flag_value)


## ============================================================================
## STATE
## ============================================================================

static func _progress_data(campaign: Variant) -> Variant:
	if campaign == null:
		return null
	if campaign is Dictionary:
		if not campaign.has("progress_data"):
			campaign["progress_data"] = {}
		return campaign["progress_data"]
	if "progress_data" in campaign:
		return campaign.progress_data
	return null


## Every tracked world's state, keyed by planet id. Returns {} (not null) when
## there is no campaign, so callers never have to null-check the container.
static func all_states(campaign: Variant) -> Dictionary:
	var pd: Variant = _progress_data(campaign)
	if pd == null or not (pd is Dictionary):
		return {}
	var states = pd.get(STATE_KEY, {})
	return states if states is Dictionary else {}


## One world's state. `{}` means the world has never been rolled for.
static func get_state(campaign: Variant, planet_id: String) -> Dictionary:
	if planet_id.is_empty():
		return {}
	var state = all_states(campaign).get(planet_id, {})
	return state if state is Dictionary else {}


static func _write_state(campaign: Variant, planet_id: String, state: Dictionary) -> void:
	var pd: Variant = _progress_data(campaign)
	if pd == null or not (pd is Dictionary) or planet_id.is_empty():
		return
	var states = pd.get(STATE_KEY, {})
	if not (states is Dictionary):
		states = {}
	states[planet_id] = state
	pd[STATE_KEY] = states


static func is_unstable(campaign: Variant, planet_id: String) -> bool:
	return bool(get_state(campaign, planet_id).get("unstable", false))


## False once an "NA" row has fired (p.151: "Instability is no longer tracked").
static func is_tracking(campaign: Variant, planet_id: String) -> bool:
	var state: Dictionary = get_state(campaign, planet_id)
	if not bool(state.get("unstable", false)):
		return false
	return bool(state.get("tracking", true))


static func get_instability(campaign: Variant, planet_id: String) -> int:
	return int(get_state(campaign, planet_id).get("instability", 0))


## Persistent consequences currently in force on this world — the rows whose
## effect outlasts the turn it fired on (Criminal Gang, Economic Collapse, ...).
static func active_effects(campaign: Variant, planet_id: String) -> Array:
	var effects = get_state(campaign, planet_id).get("active_effects", [])
	return effects if effects is Array else []


## ============================================================================
## p.148 ARRIVAL
## ============================================================================

## "when arriving on a new world, roll 1D6. A roll of 4+ indicates the world is
## Unstable. You may opt to use a 5+ roll if you prefer a less chaotic
## environment."
##
## Idempotent per world: a world already rolled for keeps its verdict, so
## re-entering the World Phase (or reloading) cannot re-roll a stable world into
## an unstable one. Returns the state dict, or {} when the option is off.
static func roll_arrival(campaign: Variant, planet_id: String,
		use_calmer_setting: bool = false) -> Dictionary:
	if not is_enabled() or planet_id.is_empty() or campaign == null:
		return {}
	var existing: Dictionary = get_state(campaign, planet_id)
	if not existing.is_empty():
		return existing

	var threshold: int = 5 if use_calmer_setting else 4
	var roll: int = randi_range(1, 6)
	var unstable: bool = roll >= threshold
	var state := {
		"planet_id": planet_id,
		"arrival_roll": roll,
		"arrival_threshold": threshold,
		"unstable": unstable,
		# "When you arrive on the world, it begins at +1 Instability."
		"instability": STARTING_INSTABILITY if unstable else 0,
		"tracking": unstable,
		"active_effects": [],
		"history": [],
	}
	_write_state(campaign, planet_id, state)
	return state


## ============================================================================
## p.148 ACCUMULATOR — the engine of the chapter
## ============================================================================

## Run one Invasion-step accumulation for `planet_id`.
##
## Returns a report:
##   {"ran": bool, "delta": int, "instability": int, "fired": bool,
##    "event": Dictionary, "reduction": int, "tracking": bool,
##    "modifiers": Dictionary}
##
## `ran == false` means the world is stable, untracked, or the option is off —
## the caller should do nothing at all, not apply a default.
##
## NOTE on the 0 floor: the book states no lower bound. The minimum possible
## delta is 1D6(1) - 1 (Patron job) - 1 (Held the Field) = -1, so a quiet turn
## CAN reduce the score. Instability is clamped at 0 rather than allowed to bank
## negative buffer, because the book's own arithmetic treats 0 as the resting
## floor (a -10 reduction against a score of exactly 10 lands on 0). Tagged
## because it is the one number here the book does not print.
static func accumulate(campaign: Variant, planet_id: String,
		active_rivals: int = 0, patron_job_completed: bool = false,
		held_field_vs_roving_threat: bool = false) -> Dictionary:
	var idle := {
		"ran": false, "delta": 0, "instability": 0, "fired": false,
		"event": {}, "reduction": 0, "tracking": false, "modifiers": {},
	}
	if not is_enabled() or not is_tracking(campaign, planet_id):
		return idle

	var state: Dictionary = get_state(campaign, planet_id)
	var die: int = randi_range(1, 6)
	var rival_mod: int = maxi(active_rivals, 0)
	var patron_mod: int = -1 if patron_job_completed else 0
	var roving_mod: int = -1 if held_field_vs_roving_threat else 0
	var delta: int = die + rival_mod + patron_mod + roving_mod

	var instability: int = maxi(int(state.get("instability", 0)) + delta, 0)
	state["instability"] = instability

	var report := {
		"ran": true,
		"delta": delta,
		"instability": instability,
		"fired": false,
		"event": {},
		"reduction": 0,
		"tracking": true,
		"modifiers": {
			"die": die,
			"rivals": rival_mod,
			"patron_job": patron_mod,
			"held_field_roving": roving_mod,
		},
	}

	# "If this causes Instability to reach or exceed 10, make a D100 roll on the
	# table below, reduce the Instability score by the amount listed, and apply
	# the listed effect."
	if instability >= THRESHOLD:
		var event: Dictionary = _roll_strife_row()
		if not event.is_empty():
			report["fired"] = true
			report["event"] = event
			var reduction: int = int(event.get("instability_reduction", 0))
			report["reduction"] = reduction
			# A reduction of 0 is the book's "NA" — the two rows (Invasion
			# Imminent, Civil War) that stop tracking outright.
			if reduction <= 0:
				state["tracking"] = false
				report["tracking"] = false
			else:
				state["instability"] = maxi(instability - reduction, 0)
				report["instability"] = state["instability"]
			var history: Array = state.get("history", [])
			history.append({
				"event_id": str(event.get("id", "")),
				"name": str(event.get("name", "")),
				"roll": int(event.get("roll", 0)),
				"reduction": reduction,
			})
			state["history"] = history

	_write_state(campaign, planet_id, state)
	return report


## The D100 row. Split out so the threshold logic above can be tested against a
## stub without a DLCManager in the tree.
static func _roll_strife_row() -> Dictionary:
	return WorldOptionsRef.roll_strife_event()


## ============================================================================
## PERSISTENT EFFECTS
## ============================================================================
##
## Several rows outlast the turn they fire on. They are recorded here and read
## by the consumers listed against each one. Rows whose effect is a mission the
## PLAYER sets up on the tabletop (Criminal Gang's Fight Off, Enemy
## Infiltration's Track, Raiders' Raid scenario, Civil War's faction war) carry
## their book text to the player and are NOT auto-resolved — this is a companion
## app, and inventing a resolution for them would replace the player's decision.

## Rows that impose a standing -1 Credit on this world's payouts.
##   Criminal Gang: "all post-battle payouts on this world are reduced by
##                   1 Credit" until cleared.
##   Economic Collapse: "all mission payouts are -1 Credit" until recovered.
const PAYOUT_PENALTY_EFFECTS := ["criminal_gang", "economic_collapse"]

## Rows that block crew actions.
##   Hooligans: "You cannot perform any Explore or Trade crew actions during the
##              next campaign turn."
##   Economic Collapse: "For now, you cannot take Trade actions."
const BLOCKED_TASKS_BY_EFFECT := {
	"hooligans": ["explore", "trade"],
	"economic_collapse": ["trade"],
}


static func add_active_effect(campaign: Variant, planet_id: String,
		effect_id: String, payload: Dictionary = {}) -> void:
	if effect_id.is_empty():
		return
	var state: Dictionary = get_state(campaign, planet_id)
	if state.is_empty():
		return
	var effects: Array = state.get("active_effects", [])
	for existing in effects:
		if existing is Dictionary and str(existing.get("id", "")) == effect_id:
			return
	var entry := {"id": effect_id}
	entry.merge(payload)
	effects.append(entry)
	state["active_effects"] = effects
	_write_state(campaign, planet_id, state)


static func clear_active_effect(campaign: Variant, planet_id: String,
		effect_id: String) -> bool:
	var state: Dictionary = get_state(campaign, planet_id)
	if state.is_empty():
		return false
	var effects: Array = state.get("active_effects", [])
	for i in range(effects.size() - 1, -1, -1):
		var entry = effects[i]
		if entry is Dictionary and str(entry.get("id", "")) == effect_id:
			effects.remove_at(i)
			state["active_effects"] = effects
			_write_state(campaign, planet_id, state)
			return true
	return false


static func has_active_effect(campaign: Variant, planet_id: String,
		effect_id: String) -> bool:
	for entry in active_effects(campaign, planet_id):
		if entry is Dictionary and str(entry.get("id", "")) == effect_id:
			return true
	return false


## Standing payout modifier on this world, in credits (0 or negative).
## Criminal Gang and Economic Collapse each say "-1 Credit"; the book gives no
## rule for stacking them, so they do NOT stack — the worse of the two applies.
static func payout_modifier(campaign: Variant, planet_id: String) -> int:
	for entry in active_effects(campaign, planet_id):
		if entry is Dictionary and str(entry.get("id", "")) in PAYOUT_PENALTY_EFFECTS:
			return -1
	return 0


## Crew task ids blocked on this world right now (lowercase, e.g. "explore").
##
## Expiry is NOT re-derived here. Single-turn effects (Hooligans is explicitly
## "during the NEXT campaign turn") are removed by expire_effects() at turn
## rollover, so this reader has one job: report what is currently recorded. A
## reader that also decided expiry would need the turn number threaded through
## every call site, and the two would drift the first time one was updated alone.
static func blocked_crew_tasks(campaign: Variant, planet_id: String) -> Array:
	var blocked: Array = []
	for entry in active_effects(campaign, planet_id):
		if not (entry is Dictionary):
			continue
		var effect_id: String = str(entry.get("id", ""))
		if not BLOCKED_TASKS_BY_EFFECT.has(effect_id):
			continue
		for task in BLOCKED_TASKS_BY_EFFECT[effect_id]:
			if task not in blocked:
				blocked.append(task)
	return blocked


## p.149 Heating Up: "Add a Rival randomly selected from the Criminal Elements
## subtable (core rules, p.94)." Rolls the real D100 against that subtable rather
## than picking a name from a hand-written shortlist.
##
## Defers to the Compendium Elite Criminal Elements table when Elite-level
## Enemies is on, because p.48 says the elite tables "take the place of the
## regular encounter tables" — an elite campaign should draw an elite Rival.
static func roll_criminal_elements_name() -> String:
	var elite: Dictionary = EliteEnemiesRef.roll_enemy_in_category("criminal_elements")
	if not elite.is_empty():
		return str(elite.get("name", ""))

	var file := FileAccess.open("res://data/enemy_types.json", FileAccess.READ)
	if not file:
		return ""
	var json := JSON.new()
	var parsed_ok: bool = json.parse(file.get_as_text()) == OK
	file.close()
	if not parsed_ok or not (json.data is Dictionary):
		return ""
	for category in json.data.get("enemy_categories", []):
		if not (category is Dictionary) or str(category.get("id", "")) != "criminal_elements":
			continue
		var roll: int = randi_range(1, 100)
		for enemy in category.get("enemies", []):
			var span: Array = enemy.get("roll_range", [])
			if span.size() >= 2 and roll >= int(span[0]) and roll <= int(span[1]):
				return str(enemy.get("name", ""))
	return ""


## Drop any single-turn effects that have run out. Called at turn rollover.
static func expire_effects(campaign: Variant, planet_id: String,
		current_turn: int) -> Array:
	var state: Dictionary = get_state(campaign, planet_id)
	if state.is_empty():
		return []
	var effects: Array = state.get("active_effects", [])
	var expired: Array = []
	for i in range(effects.size() - 1, -1, -1):
		var entry = effects[i]
		if not (entry is Dictionary) or not entry.has("expires_after_turn"):
			continue
		if current_turn > int(entry["expires_after_turn"]):
			expired.append(str(entry.get("id", "")))
			effects.remove_at(i)
	if not expired.is_empty():
		state["active_effects"] = effects
		_write_state(campaign, planet_id, state)
	return expired
