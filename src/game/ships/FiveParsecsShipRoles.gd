extends Resource
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/game/ships/FiveParsecsShipRoles.gd")

# Preloads
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CharacterManager = preload("res://src/core/character/management/CharacterManager.gd")

# Signals
signal role_assigned(character_id: String, role: int)
signal role_unassigned(character_id: String, role: int)
signal role_benefits_applied(character_id: String, role: int)

# Ship Role enum - these are the roles available on a ship according to Five Parsecs rulebook
enum ShipRole {
	NONE = 0,
	CAPTAIN = 1,
	PILOT = 2,
	ENGINEER = 3,
	MEDIC = 4,
	GUNNER = 5,
	NAVIGATOR = 6,
	MECHANIC = 7,
	COMMS_OFFICER = 8
}

# Role requirements - skills needed for optimal performance
var role_requirements = {
	ShipRole.CAPTAIN: {
		"preferred_skills": ["Leadership", "Tactics"],
		"bonus_modifier": 1
	},
	ShipRole.PILOT: {
		"preferred_skills": ["Pilot", "Reactions"],
		"bonus_modifier": 1
	},
	ShipRole.ENGINEER: {
		"preferred_skills": ["Tech", "Reactions"],
		"bonus_modifier": 1
	},
	ShipRole.MEDIC: {
		"preferred_skills": ["Medical", "Science"],
		"bonus_modifier": 1
	},
	ShipRole.GUNNER: {
		"preferred_skills": ["Reactions", "Combat"],
		"bonus_modifier": 1
	},
	ShipRole.NAVIGATOR: {
		"preferred_skills": ["Science", "Pilot"],
		"bonus_modifier": 1
	},
	ShipRole.MECHANIC: {
		"preferred_skills": ["Tech", "Savvy"],
		"bonus_modifier": 1
	},
	ShipRole.COMMS_OFFICER: {
		"preferred_skills": ["Science", "Savvy"],
		"bonus_modifier": 1
	}
}

# Stores character ID -> role assignments
var _assigned_roles = {}
# Stores role -> character ID assignments (for quick lookups)
var _role_assignments = {}

# Character manager reference (will be set in setup)
var _character_manager = null

# Setup function to connect with character manager
func setup(character_manager) -> void:
	_character_manager = character_manager
	if _character_manager:
		# Connect to character signals
		_character_manager.character_deleted.connect(_on_character_deleted)

# Assigns a character to a ship role
func assign_role(character_id: String, role: ShipRole) -> bool:
	if not _character_manager:
		push_error("Character manager not set up")
		return false
		
	# Validate character exists
	var character = _character_manager.get_character(character_id)
	if not character:
		push_error("Character not found: " + character_id)
		return false
		
	# If the character is already assigned to another role, unassign them
	if character_id in _assigned_roles:
		unassign_role(character_id)
		
	# If the role is already assigned, unassign the previous character
	if role in _role_assignments:
		var previous_character_id = _role_assignments[role]
		if previous_character_id != character_id:
			unassign_role(previous_character_id)
	
	# Assign the role
	_assigned_roles[character_id] = role
	_role_assignments[role] = character_id
	
	# Emit signal
	role_assigned.emit(character_id, role)
	
	return true

# Unassigns a character from their ship role
func unassign_role(character_id: String) -> bool:
	if not character_id in _assigned_roles:
		return false
		
	var role = _assigned_roles[character_id]
	
	# Remove assignments
	_assigned_roles.erase(character_id)
	if _role_assignments.has(role) and _role_assignments[role] == character_id:
		_role_assignments.erase(role)
	
	# Emit signal
	role_unassigned.emit(character_id, role)
	
	return true

# Gets the role assigned to a character
func get_character_role(character_id: String) -> int:
	return _assigned_roles.get(character_id, ShipRole.NONE)

# Gets the character assigned to a role
func get_role_assignment(role: ShipRole) -> String:
	return _role_assignments.get(role, "")

# Checks if a character is a good fit for a role
func is_good_fit_for_role(character_id: String, role: ShipRole) -> bool:
	if not _character_manager:
		return false
		
	var character = _character_manager.get_character(character_id)
	if not character:
		return false
		
	if not role in role_requirements:
		return false
		
	var requirements = role_requirements[role]
	var preferred_skills = requirements.get("preferred_skills", [])
	
	# Check if character has any of the preferred skills
	for skill in preferred_skills:
		if character.has_skill(skill):
			return true
			
	return false

