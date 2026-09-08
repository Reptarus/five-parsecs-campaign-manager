class_name TacticsPhaseManager
extends Node

## Manages the Tactics 8-phase operational turn:
##   ORDERS → RECON → BATTLE_PREP → DEPLOYMENT → BATTLE →
##   POST_BATTLE → ADVANCEMENT → STRATEGIC
## Each phase must complete before the next begins.
## After STRATEGIC, the operational turn is complete.
## Source: Five Parsecs: Tactics **pp.92-100** — "THE OPERATIONAL SYSTEM" in the
## Campaign Play chapter (Cohesion, the Map, Operational Zones, Army Strength, the
## 8-step Operational Turn at p.96, Commando Raids, Player Battle Points, and
## Special Regions at p.100).
## ⚠ CITE CORRECTED 2026-09-04 from "pp.155-168", which is the **Lifeforms
## bestiary** chapter — 63 pages off. docs/rules/tactics_source.txt marks raw page N
## with the PRINTED number on the next line (offset raw-2), verified at three points:
## raw 94 -> p.92 "THE OPERATIONAL SYSTEM", raw 157 -> p.155 "Lifeforms/Hulkers",
## raw 170 -> p.168 "Lifeforms/CREATURES".

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)
signal operational_turn_started(op_turn: int)
signal operational_turn_completed(op_turn: int)
signal navigation_updated(can_back: bool, can_forward: bool)
## Tactics p.99 Step 9 — "player", "enemy" or "inconclusive". Emitted the moment either
## side's Cohesion reaches 0. ⚠ A declared-but-never-emitted signal is what
## scripts/lint_signal_wiring.py exists to catch, so if this ever stops being emitted
## the lint will say so rather than the campaign silently losing its end condition.
signal campaign_ended(result: String)

enum Phase {
	NONE = -1,
	ORDERS = 0,             # Choose battle plan, assign units to zones
	RECON = 1,              # Observation tests, intel gathering
	BATTLE_PREP = 2,        # Scenario generation, objective selection
	DEPLOYMENT = 3,         # Unit placement per scenario rules
	BATTLE = 4,             # Tabletop battle (1-3 per operational turn)
	POST_BATTLE = 5,        # Casualties, CP awards, story events
	ADVANCEMENT = 6,        # Spend CP on veteran skills, roster changes
	STRATEGIC = 7,          # Operational combat, orders, redeployment, new zones
}

const PHASE_NAMES := {
	Phase.ORDERS: "Operational Orders",
	Phase.RECON: "Reconnaissance",
	Phase.BATTLE_PREP: "Battle Preparation",
	Phase.DEPLOYMENT: "Deployment",
	Phase.BATTLE: "Battle",
	Phase.POST_BATTLE: "Post-Battle",
	Phase.ADVANCEMENT: "Advancement",
	Phase.STRATEGIC: "Strategic Phase",
}

const PHASE_DESCRIPTIONS := {
	Phase.ORDERS: "Plan your approach and assign units to operational zones",
	Phase.RECON: "Gather intelligence on enemy positions and terrain",
	Phase.BATTLE_PREP: "Generate scenario, set objectives, roll battlefield conditions",
	Phase.DEPLOYMENT: "Place your forces according to scenario rules",
	Phase.BATTLE: "Fight the tabletop battle",
	Phase.POST_BATTLE: "Process casualties, award Campaign Points, check story events",
	Phase.ADVANCEMENT: "Spend CP on veteran skills and roster changes",
	Phase.STRATEGIC: "Resolve operational combat, issue orders, redeploy forces",
}

const PHASE_COUNT := 8

var campaign: Resource  # TacticsCampaignCore
var current_phase: int = Phase.NONE
var previous_phase: int = Phase.NONE
var turn_number: int = 0
var operational_turn: int = 0

