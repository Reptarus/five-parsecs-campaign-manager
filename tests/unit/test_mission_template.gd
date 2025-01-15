extends "res://addons/gut/test.gd"

const MissionTemplate = preload("res://src/core/systems/MissionTemplate.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var template: MissionTemplate

func before_each() -> void:
    template = MissionTemplate.new()
    
    # Setup basic template properties
    template.type = GameEnums.MissionType.RED_ZONE
    template.title_templates = ["Mission: {LOCATION}", "Operation: {LOCATION}"]
    template.description_templates = ["Search and secure {LOCATION}", "Investigate activity at {LOCATION}"]
    template.objective = "SEARCH"
    template.objective_description = "Search the area for valuable items"
    template.reward_range = Vector2(100, 500)
    template.difficulty_range = Vector2(1, 3)
    template.required_skills = ["combat", "tech"]
    template.enemy_types = ["standard", "elite"]
    template.deployment_condition_chance = 0.3
    template.notable_sight_chance = 0.2
    template.economic_impact = 1.0

func after_each() -> void:
    template.free()

func test_template_initialization() -> void:
    assert_eq(template.type, GameEnums.MissionType.RED_ZONE, "Template type should be set")
    assert_eq(template.title_templates.size(), 2, "Should have 2 title templates")
    assert_eq(template.description_templates.size(), 2, "Should have 2 description templates")
    assert_eq(template.objective, "SEARCH", "Objective should be set")
    assert_eq(template.required_skills.size(), 2, "Should have 2 required skills")

func test_template_validation() -> void:
    # Test valid template
    assert_true(template.validate(), "Valid template should pass validation")
    
    # Test invalid type
    var original_type = template.type
    template.type = GameEnums.MissionType.NONE
    assert_false(template.validate(), "Invalid type should fail validation")
    template.type = original_type
    
    # Test empty title templates
    template.title_templates.clear()
    assert_false(template.validate(), "Empty title templates should fail validation")
    template.title_templates = ["Mission: {LOCATION}"]
    
    # Test invalid ranges
    template.reward_range = Vector2(-100, 500)
    assert_false(template.validate(), "Negative reward range should fail validation")
    template.reward_range = Vector2(100, 500)
    
    template.difficulty_range = Vector2(3, 1)
    assert_false(template.validate(), "Invalid difficulty range should fail validation")
    template.difficulty_range = Vector2(1, 3)
    
    # Test invalid probabilities
    template.deployment_condition_chance = -0.1
    assert_false(template.validate(), "Invalid deployment chance should fail validation")
    template.deployment_condition_chance = 0.3
    
    template.notable_sight_chance = 1.5
    assert_false(template.validate(), "Invalid sight chance should fail validation")
    template.notable_sight_chance = 0.2

func test_random_getters() -> void:
    # Test random title
    var title = template.get_random_title()
    assert_true(template.title_templates.has(title), "Random title should be from templates")
    
    # Test random description
    var description = template.get_random_description()
    assert_true(template.description_templates.has(description), "Random description should be from templates")
    
    # Test random enemy type
    var enemy = template.get_random_enemy_type()
    assert_true(template.enemy_types.has(enemy), "Random enemy should be from types")
    
    # Test random difficulty
    var difficulty = template.get_random_difficulty()
    assert_true(difficulty >= template.difficulty_range.x and difficulty <= template.difficulty_range.y,
        "Random difficulty should be within range")
    
    # Test random reward
    var reward = template.get_random_reward()
    assert_true(reward >= template.reward_range.x and reward <= template.reward_range.y,
        "Random reward should be within range")

func test_skill_requirements() -> void:
    assert_true(template.requires_skill("combat"), "Should require combat skill")
    assert_true(template.requires_skill("tech"), "Should require tech skill")
    assert_false(template.requires_skill("medical"), "Should not require medical skill")

func test_chance_calculations() -> void:
    var deployment_results := []
    var sight_results := []
    
    # Test multiple times to account for randomness
    for i in range(1000):
        deployment_results.append(template.should_have_deployment_condition())
        sight_results.append(template.should_have_notable_sight())
    
    # Calculate percentages
    var deployment_percentage = deployment_results.count(true) / 1000.0
    var sight_percentage = sight_results.count(true) / 1000.0
    
    # Allow for some variance due to randomness
    assert_almost_eq(deployment_percentage, template.deployment_condition_chance, 0.1,
        "Deployment condition chance should be approximately correct")
    assert_almost_eq(sight_percentage, template.notable_sight_chance, 0.1,
        "Notable sight chance should be approximately correct")

func test_dictionary_conversion() -> void:
    var dict = template.to_dictionary()
    
    # Test dictionary contents
    assert_eq(dict["type"], template.type, "Dictionary should contain correct type")
    assert_eq(dict["title_templates"], template.title_templates, "Dictionary should contain title templates")
    assert_eq(dict["objective"], template.objective, "Dictionary should contain objective")
    assert_eq(dict["reward_range"]["min"], template.reward_range.x, "Dictionary should contain reward range min")
    assert_eq(dict["reward_range"]["max"], template.reward_range.y, "Dictionary should contain reward range max")
    
    # Test conversion back to template
    var new_template = MissionTemplate.from_dictionary(dict)
    assert_eq(new_template.type, template.type, "Converted template should have same type")
    assert_eq(new_template.title_templates, template.title_templates, "Converted template should have same titles")
    assert_eq(new_template.objective, template.objective, "Converted template should have same objective")
    assert_eq(new_template.reward_range, template.reward_range, "Converted template should have same reward range")
    assert_eq(new_template.difficulty_range, template.difficulty_range, "Converted template should have same difficulty range")