# Apply role benefits to assigned character
func apply_role_benefits(character_id: String) -> bool:
	if not character_id in _assigned_roles:
		return false
		
	var role = _assigned_roles[character_id]
	if not role in role_requirements:
		return false
	
	var benefits_applied = false
	
	# Apply appropriate benefits based on role
	match role:
		ShipRole.CAPTAIN:
			# Captain adds +1 to crew morale checks
			benefits_applied = true
		ShipRole.PILOT:
			# Pilot improves ship maneuverability
			benefits_applied = true
		ShipRole.ENGINEER:
			# Engineer provides better fuel efficiency
			benefits_applied = true
		ShipRole.MEDIC:
			# Medic speeds up recovery from injuries
			benefits_applied = true
		ShipRole.GUNNER:
			# Gunner improves weapon accuracy
			benefits_applied = true
		# Add additional role benefits as needed
	
	if benefits_applied:
		role_benefits_applied.emit(character_id, role)
		
	return benefits_applied

# Calculate effectiveness of a character in their role
func calculate_role_effectiveness(character_id: String) -> float:
	if not character_id in _assigned_roles:
		return 0.0
		
	if not _character_manager:
		return 0.0
		
	var character = _character_manager.get_character(character_id)
	if not character:
		return 0.0
		
	var role = _assigned_roles[character_id]
	if not role in role_requirements:
		return 0.0
		
	var requirements = role_requirements[role]
	var preferred_skills = requirements.get("preferred_skills", [])
	var bonus_modifier = requirements.get("bonus_modifier", 1)
	
	var base_effectiveness = 0.5 # Base 50% effectiveness
	
	# Add bonus for each preferred skill the character has
	for skill in preferred_skills:
		if character.has_skill(skill):
			base_effectiveness += 0.25 * bonus_modifier
			
	# Cap at maximum effectiveness
	return minf(1.0, base_effectiveness)

# Process ship role effects for travel
func process_travel_effects(fuel_consumption: int) -> int:
	var modified_consumption = fuel_consumption
	
	# Engineer reduces fuel consumption
	if ShipRole.ENGINEER in _role_assignments:
		var engineer_id = _role_assignments[ShipRole.ENGINEER]
		var effectiveness = calculate_role_effectiveness(engineer_id)
		
		# Reduce fuel consumption based on effectiveness (up to 25%)
		var reduction = int(fuel_consumption * 0.25 * effectiveness)
		modified_consumption = max(1, fuel_consumption - reduction)
	
	# Navigator can find shortcuts
	if ShipRole.NAVIGATOR in _role_assignments:
		var navigator_id = _role_assignments[ShipRole.NAVIGATOR]
		var effectiveness = calculate_role_effectiveness(navigator_id)
		
		# Small chance to reduce travel time/fuel based on effectiveness
		if randf() < 0.2 * effectiveness:
			modified_consumption = max(1, modified_consumption - 1)
	
	return modified_consumption

# Process ship role effects for battle
func process_battle_effects() -> Dictionary:
	var effects = {
		"morale_bonus": 0,
		"repair_bonus": 0,
		"medical_bonus": 0,
		"accuracy_bonus": 0
	}
	
	# Captain provides morale bonus
	if ShipRole.CAPTAIN in _role_assignments:
		var captain_id = _role_assignments[ShipRole.CAPTAIN]
		var effectiveness = calculate_role_effectiveness(captain_id)
		effects.morale_bonus = int(effectiveness * 2) # Up to +2
	
	# Mechanic provides repair bonus
	if ShipRole.MECHANIC in _role_assignments:
		var mechanic_id = _role_assignments[ShipRole.MECHANIC]
		var effectiveness = calculate_role_effectiveness(mechanic_id)
		effects.repair_bonus = int(effectiveness * 2) # Up to +2
	
	# Medic provides medical bonus
	if ShipRole.MEDIC in _role_assignments:
		var medic_id = _role_assignments[ShipRole.MEDIC]
		var effectiveness = calculate_role_effectiveness(medic_id)
		effects.medical_bonus = int(effectiveness * 2) # Up to +2
	
	# Gunner provides accuracy bonus
	if ShipRole.GUNNER in _role_assignments:
		var gunner_id = _role_assignments[ShipRole.GUNNER]
		var effectiveness = calculate_role_effectiveness(gunner_id)
		effects.accuracy_bonus = int(effectiveness * 2) # Up to +2
	
	return effects

# Handle character deletion
func _on_character_deleted(character_id: String) -> void:
	if character_id in _assigned_roles:
		unassign_role(character_id)

# Serialize ship roles for saving
func serialize() -> Dictionary:
	var data = {
		"assigned_roles": {},
	}
	
	# Convert int keys to strings for JSON compatibility
	for character_id in _assigned_roles:
		data.assigned_roles[character_id] = _assigned_roles[character_id]
	
	return data

# Deserialize ship roles when loading
func deserialize(data: Dictionary) -> void:
	_assigned_roles.clear()
	_role_assignments.clear()
	
	if not data.has("assigned_roles"):
		return
		
	# Restore role assignments
	for character_id in data.assigned_roles:
		var role = data.assigned_roles[character_id]
		_assigned_roles[character_id] = role
		_role_assignments[role] = character_id