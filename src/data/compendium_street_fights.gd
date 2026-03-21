class_name CompendiumStreetFights
extends RefCounted
## Street Fights — Compendium pp.123-138
##
## Urban combat with Suspect markers, City markers, pistol Shootout mechanics,
## Evasion, unique enemy tables, and street combatants. Confused, chaotic
## environments where enemies start as unidentified Suspects.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.STREET_FIGHTS.
##
## Integration notes (p.125):
##   - Notable Sights and Deployment Conditions are NOT used
##   - Enemy Deployment Variables (p.44) are NOT used
##   - Escalating Battles (p.46) are NOT used
##   - Morale is NOT checked (situation too confusing)
##   - Visibility limited to 9" (cannot be increased by abilities/equipment)


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STREET_FIGHTS)


## ============================================================================
## TABLE SETUP (Compendium pp.125-126)
## ============================================================================

const TABLE_SETUP_RULES: String = (
	"STREET FIGHT TABLE SETUP:\n" +
	"- Mark off streets and alleys (paper/card building blocks work fine).\n" +
	"- Make some buildings accessible with entrance points and 1-2 rooms.\n" +
	"- All visibility limited to 9\" (cannot be increased).\n" +
	"- Lots of incidental terrain to clutter streets and alleys."
)

const BUILDING_TYPES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 2, "id": "commercial", "name": "Commercial (shops, offices)",
	 "instruction": "BUILDING: Commercial. +1 City marker placed by entrance."},
	{"roll_min": 3, "roll_max": 4, "id": "residential", "name": "Residential (apartments, houses)",
	 "instruction": "BUILDING: Residential. No special effects."},
	{"roll_min": 5, "roll_max": 5, "id": "warehouse", "name": "Warehouse",
	 "instruction": "BUILDING: Warehouse. +1 Suspect marker placed by entrance."},
	{"roll_min": 6, "roll_max": 6, "id": "abandoned", "name": "Abandoned or Empty",
	 "instruction": "BUILDING: Abandoned/Empty. No special effects, but place plenty of difficult terrain and additional cover nearby."},
]


## ============================================================================
## DEPLOYMENT (Compendium p.126)
## ============================================================================

const DEPLOYMENT_RULES: String = (
	"STREET FIGHT DEPLOYMENT:\n" +
	"- SUSPECT MARKERS: Place markers equal to crew size, spread evenly around table.\n" +
	"  Place along streets, near shops or interesting features.\n" +
	"  +1 Suspect by entrance to each Warehouse.\n" +
	"- CITY MARKERS: Place 6 markers around table in/by terrain or buildings.\n" +
	"  +1 City marker by each Commercial area.\n" +
	"- CREW ENTRY: Each crew figure enters from random table edge point.\n" +
	"  Roll direction die in table center for each figure.\n" +
	"  Captain arrives LAST — may choose random or alongside any placed crew member."
)


## ============================================================================
## SUSPECT MARKER BEHAVIOR (Compendium pp.126-127)
## Act in Enemy Phase after all active enemies.
## Move left-to-right on table, roll D6 each.
## ============================================================================

const SUSPECT_ACTIONS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 1, "id": "stay",
	 "instruction": "SUSPECT: Stay. Remain in place."},
	{"roll_min": 2, "roll_max": 4, "id": "move",
	 "instruction": "SUSPECT: Move 4\" in random direction, halting if unable to make full move."},
	{"roll_min": 5, "roll_max": 5, "id": "pursue",
	 "instruction": "SUSPECT: Pursue. Move 4\" toward nearest crew member by shortest route. Marker is now in pursuit — no longer rolls on this table (always pursues)."},
	{"roll_min": 6, "roll_max": 6, "id": "something_interesting",
	 "instruction": "SUSPECT: Something Interesting? Remains in place. Place City marker underneath it. (Only occurs once per round — if multiple 6s, treat rest as Stay.)"},
]


## ============================================================================
## SUSPECT IDENTIFICATION (Compendium p.127)
## Triggered when crew within LoS and within (4 + Savvy) inches.
## ============================================================================

