class_name Item
extends Resource

enum ItemType { CONSUMABLE, PROTECTIVE, IMPLANT, UTILITY, ONBOARD }

@export var name: String
@export var type: ItemType
@export var effect: Callable

func _init(_name: String = "", _type: ItemType = ItemType.CONSUMABLE, _effect: Callable = Callable()):
	name = _name
	type = _type
	effect = _effect

func use(user: Character, target: Character = null):
	effect.call(user, target)

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": type,
		"effect": effect.get_method()
	}

static func deserialize(data: Dictionary) -> Item:
	return Item.new(data["name"], data["type"], Callable(Item, data["effect"]))

static func create_item_database() -> Dictionary:
	return {
		"Booster pills": Item.new("Booster pills", ItemType.CONSUMABLE, Callable(Item, "effect_booster_pills")),
		"Combat serum": Item.new("Combat serum", ItemType.CONSUMABLE, Callable(Item, "effect_combat_serum")),
		"Kiranin crystals": Item.new("Kiranin crystals", ItemType.CONSUMABLE, Callable(Item, "effect_kiranin_crystals")),
		"Rage out": Item.new("Rage out", ItemType.CONSUMABLE, Callable(Item, "effect_rage_out")),
		"Still": Item.new("Still", ItemType.CONSUMABLE, Callable(Item, "effect_still")),
		"Stim-pack": Item.new("Stim-pack", ItemType.CONSUMABLE, Callable(Item, "effect_stim_pack")),
		"Battle dress": Item.new("Battle dress", ItemType.PROTECTIVE, Callable(Item, "effect_battle_dress")),
		"Camo cloak": Item.new("Camo cloak", ItemType.PROTECTIVE, Callable(Item, "effect_camo_cloak")),
		"Combat armor": Item.new("Combat armor", ItemType.PROTECTIVE, Callable(Item, "effect_combat_armor")),
		"Deflector field": Item.new("Deflector field", ItemType.PROTECTIVE, Callable(Item, "effect_deflector_field")),
		"Flak screen": Item.new("Flak screen", ItemType.PROTECTIVE, Callable(Item, "effect_flak_screen")),
		"Flex-armor": Item.new("Flex-armor", ItemType.PROTECTIVE, Callable(Item, "effect_flex_armor")),
		"Frag vest": Item.new("Frag vest", ItemType.PROTECTIVE, Callable(Item, "effect_frag_vest")),
		"Screen generator": Item.new("Screen generator", ItemType.PROTECTIVE, Callable(Item, "effect_screen_generator")),
		"Stealth gear": Item.new("Stealth gear", ItemType.PROTECTIVE, Callable(Item, "effect_stealth_gear")),
		"AI companion": Item.new("AI companion", ItemType.IMPLANT, Callable(Item, "effect_ai_companion")),
		"Body wire": Item.new("Body wire", ItemType.IMPLANT, Callable(Item, "effect_body_wire")),
		"Boosted arm": Item.new("Boosted arm", ItemType.IMPLANT, Callable(Item, "effect_boosted_arm")),
		"Boosted leg": Item.new("Boosted leg", ItemType.IMPLANT, Callable(Item, "effect_boosted_leg")),
		"Cyber hand": Item.new("Cyber hand", ItemType.IMPLANT, Callable(Item, "effect_cyber_hand")),
		"Genetic defenses": Item.new("Genetic defenses", ItemType.IMPLANT, Callable(Item, "effect_genetic_defenses")),
		"Health boost": Item.new("Health boost", ItemType.IMPLANT, Callable(Item, "effect_health_boost")),
		"Nerve adjuster": Item.new("Nerve adjuster", ItemType.IMPLANT, Callable(Item, "effect_nerve_adjuster")),
		"Neural optimization": Item.new("Neural optimization", ItemType.IMPLANT, Callable(Item, "effect_neural_optimization")),
		"Night sight": Item.new("Night sight", ItemType.IMPLANT, Callable(Item, "effect_night_sight")),
		"Pain suppressor": Item.new("Pain suppressor", ItemType.IMPLANT, Callable(Item, "effect_pain_suppressor"))
	}

static func effect_booster_pills(user: Character, _target: Character):
	user.remove_all_stun()
	user.double_speed_this_round()

static func effect_combat_serum(user: Character, _target: Character):
	user.increase_speed(2)
	user.increase_reactions(2)

static func effect_kiranin_crystals(user: Character, _target: Character):
	# Implement the dazzling effect
	pass

static func effect_rage_out(user: Character, _target: Character):
	user.increase_speed(2)
	user.increase_brawling(1)
	if user.race == CharacterCreationData.Race.KERIN:
		user.set_rage_state(true)

static func effect_still(user: Character, _target: Character):
	user.increase_hit(1)
	user.set_immobile(2)  # Immobile for this round and the next

static func effect_stim_pack(user: Character, _target: Character):
	user.prevent_next_casualty()

static func effect_battle_dress(user: Character, _target: Character):
	user.increase_reactions(1, 4)  # Increase by 1, max 4
	user.set_saving_throw(5)

static func effect_camo_cloak(user: Character, _target: Character):
	user.set_camo_cloak(true)

static func effect_combat_armor(user: Character, _target: Character):
	user.set_saving_throw(5)

static func effect_deflector_field(user: Character, _target: Character):
	user.set_deflector_field(true)

static func effect_flak_screen(user: Character, _target: Character):
	user.set_flak_screen(true)

static func effect_flex_armor(user: Character, _target: Character):
	user.set_flex_armor(true)

static func effect_frag_vest(user: Character, _target: Character):
	user.set_frag_vest(true)

static func effect_screen_generator(user: Character, _target: Character):
	user.set_screen_generator(true)

static func effect_stealth_gear(user: Character, _target: Character):
	user.set_stealth_gear(true)

static func effect_ai_companion(user: Character, _target: Character):
	user.set_ai_companion(true)

static func effect_body_wire(user: Character, _target: Character):
	user.increase_reactions(1)

static func effect_boosted_arm(user: Character, _target: Character):
	user.set_boosted_arm(true)

static func effect_boosted_leg(user: Character, _target: Character):
	user.increase_speed(1)
	user.increase_dash_speed(1)

static func effect_cyber_hand(user: Character, _target: Character):
	user.set_cyber_hand(true)

static func effect_genetic_defenses(user: Character, _target: Character):
	user.set_genetic_defenses(true)

static func effect_health_boost(user: Character, _target: Character):
	user.set_health_boost(true)
	if user.toughness == 3:
		user.increase_toughness(1)

static func effect_nerve_adjuster(user: Character, _target: Character):
	user.set_nerve_adjuster(true)

static func effect_neural_optimization(user: Character, _target: Character):
	user.set_neural_optimization(true)

static func effect_night_sight(user: Character, _target: Character):
	user.set_night_sight(true)

static func effect_pain_suppressor(user: Character, _target: Character):
	user.set_pain_suppressor(true)
