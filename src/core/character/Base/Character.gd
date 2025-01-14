class_name Character
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal status_changed(new_status: GameEnums.CharacterStatus)
signal level_up(new_level: int)
signal xp_gained(amount: int)
signal equipment_changed(slot: String, item: Resource)

@export var character_name: String = ""
@export var level: int = 1
@export var xp: int = 0
@export var status: GameEnums.CharacterStatus = GameEnums.CharacterStatus.HEALTHY
@export var origin: GameEnums.Origin = GameEnums.Origin.HUMAN
@export var character_class: GameEnums.CharacterClass = GameEnums.CharacterClass.SOLDIER
@export var background: GameEnums.CharacterBackground = GameEnums.CharacterBackground.NONE
@export var motivation: GameEnums.CharacterMotivation = GameEnums.CharacterMotivation.NONE

# Stats
@export var health: int = 100
@export var max_health: int = 100
@export var armor: int = 0
@export var speed: int = 6
@export var accuracy: int = 70
@export var evasion: int = 30

# Equipment slots
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"gear": []
}

# Combat state
var combat_modifiers: Array[GameEnums.CombatModifier] = []
var current_action: GameEnums.UnitAction = GameEnums.UnitAction.NONE
var action_points: int = 2
var max_action_points: int = 2

func _init() -> void:
	_initialize_character()

func take_damage(amount: int) -> void:
	var actual_damage = max(0, amount - armor)
	health = max(0, health - actual_damage)
	_update_status()

func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	_update_status()

func gain_xp(amount: int) -> void:
	xp += amount
	xp_gained.emit(amount)
	_check_level_up()

func equip_item(item: Resource, slot: String) -> void:
	if _can_equip_item(item, slot):
		_unequip_slot(slot)
		equipment[slot] = item
		_apply_equipment_stats(item)
		equipment_changed.emit(slot, item)

func unequip_item(slot: String) -> void:
	if slot in equipment:
		var item = equipment[slot]
		_unequip_slot(slot)
		equipment_changed.emit(slot, null)

func add_combat_modifier(modifier: GameEnums.CombatModifier) -> void:
	if not modifier in combat_modifiers:
		combat_modifiers.append(modifier)

func remove_combat_modifier(modifier: GameEnums.CombatModifier) -> void:
	combat_modifiers.erase(modifier)

func start_turn() -> void:
	action_points = max_action_points
	current_action = GameEnums.UnitAction.NONE

func end_turn() -> void:
	action_points = 0
	current_action = GameEnums.UnitAction.NONE

func can_perform_action(action: GameEnums.UnitAction) -> bool:
	if action_points <= 0:
		return false
	
	match action:
		GameEnums.UnitAction.MOVE:
			return action_points >= 1
		GameEnums.UnitAction.ATTACK:
			return action_points >= 1 and equipment.weapon != null
		GameEnums.UnitAction.DASH:
			return action_points >= 2
		GameEnums.UnitAction.ITEMS:
			return action_points >= 1 and not equipment.gear.is_empty()
		GameEnums.UnitAction.BRAWL:
			return action_points >= 1
		GameEnums.UnitAction.SNAP_FIRE:
			return action_points >= 1 and equipment.weapon != null
		GameEnums.UnitAction.OVERWATCH:
			return action_points >= 2 and equipment.weapon != null
		GameEnums.UnitAction.TAKE_COVER:
			return action_points >= 1
		GameEnums.UnitAction.RELOAD:
			return action_points >= 1 and equipment.weapon != null
		GameEnums.UnitAction.INTERACT:
			return action_points >= 1
		_:
			return false

func perform_action(action: GameEnums.UnitAction) -> void:
	if can_perform_action(action):
		current_action = action
		match action:
			GameEnums.UnitAction.MOVE, GameEnums.UnitAction.ATTACK, \
			GameEnums.UnitAction.ITEMS, GameEnums.UnitAction.BRAWL, \
			GameEnums.UnitAction.SNAP_FIRE, GameEnums.UnitAction.TAKE_COVER, \
			GameEnums.UnitAction.RELOAD, GameEnums.UnitAction.INTERACT:
				action_points -= 1
			GameEnums.UnitAction.DASH, GameEnums.UnitAction.OVERWATCH:
				action_points -= 2

func _initialize_character() -> void:
	health = max_health
	action_points = max_action_points
	combat_modifiers.clear()
	current_action = GameEnums.UnitAction.NONE

func _update_status() -> void:
	var new_status: GameEnums.CharacterStatus
	var health_percent := float(health) / float(max_health)
	
	if health <= 0:
		new_status = GameEnums.CharacterStatus.DEAD
	elif health_percent <= 0.25:
		new_status = GameEnums.CharacterStatus.CRITICAL
	elif health_percent <= 0.5:
		new_status = GameEnums.CharacterStatus.INJURED
	else:
		new_status = GameEnums.CharacterStatus.HEALTHY
	
	if new_status != status:
		status = new_status
		status_changed.emit(new_status)

func _check_level_up() -> void:
	var xp_needed := level * 100
	if xp >= xp_needed:
		level += 1
		xp -= xp_needed
		level_up.emit(level)
		_apply_level_up_bonuses()

func _apply_level_up_bonuses() -> void:
	max_health += 10
	health = max_health
	accuracy += 2
	evasion += 1

func _can_equip_item(item: Resource, slot: String) -> bool:
	if not slot in equipment:
		return false
	
	# Add specific equipment type checks here
	return true

func _unequip_slot(slot: String) -> void:
	if slot in equipment:
		var item = equipment[slot]
		if item:
			_remove_equipment_stats(item)
		equipment[slot] = null

func _apply_equipment_stats(item: Resource) -> void:
	# Add equipment stat application logic here
	pass

func _remove_equipment_stats(item: Resource) -> void:
	# Add equipment stat removal logic here
	pass
