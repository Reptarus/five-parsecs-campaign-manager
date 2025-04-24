@tool
extends Resource
class_name BattleCharacterResource

const BaseCharacter = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")

# Delegation to character resource
var _base_character_resource = null

# Core character properties
var character_name: String = "New Character"
var character_type: int = 0
var level: int = 1
var experience: int = 0
var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var is_wounded: bool = false

# Battle specific properties
var position_on_grid: Vector2i = Vector2i.ZERO
var is_active_state: bool = false
var can_move_state: bool = true
var can_attack_state: bool = true
var action_points: int = 0
var max_action_points: int = 2
var movement_range: int = 3 # Cells

# Character stats
var reaction: int = 0
var combat: int = 0
var toughness: int = 0
var speed: int = 0

# Signals
signal character_initialized()
signal health_changed(old_value, new_value)
signal position_changed(old_position, new_position)
signal action_points_changed(old_value, new_value)
signal turn_started()
signal turn_ended()
signal attack_executed(target)
signal died()
signal status_changed(status)
signal experience_changed(old_value, new_value) 
signal level_changed(old_value, new_value)

# Static helpers for test compatibility and type safety
static func is_resource_script() -> bool:
	return true

static func is_node_script() -> bool:
	return false
	
static func create_node_character() -> Node:
	# Check if the battle character script exists
	if not ResourceLoader.exists("res://src/battle/character/Character.gd"):
		push_error("BattleCharacter script not found")
		return null
	
	var script = load("res://src/battle/character/Character.gd")
	if not script or not script is GDScript:
		push_error("BattleCharacter is not a valid GDScript")
		return null
		
	var instance = script.new()
	if not instance:
		push_error("Failed to create BattleCharacter instance")
		return null
		
	if not instance is Node:
		push_error("BattleCharacter instance is not a Node")
		instance.free()
		return null
		
	return instance

func _init() -> void:
	# Create a core character resource for delegation
	_create_base_character()
	_connect_signals()

# Create the base character for delegation with error handling
func _create_base_character() -> void:
	if not ResourceLoader.exists("res://src/core/character/Base/Character.gd"):
		push_warning("BaseCharacter script not found, some functionality will be limited")
		return
		
	var script = load("res://src/core/character/Base/Character.gd")
	if not script or not script is GDScript:
		push_warning("BaseCharacter is not a valid GDScript, some functionality will be limited")
		return
		
	var instance = script.new()
	if not instance or not instance is Resource:
		push_warning("Failed to create BaseCharacter instance, some functionality will be limited")
		return
		
	_base_character_resource = instance

# Connect base character resource signals to this resource's signals
func _connect_signals() -> void:
	if not _base_character_resource:
		return
		
	# Connect signals if they exist in the base character
	var signals_to_connect = [
		{"signal_name": "experience_changed", "method": "_on_base_experience_changed"},
		{"signal_name": "level_changed", "method": "_on_base_level_changed"},
		{"signal_name": "health_changed", "method": "_on_base_health_changed"},
		{"signal_name": "status_changed", "method": "_on_base_status_changed"}
	]
	
	for sig_data in signals_to_connect:
		if _base_character_resource.has_signal(sig_data.signal_name):
			# Check if already connected
			if not _base_character_resource.is_connected(sig_data.signal_name, Callable(self, sig_data.method)):
				_base_character_resource.connect(sig_data.signal_name, Callable(self, sig_data.method))
	
	# Initialize properties from base character
	if _base_character_resource:
		# Sync character properties
		if _base_character_resource.get("character_name") != null:
			character_name = _base_character_resource.character_name
		if _base_character_resource.get("level") != null:
			level = _base_character_resource.level
		if _base_character_resource.get("experience") != null:
			experience = _base_character_resource.experience
		if _base_character_resource.get("health") != null:
			health = _base_character_resource.health
		if _base_character_resource.get("max_health") != null:
			max_health = _base_character_resource.max_health
		if _base_character_resource.get("is_dead") != null:
			is_dead = _base_character_resource.is_dead
		if _base_character_resource.get("is_wounded") != null:
			is_wounded = _base_character_resource.is_wounded
		
		# Sync stats
		if _base_character_resource.get("reaction") != null:
			reaction = _base_character_resource.reaction
		if _base_character_resource.get("combat") != null:
			combat = _base_character_resource.combat
		if _base_character_resource.get("toughness") != null:
			toughness = _base_character_resource.toughness
		if _base_character_resource.get("speed") != null:
			speed = _base_character_resource.speed
			
			# Set movement range based on speed
			movement_range = ceili(speed / 2)