const SUSPECT_IDENTIFICATION: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 1, "id": "nothing",
	 "instruction": "SUSPECT REVEAL: Nothing interesting. Remove marker."},
	{"roll_min": 2, "roll_max": 2, "id": "possible_enemy",
	 "instruction": "SUSPECT REVEAL: Possible enemy. If marker was in pursuit, it IS an enemy — remove and place enemy figure. Otherwise, nothing — remove marker."},
	{"roll_min": 3, "roll_max": 5, "id": "enemy",
	 "instruction": "SUSPECT REVEAL: Enemy! Remove marker and place enemy figure."},
	{"roll_min": 6, "roll_max": 6, "id": "ambush",
	 "instruction": "SUSPECT REVEAL: Ambush! Remove marker, place enemy figure. ALSO place second enemy 6\" from spotting crew member in random direction."},
]


## ============================================================================
## OBJECTIVES (Compendium pp.128-130, D100)
## ============================================================================

const STREET_FIGHT_OBJECTIVES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 10, "id": "contact_individual",
	 "has_individual": true, "has_package": false,
	 "instruction": "OBJECTIVE: Contact Individual. Reach individual and move within 1\" to deliver message. Individual is then removed. The figure that delivered the message must survive the mission (not permanently dead)."},
	{"roll_min": 11, "roll_max": 20, "id": "locate_individual",
	 "has_individual": true, "has_package": false,
	 "instruction": "OBJECTIVE: Locate Individual. Individual not on table initially. Place 6 markers in buildings/locations, spread evenly. Move within 4\" and LoS of a marker: remove it, roll D6. If roll <= markers removed so far (including this one), individual found. Must get individual off table edge without them becoming a casualty."},
	{"roll_min": 21, "roll_max": 40, "id": "surveil_individual",
	 "has_individual": true, "has_package": false,
	 "instruction": "OBJECTIVE: Surveil Individual. End 3 total battle rounds with a figure within LoS and 4-9\" of individual, then escape. If individual comes within 3\" and LoS, they panic — flee to nearest table edge until no LoS, then resume wandering. Cannot surveil while panicked."},
	{"roll_min": 41, "roll_max": 60, "id": "confront_individual",
	 "has_individual": true, "has_package": false,
	 "instruction": "OBJECTIVE: Confront Individual. Reach within 2\", then roll D6:\n1-2: Terrified, flees toward nearest edge. Defeat in unarmed Brawl to complete.\n3-4: Wants to fight — roll Street Combatant table for their real identity. Must make them a casualty.\n5-6: Must be threatened. Roll 1D6+Savvy (6+ succeeds). Can retry any time within 2\". On success, removed from play and mission complete."},
	{"roll_min": 61, "roll_max": 75, "id": "rescue_individual",
	 "has_individual": true, "has_package": false,
	 "instruction": "OBJECTIVE: Rescue Individual. Reach individual and corral them. Once contacted, crew within 1\" can move them any direction once/round. If individual spends entire round with no crew within 6\", they panic and move to nearest cover. Nearest Suspect marker begins pursuit. Enemy may Brawl (not shoot) the individual. Must get off table edge."},
	{"roll_min": 76, "roll_max": 90, "id": "deliver_package",
	 "has_individual": false, "has_package": true,
	 "instruction": "OBJECTIVE: Deliver Package. Select carrier. Deliver to table center — no enemy or Suspect within 5\" when placed. Place additional Suspect at table center. Then escape off any edge."},
	{"roll_min": 91, "roll_max": 100, "id": "retrieve_package",
	 "has_individual": false, "has_package": true,
	 "instruction": "OBJECTIVE: Retrieve Package. Package at table center. Place Suspect marker on it. If distance from edge to center < 15\", place second Suspect 6\" from center in random direction. Move into contact, then carry off any table edge."},
]


## ============================================================================
## INDIVIDUAL RULES — STREET FIGHTS (Compendium p.128)
## ============================================================================

const INDIVIDUAL_PROFILE: Dictionary = {
	"speed": 4, "toughness": 3,
}

