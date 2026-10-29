class_name FPCM_AdvancementSystem
extends RefCounted

## Five Parsecs Character Advancement System
##
## Implements complete Five Parsecs advancement rules:
	## - Experience point tracking and spending
## - Stat improvements with dice rolling
## - Training and specialization paths
## - Experience-based benefits and abilities
## - Integration with dice system for advancement rolls

# Dependencies
# GlobalEnums available as autoload singleton
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")
const CompendiumTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
## Compendium p.147 — Bot upgrades are one of the three things Salvage may buy.
const SalvageLedgerRef = preload("res://src/core/campaign/SalvageLedger.gd")
const CompendiumEquipmentRef = preload("res://src/data/compendium_equipment.gd")
const BotUpgradeEffectsRef = preload("res://src/core/character/BotUpgradeEffects.gd")
## Core Rules p.74 "Bot manufacturing — All Bot upgrades are 1 credit cheaper."
const WorldTraitEffectsRef = preload("res://src/core/world/WorldTraitEffects.gd")

## ============================================================================
## THE ONE WAY TO ASK "DOES THIS CREW MEMBER HAVE COURSE X?"
## ============================================================================
##
## `acquired_training` is the single source of truth (Character.gd:1067). The
## `has_*_training` BOOLEANS that `_apply_training_benefits()` below writes via
## `Object.set()` are silent no-ops — no such property is declared on Character —
## and `purchase_training()`, their only producer, has ZERO callers. The live
## grant path is `Character.add_training()`, reached from TrainingSelectionDialog
## and CharacterDetailsScreen.
##
## That combination is why `RedZoneSystem.can_obtain_license()` read
## `has_broker_training` and never once found it: a crew member who PURCHASED
## Broker training got no Red Zone licence discount, only one who happened to roll
## a broker-ish background trait at creation.
##
## Dual-shape on purpose. Crew are Dictionaries on a loaded save and Character
## RESOURCES on a fresh campaign, and the Dictionary branch must come FIRST —
## `has_method()` on a Dictionary is an invalid call that unwinds the caller.
static func member_has_training(member: Variant, course_id: String) -> bool:
	if member == null:
		return false
	if member is Dictionary:
		var d: Dictionary = member
		var list: Variant = d.get("acquired_training", [])
		if not (list is Array) or (list as Array).is_empty():
			list = d.get("training", [])
		return list is Array and course_id in (list as Array)
	if member.has_method("has_training"):
		return member.has_training(course_id)
	if "acquired_training" in member and member.acquired_training is Array:
		return course_id in member.acquired_training
	return false


## True when ANY member of `crew` holds the course. Several p.125 courses are
## crew-wide in effect ("When rolling to obtain licenses ... add +1") rather than
## tied to the figure that acts.
static func crew_has_training(crew: Array, course_id: String) -> bool:
	for member: Variant in crew:
		if member_has_training(member, course_id):
			return true
	return false


# Signals
signal character_advanced(character: Resource, advancement_type: String, new_value: int)
signal experience_gained(character: Resource, amount: int, source: String)
signal training_completed(character: Resource, training_type: String)
signal bot_upgrade_installed(bot: Resource, upgrade_id: String, upgrade_data: Dictionary)

# Manager references
var dice_manager: Node = null
var _campaign_manager: Resource = null

# Advancement rules from Five Parsecs Core Rules
var stat_advancement_costs: Dictionary = {
	"reactions": 7,
	"combat_skill": 7,
	"toughness": 6,
	"savvy": 5,
	"speed": 5,
	"luck": 10
}

var stat_max_values: Dictionary = {
	"reactions": 6,
	"combat_skill": 5,
	"toughness": 6,
	"savvy": 5,
	"speed": 8,
	"luck": 1 # Base humans, some species can go higher
}


