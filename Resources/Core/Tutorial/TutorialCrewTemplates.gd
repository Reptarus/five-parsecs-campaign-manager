class_name TutorialCrewTemplates
extends Resource

const TUTORIAL_CREWS = {
    "beginner": {
        "name": "Rookie Explorers",
        "description": "A balanced crew perfect for learning the basics",
        "credits": 1000,
        "members": [
            {
                "name": "Captain Sarah",
                "class": GlobalEnums.Class.LEADER,
                "background": GlobalEnums.Background.SOLDIER,
                "stats": {
                    "combat": 2,
                    "technical": 1,
                    "social": 3,
                    "survival": 2
                },
                "equipment": {
                    "weapon": "Basic Pistol",
                    "armor": "Light Armor"
                }
            },
            {
                "name": "Tech Specialist Alex",
                "class": GlobalEnums.Class.TECH,
                "background": GlobalEnums.Background.SCIENTIST,
                "stats": {
                    "combat": 1,
                    "technical": 3,
                    "social": 2,
                    "survival": 2
                },
                "equipment": {
                    "weapon": "Utility Tool",
                    "armor": "Tech Vest"
                }
            },
            {
                "name": "Combat Specialist Marcus",
                "class": GlobalEnums.Class.WARRIOR,
                "background": GlobalEnums.Background.SOLDIER,
                "stats": {
                    "combat": 3,
                    "technical": 1,
                    "social": 1,
                    "survival": 3
                },
                "equipment": {
                    "weapon": "Combat Rifle",
                    "armor": "Combat Armor"
                }
            }
        ]
    },
    "stealth": {
        "name": "Shadow Operations",
        "description": "A crew focused on stealth and subterfuge",
        "credits": 1200,
        "members": [
            {
                "name": "Captain Ghost",
                "class": GlobalEnums.Class.SPECIALIST,
                "background": GlobalEnums.Background.OUTLAW,
                "stats": {
                    "combat": 2,
                    "technical": 2,
                    "social": 2,
                    "survival": 2
                },
                "equipment": {
                    "weapon": "Silenced Pistol",
                    "armor": "Stealth Suit"
                }
            },
            # Add more stealth-focused members...
        ]
    },
    "technical": {
        "name": "Tech Salvagers",
        "description": "A crew specializing in technical operations and salvage",
        "credits": 1500,
        "members": [
            {
                "name": "Captain Nova",
                "class": GlobalEnums.Class.TECH,
                "background": GlobalEnums.Background.SCIENTIST,
                "stats": {
                    "combat": 1,
                    "technical": 3,
                    "social": 2,
                    "survival": 2
                },
                "equipment": {
                    "weapon": "Tech Tool",
                    "armor": "Engineer Suit"
                }
            },
            # Add more tech-focused members...
        ]
    }
}

func load_tutorial_crew(template_name: String) -> Crew:
    if not TUTORIAL_CREWS.has(template_name):
        push_error("Tutorial crew template '%s' not found" % template_name)
        return null
        
    var crew = Crew.new()
    var template = TUTORIAL_CREWS[template_name]
    
    crew.credits = template.get("credits", 1000)
    
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
                character.equipped_weapon = weapon
            
            if member_data.equipment.has("armor"):
                var armor = _create_armor(member_data.equipment.armor)
                character.equipped_armor = armor
        
        # Add to crew
        crew.add_member(character)
        
        # Set captain if this is the first member
        if crew.get_member_count() == 1:
            crew.set_captain(character)
    
    return crew

func get_template_names() -> Array[String]:
    return TUTORIAL_CREWS.keys()

func get_template_info(template_name: String) -> Dictionary:
    if not TUTORIAL_CREWS.has(template_name):
        return {}
    
    var template = TUTORIAL_CREWS[template_name]
    return {
        "name": template.name,
        "description": template.description,
        "credits": template.credits,
        "member_count": template.members.size()
    }

func _create_weapon(weapon_name: String) -> Weapon:
    # This should be replaced with proper weapon creation from your game's weapon system
    var weapon = Weapon.new()
    weapon.name = weapon_name
    return weapon

func _create_armor(armor_name: String) -> Armor:
    # This should be replaced with proper armor creation from your game's armor system
    var armor = Armor.new()
    armor.name = armor_name
    return armor 