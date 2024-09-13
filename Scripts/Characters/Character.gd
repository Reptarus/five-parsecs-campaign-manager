class_name Character
extends Resource

# Import necessary dependencies
const GlobalEnums = preload("res://Resources/GlobalEnums.gd")
const CharacterNameGenerator = preload("res://Resources/CharacterNameGenerator.gd")
const CharacterCreationData = preload("res://Scripts/Characters/CharacterCreationData.gd")
const PsionicManager = preload("res://Resources/PsionicManager.gd")
const StrangeCharacters = preload("res://Scripts/Characters/StrangeCharacters.gd")

@export var character_name: String = ""
@export var species: GlobalEnums.Species = GlobalEnums.Species.HUMAN
@export var background: GlobalEnums.Background = GlobalEnums.Background.HIGH_TECH_COLONY
@export var motivation: GlobalEnums.Motivation = GlobalEnums.Motivation.WEALTH
@export var character_class: GlobalEnums.Class = GlobalEnums.Class.WORKING_CLASS

@export var reactions: int = 1
@export var speed: int = 4
@export var combat_skill: int = 0
@export var toughness: int = 3
@export var savvy: int = 0
@export var luck: int = 0

@export var is_psionic: bool = false
@export var psionic_powers: Array[int] = []

var strange_character: StrangeCharacters = null
var traits: Array[String] = []
var equipment: Array[String] = []
var armor: String = ""
var screen: String = ""
var implants: Array[String] = []
var stun_markers: int = 0
var xp: int = 0

@export var characteristics: Array[String] = []

var abilities: Array[String] = []

func generate_random() -> void:
    character_name = CharacterNameGenerator.get_random_name()
    species = GlobalEnums.Species.values()[randi() % GlobalEnums.Species.size()]
    background = GlobalEnums.Background.values()[randi() % GlobalEnums.Background.size()]
    motivation = GlobalEnums.Motivation.values()[randi() % GlobalEnums.Motivation.size()]
    character_class = GlobalEnums.Class.values()[randi() % GlobalEnums.Class.size()]
    
    # Reset stats before applying effects
    reactions = 1
    speed = 4
    combat_skill = 0
    toughness = 3
    savvy = 0
    luck = 0
    
    # Apply effects
    apply_species_effects(CharacterCreationData.new())
    apply_character_effects(CharacterCreationData.new())
    
    if randf() < 0.1:  # 10% chance of being psionic
        make_psionic()
    if randf() < 0.05:  # 5% chance of being a strange character
        set_strange_character_type(StrangeCharacters.StrangeCharacterType.values()[randi() % StrangeCharacters.StrangeCharacterType.size()])

func make_psionic() -> void:
    is_psionic = true
    var psionic_manager = PsionicManager.new()
    psionic_manager.generate_starting_powers()
    psionic_powers = psionic_manager.powers

func set_strange_character_type(type: StrangeCharacters.StrangeCharacterType) -> void:
    strange_character = StrangeCharacters.new(type)
    strange_character.apply_special_abilities(self)

func add_ability(ability: String) -> void:
    if ability not in abilities:
        abilities.append(ability)

func add_equipment(item: String) -> void:
    equipment.append(item)

func set_armor(new_armor: String) -> void:
    armor = new_armor

func set_screen(new_screen: String) -> void:
    screen = new_screen

func add_implant(implant: String) -> void:
    if implants.size() < 2 and implant not in implants:
        implants.append(implant)

func add_stun_marker() -> void:
    stun_markers += 1

func remove_stun_marker() -> void:
    if stun_markers > 0:
        stun_markers -= 1

func add_xp(amount: int) -> void:
    xp += amount

func use_luck() -> void:
    if luck > 0:
        luck -= 1

func apply_saving_throw(damage: int) -> bool:
    var save_roll = randi() % 6 + 1
    if armor == "Battle dress" and save_roll >= 5:
        return true
    elif armor == "Combat armor" and save_roll >= 5:
        return true
    elif armor == "Frag vest":
        if save_roll >= 6 or (damage > 0 and save_roll >= 5):
            return true
    elif screen == "Screen generator" and save_roll >= 5:
        return true
    return false

