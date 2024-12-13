class_name TutorialCrewTemplates
extends Resource

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const GameWeapon = preload("res://Resources/Core/Items/Weapons/Weapon.gd")
const GameArmor = preload("res://Resources/Core/Character/Equipment/Armor.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")
const Crew = preload("res://Resources/Campaign/Crew/Crew.gd")

var TUTORIAL_CREWS = {
    "beginner": {
        "name": "Rookie Explorers",
        "description": "A balanced crew perfect for learning the basics",
        "credits": 1000,
        "characteristic": "DREAMERS",
        "meeting_story": "Met at a starport looking for adventure",
        "members": [
            {
                "name": "Captain Sarah",
                "class": GameEnums.CharacterClass.SOLDIER,
                "background": GameEnums.CharacterBackground.MILITARY_OUTPOST,
                "stats": {
                    "combat": 2,
                    "technical": 1,
                    "survival": 2,
                    "leadership": 2
                },
                "equipment": {
                    "weapon": "Standard Pistol",
                    "armor": "Light Armor"
                }
            },
            {
                "name": "Tech Specialist Alex",
                "class": GameEnums.CharacterClass.TECHNICIAN,
                "background": GameEnums.CharacterBackground.TECH_GUILD,
                "stats": {
                    "combat": 1,
                    "technical": 3,
                    "survival": 1,
                    "leadership": 1
                },
                "equipment": {
                    "weapon": "Laser Pistol",
                    "armor": "Light Armor"
                }
            }
        ]
    }
}

func load_tutorial_crew(template_name: String) -> Crew:
    if not TUTORIAL_CREWS.has(template_name):
        push_error("Tutorial crew template '%s' not found" % template_name)
        return null
        
    var crew = Crew.new()
    var template = TUTORIAL_CREWS[template_name]
    
    crew.name = template.get("name", "")
    crew.credits = template.get("credits", 1000)
    crew.characteristic = template.get("characteristic", "")
    crew.meeting_story = template.get("meeting_story", "")
    
    for member_data in template.members:
        var character = Character.new()
        
        # Set basic info
        character.character_name = member_data.name
        character.character_class = member_data.class
        character.background = member_data.background
        
        # Set stats
        for stat_name in member_data.stats:
            character.stats.set_stat(stat_name, member_data.stats[stat_name])
        
        # Set equipment
        if member_data.has("equipment"):
            if member_data.equipment.has("weapon"):
                var weapon = _create_weapon(member_data.equipment.weapon)
                character.equip_weapon(weapon)
            
            if member_data.equipment.has("armor"):
                var armor = _create_armor(member_data.equipment.armor)
                character.equip_gear(armor)
        
        # Add to crew
        crew.add_member(character)
    
    return crew

func _create_weapon(weapon_name: String) -> GameWeapon:
    var weapon = GameWeapon.new()
    # Set up weapon based on name
    match weapon_name:
        "Standard Pistol":
            weapon.setup("Standard Pistol", GameEnums.WeaponType.PISTOL, 12, 1, 1)
        "Laser Pistol":
            weapon.setup("Laser Pistol", GameEnums.WeaponType.PISTOL, 14, 1, 2)
        _:
            weapon.setup("Basic Pistol", GameEnums.WeaponType.PISTOL, 10, 1, 1)
    return weapon

func _create_armor(armor_name: String) -> Equipment:
    var armor = Equipment.new()
    # Set up armor based on name
    match armor_name:
        "Light Armor":
            armor.name = "Light Armor"
            armor.type = GameEnums.ItemType.ARMOR
            armor.value = 1
            armor.description = "Basic protective gear"
        _:
            armor.name = "Basic Armor"
            armor.type = GameEnums.ItemType.ARMOR
            armor.value = 1
            armor.description = "Simple protective gear"
    return armor 