const INDIVIDUAL_RULES: String = (
	"STREET FIGHT INDIVIDUAL:\n" +
	"- Profile: Speed 4\", Toughness 3. Will not fight.\n" +
	"- Moves random direction at end of Enemy Phase.\n" +
	"- If figure within 6\" and LoS fires or is fired upon: individual panics, " +
	"runs full move away toward cover.\n" +
	"- Corral: Crew within 3\" and LoS, roll 1D6+Savvy (5+). " +
	"Individual then moves to designated location within LoS before resuming wandering.\n" +
	"- Individuals begin at table center."
)


## ============================================================================
## PACKAGE RULES (Compendium p.128)
## ============================================================================

const PACKAGE_RULES: String = (
	"PACKAGE RULES:\n" +
	"- Costs 1\" of movement to pick up, place, or hand off.\n" +
	"- If carrier becomes Down, package drops at their feet. Roll D6: on 1, package destroyed (mission fails)."
)


## ============================================================================
## EVASION (Compendium p.128)
## ============================================================================

const EVASION_RULES: String = (
	"EVASION:\n" +
	"- Eligible if crew member had NO enemies visible at start of Enemy Actions phase.\n" +
	"- Trigger: if moving enemy comes into sight, may attempt Evasion immediately.\n" +
	"- Roll 1D6+Savvy. For every point above 4, move 1\" in any direction.\n" +
	"  (e.g., result 6 = move 2\"). Result 4 or less = failed, no movement.\n" +
	"- Can cross traversable terrain without penalty. Cannot Evade into Brawl.\n" +
	"- Once per battle round per figure."
)


## ============================================================================
## SHOOTOUT RULES (Compendium p.130)
## ============================================================================

const SHOOTOUT_RULES: String = (
	"SHOOTOUT (Pistol trait weapons):\n" +
	"1. Attacker fires normally with Pistol.\n" +
	"2. If target not Stunned/eliminated AND armed with Pistol, target returns fire.\n" +
	"3. If attacker not Stunned/eliminated OR target has no Pistol, attacker fires a second time.\n" +
	"No additional shots after these 3 steps. Then normal combat rules.\n" +
	"Non-Pistol weapons work normally but cannot initiate or return fire in Shootout."
)


## ============================================================================
## STARTING TROUBLE (Compendium p.128)
## ============================================================================

const STARTING_TROUBLE_RULES: String = (
	"STARTING TROUBLE:\n" +
	"- Revealed enemies unable to spot any crew after moving try to start trouble.\n" +
	"- Roll D6: On 1, place Suspect marker randomly 6\" from their position.\n" +
	"- Only 1 new marker per battle round regardless of how many 1s rolled."
)


## ============================================================================
## STREET FIGHT ENEMIES (Compendium pp.131-133, D100)
## Same profile used for ALL enemies in the mission.
## Determined when first enemy is revealed.
## ============================================================================

