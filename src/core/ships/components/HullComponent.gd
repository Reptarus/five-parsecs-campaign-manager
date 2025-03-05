# Scripts/ShipAndCrew/HullComponent.gd
@tool
extends FPCM_ShipComponent
class_name HullComponent

@export var hull_durability: int = 100
@export var armor: int = 5
@export var shield_strength: int = 0
@export var shield_recharge_rate: float = 0.0
@export var has_shields: bool = false
@export var current_shield: int = 0
@export var has_emergency_bulkheads: bool = false
@export var breach_resistance: float = 0.5

func _init() -> void:
	super()
	name = "Hull"
	description = "Basic hull structure"
	cost = 400
	power_draw = 1
	
func _apply_upgrade_effects() -> void:
	super()
	hull_durability += 25
	armor += 2
	if has_shields:
		shield_strength += 10
		shield_recharge_rate += 0.2
	breach_resistance += 0.1

func get_damage_reduction(damage_type: int = 0) -> float:
	var reduction = armor * 0.1 * get_efficiency()
	
	# Different damage types could have different effectiveness against armor
	match damage_type:
		1: # Energy weapons - less effective against armor
			reduction *= 0.8
		2: # Kinetic weapons - standard
			pass
		3: # Explosive - more effective against armor
			reduction *= 0.6
	
	return reduction

func damage_hull(amount: int, damage_type: int = 0) -> int:
	var damage_reduction = get_damage_reduction(damage_type)
	var actual_damage = max(0, amount - damage_reduction)
	
	# Apply damage to the ship component
	damage(actual_damage)
	
	# Check for breach
	if actual_damage > 0 and randf() > breach_resistance:
		_trigger_hull_breach()
	
	return actual_damage

func damage_shield(amount: int) -> int:
	if not has_shields or current_shield <= 0:
		return 0
		
	var before = current_shield
	current_shield = max(0, current_shield - amount)
	
	return before - current_shield

# Process shield recharge
func process_shields(delta: float) -> void:
	if has_shields and current_shield < shield_strength and is_active:
		var recharge = shield_recharge_rate * delta * get_efficiency()
		current_shield = min(shield_strength, current_shield + recharge)

func _trigger_hull_breach() -> void:
	if has_emergency_bulkheads and randf() < breach_resistance:
		# Emergency bulkheads prevented a hull breach
		return
		
	# Hull breach effects would go here
	# Add status effects or other consequences
	var breach_effect = {
		"id": "hull_breach",
		"name": "Hull Breach",
		"duration": 3,
		"effect": "reduced_efficiency",
		"value": 0.5
	}
	add_status_effect(breach_effect)

func is_shield_active() -> bool:
	return has_shields and current_shield > 0 and is_active

func initialize_shields() -> void:
	if has_shields:
		current_shield = shield_strength

func serialize() -> Dictionary:
	var data = super()
	data["armor"] = armor
	data["shield_strength"] = shield_strength
	data["shield_recharge_rate"] = shield_recharge_rate
	data["has_shields"] = has_shields
	data["current_shield"] = current_shield
	data["has_emergency_bulkheads"] = has_emergency_bulkheads
	data["breach_resistance"] = breach_resistance
	return data

# Factory method to create HullComponent from data
static func create_from_data(data: Dictionary) -> HullComponent:
	var component = HullComponent.new()
	var base_data = FPCM_ShipComponent.deserialize(data)
	
	# Copy base data
	component.name = base_data.name
	component.description = base_data.description
	component.cost = base_data.cost
	component.level = base_data.level
	component.max_level = base_data.max_level
	component.is_active = base_data.is_active
	component.upgrade_cost = base_data.upgrade_cost
	component.maintenance_cost = base_data.maintenance_cost
	component.hull_durability = base_data.durability
	component.max_durability = base_data.max_durability
	component.efficiency = base_data.efficiency
	component.power_draw = base_data.power_draw
	component.status_effects = base_data.status_effects
	
	# Hull-specific properties
	component.armor = data.get("armor", 5)
	component.shield_strength = data.get("shield_strength", 0)
	component.shield_recharge_rate = data.get("shield_recharge_rate", 0.0)
	component.has_shields = data.get("has_shields", false)
	component.current_shield = data.get("current_shield", 0)
	component.has_emergency_bulkheads = data.get("has_emergency_bulkheads", false)
	component.breach_resistance = data.get("breach_resistance", 0.5)
	
	return component

# Return serialized data with proper hull type
static func deserialize(data: Dictionary) -> Dictionary:
	var base_data = FPCM_ShipComponent.deserialize(data)
	base_data["component_type"] = "hull"
	base_data["armor"] = data.get("armor", 5)
	base_data["shield_strength"] = data.get("shield_strength", 0)
	base_data["shield_recharge_rate"] = data.get("shield_recharge_rate", 0.0)
	base_data["has_shields"] = data.get("has_shields", false)
	base_data["current_shield"] = data.get("current_shield", 0)
	base_data["has_emergency_bulkheads"] = data.get("has_emergency_bulkheads", false)
	base_data["breach_resistance"] = data.get("breach_resistance", 0.5)
	return base_data
