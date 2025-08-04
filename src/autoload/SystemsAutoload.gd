extends Node

## Systems Autoload for Five Parsecs Campaign Manager
##
## Provides access to consolidated game systems:
	## - PatronSystem (formerly PatronManager + PatronJobManager + ExtendedConnectionsManager)
## - EconomySystem (formerly ResourceManager + EconomyManager + WorldEconomyManager)
## - FactionSystem (formerly RivalManager + FactionManager + ExpandedFactionManager)

# Load system classes - with error handling (fixed paths)
const PatronSystem = preload("res://src/core/systems/PatronSystem.gd")
const EconomySystem = preload("res://src/core/systems/EconomySystem.gd")
const FactionSystem = preload("res://src/core/systems/FactionSystem.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# System instances
var patron_system: PatronSystem
var economy_system: EconomySystem
var faction_system: FactionSystem

# Initialization status
var systems_initialized: bool = false
var initialization_errors: Array[String] = []

signal systems_ready()
signal system_error(system_name: String, error: String)

func _ready() -> void:
	name = "SystemsAutoload"
	print("SystemsAutoload: Starting system initialization...")

	# Wait for critical autoloads to be ready first
	await _wait_for_critical_autoloads()
	
	# Initialize systems in dependency order
	_initialize_systems()

func _wait_for_critical_autoloads() -> void:
	"""Wait for critical autoloads to be ready before initializing systems"""
	print("SystemsAutoload: Waiting for critical autoloads...")
	
	# Wait one frame to ensure all autoloads are registered
	await get_tree().process_frame
	
	# Wait for DataManager specifically - using signal-based approach
	var data_manager = get_node_or_null("/root/DataManagerAutoload") as Node
	if data_manager:
		# Check if DataManager static system has finished loading using public API
		if not DataManager.is_system_ready():
			print("SystemsAutoload: Waiting for DataManager initialization signal...")
			# Wait for initialization_complete signal
			await data_manager.initialization_complete
			print("SystemsAutoload: DataManager initialization complete, proceeding with system initialization")
		else:
			print("SystemsAutoload: DataManager already loaded, proceeding immediately")
	else:
		push_warning("SystemsAutoload: DataManager not found, attempting fallback initialization")
		# Fallback for edge cases
		DataManager.initialize_data_system()
	
	# Ensure other critical autoloads are available
	var critical_autoloads: Array[String] = [
		"GlobalEnums",
		"GameStateManagerAutoload",
		"SceneRouter"
	]
	
	for autoload_name in critical_autoloads:
		var autoload_node = get_node_or_null("/root/" + autoload_name) as Node
		if not autoload_node:
			push_warning("SystemsAutoload: Critical autoload '%s' not found" % autoload_name)
		else:
			print("SystemsAutoload: Critical autoload '%s' verified" % autoload_name)

func _initialize_systems() -> void:
	"""Initialize all consolidated systems"""
	initialization_errors.clear()

	# Create system instances with error handling
	if EconomySystem:
		economy_system = EconomySystem.new()
		add_child(economy_system)
	else:
		initialization_errors.append("Failed to load EconomySystem class")

	if PatronSystem:
		patron_system = PatronSystem.new()
		add_child(patron_system)
	else:
		initialization_errors.append("Failed to load PatronSystem class")

	if FactionSystem:
		faction_system = FactionSystem.new()
		add_child(faction_system)
	else:
		initialization_errors.append("Failed to load FactionSystem class")

	# Initialize systems with null checks
	var economy_success: bool = true
	var patron_success: bool = true
	var faction_success: bool = true

	if economy_system:
		economy_success = economy_system.initialize()
	else:
		economy_success = false

	if patron_system:
		patron_success = patron_system.initialize()
	else:
		patron_success = false

	if faction_system:
		faction_success = faction_system.initialize()
	else:
		faction_success = false

	if not economy_success:
		var error: String = "Failed to initialize EconomySystem"
		safe_call_method(initialization_errors, "append", [error])
		system_error.emit("EconomySystem", error)

	if not patron_success:
		var error: String = "Failed to initialize PatronSystem"
		safe_call_method(initialization_errors, "append", [error])
		system_error.emit("PatronSystem", error)

	if not faction_success:
		var error: String = "Failed to initialize FactionSystem"
		safe_call_method(initialization_errors, "append", [error])
		system_error.emit("FactionSystem", error)

	systems_initialized = economy_success and patron_success and faction_success

	if systems_initialized:
		print("SystemsAutoload: All systems initialized successfully")
		systems_ready.emit()
	else:
		push_error("SystemsAutoload: System initialization failed - errors: " + str(initialization_errors))

# =====================================================
# ECONOMY SYSTEM ACCESS
# =====================================================

func get_economy_system() -> EconomySystem:
	"""Get the EconomySystem instance"""
	return economy_system

func get_resource(resource_type: int) -> int:
	"""Get resource amount (convenience method)"""
	if economy_system:
		return economy_system.get_resource(resource_type)
	return 0

func modify_resource(resource_type: int, amount: int, source: String = "system") -> void:
	"""Modify resource amount (convenience method)"""
	if economy_system:
		economy_system.modify_resource(resource_type, amount, source)

func calculate_item_price(item: Resource, is_buying: bool, planet_name: String = "") -> int:
	"""Calculate item price (convenience method)"""
	if economy_system:
		return economy_system.calculate_item_price(item, is_buying, planet_name)
	return 0

func get_economy_status(planet_name: String) -> int:
	"""Get planetary economy status (convenience method)"""
	if economy_system:
		return economy_system.get_economy_status(planet_name)
	return 2 # STABLE

# =====================================================
# PATRON SYSTEM ACCESS
# =====================================================

func get_patron_system() -> PatronSystem:
	"""Get the PatronSystem instance"""
	return patron_system

func generate_patron() -> Dictionary:
	"""Generate new patron (convenience method)"""
	if patron_system:
		return patron_system.generate_patron()
	return {}

func get_active_patrons() -> Array[Dictionary]:
	"""Get all active patrons (convenience method)"""
	if patron_system:
		return patron_system.get_active_patrons()
	return []

func get_patron_reputation(patron_id: String) -> int:
	"""Get patron reputation (convenience method)"""
	if patron_system:
		return patron_system.get_patron_reputation(patron_id)
	return 0

func has_active_job() -> bool:
	"""Check if there's an active job (convenience method)"""
	if patron_system:
		return patron_system.has_active_job()
	return false

# =====================================================
# FACTION SYSTEM ACCESS
# =====================================================

func get_faction_system() -> FactionSystem:
	"""Get the FactionSystem instance"""
	return faction_system

func get_faction_standing(faction_id: String) -> float:
	"""Get faction standing (convenience method)"""
	if faction_system:
		return faction_system.get_faction_standing(faction_id)
	return 0.0

func modify_faction_standing(faction_id: String, amount: float) -> void:
	"""Modify faction standing (convenience method)"""
	if faction_system:
		faction_system.modify_faction_standing(faction_id, amount)

func get_active_rivals() -> Array[Dictionary]:
	"""Get all active rivals (convenience method)"""
	if faction_system:
		return faction_system.get_active_rivals()
	return []

func generate_rival() -> Dictionary:
	"""Generate new rival (convenience method)"""
	if faction_system:
		return faction_system.generate_rival()
	return {}

# =====================================================
# SYSTEM STATUS AND UTILITIES
# =====================================================

func are_systems_ready() -> bool:
	"""Check if all systems are initialized and ready"""
	return systems_initialized

func get_system_status() -> Dictionary:
	"""Get status of all systems"""
	var status = {
		"initialized": systems_initialized,
		"errors": initialization_errors.duplicate(),
		"systems": {}
	}

	if economy_system:
		status.systems.economy = economy_system.get_status()

	if patron_system:
		status.systems.patron = patron_system.get_status()

	if faction_system:
		status.systems.faction = faction_system.get_status()

	return status

func validate_all_systems() -> Dictionary:
	"""Validate all system states"""
	var validation = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	if economy_system:
		var economy_validation = economy_system.validate_state()
		if not economy_validation.valid:
			validation.valid = false
		validation.errors.append_array(economy_validation.errors)
		validation.warnings.append_array(economy_validation.warnings)

	if patron_system:
		var patron_validation = patron_system.validate_state()
		if not patron_validation.valid:
			validation.valid = false
		validation.errors.append_array(patron_validation.errors)
		validation.warnings.append_array(patron_validation.warnings)

	if faction_system:
		var faction_validation = faction_system.validate_state()
		if not faction_validation.valid:
			validation.valid = false
		validation.errors.append_array(faction_validation.errors)
		validation.warnings.append_array(faction_validation.warnings)

	return validation

func save_all_systems() -> Dictionary:
	"""Save data from all systems"""
	var save_data: Dictionary = {}

	if economy_system:
		save_data.economy = economy_system.get_data()

	if patron_system:
		save_data.patron = patron_system.get_data()

	if faction_system:
		save_data.faction = faction_system.get_data()

	return save_data

func load_all_systems(data: Dictionary) -> bool:
	"""Load data into all systems"""
	var success: bool = true

	if data.has("economy") and economy_system:
		success = economy_system.update_data(data.economy) and success

	if data.has("patron") and patron_system:
		success = patron_system.update_data(data.patron) and success

	if data.has("faction") and faction_system:
		success = faction_system.update_data(data.faction) and success

	return success

func process_turn_update() -> void:
	"""Process turn-based updates for all systems"""
	if not systems_initialized:
		return

	# Update economy systems
	if economy_system:
		economy_system.update_market()
		economy_system.process_economic_fluctuations()

	# Update faction activities
	if faction_system:
		faction_system.process_faction_activities()

	print("SystemsAutoload: Turn update processed for all systems")

func cleanup_all_systems() -> void:
	"""Clean up all systems"""
	if economy_system:
		economy_system.cleanup()

	if patron_system:
		patron_system.cleanup()

	if faction_system:
		faction_system.cleanup()

	systems_initialized = false
	print("SystemsAutoload: All systems cleaned up")

# Helper methods for backward compatibility
func get_world_economy_manager() -> EconomySystem:
	"""Backward compatibility alias"""
	return economy_system

func get_resource_manager() -> EconomySystem:
	"""Backward compatibility alias"""
	return economy_system

func get_patron_manager() -> PatronSystem:
	"""Backward compatibility alias"""
	return patron_system

func get_faction_manager() -> FactionSystem:
	"""Backward compatibility alias"""
	return faction_system
func _exit_tree() -> void:
	"""Cleanup all systems during shutdown"""
	print("SystemsAutoload: Shutting down and cleaning up all systems...")
	cleanup_all_systems()
	print("SystemsAutoload: Shutdown complete")

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
