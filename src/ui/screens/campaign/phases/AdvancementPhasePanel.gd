extends BasePhasePanel
class_name AdvancementPhasePanel

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

@onready var crew_list = $VBoxContainer/CrewList
@onready var advancement_options = $VBoxContainer/AdvancementOptions
@onready var character_info = $VBoxContainer/CharacterInfo
@onready var apply_button = $VBoxContainer/ApplyButton

var selected_crew_member: Character
var available_advancements: Array = []
var selected_advancement: Dictionary = {}
var advancement_costs: Dictionary = {
	"STAT": 100,
	"SKILL": 150,
	"ABILITY": 200,
	"TRAIT": 250
}

func _ready() -> void:
	super._ready()
	_connect_signals()

func _connect_signals() -> void:
	crew_list.item_selected.connect(_on_crew_selected)
	advancement_options.item_selected.connect(_on_advancement_selected)
	apply_button.pressed.connect(_on_apply_pressed)

func setup_phase() -> void:
	super.setup_phase()
	_load_crew()
	_update_ui()

func _load_crew() -> void:
	crew_list.clear()
	for member in game_state.campaign.crew_members:
		var text = "%s (Level %d)" % [member.character_name, member.level]
		if member.experience >= member.get_experience_for_next_level():
			text += " - LEVEL UP AVAILABLE"
		crew_list.add_item(text)

func _update_ui() -> void:
	if not selected_crew_member:
		character_info.text = "Select a crew member"
		advancement_options.clear()
		apply_button.disabled = true
		return
	
	_update_character_info()
	_update_advancement_options()

func _update_character_info() -> void:
	var info = "[b]%s[/b]\n" % selected_crew_member.character_name
	info += "Class: %s\n" % GameEnums.get_character_class_name(selected_crew_member.character_class)
	info += "Level: %d\n" % selected_crew_member.level
	info += "Experience: %d/%d\n" % [
		selected_crew_member.experience,
		selected_crew_member.get_experience_for_next_level()
	]
	
	info += "\n[b]Stats:[/b]\n"
	info += "Health: %d/%d\n" % [selected_crew_member.health, selected_crew_member.max_health]
	info += "Reaction: %d\n" % selected_crew_member.reaction
	info += "Combat: %d\n" % selected_crew_member.combat
	info += "Toughness: %d\n" % selected_crew_member.toughness
	info += "Savvy: %d\n" % selected_crew_member.savvy
	
	info += "\n[b]Skills:[/b]\n"
	if selected_crew_member.skills.is_empty():
		info += "None\n"
	else:
		for skill in selected_crew_member.skills:
			info += "• %s\n" % GameEnums.get_skill_name(skill)
	
	info += "\n[b]Abilities:[/b]\n"
	if selected_crew_member.abilities.is_empty():
		info += "None\n"
	else:
		for ability in selected_crew_member.abilities:
			info += "• %s\n" % GameEnums.get_ability_name(ability)
	
	info += "\n[b]Traits:[/b]\n"
	if selected_crew_member.traits.is_empty():
		info += "None\n"
	else:
		for trait in selected_crew_member.traits:
			info += "• %s\n" % GameEnums.get_trait_name(trait )
	
	character_info.text = info

func _update_advancement_options() -> void:
	advancement_options.clear()
	available_advancements = _get_available_advancements()
	
	for advancement in available_advancements:
		var text = advancement.name
		text += " (%d credits)" % advancement.cost
		advancement_options.add_item(text)
		
		if not _can_apply_advancement(advancement):
			var idx = advancement_options.item_count - 1
			advancement_options.set_item_disabled(idx, true)
			advancement_options.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
			advancement_options.set_item_tooltip(idx, _get_requirement_tooltip(advancement))

