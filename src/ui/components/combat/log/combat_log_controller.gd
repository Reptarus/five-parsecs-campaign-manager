@tool
extends Node

## Required dependencies
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")
const BaseCombatManager = preload("res://src/base/combat/BaseCombatManager.gd")

## Combat Log Entry Types
enum CombatLogEntryType {
	COMBAT,
	MOVEMENT,
	OBJECTIVE,
	ENVIRONMENTAL,
	SPECIAL
}

## Validation results
class ValidationResult:
	var type: int = 0 # VerificationType.NONE
	var result: int = 0 # VerificationResult.NONE
	var message: String = ""
	var context: Dictionary = {}

	func _init(
		p_type: int = 0, # VerificationType.NONE
		p_result: int = 0, # VerificationResult.NONE
		p_message: String = "",
		p_context: Dictionary = {}
	) -> void:
		type = p_type
		result = p_result
		message = p_message
		context = p_context

	func is_error() -> bool:
		return result == 1 or result == 2 # ERROR or CRITICAL

	func is_warning() -> bool:
		return result == 3 # WARNING

	func is_success() -> bool:
		return result == 4 # SUCCESS

# Factory method to create ValidationResult objects
func create_result(
	p_type: int = 0, # VerificationType.NONE
	p_result: int = 0, # VerificationResult.NONE
	p_message: String = "",
	p_context: Dictionary = {}
) -> ValidationResult:
	var result = ValidationResult.new()
	result._init(p_type, p_result, p_message, p_context)
	return result

## Node references
@onready var combat_log_panel: PanelContainer = %CombatLogPanel
@onready var combat_manager: BaseCombatManager = get_node("/root/CombatManager")

## Properties
var log_entries: Array = []
var active_filters: Dictionary = {
	"combat": true,
	"ability": true,
	"reaction": true,
	"area": true,
	"damage": true,
	"modifier": true,
	"critical": true,
	"override": true,
	"result": true,
	"verification": true
}

## Called when the node enters scene tree
func _ready() -> void:
	if not combat_log_panel or not combat_manager:
		push_error("CombatLogController: Required nodes not found")
		return

	_connect_signals()
	_load_saved_filters()

## Connects all required signals
func _connect_signals() -> void:
	# Combat log panel signals
	combat_log_panel.entry_selected.connect(_on_entry_selected)
	combat_log_panel.filter_changed.connect(_on_filter_changed)
	combat_log_panel.context_action_requested.connect(_on_context_action_requested)
	combat_log_panel.verification_requested.connect(_on_verification_requested)

	# Combat manager signals
	combat_manager.combat_state_changed.connect(_on_combat_state_changed)
	combat_manager.combat_result_calculated.connect(_on_combat_result_calculated)
	combat_manager.combat_advantage_changed.connect(_on_combat_advantage_changed)
	combat_manager.combat_status_changed.connect(_on_combat_status_changed)
	combat_manager.manual_override_applied.connect(_on_manual_override_applied)
	combat_manager.special_ability_activated.connect(_on_special_ability_activated)
	combat_manager.reaction_triggered.connect(_on_reaction_triggered)
	combat_manager.area_effect_applied.connect(_on_area_effect_applied)

	# Verification signals
	combat_manager.verification_completed.connect(_on_verification_completed)
	combat_manager.verification_failed.connect(_on_verification_failed)

## Loads saved filters from game state
func _load_saved_filters() -> void:
	var game_state = get_node("/root/GameState")
	if not game_state:
		return

	var saved_filters = game_state.get_combat_log_filters()
	if saved_filters:
		active_filters = saved_filters

## Adds a new log entry
func add_log_entry(entry_type: String, entry_data: Dictionary) -> void:
	var entry = {
		"id": str(Time.get_unix_time_from_system()),
		"type": entry_type,
		"_data": entry_data,
		"timestamp": Time.get_datetime_string_from_system()
	}

	log_entries.append(entry)
	if _should_display_entry(entry):
		combat_log_panel.add_entry(entry)

## Checks if an entry should be displayed based on filters
func _should_display_entry(entry: Dictionary) -> bool:
	return active_filters.get(entry.type, true)

## Updates the display based on current filters
func _update_display() -> void:
	combat_log_panel.clear_entries()
	for entry in log_entries:
		if _should_display_entry(entry):
			combat_log_panel.add_entry(entry)

