class_name FPCM_VictoryDescriptions
extends Resource

## Enhanced Victory Condition Descriptions
## Includes full narratives, strategy tips, and metadata for UI display

# GlobalEnums available as autoload singleton

# Category constants
enum VictoryCategory { DURATION, COMBAT, STORY, WEALTH, CHALLENGE }

# Comprehensive victory condition data
const VICTORY_DATA: Dictionary = {
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20: {
		"name": "20 Turns",
		"short_desc": "Play 20 campaign turns",
		"full_desc": "A quick introduction to the Five Parsecs universe. Perfect for learning the game systems without a major time commitment. Your crew will face a handful of missions and start building their reputation.",
		"strategy": "Focus on survival and learning mechanics. Don't take unnecessary risks early on.",
		"category": VictoryCategory.DURATION,
		"difficulty": "Easy",
		"estimated_hours": "3-5",
		"min_value": 10,
		"max_value": 30
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50: {
		"name": "50 Turns",
		"short_desc": "Play 50 campaign turns",
		"full_desc": "A seasoned campaign where your crew will face numerous challenges. Expect to develop strong patron relationships, encounter 5-7 major story events, and see your crew evolve from desperate freelancers to experienced operatives.",
		"strategy": "Balance combat missions with downtime to keep your crew healthy. Invest in better equipment around turn 20.",
		"category": VictoryCategory.DURATION,
		"difficulty": "Medium",
		"estimated_hours": "10-15",
		"min_value": 30,
		"max_value": 75
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100: {
		"name": "100 Turns",
		"short_desc": "Play 100 campaign turns",
		"full_desc": "An epic saga spanning the galaxy. Your crew will become legends, facing countless enemies, uncovering ancient secrets, and perhaps changing the fate of entire worlds. Not for the faint of heart.",
		"strategy": "Pace yourself. Rotate crew to prevent burnout. Save credits for emergency medical expenses.",
		"category": VictoryCategory.DURATION,
		"difficulty": "Hard",
		"estimated_hours": "25-40",
		"min_value": 75,
		"max_value": 500
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20: {
		"name": "20 Battles",
		"short_desc": "Fight 20 battles",
		"full_desc": "Combat-focused campaign for those who love tactical action. Less downtime, more firefights. Your crew will be battle-hardened veterans by the end.",
		"strategy": "Invest heavily in weapons and armor. Keep a medic on every mission.",
		"category": VictoryCategory.COMBAT,
		"difficulty": "Medium",
		"estimated_hours": "5-8",
		"min_value": 10,
		"max_value": 50
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50: {
		"name": "50 Battles",
		"short_desc": "Fight 50 battles",
		"full_desc": "A sustained combat campaign. Your crew will become elite mercenaries, known throughout the sector for their combat prowess. Expect high casualties and higher rewards.",
		"strategy": "Recruit aggressively to replace fallen crew. Specialize your team for different mission types.",
		"category": VictoryCategory.COMBAT,
		"difficulty": "Hard",
		"estimated_hours": "15-20",
		"min_value": 30,
		"max_value": 100
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100: {
		"name": "100 Battles",
		"short_desc": "Fight 100 battles",
		"full_desc": "The ultimate test of combat leadership. Only the most skilled commanders will lead their crew through a hundred engagements. Legends are forged in such crucibles.",
		"strategy": "This is a marathon. Establish reliable income sources and maintain crew morale at all costs.",
		"category": VictoryCategory.COMBAT,
		"difficulty": "Very Hard",
		"estimated_hours": "30-50",
		"min_value": 75,
		"max_value": 200
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3: {
		"name": "3 Story Quests",
		"short_desc": "Complete 3 story quests",
		"full_desc": "A narrative-focused campaign following your crew's story arc. Complete three major story missions to reach your conclusion. Quick and satisfying.",
		"strategy": "Pursue story leads actively. Don't get distracted by side jobs unless you need credits.",
		"category": VictoryCategory.STORY,
		"difficulty": "Easy",
		"estimated_hours": "4-6",
		"min_value": 1,
		"max_value": 5
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5: {
		"name": "5 Story Quests",
		"short_desc": "Complete 5 story quests",
		"full_desc": "A complete story campaign with a beginning, middle, and end. Experience the full narrative potential of Five Parsecs with five interconnected story missions.",
		"strategy": "Balance story progression with crew development. Stronger crew means easier quest completion.",
		"category": VictoryCategory.STORY,
		"difficulty": "Medium",
		"estimated_hours": "8-12",
		"min_value": 3,
		"max_value": 8
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10: {
		"name": "10 Story Quests",
		"short_desc": "Complete 10 story quests",
		"full_desc": "An epic storyline spanning multiple chapters. Your crew's journey will take them across the galaxy, facing increasingly dangerous foes and uncovering deeper mysteries.",
		"strategy": "Story quests often chain together. Keep notes on plot threads and character connections.",
		"category": VictoryCategory.STORY,
		"difficulty": "Hard",
		"estimated_hours": "20-30",
		"min_value": 5,
		"max_value": 15
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10: {
		"name": "10 Story Points",
		"short_desc": "Accumulate 10 story points",
		"full_desc": "Earn story points through narrative encounters, patron missions, and world events. A flexible goal that rewards engaging with the game's rich story systems.",
		"strategy": "Accept patron missions and explore narrative options in world events.",
		"category": VictoryCategory.STORY,
		"difficulty": "Easy",
		"estimated_hours": "4-6",
		"min_value": 5,
		"max_value": 15
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20: {
		"name": "20 Story Points",
		"short_desc": "Accumulate 20 story points",
		"full_desc": "Build a rich narrative through extensive engagement with the story systems. Your crew's tale will be filled with memorable characters, dramatic twists, and hard-won victories.",
		"strategy": "Develop long-term patron relationships. They offer better story opportunities.",
		"category": VictoryCategory.STORY,
		"difficulty": "Medium",
		"estimated_hours": "10-15",
		"min_value": 10,
		"max_value": 50
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K: {
		"name": "50K Credits",
		"short_desc": "Accumulate 50,000 credits",
		"full_desc": "Build your fortune to 50,000 credits. Focus on profitable missions, trading opportunities, and careful resource management. Money talks in the Fringe.",
		"strategy": "Take high-paying patron jobs. Salvage everything. Avoid expensive medical bills.",
		"category": VictoryCategory.WEALTH,
		"difficulty": "Medium",
		"estimated_hours": "8-12",
		"min_value": 25000,
		"max_value": 75000
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K: {
		"name": "100K Credits",
		"short_desc": "Accumulate 100,000 credits",
		"full_desc": "Amass a fortune of 100,000 credits. You'll need to become a shrewd operator, maximizing every opportunity and minimizing every expense. Retirement awaits.",
		"strategy": "Invest in crew that can salvage and trade. Avoid risky missions that could cost you more than they pay.",
		"category": VictoryCategory.WEALTH,
		"difficulty": "Hard",
		"estimated_hours": "15-25",
		"min_value": 50000,
		"max_value": 200000
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10: {
		"name": "Reputation 10",
		"short_desc": "Achieve reputation level 10",
		"full_desc": "Build your crew's reputation to level 10. Complete missions, help patrons, and make a name for yourself across the sector. Doors will open that were once closed.",
		"strategy": "Success breeds reputation. Focus on winning missions cleanly without excessive collateral damage.",
		"category": VictoryCategory.STORY,
		"difficulty": "Medium",
		"estimated_hours": "8-12",
		"min_value": 5,
		"max_value": 15
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20: {
		"name": "Reputation 20",
		"short_desc": "Achieve reputation level 20",
		"full_desc": "Become legendary across the sector with reputation level 20. Your crew's name will be known in every spaceport, feared by enemies and sought by allies.",
		"strategy": "Take on challenging missions that boost reputation faster. Maintain good patron relationships.",
		"category": VictoryCategory.STORY,
		"difficulty": "Hard",
		"estimated_hours": "15-25",
		"min_value": 10,
		"max_value": 30
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL: {
		"name": "Captain Survives",
		"short_desc": "Keep your original captain alive",
		"full_desc": "A tense survival challenge. Your original captain must survive the entire campaign. Every decision matters when permadeath is on the line. True test of tactical skill.",
		"strategy": "Protect your captain at all costs. Don't send them on the most dangerous missions alone.",
		"category": VictoryCategory.CHALLENGE,
		"difficulty": "Very Hard",
		"estimated_hours": "Variable",
		"min_value": 1,
		"max_value": 1
	},
	GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10: {
		"name": "Crew of 10",
		"short_desc": "Reach crew size of 10",
		"full_desc": "Build a crew of 10 members. Recruit, train, and retain a full team of operatives. Managing a large crew requires excellent leadership and steady income.",
		"strategy": "Prioritize income for upkeep costs. Treat injuries quickly to avoid losing crew.",
		"category": VictoryCategory.CHALLENGE,
		"difficulty": "Hard",
		"estimated_hours": "15-20",
		"min_value": 6,
		"max_value": 12
	}
}

# Legacy simple descriptions for backward compatibility
var _CAMPAIGN_DESCRIPTIONS: Dictionary = {}
var _MISSION_DESCRIPTIONS: Dictionary = {
	GlobalEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GlobalEnums.MissionVictoryType.EXTRACTION: "Reach extraction point"
}

func _init():
	# Build legacy dictionary from VICTORY_DATA
	for key in VICTORY_DATA:
		_CAMPAIGN_DESCRIPTIONS[key] = VICTORY_DATA[key].short_desc

## Get short description (backward compatible)
static func get_campaign_description(victory_type: int) -> String:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].short_desc
	return "Unknown victory condition"

## Get full narrative description
static func get_full_description(victory_type: int) -> String:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].full_desc
	return "No description available"

## Get strategy tips
static func get_strategy_tip(victory_type: int) -> String:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].strategy
	return ""

## Get victory condition name
static func get_victory_name(victory_type: int) -> String:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].name
	return "Unknown"

## Get difficulty rating
static func get_difficulty(victory_type: int) -> String:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].difficulty
	return "Unknown"

## Get estimated play time
static func get_estimated_time(victory_type: int) -> String:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].estimated_hours + " hours"
	return "Unknown"

## Get category
static func get_category(victory_type: int) -> int:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].category
	return VictoryCategory.DURATION

## Get category name as string
static func get_category_name(victory_type: int) -> String:
	var category = get_category(victory_type)
	match category:
		VictoryCategory.DURATION:
			return "Duration"
		VictoryCategory.COMBAT:
			return "Combat"
		VictoryCategory.STORY:
			return "Story"
		VictoryCategory.WEALTH:
			return "Wealth"
		VictoryCategory.CHALLENGE:
			return "Challenge"
		_:
			return "Other"

## Get min/max values for custom conditions
static func get_value_range(victory_type: int) -> Dictionary:
	if VICTORY_DATA.has(victory_type):
		return {
			"min": VICTORY_DATA[victory_type].min_value,
			"max": VICTORY_DATA[victory_type].max_value
		}
	return {"min": 1, "max": 100}

## Get complete victory data for UI display
static func get_victory_data(victory_type: int) -> Dictionary:
	if VICTORY_DATA.has(victory_type):
		return VICTORY_DATA[victory_type].duplicate()
	return {
		"name": "Unknown",
		"short_desc": "Unknown victory condition",
		"full_desc": "No description available",
		"strategy": "",
		"category": VictoryCategory.DURATION,
		"difficulty": "Unknown",
		"estimated_hours": "Unknown",
		"min_value": 1,
		"max_value": 100
	}

## Get all victory types for a category
static func get_victory_types_by_category(category: int) -> Array:
	var results: Array = []
	for key in VICTORY_DATA:
		if VICTORY_DATA[key].category == category:
			results.append(key)
	return results

static func get_mission_description(victory_type: int) -> String:
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3, GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5, GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return "Story mission objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K, GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return "Wealth accumulation objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10, GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return "Reputation building objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20, GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50, GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return "Combat mission objective"
		_:
			return "Standard mission objective"
