class_name FiveParcecsSystem
extends Node

# Core Battle Signals
signal battle_started
signal battle_ended
signal phase_changed(new_phase: BattlePhase)
signal state_saved(checkpoint_data: Dictionary)
signal state_loaded(checkpoint_data: Dictionary)

# Combat Signals
signal combat_effect_triggered(effect_name: String, source: Character, target: Character)
signal reaction_opportunity(unit: Character, reaction_type: String, source: Character)
signal attack_resolved(attacker: Character, target: Character, result: Dictionary)
signal damage_applied(target: Character, amount: int)

# Core Constants
const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const BattleEventManager = preload("res://Resources/Battle/Events/BattleEventManager.gd")
const TerrainTypes = preload("res://Resources/Battle/Core/TerrainTypes.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")

# Core Enums
enum BattlePhase {
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTIVATION,
	REACTION,
	BRAWL,
	CLEANUP
}

# Core Variables
static var battle_phases = BattlePhase
var game_state: Node
var event_manager: BattleEventManager
var current_battle_state: Dictionary = {}
var initial_state: Dictionary

# Combat Components
@onready var combat_manager: Node = $CombatManager
@onready var combat_resolver: Node = $CombatResolver
@onready var battlefield_manager: Node = $BattlefieldManager

# Combat State
var active_combatants: Array[Character] = []
var reaction_shots_remaining: Dictionary = {}

func _ready() -> void:
	_validate_combat_components()
	_connect_signals()

func _validate_combat_components() -> void:
	var missing_components = []
	
	if not combat_manager:
		missing_components.append("CombatManager")
	if not combat_resolver:
		missing_components.append("CombatResolver")
	if not battlefield_manager:
		missing_components.append("BattlefieldManager")
	
	if not missing_components.is_empty():
		push_error("FiveParcecsSystem: Missing required components: %s" % missing_components)
		return
	
	# Set up component references
	combat_manager.battlefield_manager = battlefield_manager
	combat_resolver.combat_manager = combat_manager
	combat_resolver.battlefield_manager = battlefield_manager
	combat_resolver.battle_state_machine = self

func _connect_signals() -> void:
	if combat_manager:
		combat_manager.combat_effect_triggered.connect(_on_combat_effect_triggered)
		combat_manager.reaction_opportunity.connect(_on_reaction_opportunity)
		combat_manager.terrain_updated.connect(_on_terrain_updated)
		combat_manager.battlefield_effect_applied.connect(_on_battlefield_effect_applied)
	
	if combat_resolver:
		combat_resolver.combat_started.connect(_on_combat_started)
		combat_resolver.combat_ended.connect(_on_combat_ended)
		combat_resolver.critical_hit.connect(_on_critical_hit)
		combat_resolver.special_effect_triggered.connect(_on_special_effect)
		combat_resolver.target_selected.connect(_on_target_selected)
		combat_resolver.target_invalid.connect(_on_target_invalid)

func _init(_game_state: Node) -> void:
	game_state = _game_state
	event_manager = BattleEventManager.new()
	_initialize_combat_system()

func _initialize_combat_system() -> void:
	reaction_shots_remaining.clear()
	active_combatants.clear()
	current_battle_state.clear()

# Combat Signal Handlers
func _on_combat_started(attacker: Character, defender: Character) -> void:
	event_manager.emit_event("combat_started", {
		"attacker": attacker,
		"defender": defender
	})

func _on_combat_ended(attacker: Character, defender: Character, hit: bool, damage: int) -> void:
	event_manager.emit_event("combat_ended", {
		"attacker": attacker,
		"defender": defender,
		"hit": hit,
		"damage": damage
	})

func _on_critical_hit(attacker: Character, defender: Character, multiplier: float) -> void:
	event_manager.emit_event("critical_hit", {
		"attacker": attacker,
		"defender": defender,
		"multiplier": multiplier
	})

func _on_special_effect(attacker: Character, defender: Character, effect: String) -> void:
	event_manager.emit_event("special_effect", {
		"attacker": attacker,
		"defender": defender,
		"effect": effect
	})

func _on_combat_effect_triggered(effect_name: String, source: Character, target: Character) -> void:
	combat_effect_triggered.emit(effect_name, source, target)

func _on_reaction_opportunity(unit: Character, reaction_type: String, source: Character) -> void:
	reaction_opportunity.emit(unit, reaction_type, source)

func _on_terrain_updated(position: Vector2i, old_type: int, new_type: int) -> void:
	event_manager.emit_event("terrain_updated", {
		"position": position,
		"old_type": old_type,
		"new_type": new_type
	})

func _on_battlefield_effect_applied(effect_type: String, position: Vector2i) -> void:
	event_manager.emit_event("battlefield_effect", {
		"type": effect_type,
		"position": position
	})

func _on_target_selected(attacker: Character, target: Character) -> void:
	event_manager.emit_event("target_selected", {
		"attacker": attacker,
		"target": target
	})

func _on_target_invalid(attacker: Character, reason: String) -> void:
	event_manager.emit_event("target_invalid", {
		"attacker": attacker,
		"reason": reason
	})

# Combat Resolution Interface
func resolve_attack(attacker: Character, target: Character, is_snap_fire: bool = false) -> void:
	if not _validate_combat_action(attacker, target):
		return
		
	var action = GlobalEnums.UnitAction.SNAP_FIRE if is_snap_fire else GlobalEnums.UnitAction.ATTACK
	combat_resolver.resolve_combat_action(attacker, action)

func resolve_melee(attacker: Character, target: Character) -> void:
	if not _validate_combat_action(attacker, target):
		return
		
	combat_resolver.resolve_combat_action(attacker, GlobalEnums.UnitAction.BRAWL)

# Combat Validation
func _validate_combat_action(attacker: Character, target: Character) -> bool:
	if not combat_resolver or not combat_manager:
		push_error("FiveParcecsSystem: Combat components not initialized")
		return false
	
	if not attacker or not target:
		push_error("FiveParcecsSystem: Invalid attacker or target")
		return false
	
	if not attacker in active_combatants or not target in active_combatants:
		push_error("FiveParcecsSystem: Units not in active combat")
		return false
	
	return true

# Helper Functions
func _get_elevation(pos: Vector2) -> int:
	if not combat_manager:
		return 0
		
	var terrain_mod = combat_manager.calculate_terrain_modifier(Vector2i(pos), Vector2i(pos))
	return int(terrain_mod * 2) # Convert modifier to elevation units

func _get_positions_in_radius(center: Vector2, radius: int) -> Array:
	if not combat_manager:
		return []
		
	var positions = []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var pos = Vector2(center.x + x, center.y + y)
			if pos.distance_to(center) <= radius and combat_manager.is_valid_position(Vector2i(pos)):
				positions.append(pos)
	return positions

func _get_character_at_position(pos: Vector2) -> Character:
	if not combat_manager:
		return null
		
	for unit in active_combatants:
		if combat_manager.get_character_position(unit) == pos:
			return unit
	return null