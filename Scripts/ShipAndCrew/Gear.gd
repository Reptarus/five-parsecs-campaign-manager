class_name Gear
extends Resource

var gear_name: String
var effect: String
var gear_type: String  # "Consumable", "Protective", "Implant", "Utility", or "On-board"

func _init(_name: String, _effect: String, _gear_type: String):
	gear_name = _name
	effect = _effect
	gear_type = _gear_type

# Gear database
static func create_gear_database() -> Dictionary:
	return {
	"Booster pills": Gear.new("Booster pills", "When taken, the character removes all Stun markers. They may move at double normal Speed this round.", "Consumable"),
	"Combat serum": Gear.new("Combat serum", "The character receives +2\" Speed and +2 Reactions for the rest of the battle.", "Consumable"),
	"Kiranin crystals": Gear.new("Kiranin crystals", "A bright, dazzling display of hypnotic lights will daze any character within 4\" of the user, making them unable to act this round. The crystals have no effect on characters that already acted earlier in the round, and do not affect the user. A character that is attacked in Brawling combat will defend themselves normally.", "Consumable"),
	"Rage out": Gear.new("Rage out", "The user gains +2\" Speed and +1 to all Brawling rolls for the rest of this and the following round. A K'Erin user gets the benefits for the rest of the battle.", "Consumable"),
	"Still": Gear.new("Still", "The user gains +1 to Hit, but cannot Move during this and the next round.", "Consumable"),
	"Stim-pack": Gear.new("Stim-pack", "If a character would become a casualty, they remain on the table with a single Stun marker. This item can be used reflexively upon becoming a casualty.", "Consumable"),
	"Battle dress": Gear.new("Battle dress", "The character counts as +1 Reactions (maximum 4) and receives a Saving Throw of 5+.", "Protective"),
	"Camo cloak": Gear.new("Camo cloak", "If character is within 2\" of Cover, they are counted as being in Cover. Does not apply if the shooter is within 4\".", "Protective"),
	"Combat armor": Gear.new("Combat armor", "Saving Throw 5+", "Protective"),
	"Deflector field": Gear.new("Deflector field", "Automatically deflects a single ranged weapon's Hit per battle. After a Hit is scored, decide if you wish to use the field before any rolls for Toughness or armor are made.", "Protective"),
	"Flak screen": Gear.new("Flak screen", "All Area weapons striking the wearer, whether through the initial shots or additional attacks from the Area trait have their Damage reduced by -1 (to a cap of +0).", "Protective"),
	"Flex-armor": Gear.new("Flex-armor", "If the character did not move on their last activation, they count as +1 Toughness (to a maximum of 6).", "Protective"),
	"Frag vest": Gear.new("Frag vest", "The wearer receives a 6+ Saving Throw, improved to 5+ against any Area attack.", "Protective"),
	"Screen generator": Gear.new("Screen generator", "Receives a 5+ Saving Throw against gunfire. No effect against Area or Melee attacks.", "Protective"),
	"Stealth gear": Gear.new("Stealth gear", "Enemies firing from a range over 9\" are -1 to Hit.", "Protective"),
	"AI companion": Gear.new("AI companion", "When making Savvy rolls, the character may roll twice and pick the better score.", "Implant"),
	"Body wire": Gear.new("Body wire", "+1 Reactions.", "Implant"),
	"Boosted arm": Gear.new("Boosted arm", "Increase Grenade range by +2\". If the character ends their Move in contact with an obstacle that is no taller than the miniature, they may pull themselves up on top (but not cross) as a Free Action.", "Implant"),
	"Boosted leg": Gear.new("Boosted leg", "Increase base move and Dash speed by +1\" each.", "Implant"),
	"Cyber hand": Gear.new("Cyber hand", "The character may take any one Pistol they own and build it into their hand. Range is reduced to half, but the weapon always shoots with +1 to Hit and an additional +1 bonus when Brawling.", "Implant"),
	"Genetic defenses": Gear.new("Genetic defenses", "5+ Saving Throw, if subjected to any poison, virus, gas, or disease.", "Implant"),
	"Health boost": Gear.new("Health boost", "If a post-battle Injury would result in 2+ campaign turns of recovery time, reduce the time by 1. If the character has Toughness 3 when receiving this implant, raise it to 4.", "Implant"),
	"Nerve adjuster": Gear.new("Nerve adjuster", "Whenever the character is Stunned for any reason, they receive a 5+ Saving Throw to avoid the Stun.", "Implant"),
	"Neural optimization": Gear.new("Neural optimization", "The character cannot be Stunned.", "Implant"),
	"Night sight": Gear.new("Night sight", "The character does not suffer visibility reductions due to darkness, but is affected by smoke, gas, etc. normally.", "Implant"),
	"Pain suppressor": Gear.new("Pain suppressor", "The character can perform crew tasks while in Sick Bay, though they cannot participate in battles.", "Implant"),
	"Auto sensor": Gear.new("Auto sensor", "If an enemy begins or ends a move within 4\" and Line of Sight of the character, you may immediately fire one shot from any Pistol carried. The shot is resolved even if the enemy is in contact with a character and Hits only on a natural 6.", "Utility"),
	"Battle visor": Gear.new("Battle visor", "When shooting, the character may reroll any 1s on the firing dice.", "Utility"),
	"Communicator": Gear.new("Communicator", "When making the Reaction roll each round, you may roll one additional die, then choose a die to discard.", "Utility"),
	"Concealed blade": Gear.new("Concealed blade", "If the character begins their round within 2\" of an opponent, they may throw the blade as a Free Action before doing anything else. Roll to Hit normally, resolving the Hit with Damage +0. The blade can be used once per battle, and is replaced afterwards for free.", "Utility"),
	"Displacer": Gear.new("Displacer", "Usable once per mission instead of Moving. Aim anywhere in sight. The character teleports to a point 1D6\" away in a random direction. If the teleport would end up within a solid obstacle, the device fails and must be Repaired before it can used again.", "Utility"),
	"Distraction bot": Gear.new("Distraction bot", "Usable once per battle as a Combat Action. Select an enemy within 12\". Next time they would become active, they are unable to act, though they remove Stun markers as normal. Use a small marker to remember.", "Utility"),
	"Grapple launcher": Gear.new("Grapple launcher", "As a Combat Action, the character may use the launcher to scale a terrain feature within 1\". The character can ascend up to 12\" but must reach a surface they can stand on.", "Utility"),
	"Grav dampener": Gear.new("Grav dampener", "The character suffers no damage from falling and can descend from any height with no risk. If dropping more than 6\", it counts as the character's Move for the round.", "Utility"),
	"Hazard suit": Gear.new("Hazard suit", "If the character takes a Hit from an environmental hazard, they receive a 5+ Saving Throw.", "Utility"),
	"Hover board": Gear.new("Hover board", "The character may use the board to move instead of walking. When used, the character can move up to 9\" and can ignore any terrain that is man-height or lower. While hover-boarding, the character cannot engage in combat, but can perform a non-Combat Action as needed.", "Utility"),
	"Insta-wall": Gear.new("Insta-wall", "May be used once per mission as a Combat Action. Place a marker within 3\", then place a 2\" long force wall oriented any way you like, as long as it touches the marker. The wall is man-height and impenetrable to attacks (but does not block sight or mental abilities). At the start of each subsequent round, a D6 is rolled. On a 6, the wall dissipates.", "Utility"),
	"Jump belt": Gear.new("Jump belt", "Instead of Moving normally, the character may jump up to 9\" directly forward and 3\" upwards. The character may take a Combat Action normally after landing.", "Utility"),
	"Motion tracker": Gear.new("Motion tracker", "Add +1 to all rolls to Seize the Initiative.", "Utility"),
	"Multi-cutter": Gear.new("Multi-cutter", "As a Combat Action, the character can cut a man-sized hole through any terrain feature up to 1\" thick. The tool has no effect on force fields.", "Utility"),
	"Robo-rabbit's foot": Gear.new("Robo-rabbit's foot", "A character with Luck 0 counts as having Luck 1. If the character would die while carrying this, the foot is destroyed (and cannot be Repaired), the character does not roll on the injury table.", "Utility"),
	"Scanner bot": Gear.new("Scanner bot", "The crew adds +1 to all Seize the Initiative rolls.", "Utility"),
	"Snooper bot": Gear.new("Snooper bot", "May be deployed before a battle, if the Seize the Initiative roll would be penalized or negated. The penalty can be ignored, but the Bot is Damaged on a D6 roll of a 1.", "Utility"),
	"Sonic emitter": Gear.new("Sonic emitter", "Any enemy within 5\" suffers -1 to all Hit rolls when shooting.", "Utility"),
	"Steel boots": Gear.new("Steel boots", "If the character rolls a natural 5 or 6 in a Brawl and wins the Brawl, they may opt to kick instead of striking normally. This hits with Damage +0 and knocks them 1D3\" directly backwards. If the opponent is kicked into another character, that character is knocked 1D3\" in a random direction.", "Utility"),
	"Time distorter": Gear.new("Time distorter", "Activated as a Free Action. Select up to 3 enemy figures on the battlefield. They are frozen in time until the end of the following round. While in this state, they cannot Move, take any Actions, or be affected by attacks or effects in any way. They are unaffected by Morale rolls as well. Single-use.", "Utility"),
	"Analyzer": Gear.new("Analyzer", "Add +1 when rolling to see if Rumors result in a Quest and when rolling for Quest resolution.", "On-board"),
	"Colonist ration packs": Gear.new("Colonist ration packs", "Ignore Upkeep costs for one campaign turn. +1 story point. Single-use.", "On-board"),
	"Duplicator": Gear.new("Duplicator", "Create a perfect copy of any one item in your inventory. A Duplicator cannot copy a Duplicator, due to the same proprietary nano-bot lock-out codes that makes your printer say it's out of ink after printing 17 pages. Single-use.", "On-board"),
	"Fake ID": Gear.new("Fake ID", "Add +1 to all attempts to obtain a license or other legal document.", "On-board"),
	"Fixer": Gear.new("Fixer", "One piece of damaged or destroyed personal equipment can be repaired automatically, and at no cost. Single-use.", "On-board"),
	"Genetic reconfiguration kit": Gear.new("Genetic reconfiguration kit", "Reduce the cost of an ability score upgrade by 2 XP. Has no effect on Bots or Soulless. K'Erin may only use this to increase Toughness. Single-use.", "On-board"),
	"Loaded dice": Gear.new("Loaded dice", "Each campaign turn, one crew member may gamble on the side. Roll 1D6. On a 1-4, earn that many credits. On a 5, earn nothing. On a 6, the locals don't take kindly to losing: The dice are lost and the crew member must roll on the post-battle Injury Table.", "On-board"),
	"Lucky dice": Gear.new("Lucky dice", "Each campaign turn, one crew member may gamble on the side, earning +1 credit.", "On-board"),
	"Mk II translator": Gear.new("Mk II translator", "When rolling to Recruit, you may roll an additional D6.", "On-board"),
	"Med-patch": Gear.new("Med-patch", "A character recovering from an Injury may subtract one campaign turn from the recovery duration required. If this reduces the time to zero turns, they may act normally this campaign turn. Single-use.", "On-board"),
	"Meditation orb": Gear.new("Meditation orb", "The crew all feel reassured of their karmic balance. Add +2 story points. All Swift or Precursor in the crew may also add +1 XP. Single-use.", "On-board"),
	"Nano-doc": Gear.new("Nano-doc", "Prevent one roll on the post-battle Injury Table, no matter the source of the injury. You must decide before rolling the dice. Single-use.", "On-board"),
	"Novelty stuffed animal": Gear.new("Novelty stuffed animal", "Give to any character that isn't Soulless, K'Erin, or a Bot. The character receives +1 XP, and may roll 1D6. On a 6, you may add +1 story point as well. Single-use.", "On-board"),
	"Purifier": Gear.new("Purifier", "Each campaign turn, the Purifier can be used to generate clean water which can be sold off for 1 credit. This does not require a crew member to operate, but only one Purifier may be used at a time.", "On-board"),
	"Repair Bot": Gear.new("Repair Bot", "+1 to all Repair attempts.", "On-board"),
	"Sector permit": Gear.new("Sector permit", "Whenever you arrive at a planet where a license is required, roll 1D6. On a 4+, the Sector Permit is accepted. You must roll for each license type, on each planet.", "On-board"),
	"Spare parts": Gear.new("Spare parts", "Add +1 when making a Repair attempt. If the roll is a natural 1, the Spare Parts are used up and must be erased from your roster.", "On-board"),
	"Teach-bot": Gear.new("Teach-bot", "A character engaging in the Train crew task will earn 1D6 additional XP. Single-use.", "On-board"),
	"Transcender": Gear.new("Transcender", "The character activating this mysterious device receives +1 XP. The entire crew makes realizations about their place in the cosmos. Add +2 story points. Single-use.", "On-board"),
}