## Exports the combat log
func export_log() -> void:
	var export_data = {
		"entries": log_entries,
		"filters": active_filters,
		"timestamp": Time.get_datetime_string_from_system()
	}

	var file: FileAccess = FileAccess.open("user://combat_log.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(export_data))
		file.close()

## Signal handlers
func _on_entry_selected(entry_id: String) -> void:
	for entry in log_entries:
		if entry._id == entry_id:
			combat_log_panel.show_entry_details(entry)
			break

func _on_filter_changed(filter_type: String, enabled: bool) -> void:
	active_filters[filter_type] = enabled
	_update_display()

func _on_context_action_requested(entry_id: String, action: String) -> void:
	var entry: Dictionary = {}
	for e in log_entries:
		if e._id == entry_id:
			entry = e
			break

	if not entry:
		return

	match action:
		"verify":
			_verify_entry(entry)
		"export":
			_export_entry(entry)
		"revert":
			_revert_entry(entry)

func _on_verification_requested(entry_id: String) -> void:
	for entry in log_entries:
		if entry._id == entry_id:
			_verify_entry(entry)
			break

func _verify_entry(entry: Dictionary) -> void:
	match entry.type:
		"combat":
			combat_manager.verify_state(0) # COMBAT
		"movement":
			combat_manager.verify_state(1) # MOVEMENT
		"status":
			combat_manager.verify_state(2) # STATE
		"resource":
			combat_manager.verify_state(3) # DEPLOYMENT
		"override":
			combat_manager.verify_state(1) # MOVEMENT

func _export_entry(entry: Dictionary) -> void:
	var file: FileAccess = FileAccess.open("user://combat_log.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(entry))
		if file: file.close()

func _revert_entry(entry: Dictionary) -> void:
	match entry.type:
		"override":
			combat_manager.revert_override.emit(entry.data)
		"status":
			combat_manager.revert_status_change.emit(entry.data)
		"resource":
			combat_manager.revert_resource_change.emit(entry.data)

## Combat manager signal handlers
func _on_combat_state_changed(new_state: Dictionary) -> void:
	add_log_entry("combat", {
		"type": "state_change",
		"_state": new_state
	})

func _on_combat_result_calculated(attacker: Character, target: Character, result: Dictionary) -> void:
	combat_log_panel.log_combat_result(
		attacker.get_display_name(),
		target.get_display_name(),
		result
	)

func _on_combat_advantage_changed(character: Character, advantage: GlobalEnums.CombatAdvantage) -> void:
	add_log_entry("combat", {
		"type": "advantage",
		"character": character.get_id(),
		"advantage": advantage
	})

func _on_combat_status_changed(character: Character, status: GlobalEnums.CombatStatus) -> void:
	add_log_entry("status", {
		"type": "status_change",
		"character": character.get_id(),
		"status": status
	})

func _on_manual_override_applied(override_type: String, override_data: Dictionary) -> void:
	add_log_entry("override", {
		"type": override_type,
		"_data": override_data
	})

## Verification signal handlers
func _on_verification_completed(verification_type: int, result: int, details: Dictionary) -> void:
	add_log_entry("verification", {
		"_type": verification_type,
		"result": result,
		"details": details
	})

	combat_log_panel.show_verification_result(str(Time.get_unix_time_from_system()), {
		"status": result,
		"details": details
	})

func _on_verification_failed(verification_type: int, error: String) -> void:
	add_log_entry("verification", {
		"_type": verification_type,
		"result": 1, # ERROR
		"details": {"error": error}
	})

	combat_log_panel.show_verification_result(str(Time.get_unix_time_from_system()), {
		"status": 1, # ERROR
		"details": {"error": error}
	})

## Signal handlers for new combat events
func _on_special_ability_activated(character: Character, ability: String, targets: Array[Character], cooldown: int) -> void:
	var target_names := targets.map(func(t): return t.get_display_name())
	combat_log_panel.log_special_ability(
		character.get_display_name(),
		ability,
		target_names,
		cooldown
	)

func _on_reaction_triggered(character: Character, reaction: String, trigger: String) -> void:
	combat_log_panel.log_reaction(
		character.get_display_name(),
		reaction,
		trigger
	)

func _on_area_effect_applied(effect: String, center: Vector2, radius: float, affected: Array[Character]) -> void:
	var affected_names := affected.map(func(c): return c.get_display_name())
	combat_log_panel.log_area_effect(
		effect,
		center,
		radius,
		affected_names
	)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.call(method_name, args)
	return null