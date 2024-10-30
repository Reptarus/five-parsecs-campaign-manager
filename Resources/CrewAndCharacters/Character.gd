class_name Character
extends Resource

signal morale_changed(new_value: int)
signal experience_gained(amount: int)
signal status_changed(new_status: int)

@export var name: String = ""
@export var role: GlobalEnums.CrewRole
@export var traits: Array[String] = []
@export var skills: Dictionary = {}
@export var experience: int = 0
@export var morale: int = 5
@export var equipment: Array[Equipment] = []
@export var status_effects: Array[String] = []
@export var status: GlobalEnums.CharacterStatus = GlobalEnums.CharacterStatus.READY

var mission_ready: bool = true
var current_task: String = ""

func can_participate_in_mission(mission: Mission) -> bool:
	if not mission_ready or status != GlobalEnums.CharacterStatus.READY:
		return false
	
	# Check if character's role is required for the mission
	if mission.required_roles.has(role):
		return true
	
	# Check if character has required skills
	for skill in mission.required_skills:
		if not skills.has(skill) or skills[skill] < mission.required_skills[skill]:
			return false
	
	# Check if character has required equipment for mission type
	if mission.mission_type == GlobalEnums.Type.RED_ZONE and not has_hazard_gear():
		return false
	
	return true

func decrease_morale() -> void:
	morale = max(0, morale - 1)
	morale_changed.emit(morale)

func gain_experience(amount: int) -> void:
	experience += amount
	experience_gained.emit(amount)

func has_trait(trait_name: String) -> bool:
	return traits.has(trait_name)

func get_skill_level(skill_name: String) -> int:
	return skills.get(skill_name, 0)

func has_hazard_gear() -> bool:
	for item in equipment:
		if item.type == GlobalEnums.EquipmentType.HAZARD_GEAR:
			return true
	return false

func set_status(new_status: GlobalEnums.CharacterStatus) -> void:
	status = new_status
	status_changed.emit(status)
	mission_ready = (status == GlobalEnums.CharacterStatus.READY)

func roll_injury() -> String:
	var injury_table = ["Minor Cuts", "Broken Arm", "Concussion", "Severe Burns"]
	return injury_table.pick_random()

func apply_upgrade(upgrade: Dictionary) -> void:
	if upgrade.has("skill"):
		skills[upgrade.skill] = skills.get(upgrade.skill, 0) + 1
	if upgrade.has("trait"):
		if not traits.has(upgrade.trait):
			traits.append(upgrade.trait)