## The XP cost to raise `stat_name` by +1.
##
## Compendium p.32 "Slower Progression" reprints the whole Core Rules p.123
## Ability Increase Table with harsher numbers (Reactions 7->8, Combat 7->8,
## Toughness 6->8). Read through here, never straight off the dictionary, so the
## option cannot end up applied at some advancement sites and not others.
##
## Bot upgrades read this too, and that is correct: p.123 says a Bot pays
## "credits equal to the XP cost", so a raised XP cost raises the credit price
## by the book's own rule rather than by a second decision made here.
func get_stat_cost(stat_name: String) -> int:
	return CompendiumTogglesRef.progression_cost(
		stat_name, int(stat_advancement_costs.get(stat_name, 0)))


## The maximum value `stat_name` may reach.
##
## Slower Progression also lowers three maximums (Reactions 6->4, Combat +5->+3,
## Toughness 6->5). Applied through progression_maximum(), which can only LOWER
## the base — see the note there on why the Luck row must not raise a non-Human
## cap from 1 to 3.
func get_stat_max(stat_name: String, fallback: int = 5) -> int:
	return CompendiumTogglesRef.progression_maximum(
		stat_name, int(stat_max_values.get(stat_name, fallback)))

var training_costs: Dictionary = {
	# Core Rules p.125 — 7 Advanced Training courses
	"pilot": 20,
	"medical": 20,
	"mechanic": 15,
	"broker": 15,
	"security": 10,
	"merchant": 10,
	"bot_tech": 10,
	# Compendium p.22 — Psionic advancement (XP cost, not credits)
	"psionics": 12, # Acquire new psionic power (Compendium p.22)
	"psionics_enhance": 6 # Enhance existing psionic power (Compendium p.22)
}

# Bot stat upgrades — Core Rules p.123:
# "Bot characters may install upgrades to any ability score by paying credits
#  equal to the XP cost. Each ability score can be upgraded only once."
# Cost in credits = stat_advancement_costs value for that stat.
# Compendium p.28 has separate functional upgrades (Built-in weapon, Jump module,
# etc.) — those are NOT stat boosts and should be implemented separately if needed.

# Experience gain rates — Core Rules p.123 XP table
# Characters that flee in the first 2 rounds receive 0 XP.
var experience_sources: Dictionary = {
	"casualty": 1,              # Became a casualty
	"survived_no_win": 2,       # Survived, but did not Win
	"survived_and_won": 3,      # Survived and Won
	"first_casualty": 1,        # First character to inflict a casualty
	"killed_unique_individual": 1, # Killed Unique Individual
	"easy_mode": 1,             # Campaign is on Easy mode
	"final_quest_stage": 1,     # Crew completed the final stage of a Quest
}

func _init() -> void:
	_initialize_dice_manager()

func _initialize_dice_manager() -> void:
	## Initialize dice manager reference
	# Will be injected by parent system
	pass

## Award experience to a character

func award_experience(character: Resource, amount: int, source: String) -> void:
	## Award experience points to a character
	if not character:
		return

	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)
	var new_xp = current_xp + amount

	if character and character.has_method("set"): character.set("experience_points", new_xp)

	# Track experience sources for stats
	var xp_sources = Godot4Utils.safe_get_property(character, "experience_sources", {})

	xp_sources[source] = xp_sources.get(source, 0) + amount
	if character and character.has_method("set"): character.set("experience_sources", xp_sources)

	experience_gained.emit(character, amount, source)

	pass # XP awarded

## Check if character can afford an advancement
func can_afford_advancement(character: Resource, advancement_type: String, advancement_target: String = "") -> bool:
	## Check if character has enough XP for advancement

	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)
	var cost = _get_advancement_cost(advancement_type, advancement_target)

	return current_xp >= cost

## Get the cost of an advancement
func _get_advancement_cost(advancement_type: String, target: String = "") -> int:
	## Get the XP cost for a specific advancement (Core Rules p.123-125)
	match advancement_type:
		"stat":
			return get_stat_cost(target)
		"training":
			return training_costs.get(target, 0)
		_:
			return 0

