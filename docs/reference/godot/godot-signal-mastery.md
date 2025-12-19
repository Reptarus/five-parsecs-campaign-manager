# Godot Signal Communication - Production Mastery Guide

*Enterprise-grade signal patterns for 10+ years Godot expertise*

## 🎯 **SIGNAL ARCHITECTURE FUNDAMENTALS**

### **Core Signal Philosophy**
```gdscript
# PRINCIPLE: Signals are for RESPONDING to events, not STARTING behavior
# Signal names should be past-tense verbs: "entered", "collected", "activated"
# Use signals for loose coupling, method calls for tight coupling
```

**The Production Rule**: *"Signals flow UP the hierarchy (child → parent), method calls flow DOWN (parent → child). This maintains clean separation of concerns."*

### **Signal Naming Conventions (Industry Standard)**

**Event Signals (Past-Tense)**
```gdscript
# CORRECT: Describes what happened
signal health_depleted(final_amount: int)
signal item_collected(item: Item, collector: Character)
signal animation_completed(animation_name: String)
signal user_input_received(action: String, strength: float)

# INCORRECT: Imperative commands
signal deplete_health(amount: int)  # This is a method, not a signal
signal collect_item(item: Item)     # Commands should be function calls
```

**State Change Signals**
```gdscript
# CORRECT: State transition notifications
signal state_changed(from_state: GameState, to_state: GameState)
signal visibility_toggled(is_visible: bool)
signal connection_status_updated(status: NetworkStatus)

# Data Update Signals
signal data_updated(changed_fields: Array[String])
signal inventory_modified(action: String, item: Item, quantity: int)
signal settings_applied(category: String, changes: Dictionary)
```

## 🏗️ **PRODUCTION SIGNAL PATTERNS**

### **1. Group-Based Communication (Scalable)**

**Event Broadcasting System**
```gdscript
# PRODUCTION PATTERN: Decoupled event system
class_name EventBus
extends Node

# Global event signals
signal game_state_changed(new_state: GameState)
signal player_stats_updated(player: Player, stat_type: String, new_value: float)
signal item_interaction(item: Item, action: String, actor: Node)
signal ui_notification_requested(message: String, type: NotificationType)
signal audio_event_triggered(event_name: String, position: Vector3)

# Singleton instance
static var instance: EventBus

func _ready() -> void:
    instance = self
    add_to_group("event_bus")

# Static convenience methods
static func emit_game_state_change(new_state: GameState) -> void:
    if instance:
        instance.game_state_changed.emit(new_state)

static func emit_player_stat_update(player: Player, stat_type: String, value: float) -> void:
    if instance:
        instance.player_stats_updated.emit(player, stat_type, value)
```

**Group Registration Pattern**
```gdscript
# PRODUCTION PATTERN: Auto-registration with groups
class_name GameComponent
extends Node

@export var component_groups: Array[String] = []
@export var auto_connect_events: Array[String] = []

func _ready() -> void:
    # Register with specified groups
    for group in component_groups:
        add_to_group(group)
    
    # Auto-connect to EventBus
    var event_bus = get_tree().get_first_node_in_group("event_bus")
    if event_bus:
        _connect_event_bus_signals(event_bus)

func _connect_event_bus_signals(event_bus: Node) -> void:
    for event_name in auto_connect_events:
        if event_bus.has_signal(event_name) and has_method("_on_" + event_name):
            var method_name = "_on_" + event_name
            event_bus.connect(event_name, Callable(self, method_name))
```

### **2. Hierarchical Signal Propagation**

**Bottom-Up Signal Flow**
```gdscript
# PRODUCTION PATTERN: Child-to-parent communication
class_name InventoryItem
extends Control

signal item_selected(item: Item)
signal item_action_requested(item: Item, action: String)
signal item_context_menu_opened(item: Item, position: Vector2)

@export var item_data: Item

func _on_item_clicked() -> void:
    item_selected.emit(item_data)

func _on_item_right_clicked() -> void:
    var global_pos = global_position + size * 0.5
    item_context_menu_opened.emit(item_data, global_pos)

# Parent inventory container
class_name InventoryContainer
extends Control

@onready var item_grid: GridContainer = %ItemGrid

func _ready() -> void:
    _connect_existing_items()

func add_item_ui(item: Item) -> void:
    var item_ui = preload("res://ui/InventoryItem.tscn").instantiate()
    item_ui.item_data = item
    item_grid.add_child(item_ui)
    
    # Connect child signals
    item_ui.item_selected.connect(_on_item_selected)
    item_ui.item_action_requested.connect(_on_item_action_requested)
    item_ui.item_context_menu_opened.connect(_on_item_context_menu_opened)

func _on_item_selected(item: Item) -> void:
    # Handle locally and propagate up if needed
    _update_item_details(item)
    item_selected.emit(item)  # Propagate to parent

func _on_item_action_requested(item: Item, action: String) -> void:
    # Process action locally
    match action:
        "use":
            _use_item(item)
        "drop":
            _drop_item(item)
        _:
            # Unknown action, propagate up
            item_action_requested.emit(item, action)
```