## How many battles fought this operational turn (1-3 allowed)
var battles_this_turn: int = 0
## Tabletop results this operational turn, for the p.96 Player Battle Point award.
## Both are needed: the book cancels the two sides' points 1-for-1 in the same Zone.
var battle_wins_this_turn: int = 0
var battle_losses_this_turn: int = 0
## PBP held when this operational turn began. The award is recomputed from the running
## tally after every battle rather than incremented, so playing a second battle in the
## same turn cannot push the total past the p.96 per-turn cap of 2.
var _pbp_at_turn_start: int = 0

const OperationalRulesRef = preload(
	"res://src/core/campaign/TacticsOperationalRules.gd")
const MAX_BATTLES_PER_TURN := 3

var _phase_complete: Dictionary = {}


func _ready() -> void:
	_reset_phase_completion()


func setup(campaign_resource: Resource) -> void:
	campaign = campaign_resource
	if campaign and "campaign_turn" in campaign:
		turn_number = campaign.campaign_turn
	if campaign and "operational_turn" in campaign:
		operational_turn = campaign.operational_turn


func start_new_turn() -> void:
	turn_number += 1
	operational_turn += 1
	battles_this_turn = 0
	# Tactics p.96 caps PBP at 2 gained per OPERATIONAL TURN, so the tally has to be
	# per-turn state rather than per-battle.
	battle_wins_this_turn = 0
	battle_losses_this_turn = 0
	_pbp_at_turn_start = _current_battle_points()

	if campaign:
		if campaign.has_method("advance_turn"):
			campaign.advance_turn()
		if campaign.has_method("advance_operational_turn"):
			campaign.advance_operational_turn()

	_reset_phase_completion()
	campaign_turn_started.emit(turn_number)
	operational_turn_started.emit(operational_turn)
	_journal_log_turn_start(turn_number, operational_turn)
	_go_to_phase(Phase.ORDERS)


func get_phase_name(phase: int = -99) -> String:
	if phase == -99:
		phase = current_phase
	return PHASE_NAMES.get(phase, "Unknown")


func get_phase_description(phase: int = -99) -> String:
	if phase == -99:
		phase = current_phase
	return PHASE_DESCRIPTIONS.get(phase, "")


func complete_current_phase(result_data: Dictionary = {}) -> void:
	if current_phase == Phase.NONE:
		return

	_phase_complete[current_phase] = true
	phase_completed.emit(current_phase)
	_journal_log_phase_complete(current_phase, result_data)

	_apply_phase_results(current_phase, result_data)

	# Special case: BATTLE phase can loop (1-3 battles per operational turn)
	if current_phase == Phase.BATTLE:
		battles_this_turn += 1
		if battles_this_turn < MAX_BATTLES_PER_TURN and result_data.get("play_another", false):
			# Reset battle phase for another round
			_phase_complete[Phase.BATTLE] = false
			_phase_complete[Phase.BATTLE_PREP] = false
			_phase_complete[Phase.DEPLOYMENT] = false
			_go_to_phase(Phase.BATTLE_PREP)
			return

	# Advance or end turn
	if current_phase < Phase.STRATEGIC:
		_go_to_phase(current_phase + 1)
	else:
		_complete_turn()


func is_phase_complete(phase: int) -> bool:
	return _phase_complete.get(phase, false)


func can_advance() -> bool:
	return _phase_complete.get(current_phase, false)


func can_play_another_battle() -> bool:
	return battles_this_turn < MAX_BATTLES_PER_TURN


func go_to_phase(phase: int) -> void:
	_go_to_phase(phase)


func _go_to_phase(phase: int) -> void:
	previous_phase = current_phase
	current_phase = phase
	phase_changed.emit(previous_phase, current_phase)
	_update_navigation()


func _complete_turn() -> void:
	# Auto-save via GameState
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") \
		if Engine.get_main_loop() else null
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(campaign)
	elif campaign and campaign.has_method("save_to_file") \
			and campaign.has_method("get_campaign_id"):
		var path: String = "user://saves/" + campaign.get_campaign_id() + ".save"
		campaign.save_to_file(path)

	campaign_turn_completed.emit(turn_number)
	operational_turn_completed.emit(operational_turn)
	_journal_log_turn_complete(turn_number, operational_turn)


