@tool
extends CharacterBody2D
# Renamed from BaseEnemy to EnemyNode - this is the main scene node script for enemies

# Preload the data resource script (assuming it will be renamed to EnemyData.gd)
const EnemyData = preload("res://src/core/enemy/EnemyData.gd")

# Export variable to assign the data resource in the editor
@export var enemy_data: EnemyData = null

# Remove circular dependency
# const MainEnemy = preload("res://src/core/enemy/Enemy.gd")

# Core properties
var navigation_agent: NavigationAgent2D = null

# Stats
var health: float = 100.0
var max_health: float = 100.0
var damage: float = 10.0
var armor: float = 5.0
var abilities: Array = []
var loot_table: Dictionary = {"credits": 50, "items": []}
var is_dead_state: bool = false
var stance: int = 0 # 0 = neutral, 1 = aggressive, 2 = defensive
var status_effects: Dictionary = {}
var target = null

# Additional state for testing
var is_active_state: bool = false
var can_move_state: bool = false

# Behavior
var behavior: int = 0 # 0 = passive, 1 = aggressive, 2 = defensive, 3 = support

# Combat and movement properties
var movement_range: float = 4.0
var weapon_range: float = 1.0

# Signals
signal enemy_initialized(node: EnemyNode) # Pass self
signal health_changed(old_value, new_value)
signal died
signal turn_started(node: EnemyNode)
signal turn_ended(node: EnemyNode)
signal attack_executed(node: EnemyNode, target_node: Node) # Specify target type later if possible
signal attack_completed(node: EnemyNode)
signal touch_handled(node: EnemyNode, position: Vector2)
signal drag_handled(node: EnemyNode, start_position: Vector2, end_position: Vector2)
signal selected(node: EnemyNode)
signal position_changed(node: EnemyNode, old_position: Vector2, new_position: Vector2) # Emit Node position

# Static helper method to determine type compatibility
static func is_node_script() -> bool:
	return true

# Static helper method that creates a safe instance
static func create_instance() -> Node: # Return generic Node type
	# return EnemyNode.new() # Cannot use the removed class name
	# Instantiate using the script resource itself
	var script = preload("res://src/core/enemy/base/Enemy.gd")
	return script.new()

func _ready() -> void:
	# Set default position if needed (or rely on scene placement)
	# position = Vector2(50, 50) 
	# Create a NavigationAgent2D if needed for pathing
	_setup_navigation_agent()
	
	# Initialize internal state from the assigned resource
	if enemy_data:
		if not initialize(enemy_data): # Call internal initialize
			push_warning("Failed to initialize EnemyNode from assigned EnemyData.")
		# Connect signals from the data resource AFTER it's assigned
		_connect_data_signals()
	else:
		push_warning("EnemyNode '%s' is missing its enemy_data assignment!" % name)
		# Optionally create a default EnemyData instance here if desired
		# enemy_data = EnemyData.new()
		# initialize(enemy_data)

	emit_signal("enemy_initialized", self) # Emit node initialized

# Set up navigation agent with error handling
func _setup_navigation_agent() -> void:
	if has_node("NavigationAgent2D"):
		# Already has one
		navigation_agent = $NavigationAgent2D
		return
		
	# Create and add NavigationAgent2D for path finding
	var nav_agent = NavigationAgent2D.new()
	if nav_agent:
		nav_agent.name = "NavigationAgent2D"
		add_child(nav_agent)
		navigation_agent = nav_agent
	else:
		push_warning("Failed to create NavigationAgent2D")

# Initialize NODE properties based on DATA resource
func initialize(data: EnemyData) -> bool:
	if not data:
		push_warning("EnemyNode initialized with null data")
		# Cannot proceed without data
		return false

	# Ensure the internal reference is set if called manually
	if not enemy_data:
		enemy_data = data
		# Connect signals if initializing manually after _ready
		_connect_data_signals()

	# Set node-specific properties based on data if needed
	# Example: Maybe modulate color based on health? Not strictly necessary here.
	# update_visuals()

	# Initial position might be set by scene placement or data
	var props = data.get_property_list()
	var has_initial_position = false
	for prop in props:
		if prop.name == "initial_position":
			has_initial_position = true
			break
	
	if has_initial_position and data.initial_position != Vector2.INF:
		global_position = data.initial_position

	return true

# Connect signals from the EnemyData resource
func _connect_data_signals() -> void:
	if not enemy_data:
		push_warning("Cannot connect signals: enemy_data is null.")
		return

	# Connect signals IF they exist on EnemyData and are not already connected
	if enemy_data.has_signal("health_changed"):
		if not enemy_data.is_connected("health_changed", Callable(self, "_on_data_health_changed")):
			enemy_data.connect("health_changed", Callable(self, "_on_data_health_changed"))

	if enemy_data.has_signal("died"):
		if not enemy_data.is_connected("died", Callable(self, "_on_data_died")):
			enemy_data.connect("died", Callable(self, "_on_data_died"))

	# Add connections for other relevant data signals (e.g., status_changed) if they exist in EnemyData