# Signal forwarders
func _on_base_experience_changed(old_value, new_value) -> void:
	experience = new_value
	experience_changed.emit(old_value, new_value)
	
func _on_base_level_changed(old_value, new_value) -> void:
	level = new_value
	level_changed.emit(old_value, new_value)
	
func _on_base_health_changed(old_value, new_value) -> void:
	health = new_value
	health_changed.emit(old_value, new_value)
	
func _on_base_status_changed(status_value) -> void:
	status_changed.emit(status_value)

# Initialize the character with data
func initialize(character_data: Resource) -> bool:
	if not character_data:
		push_warning("Cannot initialize BattleCharacterResource with null character data")
		return false
	
	# Store the base character resource
	if character_data is Resource and character_data.get_script():
		_base_character_resource = character_data
		_connect_signals()
		
		# Setup initial state
		is_active_state = false
		can_move_state = true
		can_attack_state = true
		action_points = 0
		
		# Emit initialized signal
		character_initialized.emit()
		return true
	
	return false

# Set position on grid
func set_position(pos: Vector2i) -> void:
	var old_position = position_on_grid
	position_on_grid = pos
	
	position_changed.emit(old_position, position_on_grid)

# Turn management
func start_turn() -> bool:
	is_active_state = true
	can_move_state = true
	can_attack_state = true
	
	# Reset action points
	set_action_points(max_action_points)
	
	# Emit turn started signal
	turn_started.emit()
	
	return true

func end_turn() -> bool:
	is_active_state = false
	
	# Reset action points
	set_action_points(0)
	
	# Emit turn ended signal
	turn_ended.emit()
	
	return true

# Action points management
func set_action_points(value: int) -> void:
	var old_value = action_points
	action_points = clampi(value, 0, max_action_points)
	
	if old_value != action_points:
		action_points_changed.emit(old_value, action_points)

# State getters
var is_active: bool:
	get: return is_active_state

var can_move: bool:
	get: return can_move_state
	set(value): can_move_state = value

var can_attack: bool:
	get: return can_attack_state
	set(value): can_attack_state = value

# Movement methods
func move_to_grid_position(grid_pos: Vector2i) -> bool:
	if not is_active_state:
		return false
	
	if not can_move_state:
		return false
	
	# Check if we have enough action points
	if action_points <= 0:
		return false
	
	# Calculate distance
	var distance = position_on_grid.distance_to(grid_pos)
	if distance > movement_range:
		return false
	
	# Store old position for signal
	var old_position = position_on_grid
	
	# Update grid position
	position_on_grid = grid_pos
	
	# Use an action point
	set_action_points(action_points - 1)
	
	# Emit position changed signal
	position_changed.emit(old_position, position_on_grid)
	
	return true

# Combat methods
func attack(target_node: Node) -> bool:
	if not is_active_state or not can_attack_state:
		return false
	
	if not target_node or not is_instance_valid(target_node):
		return false
	
	# Check if we have enough action points
	if action_points <= 0:
		return false
	
	# Get target position - try different ways to get it
	var target_position = Vector2i.ZERO
	if target_node.get("position_on_grid") != null:
		target_position = target_node.position_on_grid
	
	# Calculate distance to target
	var distance = position_on_grid.distance_to(target_position)
	
	# Get character's weapon range
	var weapon_range = 1 # Default melee range
	if _base_character_resource and _base_character_resource.get("weapons") != null and _base_character_resource.weapons.size() > 0:
		var equipped_weapon = _base_character_resource.weapons[0]
		if equipped_weapon and equipped_weapon.get("range") != null:
			weapon_range = equipped_weapon.range
	
	# Check if target is in range
	if distance > weapon_range:
		return false
	
	# Calculate damage using character's combat stat
	var damage = 10 # Default damage
	if combat > 0:
		damage = 5 + (combat * 2)
	
	# Apply damage to target
	if target_node.has_method("take_damage"):
		target_node.take_damage(damage)
	
	# Use an action point
	set_action_points(action_points - 1)
	
	# Emit attack signal
	attack_executed.emit(target_node)
	
	# Simulate the attack delay for animation purposes
	if Engine.get_main_loop():
		var main_loop = Engine.get_main_loop()
		var frame_count = 8 # Approximately 0.15 seconds at 60 FPS
		for i in range(frame_count):
			if main_loop.has_method("process_frame"):
				main_loop.process_frame()
	
	return true

