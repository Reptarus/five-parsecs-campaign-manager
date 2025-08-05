extends RefCounted
class_name FiveParsecsCombatMigration

## Five Parsecs Combat System Migration Adapter
## Provides backward compatibility during combat system consolidation
## Handles migration from 8 Base classes to 3 consolidated files
## Ensures existing combat UI and systems continue to work

const FiveParsecsCombatSystem = preload("res://src/core/combat/FiveParsecsCombatSystem.gd")
const FiveParsecsBattlefield = preload("res://src/core/combat/FiveParsecsBattlefield.gd")
const FiveParsecsCombatData = preload("res://src/core/combat/FiveParsecsCombatData.gd")

## Legacy class mapping for backward compatibility
static var legacy_class_mapping: Dictionary = {
	"FiveParsecsCombatManager": "FiveParsecsCombatSystem",
	"FiveParsecsMainBattleController": "FiveParsecsCombatSystem", 
	"FiveParsecsBattlefieldManager": "FiveParsecsBattlefield",
	"FiveParsecsBattlefieldGenerator": "FiveParsecsBattlefield",
	"FiveParsecsBattleData": "FiveParsecsCombatData",
	"FiveParsecsBattleRules": "FiveParsecsCombatData",
	"FiveParsecsBattleCharacter": "FiveParsecsCombatData",
	"base_combat_system": "FiveParsecsCombatSystem"
}

## Migration entry point for legacy combat systems
static func migrate_combat_system(legacy_system: Node) -> Node:
	"""
	Migrate legacy combat system to new consolidated system
	Handles migration from any of the 8 Base combat classes
	"""
	if not legacy_system:
		push_error("FiveParsecsCombatMigration: Cannot migrate null system")
		return null
	
	print("FiveParsecsCombatMigration: Migrating legacy system: ", legacy_system.get_class())
	
	var legacy_class = legacy_system.get_class()
	var target_class = legacy_class_mapping.get(legacy_class, "")
	
	match target_class:
		"FiveParsecsCombatSystem":
			return _migrate_to_combat_system(legacy_system)
		"FiveParsecsBattlefield":
			return _migrate_to_battlefield(legacy_system)
		"FiveParsecsCombatData":
			return _migrate_to_combat_data(legacy_system)
		_:
			push_warning("FiveParsecsCombatMigration: Unknown legacy class: " + legacy_class)
			return _migrate_generic_combat_system(legacy_system)

## Migration Methods for Specific Legacy Classes

static func _migrate_to_combat_system(legacy_system: Node) -> FiveParsecsCombatSystem:
	"""Migrate BaseCombatManager/BaseMainBattleController to FiveParsecsCombatSystem"""
	var new_system = FiveParsecsCombatSystem.new()
	
	# Migrate common properties
	if legacy_system.has_method("get_battle_active"):
		new_system.combat_active = legacy_system.get_battle_active()
	elif legacy_system.has("battle_active"):
		new_system.combat_active = legacy_system.battle_active
	
	if legacy_system.has("current_turn"):
		new_system.current_turn = legacy_system.current_turn
	
	if legacy_system.has("active_faction"):
		new_system.active_faction = str(legacy_system.active_faction)
	
	# Migrate character arrays
	if legacy_system.has_method("get_crew_characters"):
		new_system.crew_characters = legacy_system.get_crew_characters()
	elif legacy_system.has("crew_characters"):
		new_system.crew_characters = legacy_system.crew_characters
	
	if legacy_system.has_method("get_enemy_characters"):
		new_system.enemy_characters = legacy_system.get_enemy_characters()
	elif legacy_system.has("enemy_characters"):
		new_system.enemy_characters = legacy_system.enemy_characters
	
	# Migrate signals if possible
	_migrate_combat_signals(legacy_system, new_system)
	
	print("FiveParsecsCombatMigration: Migrated to FiveParsecsCombatSystem")
	return new_system