### **3. Signal Connection Management**

**Managed Signal Connections**
```gdscript
# PRODUCTION PATTERN: Automatic signal cleanup
class_name ManagedSignalNode
extends Node

var signal_connections: Array[Dictionary] = []

func connect_managed_signal(
    source: Object, 
    signal_name: String, 
    handler: Callable,
    flags: int = 0
) -> void:
    # Connect the signal
    source.connect(signal_name, handler, flags)
    
    # Track connection for cleanup
    signal_connections.append({
        "source": source,
        "signal": signal_name,
        "handler": handler
    })

func disconnect_managed_signal(source: Object, signal_name: String, handler: Callable) -> void:
    source.disconnect(signal_name, handler)
    
    # Remove from tracking
    signal_connections = signal_connections.filter(
        func(conn): return not (conn.source == source and conn.signal == signal_name and conn.handler == handler)
    )

func _exit_tree() -> void:
    # Clean up all managed connections
    for connection in signal_connections:
        if is_instance_valid(connection.source):
            if connection.source.is_connected(connection.signal, connection.handler):
                connection.source.disconnect(connection.signal, connection.handler)
    signal_connections.clear()
```

### **4. Conditional Signal Emission**

**State-Aware Signal System**
```gdscript
# PRODUCTION PATTERN: Smart signal emission
class_name StatefulComponent
extends Node

enum ComponentState {
    INACTIVE,
    INITIALIZING,
    ACTIVE,
    PAUSED,
    DESTROYED
}

var current_state: ComponentState = ComponentState.INACTIVE
var signal_enabled: bool = true
var signal_queue: Array[Dictionary] = []

signal state_changed(from_state: ComponentState, to_state: ComponentState)
signal data_updated(data_type: String, new_value: Variant)

func emit_managed_signal(signal_name: String, args: Array = []) -> void:
    # Check if signals should be emitted
    if not signal_enabled or current_state == ComponentState.DESTROYED:
        return
    
    # Queue signals if not active
    if current_state != ComponentState.ACTIVE:
        signal_queue.append({"signal": signal_name, "args": args})
        return
    
    # Emit immediately if active
    match signal_name:
        "data_updated":
            if args.size() >= 2:
                data_updated.emit(args[0], args[1])
        _:
            # Generic emission using call
            call("emit_signal", signal_name, args)

func set_state(new_state: ComponentState) -> void:
    var old_state = current_state
    current_state = new_state
    
    state_changed.emit(old_state, new_state)
    
    # Process queued signals when becoming active
    if new_state == ComponentState.ACTIVE and signal_queue.size() > 0:
        _process_signal_queue()

func _process_signal_queue() -> void:
    for queued_signal in signal_queue:
        emit_managed_signal(queued_signal.signal, queued_signal.args)
    signal_queue.clear()
```

## 🔄 **ASYNC SIGNAL PATTERNS**

