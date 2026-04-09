class_name TacticsPhaseManager
extends Node

## Manages the Tactics 8-phase operational turn:
##   ORDERS → RECON → BATTLE_PREP → DEPLOYMENT → BATTLE →
##   POST_BATTLE → ADVANCEMENT → STRATEGIC
## Each phase must complete before the next begins.
## After STRATEGIC, the operational turn is complete.
## Source: Five Parsecs: Tactics rulebook pp.155-168

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)
signal operational_turn_started(op_turn: int)
signal operational_turn_completed(op_turn: int)
signal navigation_updated(can_back: bool, can_forward: bool)

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

	if campaign:
		if campaign.has_method("advance_turn"):
			campaign.advance_turn()
		if campaign.has_method("advance_operational_turn"):
			campaign.advance_operational_turn()

	_reset_phase_completion()
	campaign_turn_started.emit(turn_number)
	operational_turn_started.emit(operational_turn)
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

	# PBP spending (commando raids)
	if data.has("pbp_spent"):
		campaign.operational_map["player_battle_points"] = \
			campaign.operational_map.get("player_battle_points", 0) - data.pbp_spent

	# Clear current battle data for next turn
	campaign.current_battle = {}


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