func _get_available_advancements() -> Array:
	var advancements = []
	
	# Add stat improvements
	advancements.append_array([
		{
			"name": "Increase Reaction",
			"type": "STAT",
			"stat": "reaction",
			"amount": 1,
			"cost": advancement_costs.STAT,
			"requirements": {"min_level": 2}
		},
		{
			"name": "Increase Combat",
			"type": "STAT",
			"stat": "combat",
			"amount": 1,
			"cost": advancement_costs.STAT,
			"requirements": {"min_level": 2}
		},
		{
			"name": "Increase Toughness",
			"type": "STAT",
			"stat": "toughness",
			"amount": 1,
			"cost": advancement_costs.STAT,
			"requirements": {"min_level": 2}
		},
		{
			"name": "Increase Savvy",
			"type": "STAT",
			"stat": "savvy",
			"amount": 1,
			"cost": advancement_costs.STAT,
			"requirements": {"min_level": 2}
		}
	])
	
	# Add class-specific skills
	match selected_crew_member.character_class:
		GameEnums.CharacterClass.SOLDIER:
			advancements.append_array(_get_soldier_advancements())
		GameEnums.CharacterClass.MEDIC:
			advancements.append_array(_get_medic_advancements())
		GameEnums.CharacterClass.SCOUT:
			advancements.append_array(_get_scout_advancements())
		GameEnums.CharacterClass.TECH:
			advancements.append_array(_get_tech_advancements())
		GameEnums.CharacterClass.PSYKER:
			advancements.append_array(_get_psyker_advancements())
	
	# Add general traits based on background
	advancements.append_array(_get_background_traits())
	
	return advancements

func _get_soldier_advancements() -> Array:
	return [
		{
			"name": "Combat Training",
			"type": "SKILL",
			"skill": GameEnums.Skill.COMBAT_TRAINING,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 3}
		},
		{
			"name": "Heavy Weapons",
			"type": "SKILL",
			"skill": GameEnums.Skill.HEAVY_WEAPONS,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 4}
		},
		{
			"name": "Battle Hardened",
			"type": "ABILITY",
			"ability": GameEnums.Ability.BATTLE_HARDENED,
			"cost": advancement_costs.ABILITY,
			"requirements": {"min_level": 5}
		}
	]

func _get_medic_advancements() -> Array:
	return [
		{
			"name": "Field Medicine",
			"type": "SKILL",
			"skill": GameEnums.Skill.FIELD_MEDICINE,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 3}
		},
		{
			"name": "Combat Medic",
			"type": "SKILL",
			"skill": GameEnums.Skill.COMBAT_MEDIC,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 4}
		},
		{
			"name": "Miracle Worker",
			"type": "ABILITY",
			"ability": GameEnums.Ability.MIRACLE_WORKER,
			"cost": advancement_costs.ABILITY,
			"requirements": {"min_level": 5}
		}
	]

func _get_scout_advancements() -> Array:
	return [
		{
			"name": "Stealth",
			"type": "SKILL",
			"skill": GameEnums.Skill.STEALTH,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 3}
		},
		{
			"name": "Survival",
			"type": "SKILL",
			"skill": GameEnums.Skill.SURVIVAL,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 4}
		},
		{
			"name": "Ghost",
			"type": "ABILITY",
			"ability": GameEnums.Ability.GHOST,
			"cost": advancement_costs.ABILITY,
			"requirements": {"min_level": 5}
		}
	]

func _get_tech_advancements() -> Array:
	return [
		{
			"name": "Tech Repair",
			"type": "SKILL",
			"skill": GameEnums.Skill.TECH_REPAIR,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 3}
		},
		{
			"name": "Hacking",
			"type": "SKILL",
			"skill": GameEnums.Skill.HACKING,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 4}
		},
		{
			"name": "Tech Master",
			"type": "ABILITY",
			"ability": GameEnums.Ability.TECH_MASTER,
			"cost": advancement_costs.ABILITY,
			"requirements": {"min_level": 5}
		}
	]

func _get_psyker_advancements() -> Array:
	return [
		{
			"name": "Psychic Focus",
			"type": "SKILL",
			"skill": GameEnums.Skill.PSYCHIC_FOCUS,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 3}
		},
		{
			"name": "Mind Control",
			"type": "SKILL",
			"skill": GameEnums.Skill.MIND_CONTROL,
			"cost": advancement_costs.SKILL,
			"requirements": {"min_level": 4}
		},
		{
			"name": "Psychic Master",
			"type": "ABILITY",
			"ability": GameEnums.Ability.PSYCHIC_MASTER,
			"cost": advancement_costs.ABILITY,
			"requirements": {"min_level": 5}
		}
	]