func _reset_phase_completion() -> void:
	_phase_complete.clear()
	for i in range(PHASE_COUNT):
		_phase_complete[i] = false


func _update_navigation() -> void:
	var can_back := false  # No going back in Tactics turns
	var can_forward := _phase_complete.get(current_phase, false)
	navigation_updated.emit(can_back, can_forward)


func _apply_phase_results(phase: int, data: Dictionary) -> void:
	if not campaign:
		return

	match phase:
		Phase.ORDERS:
			# Store selected operational orders for this turn
			if data.has("orders") and "current_battle" in campaign:
				campaign.current_battle["orders"] = data.orders

		Phase.RECON:
			# Intel results — may reveal enemy composition
			if data.has("intel") and "current_battle" in campaign:
				campaign.current_battle["intel"] = data.intel

		Phase.BATTLE_PREP:
			# Store scenario data
			if data.has("scenario") and "current_battle" in campaign:
				campaign.current_battle["scenario"] = data.scenario

		Phase.DEPLOYMENT:
			# Deployment complete — record which units deployed
			if data.has("deployed_units") and "current_battle" in campaign:
				campaign.current_battle["deployed_units"] = data.deployed_units

		Phase.BATTLE:
			_apply_battle_results(data)

		Phase.POST_BATTLE:
			_apply_post_battle_results(data)

		Phase.ADVANCEMENT:
			_apply_advancement_results(data)

		Phase.STRATEGIC:
			_apply_strategic_results(data)


func _apply_battle_results(data: Dictionary) -> void:
	if not campaign:
		return

	# Record battle in campaign history
	if data.has("battle_result") and campaign.has_method("record_battle"):
		campaign.record_battle(data.battle_result)

	# ⭐ Step 2, Player Battle Points (Tactics p.96). This had NO PRODUCER anywhere:
	# `player_battle_points` was only ever decremented, so the resource the whole
	# operational layer spends could never be earned. The book: "Award 1 Player Battle
	# Point (1 PBP) for every tabletop battle victory in an Operational Zone", 0 for a
	# draw or inconclusive result, both sides' points cancel 1-for-1 in the same Zone,
	# max 2 gained per operational turn and max 3 held.
	#
	# ⚠ A tabletop defeat is read as an enemy victory, which is what earns THEM a point
	# and triggers the cancellation. That holds for the two-faction campaign this model
	# supports; the state carries no enemy PBP field, so nothing here tries to bank the
	# enemy's side of it.
	if data.has("battle_result"):
		var br: Variant = data.battle_result
		if br is Dictionary:
			var brd: Dictionary = br
			# Absent `won` means the result was never recorded either way — treat it as
			# inconclusive (0 PBP) rather than assuming a defeat.
			if brd.has("won"):
				if bool(brd.get("won", false)):
					battle_wins_this_turn += 1
				else:
					battle_losses_this_turn += 1
		_award_battle_points()

	# Apply casualties to campaign units
	var casualties: Dictionary = data.get("casualties", {})
	for unit_id in casualties:
		var models_lost: int = casualties[unit_id]
		for cu in campaign.campaign_units:
			if cu is Dictionary and cu.get("unit_id", "") == unit_id:
				cu["models_lost_current"] = models_lost
				cu["models_lost_total"] = cu.get("models_lost_total", 0) + models_lost
				cu["current_models"] = maxi(cu.get("current_models", 5) - models_lost, 0)
				if cu["current_models"] <= 0:
					cu["is_destroyed"] = true
				break


## Guard on the OWNER, not on the container's emptiness: an operational map with no
## zones yet is a legal state, and treating an empty dict as "no campaign" is how the
## salvage ledger silently disabled itself for every fresh campaign.
func _operational_map_dict() -> Dictionary:
	if campaign == null or not ("operational_map" in campaign):
		return {}
	var m: Variant = campaign.operational_map
	return m if m is Dictionary else {}