# --- Signal Handlers for Data Resource ---
func _on_data_health_changed(old_value, new_value) -> void:
	# Maybe update visuals based on health? E.g., health bar
	# print("EnemyNode %s health changed: %s -> %s" % [name, old_value, new_value])
	pass

func _on_data_died() -> void:
	# Handle node death visuals/logic
	# print("EnemyNode %s died!" % name)
	# Play death animation, disable interactions, etc.
	set_process(false) # Example: stop processing
	set_physics_process(false)
	hide() # Example: hide the node
	pass

# --- Getter methods - Delegate to enemy_data ---
func get_health() -> float:
	return enemy_data.get_health() if enemy_data else 0.0
	
func get_max_health() -> float:
	return enemy_data.max_health if enemy_data else 0.0

func get_damage() -> float:
	return enemy_data.damage if enemy_data else 0.0

func get_armor() -> float:
	return enemy_data.armor if enemy_data else 0.0

func get_abilities() -> Array:
	return enemy_data.abilities if enemy_data else []
	
func get_loot() -> Dictionary:
	return enemy_data.loot_table if enemy_data else {"credits": 0, "items": []}

func get_stance() -> int:
	return enemy_data.stance if enemy_data else 0 # Default stance

func get_status_effects() -> Dictionary:
	return enemy_data.status_effects if enemy_data else {}
	
func get_behavior() -> int:
	return enemy_data.behavior if enemy_data else 0 # Default behavior

func get_movement_range() -> float:
	return enemy_data.movement_range if enemy_data else 0.0

func get_weapon_range() -> float:
	return enemy_data.weapon_range if enemy_data else 0.0

# --- Methods that operate on data - Delegate actions to enemy_data ---
func take_damage(amount) -> int:
	if enemy_data:
		return enemy_data.take_damage(amount)
	return 0
	
func is_dead() -> bool:
	# The node itself isn't "dead", its data indicates if it should be treated as such
	return enemy_data.is_dead() if enemy_data else true # Assume dead if no data

func heal(amount: int) -> int:
	if enemy_data:
		return enemy_data.heal(amount)
	return 0

func apply_status_effect(effect_name: String, duration: int = 3) -> bool:
	if enemy_data:
		return enemy_data.apply_status_effect(effect_name, duration)
	return false

func apply_status_effect_dict(effect_data: Dictionary) -> bool:
	if enemy_data:
		return enemy_data.apply_status_effect_dict(effect_data)
	return false

func has_status_effect(effect_name: String) -> bool:
	if enemy_data and enemy_data.has_method("has_status_effect"):
		return enemy_data.has_status_effect(effect_name)
	return false

# --- Node-specific Methods ---

# Position getter/setter - Operates on the Node's transform
func get_position() -> Vector2:
	return global_position # Use global_position for scene context

func set_position(value: Vector2) -> void:
	var old_position = global_position
	if old_position != value:
		global_position = value
		emit_signal("position_changed", self, old_position, value)

# Movement methods - Should use navigation agent or physics movement
func move_to(target_position: Vector2) -> bool:
	if not navigation_agent:
		push_warning("Cannot move_to: NavigationAgent2D not found.")
		return false
		
	# Check if target is reachable (optional, depends on nav mesh setup)
	# var path = NavigationServer2D.map_get_path(navigation_agent.get_navigation_map(), global_position, target_position, true)
	# if path.is_empty():
	#     push_warning("Cannot move_to: Target position is not reachable.")
	#     return false

	navigation_agent.target_position = target_position
	
	# Actual movement should happen in _physics_process based on navigation_agent
	# For now, just setting the target is enough to indicate intent
	return true

func _physics_process(delta: float) -> void:
	if not enemy_data or is_dead(): # Stop moving if dead or no data
		set_physics_process(false)
		return

	if navigation_agent and not navigation_agent.is_navigation_finished():
		var current_agent_position: Vector2 = global_position
		var next_agent_position: Vector2 = navigation_agent.get_next_path_position()
		
		# Example movement logic (replace with your preferred movement method)
		var direction = (next_agent_position - current_agent_position).normalized()
		
		# Get speed from data if available using property list check
		var speed = 100.0 # Default speed
		var props = enemy_data.get_property_list()
		var has_speed = false
		for prop in props:
			if prop.name == "speed":
				has_speed = true
				break
				
		if has_speed:
			speed = enemy_data.speed
			
		var desired_velocity = direction * speed
		
		navigation_agent.velocity = desired_velocity # Let agent calculate safe velocity
		velocity = navigation_agent.velocity # Use agent's calculated velocity
		move_and_slide()
		
		# Update Node's position based on physics movement
		var old_position = current_agent_position # Position before move_and_slide
		if old_position.distance_to(global_position) > 0.1: # Check if moved significantly
			emit_signal("position_changed", self, old_position, global_position)
	else:
		# Stop movement if finished or no target
		velocity = Vector2.ZERO

