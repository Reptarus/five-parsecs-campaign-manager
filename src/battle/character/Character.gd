@tool
extends Node2D
class_name Character

const BaseCharacter = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")

# Reference to the character data resource
var _character: Resource = null

# Battle specific properties
var position_on_grid: Vector2i = Vector2i.ZERO
var is_active: bool = false
var can_move: bool = true
var can_attack: bool = true
var action_points: int = 0
var max_action_points: int = 2
var movement_range: int = 3 # Cells

# Navigation
var _navigation_agent: NavigationAgent2D = null
var _movement_target: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _movement_speed: float = 100.0 # Pixels per second

# Status effect indicators
var _status_effect_container: Node2D = null

# Animation
var _animator: AnimationPlayer = null
var _sprite: Sprite2D = null

# UI elements
var _health_bar: ProgressBar = null
var _character_name_label: Label = null

# Signals
signal character_initialized()
signal health_changed(old_value, new_value)
signal position_changed(old_position, new_position)
signal action_points_changed(old_value, new_value)
signal turn_started()
signal turn_ended()
signal attack_executed(target)
signal died()

# Static helper for detecting the correct script type
static func is_node_script() -> bool:
	return true

static func is_resource_script() -> bool:
	return false

func _ready() -> void:
	# Configure the node
	_setup_components()
	_setup_navigation_agent()
	
	# Emit initialized signal when ready
	character_initialized.emit()

func _setup_components() -> void:
	# Create components if they don't exist
	if not has_node("StatusEffects"):
		_status_effect_container = Node2D.new()
		_status_effect_container.name = "StatusEffects"
		add_child(_status_effect_container)
	else:
		_status_effect_container = get_node("StatusEffects")
	
	if not has_node("AnimationPlayer"):
		_animator = AnimationPlayer.new()
		_animator.name = "AnimationPlayer"
		add_child(_animator)
	else:
		_animator = get_node("AnimationPlayer")
	
	if not has_node("Sprite2D"):
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
	else:
		_sprite = get_node("Sprite2D")
	
	# Setup UI components
	if not has_node("UI"):
		var ui_container = Node2D.new()
		ui_container.name = "UI"
		add_child(ui_container)
		
		_health_bar = ProgressBar.new()
		_health_bar.name = "HealthBar"
		_health_bar.max_value = 100
		_health_bar.value = 100
		_health_bar.size = Vector2(32, 5)
		_health_bar.position = Vector2(-16, -30)
		ui_container.add_child(_health_bar)
		
		_character_name_label = Label.new()
		_character_name_label.name = "NameLabel"
		_character_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_character_name_label.position = Vector2(-32, -45)
		_character_name_label.size = Vector2(64, 20)
		ui_container.add_child(_character_name_label)
	else:
		var ui_container = get_node("UI")
		_health_bar = ui_container.get_node("HealthBar")
		_character_name_label = ui_container.get_node("NameLabel")

func _setup_navigation_agent() -> void:
	if not has_node("NavigationAgent2D"):
		_navigation_agent = NavigationAgent2D.new()
		_navigation_agent.name = "NavigationAgent2D"
		_navigation_agent.path_desired_distance = 4.0
		_navigation_agent.target_desired_distance = 4.0
		_navigation_agent.avoidance_enabled = true
		add_child(_navigation_agent)
	else:
		_navigation_agent = get_node("NavigationAgent2D")
	
	# Connect navigation signals
	if not _navigation_agent.velocity_computed.is_connected(Callable(self, "_on_velocity_computed")):
		_navigation_agent.velocity_computed.connect(_on_velocity_computed)
	if not _navigation_agent.navigation_finished.is_connected(Callable(self, "_on_navigation_finished")):
		_navigation_agent.navigation_finished.connect(_on_navigation_finished)

func _physics_process(delta: float) -> void:
	if _is_moving:
		_process_movement(delta)

# Initialize with character data
func initialize(character_data: Resource) -> bool:
	if not character_data:
		push_warning("Cannot initialize BattleCharacter with null character data")
		return false
	
	if not (character_data is Resource) or not character_data.get_script():
		push_warning("Character data must be a valid Resource with script")
		return false
	
	# Add explicit type check for BaseCharacterResource with safety measures
	# Check if the resource has the critical methods and properties we need
	var has_required_properties = true
	var required_methods = ["get_health", "get_max_health", "serialize"]
	for method in required_methods:
		if not character_data.has_method(method):
			push_warning("Character data missing required method: " + method)
			has_required_properties = false
	
	if not has_required_properties:
		push_warning("Character data does not appear to be a valid character resource")
		return false
	
	# If resource has a is_resource_script static method, call it to verify
	var script = character_data.get_script()
	if script and script.has_method("is_resource_script"):
		var is_valid = script.call("is_resource_script")
		if not is_valid:
			push_warning("Character data script reports it is not a resource script")
			return false
	
	# Store the character resource
	_character = character_data
	
	# Connect signals from character resource
	_connect_signals()
	
	# Initialize UI
	if _character.get("character_name") != null:
		_character_name_label.text = _character.character_name
	
	if _character.get("health") != null and _character.get("max_health") != null:
		_health_bar.max_value = _character.max_health
		_health_bar.value = _character.health
	
	# Determine movement range from character speed
	if _character.get("speed") != null:
		movement_range = ceili(_character.speed / 2)
	
	# Initialize sprite
	_setup_character_sprite()
	
	# Start with full action points
	action_points = max_action_points
	
	return true