func _current_battle_points() -> int:
	return int(_operational_map_dict().get("player_battle_points", 0))


## Recompute this operational turn's PBP from the running tally (p.96).
func _award_battle_points() -> void:
	var m: Dictionary = _operational_map_dict()
	if m.is_empty():
		return
	var res: Dictionary = OperationalRulesRef.award_battle_points(
		battle_wins_this_turn, battle_losses_this_turn, _pbp_at_turn_start)
	m["player_battle_points"] = int(res.get("total", _pbp_at_turn_start))


func _apply_post_battle_results(data: Dictionary) -> void:
	if not campaign:
		return

	# Story events
	if data.has("story_event"):
		campaign.story_events.append(data.story_event)

	# Reset per-battle casualty tracking
	for cu in campaign.campaign_units:
		if cu is Dictionary:
			cu["models_lost_current"] = 0


func _apply_advancement_results(data: Dictionary) -> void:
	if not campaign:
		return

	# Veteran skills acquired
	var skills_acquired: Dictionary = data.get("skills_acquired", {})
	for unit_id in skills_acquired:
		if not campaign.veteran_skills.has(unit_id):
			campaign.veteran_skills[unit_id] = []
		var skill_data: Variant = skills_acquired[unit_id]
		if skill_data is Array:
			for skill in skill_data:
				campaign.veteran_skills[unit_id].append(skill)

	# CP spending
	var cp_spent: int = data.get("cp_spent", 0)
	if cp_spent > 0 and campaign.has_method("spend_cp"):
		campaign.spend_cp(cp_spent)

	# Roster changes (reinforcements, replacements)
	if data.has("roster_changes"):
		var changes: Array = data.roster_changes
		for change in changes:
			if change is Dictionary:
				match change.get("action", ""):
					"reinforce":
						_reinforce_unit(change)
					"replace":
						_replace_unit(change)


func _apply_strategic_results(data: Dictionary) -> void:
	if not campaign:
		return

	# Update operational map
	if data.has("operational_map_update"):
		var update: Dictionary = data.operational_map_update
		# Merge zone status changes
		if update.has("zones"):
			campaign.operational_map["zones"] = update.zones
		if update.has("player_cohesion"):
			campaign.operational_map["player_cohesion"] = update.player_cohesion
		if update.has("enemy_cohesion"):
			campaign.operational_map["enemy_cohesion"] = update.enemy_cohesion
		if update.has("focus_zone_id"):
			campaign.operational_map["focus_zone_id"] = update.focus_zone_id

	# PBP spending (commando raids). Never let it go negative: the panel is the only
	# producer today, but a payload is untrusted input once anything else can emit one.
	if data.has("pbp_spent"):
		campaign.operational_map["player_battle_points"] = maxi(
			int(campaign.operational_map.get("player_battle_points", 0))
			- int(data.pbp_spent), 0)

	# ⭐ Step 9 — Adjust Cohesion scores (Tactics p.99). This step is ABSENT from the
	# book's own 8-step summary list on p.96 and present as a section on p.99, which is
	# why every step list in this project stopped at 8 and no code path ever ended a
	# Tactics campaign. "Each time a region is lost, the Cohesion score of the losing
	# faction is reduced by 1"; at 0 the faction is defeated; "The campaign is won when
	# only one faction remains", and if all remaining factions reach 0 together the war
	# is inconclusive.
	#
	# `regions_lost` / `enemy_regions_lost` are optional: absent means no region changed
	# hands this turn, which is the common case and must not cost anybody Cohesion.
	var player_lost: int = int(data.get("regions_lost", 0))
	var enemy_lost: int = int(data.get("enemy_regions_lost", 0))
	if player_lost > 0 or enemy_lost > 0:
		var om: Dictionary = campaign.operational_map
		if player_lost > 0:
			om["player_cohesion"] = OperationalRulesRef.cohesion_after_region_loss(
				int(om.get("player_cohesion", 5)), player_lost)
		if enemy_lost > 0:
			om["enemy_cohesion"] = OperationalRulesRef.cohesion_after_region_loss(
				int(om.get("enemy_cohesion", 5)), enemy_lost)

	_check_campaign_end()

	# Clear current battle data for next turn
	campaign.current_battle = {}