# Character info methods
func get_character_name() -> String:
	if _base_character_resource and _base_character_resource.get("character_name") != null:
		return _base_character_resource.character_name
	return character_name

func get_health() -> int:
	if _base_character_resource and _base_character_resource.has_method("get_health"):
		return _base_character_resource.get_health()
	return health

func set_health(value: int) -> void:
	if value < 0:
		value = 0
	
	if value > max_health:
		value = max_health
	
	var old_value = health
	health = value
	
	# Update is_dead state
	if health <= 0:
		is_dead = true
		died.emit()
	
	if _base_character_resource and _base_character_resource.has_method("set_health"):
		_base_character_resource.set_health(value)
	else:
		# Only emit if we're not delegating to base character
		# (base character will emit and we'll forward from _on_base_health_changed)
		health_changed.emit(old_value, health)

func get_max_health() -> int:
	if _base_character_resource and _base_character_resource.has_method("get_max_health"):
		return _base_character_resource.get_max_health()
	return max_health

func check_if_dead() -> bool:
	if _base_character_resource and _base_character_resource.has_method("is_dead"):
		return _base_character_resource.is_dead()
	return is_dead

func take_damage(amount: int) -> bool:
	if amount <= 0:
		return false
	
	if _base_character_resource and _base_character_resource.has_method("take_damage"):
		var result = _base_character_resource.take_damage(amount)
		
		# Sync our health
		if _base_character_resource.get("health") != null:
			health = _base_character_resource.health
		
		# Check for death condition
		if health <= 0:
			is_dead = true
			died.emit()
			
		return result
	
	# Apply damage
	var old_health = health
	health = clampi(health - amount, 0, max_health)
	
	# Check for death
	if health <= 0:
		is_dead = true
		died.emit()
	
	health_changed.emit(old_health, health)
	return true

func heal(amount: int) -> bool:
	if amount <= 0 or is_dead:
		return false
	
	if _base_character_resource and _base_character_resource.has_method("heal"):
		var result = _base_character_resource.heal(amount)
		
		# Sync our health
		if _base_character_resource.get("health") != null:
			health = _base_character_resource.health
			
		return result
	
	# Apply healing
	var old_health = health
	health = clampi(health + amount, 0, max_health)
	
	health_changed.emit(old_health, health)
	return true

# Apply status effect
func apply_status_effect(effect: Dictionary) -> void:
	if not effect:
		return
	
	if _base_character_resource and _base_character_resource.has_method("apply_status_effect"):
		_base_character_resource.apply_status_effect(effect)
	else:
		status_changed.emit("effect_applied")

# Experience and leveling methods
func add_experience(amount: int) -> bool:
	if amount <= 0:
		return false
		
	if _base_character_resource and _base_character_resource.has_method("add_experience"):
		var result = _base_character_resource.add_experience(amount)
		
		# Sync our copies
		if _base_character_resource.get("experience") != null:
			experience = _base_character_resource.experience
		if _base_character_resource.get("level") != null:
			level = _base_character_resource.level
			
		return result
	
	var old_experience = experience
	var old_level = level
	
	# Cap experience at some maximum value
	experience = clampi(experience + amount, 0, 10000)
	
	# Handle leveling up
	var experience_for_level = level * 100
	if experience >= experience_for_level:
		level += 1
		level_changed.emit(old_level, level)
	
	experience_changed.emit(old_experience, experience)
	return true