const STREET_FIGHT_ENEMIES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 7, "id": "hit_squad",
	 "speed": 5, "combat_skill": 1, "toughness": 4, "ai": "aggressive",
	 "weapons": "Hand laser",
	 "instruction": "ENEMY: Hit Squad. Speed 5\", +1 Combat, Toughness 4, Aggressive AI. Hand laser. A natural 6 to Hit ignores any Armor the target is wearing."},
	{"roll_min": 8, "roll_max": 12, "id": "spooks",
	 "speed": 5, "combat_skill": 1, "toughness": 4, "ai": "aggressive",
	 "weapons": "Machine pistol; Blade",
	 "instruction": "ENEMY: Spooks. Speed 5\", +1 Combat, Toughness 4, Aggressive AI. Machine pistol + Blade. Once revealed, ALL current and future Suspect markers automatically Pursue."},
	{"roll_min": 13, "roll_max": 22, "id": "gutter_gang",
	 "speed": 4, "combat_skill": 0, "toughness": 4, "ai": "aggressive",
	 "weapons": "Handgun",
	 "instruction": "ENEMY: Gutter Gang. Speed 4\", +0 Combat, Toughness 4, Aggressive AI. Handgun. No special rules. If another gang shows up, they are also Gutter Gangers but a RIVAL gang (may fight each other and you)."},
	{"roll_min": 23, "roll_max": 32, "id": "main_gang",
	 "speed": 4, "combat_skill": 1, "toughness": 4, "ai": "aggressive",
	 "weapons": "Handgun",
	 "instruction": "ENEMY: Main Gang. Speed 4\", +1 Combat, Toughness 4, Aggressive AI. Handgun. No special rules. If another gang shows up, they are also Main Gangers but a RIVAL gang (may fight each other and you)."},
	{"roll_min": 33, "roll_max": 40, "id": "urban_separatists",
	 "speed": 4, "combat_skill": 1, "toughness": 4, "ai": "tactical",
	 "weapons": "Colony rifle",
	 "instruction": "ENEMY: Urban Separatists. Speed 4\", +1 Combat, Toughness 4, Tactical AI. Colony rifle. If gangers or enforcers show up during mission, 3 additional separatists placed in battlefield center (1 with rattle gun, 2 with colony rifles)."},
	{"roll_min": 41, "roll_max": 48, "id": "fanatics",
	 "speed": 4, "combat_skill": 0, "toughness": 4, "ai": "aggressive",
	 "weapons": "Handgun; Blade",
	 "instruction": "ENEMY: Fanatics. Speed 4\", +0 Combat, Toughness 4, Aggressive AI. Handgun + Blade. End of each round: roll D6 per Fanatic on table. If any rolls 6, 1 additional Fanatic appears adjacent to Fanatic closest to any crew."},
	{"roll_min": 49, "roll_max": 54, "id": "tech_cultists",
	 "speed": 4, "combat_skill": 1, "toughness": 5, "ai": "tactical",
	 "weapons": "Beam pistol",
	 "instruction": "ENEMY: Tech Cultists. Speed 4\", +1 Combat, Toughness 5, Tactical AI. Beam pistol. Armor save 6+."},
	{"roll_min": 55, "roll_max": 60, "id": "roid_gangers",
	 "speed": 4, "combat_skill_brawl": 2, "combat_skill_shoot": 0, "toughness": 5, "ai": "aggressive",
	 "weapons": "Hand cannon; Brutal melee",
	 "instruction": "ENEMY: Roid Gangers. Speed 4\", +2 Combat Brawl / +0 Shooting, Toughness 5, Aggressive AI. Hand cannon + Brutal melee. If LoS to crew at activation start without Shout marker: place Shout marker. Next activation: remove Shout, remove all Stun markers."},
	{"roll_min": 61, "roll_max": 65, "id": "bot_gang",
	 "speed": 4, "combat_skill": 0, "toughness": 5, "ai": "tactical",
	 "weapons": "Blast pistol",
	 "instruction": "ENEMY: Bot Gang. Speed 4\", +0 Combat, Toughness 5, Tactical AI. Blast pistol. Armor save 5+. Will not attack Bots or Soulless unless that figure attacked a bot previously during mission."},
	{"roll_min": 66, "roll_max": 74, "id": "vigilantes",
	 "speed": 4, "combat_skill": 0, "toughness": 4, "ai": "tactical",
	 "weapons": "Colony rifle",
	 "instruction": "ENEMY: Vigilantes. Speed 4\", +0 Combat, Toughness 4, Tactical AI. Colony rifle. No special rules."},
	{"roll_min": 75, "roll_max": 84, "id": "crime_syndicate",
	 "speed": 4, "combat_skill": 1, "toughness": 4, "ai": "tactical",
	 "weapons": "Blast pistol",
	 "instruction": "ENEMY: Crime Syndicate. Speed 4\", +1 Combat, Toughness 4, Tactical AI. Blast pistol. No special rules."},
	{"roll_min": 85, "roll_max": 94, "id": "terror_faction",
	 "speed": 4, "combat_skill": 1, "toughness": 4, "ai": "aggressive",
	 "weapons": "Handgun; Blade",
	 "instruction": "ENEMY: Terror Faction. Speed 4\", +1 Combat, Toughness 4, Aggressive AI. Handgun + Blade. If activates with no figure in sight: D6, on 1 they move toward nearest terrain feature to plant bomb. Once inside, roll D6 each activation — on 1-2 bomb goes off (all in/on/adjacent are casualties, no save). Sirens! triggers automatically. Bomb disarmed with 6+ Savvy test at contact."},
	{"roll_min": 95, "roll_max": 100, "id": "neon_barbarians",
	 "speed": 5, "combat_skill": 1, "toughness": 5, "ai": "aggressive",
	 "weapons": "Boarding saber",
	 "instruction": "ENEMY: Neon Barbarians. Speed 5\", +1 Combat, Toughness 5, Aggressive AI. Boarding saber. Crew within 4\" can attempt Savvy test (7+) to make them ignore that character. +1 Combat Skill vs anyone who fired a gun at them. Any character carrying a sword will be challenged (cannot talk out of it). Blades, boarding sabers, glare swords, ripper swords all count."},
]