func serialize() -> Dictionary:
    var data = {
        "name": self.name,
        "species": GlobalEnums.Species.keys()[self.species],
        "background": GlobalEnums.Background.keys()[self.background],
        "motivation": GlobalEnums.Motivation.keys()[self.motivation],
        "character_class": GlobalEnums.Class.keys()[self.character_class],
        "reactions": reactions,
        "speed": speed,
        "combat_skill": combat_skill,
        "toughness": toughness,
        "savvy": savvy,
        "luck": luck,
        "is_psionic": is_psionic,
        "psionic_powers": psionic_powers.map(func(power): return GlobalEnums.PsionicPower.keys()[power]),
        "abilities": abilities,
        "equipment": equipment,
        "armor": armor,
        "screen": screen,
        "implants": implants,
        "stun_markers": stun_markers,
        "xp": xp
    }
    if strange_character:
        data["strange_character"] = strange_character.serialize()
    return data

static func deserialize(data: Dictionary) -> Character:
    var character = Character.new()
    character.name = data["name"]
    character.species = GlobalEnums.Species[data["species"]]
    character.background = GlobalEnums.Background[data["background"]]
    character.motivation = GlobalEnums.Motivation[data["motivation"]]
    character.character_class = GlobalEnums.Class[data["character_class"]]
    character.reactions = data["reactions"]
    character.speed = data["speed"]
    character.combat_skill = data["combat_skill"]
    character.toughness = data["toughness"]
    character.savvy = data["savvy"]
    character.luck = data["luck"]
    character.is_psionic = data["is_psionic"]
    character.psionic_powers = data["psionic_powers"].map(func(power): return GlobalEnums.PsionicPower[power])
    character.abilities = data["abilities"]
    character.equipment = data["equipment"]
    character.armor = data["armor"]
    character.screen = data["screen"]
    character.implants = data["implants"]
    character.stun_markers = data["stun_markers"]
    character.xp = data["xp"]
    if "strange_character" in data:
        character.strange_character = StrangeCharacters.deserialize(data["strange_character"])
    return character

func apply_species_effects(character_data: CharacterCreationData):
    var species_data = character_data.species.filter(func(species): return species.name == self.species)
    if species_data.size() > 0:
        var effects = species_data[0].get("effects", {})
        # Apply effects to character stats
        self.reactions += effects.get("reactions", 0)
        self.speed += effects.get("speed", 0)
        self.combat_skill += effects.get("combat_skill", 0)
        self.toughness += effects.get("toughness", 0)
        self.savvy += effects.get("savvy", 0)
       
        # Apply special abilities
        var special_abilities = effects.get("special_abilities", [])
        for ability in special_abilities:
            if ability not in self.abilities:
                self.abilities.append(ability)
       
        # Apply equipment
        var starting_equipment = effects.get("starting_equipment", [])
        for item in starting_equipment:
            if item not in self.equipment:
                self.equipment.append(item)
       
        # Apply psionic effects
        if effects.get("psionic", false):
            self.is_psionic = true
            var psionic_powers = effects.get("psionic_powers", [])
            for power in psionic_powers:
                if power not in self.psionic_powers:
                    self.psionic_powers.append(power)

func apply_character_effects(character_data: CharacterCreationData):
    # Apply background effects
    var background_data = character_data.get_background_data(self.background)
    if background_data:
        apply_effects(background_data.get("effects", {}))
        add_starting_equipment(background_data.get("starting_equipment", []))
   
    # Apply motivation effects
    var motivation_data = character_data.get_motivation_data(self.motivation)
    if motivation_data:
        apply_effects(motivation_data.get("effects", {}))
   
    # Apply class effects
    var class_data = character_data.get_class_data(self.character_class)
    if class_data:
        apply_effects(class_data.get("effects", {}))
        add_starting_equipment(class_data.get("starting_equipment", []))
        apply_psionic_effects(class_data.get("effects", {}))

func apply_effects(effects: Dictionary):
    self.reactions += effects.get("reactions", 0)
    self.speed += effects.get("speed", 0)
    self.combat_skill += effects.get("combat_skill", 0)
    self.toughness += effects.get("toughness", 0)
    self.savvy += effects.get("savvy", 0)
   
    var new_characteristics = effects.get("characteristics", [])
    for characteristic in new_characteristics:
        add_characteristic(characteristic)

func add_characteristic(characteristic: String):
    if not has_characteristic(characteristic):
        characteristics.append(characteristic)

func has_characteristic(characteristic: String) -> bool:
    return characteristic in characteristics

func add_starting_equipment(equipment_list: Array):
    for item in equipment_list:
        if item not in self.equipment:
            self.equipment.append(item)

func apply_psionic_effects(effects: Dictionary):
    if effects.get("psionic", false):
        self.is_psionic = true
        var psionic_powers = effects.get("psionic_powers", [])
        for power in psionic_powers:
            if power not in self.psionic_powers:
                self.psionic_powers.append(power)