# Serialize state for saving
func serialize() -> Dictionary:
	var data = {
		"character_name": character_name,
		"character_type": character_type,
		"level": level,
		"experience": experience,
		"health": health,
		"max_health": max_health,
		"is_dead": is_dead,
		"is_wounded": is_wounded,
		"reaction": reaction,
		"combat": combat,
		"toughness": toughness,
		"speed": speed,
		"position_on_grid": {"x": position_on_grid.x, "y": position_on_grid.y},
		"is_active": is_active_state,
		"can_move": can_move_state,
		"can_attack": can_attack_state,
		"action_points": action_points,
		"max_action_points": max_action_points,
		"movement_range": movement_range
	}
	
	# Add base character data if available
	if _base_character_resource and _base_character_resource.has_method("serialize"):
		var base_data = _base_character_resource.serialize()
		data["base_character"] = base_data
	
	return data

# Deserialize from saved state
func deserialize(data: Dictionary) -> void:
	if not data:
		push_warning("Attempt to deserialize null or empty data")
		return
	
	# Load character properties
	if "character_name" in data:
		character_name = data.character_name
	if "character_type" in data:
		character_type = data.character_type
	if "level" in data:
		level = data.level
	if "experience" in data:
		experience = data.experience
	if "health" in data:
		health = data.health
	if "max_health" in data:
		max_health = data.max_health
	if "is_dead" in data:
		is_dead = data.is_dead
	if "is_wounded" in data:
		is_wounded = data.is_wounded
	
	# Load stats
	if "reaction" in data:
		reaction = data.reaction
	if "combat" in data:
		combat = data.combat
	if "toughness" in data:
		toughness = data.toughness
	if "speed" in data:
		speed = data.speed
	
	# Load battle state
	if "position_on_grid" in data:
		var pos_data = data.position_on_grid
		position_on_grid = Vector2i(pos_data.x, pos_data.y)
	if "is_active" in data:
		is_active_state = data.is_active
	if "can_move" in data:
		can_move_state = data.can_move
	if "can_attack" in data:
		can_attack_state = data.can_attack
	if "action_points" in data:
		action_points = data.action_points
	if "max_action_points" in data:
		max_action_points = data.max_action_points
	if "movement_range" in data:
		movement_range = data.movement_range
	
	# Deserialize base character if data available
	if "base_character" in data and _base_character_resource and _base_character_resource.has_method("deserialize"):
		_base_character_resource.deserialize(data.base_character)
		
		# Sync properties from base character
		if _base_character_resource.get("character_name") != null:
			character_name = _base_character_resource.character_name
		if _base_character_resource.get("level") != null:
			level = _base_character_resource.level
		if _base_character_resource.get("experience") != null:
			experience = _base_character_resource.experience
		if _base_character_resource.get("health") != null:
			health = _base_character_resource.health
		if _base_character_resource.get("max_health") != null:
			max_health = _base_character_resource.max_health
		if _base_character_resource.get("is_dead") != null:
			is_dead = _base_character_resource.is_dead
		if _base_character_resource.get("is_wounded") != null:
			is_wounded = _base_character_resource.is_wounded
		if _base_character_resource.get("reaction") != null:
			reaction = _base_character_resource.reaction
		if _base_character_resource.get("combat") != null:
			combat = _base_character_resource.combat
		if _base_character_resource.get("toughness") != null:
			toughness = _base_character_resource.toughness
		if _base_character_resource.get("speed") != null:
			speed = _base_character_resource.speed

# Ensure the resource has a valid path to allow serialization
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Clean up the base character instance when this resource is freed
		if _base_character_resource and _base_character_resource is Resource and is_instance_valid(_base_character_resource):
			_base_character_resource.notification(NOTIFICATION_PREDELETE)
	
	# Add serialization safety
	if what == NOTIFICATION_POSTINITIALIZE:
		# Add a resource path if one doesn't exist (needed for proper serialization)
		if resource_path.is_empty():
			# Use a temporary path that's unique for this session
			resource_path = "res://tests/generated/battle_character_resource_%d.tres" % [Time.get_unix_time_from_system()] 