## Attempt to advance a character stat
func advance_stat(character: Resource, stat_name: String) -> bool:
	## Attempt to advance a character stat using Five Parsecs rules
	if not character:
		return false

	var cost = get_stat_cost(stat_name)
	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)
	var current_stat = Godot4Utils.safe_get_property(character, stat_name, 0)
	var max_stat = get_stat_max(stat_name)

	# Engineer restriction: Cannot raise Toughness above 4 (Core Rules p.124)
	var char_class: String = Godot4Utils.safe_get_property(character, "character_class", "")
	if char_class.to_upper() == "ENGINEER" and stat_name == "toughness":
		max_stat = mini(max_stat, 4)

	# Psionic restriction: Cannot increase Combat Skill through XP (Compendium p.20)
	var psionic_power_val: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
	if psionic_power_val != "" and stat_name == "combat_skill":
		return false

	# Minor Alien: One stat has reduced XP cost (Core Rules p.22)
	var species_id_val: String = Godot4Utils.safe_get_property(
		character, "species_id", "")
	if species_id_val.to_lower() == "minor_alien":
		var discount_stat: String = Godot4Utils.safe_get_property(
			character, "xp_discount_stat", "")
		if discount_stat == stat_name:
			cost = maxi(cost - 1, 1)

	# Check if advancement is possible
	if current_xp < cost:
		return false

	if current_stat >= max_stat:
		return false

	# Core Rules p.123: Direct spend — pay XP cost, increase stat by +1. No roll needed.
	var new_stat_value = current_stat + 1
	if character and character.has_method("set"): character.set(stat_name, new_stat_value)
	if character and character.has_method("set"): character.set("experience_points", current_xp - cost)

	character_advanced.emit(character, "stat_" + str(stat_name), new_stat_value)
	return true

## Purchase training for a character
func purchase_training(character: Resource, training_type: String) -> bool:
	## Purchase training for a character
	if not character:
		return false

	var cost = training_costs.get(training_type, 0)
	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)

	if current_xp < cost:
		return false

	# Check if character already has this training
	var current_training = Godot4Utils.safe_get_property(character, "training", [])
	if training_type in current_training:
		return false

	# Apply training
	current_training.append(training_type)
	if character and character.has_method("set"): character.set("training", current_training)
	if character and character.has_method("set"): character.set("experience_points", current_xp - cost)

	training_completed.emit(character, training_type)

	pass # Training completed

	# Apply training benefits
	_apply_training_benefits(character, training_type)

	return true

## Apply benefits from completed training
## Core Rules p.125: Training effects are rule modifications checked during
## specific game phases, NOT generic stat bonuses. We set boolean flags here;
## the actual effects are applied at the relevant game phases.
func _apply_training_benefits(character: Resource, training_type: String) -> void:
	if not character or not character.has_method("set"):
		return

	match training_type:
		"pilot":
			# Core Rules p.125: If Starship Travel event calls for Savvy test,
			# roll 2D6 pick better die + add +2 to score.
			character.set("has_pilot_training", true)

		"medical":
			# Core Rules p.125: After battle, nominate a casualty to roll twice
			# on Injury Table, pick better result. Crew member must have been in
			# battle and not become a casualty. Shuttle allows remote application.
			character.set("has_medical_training", true)

		"mechanic":
			# Core Rules p.125: Ship in need of Repairs: repair +1 Hull Point per
			# campaign turn (2 total per turn). Engineers count XP spent as double.
			character.set("has_mechanic_training", true)

		"broker":
			# Core Rules p.125: Add +1 when rolling for licenses, Advanced
			# Training applications, or searching for Patrons.
			character.set("has_broker_training", true)

		"security":
			# Core Rules p.125: If this crew member is in your squad, add +1 to
			# Seize the Initiative roll. Ferals obtain at -2 cost.
			character.set("has_security_training", true)

		"merchant":
			# Core Rules p.125: When this crew member Trades, reroll one Trade
			# roll per campaign turn. Must accept new roll.
			character.set("has_merchant_training", true)

		"bot_tech":
			# Core Rules p.125: All Bot upgrades cost 1 credit less. If Bot/Soulless
			# rolls for post-battle injury, roll twice pick better.
			character.set("has_bot_tech_training", true)

		"psionics":
			# Compendium p.22: Acquire Psionic Power (12 XP)
			# Roll D10 for power. If duplicate, modify roll ±1.
			var psionic_data: Dictionary = _load_psionic_powers_json()
			var power_ids: Array = psionic_data.keys()
			if power_ids.is_empty():
				return
			var roll_index: int = _roll_dice("Psionic Acquisition", "D10") - 1
			roll_index = clampi(roll_index, 0, power_ids.size() - 1)
			var new_power_id: String = power_ids[roll_index]
			var current_power: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
			if new_power_id == current_power and power_ids.size() > 1:
				var alt_index: int = (roll_index + 1) % power_ids.size()
				new_power_id = power_ids[alt_index]
			character.set("psionic_power", new_power_id)

		"psionics_enhance":
			# Compendium p.22: Power Enhancement (6 XP)
			# +1D6 to projection roll for chosen power. One enhancement per power.
			var has_power: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
			if has_power != "":
				character.set("psionic_power_enhanced", true)

