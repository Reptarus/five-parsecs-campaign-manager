## Test Helper: Loot System Functions
## Extracts testable functions from simulate_campaign_turns.gd
## Plain class (no Node inheritance) to avoid lifecycle issues in tests

class_name LootSystemHelper

func _roll_battlefield_finds(d100_roll: int = 0, d6_roll: int = 0) -> Dictionary:
	"""Roll on Battlefield Finds Table (Five Parsecs rulebook p.6601-6670)

	Args:
		d100_roll: For testing - battlefield finds table roll (1-100)
		d6_roll: For testing - debris credits roll (1-6)
	"""
	var roll = d100_roll if d100_roll > 0 else (randi() % 100) + 1
	var result = {"roll": roll, "category": "", "description": "", "credits": 0, "quest_rumor": false}

	if roll <= 15:
		result.category = "Weapon"
		result.description = "Random weapon from slain enemy"
	elif roll <= 25:
		result.category = "Consumable"
		result.description = "Usable goods (consumable item)"
	elif roll <= 35:
		result.category = "Quest Rumor"
		result.description = "Curious data stick"
		result.quest_rumor = true
	elif roll <= 45:
		result.category = "Ship Part"
		result.description = "Starship part (2 credits value)"
		result.credits = 2
	elif roll <= 60:
		result.category = "Trinket"
		result.description = "Personal trinket (possible future loot roll)"
	elif roll <= 75:
		result.category = "Debris"
		var d6 = d6_roll if d6_roll > 0 else (randi() % 6) + 1
		var debris_credits = (d6 % 3) + 1  # 1D3
		result.description = "Debris (%d credits)" % debris_credits
		result.credits = debris_credits
	elif roll <= 90:
		result.category = "Vital Info"
		result.description = "Vital info (Corporate Patron opportunity)"
	else:
		result.category = "Nothing"
		result.description = "Nothing of value"

	return result

func _roll_loot_table(d100_roll: int = 0, weapon1_type: int = 0, weapon2_type: int = 0, gear1_type: int = 0, gear2_type: int = 0, odds_type: int = 0, reward_type: int = 0) -> Dictionary:
	"""Roll on main Loot Table (Five Parsecs rulebook p.7084-7280)

	Args:
		d100_roll: For testing - main loot table roll (1-100)
		weapon1_type, weapon2_type: For testing - weapon subtable rolls
		gear1_type, gear2_type: For testing - gear subtable rolls
		odds_type: For testing - odds and ends subtable roll
		reward_type: For testing - rewards subtable roll
	"""
	var roll = d100_roll if d100_roll > 0 else (randi() % 100) + 1
	var result = {"roll": roll, "category": "", "item": "", "credits": 0, "rumors": 0, "requires_repair": false}

	if roll <= 25:
		# Weapon
		result.category = "Weapon"
		result.item = _roll_weapon_subtable(weapon1_type)
	elif roll <= 35:
		# Damaged weapons (2 items, need repair)
		result.category = "Damaged Weapons"
		var weapon1 = _roll_weapon_subtable(weapon1_type)
		var weapon2 = _roll_weapon_subtable(weapon2_type)
		result.item = "%s, %s (both damaged)" % [weapon1, weapon2]
		result.requires_repair = true
	elif roll <= 45:
		# Damaged gear (2 items, need repair)
		result.category = "Damaged Gear"
		var gear1 = _roll_gear_subtable(gear1_type)
		var gear2 = _roll_gear_subtable(gear2_type)
		result.item = "%s, %s (both damaged)" % [gear1, gear2]
		result.requires_repair = true
	elif roll <= 65:
		# Gear
		result.category = "Gear"
		result.item = _roll_gear_subtable(gear1_type)
	elif roll <= 80:
		# Odds and Ends
		result.category = "Odds and Ends"
		result.item = _roll_odds_and_ends_subtable(odds_type)
	else:
		# Rewards
		result.category = "Rewards"
		var reward_data = _roll_rewards_subtable(reward_type)
		result.item = reward_data.item
		result.credits = reward_data.credits
		result.rumors = reward_data.rumors

	return result