## Step 9's consequence. `TacticsOperationalMap.is_player_victory()` and
## `.is_player_defeat()` have existed and been correct since the file was written, with
## ZERO callers — so a Tactics campaign could drive either side's Cohesion to 0 and
## nothing noticed. Emitting rather than mutating keeps the decision with the UI.
func _check_campaign_end() -> void:
	var m: Dictionary = _operational_map_dict()
	if m.is_empty():
		return
	var result: String = OperationalRulesRef.campaign_result(
		int(m.get("player_cohesion", 5)), int(m.get("enemy_cohesion", 5)))
	if result != "":
		campaign_ended.emit(result)


func _reinforce_unit(change: Dictionary) -> void:
	var unit_id: String = change.get("unit_id", "")
	var models_added: int = change.get("models_added", 0)
	for cu in campaign.campaign_units:
		if cu is Dictionary and cu.get("unit_id", "") == unit_id:
			cu["current_models"] = cu.get("current_models", 0) + models_added
			cu["is_destroyed"] = false
			break


func _replace_unit(change: Dictionary) -> void:
	var old_unit_id: String = change.get("old_unit_id", "")
	var new_unit: Dictionary = change.get("new_unit", {})
	if new_unit.is_empty():
		return
	# Remove old
	for i in range(campaign.campaign_units.size() - 1, -1, -1):
		var cu: Variant = campaign.campaign_units[i]
		if cu is Dictionary and cu.get("unit_id", "") == old_unit_id:
			campaign.campaign_units.remove_at(i)
			break
	# Add new
	campaign.campaign_units.append(new_unit)


# ── Journal integration (cross-mode coverage) ────────────────────────

func _journal() -> Node:
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/CampaignJournal")


func _journal_log_turn_start(turn: int, op_turn: int) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	j.create_entry({
		"type": "milestone",
		"title": "Tactics — Operational Turn %d begins" % op_turn,
		"description": "Campaign turn %d. Operational turn %d opens with Orders." % [
			turn, op_turn],
		"turn_number": turn,
		"tags": ["tactics", "milestone", "campaign_setup"],
		"mood": "neutral",
	})


func _journal_log_phase_complete(phase: int, _result_data: Dictionary) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	var phase_name: String = PHASE_NAMES.get(phase, "Unknown")
	# BATTLE phase can fire 1-3 times per operational turn; surface which one
	var desc: String = "Phase complete: %s." % phase_name
	if phase == Phase.BATTLE:
		desc += " Battle %d of %d this operational turn." % [
			battles_this_turn + 1, MAX_BATTLES_PER_TURN]
	# Pick entry type by phase semantics for taxonomy alignment
	var entry_type: String = "milestone"
	if phase == Phase.BATTLE:
		entry_type = "battle"
	elif phase == Phase.POST_BATTLE:
		entry_type = "event"
	elif phase == Phase.ADVANCEMENT:
		entry_type = "experience"
	j.create_entry({
		"type": entry_type,
		"title": "Tactics — %s" % phase_name,
		"description": desc,
		"turn_number": turn_number,
		"tags": ["tactics", "milestone"],
		"mood": "neutral",
	})


func _journal_log_turn_complete(turn: int, op_turn: int) -> void:
	var j: Node = _journal()
	if j == null or not j.has_method("create_entry"):
		return
	var battle_count_note: String = ""
	if battles_this_turn > 0:
		battle_count_note = " Battles fought: %d." % battles_this_turn
	j.create_entry({
		"type": "milestone",
		"title": "Tactics — Operational Turn %d completed" % op_turn,
		"description": "Campaign turn %d, operational turn %d finished.%s" % [
			turn, op_turn, battle_count_note],
		"turn_number": turn,
		"tags": ["tactics", "milestone"],
		"mood": "neutral",
	})