## Get available advancements for a character

func get_available_advancements(character: Resource) -> Array[Dictionary]:
	## Get list of available advancements for a character.
	##
	## The element type MUST match the signature. A bare `Array` here returns fine to
	## the compiler and then dies at runtime on
	##     "Trying to return an array of type "Array" where expected return type is
	##      "Array[Dictionary]"."
	## which ABORTS the function silently — the caller gets nothing and the process
	## keeps running. Narrowed rather than widening the signature because callers of
	## the sibling CharacterAdvancementService assign straight into
	## `var options: Array[Dictionary]` (PostBattleSequence :1800,
	## CharacterUpgradeDialog :133), and only Dictionary literals are appended below.
	var advancements: Array[Dictionary] = []
	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)

	# Stat advancements
	for stat_name in stat_advancement_costs.keys():
		var current_stat = Godot4Utils.safe_get_property(character, stat_name, 0)
		var max_stat = get_stat_max(stat_name)
		var cost = get_stat_cost(stat_name)

		# Engineer restriction: Cannot raise Toughness above 4 (Core Rules p.124)
		var adv_char_class: String = Godot4Utils.safe_get_property(character, "character_class", "")
		if adv_char_class.to_upper() == "ENGINEER" and stat_name == "toughness":
			max_stat = mini(max_stat, 4)

		# Psionic restriction: Cannot increase Combat Skill through XP (Compendium p.20)
		var adv_psionic: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
		if adv_psionic != "" and stat_name == "combat_skill":
			continue

		if current_stat < max_stat and current_xp >= cost:
			advancements.append({
				"type": "stat",
				"target": stat_name,
				"cost": cost,
				"current_value": current_stat,
				"max_value": max_stat,
				"description": "Advance %s from %d to %d" % [stat_name.capitalize(), current_stat, current_stat + 1]
			})

	# Training advancements
	var current_training = Godot4Utils.safe_get_property(character, "training", [])
	for training_type in training_costs.keys():
		var cost = training_costs[training_type]

		if training_type not in current_training and current_xp >= cost:
			advancements.append({
				"type": "training",
				"target": training_type,
				"cost": cost,
				"description": "Learn %s training" % training_type.capitalize()
			})

	return advancements

# calculate_battle_experience() and award_post_battle_experience() were
# DELETED here. They were a second, divergent implementation of the Core
# Rules p.123 XP table with ZERO callers — award_* was called by nothing and
# calculate_* only by award_*. The live path is
# ExperienceTrainingProcessor._calculate_crew_xp(), reached from
# PostBattlePhase.
#
# Worse than merely dead: calculate_battle_experience() read `fled_early` as
# an ARRAY of character names and `crew_casualties` likewise, while the live
# battle-result contract carries fled_early as a BOOL and casualties as an
# array of crew-id dicts. Wiring this up would not have failed loudly — the
# `in` test against a bool errors and unwinds the function, so XP would have
# silently stopped. Removing it removes the trap.

## Get character advancement statistics

func get_advancement_stats(character: Resource) -> Dictionary:
	## Get advancement statistics for a character
	return {
		"experience_points": Godot4Utils.safe_get_property(character, "experience_points", 0),
		"total_stat_improvements": _count_stat_improvements(character),
		"training_completed": Godot4Utils.safe_get_property(character, "training", []).size(),
		"advancement_attempts": Godot4Utils.safe_get_property(character, "advancement_attempts", 0),
		"advancement_successes": Godot4Utils.safe_get_property(character, "advancement_successes", 0)
	}

