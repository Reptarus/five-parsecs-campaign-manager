@tool
class_name AutoloadManager
extends RefCounted

## Robust Autoload Access Manager with Fallback Systems
## Prevents crashes when critical autoloads are missing
## Provides graceful degradation for missing dependencies

static var _fallback_instances: Dictionary = {}
static var _autoload_cache: Dictionary = {}
static var _initialization_attempted: Dictionary = {}

## Get autoload safely with fallback creation
static func get_autoload_safe(name: String) -> Node:
	# Return cached instance if available
	if _autoload_cache.has(name) and is_instance_valid(_autoload_cache[name]):
		return _autoload_cache[name]
	
	# Try multiple access methods for autoloads
	var node = _try_autoload_access(name)
	
	if not node and not _initialization_attempted.get(name, false):
		push_warning("AutoloadManager: Autoload '%s' not available, creating fallback" % name)
		node = _create_fallback_instance(name)
		_initialization_attempted[name] = true
	
	# Cache valid node
	if node and is_instance_valid(node):
		_autoload_cache[name] = node
	
	return node

static func _try_autoload_access(name: String) -> Node:
	## Try multiple methods to access autoload
	var node: Node = null
	
	# Method 1: Engine singleton
	if Engine.has_singleton(name):
		node = Engine.get_singleton(name)
		if node:
			return node
	
	# Method 2: Scene tree root access
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var scene_tree = main_loop as SceneTree
		if scene_tree.root:
			node = scene_tree.root.get_node_or_null("/root/" + name)
			if node:
				return node
	
	# Method 3: Direct root access (fallback)
	if main_loop and main_loop is SceneTree:
		var scene_tree = main_loop as SceneTree
		if scene_tree.root:
			node = scene_tree.root.get_node_or_null(name)
	
	return node

static func _create_fallback_instance(name: String) -> Node:
	## Create fallback instances for critical autoloads
	var fallback: Node = null
	
	match name:
		"DiceManager":
			fallback = _create_dice_manager_fallback()
		"GameStateManager":
			fallback = _create_game_state_manager_fallback()
		"DataManager":
			fallback = _create_data_manager_fallback()
		"GlobalEnums":
			fallback = _create_global_enums_fallback()
		"SystemsAutoload":
			fallback = _create_systems_fallback()
		_:
			push_warning("AutoloadManager: No fallback available for %s" % name)
			return null
	
	if fallback:
		print("AutoloadManager: Created fallback instance for %s" % name)
		_fallback_instances[name] = fallback
	
	return fallback

static func _create_dice_manager_fallback() -> Node:
	## Create fallback DiceManager with essential functionality
	var dice_manager = Node.new()
	dice_manager.name = "DiceManagerFallback"
	dice_manager.set_script(preload("res://src/core/systems/FallbackDiceManager.gd"))
	return dice_manager

static func _create_game_state_manager_fallback() -> Node:
	## Create fallback GameStateManager
	if ResourceLoader.exists("res://src/core/managers/GameStateManager.gd"):
		var game_state = preload("res://src/core/managers/GameStateManager.gd").new()
		game_state.name = "GameStateManagerFallback"
		print("AutoloadManager: Created GameStateManager fallback instance")
		return game_state
	else:
		push_error("AutoloadManager: GameStateManager.gd not found, cannot create fallback")
		return null

static func _create_data_manager_fallback() -> Node:
	## Create fallback DataManager
	if ResourceLoader.exists("res://src/core/data/DataManager.gd"):
		var data_manager = preload("res://src/core/data/DataManager.gd").new()
		data_manager.name = "DataManagerFallback"
		return data_manager
	else:
		# Create minimal data manager
		var minimal_dm = Node.new()
		minimal_dm.name = "MinimalDataManager"
		return minimal_dm

static func _create_global_enums_fallback() -> Node:
	## Create fallback GlobalEnums
	if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd"):
		var enums = preload("res://src/core/systems/GlobalEnums.gd").new()
		enums.name = "GlobalEnumsFallback"
		return enums
	else:
		# Return minimal enum container
		var minimal_enums = Node.new()
		minimal_enums.name = "MinimalGlobalEnums"
		return minimal_enums

static func _create_systems_fallback() -> Node:
	## Create fallback SystemsAutoload
	var systems = Node.new()
	systems.name = "SystemsFallback"
	return systems

## Verify autoload availability without creating fallbacks
static func is_autoload_available(name: String) -> bool:
	var node = _try_autoload_access(name)
	return node != null and is_instance_valid(node)

## Get list of all available autoloads
static func get_available_autoloads() -> Array[String]:
	var available: Array[String] = []
	var common_autoloads = [
		"GameStateManager", "DiceManager", "GlobalEnums", 
		"DataManager", "SystemsAutoload"
	]
	
	for autoload_name in common_autoloads:
		if is_autoload_available(autoload_name):
			available.append(autoload_name)
	
	return available

## Force refresh of autoload cache
static func refresh_cache() -> void:
	_autoload_cache.clear()
	_initialization_attempted.clear()
	print("AutoloadManager: Cache refreshed")

## Check if using fallback instance
static func is_using_fallback(name: String) -> bool:
	return _fallback_instances.has(name)

## Get system status report
static func get_status_report() -> Dictionary:
	var report = {
		"available_autoloads": get_available_autoloads(),
		"fallback_instances": _fallback_instances.keys(),
		"cached_instances": _autoload_cache.keys(),
		"system_health": "good"
	}
	
	# Assess system health
	var critical_missing = []
	var critical_autoloads = ["GameStateManager", "DiceManager"]
	
	for critical in critical_autoloads:
		if not is_autoload_available(critical) and not is_using_fallback(critical):
			critical_missing.append(critical)
	
	if critical_missing.size() > 0:
		report.system_health = "degraded"
		report.critical_missing = critical_missing
	
	return report

## Clear all fallback instances (cleanup)
static func cleanup_fallbacks() -> void:
	for fallback in _fallback_instances.values():
		if is_instance_valid(fallback):
			fallback.queue_free()
	_fallback_instances.clear()
	print("AutoloadManager: Fallback instances cleaned up")
