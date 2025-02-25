@tool
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var name: String
@export var type: int = GameEnums.ItemType.MISC
@export var effect: Callable

func _init(_name: String = "", item_type: int = GameEnums.ItemType.MISC, _effect: Callable = Callable()):
	name = _name
	type = item_type
	effect = _effect

func use(user, target = null):
	effect.call(user, target)

func serialize() -> Dictionary:
	return {
		"name": name,
		"type": type,
		"effect": effect.get_method()
	}

static func deserialize(data: Dictionary) -> Resource:
	return Item.new(data["name"], data["type"], Callable(Item, data["effect"]))

static func create_item_database() -> Dictionary:
	return {
		# Consumables
		"Booster pills": Item.new("Booster pills", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_booster_pills")),
		"Combat serum": Item.new("Combat serum", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_combat_serum")),
		"Kiranin crystals": Item.new("Kiranin crystals", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_kiranin_crystals")),
		"Rage out": Item.new("Rage out", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_rage_out")),
		"Still": Item.new("Still", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_still")),
		"Stim-pack": Item.new("Stim-pack", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_stim_pack")),
		"Reflective dust": Item.new("Reflective dust", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_reflective_dust")),
		
		# Protective
		"Battle dress": Item.new("Battle dress", GameEnums.ItemType.ARMOR, Callable(Item, "effect_battle_dress")),
		"Camo cloak": Item.new("Camo cloak", GameEnums.ItemType.ARMOR, Callable(Item, "effect_camo_cloak")),
		"Combat armor": Item.new("Combat armor", GameEnums.ItemType.ARMOR, Callable(Item, "effect_combat_armor")),
		"Deflector field": Item.new("Deflector field", GameEnums.ItemType.MISC, Callable(Item, "effect_deflector_field")),
		"Flak screen": Item.new("Flak screen", GameEnums.ItemType.MISC, Callable(Item, "effect_flak_screen")),
		"Flex-armor": Item.new("Flex-armor", GameEnums.ItemType.ARMOR, Callable(Item, "effect_flex_armor")),
		"Frag vest": Item.new("Frag vest", GameEnums.ItemType.ARMOR, Callable(Item, "effect_frag_vest")),
		"Screen generator": Item.new("Screen generator", GameEnums.ItemType.MISC, Callable(Item, "effect_screen_generator")),
		"Stealth gear": Item.new("Stealth gear", GameEnums.ItemType.MISC, Callable(Item, "effect_stealth_gear")),
		
		# Implants
		"AI companion": Item.new("AI companion", GameEnums.ItemType.MISC, Callable(Item, "effect_ai_companion")),
		"Body wire": Item.new("Body wire", GameEnums.ItemType.MISC, Callable(Item, "effect_body_wire")),
		"Boosted arm": Item.new("Boosted arm", GameEnums.ItemType.MISC, Callable(Item, "effect_boosted_arm")),
		"Boosted leg": Item.new("Boosted leg", GameEnums.ItemType.MISC, Callable(Item, "effect_boosted_leg")),
		"Cyber hand": Item.new("Cyber hand", GameEnums.ItemType.MISC, Callable(Item, "effect_cyber_hand")),
		"Genetic defenses": Item.new("Genetic defenses", GameEnums.ItemType.MISC, Callable(Item, "effect_genetic_defenses")),
		"Health boost": Item.new("Health boost", GameEnums.ItemType.MISC, Callable(Item, "effect_health_boost")),
		"Nerve adjuster": Item.new("Nerve adjuster", GameEnums.ItemType.MISC, Callable(Item, "effect_nerve_adjuster")),
		"Neural optimization": Item.new("Neural optimization", GameEnums.ItemType.MISC, Callable(Item, "effect_neural_optimization")),
		"Night sight": Item.new("Night sight", GameEnums.ItemType.MISC, Callable(Item, "effect_night_sight")),
		"Pain suppressor": Item.new("Pain suppressor", GameEnums.ItemType.MISC, Callable(Item, "effect_pain_suppressor")),
		
		# Utility
		"Fog generator": Item.new("Fog generator", GameEnums.ItemType.MISC, Callable(Item, "effect_fog_generator")),
		"Teleportation device": Item.new("Teleportation device", GameEnums.ItemType.MISC, Callable(Item, "effect_teleportation_device")),
		"Bot upgrade": Item.new("Bot upgrade", GameEnums.ItemType.MISC, Callable(Item, "effect_bot_upgrade")),
		
		# Onboard
		"Ship part": Item.new("Ship part", GameEnums.ItemType.MISC, Callable(Item, "effect_ship_part")),
		"Analyzer": Item.new("Analyzer", GameEnums.ItemType.MISC, Callable(Item, "effect_analyzer")),
		"Colonist ration packs": Item.new("Colonist ration packs", GameEnums.ItemType.CONSUMABLE, Callable(Item, "effect_colonist_ration_packs")),
		"Duplicator": Item.new("Duplicator", GameEnums.ItemType.MISC, Callable(Item, "effect_duplicator")),
		"Fake ID": Item.new("Fake ID", GameEnums.ItemType.MISC, Callable(Item, "effect_fake_id")),
		"Fixer": Item.new("Fixer", GameEnums.ItemType.MISC, Callable(Item, "effect_fixer")),
		"Genetic reconfiguration kit": Item.new("Genetic reconfiguration kit", GameEnums.ItemType.MISC, Callable(Item, "effect_genetic_reconfiguration_kit")),
		
		# Psionic
		"Psionic amplifier": Item.new("Psionic amplifier", GameEnums.ItemType.MISC, Callable(Item, "effect_psionic_amplifier")),
	}

static func effect_booster_pills(user, _target):
	user.remove_all_stun()
	user.double_speed_this_round()

static func effect_combat_serum(user, _target):
	user.increase_speed(2)
	user.increase_reactions(2)

static func effect_kiranin_crystals(user, _target):
	user.set_dazzling_effect(true)
	user.increase_reactions(1)

static func effect_reflective_dust(user, _target):
	user.set_reflective_dust(true)

static func effect_fog_generator(user, _target):
	user.set_fog_generator(true)

static func effect_teleportation_device(user, _target):
	user.set_teleportation_device(true)

static func effect_psionic_amplifier(user, _target):
	user.increase_psionic_power(1)

static func effect_bot_upgrade(user, _target):
	user.upgrade_bot()

static func effect_ship_part(user, _target):
	user.add_ship_part()

static func effect_rage_out(user, _target):
	user.increase_speed(2)
	user.increase_brawling(1)
	if user.species == GlobalEnums.Origin.KERIN:
		user.set_rage_state(true)

static func effect_still(user, _target):
	user.increase_hit(1)
	user.set_immobile(2)

static func effect_stim_pack(user, _target):
	user.prevent_next_casualty()

static func effect_battle_dress(user, _target):
	user.increase_reactions(1, 4)
	user.set_saving_throw(5)

static func effect_camo_cloak(user, _target):
	user.set_camo_cloak(true)

static func effect_combat_armor(user, _target):
	user.set_saving_throw(5)

static func effect_deflector_field(user, _target):
	user.set_deflector_field(true)

static func effect_flak_screen(user, _target):
	user.set_flak_screen(true)

static func effect_flex_armor(user, _target):
	user.set_flex_armor(true)

static func effect_frag_vest(user, _target):
	user.set_frag_vest(true)

static func effect_screen_generator(user, _target):
	user.set_screen_generator(true)

static func effect_stealth_gear(user, _target):
	user.set_stealth_gear(true)

static func effect_ai_companion(user, _target):
	user.set_ai_companion(true)

static func effect_body_wire(user, _target):
	user.increase_reactions(1)

static func effect_boosted_arm(user, _target):
	user.set_boosted_arm(true)

static func effect_boosted_leg(user, _target):
	user.increase_speed(1)
	user.increase_dash_speed(1)

static func effect_cyber_hand(user, _target):
	user.set_cyber_hand(true)

static func effect_genetic_defenses(user, _target):
	user.set_genetic_defenses(true)

static func effect_health_boost(user, _target):
	user.set_health_boost(true)
	if user.toughness == 3:
		user.increase_toughness(1)

static func effect_nerve_adjuster(user, _target):
	user.set_nerve_adjuster(true)

static func effect_neural_optimization(user, _target):
	user.set_neural_optimization(true)

static func effect_night_sight(user, _target):
	user.set_night_sight(true)

static func effect_pain_suppressor(user, _target):
	user.set_pain_suppressor(true)

static func effect_analyzer(user, _target):
	user.set_analyzer(true)

static func effect_colonist_ration_packs(user, _target):
	user.add_colonist_ration_packs()

static func effect_duplicator(user, _target):
	user.set_duplicator(true)

static func effect_fake_id(user, _target):
	user.set_fake_id(true)

static func effect_fixer(user, _target):
	user.set_fixer(true)

static func effect_genetic_reconfiguration_kit(user, _target):
	user.set_genetic_reconfiguration_kit(true)

func from_dict(data: Dictionary) -> void:
	type = data.get("type", GlobalEnums.ItemType.MISC)

static func get_all_items() -> Array[Resource]:
	var items: Array[Resource] = []
	
	# Gear items
	items.append(Item.new("Medkit", GameEnums.ItemType.MISC, Callable(Item, "effect_medkit")))
	items.append(Item.new("Stimpak", GameEnums.ItemType.MISC, Callable(Item, "effect_stimpak")))
	
	# Consumables
	items.append(Item.new("Genetic Reconfiguration Kit", GameEnums.ItemType.MISC, Callable(Item, "effect_genetic_reconfiguration_kit")))
	items.append(Item.new("Neural Enhancer", GameEnums.ItemType.MISC, Callable(Item, "effect_neural_enhancer")))
	
	# Tech items
	items.append(Item.new("Shield Generator", GameEnums.ItemType.MISC, Callable(Item, "effect_shield_generator")))
	items.append(Item.new("Stealth Field", GameEnums.ItemType.MISC, Callable(Item, "effect_stealth_field")))
	items.append(Item.new("Targeting System", GameEnums.ItemType.MISC, Callable(Item, "effect_targeting_system")))
	items.append(Item.new("Jump Pack", GameEnums.ItemType.MISC, Callable(Item, "effect_jump_pack")))
	items.append(Item.new("Combat Scanner", GameEnums.ItemType.MISC, Callable(Item, "effect_combat_scanner")))
	items.append(Item.new("Energy Shield", GameEnums.ItemType.MISC, Callable(Item, "effect_energy_shield")))
	items.append(Item.new("Repair Kit", GameEnums.ItemType.MISC, Callable(Item, "effect_repair_kit")))
	items.append(Item.new("Hacking Tool", GameEnums.ItemType.MISC, Callable(Item, "effect_hacking_tool")))
	items.append(Item.new("Cloaking Device", GameEnums.ItemType.MISC, Callable(Item, "effect_cloaking_device")))
	
	# Support items
	items.append(Item.new("Drone Controller", GameEnums.ItemType.MISC, Callable(Item, "effect_drone_controller")))
	items.append(Item.new("Turret Control", GameEnums.ItemType.MISC, Callable(Item, "effect_turret_control")))
	items.append(Item.new("Beacon", GameEnums.ItemType.MISC, Callable(Item, "effect_beacon")))
	
	# Utility items
	items.append(Item.new("Grappling Hook", GameEnums.ItemType.MISC, Callable(Item, "effect_grappling_hook")))
	items.append(Item.new("Jetpack", GameEnums.ItemType.MISC, Callable(Item, "effect_jetpack")))
	
	# Special items
	items.append(Item.new("Quantum Stabilizer", GameEnums.ItemType.MISC, Callable(Item, "effect_quantum_stabilizer")))
	items.append(Item.new("Phase Shifter", GameEnums.ItemType.MISC, Callable(Item, "effect_phase_shifter")))
	items.append(Item.new("Time Dilator", GameEnums.ItemType.MISC, Callable(Item, "effect_time_dilator")))
	items.append(Item.new("Reality Anchor", GameEnums.ItemType.MISC, Callable(Item, "effect_reality_anchor")))
	
	# Rare items
	items.append(Item.new("Ancient Artifact", GameEnums.ItemType.MISC, Callable(Item, "effect_ancient_artifact")))
	
	return items