func _count_stat_improvements(character: Resource) -> int:
	## Count total stat improvements above base values
	var improvements: int = 0
	var base_stats = {"reactions": 1, "combat_skill": 0, "toughness": 3, "savvy": 1, "speed": 4, "luck": 0}

	for stat_name in base_stats.keys():
		var current = Godot4Utils.safe_get_property(character, stat_name, base_stats[stat_name])
		var base = base_stats[stat_name]
		improvements += max(0, current - base)

	return improvements

## Roll dice for advancement
func _roll_dice(context: String, pattern: String) -> int:
	## Roll dice using the dice system
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, pattern)
	else:
		match pattern:
			"D6": return randi_range(1, 6)
			"D10": return randi_range(1, 10)
			_: return randi_range(1, 6)

## Bot Stat Upgrade System — Core Rules p.123:
## "Bot characters may install upgrades to any ability score by paying credits
##  equal to the XP cost. Each ability score can be upgraded only once."
## Bots do NOT receive XP. Soulless use the normal XP process and cannot buy
## Bot upgrades. Bot Tech training reduces all bot upgrade costs by 1 credit.

func get_available_bot_upgrades(bot: Resource) -> Array[Dictionary]:
	## Get list of available stat upgrades for a bot (Core Rules p.123)
	var available: Array[Dictionary] = []

	if not bot or not _is_bot(bot):
		return available

	var upgraded_stats: Array = Godot4Utils.safe_get_property(bot, "bot_upgraded_stats", [])

	for stat_name in stat_advancement_costs.keys():
		if stat_name in upgraded_stats:
			continue  # Each stat can only be upgraded once

		# The price the sheet SHOWS must be the price install_bot_upgrade() CHARGES:
		# world trait (p.74) and Bot technician (p.125) included.
		var cost: int = _bot_upgrade_cost(stat_name, null)
		var current_val: int = Godot4Utils.safe_get_property(bot, stat_name, 0)
		var max_val: int = get_stat_max(stat_name, 6)

		if current_val >= max_val:
			continue

		available.append({
			"id": stat_name,
			"name": "+1 %s" % stat_name.capitalize(),
			"cost": cost,
			"effects": {stat_name: 1},
			"description": "+1 %s (credits = XP cost)" % stat_name.capitalize()
		})

	return available

func can_install_bot_upgrade(bot: Resource, stat_name: String, campaign_credits: int) -> bool:
	## Check if bot can upgrade a stat (Core Rules p.123)
	if not bot or not _is_bot(bot):
		return false
	if _is_soulless(bot):
		return false

	if not stat_advancement_costs.has(stat_name):
		return false

	var upgraded_stats: Array = Godot4Utils.safe_get_property(bot, "bot_upgraded_stats", [])
	if stat_name in upgraded_stats:
		return false

	var cost: int = _bot_upgrade_cost(stat_name, null)
	return campaign_credits >= cost

## `game_state_ref` is the CREDITS owner, GameStateManager. It was typed Resource
## while its one caller, CharacterDetailsScreen, passed the GameState autoload (a
## Node), so the call was rejected at the argument check and no Bot upgrade could
## ever be installed from the character sheet.
func install_bot_upgrade(bot: Resource, stat_name: String, game_state_ref: Object) -> bool:
	## Install a bot stat upgrade by spending credits (Core Rules p.123)
	if not bot or not game_state_ref:
		return false

	if not _is_bot(bot):
		return false

	if _is_soulless(bot):
		return false

	if not stat_advancement_costs.has(stat_name):
		return false

	var upgraded_stats: Array = Godot4Utils.safe_get_property(bot, "bot_upgraded_stats", [])
	if stat_name in upgraded_stats:
		return false

	var cost: int = _bot_upgrade_cost(stat_name, game_state_ref)
	if not pay_for_bot_upgrade(game_state_ref, cost):
		return false

	# Apply +1 to the stat
	var current_val: int = Godot4Utils.safe_get_property(bot, stat_name, 0)
	var max_val: int = get_stat_max(stat_name, 6)
	var new_val: int = mini(current_val + 1, max_val)

	if bot.has_method("set"):
		bot.set(stat_name, new_val)

	# Track that this stat has been upgraded (each stat only once)
	upgraded_stats.append(stat_name)
	if bot.has_method("set"):
		# Declared on Character (and saved) since 2026-10-29. Before that this set()
		# was a silent no-op, so "each ability score can be upgraded only once"
		# (p.123) was never recorded.
		bot.set("bot_upgraded_stats", upgraded_stats)

	bot_upgrade_installed.emit(bot, stat_name, {"stat": stat_name, "cost": cost, "new_value": new_val})
	return true