### **Signal-Based Async Operations**
```gdscript
# PRODUCTION PATTERN: Promise-like signal usage
class_name AsyncOperationManager
extends Node

signal operation_started(operation_id: String)
signal operation_progress(operation_id: String, progress: float)
signal operation_completed(operation_id: String, result: Variant)
signal operation_failed(operation_id: String, error: String)

var active_operations: Dictionary = {}

func start_async_operation(operation_type: String, params: Dictionary = {}) -> String:
    var operation_id = _generate_operation_id()
    
    active_operations[operation_id] = {
        "type": operation_type,
        "start_time": Time.get_unix_time_from_system(),
        "params": params
    }
    
    operation_started.emit(operation_id)
    
    # Start operation based on type
    match operation_type:
        "save_game":
            _save_game_async(operation_id, params)
        "load_assets":
            _load_assets_async(operation_id, params)
        "network_request":
            _network_request_async(operation_id, params)
    
    return operation_id

func _save_game_async(operation_id: String, params: Dictionary) -> void:
    # Simulate async save operation
    var save_data = params.get("save_data", {})
    var save_path = params.get("path", "user://save.dat")
    
    # Progress updates
    operation_progress.emit(operation_id, 0.1)
    await get_tree().create_timer(0.1).timeout
    
    operation_progress.emit(operation_id, 0.5)
    await get_tree().create_timer(0.1).timeout
    
    # Actual save operation
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))
        file.close()
        
        operation_progress.emit(operation_id, 1.0)
        operation_completed.emit(operation_id, {"saved_path": save_path})
        active_operations.erase(operation_id)
    else:
        operation_failed.emit(operation_id, "Failed to open file for writing")
        active_operations.erase(operation_id)

# Usage example
func save_game_with_callback(save_data: Dictionary) -> void:
    var operation_id = start_async_operation("save_game", {"save_data": save_data})
    
    # Connect to completion signals
    var completion_handler = func(op_id: String, result: Variant):
        if op_id == operation_id:
            print("Save completed: ", result)
            operation_completed.disconnect(completion_handler)
    
    var error_handler = func(op_id: String, error: String):
        if op_id == operation_id:
            print("Save failed: ", error)
            operation_failed.disconnect(error_handler)
    
    operation_completed.connect(completion_handler)
    operation_failed.connect(error_handler)
```

## 🎭 **SIGNAL PERFORMANCE OPTIMIZATION**

### **Signal Pooling and Batching**
```gdscript
# PRODUCTION PATTERN: High-frequency signal optimization
class_name PerformanceSignalManager
extends Node

# Signal batching for high-frequency events
var batched_signals: Dictionary = {}
var batch_timer: Timer

signal batch_processed(signal_name: String, batch_data: Array)

func _ready() -> void:
    batch_timer = Timer.new()
    batch_timer.wait_time = 0.016  # ~60 FPS
    batch_timer.timeout.connect(_process_batched_signals)
    add_child(batch_timer)
    batch_timer.start()

func emit_batched_signal(signal_name: String, data: Variant) -> void:
    if not signal_name in batched_signals:
        batched_signals[signal_name] = []
    
    batched_signals[signal_name].append({
        "data": data,
        "timestamp": Time.get_unix_time_from_system()
    })

func _process_batched_signals() -> void:
    for signal_name in batched_signals.keys():
        var batch_data = batched_signals[signal_name]
        if batch_data.size() > 0:
            batch_processed.emit(signal_name, batch_data)
            batched_signals[signal_name].clear()

# Usage for high-frequency events like movement
class_name PlayerController
extends CharacterBody3D

@onready var signal_manager: PerformanceSignalManager = get_node("/root/SignalManager")

func _physics_process(delta: float) -> void:
    # Instead of emitting position_updated every frame
    if velocity.length() > 0.1:
        signal_manager.emit_batched_signal("player_movement", {
            "position": global_position,
            "velocity": velocity,
            "delta": delta
        })
```

### **Signal Priority System**
```gdscript
# PRODUCTION PATTERN: Priority-based signal processing
class_name PrioritySignalProcessor
extends Node

enum SignalPriority {
    CRITICAL = 0,   # Process immediately
    HIGH = 1,       # Process within 1 frame
    NORMAL = 2,     # Process within 3 frames
    LOW = 3         # Process when system is idle
}

var signal_queues: Array[Array] = [[], [], [], []]  # One queue per priority
var processing_enabled: bool = true

func queue_priority_signal(
    priority: SignalPriority,
    target: Object,
    signal_name: String,
    args: Array = []
) -> void:
    if priority == SignalPriority.CRITICAL:
        # Process immediately
        target.emit_signal(signal_name, args)
        return
    
    signal_queues[priority].append({
        "target": target,
        "signal": signal_name,
        "args": args,
        "queued_time": Time.get_unix_time_from_system()
    })

func _process(delta: float) -> void:
    if not processing_enabled:
        return
    
    var frame_budget = 0.016  # 16ms per frame budget
    var start_time = Time.get_unix_time_from_system()
    
    # Process high priority first
    for priority in range(SignalPriority.HIGH, SignalPriority.LOW + 1):
        while signal_queues[priority].size() > 0:
            var signal_data = signal_queues[priority].pop_front()
            
            if is_instance_valid(signal_data.target):
                signal_data.target.emit_signal(signal_data.signal, signal_data.args)
            
            # Check frame budget
            var elapsed = Time.get_unix_time_from_system() - start_time
            if elapsed > frame_budget:
                return  # Continue next frame
```