static func _migrate_to_battlefield(legacy_system: Node) -> FiveParsecsBattlefield:
	"""Migrate BattlefieldManager/BattlefieldGenerator to FiveParsecsBattlefield"""
	var new_battlefield = FiveParsecsBattlefield.new()
	
	# Migrate battlefield size
	if legacy_system.has("grid_size"):
		new_battlefield.battlefield_size = legacy_system.grid_size
	elif legacy_system.has("GRID_SIZE"):
		new_battlefield.battlefield_size = legacy_system.GRID_SIZE
	
	# Migrate terrain settings
	if legacy_system.has("terrain_density"):
		new_battlefield.terrain_density = legacy_system.terrain_density
	elif legacy_system.has("_terrain_density"):
		new_battlefield.terrain_density = legacy_system._terrain_density
	
	# Migrate character positions if available
	if legacy_system.has_method("get_character_positions"):
		new_battlefield.character_positions = legacy_system.get_character_positions()
	elif legacy_system.has("character_positions"):
		new_battlefield.character_positions = legacy_system.character_positions
	
	# Migrate terrain grid if available
	if legacy_system.has_method("get_terrain_grid"):
		var legacy_grid = legacy_system.get_terrain_grid()
		if legacy_grid:
			new_battlefield.terrain_grid = legacy_grid
	elif legacy_system.has("terrain_grid"):
		new_battlefield.terrain_grid = legacy_system.terrain_grid
	
	print("FiveParsecsCombatMigration: Migrated to FiveParsecsBattlefield")
	return new_battlefield

static func _migrate_to_combat_data(legacy_system: Node) -> FiveParsecsCombatData:
	"""Migrate BattleData/BattleRules/BattleCharacter to FiveParsecsCombatData"""
	var new_data = FiveParsecsCombatData.new()
	
	# Migration is mostly handled by the new system's default values
	# since FiveParsecsCombatData is primarily constants and methods
	
	print("FiveParsecsCombatMigration: Migrated to FiveParsecsCombatData")
	return new_data

static func _migrate_generic_combat_system(legacy_system: Node) -> FiveParsecsCombatSystem:
	"""Generic migration for unknown combat systems"""
	print("FiveParsecsCombatMigration: Performing generic migration")
	return FiveParsecsCombatSystem.new()

## Signal Migration Support

static func _migrate_combat_signals(legacy_system: Node, new_system: FiveParsecsCombatSystem) -> void:
	"""Migrate signals from legacy system to new system"""
	var legacy_signals = legacy_system.get_signal_list()
	
	for signal_info in legacy_signals:
		var signal_name = signal_info.name
		
		# Map legacy signals to new signals
		var new_signal_name = _map_legacy_signal(signal_name)
		if not new_signal_name.is_empty():
			_connect_migrated_signal(legacy_system, signal_name, new_system, new_signal_name)

static func _map_legacy_signal(legacy_signal: String) -> String:
	"""Map legacy signal names to new signal names"""
	var signal_mapping = {
		"battle_initialized": "combat_started",
		"battle_started": "combat_started", 
		"battle_ended": "combat_ended",
		"turn_started": "turn_started",
		"turn_ended": "turn_ended",
		"unit_activated": "character_activated",
		"character_position_updated": "",  # Handled by battlefield
		"combat_result_calculated": "combat_result_calculated"
	}
	
	return signal_mapping.get(legacy_signal, "")

static func _connect_migrated_signal(legacy_system: Node, legacy_signal: String, new_system: Node, new_signal: String) -> void:
	"""Connect legacy signal to new signal for compatibility"""
	if legacy_system.has_signal(legacy_signal) and new_system.has_signal(new_signal):
		# Create a bridge function to forward the signal
		var callable = func(args): new_system.emit_signal(new_signal, args)
		legacy_system.connect(legacy_signal, callable)

## Data Migration Support

static func migrate_battle_data(legacy_data: Dictionary) -> Dictionary:
	"""Migrate legacy battle data to new format"""
	var migrated_data = {}
	
	# Standard field mappings
	var field_mappings = {
		"battle_id": "battle_id",
		"turn_number": "current_turn", 
		"active_player": "active_faction",
		"battlefield_size": "battlefield_size",
		"crew": "crew_characters",
		"enemies": "enemy_characters"
	}
	
	for old_field in field_mappings:
		if legacy_data.has(old_field):
			var new_field = field_mappings[old_field]
			migrated_data[new_field] = legacy_data[old_field]
	
	# Handle special cases
	if legacy_data.has("battle_state"):
		migrated_data["current_phase"] = _convert_battle_state(legacy_data.battle_state)
	
	if legacy_data.has("terrain_data"):
		migrated_data["terrain_grid"] = _convert_terrain_data(legacy_data.terrain_data)
	
	return migrated_data

static func _convert_battle_state(legacy_state) -> int:
	"""Convert legacy battle state to new phase enum"""
	if legacy_state is String:
		match legacy_state.to_lower():
			"setup": return 0  # CombatPhase.SETUP
			"deployment": return 1  # CombatPhase.DEPLOYMENT
			"battle", "combat": return 2  # CombatPhase.BATTLE
			"resolution": return 3  # CombatPhase.RESOLUTION
			"cleanup": return 4  # CombatPhase.CLEANUP
			_: return 0
	elif legacy_state is int:
		return clamp(legacy_state, 0, 4)
	
	return 0