func _get_background_traits() -> Array:
	var traits = []
	
	match selected_crew_member.background:
		GameEnums.Background.MILITARY:
			traits.append({
				"name": "Tactical Mind",
				"type": "TRAIT",
				"trait": GameEnums.Trait.TACTICAL_MIND,
				"cost": advancement_costs.TRAIT,
				"requirements": {"min_level": 4}
			})
		GameEnums.Background.CRIMINAL:
			traits.append({
				"name": "Street Smart",
				"type": "TRAIT",
				"trait": GameEnums.Trait.STREET_SMART,
				"cost": advancement_costs.TRAIT,
				"requirements": {"min_level": 4}
			})
		GameEnums.Background.ACADEMIC:
			traits.append({
				"name": "Quick Learner",
				"type": "TRAIT",
				"trait": GameEnums.Trait.QUICK_LEARNER,
				"cost": advancement_costs.TRAIT,
				"requirements": {"min_level": 4}
			})
	
	return traits

func _can_apply_advancement(advancement: Dictionary) -> bool:
	if not advancement.has("requirements"):
		return true
	
	var reqs = advancement.requirements
	if reqs.has("min_level") and selected_crew_member.level < reqs.min_level:
		return false
	
	if advancement.cost > game_state.campaign.credits:
		return false
	
	match advancement.type:
		"SKILL":
			if selected_crew_member.has_skill(advancement.skill):
				return false
		"ABILITY":
			if selected_crew_member.has_ability(advancement.ability):
				return false
		"TRAIT":
			if selected_crew_member.has_trait(advancement.trait):
				return false
	
	return true

func _get_requirement_tooltip(advancement: Dictionary) -> String:
	var reasons = []
	
	if advancement.cost > game_state.campaign.credits:
		reasons.append("Not enough credits")
	
	if advancement.has("requirements"):
		var reqs = advancement.requirements
		if reqs.has("min_level") and selected_crew_member.level < reqs.min_level:
			reasons.append("Requires level %d" % reqs.min_level)
	
	match advancement.type:
		"SKILL":
			if selected_crew_member.has_skill(advancement.skill):
				reasons.append("Already has this skill")
		"ABILITY":
			if selected_crew_member.has_ability(advancement.ability):
				reasons.append("Already has this ability")
		"TRAIT":
			if selected_crew_member.has_trait(advancement.trait):
				reasons.append("Already has this trait")
	
	return reasons.join("\n")

func _on_crew_selected(index: int) -> void:
	selected_crew_member = game_state.campaign.crew_members[index]
	selected_advancement = {}
	_update_ui()

func _on_advancement_selected(index: int) -> void:
	selected_advancement = available_advancements[index]
	apply_button.disabled = not _can_apply_advancement(selected_advancement)

func _on_apply_pressed() -> void:
	if not selected_crew_member or selected_advancement.is_empty():
		return
	
	if not _can_apply_advancement(selected_advancement):
		return
	
	_apply_advancement()
	_update_ui()
	
	# Check if we can complete the phase
	if _check_all_advancements_complete():
		complete_phase()

func _apply_advancement() -> void:
	match selected_advancement.type:
		"STAT":
			match selected_advancement.stat:
				"reaction":
					selected_crew_member.reaction += selected_advancement.amount
				"combat":
					selected_crew_member.combat += selected_advancement.amount
				"toughness":
					selected_crew_member.toughness += selected_advancement.amount
				"savvy":
					selected_crew_member.savvy += selected_advancement.amount
		"SKILL":
			selected_crew_member.add_skill(selected_advancement.skill)
		"ABILITY":
			selected_crew_member.add_ability(selected_advancement.ability)
		"TRAIT":
			selected_crew_member.add_trait(selected_advancement.trait)
	
	game_state.campaign.credits -= selected_advancement.cost
	selected_crew_member.add_experience(50) # Bonus XP for advancement
	
	# Clear selection
	selected_advancement = {}
	apply_button.disabled = true

func _check_all_advancements_complete() -> bool:
	for member in game_state.campaign.crew_members:
		# Check if any crew member has enough XP to level up
		if member.experience >= member.get_experience_for_next_level():
			return false
		
		# Check if any crew member has available advancements they can afford
		for advancement in _get_available_advancements():
			if _can_apply_advancement(advancement):
				return false
	
	return true

func validate_phase_requirements() -> bool:
	if not game_state or not game_state.campaign:
		return false
	
	if not game_state.campaign.crew_members or game_state.campaign.crew_members.is_empty():
		return false
	
	return true