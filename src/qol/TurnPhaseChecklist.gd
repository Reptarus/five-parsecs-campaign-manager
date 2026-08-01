extends Node
## TurnPhaseChecklist autoload - Prevent forgotten steps with validation
## Integrates with existing GameState.gd phase system

signal action_completed(action_id: String)
signal phase_validation_changed(can_advance: bool)

## Checklist storage
var completed_actions: Dictionary = {}  # action_id -> bool
var current_phase_checklist: Dictionary = {}

## Configuration
var veteran_mode: bool = false  # Minimizes guidance for experienced players

## Phase checklist definitions (extend as needed)
const PHASE_CHECKLISTS = {
	"upkeep": {
		"required": ["pay_crew_upkeep", "pay_ship_maintenance", "resolve_injuries"],
		"optional": ["check_story_events", "purchase_equipment", "train_crew"]
	},
	"world_steps": {
		"required": ["patron_job_check", "enemy_encounter_check"],
		"optional": ["hire_crew", "trade_goods", "repair_ship", "visit_location"]
	},
	"battle": {
		"required": ["deploy_crew", "fight_battle", "resolve_casualties"],
		"optional": ["loot_battlefield", "capture_enemies"]
	},
	"post_battle": {
		"required": ["collect_loot", "resolve_injuries", "gain_experience"],
		"optional": ["salvage_equipment", "interrogate_prisoners"]
	}
}

## Action descriptions for UI
const ACTION_DESCRIPTIONS = {
	"pay_crew_upkeep": "Pay crew upkeep costs",
	"pay_ship_maintenance": "Pay ship maintenance",
	"resolve_injuries": "Resolve wounded crew status",
	"patron_job_check": "Check for patron job offers",
	"enemy_encounter_check": "Roll for enemy encounters",
	# ... extend as needed
}

func get_phase_checklist(phase: String) -> Dictionary:
	## Get checklist for a phase
	if not PHASE_CHECKLISTS.has(phase):
		return {"required": [], "optional": []}
	
	return PHASE_CHECKLISTS[phase]

func load_checklist_for_phase(phase: String) -> void:
	## Load and reset checklist for new phase
	current_phase_checklist = get_phase_checklist(phase)
	completed_actions.clear()
	
	# Initialize all actions as incomplete
	for action in current_phase_checklist.required:
		completed_actions[action] = false
	for action in current_phase_checklist.optional:
		completed_actions[action] = false
	
	phase_validation_changed.emit(can_advance_phase())

func mark_action_complete(action_id: String, completed: bool = true) -> void:
	## Mark an action as completed/incomplete
	if not completed_actions.has(action_id):
		push_warning("Unknown action: " + action_id)
		return
	
	completed_actions[action_id] = completed
	action_completed.emit(action_id)
	phase_validation_changed.emit(can_advance_phase())

func can_advance_phase() -> bool:
	## Check if all required actions are complete
	if current_phase_checklist.is_empty():
		return true
	
	for action in current_phase_checklist.required:
		if not completed_actions.get(action, false):
			return false
	
	return true

func get_incomplete_required_actions() -> Array[String]:
	## Get list of incomplete required actions
	var incomplete: Array[String] = []
	
	for action in current_phase_checklist.get("required", []):
		if not completed_actions.get(action, false):
			incomplete.append(action)
	
	return incomplete

func get_completion_status() -> Dictionary:
	## Get checklist completion statistics
	var required_total = current_phase_checklist.get("required", []).size()
	var optional_total = current_phase_checklist.get("optional", []).size()
	var required_complete = 0
	var optional_complete = 0
	
	for action in current_phase_checklist.get("required", []):
		if completed_actions.get(action, false):
			required_complete += 1
	
	for action in current_phase_checklist.get("optional", []):
		if completed_actions.get(action, false):
			optional_complete += 1
	
	return {
		"required_complete": required_complete,
		"required_total": required_total,
		"optional_complete": optional_complete,
		"optional_total": optional_total,
		"can_advance": can_advance_phase()
	}

func get_action_description(action_id: String) -> String:
	## Get human-readable description of action
	return ACTION_DESCRIPTIONS.get(action_id, action_id.capitalize().replace("_", " "))

## Save/Load
func load_from_save(save_data: Dictionary) -> void:
	## THE KEY MISMATCH THIS FIXES: the writer
	## (FiveParsecsCampaignCore._collect_qol_data) stores this block under
	## "turn_checklist", and NOTHING in the repo has ever written
	## "checklist_settings" — so this function early-returned on every load and
	## veteran mode silently reverted to false after each quit. The READER is
	## corrected rather than the writer, because every existing save already
	## carries "turn_checklist"; the old name is kept as a fallback so a save
	## written by some future/branch build still loads.
	if not save_data.has("qol_data"):
		return
	var qol: Dictionary = save_data["qol_data"]
	var checklist_data: Dictionary = qol.get("turn_checklist",
		qol.get("checklist_settings", {}))
	if checklist_data.is_empty():
		return

	veteran_mode = checklist_data.get("veteran_mode", false)
	# Mid-turn progress. Neither of these was serialized at all, so a player who
	# saved partway through a phase came back to an empty checklist and could be
	# blocked from advancing (or re-prompted for steps they had already done).
	var actions: Variant = checklist_data.get("completed_actions", {})
	completed_actions = (actions as Dictionary).duplicate(true) if actions is Dictionary else {}
	var phase_cl: Variant = checklist_data.get("current_phase_checklist", {})
	current_phase_checklist = (phase_cl as Dictionary).duplicate(true) \
		if phase_cl is Dictionary else {}

func save_to_dict() -> Dictionary:
	return {
		"veteran_mode": veteran_mode,
		"completed_actions": completed_actions.duplicate(true),
		"current_phase_checklist": current_phase_checklist.duplicate(true),
	}
