@tool
class_name Enemy
extends Node3D

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameWeapon = preload("res://src/core/systems/items/Weapon.gd")

# Signals
signal health_changed(new_health: int, max_health: int)
signal enemy_died
signal weapon_changed(new_weapon: GameWeapon)
signal behavior_changed(new_behavior: GlobalEnums.EnemyBehavior)

# Basic Properties
@export var enemy_name: String = "Enemy"
@export var enemy_type: GlobalEnums.EnemyType = GlobalEnums.EnemyType.GRUNT
@export var enemy_category: GlobalEnums.EnemyCategory = GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS

# Combat Stats
@export var health: int = 100:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health, max_health)
		if health <= 0:
			die()

@export var max_health: int = 100:
	set(value):
		max_health = maxi(1, value)
		health = mini(health, max_health)

@export var toughness: int = 3
@export var combat_skill: int = 0
@export var movement_speed: float = 4.0
@export var panic_value: String = "1-2"

# Combat Properties
@export var behavior: GlobalEnums.AIBehavior = GlobalEnums.AIBehavior.AGGRESSIVE:
	set(value):
		behavior = value
		behavior_changed.emit(value)

@export var weapon_class: GlobalEnums.WeaponType = GlobalEnums.WeaponType.BASIC
@export var characteristics: Array[GlobalEnums.EnemyCharacteristic] = []
@export var special_rules: Array[String] = []

# Node References
@onready var health_bar = $HealthBar
@onready var weapon_system = $WeaponSystem
@onready var animation_player = $AnimationPlayer
@onready var collision_shape = $CollisionShape3D

# State tracking
var is_active: bool = true
var current_weapon: GameWeapon
var target_position: Vector3
var current_target: Node
var in_cover: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		_initialize_health_display()
		_initialize_weapon_system()
		_initialize_collision()

func _initialize_health_display() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_changed.connect(_on_health_changed)

func _initialize_weapon_system() -> void:
	if weapon_system:
		setup_default_weapon()

func _initialize_collision() -> void:
	if collision_shape:
		collision_shape.disabled = false

func setup_default_weapon() -> void:
	var new_weapon = GameWeapon.new()
	new_weapon.name = "Enemy Weapon"
	new_weapon.weapon_type = weapon_class
	set_weapon(new_weapon)

func set_weapon(new_weapon: GameWeapon) -> void:
	if current_weapon != new_weapon:
		current_weapon = new_weapon
		weapon_changed.emit(current_weapon)

func take_damage(amount: int) -> void:
	if not is_active:
		return
	health -= amount

func heal(amount: int) -> void:
	if not is_active:
		return
	health += amount

func die() -> void:
	if not is_active:
		return
		
	is_active = false
	enemy_died.emit()
	
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
		await animation_player.animation_finished
		
	queue_free()

func get_attack_range() -> float:
	return current_weapon.range if current_weapon else 1.0

func get_movement_range() -> float:
	return movement_speed

func get_weapon() -> GameWeapon:
	return current_weapon

func has_characteristic(characteristic: GlobalEnums.EnemyCharacteristic) -> bool:
	return characteristic in characteristics

func add_characteristic(characteristic: GlobalEnums.EnemyCharacteristic) -> void:
	if not has_characteristic(characteristic):
		characteristics.append(characteristic)

func remove_characteristic(characteristic: GlobalEnums.EnemyCharacteristic) -> void:
	characteristics.erase(characteristic)

func set_target(new_target: Node) -> void:
	current_target = new_target

func get_target() -> Node:
	return current_target

func set_target_position(position: Vector3) -> void:
	target_position = position

func get_target_position() -> Vector3:
	return target_position

func is_in_cover() -> bool:
	return in_cover

func set_in_cover(value: bool) -> void:
	in_cover = value

func _on_health_changed(new_health: int, _max_health: int) -> void:
	if health_bar:
		health_bar.value = new_health

# Serialization
func serialize() -> Dictionary:
	return {
		"enemy_name": enemy_name,
		"enemy_type": enemy_type,
		"enemy_category": enemy_category,
		"health": health,
		"max_health": max_health,
		"toughness": toughness,
		"combat_skill": combat_skill,
		"movement_speed": movement_speed,
		"panic_value": panic_value,
		"behavior": behavior,
		"weapon_class": weapon_class,
		"characteristics": characteristics,
		"special_rules": special_rules,
		"position": global_position,
		"is_active": is_active,
		"in_cover": in_cover
	}

func deserialize(data: Dictionary) -> void:
	enemy_name = data.get("enemy_name", enemy_name)
	enemy_type = data.get("enemy_type", enemy_type)
	enemy_category = data.get("enemy_category", enemy_category)
	max_health = data.get("max_health", max_health)
	health = data.get("health", health)
	toughness = data.get("toughness", toughness)
	combat_skill = data.get("combat_skill", combat_skill)
	movement_speed = data.get("movement_speed", movement_speed)
	panic_value = data.get("panic_value", panic_value)
	behavior = data.get("behavior", behavior)
	weapon_class = data.get("weapon_class", weapon_class)
	characteristics = data.get("characteristics", characteristics)
	special_rules = data.get("special_rules", special_rules)
	global_position = data.get("position", global_position)
	is_active = data.get("is_active", is_active)
	in_cover = data.get("in_cover", in_cover)
	
	if not current_weapon:
		setup_default_weapon() 