## Core Rules p.74, verbatim: "Bot manufacturing — All Bot upgrades are 1 credit
## cheaper."
##
## `WorldTraitEffects.bot_upgrade_cost()` implemented this and had ZERO callers,
## so the trait was a paragraph of text. Applied at BOTH the affordability check
## and the charge, or the button greys out at the undiscounted price on a world
## the crew can actually afford — the guard-applied-to-N-1-of-N shape.
func _bot_upgrade_cost(stat_name: String, game_state_ref: Variant) -> int:
	var base: int = get_stat_cost(stat_name)
	var campaign: Variant = _campaign_for_salvage(game_state_ref)
	if campaign == null:
		return base
	return bot_upgrade_price(base, campaign)


## One price rule for EVERY Bot upgrade, the p.123 stat upgrades here and the
## Compendium p.26 upgrades in the Advancement phase: Core Rules p.74 "Bot
## manufacturing — All Bot upgrades are 1 credit cheaper", then p.125 Bot
## technician.
static func bot_upgrade_price(base: int, campaign: Variant) -> int:
	if campaign == null:
		return base
	return bot_technician_price(WorldTraitEffectsRef.bot_upgrade_cost(
		base, WorldTraitEffectsRef.traits_for_current_world(campaign)), campaign)


## Core Rules p.125, Bot technician: "All Bot upgrades cost 1 credit less."
## Compendium p.26 applies it to the New Bot Upgrades too. Crew-wide, like Broker:
## the course is held by a crew member, not by the Bot. `bot_tech` is the legacy
## spelling a dictionary crew member may still carry (see Character.has_training).
static func bot_technician_price(price: int, campaign: Variant) -> int:
	if campaign == null or not campaign.has_method("get_crew_members"):
		return price
	var crew: Array = campaign.get_crew_members()
	if crew_has_training(crew, "bot_technician") or crew_has_training(crew, "bot_tech"):
		return maxi(0, price - 1)
	return price


## Charge a Bot upgrade: Salvage first (Compendium p.147), then credits from
## `game_state_ref`, the credits owner (GameStateManager). Spends nothing and
## returns false when the crew cannot pay. Shared by the p.123 stat upgrades here
## and the Compendium p.26 upgrades sold in Trading, so both charge the same way.
static func pay_for_bot_upgrade(game_state_ref: Object, cost: int) -> bool:
	if game_state_ref == null:
		return false
	var current_credits: int = 0
	if game_state_ref.has_method("get_credits"):
		current_credits = game_state_ref.get_credits()
	else:
		current_credits = Godot4Utils.safe_get_property(game_state_ref, "credits", 0)

	# Compendium p.147: "When purchasing any of the following, you may cash in
	# Salvage to offset the cost in Credits. 1 unit of Salvage equals 1 Credit
	# ONLY when purchasing: Ship repairs / Ship modules / Bot upgrades."
	#
	# Applied BEFORE the affordability check so salvage can actually make an
	# upgrade reachable, and refunded below if the credit half then fails —
	# salvage that bought nothing was never "cashed in".
	var campaign_for_salvage: Variant = _salvage_campaign(game_state_ref)
	var salvage_paid: int = 0
	if campaign_for_salvage != null:
		var offset: Dictionary = SalvageLedgerRef.apply_offset(
			campaign_for_salvage, cost, SalvageLedgerRef.PURPOSE_BOT_UPGRADE)
		salvage_paid = int(offset.get("salvage_applied", 0))
	var credit_cost: int = maxi(0, cost - salvage_paid)

	if current_credits < credit_cost:
		if campaign_for_salvage != null and salvage_paid > 0:
			SalvageLedgerRef.add_units(campaign_for_salvage, salvage_paid)
		return false

	# Deduct credits
	if credit_cost > 0:
		if game_state_ref.has_method("remove_credits"):
			if not game_state_ref.remove_credits(credit_cost):
				if campaign_for_salvage != null and salvage_paid > 0:
					SalvageLedgerRef.add_units(campaign_for_salvage, salvage_paid)
				return false
		elif game_state_ref.has_method("set"):
			game_state_ref.set("credits", current_credits - credit_cost)
	return true


