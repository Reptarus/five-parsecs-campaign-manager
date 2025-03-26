@tool
extends CharacterBody2D

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Core properties
var enemy_data = null
var navigation_agent: NavigationAgent2D = null

# Stats
var health: int = 100
var max_health: int = 100
var damage: int = 10
var armor: int = 5
var abilities: Array = []
var loot_table: Dictionary = {"credits": 50, "items": []}
var is_dead_state: bool = false

# Signals
signal enemy_initialized
signal health_changed(new_health: int, old_health: int)
signal died

func _ready() -> void:
	# Create a NavigationAgent2D if needed for pathing
	if not has_node("NavigationAgent2D"):
		navigation_agent = NavigationAgent2D.new()
		navigation_agent.name = "NavigationAgent2D"
		add_child(navigation_agent)
	emit_signal("enemy_initialized")

func initialize(data) -> bool:
	enemy_data = data
	# Set basic properties
	if data:
		# First check if the data is an Object or a Dictionary
		if typeof(data) == TYPE_DICTIONARY:
			# Direct dictionary access
			health = data.get("health", 100)
			max_health = data.get("max_health", 100)
			damage = data.get("damage", 10)
			armor = data.get("armor", 5)
			if data.has("name") or data.has("enemy_name"):
				name = data.get("name", data.get("enemy_name", "Enemy"))
		# If it's an object, check for methods
		elif data.has_method("get_meta"):
			health = data.get_meta("health") if data.has_meta("health") else 100
			max_health = data.get_meta("max_health") if data.has_meta("max_health") else 100
			damage = data.get_meta("damage") if data.has_meta("damage") else 10
			armor = data.get_meta("armor") if data.has_meta("armor") else 5
			if data.has_meta("name"):
				name = data.get_meta("name")
		elif data.has_method("to_dict"):
			var dict = data.to_dict()
			health = dict.get("health", 100)
			max_health = dict.get("max_health", 100)
			damage = dict.get("damage", 10)
			armor = dict.get("armor", 5)
			name = dict.get("enemy_name", "Enemy")
		# Fallback to direct property access if methods aren't available
		else:
			if data.get("health") != null:
				health = data.health
			if data.get("max_health") != null:
				max_health = data.max_health
			if data.get("damage") != null:
				damage = data.damage
			if data.get("armor") != null:
				armor = data.armor
			if data.get("name") != null:
				name = data.name
			elif data.get("enemy_name") != null:
				name = data.enemy_name
	emit_signal("enemy_initialized")
	return true
	
func get_health() -> int:
	return health
	
func set_health(value: int) -> void:
	var old_health = health
	health = value
	is_dead_state = health <= 0
	health_changed.emit(health, old_health)
	
	if is_dead_state:
		died.emit()
	
func take_damage(amount: int) -> int:
	var actual_damage = max(0, amount - armor)
	var old_health = health
	health -= actual_damage
	is_dead_state = health <= 0
	health_changed.emit(health, old_health)
	
	if is_dead_state:
		died.emit()
		
	return actual_damage
	
func heal(amount: int) -> int:
	var old_health = health
	health = min(health + amount, max_health)
	health_changed.emit(health, old_health)
	return health - old_health
	
func is_dead() -> bool:
	return is_dead_state
	
func get_abilities() -> Array:
	return abilities
	
func get_loot() -> Dictionary:
	return loot_table

# Combat methods
func get_attack_damage() -> int:
	return damage
	
func can_attack() -> bool:
	return health > 0
	
# Movement methods
func move_to(target_position: Vector2) -> void:
	if not is_instance_valid(navigation_agent):
		navigation_agent = $NavigationAgent2D if has_node("NavigationAgent2D") else null
		if not navigation_agent:
			navigation_agent = NavigationAgent2D.new()
			navigation_agent.name = "NavigationAgent2D"
			add_child(navigation_agent)
	
	# Set the target for navigation
	navigation_agent.target_position = target_position
	
	# Basic implementation - just update position
	position = target_position

# Test pathfinding initialization
func test_pathfinding_initialization() -> bool:
	if not has_node("NavigationAgent2D"):
		var nav_agent = NavigationAgent2D.new()
		nav_agent.name = "NavigationAgent2D"
		add_child(nav_agent)
		navigation_agent = nav_agent
		
	if not is_instance_valid(navigation_agent):
		navigation_agent = get_node_or_null("NavigationAgent2D")
		
	return is_instance_valid(navigation_agent)

# Ability handling
func has_ability(ability_type: int) -> bool:
	for ability in abilities:
		if ability is Dictionary and ability.get("ability_type") == ability_type:
			return true
	return false
	
func add_ability(ability: Dictionary) -> void:
	if not ability in abilities:
		abilities.append(ability)
		
func use_ability(ability_type: int, target: Node2D = null) -> bool:
	# Simple implementation
	for ability in abilities:
		if ability is Dictionary and ability.get("ability_type") == ability_type:
			return true
	return false