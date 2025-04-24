@tool
## Class Registry for Test Classes
##
## This file contains information about class names used in tests

# This function is just to confirm the class registry is loaded
func is_loaded() -> bool:
    return true

# This function returns the standard test class names
func get_test_class_names() -> Array:
    return ["GutTest", "BaseTest", "GameTest", "UITest", "BattleTest", "CampaignTest"]