## ============================================================================
## STREET COMBATANTS (Compendium pp.134-135, D100)
## Fight alone, attack anyone including each other.
## Never accumulate more than 1 Stun marker.
## ============================================================================

const STREET_COMBATANTS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 10, "id": "haywire_bot",
	 "speed": 4, "combat_skill": 1, "toughness": 5, "ai": "random",
	 "weapons": "Power claw",
	 "instruction": "COMBATANT: Haywire Bot. Speed 4\", +1 Combat, Toughness 5. Power claw. Armor save 5+. Cannot be Stunned. Moves 4\" randomly each turn — if within 1\" of any figure during move, engages Brawl. If you win Brawl: 1D6+Savvy (7+) to reprogram it to fight on your side."},
	{"roll_min": 11, "roll_max": 15, "id": "mech_gladiator",
	 "speed": 6, "combat_skill": 2, "toughness": 5, "ai": "rampage",
	 "weapons": "Ripper sword",
	 "instruction": "COMBATANT: Mech-Gladiator. Speed 6\", +2 Combat, Toughness 5, Rampage AI. Ripper sword. May reroll 1s in Brawl. If opponent wins by only 1, gladiator retreats 4\" and is NOT Hit."},
	{"roll_min": 16, "roll_max": 27, "id": "assassin",
	 "speed": 6, "combat_skill": 2, "toughness": 4, "ai": "tactical",
	 "weapons": "Hand laser; Blade",
	 "instruction": "COMBATANT: Assassin. Speed 6\", +2 Combat, Toughness 4, Tactical AI. Hand laser + Blade. If the figure that revealed the Assassin is removed from play, the Assassin leaves immediately."},
	{"roll_min": 28, "roll_max": 37, "id": "roid_head",
	 "speed": 5, "combat_skill": 1, "toughness": 5, "ai": "rampage",
	 "weapons": "Fists (Power claw damage)",
	 "instruction": "COMBATANT: Roid-head. Speed 5\", +1 Combat, Toughness 5, Rampage AI. Fists = Power claw damage. First casualty inflicted is IGNORED. Cannot be Stunned. Each activation: D6, on 1 moves 8\" randomly, Stunning and pushing away any figure contacted."},
	{"roll_min": 38, "roll_max": 47, "id": "tech_head",
	 "speed": 4, "combat_skill": 1, "toughness": 4, "ai": "tactical",
	 "weapons": "Plasma rifle; Blade",
	 "instruction": "COMBATANT: Tech-head. Speed 4\", +1 Combat, Toughness 4, Tactical AI. Plasma rifle + Blade. Won't shoot at Soulless or Bots unless attacked first. 5+ Screen save."},
	{"roll_min": 48, "roll_max": 55, "id": "combat_bot",
	 "speed": 4, "combat_skill": 2, "toughness": 5, "ai": "aggressive",
	 "weapons": "Rattle gun; Brutal melee",
	 "instruction": "COMBATANT: Combat Bot. Speed 4\", +2 Combat, Toughness 5, Aggressive AI. Rattle gun + Brutal melee. Armor save 5+. Cannot be Stunned. Ignores Heavy weapon trait."},
	{"roll_min": 56, "roll_max": 63, "id": "sinister",
	 "speed": 7, "combat_skill": 1, "toughness": 4, "ai": "aggressive",
	 "weapons": "Claws (Melee, 2 damage)",
	 "instruction": "COMBATANT: Sinister. Speed 7\", +1 Combat, Toughness 4, Aggressive AI. Claws (Melee, 2 damage). Roll 2 dice in Brawl (use highest). If both beat opponent, inflict 2 Hits. Weapons hit dodged on D6 5+. When dodging, moves 3\" randomly."},
	{"roll_min": 64, "roll_max": 68, "id": "slasher",
	 "speed": 3, "combat_skill": 2, "toughness": 99, "ai": "rampage",
	 "weapons": "Brutal melee",
	 "instruction": "COMBATANT: Slasher. Speed 3\", +2 Combat, Rampage AI. Brutal melee. CANNOT be eliminated. Weapons hit knocks back 1\". Cannot be Stunned."},
	{"roll_min": 69, "roll_max": 80, "id": "criminal",
	 "speed": 4, "combat_skill": 1, "toughness": 4, "ai": "cautious",
	 "weapons": "Hand cannon; Blade",
	 "instruction": "COMBATANT: Criminal. Speed 4\", +1 Combat, Toughness 4, Cautious AI. Hand cannon + Blade. If eliminated: D6 — on 1 receive Gang Rival, on 6 cash in 2 Credit bounty."},
	{"roll_min": 81, "roll_max": 92, "id": "gang_prospect",
	 "speed": 4, "combat_skill": 0, "toughness": 4, "ai": "aggressive",
	 "weapons": "Handgun",
	 "instruction": "COMBATANT: Gang Prospect. Speed 4\", +0 Combat, Toughness 4, Aggressive AI. Handgun. No special rules."},
	{"roll_min": 93, "roll_max": 100, "id": "gun_bunny",
	 "speed": 4, "combat_skill": 1, "toughness": 4, "ai": "tactical",
	 "weapons": "2 handguns",
	 "instruction": "COMBATANT: Gun Bunny. Speed 4\", +1 Combat, Toughness 4, Tactical AI. 2 handguns. May fire both simultaneously."},
]


