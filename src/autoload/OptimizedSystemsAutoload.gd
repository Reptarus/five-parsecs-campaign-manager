extends Node # Essential imports
# DataManager is accessed as autoload singleton (registered in project.godot)

## Optimized Systems Autoload - Load Time Optimization
## Reduces autoload initialization time via deferred and lazy initialization
## Target: <150ms total autoload time (down from 361ms)

# Load system classes lazily
var PatronSystem = null
var EconomySystem = null
var FactionSystem = null

# System instances - created on demand
var patron_system = null
var economy_system = null
var faction_system = null

# Initialization control
var essential_systems_ready: bool = false
var all_systems_ready: bool = false
var initialization_start_time: int = 0

signal systems_essential_ready() # Core systems ready for UI
signal systems_fully_ready() # All systems ready
signal system_error(system_name: String, error: String)

func _ready() -> void:
	name = "OptimizedSystemsAutoload"
	initialization_start_time = Time.get_ticks_msec()
	print("OptimizedSystemsAutoload: Starting fast initialization...")
	
	# Initialize only essential systems immediately
	_initialize_essential_systems()
	
	# Defer heavy system initialization
	call_deferred("_initialize_heavy_systems")

func _initialize_essential_systems() -> void:
	"""Initialize only the minimum required systems for basic UI functionality"""
	print("OptimizedSystemsAutoload: Initializing essential systems...")
	
	# Only initialize critical path systems
	essential_systems_ready = true
	systems_essential_ready.emit()
	
	var essential_time = Time.get_ticks_msec() - initialization_start_time
	print("OptimizedSystemsAutoload: Essential systems ready in %d ms" % essential_time)

func _initialize_heavy_systems() -> void:
	"""Initialize resource-intensive systems in background after UI is functional"""
	print("OptimizedSystemsAutoload: Initializing heavy systems in background...")
	
	# Wait for essential autoloads (but don't block startup)
	await _wait_for_essential_autoloads()
	
	# Initialize systems with lazy loading
	await _initialize_systems_lazy()
	
	all_systems_ready = true
	systems_fully_ready.emit()
	
	var total_time = Time.get_ticks_msec() - initialization_start_time
	print("OptimizedSystemsAutoload: All systems ready in %d ms" % total_time)

func _wait_for_essential_autoloads() -> void:
	"""Wait for only critical autoloads to prevent dependency issues"""
	# Wait just one frame for autoload registration
	await get_tree().process_frame
	
	# Check for DataManager but don't block if it's still loading
	var data_manager = DataManager
	if data_manager:
		# Check DataManager instance state
		if not data_manager._is_data_loaded:
			print("OptimizedSystemsAutoload: DataManager essential data loading...")
			# Initialize but don't wait - proceed regardless
			data_manager.initialize_data_system()
			print("OptimizedSystemsAutoload: Continued after DataManager initialization")
		else:
			print("OptimizedSystemsAutoload: DataManager already loaded")
	else:
		print("OptimizedSystemsAutoload: DataManager not found - proceeding without")

func _initialize_systems_lazy() -> void:
	"""Initialize systems with lazy loading and error resilience"""
	var systems_to_initialize = [
		{"name": "PatronSystem", "path": "res://src/core/systems/PatronSystem.gd", "priority": "high"},
		{"name": "EconomySystem", "path": "res://src/core/systems/EconomySystem.gd", "priority": "medium"},
		{"name": "FactionSystem", "path": "res://src/core/systems/FactionSystem.gd", "priority": "low"}
	]
	
	# Initialize high-priority systems first
	for system_info in systems_to_initialize:
		if system_info["priority"] == "high":
			await _initialize_system_safe(system_info)
			await get_tree().process_frame # Prevent frame drops
	
	# Initialize remaining systems
	for system_info in systems_to_initialize:
		if system_info["priority"] != "high":
			await _initialize_system_safe(system_info)
			await get_tree().process_frame

func _initialize_system_safe(system_info: Dictionary) -> bool:
	"""Safely initialize a single system with error handling"""
	var system_name = system_info["name"]
	var system_path = system_info["path"]
	
	print("OptimizedSystemsAutoload: Loading %s..." % system_name)
	var start_time = Time.get_ticks_msec()
	
	# Load system class
	var system_class = load(system_path)
	if not system_class:
		push_error("OptimizedSystemsAutoload: Failed to load %s class" % system_name)
		system_error.emit(system_name, "Class loading failed")
		return false
	
	# Create system instance
	var system_instance = system_class.new()
	if not system_instance:
		push_error("OptimizedSystemsAutoload: Failed to instantiate %s" % system_name)
		system_error.emit(system_name, "Instantiation failed")
		return false
	
	# Store references
	match system_name:
		"PatronSystem":
			PatronSystem = system_class
			patron_system = system_instance
		"EconomySystem":
			EconomySystem = system_class
			economy_system = system_instance
		"FactionSystem":
			FactionSystem = system_class
			faction_system = system_instance
	
	var load_time = Time.get_ticks_msec() - start_time
	print("OptimizedSystemsAutoload: %s initialized in %d ms" % [system_name, load_time])
	return true

## System Access API - Lazy Loading
func get_patron_system() -> Object:
	"""Get PatronSystem instance, loading if necessary"""
	if not patron_system:
		if PatronSystem:
			patron_system = PatronSystem.new()
		else:
			# Load synchronously if needed immediately
			_initialize_system_safe({"name": "PatronSystem", "path": "res://src/core/systems/PatronSystem.gd"})
	return patron_system

func get_economy_system() -> Object:
	"""Get EconomySystem instance, loading if necessary"""
	if not economy_system:
		if EconomySystem:
			economy_system = EconomySystem.new()
		else:
			_initialize_system_safe({"name": "EconomySystem", "path": "res://src/core/systems/EconomySystem.gd"})
	return economy_system

func get_faction_system() -> Object:
	"""Get FactionSystem instance, loading if necessary"""
	if not faction_system:
		if FactionSystem:
			faction_system = FactionSystem.new()
		else:
			_initialize_system_safe({"name": "FactionSystem", "path": "res://src/core/systems/FactionSystem.gd"})
	return faction_system

## Performance Monitoring
func get_initialization_stats() -> Dictionary:
	return {
		"total_time_ms": Time.get_ticks_msec() - initialization_start_time,
		"essential_systems_ready": essential_systems_ready,
		"all_systems_ready": all_systems_ready,
		"systems_loaded": _get_systems_loaded_count(),
		"total_systems": 3
	}

func _get_systems_loaded_count() -> int:
	var count = 0
	if patron_system: count += 1
	if economy_system: count += 1
	if faction_system: count += 1
	return count

## Compatibility API
func is_systems_ready() -> bool:
	return essential_systems_ready

func is_all_systems_ready() -> bool:
	return all_systems_ready