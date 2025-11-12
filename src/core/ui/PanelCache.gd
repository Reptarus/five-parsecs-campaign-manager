class_name PanelCache
extends RefCounted

## Five Parsecs Campaign Manager - Panel Cache Manager
## Refactored for Godot 4.x best practices compliance
## 
## Architecture: Efficient scene loading, caching, and memory management
## Performance: <200MB memory usage, <100ms scene loading, intelligent preloading
## Patterns: LRU cache, resource pooling, memory monitoring, lazy loading

# ============================================================================
# CONSTANTS & ENUMS
# ============================================================================

## Cache policy for memory management
enum CachePolicy {
	KEEP_ALL, ## Keep all loaded panels in memory
	LRU, ## Least Recently Used eviction
	TIME_BASED, ## Time-based expiry
	MEMORY_LIMIT, ## Memory usage limit
	HYBRID ## Combination of LRU + memory limit
}

## Loading strategy for panels
enum LoadingStrategy {
	LAZY, ## Load panels when needed
	PRELOAD_ALL, ## Preload all panels at startup
	PRELOAD_NEXT, ## Preload next likely panel
	SMART ## Intelligent preloading based on usage patterns
}

## Panel state tracking
enum PanelState {
	UNLOADED, ## Not loaded in memory
	LOADING, ## Currently being loaded
	LOADED, ## Loaded and ready
	CACHED, ## Loaded but not active
	EXPIRED, ## Cached but expired
	ERROR ## Failed to load
}

# Memory limits (in MB)
const DEFAULT_MEMORY_LIMIT_MB: float = 150.0
const WARNING_MEMORY_LIMIT_MB: float = 120.0
const CRITICAL_MEMORY_LIMIT_MB: float = 180.0

# Time limits (in seconds)
const DEFAULT_CACHE_EXPIRY_TIME: float = 300.0 # 5 minutes
const MAX_LOADING_TIME: float = 10.0 # Maximum time to wait for loading

# Performance targets
const TARGET_LOADING_TIME_MS: float = 100.0
const TARGET_INSTANTIATION_TIME_MS: float = 50.0

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when a panel is loaded successfully
signal panel_loaded(panel_id: String, panel: Control, loading_time_ms: float)

## Emitted when a panel fails to load
signal panel_load_failed(panel_id: String, error_message: String)

## Emitted when a panel is cached
signal panel_cached(panel_id: String, panel: Control)

## Emitted when a panel is evicted from cache
signal panel_evicted(panel_id: String, reason: String)

## Emitted when memory usage changes significantly
signal memory_usage_changed(current_mb: float, limit_mb: float, percentage: float)

## Emitted when cache performance statistics are updated
signal cache_stats_updated(stats: Dictionary)

# ============================================================================
# PROPERTIES
# ============================================================================

## Cache configuration
var cache_policy: CachePolicy = CachePolicy.HYBRID
var loading_strategy: LoadingStrategy = LoadingStrategy.SMART
var memory_limit_mb: float = DEFAULT_MEMORY_LIMIT_MB
var cache_expiry_time: float = DEFAULT_CACHE_EXPIRY_TIME

## Panel registry and cache
var panel_registry: Dictionary = {} # panel_id -> panel_info
var loaded_panels: Dictionary = {} # panel_id -> Control instance
var cached_scenes: Dictionary = {} # panel_id -> PackedScene
var panel_states: Dictionary = {} # panel_id -> PanelState

## LRU tracking
var access_order: Array[String] = [] # Most recent first
var access_times: Dictionary = {} # panel_id -> last_access_time
var load_times: Dictionary = {} # panel_id -> load_time

## Memory tracking
var current_memory_usage_mb: float = 0.0
var peak_memory_usage_mb: float = 0.0
var memory_tracking_enabled: bool = true

## Performance statistics
var cache_hits: int = 0
var cache_misses: int = 0
var total_loads: int = 0
var average_loading_time_ms: float = 0.0