## ============================================================================
## CITY MARKER BEHAVIOR (Compendium p.135)
## Roll D6 ONCE per turn at end of Slow Actions phase.
## ============================================================================

const CITY_MARKER_ACTIONS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 3, "id": "nothing",
	 "instruction": "CITY: Nothing happens."},
	{"roll_min": 4, "roll_max": 5, "id": "movement",
	 "instruction": "CITY: Movement. Randomly select City marker, move 6\" toward furthest table edge."},
	{"roll_min": 6, "roll_max": 6, "id": "something_interesting",
	 "instruction": "CITY: Something Interesting. Place City marker adjacent to terrain closest to last crew member to act."},
]


## ============================================================================
## CITY MARKER REVEALS (Compendium pp.136-137, D100)
## Triggered when player figure moves within 4" (regardless of LoS).
## ============================================================================

const CITY_MARKER_REVEALS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 10, "id": "jostled",
	 "instruction": "CITY REVEAL: Jostled. Character halts immediately and is Stunned. Roll D6: 1-3 crowd disperses, 4-6 place 4\"x4\" Crowd marker centered on character."},
	{"roll_min": 11, "roll_max": 15, "id": "curiosity",
	 "instruction": "CITY REVEAL: Curiosity. Place marker randomly 6\" from character. If picked up (by anyone): D6 — 1-4 garbage, 5-6 grants 2 Quest Clues."},
	{"roll_min": 16, "roll_max": 30, "id": "informer",
	 "instruction": "CITY REVEAL: Informer. Encounter someone who has been trying to meet up. Add a Quest Clue!"},
	{"roll_min": 31, "roll_max": 40, "id": "crowd",
	 "instruction": "CITY REVEAL: Crowd. 4\"x4\" space centered on marker. Moves 4\" in random direction at end of Enemy Phase. Blocks all LoS. Figures inside must stand still or move with crowd (no actions). If fired upon while in sight of crowd, crowd disperses AND triggers Sirens!"},
	{"roll_min": 41, "roll_max": 45, "id": "roadblock",
	 "instruction": "CITY REVEAL: Roadblock. 4\"x4\" area centered on marker — impassable, cannot fire across."},
	{"roll_min": 46, "roll_max": 50, "id": "bot_struction",
	 "instruction": "CITY REVEAL: Bot-struction. 4\"x4\" area of construction bots. Moves randomly 4\" at end of each Enemy Phase. Cannot move or fire through. Figures caught in zone: 1D6+Savvy (6+ to evade). Failures become casualties."},
	{"roll_min": 51, "roll_max": 55, "id": "reporter",
	 "instruction": "CITY REVEAL: Reporter. Place figure randomly 6\" from spotter. Moves 4\" randomly at end of Enemy Phase. Cannot be attacked. If gunfire within LoS: triggers Sirens! If crew fires or Brawls in sight of reporter: receive Enforcer Rival (unless returning fire in Shootout)."},
	{"roll_min": 56, "roll_max": 70, "id": "street_combatant",
	 "instruction": "CITY REVEAL: Street Combatant! Roll on Street Combatant table (D100). Sets up at least 6\" from character in closest out-of-sight location."},
	{"roll_min": 71, "roll_max": 75, "id": "set_up",
	 "instruction": "CITY REVEAL: It's a set-up! At end of current battle round, place Suspect marker on center of each of 4 table edges. All are in pursuit."},
	{"roll_min": 76, "roll_max": 80, "id": "gang_turf",
	 "instruction": "CITY REVEAL: Gang Turf. At end of following battle round, roll Criminal Elements table (core rules p.94). 6 enemies arrive — 2 on center of each of 3 random edges. Fight both sides, ignore Suspect markers."},
	{"roll_min": 81, "roll_max": 90, "id": "sirens",
	 "instruction": "CITY REVEAL: Sirens! Start Siren clock at 0. End of each battle round (including current): advance 1D6 ticks. At 10: 6 Enforcers arrive at table edge center. They take down anyone, remove Suspect/City markers within 4\", move within 6\" before firing. Crew may surrender (see Messing with the Law)."},
	{"roll_min": 91, "roll_max": 100, "id": "looking_suspicious",
	 "instruction": "CITY REVEAL: Looking Suspicious. Place City marker AND Suspect marker in nearest terrain feature."},
]


