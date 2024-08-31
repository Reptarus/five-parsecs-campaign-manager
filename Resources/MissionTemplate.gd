class_name MissionTemplate
extends Resource

enum MissionType {
	OPPORTUNITY,
	PATRON,
	QUEST,
	RIVAL
}

enum Objective {
	MOVE_THROUGH,
	DELIVER,
	ACCESS,
	PATROL,
	FIGHT_OFF,
	SEARCH,
	DEFEND,
	ACQUIRE,
	ELIMINATE,
	SECURE,
	PROTECT
}

@export var type: MissionType
@export var title_templates: Array[String]
@export var description_templates: Array[String]
@export var objective: Objective
@export var objective_description: String
@export var reward_range: Vector2
@export var difficulty_range: Vector2
@export var required_skills: Array[String]
@export var enemy_types: Array[String]
@export var deployment_condition_chance: float
@export var notable_sight_chance: float

func _init(
	_type: MissionType = MissionType.OPPORTUNITY,
	_title_templates: Array[String] = [],
	_description_templates: Array[String] = [],
	_objective: Objective = Objective.FIGHT_OFF,
	_objective_description: String = "",
	_reward_range: Vector2 = Vector2(1, 6),
	_difficulty_range: Vector2 = Vector2(1, 5),
	_required_skills: Array[String] = [],
	_enemy_types: Array[String] = [],
	_deployment_condition_chance: float = 0.4,
	_notable_sight_chance: float = 0.2
):
	type = _type
	title_templates = _title_templates
	description_templates = _description_templates
	objective = _objective
	objective_description = _objective_description
	reward_range = _reward_range
	difficulty_range = _difficulty_range
	required_skills = _required_skills
	enemy_types = _enemy_types
	deployment_condition_chance = _deployment_condition_chance
	notable_sight_chance = _notable_sight_chance

static func create_opportunity_mission() -> MissionTemplate:
	return MissionTemplate.new(
		MissionType.OPPORTUNITY,
		[
			"Local Trouble",
			"Quick Cash",
			"Unexpected Opportunity",
			"Starport Scuffle",
			"Frontier Justice"
		],
		[
			"A local dispute has escalated, and someone's willing to pay for outside help.",
			"A desperate individual offers a job that seems too good to be true.",
			"Word on the street is that there's easy money to be made for those willing to get their hands dirty.",
			"Tensions are high at the starport, and credits are on the line for those who can handle the heat.",
			"The frontier's calling for some old-fashioned problem-solving, and you're just the crew for the job."
		],
		Objective.FIGHT_OFF,
		"Drive off the opposing force and hold your ground.",
		Vector2(1, 6),
		Vector2(1, 5),
		["combat", "negotiation"],
		["Gangers", "Cultists", "Mercenaries", "Security Forces"],
		0.4,
		0.2
	)

static func create_patron_mission() -> MissionTemplate:
	return MissionTemplate.new(
		MissionType.PATRON,
		[
			"Corporate Interests",
			"Government Contract",
			"Private Matter",
			"Off-the-Books Operation",
			"Delicate Situation"
		],
		[
			"A powerful corporation needs a problem solved discreetly and efficiently.",
			"The local government is offering a lucrative contract for those with the right skills.",
			"A wealthy individual seeks your services for a sensitive personal matter.",
			"An anonymous patron offers a job that requires absolute secrecy.",
			"A complex situation requires a delicate touch and a willingness to get your hands dirty."
		],
		Objective.DELIVER,
		"Safely deliver the package to the designated location.",
		Vector2(3, 8),
		Vector2(2, 6),
		["stealth", "combat", "tech"],
		["Corporate Security", "Government Agents", "Rival Operatives"],
		0.6,
		0.4
	)

static func create_quest_mission() -> MissionTemplate:
	return MissionTemplate.new(
		MissionType.QUEST,
		[
			"The Ancient Artifact",
			"Echoes of the Past",
			"Uncharted Territories",
			"The Hidden Truth",
			"Legacy of the Precursors"
		],
		[
			"An ancient artifact of immense power has been discovered, and multiple factions are vying for control.",
			"Mysterious signals from a long-lost expedition have surfaced, leading to a dangerous rescue mission.",
			"Uncharted space holds the promise of riches and glory for those brave enough to explore.",
			"A conspiracy threatens the stability of the sector, and only you can uncover the truth.",
			"Remnants of an advanced alien civilization have been found, holding secrets that could change everything."
		],
		Objective.SEARCH,
		"Search the area for clues or artifacts related to the quest.",
		Vector2(5, 10),
		Vector2(3, 7),
		["exploration", "combat", "tech", "negotiation"],
		["Ancient Guardians", "Rival Explorers", "Alien Entities"],
		0.8,
		0.6
	)

static func create_rival_mission() -> MissionTemplate:
	return MissionTemplate.new(
		MissionType.RIVAL,
		[
			"Old Scores",
			"Revenge Served Cold",
			"The Double-Cross",
			"Turf War",
			"Family Feud"
		],
		[
			"An old enemy has resurfaced, seeking to settle a long-standing grudge.",
			"Your past actions have come back to haunt you as a rival seeks revenge.",
			"A supposed ally reveals their true colors, forcing a confrontation.",
			"Rival factions clash over control of valuable territory or resources.",
			"A bitter family dispute erupts into open conflict, dragging you into the fray."
		],
		Objective.ELIMINATE,
		"Defeat your rival and their forces to assert your dominance.",
		Vector2(2, 7),
		Vector2(3, 8),
		["combat", "tactics"],
		["Rival Crew", "Criminal Syndicate", "Vengeful Ex-Allies"],
		0.5,
		0.3
	)