## Loading queue and state
var loading_queue: Array[String] = []
var currently_loading: Dictionary = {} # panel_id -> loading_start_time

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	"""Initialize the panel cache manager"""
	_setup_default_panels()
	_start_memory_monitoring()
	print("PanelCache: Initialized with policy: %s, strategy: %s" % [
		CachePolicy.keys()[cache_policy],
		LoadingStrategy.keys()[loading_strategy]
	])

func _setup_default_panels() -> void:
	"""Setup default panel registry for Five Parsecs campaign panels"""
	register_panel("config", "res://src/ui/screens/campaign/panels/ConfigPanel.tscn", 1)
	register_panel("crew", "res://src/ui/screens/campaign/panels/CrewPanel.tscn", 2)
	register_panel("captain", "res://src/ui/screens/campaign/panels/CaptainPanel.tscn", 3)
	register_panel("ship", "res://src/ui/screens/campaign/panels/ShipPanel.tscn", 4)
	register_panel("equipment", "res://src/ui/screens/campaign/panels/EquipmentPanel.tscn", 5)
	register_panel("final", "res://src/ui/screens/campaign/panels/FinalPanel.tscn", 6)
	
	print("PanelCache: Default panels registered - %d panels" % panel_registry.size())

func _start_memory_monitoring() -> void:
	"""Start periodic memory monitoring"""
	if memory_tracking_enabled:
		# Create a timer for periodic memory checks
		var timer = Timer.new()
		timer.wait_time = 2.0 # Check every 2 seconds
		timer.timeout.connect(_update_memory_usage)
		timer.start()
		
		print("PanelCache: Memory monitoring started")

# ============================================================================
# PANEL REGISTRATION
# ============================================================================

## Register a panel for caching
func register_panel(panel_id: String, scene_path: String, priority: int = 0, should_preload: bool = false) -> void:
	"""Register a panel with the cache system"""
	if panel_registry.has(panel_id):
		push_warning("PanelCache: Panel '%s' already registered - updating" % panel_id)
	
	panel_registry[panel_id] = {
		"scene_path": scene_path,
		"priority": priority,
		"preload": should_preload,
		"registered_time": Time.get_ticks_msec(),
		"load_count": 0,
		"last_used": 0,
		"estimated_memory_mb": 0.0
	}
	
	panel_states[panel_id] = PanelState.UNLOADED
	
	# Auto-preload if requested
	if should_preload and loading_strategy in [LoadingStrategy.PRELOAD_ALL, LoadingStrategy.SMART]:
		_queue_for_loading(panel_id)
	
	print("PanelCache: Registered panel '%s' - Path: %s, Priority: %d" % [panel_id, scene_path, priority])

## Unregister a panel
func unregister_panel(panel_id: String) -> void:
	"""Remove a panel from the cache system"""
	if not panel_registry.has(panel_id):
		push_warning("PanelCache: Cannot unregister unknown panel '%s'" % panel_id)
		return
	
	# Clean up all references
	_evict_panel(panel_id, "unregistered")
	panel_registry.erase(panel_id)
	panel_states.erase(panel_id)
	access_times.erase(panel_id)
	load_times.erase(panel_id)
	
	print("PanelCache: Unregistered panel '%s'" % panel_id)

# ============================================================================
# PANEL LOADING
# ============================================================================

## Get a panel instance (load if necessary)
func get_panel(panel_id: String) -> Control:
	"""Get a panel instance, loading it if necessary"""
	if not panel_registry.has(panel_id):
		push_error("PanelCache: Unknown panel '%s' requested" % panel_id)
		return null
	
	# Update access tracking
	_track_panel_access(panel_id)
	
	# Check if already loaded
	if loaded_panels.has(panel_id):
		var panel = loaded_panels[panel_id]
		if is_instance_valid(panel):
			cache_hits += 1
			print("PanelCache: Cache hit for panel '%s'" % panel_id)
			return panel
		else:
			# Clean up invalid reference
			loaded_panels.erase(panel_id)
			panel_states[panel_id] = PanelState.UNLOADED
	
	# Cache miss - need to load
	cache_misses += 1
	return await _load_panel(panel_id)