# Connect signals from the character resource
func _connect_signals() -> void:
	if not _character:
		return
	
	# Connect health changed signal
	if _character.has_signal("health_changed"):
		# Disconnect any existing connections to avoid duplicates
		if _character.is_connected("health_changed", Callable(self, "_on_character_health_changed")):
			_character.disconnect("health_changed", Callable(self, "_on_character_health_changed"))
		_character.connect("health_changed", Callable(self, "_on_character_health_changed"))
	
	# Connect died signal
	if _character.has_signal("died"):
		if _character.is_connected("died", Callable(self, "_on_character_died")):
			_character.disconnect("died", Callable(self, "_on_character_died"))
		_character.connect("died", Callable(self, "_on_character_died"))
	
	# Connect status changed signal
	if _character.has_signal("status_changed"):
		if _character.is_connected("status_changed", Callable(self, "_on_character_status_changed")):
			_character.disconnect("status_changed", Callable(self, "_on_character_status_changed"))
		_character.connect("status_changed", Callable(self, "_on_character_status_changed"))

# Setup character sprite based on character data
func _setup_character_sprite() -> void:
	if not _sprite:
		return
	
	# Placeholder sprite logic - in a real game you'd load based on character properties
	var texture_path = "res://assets/sprites/characters/default_character.png"
	
	# Try to determine sprite based on character class if available
	if _character and _character.get("character_class") != null:
		var character_class = _character.character_class
		match character_class:
			0: # Soldier
				texture_path = "res://assets/sprites/characters/soldier.png"
			1: # Scout
				texture_path = "res://assets/sprites/characters/scout.png"
			2: # Medic
				texture_path = "res://assets/sprites/characters/medic.png"
			3: # Engineer
				texture_path = "res://assets/sprites/characters/engineer.png"
	
	# Load texture if it exists
	if ResourceLoader.exists(texture_path):
		_sprite.texture = load(texture_path)
	else:
		# Create a placeholder texture
		var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 0, 0, 1))
		var texture = ImageTexture.create_from_image(image)
		_sprite.texture = texture

# Signal handlers
func _on_character_health_changed(old_value: int, new_value: int) -> void:
	if _health_bar:
		_health_bar.value = new_value
	
	# Forward the signal
	health_changed.emit(old_value, new_value)

func _on_character_died() -> void:
	# Handle death visually
	if _animator and _animator.has_animation("death"):
		_animator.play("death")
	else:
		# Simple visual effect for death
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	# Forward the signal
	died.emit()

func _on_character_status_changed(status: String) -> void:
	# Update visual status effects
	_update_status_effects()

# Update visual representation of status effects
func _update_status_effects() -> void:
	if not _character or not _status_effect_container:
		return
	
	# Clear existing status icons
	for child in _status_effect_container.get_children():
		child.queue_free()
	
	# Get status effects from character if available
	var status_effects = []
	if _character.get("status_effects") != null:
		status_effects = _character.status_effects
	
	# Add visual indicator for each status effect
	var offset = 0
	for effect in status_effects:
		if effect is Dictionary and "type" in effect:
			var icon = Sprite2D.new()
			icon.position = Vector2(0, -50 - offset)
			
			# Load appropriate icon based on effect type
			var icon_path = "res://assets/sprites/ui/status_" + str(effect.type) + ".png"
			if ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)
			else:
				# Create placeholder icon
				var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
				image.fill(Color(1, 0, 0, 1))
				var texture = ImageTexture.create_from_image(image)
				icon.texture = texture
			
			_status_effect_container.add_child(icon)
			offset += 20

# Movement methods
func move_to_grid_position(grid_pos: Vector2i) -> bool:
	if not _navigation_agent or not is_active:
		return false
	
	if not can_move:
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
	
	# Convert grid position to world position
	var target_world_pos = Vector2(grid_pos.x * 32 + 16, grid_pos.y * 32 + 16)
	
	# Set the movement target
	_movement_target = target_world_pos
	_navigation_agent.target_position = _movement_target
	_is_moving = true
	
	# Use an action point
	set_action_points(action_points - 1)
	
	# Emit position changed signal
	position_changed.emit(old_position, position_on_grid)
	
	return true