## ============================================================================
## MESSING WITH THE LAW (Compendium p.138)
## ============================================================================

const LAW_RULES: String = (
	"MESSING WITH THE LAW — Surrender to law officer in sight:\n" +
	"\n" +
	"LEVEL 1 (no crew attacked law, no Bounty Hunter/Vigilante/Enforcer Rivals):\n" +
	"  Roll 1D6+Savvy. 6+ = talk your way out. Fail = detained 1D6 turns, " +
	"non-Pistol weapons confiscated.\n" +
	"\n" +
	"LEVEL 2 (have Bounty Hunter/Vigilante Rival, OR crew attacked law but surrenderer did not):\n" +
	"  Savvy test 8+ required. Fail = detained 1D6+2 turns. " +
	"All weapons confiscated regardless of outcome.\n" +
	"\n" +
	"LEVEL 3 (have Enforcer Rival, OR surrenderer fired on law):\n" +
	"  Sent to prison planet. Cannot be used again in this campaign.\n" +
	"  (New campaign: may include 1 prison planet character — old profile, " +
	"stripped of all equipment+implants, 3 Enforcer Rivals, +1 Story Point, +3 XP.)\n" +
	"\n" +
	"While detained: no actions, no events. Recover from injuries normally."
)


## ============================================================================
## END GAME (Compendium p.138)
## ============================================================================

const END_GAME_RULES: String = (
	"STREET FIGHT END GAME:\n" +
	"- Must move off table to complete scenario. Escape through any edge.\n" +
	"- If a building has interior access and extends off table, can escape through it.\n" +
	"- Holding the Field requires clearing ALL enemies AND Suspect markers.\n" +
	"- All post-game resolution handled normally per core rules."
)


## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll a street fight objective. Returns objective dict.
static func roll_objective() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 100)
	for obj in STREET_FIGHT_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			var result: Dictionary = obj.duplicate()
			result["roll"] = roll
			return result
	return STREET_FIGHT_OBJECTIVES[0]


## Roll street fight enemy type (first reveal). Returns enemy dict.
static func roll_enemy_type() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 100)
	for enemy in STREET_FIGHT_ENEMIES:
		if roll >= enemy.roll_min and roll <= enemy.roll_max:
			var result: Dictionary = enemy.duplicate()
			result["roll"] = roll
			return result
	return STREET_FIGHT_ENEMIES[0]


## Roll street combatant (from City marker reveal). Returns combatant dict.
static func roll_street_combatant() -> Dictionary:
	var roll := randi_range(1, 100)
	for combatant in STREET_COMBATANTS:
		if roll >= combatant.roll_min and roll <= combatant.roll_max:
			var result: Dictionary = combatant.duplicate()
			result["roll"] = roll
			return result
	return STREET_COMBATANTS[0]


## Roll suspect action. Returns action dict.
static func roll_suspect_action() -> Dictionary:
	var roll := randi_range(1, 6)
	for action in SUSPECT_ACTIONS:
		if roll >= action.roll_min and roll <= action.roll_max:
			var result: Dictionary = action.duplicate()
			result["roll"] = roll
			return result
	return SUSPECT_ACTIONS[0]


## Roll suspect identification. Returns identification dict.
static func roll_suspect_identification() -> Dictionary:
	var roll := randi_range(1, 6)
	for ident in SUSPECT_IDENTIFICATION:
		if roll >= ident.roll_min and roll <= ident.roll_max:
			var result: Dictionary = ident.duplicate()
			result["roll"] = roll
			return result
	return SUSPECT_IDENTIFICATION[0]


## Roll city marker behavior (once per turn). Returns action dict.
static func roll_city_marker_action() -> Dictionary:
	var roll := randi_range(1, 6)
	for action in CITY_MARKER_ACTIONS:
		if roll >= action.roll_min and roll <= action.roll_max:
			var result: Dictionary = action.duplicate()
			result["roll"] = roll
			return result
	return CITY_MARKER_ACTIONS[0]


## Roll city marker reveal (when crew within 4"). Returns reveal dict.
static func roll_city_marker_reveal() -> Dictionary:
	var roll := randi_range(1, 100)
	for reveal in CITY_MARKER_REVEALS:
		if roll >= reveal.roll_min and roll <= reveal.roll_max:
			var result: Dictionary = reveal.duplicate()
			result["roll"] = roll
			return result
	return CITY_MARKER_REVEALS[0]


## Roll building type (D6). Returns building dict.
static func roll_building_type() -> Dictionary:
	var roll := randi_range(1, 6)
	for bldg in BUILDING_TYPES:
		if roll >= bldg.roll_min and roll <= bldg.roll_max:
			var result: Dictionary = bldg.duplicate()
			result["roll"] = roll
			return result
	return BUILDING_TYPES[0]


## Get full street fight setup as instruction block.
static func generate_mission_setup() -> Dictionary:
	if not _is_enabled():
		return {}

	var objective := roll_objective()
	return {
		"objective": objective,
		"table_setup": TABLE_SETUP_RULES,
		"deployment": DEPLOYMENT_RULES,
		"suspect_actions": SUSPECT_ACTIONS,
		"suspect_identification": SUSPECT_IDENTIFICATION,
		"evasion": EVASION_RULES,
		"shootout": SHOOTOUT_RULES,
		"starting_trouble": STARTING_TROUBLE_RULES,
		"city_marker_actions": CITY_MARKER_ACTIONS,
		"city_marker_reveals": CITY_MARKER_REVEALS,
		"law_rules": LAW_RULES,
		"end_game": END_GAME_RULES,
		"individual_rules": INDIVIDUAL_RULES if objective.get("has_individual", false) else "",
		"package_rules": PACKAGE_RULES if objective.get("has_package", false) else "",
	}