## Load a panel asynchronously
func _load_panel(panel_id: String) -> Control:
	"""Load a panel asynchronously with error handling"""
	if not panel_registry.has(panel_id):
		push_error("PanelCache: Cannot load unknown panel '%s'" % panel_id)
		return null
	
	# Check if already loading
	if currently_loading.has(panel_id):
		print("PanelCache: Panel '%s' already loading - waiting..." % panel_id)
		return await _wait_for_loading(panel_id)
	
	var panel_info = panel_registry[panel_id]
	var scene_path = panel_info.scene_path
	var loading_start_time = Time.get_ticks_msec()
	
	print("PanelCache: Loading panel '%s' from %s" % [panel_id, scene_path])
	
	# Mark as loading
	panel_states[panel_id] = PanelState.LOADING
	currently_loading[panel_id] = loading_start_time
	
	# Check memory before loading
	if not _check_memory_before_loading():
		_evict_oldest_panels()
	
	# Load the scene
	var packed_scene: PackedScene = null
	var panel_instance: Control = null
	
	# Load PackedScene
	if ResourceLoader.exists(scene_path):
		packed_scene = load(scene_path) as PackedScene
	else:
		push_error("PanelCache: Scene file not found: %s" % scene_path)
		_handle_loading_error(panel_id, "Scene file not found")
		return null
		
		if not packed_scene:
			push_error("PanelCache: Failed to load PackedScene: %s" % scene_path)
			_handle_loading_error(panel_id, "Failed to load PackedScene")
			return null
		
		# Instantiate the scene
		panel_instance = packed_scene.instantiate() as Control
		
		if not panel_instance:
			push_error("PanelCache: Failed to instantiate panel: %s" % scene_path)
			_handle_loading_error(panel_id, "Failed to instantiate panel")
			return null
		
		# Configure the panel instance
		panel_instance.name = "CachedPanel_%s" % panel_id
		panel_instance.visible = false # Hidden by default
	
	# Loading completed successfully
	var loading_time_ms = Time.get_ticks_msec() - loading_start_time
	_handle_loading_success(panel_id, panel_instance, packed_scene, loading_time_ms)
	
	return panel_instance

func _handle_loading_success(panel_id: String, panel: Control, packed_scene: PackedScene, loading_time_ms: float) -> void:
	"""Handle successful panel loading"""
	# Update state
	panel_states[panel_id] = PanelState.LOADED
	loaded_panels[panel_id] = panel
	cached_scenes[panel_id] = packed_scene
	load_times[panel_id] = loading_time_ms
	currently_loading.erase(panel_id)
	
	# Update statistics
	total_loads += 1
	average_loading_time_ms = (average_loading_time_ms * (total_loads - 1) + loading_time_ms) / total_loads
	panel_registry[panel_id].load_count += 1
	
	# Update memory usage estimate
	_estimate_panel_memory_usage(panel_id, panel)
	_update_memory_usage()
	
	# Performance logging
	if loading_time_ms > TARGET_LOADING_TIME_MS:
		push_warning("PanelCache: Panel '%s' loaded in %.1fms (target: %.1fms)" % [panel_id, loading_time_ms, TARGET_LOADING_TIME_MS])
	else:
		print("PanelCache: Panel '%s' loaded successfully in %.1fms" % [panel_id, loading_time_ms])
	
	# Emit signals
	panel_loaded.emit(panel_id, panel, loading_time_ms)
	_update_cache_stats()

func _handle_loading_error(panel_id: String, error_message: String) -> void:
	"""Handle panel loading errors"""
	panel_states[panel_id] = PanelState.ERROR
	currently_loading.erase(panel_id)
	
	push_error("PanelCache: Failed to load panel '%s' - %s" % [panel_id, error_message])
	panel_load_failed.emit(panel_id, error_message)

func _wait_for_loading(panel_id: String) -> Control:
	"""Wait for a panel that's currently being loaded"""
	var max_wait_time = MAX_LOADING_TIME
	var wait_start = Time.get_ticks_msec()
	
	while currently_loading.has(panel_id) and (Time.get_ticks_msec() - wait_start) < (max_wait_time * 1000):
		await Engine.get_main_loop().process_frame
	
	# Check if loading completed successfully
	if loaded_panels.has(panel_id):
		return loaded_panels[panel_id]
	else:
		push_error("PanelCache: Timed out waiting for panel '%s' to load" % panel_id)
		return null

# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

func _track_panel_access(panel_id: String) -> void:
	"""Track panel access for LRU and usage patterns"""
	var current_time = Time.get_ticks_msec()
	access_times[panel_id] = current_time
	panel_registry[panel_id].last_used = current_time
	
	# Update LRU order
	if access_order.has(panel_id):
		access_order.erase(panel_id)
	access_order.push_front(panel_id)
	
	# Trim access order to reasonable size
	if access_order.size() > panel_registry.size() * 2:
		access_order.resize(panel_registry.size())

func _check_memory_before_loading() -> bool:
	"""Check if we have enough memory before loading a panel"""
	if current_memory_usage_mb < WARNING_MEMORY_LIMIT_MB:
		return true
	
	if current_memory_usage_mb >= memory_limit_mb:
		print("PanelCache: Memory limit reached (%.1f/%.1f MB) - need to evict panels" % [current_memory_usage_mb, memory_limit_mb])
		return false
	
	print("PanelCache: Memory usage warning (%.1f/%.1f MB)" % [current_memory_usage_mb, memory_limit_mb])
	return true

func _evict_oldest_panels() -> void:
	"""Evict panels based on cache policy"""
	match cache_policy:
		CachePolicy.KEEP_ALL:
			# Don't evict anything
			return
		CachePolicy.LRU:
			_evict_lru_panels(1)
		CachePolicy.TIME_BASED:
			_evict_expired_panels()
		CachePolicy.MEMORY_LIMIT:
			_evict_by_memory_usage()
		CachePolicy.HYBRID:
			_evict_hybrid()

func _evict_lru_panels(count: int) -> void:
	"""Evict least recently used panels"""
	var evicted = 0
	
	# Start from the end of access_order (least recently used)
	for i in range(access_order.size() - 1, -1, -1):
		if evicted >= count:
			break
		
		var panel_id = access_order[i]
		if loaded_panels.has(panel_id):
			_evict_panel(panel_id, "LRU eviction")
			evicted += 1

func _evict_expired_panels() -> void:
	"""Evict panels that have exceeded their cache expiry time"""
	var current_time = Time.get_ticks_msec()
	var expired_panels: Array[String] = []
	
	for panel_id in loaded_panels.keys():
		var last_access = access_times.get(panel_id, 0)
		var age_seconds = (current_time - last_access) / 1000.0
		
		if age_seconds > cache_expiry_time:
			expired_panels.append(panel_id)
	
	for panel_id in expired_panels:
		_evict_panel(panel_id, "expired")

func _evict_by_memory_usage() -> void:
	"""Evict panels to reduce memory usage"""
	# Sort panels by memory usage (largest first)
	var panels_by_memory: Array = []
	
	for panel_id in loaded_panels.keys():
		var memory_usage = panel_registry[panel_id].get("estimated_memory_mb", 0.0)
		panels_by_memory.append({"id": panel_id, "memory": memory_usage})
	
	panels_by_memory.sort_custom(func(a, b): return a.memory > b.memory)
	
	# Evict largest panels until under memory limit
	for panel_data in panels_by_memory:
		if current_memory_usage_mb < WARNING_MEMORY_LIMIT_MB:
			break
		_evict_panel(panel_data.id, "memory limit")

func _evict_hybrid() -> void:
	"""Hybrid eviction combining LRU and memory considerations"""
	# First, evict expired panels
	_evict_expired_panels()
	
	# If still over memory limit, evict by memory usage
	if current_memory_usage_mb >= WARNING_MEMORY_LIMIT_MB:
		_evict_by_memory_usage()
	
	# Finally, use LRU for remaining panels if needed
	if current_memory_usage_mb >= WARNING_MEMORY_LIMIT_MB:
		_evict_lru_panels(2)