## 🔐 **SIGNAL VALIDATION AND DEBUGGING**

### **Signal Contract Validation**
```gdscript
# PRODUCTION PATTERN: Runtime signal validation
class_name SignalValidator
extends Node

var expected_signals: Dictionary = {}
var signal_listeners: Dictionary = {}

func register_signal_contract(
    node: Node,
    signal_name: String,
    expected_args: Array[Dictionary]
) -> void:
    var node_id = node.get_instance_id()
    if not node_id in expected_signals:
        expected_signals[node_id] = {}
    
    expected_signals[node_id][signal_name] = expected_args

func validate_signal_emission(
    source: Node,
    signal_name: String,
    args: Array
) -> ValidationResult:
    var result = ValidationResult.new()
    var node_id = source.get_instance_id()
    
    if not node_id in expected_signals:
        result.valid = false
        result.error = "Node not registered for signal validation"
        return result
    
    if not signal_name in expected_signals[node_id]:
        result.valid = false
        result.error = "Signal '%s' not in contract for node" % signal_name
        return result
    
    var expected_args = expected_signals[node_id][signal_name]
    if args.size() != expected_args.size():
        result.valid = false
        result.error = "Argument count mismatch. Expected %d, got %d" % [expected_args.size(), args.size()]
        return result
    
    # Validate argument types
    for i in range(args.size()):
        var expected_type = expected_args[i].get("type", TYPE_NIL)
        var actual_type = typeof(args[i])
        
        if expected_type != TYPE_NIL and actual_type != expected_type:
            result.valid = false
            result.error = "Argument %d type mismatch. Expected %s, got %s" % [
                i, type_string(expected_type), type_string(actual_type)
            ]
            return result
    
    result.valid = true
    return result

class ValidationResult:
    var valid: bool = false
    var error: String = ""
```

### **Signal Flow Debugging**
```gdscript
# PRODUCTION PATTERN: Signal flow visualization
class_name SignalDebugger
extends Node

@export var debug_enabled: bool = false
@export var max_log_entries: int = 1000

var signal_log: Array[Dictionary] = []
var connection_map: Dictionary = {}

func _ready() -> void:
    if debug_enabled:
        _setup_signal_monitoring()

func _setup_signal_monitoring() -> void:
    # Monitor all node additions to track signal connections
    get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
    if not debug_enabled:
        return
    
    # Get all signals for this node
    var signals = node.get_signal_list()
    for signal_info in signals:
        var signal_name = signal_info.name
        
        # Wrap original emission to log
        var original_emit = node.emit_signal.bind(signal_name)
        node.set("emit_signal_debug_wrapper", _create_emit_wrapper(node, signal_name, original_emit))

func _create_emit_wrapper(node: Node, signal_name: String, original_emit: Callable) -> Callable:
    return func(args: Array = []):
        _log_signal_emission(node, signal_name, args)
        original_emit.callv(args)

func _log_signal_emission(source: Node, signal_name: String, args: Array) -> void:
    var log_entry = {
        "timestamp": Time.get_unix_time_from_system(),
        "source_node": source.name,
        "source_path": source.get_path(),
        "signal_name": signal_name,
        "args": args,
        "connected_count": source.get_signal_connection_list(signal_name).size()
    }
    
    signal_log.append(log_entry)
    
    # Maintain log size
    if signal_log.size() > max_log_entries:
        signal_log.pop_front()
    
    # Optional: Print to console
    print("SIGNAL: %s.%s -> %s" % [source.name, signal_name, str(args)])

func get_signal_flow_report() -> Dictionary:
    var report = {
        "total_emissions": signal_log.size(),
        "unique_signals": {},
        "most_active_nodes": {},
        "recent_activity": signal_log.slice(-10)  # Last 10 entries
    }
    
    for entry in signal_log:
        var signal_key = entry.source_node + "." + entry.signal_name
        if signal_key in report.unique_signals:
            report.unique_signals[signal_key] += 1
        else:
            report.unique_signals[signal_key] = 1
    
    return report
```

**This knowledge represents enterprise-grade Godot signal communication patterns used in production games. Master these patterns for expert-level event-driven architecture.**