## Compendium p.26 New Bot Upgrades offered to `member`, each priced by
## bot_upgrade_price(). The Built-in weapon has one row per weapon the Bot carries,
## priced from that weapon's profile. Empty for anyone but a Bot, and when the
## content is off.
static func bot_upgrade_options(member: Variant, campaign: Variant) -> Array:
	var out: Array = []
	if not BotUpgradeEffectsRef.is_upgradeable(member):
		return out
	for item: Variant in CompendiumEquipmentRef.get_bot_upgrades():
		if not item is Dictionary:
			continue
		if str(item.get("id", "")) == BotUpgradeEffectsRef.BUILTIN_WEAPON:
			for weapon: String in BotUpgradeEffectsRef.carried_weapons(member):
				out.append(_bot_upgrade_row(item,
					BotUpgradeEffectsRef.builtin_weapon_cost(weapon), campaign, weapon))
			continue
		out.append(_bot_upgrade_row(item, int(item.get("cost", 0)), campaign, ""))
	return out


static func _bot_upgrade_row(item: Dictionary, base_cost: int, campaign: Variant,
		weapon: String) -> Dictionary:
	var name: String = str(item.get("name", "Bot upgrade"))
	return {
		"id": str(item.get("id", "")),
		"name": name if weapon.is_empty() else "%s: %s" % [name, weapon],
		"cost": bot_upgrade_price(base_cost, campaign),
		"builtin_weapon": weapon,
		"description": str(item.get("description", "")),
	}


## Compendium p.26: "Only one upgrade can be installed per campaign turn." Kept on
## the campaign and keyed by the completed-turn count, so rebuilding a screen
## cannot reset it.
static func bot_upgrade_installed_this_turn(campaign: Variant) -> bool:
	if campaign == null or not ("progress_data" in campaign):
		return false
	var pd: Dictionary = campaign.progress_data
	return pd.has("bot_upgrade_turn") \
		and int(pd["bot_upgrade_turn"]) == int(pd.get("turns_played", 0))


## Why `option` cannot be bought for `member` now, or "" when it can. Salvage
## counts toward the price (Compendium p.147), because pay_for_bot_upgrade()
## spends it first.
static func bot_upgrade_blocked_reason(member: Variant, option: Dictionary,
		credits: int, campaign: Variant) -> String:
	if str(option.get("id", "")) in BotUpgradeEffectsRef.installed(member):
		return "Already installed: a Bot can have one of each (Compendium p.26)."
	if bot_upgrade_installed_this_turn(campaign):
		return "Only one upgrade can be installed per campaign turn (Compendium p.26)."
	var salvage: int = SalvageLedgerRef.get_units(campaign) if campaign != null else 0
	if credits + salvage < int(option.get("cost", 0)):
		return "Not enough credits (need %d)." % int(option.get("cost", 0))
	return ""


