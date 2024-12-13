@tool
class_name Enemy
extends CharacterBody2D

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const GameWeapon = preload("res://Resources/Core/Items/Weapons/Weapon.gd")

@export var enemy_name: String = "Enemy"
@export var health: int = 100
@export var max_health: int = 100
@export var movement_speed: float = 100.0
@export var attack_range: float = 5.0
@export var damage: int = 10

@onready var health_bar = $HealthBar
@onready var weapon_system = $WeaponSystem

var current_weapon: GameWeapon

func _ready() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	setup_default_weapon()

func setup_default_weapon() -> void:
	current_weapon = GameWeapon.new()
	current_weapon.name = "Enemy Weapon"
	current_weapon.weapon_type = GameEnums.WeaponType.RIFLE
	current_weapon.range = int(attack_range)
	current_weapon.damage = damage

func take_damage(amount: int) -> void:
	health = clampi(health - amount, 0, max_health)
	if health_bar:
		health_bar.value = health
	if health <= 0:
		die()

func die() -> void:
	queue_free()

func get_attack_range() -> float:
	return attack_range

func get_movement_range() -> float:
	return movement_speed

func get_weapon() -> GameWeapon:
	return current_weapon 