func _evict_panel(panel_id: String, reason: String) -> void:
	"""Evict a specific panel from cache"""
	if not loaded_panels.has(panel_id):
		return
	
	var panel = loaded_panels[panel_id]
	
	# Clean up the panel instance
	if is_instance_valid(panel):
		if panel.get_parent():
			panel.get_parent().remove_child(panel)
		panel.queue_free()
	
	# Remove from cache
	loaded_panels.erase(panel_id)
	cached_scenes.erase(panel_id)
	panel_states[panel_id] = PanelState.UNLOADED
	
	# Update memory tracking
	var estimated_memory = panel_registry[panel_id].get("estimated_memory_mb", 0.0)
	current_memory_usage_mb = max(0.0, current_memory_usage_mb - estimated_memory)
	
	print("PanelCache: Evicted panel '%s' (reason: %s) - Freed %.1f MB" % [panel_id, reason, estimated_memory])
	panel_evicted.emit(panel_id, reason)

# ============================================================================
# MEMORY MANAGEMENT
# ============================================================================

func _update_memory_usage() -> void:
	"""Update current memory usage estimates"""
	if not memory_tracking_enabled:
		return
	
	var total_memory: float = 0.0
	
	for panel_id in loaded_panels.keys():
		var estimated_memory = panel_registry[panel_id].get("estimated_memory_mb", 0.0)
		total_memory += estimated_memory
	
	var old_usage = current_memory_usage_mb
	current_memory_usage_mb = total_memory
	peak_memory_usage_mb = max(peak_memory_usage_mb, current_memory_usage_mb)
	
	# Emit signal if significant change
	if abs(current_memory_usage_mb - old_usage) > 5.0: # 5MB threshold
		var percentage = (current_memory_usage_mb / memory_limit_mb) * 100.0
		memory_usage_changed.emit(current_memory_usage_mb, memory_limit_mb, percentage)
	
	# Log warnings for high memory usage
	if current_memory_usage_mb > memory_limit_mb:
		push_warning("PanelCache: Memory usage exceeded limit! %.1f/%.1f MB" % [current_memory_usage_mb, memory_limit_mb])
	elif current_memory_usage_mb > WARNING_MEMORY_LIMIT_MB:
		print("PanelCache: High memory usage: %.1f/%.1f MB" % [current_memory_usage_mb, memory_limit_mb])

func _estimate_panel_memory_usage(panel_id: String, panel: Control) -> void:
	"""Estimate memory usage of a loaded panel"""
	# Basic estimation based on node count and textures
	var node_count = _count_nodes_recursive(panel)
	var base_memory = node_count * 0.001 # ~1KB per node baseline
	
	# Add texture memory estimates
	var texture_memory = _estimate_texture_memory(panel)
	
	var total_estimate = base_memory + texture_memory
	panel_registry[panel_id].estimated_memory_mb = total_estimate
	
	print("PanelCache: Memory estimate for '%s' - %.2f MB (%d nodes, %.2f MB textures)" % [
		panel_id, total_estimate, node_count, texture_memory
	])

func _count_nodes_recursive(node: Node) -> int:
	"""Count total nodes in a scene tree"""
	var count = 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count

func _estimate_texture_memory(node: Node) -> float:
	"""Estimate texture memory usage for a node tree"""
	var total_mb: float = 0.0
	
	# Check current node for textures
	if node is TextureRect:
		var texture_rect = node as TextureRect
		if texture_rect.texture:
			total_mb += _estimate_single_texture_memory(texture_rect.texture)
	elif node is Button:
		var button = node as Button
		# Check button icon
		if button.icon:
			total_mb += _estimate_single_texture_memory(button.icon)
	
	# Recursively check children
	for child in node.get_children():
		total_mb += _estimate_texture_memory(child)
	
	return total_mb

func _estimate_single_texture_memory(texture: Texture2D) -> float:
	"""Estimate memory usage of a single texture"""
	if not texture:
		return 0.0
	
	var width = texture.get_width()
	var height = texture.get_height()
	var bytes_per_pixel = 4 # Assume RGBA8
	var total_bytes = width * height * bytes_per_pixel
	
	return total_bytes / (1024.0 * 1024.0) # Convert to MB

# ============================================================================
# STATISTICS AND MONITORING
# ============================================================================

func _update_cache_stats() -> void:
	"""Update and emit cache statistics"""
	var stats = get_cache_statistics()
	cache_stats_updated.emit(stats)