static func _convert_terrain_data(legacy_terrain) -> Array:
	"""Convert legacy terrain data to new format"""
	if legacy_terrain is Array:
		return legacy_terrain
	elif legacy_terrain is Dictionary:
		# Convert dictionary-based terrain to grid array
		var grid: Array[Array] = []
		# This would need specific implementation based on legacy format
		return grid
	
	return []

## UI Migration Support

static func create_ui_adapter(legacy_ui: Control, new_combat_system: FiveParsecsCombatSystem) -> void:
	"""Create adapter for legacy UI to work with new combat system"""
	if not legacy_ui or not new_combat_system:
		return
	
	# Connect new system signals to legacy UI methods
	if legacy_ui.has_method("_on_battle_started"):
		new_combat_system.combat_started.connect(legacy_ui._on_battle_started)
	
	if legacy_ui.has_method("_on_battle_ended"):
		new_combat_system.combat_ended.connect(legacy_ui._on_battle_ended)
	
	if legacy_ui.has_method("_on_turn_started"):
		new_combat_system.turn_started.connect(legacy_ui._on_turn_started)
	
	if legacy_ui.has_method("_on_character_activated"):
		new_combat_system.character_activated.connect(legacy_ui._on_character_activated)
	
	print("FiveParsecsCombatMigration: Created UI adapter for ", legacy_ui.name)

## Testing and Validation

static func validate_migration(legacy_system: Node, new_system: Node) -> bool:
	"""Validate that migration preserved essential functionality"""
	if not legacy_system or not new_system:
		return false
	
	# Basic validation checks
	if legacy_system.has("current_turn") and new_system.has("current_turn"):
		if legacy_system.current_turn != new_system.current_turn:
			push_warning("Migration validation: Turn number mismatch")
			return false
	
	if legacy_system.has("combat_active") and new_system.has("combat_active"):
		if legacy_system.combat_active != new_system.combat_active:
			push_warning("Migration validation: Combat state mismatch")
			return false
	
	print("FiveParsecsCombatMigration: Migration validation successful")
	return true

## Legacy Method Wrappers for Compatibility

class LegacyCombatManagerWrapper:
	"""Wrapper to make new system compatible with legacy BaseCombatManager calls"""
	var combat_system: FiveParsecsCombatSystem
	
	func _init(system: FiveParsecsCombatSystem):
		combat_system = system
	
	func initialize_battle(crew: Array, enemies: Array) -> void:
		combat_system.start_combat(crew, enemies)
	
	func get_battle_active() -> bool:
		return combat_system.is_combat_active()
	
	func get_current_turn() -> int:
		return combat_system.current_turn
	
	func process_turn() -> void:
		# Turn processing is now automatic in new system
		pass

class LegacyBattlefieldWrapper:
	"""Wrapper to make new battlefield compatible with legacy calls"""
	var battlefield: FiveParsecsBattlefield
	
	func _init(bf: FiveParsecsBattlefield):
		battlefield = bf
	
	func generate_random_battlefield() -> Dictionary:
		battlefield.generate_battlefield()
		return battlefield.get_battlefield_state()
	
	func place_character(character, position: Vector2i) -> bool:
		return battlefield.place_character(character, position)
	
	func get_character_position(character) -> Vector2i:
		return battlefield.get_character_position(character)

## Migration Factory Methods

static func create_migrated_combat_system(legacy_data: Dictionary = {}) -> FiveParsecsCombatSystem:
	"""Create new combat system with migrated data"""
	var system = FiveParsecsCombatSystem.new()
	
	if not legacy_data.is_empty():
		var migrated = migrate_battle_data(legacy_data)
		# Apply migrated data to system
		if migrated.has("current_turn"):
			system.current_turn = migrated.current_turn
		if migrated.has("active_faction"):
			system.active_faction = migrated.active_faction
		if migrated.has("crew_characters"):
			system.crew_characters = migrated.crew_characters
		if migrated.has("enemy_characters"):
			system.enemy_characters = migrated.enemy_characters
	
	return system

static func create_legacy_wrapper(new_system: FiveParsecsCombatSystem) -> LegacyCombatManagerWrapper:
	"""Create legacy compatibility wrapper"""
	return LegacyCombatManagerWrapper.new(new_system)