func _process_movement(delta: float) -> void:
	if not _navigation_agent:
		_is_moving = false
		return
	
	if _navigation_agent.is_navigation_finished():
		_is_moving = false
		return
	
	# Get next path position
	var next_path_position = _navigation_agent.get_next_path_position()
	
	# Calculate velocity
	var direction = (next_path_position - global_position).normalized()
	var velocity = direction * _movement_speed * delta
	
	# Move the character
	_navigation_agent.velocity = velocity
	position += velocity

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	# This can be used for physics-based movement if needed
	pass

func _on_navigation_finished() -> void:
	_is_moving = false
	
	# Play idle animation
	if _animator and _animator.has_animation("idle"):
		_animator.play("idle")

# Combat methods
func attack(target_node: Node2D) -> bool:
	if not is_active or not can_attack:
		return false
	
	if not target_node or not is_instance_valid(target_node):
		return false
	
	# Check if we have enough action points
	if action_points <= 0:
		return false
	
	# Calculate distance to target
	var distance = position_on_grid.distance_to(target_node.position_on_grid)
	
	# Get character's weapon range
	var weapon_range = 1 # Default melee range
	if _character and _character.get("weapons") != null and _character.weapons.size() > 0:
		var equipped_weapon = _character.weapons[0]
		if equipped_weapon and equipped_weapon.get("range") != null:
			weapon_range = equipped_weapon.range
	
	# Check if target is in range
	if distance > weapon_range:
		return false
	
	# Play attack animation
	if _animator and _animator.has_animation("attack"):
		_animator.play("attack")
	
	# Calculate damage using character's combat stat
	var damage = 10 # Default damage
	if _character and _character.get("combat") != null:
		damage = 5 + (_character.combat * 2)
	
	# Apply damage to target
	if target_node.has_method("take_damage"):
		target_node.take_damage(damage)
	
	# Use an action point
	set_action_points(action_points - 1)
	
	# Emit attack signal
	attack_executed.emit(target_node)
	
	return true

# Take damage method
func take_damage(amount: int) -> bool:
	if not _character:
		return false
	
	# Delegate to character resource
	if _character.has_method("take_damage"):
		return _character.take_damage(amount)
	
	return false

# Heal method
func heal(amount: int) -> bool:
	if not _character:
		return false
	
	# Delegate to character resource
	if _character.has_method("heal"):
		return _character.heal(amount)
	
	return false

# Turn management
func start_turn() -> void:
	is_active = true
	
	# Reset movement and attack flags
	can_move = true
	can_attack = true
	
	# Reset action points
	set_action_points(max_action_points)
	
	# Emit turn started signal
	turn_started.emit()

func end_turn() -> void:
	is_active = false
	
	# Reset action points
	set_action_points(0)
	
	# Emit turn ended signal
	turn_ended.emit()

# Helper methods
func set_action_points(value: int) -> void:
	var old_value = action_points
	action_points = clampi(value, 0, max_action_points)
	
	if old_value != action_points:
		action_points_changed.emit(old_value, action_points)

# Get character's name
func get_character_name() -> String:
	if _character and _character.get("character_name") != null:
		return _character.character_name
	return "Unknown"

# Get character's health
func get_health() -> int:
	if _character and _character.get("health") != null:
		return _character.health
	return 0

# Get character's max health
func get_max_health() -> int:
	if _character and _character.get("max_health") != null:
		return _character.max_health
	return 0

# Check if character is dead
func is_dead() -> bool:
	if _character and _character.has_method("is_dead"):
		return _character.is_dead()
	return false

# Apply status effect
func apply_status_effect(effect: Dictionary) -> void:
	if not _character:
		return
	
	# Delegate to character resource
	if _character.has_method("apply_status_effect"):
		_character.apply_status_effect(effect)
		
		# Update visual effects
		_update_status_effects()

# Override _exit_tree to clean up
func _exit_tree() -> void:
	# Disconnect signals
	if _character:
		if _character.has_signal("health_changed") and _character.is_connected("health_changed", Callable(self, "_on_character_health_changed")):
			_character.disconnect("health_changed", Callable(self, "_on_character_health_changed"))
		
		if _character.has_signal("died") and _character.is_connected("died", Callable(self, "_on_character_died")):
			_character.disconnect("died", Callable(self, "_on_character_died"))
		
		if _character.has_signal("status_changed") and _character.is_connected("status_changed", Callable(self, "_on_character_status_changed")):
			_character.disconnect("status_changed", Callable(self, "_on_character_status_changed"))