# --- Combat / Turn Management (Node specific signals) ---
func start_turn() -> bool:
	if is_dead(): return false # Cannot start turn if dead
	emit_signal("turn_started", self)
	return true
	
func end_turn() -> bool:
	emit_signal("turn_ended", self)
	return true
	
func is_active() -> bool:
	# Active state might depend on game manager, not stored directly here
	# This method might need more context or removal
	return not is_dead()

func can_move() -> bool:
	# Movement capability depends on game rules, AP, status effects etc.
	if is_dead():
		return false
		
	if not enemy_data:
		return true
		
	if enemy_data.has_method("has_status_effect"):
		return not enemy_data.has_status_effect("stunned")
		
	return true

func can_attack() -> bool:
	if is_dead():
		return false
		
	if not enemy_data:
		return true
		
	if enemy_data.has_method("has_status_effect"):
		return not enemy_data.has_status_effect("disarmed")
		
	return true

func attack(target_node: Node) -> bool:
	if not target_node or not can_attack() or not is_instance_valid(target_node):
		return false
		
	# Check range using data
	if not is_target_in_range(target_node):
		push_warning("Cannot attack: Target out of range.")
		return false

	emit_signal("attack_executed", self, target_node)
	
	# Simulate attack delay
	var scene_tree = get_tree()
	if scene_tree:
		await scene_tree.create_timer(0.5).timeout
	else:
		await Engine.get_main_loop().process_frame # Minimal delay if not in tree
		
	# Apply damage (assuming target has take_damage)
	if target_node.has_method("take_damage"):
		var dmg = get_damage() # Get damage from data
		target_node.take_damage(dmg)

	emit_signal("attack_completed", self)
	return true
	
func is_target_in_range(target_node: Node) -> bool:
	if not target_node or not "global_position" in target_node:
		return false
		
	var range_data = get_weapon_range() # Get range from data
	# Convert range (potentially grid units) to distance units if necessary
	# Assuming range_data is already in world distance units for simplicity here
	var distance = global_position.distance_to(target_node.global_position)
	return distance <= range_data

func can_hit_target(target_node: Node) -> bool:
	# Basic range check, could add line-of-sight later
	return is_target_in_range(target_node)

# --- Interaction Handlers (Emit signals) ---
func handle_touch(touch_position: Vector2) -> bool:
	emit_signal("touch_handled", self, touch_position)
	return true
	
func handle_drag(start_pos: Vector2, end_pos: Vector2) -> bool:
	emit_signal("drag_handled", self, start_pos, end_pos)
	return true
	
func handle_selection() -> bool:
	emit_signal("selected", self)
	return true
	
# --- Save/Load (Node specific state, if any) ---
# Usually, node state is rebuilt from data, but you could save/load
# things like current animation state if needed.
# func save() -> Dictionary: ...
# func load(data: Dictionary) -> bool: ...

# --- Test/Validation Methods ---
func is_valid() -> bool:
	# A node is valid if it exists and has data (and the data isn't 'dead')
	return is_instance_valid(self) and enemy_data != null and not enemy_data.is_dead()
	
func get_combat_rating() -> float:
	# Delegate to data if it exists
	return enemy_data.get_combat_rating() if enemy_data else 0.0

# --- Removed internal state variables that are now in EnemyData ---
# --- Removed methods that purely manipulated internal state now in EnemyData ---
# --- Kept methods related to Node behavior (movement, signals, interaction) ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Disconnect signals from data resource if it exists and is valid
		if enemy_data and is_instance_valid(enemy_data):
			if enemy_data.has_signal("health_changed") and enemy_data.is_connected("health_changed", Callable(self, "_on_data_health_changed")):
				enemy_data.disconnect("health_changed", Callable(self, "_on_data_health_changed"))
			if enemy_data.has_signal("died") and enemy_data.is_connected("died", Callable(self, "_on_data_died")):
				enemy_data.disconnect("died", Callable(self, "_on_data_died"))
				
# Removed test_pathfinding_initialization - should be done in tests if needed
# Removed add_ability, use_ability - should be delegated to enemy_data or handled differently
# Removed equipment methods (equip_weapon, get_weapon) - Should likely be handled by enemy_data


# Added helper to get the data resource
func get_enemy_data() -> EnemyData:
	return enemy_data