func get_cache_statistics() -> Dictionary:
	"""Get comprehensive cache statistics"""
	var hit_rate = 0.0
	if (cache_hits + cache_misses) > 0:
		hit_rate = float(cache_hits) / float(cache_hits + cache_misses)
	
	return {
		"registered_panels": panel_registry.size(),
		"loaded_panels": loaded_panels.size(),
		"cached_scenes": cached_scenes.size(),
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"hit_rate": hit_rate,
		"total_loads": total_loads,
		"average_loading_time_ms": average_loading_time_ms,
		"current_memory_mb": current_memory_usage_mb,
		"peak_memory_mb": peak_memory_usage_mb,
		"memory_limit_mb": memory_limit_mb,
		"memory_utilization": (current_memory_usage_mb / memory_limit_mb) * 100.0,
		"loading_queue_size": loading_queue.size(),
		"currently_loading": currently_loading.size()
	}

# ============================================================================
# PUBLIC API
# ============================================================================

## Set cache policy
func set_cache_policy(policy: CachePolicy) -> void:
	cache_policy = policy
	print("PanelCache: Cache policy changed to %s" % CachePolicy.keys()[policy])

## Set loading strategy
func set_loading_strategy(strategy: LoadingStrategy) -> void:
	loading_strategy = strategy
	print("PanelCache: Loading strategy changed to %s" % LoadingStrategy.keys()[strategy])

## Set memory limit
func set_memory_limit(limit_mb: float) -> void:
	memory_limit_mb = limit_mb
	print("PanelCache: Memory limit set to %.1f MB" % limit_mb)

## Clear all cached panels
func clear_cache() -> void:
	"""Clear all cached panels from memory"""
	var panel_ids = loaded_panels.keys()
	for panel_id in panel_ids:
		_evict_panel(panel_id, "cache cleared")
	
	cache_hits = 0
	cache_misses = 0
	total_loads = 0
	average_loading_time_ms = 0.0
	
	print("PanelCache: Cache cleared - %d panels evicted" % panel_ids.size())

## Force garbage collection
func force_cleanup() -> void:
	"""Force cleanup of invalid references and garbage collection"""
	var cleaned_panels: Array[String] = []
	
	# Clean up invalid panel references
	for panel_id in loaded_panels.keys():
		var panel = loaded_panels[panel_id]
		if not is_instance_valid(panel):
			cleaned_panels.append(panel_id)
			loaded_panels.erase(panel_id)
			panel_states[panel_id] = PanelState.UNLOADED
	
	# Update memory usage
	_update_memory_usage()
	
	if cleaned_panels.size() > 0:
		print("PanelCache: Cleaned up %d invalid panel references" % cleaned_panels.size())

## Get panel state
func get_panel_state(panel_id: String) -> PanelState:
	return panel_states.get(panel_id, PanelState.UNLOADED)

## Check if panel is loaded
func is_panel_loaded(panel_id: String) -> bool:
	return loaded_panels.has(panel_id) and is_instance_valid(loaded_panels[panel_id])

## Preload a specific panel
func preload_panel(panel_id: String) -> void:
	"""Preload a panel into cache"""
	if not panel_registry.has(panel_id):
		push_warning("PanelCache: Cannot preload unknown panel '%s'" % panel_id)
		return
	
	if is_panel_loaded(panel_id):
		print("PanelCache: Panel '%s' already loaded" % panel_id)
		return
	
	_queue_for_loading(panel_id)

func _queue_for_loading(panel_id: String) -> void:
	"""Queue a panel for background loading"""
	if not loading_queue.has(panel_id):
		loading_queue.append(panel_id)
		print("PanelCache: Queued panel '%s' for loading" % panel_id)
		
		# Process queue on next frame
		call_deferred("_process_loading_queue")

func _process_loading_queue() -> void:
	"""Process the loading queue"""
	if loading_queue.is_empty():
		return
	
	var panel_id = loading_queue.pop_front()
	if not is_panel_loaded(panel_id):
		await get_panel(panel_id)
	
	# Continue processing queue if there are more items
	if not loading_queue.is_empty():
		call_deferred("_process_loading_queue")