func _roll_weapon_subtable(category_roll: int = 0) -> String:
	"""Roll on Weapon Category Subtable (simplified representative items)

	Args:
		category_roll: For testing - weapon category roll (1-100)
	"""
	var roll = category_roll if category_roll > 0 else (randi() % 100) + 1

	if roll <= 35:
		var weapons = ["Hand Gun", "Military Rifle", "Shotgun", "Auto Rifle"]
		return weapons[randi() % weapons.size()]
	elif roll <= 50:
		var weapons = ["Hand Laser", "Infantry Laser", "Blast Rifle"]
		return weapons[randi() % weapons.size()]
	elif roll <= 65:
		var weapons = ["Plasma Rifle", "Fury Rifle", "Needle Rifle"]
		return weapons[randi() % weapons.size()]
	elif roll <= 85:
		var weapons = ["Blade", "Ripper Sword", "Boarding Saber"]
		return weapons[randi() % weapons.size()]
	else:
		# Grenades - for testing, just return first option
		return "3 Frakk Grenades"

func _roll_gear_subtable(d100_roll: int = 0) -> String:
	"""Roll on Gear Subtable (simplified representative items)

	Args:
		d100_roll: For testing - gear category roll (1-100)
	"""
	var roll = d100_roll if d100_roll > 0 else (randi() % 100) + 1

	if roll <= 20:
		# Gun Mods
		var mods = ["Assault Blade", "Bipod", "Stabilizer", "Laser Sight"]
		return mods[randi() % mods.size()]
	elif roll <= 40:
		# Gun Sights
		var sights = ["Laser Sight", "Quality Sight", "Seeker Sight"]
		return sights[randi() % sights.size()]
	elif roll <= 75:
		# Protective Items
		var armor = ["Combat Armor", "Frag Vest", "Flak Screen", "Deflector Field"]
		return armor[randi() % armor.size()]
	else:
		# Utility Items
		var utility = ["Motion Tracker", "Jump Belt", "Battle Visor", "Scanner Bot", "Communicator"]
		return utility[randi() % utility.size()]

func _roll_odds_and_ends_subtable(d100_roll: int = 0) -> String:
	"""Roll on Odds and Ends Subtable

	Args:
		d100_roll: For testing - odds and ends category roll (1-100)
	"""
	var roll = d100_roll if d100_roll > 0 else (randi() % 100) + 1

	if roll <= 55:
		# Consumables (2 uses)
		var consumables = ["Booster Pills", "Combat Serum", "Stim-pack", "Rage Out"]
		return "%s (2 uses)" % consumables[randi() % consumables.size()]
	elif roll <= 70:
		# Implants
		var implants = ["Boosted Arm", "Boosted Leg", "Health Boost", "Night Sight", "Pain Suppressor"]
		return implants[randi() % implants.size()]
	else:
		# Ship Items
		var ship_items = ["Med-patch", "Spare Parts", "Repair Bot", "Nano-doc", "Colonist Ration Packs"]
		return ship_items[randi() % ship_items.size()]

func _roll_rewards_subtable(d100_roll: int = 0, d6_roll1: int = 0, d6_roll2: int = 0) -> Dictionary:
	"""Roll on Rewards Subtable

	Args:
		d100_roll: For testing - rewards category roll (1-100)
		d6_roll1, d6_roll2: For testing - dice rolls for credits (used in various rewards)
	"""
	var roll = d100_roll if d100_roll > 0 else (randi() % 100) + 1
	var result = {"item": "", "credits": 0, "rumors": 0}

	if roll <= 10:
		result.item = "Documents"
		result.rumors = 1
	elif roll <= 20:
		result.item = "Data Files"
		result.rumors = 2
	elif roll <= 25:
		result.item = "Scrap"
		result.credits = 3
	elif roll <= 40:
		result.item = "Cargo Crate"
		result.credits = d6_roll1 if d6_roll1 > 0 else (randi() % 6) + 1
	elif roll <= 55:
		result.item = "Valuable Materials"
		var d6 = d6_roll1 if d6_roll1 > 0 else (randi() % 6) + 1
		result.credits = d6 + 2
	elif roll <= 70:
		result.item = "Rare Substance"
		var d6_1 = d6_roll1 if d6_roll1 > 0 else (randi() % 6) + 1
		var d6_2 = d6_roll2 if d6_roll2 > 0 else (randi() % 6) + 1
		result.credits = max(d6_1, d6_2)  # 2D6, pick highest
	elif roll <= 85:
		result.item = "Ship Parts"
		var d6 = d6_roll1 if d6_roll1 > 0 else (randi() % 6) + 1
		result.item += " (%d credits ship component discount)" % d6
		result.credits = 0  # Not immediate credits
	elif roll <= 90:
		result.item = "Military Ship Part"
		var d6 = d6_roll1 if d6_roll1 > 0 else (randi() % 6) + 1
		var discount = d6 + 2
		result.item += " (%d credits ship component discount)" % discount
	elif roll <= 95:
		result.item = "Mysterious Items (2 story points)"
	else:
		result.item = "Personal Item (3 story points)"

	return result