## Buy `option` for `member`: pay (Salvage, then credits through `gsm`), install
## it, and record the turn. Spends nothing and returns false when blocked.
static func buy_bot_upgrade(member: Variant, option: Dictionary, gsm: Object,
		campaign: Variant) -> bool:
	var credits: int = int(gsm.get_credits()) \
		if gsm != null and gsm.has_method("get_credits") else 0
	if not bot_upgrade_blocked_reason(member, option, credits, campaign).is_empty():
		return false
	if not pay_for_bot_upgrade(gsm, int(option.get("cost", 0))):
		return false
	var upgrade_id: String = str(option.get("id", ""))
	var weapon: String = str(option.get("builtin_weapon", ""))
	if member is Dictionary:
		var ids: Array = member.get("bot_upgrades", [])
		if upgrade_id not in ids:
			ids.append(upgrade_id)
		member["bot_upgrades"] = ids
		if not weapon.is_empty():
			member["builtin_weapon"] = weapon
	elif member is Object:
		if member.has_method("add_bot_upgrade"):
			member.add_bot_upgrade(upgrade_id)
		if not weapon.is_empty():
			member.set("builtin_weapon", weapon)
	if campaign != null and "progress_data" in campaign:
		campaign.progress_data["bot_upgrade_turn"] = int(
			campaign.progress_data.get("turns_played", 0))
	return true


func _campaign_for_salvage(game_state_ref: Variant) -> Variant:
	return _salvage_campaign(game_state_ref)


## The campaign that owns the salvage ledger.
##
## Callers pass the credits owner, GameStateManager, which has no
## `current_campaign`, so the campaign is normally found through the GameState
## autoload below. An argument that does carry `current_campaign` is read first.
## This is a RefCounted, so get_node_or_null() is unavailable: the tree is reached
## via the main loop, per the Engine.has_singleton gotcha.
static func _salvage_campaign(game_state_ref: Variant) -> Variant:
	if game_state_ref != null and "current_campaign" in game_state_ref:
		var c: Variant = game_state_ref.current_campaign
		if c != null:
			return c
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var gs: Node = (loop as SceneTree).root.get_node_or_null("/root/GameState")
	if gs == null or not ("current_campaign" in gs):
		return null
	return gs.current_campaign


func _is_soulless(character: Resource) -> bool:
	## Errata v1.06 corrects Core Rules p.17. The book reads "They may also have
	## Bot Upgrades installed, but must pay 1.5 times the normal cost (rounded
	## up)"; the errata replaces that outright with "Soulless characters CANNOT
	## install Bot upgrades." The errata wins.
	##
	## Checked EXPLICITLY rather than relying on _is_bot() returning false. Bot
	## and Soulless are separate flags today, so a Soulless already fell through —
	## but only by accident, and data/character_species.json was still telling the
	## player the 1.5x rule was available (now corrected). One flag change
	## upstream would have silently re-enabled a mechanic the errata removed.
	if not character:
		return false
	if Godot4Utils.safe_get_property(character, "is_soulless", false):
		return true
	var sid: String = str(Godot4Utils.safe_get_property(character, "species_id", ""))
	return sid.to_lower() == "soulless"

func _is_bot(character: Resource) -> bool:
	## Check if character is a bot.
	##
	## THE BUG THIS FIXES: this checked has_method("is_bot") and then fell back to
	## comparing `origin` against "BOT"/"Bot". Character has NO is_bot() method —
	## `is_bot` is an @export PROPERTY (Character.gd:132) — and `origin` is a
	## validated species string defaulting to "HUMAN". So the property that
	## actually marks a Bot was never read, and _is_bot() returned false for every
	## real Bot. Since it gates both can_install_bot_upgrade() and
	## install_bot_upgrade(), Bot upgrades (Core Rules p.123) were unreachable for
	## the entire crew.
	if not character:
		return false

	# The authoritative marker.
	if Godot4Utils.safe_get_property(character, "is_bot", false):
		return true

	# A method form, for any shape that exposes one instead.
	if character.has_method("is_bot"):
		return character.is_bot()

	# Legacy fallbacks: species_id, then the origin string, case-insensitively —
	# the old comparison missed a lowercase "bot", which is how species ids are
	# actually spelled.
	if str(Godot4Utils.safe_get_property(character, "species_id", "")).to_lower() == "bot":
		return true
	return str(Godot4Utils.safe_get_property(character, "origin", "")).to_lower() == "bot"


func _load_psionic_powers_json() -> Dictionary:
	## Load psionic powers from JSON data file (same source as CharacterCreator)
	var path := "res://data/psionic_powers.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("AdvancementSystem: Could not open psionic_powers.json at %s" % path)
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_warning("AdvancementSystem: Failed to parse psionic_powers.json")
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
