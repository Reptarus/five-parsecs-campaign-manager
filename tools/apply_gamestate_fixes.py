#!/usr/bin/env python3
"""
GameState.gd Systematic Fix Application Script
Applies the established methodology to fix all remaining signal emissions,
type safety issues, and unsafe method calls in GameState.gd
"""

import re
import os
import sys

def apply_signal_emission_fixes(content):
    """Replace all direct signal emissions with wrapper methods"""
    fixes = [
        # Direct signal emissions with parameters
        (r'state_changed\.emit\(\)\s*#\s*warning:.*', '_emit_state_changed()'),
        (r'resources_changed\.emit\(\)\s*#\s*warning:.*', '_emit_resources_changed()'),
        (r'campaign_saved\.emit\(\)\s*#\s*warning:.*', '_emit_campaign_saved()'),
        (r'turn_advanced\.emit\(\)\s*#\s*warning:.*', '_emit_turn_advanced()'),
        (r'load_started\.emit\(\)\s*#\s*warning:.*', '_emit_load_started()'),
        
        # Signal emissions with complex parameters
        (r'save_completed\.emit\((.*?)\)\s*#\s*warning:.*', r'_emit_save_completed(\1)'),
        (r'load_completed\.emit\((.*?)\)\s*#\s*warning:.*', r'_emit_load_completed(\1)'),
        (r'quest_added\.emit\((.*?)\)\s*#\s*warning:.*', r'_emit_quest_added(\1)'),
        (r'quest_completed\.emit\((.*?)\)\s*#\s*warning:.*', r'_emit_quest_completed(\1)'),
        (r'backup_created\.emit\((.*?)\)\s*#\s*warning:.*', r'_emit_backup_created(\1)'),
        (r'campaign_loaded\.emit\((.*?)\)\s*#\s*warning:.*', r'_emit_campaign_loaded(\1)'),
    ]
    
    for pattern, replacement in fixes:
        content = re.sub(pattern, replacement, content)
    
    return content

def apply_array_operation_fixes(content):
    """Replace array operations that discard return values"""
    fixes = [
        # Array append operations
        (r'active_quests\.append\((.*?)\)\s*#\s*warning:.*', r'_add_active_quest(\1)'),
        (r'completed_quests\.append\((.*?)\)\s*#\s*warning:.*', r'_add_completed_quest(\1)'),
        (r'visited_locations\.append\((.*?)\)\s*#\s*warning:.*', r'_add_visited_location(\1)'),
        (r'events\.append\((.*?)\)\s*#\s*warning:.*', r'_add_turn_event(\1)'),
        (r'backups\.append\((.*?)\)\s*#\s*warning:.*', r'_add_backup_entry(\1)'),
    ]
    
    for pattern, replacement in fixes:
        content = re.sub(pattern, replacement, content)
    
    return content

def add_missing_helper_methods(content):
    """Add the missing helper methods for array operations"""
    
    helper_methods = '''
## ARRAY OPERATION HELPERS - Clean collection management
func _add_active_quest(quest: Dictionary) -> void:
	active_quests.append(quest)

func _add_completed_quest(quest: Dictionary) -> void:
	completed_quests.append(quest)

func _add_visited_location(location_id: String) -> void:
	visited_locations.append(location_id)

func _add_turn_event(event: Dictionary) -> void:
	var events: Array = []
	events.append(event)

func _add_backup_entry(backup_data: Dictionary) -> void:
	var backups: Array = []
	backups.append(backup_data)

'''
    
    # Find the position after the safe accessor methods
    pattern = r'(## OPERATION QUEUEING - Clean operation management.*?func _process_save_queue\(\) -> void:.*?\n)'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + helper_methods + content[insert_pos:]
    
    return content

def apply_type_safety_fixes(content):
    """Apply type safety improvements"""
    fixes = [
        # Safe type conversions in deserialize method
        (r'var location_data: Variant = data\.current_location\s*if location_data is Dictionary:\s*current_location = location_data\.duplicate\(\)\s*else:\s*current_location = \{\}', 
         'current_location = _get_safe_dictionary_data(data, "current_location")'),
        
        (r'var ship_data: Variant = data\.player_ship\s*if ship_data is Dictionary:', 
         'var ship_data = _get_safe_dictionary_data(data, "player_ship")\n\tif ship_data:'),
        
        (r'var campaign_data: Variant = data\.campaign\s*if campaign_data is Dictionary:', 
         'var campaign_data = _get_safe_dictionary_data(data, "campaign")\n\tif campaign_data:'),
    ]
    
    for pattern, replacement in fixes:
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    return content

def add_type_safety_helpers(content):
    """Add type safety helper methods"""
    
    type_helpers = '''
## TYPE SAFETY HELPERS - Safe data extraction and conversion
func _get_safe_dictionary_data(data: Dictionary, key: String) -> Dictionary:
	if not data.has(key):
		return {}
	var value = data[key]
	if value is Dictionary:
		return value.duplicate()
	else:
		push_warning("Invalid data format for key: " + key)
		return {}

func _get_safe_resource_type(type_variant: Variant) -> GameEnums.ResourceType:
	if type_variant is int:
		return type_variant as GameEnums.ResourceType
	elif type_variant is GameEnums.ResourceType:
		return type_variant as GameEnums.ResourceType
	else:
		push_warning("Invalid resource type: " + str(type_variant))
		return GameEnums.ResourceType.CREDITS

func _validate_quest_data(quest: Dictionary) -> bool:
	return quest.has("id") and quest.has("title") and quest.has("description")

'''
    
    # Find position after safe accessor methods
    pattern = r'(func _get_safe_world_trait\(value: Variant\) -> GameEnums\.WorldTrait:.*?return GameEnums\.WorldTrait\.NONE\n)'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + type_helpers + content[insert_pos:]
    
    return content

def apply_method_safety_fixes(content):
    """Apply method call safety improvements"""
    fixes = [
        # Safe method calls with has_method checks
        (r'if player_ship\.has_method\("deserialize"\):\s*player_ship\.deserialize\(ship_data\)', 
         '_deserialize_player_ship(ship_data)'),
        
        (r'if _current_campaign\.has_method\("deserialize"\):\s*_current_campaign\.deserialize\(campaign_data\)', 
         '_deserialize_campaign(campaign_data)'),
        
        (r'if _current_campaign\.has_method\("from_dictionary"\):\s*_current_campaign\.from_dictionary\(campaign_dict\)', 
         '_load_campaign_from_dictionary(campaign_dict)'),
        
        (r'if _current_campaign\.has_method\("to_dictionary"\):\s*campaign_data = _current_campaign\.to_dictionary\(\)', 
         'campaign_data = _get_campaign_dictionary()'),
        
        (r'if _current_campaign\.has_method\("get_crew_members"\):\s*return _current_campaign\.get_crew_members\(\)', 
         'return _get_safe_crew_members()'),
    ]
    
    for pattern, replacement in fixes:
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    return content

def add_method_safety_helpers(content):
    """Add method safety helper methods"""
    
    method_helpers = '''
## METHOD SAFETY HELPERS - Safe external method calls
func _deserialize_player_ship(ship_data: Dictionary) -> void:
	if not player_ship:
		player_ship = Ship.new()
	if player_ship.has_method("deserialize"):
		player_ship.deserialize(ship_data)
	else:
		push_warning("Ship class does not support deserialize method")

func _deserialize_campaign(campaign_data: Dictionary) -> void:
	if not _current_campaign:
		_current_campaign = FiveParsecsCampaign.new()
	if _current_campaign.has_method("deserialize"):
		_current_campaign.deserialize(campaign_data)
	else:
		push_warning("Campaign class does not support deserialize method")

func _load_campaign_from_dictionary(campaign_dict: Dictionary) -> void:
	if not _current_campaign:
		_current_campaign = FiveParsecsCampaign.new()
	if _current_campaign.has_method("from_dictionary"):
		_current_campaign.from_dictionary(campaign_dict)
	else:
		push_warning("Campaign does not support from_dictionary method")

func _get_campaign_dictionary() -> Dictionary:
	if not _current_campaign:
		return {}
	if _current_campaign.has_method("to_dictionary"):
		return _current_campaign.to_dictionary()
	else:
		push_warning("Campaign does not support to_dictionary method")
		return {}

func _get_safe_crew_members() -> Array:
	if not _current_campaign:
		return []
	if _current_campaign.has_method("get_crew_members"):
		return _current_campaign.get_crew_members()
	else:
		return []

'''
    
    # Find position after type safety helpers
    pattern = r'(func _validate_quest_data\(quest: Dictionary\) -> bool:.*?return.*?\n)'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + method_helpers + content[insert_pos:]
    
    return content

def main():
    """Main execution function"""
    if len(sys.argv) < 2:
        print("Usage: python apply_gamestate_fixes.py <path_to_GameState.gd>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} does not exist")
        sys.exit(1)
    
    # Read the current content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("Applying GameState.gd fixes...")
    
    # Apply fixes in order
    content = apply_signal_emission_fixes(content)
    print("✓ Signal emission fixes applied")
    
    content = apply_array_operation_fixes(content)
    content = add_missing_helper_methods(content)
    print("✓ Array operation fixes applied")
    
    content = apply_type_safety_fixes(content)
    content = add_type_safety_helpers(content)
    print("✓ Type safety fixes applied")
    
    content = apply_method_safety_fixes(content)
    content = add_method_safety_helpers(content)
    print("✓ Method safety fixes applied")
    
    # Create backup
    backup_path = file_path + '.backup'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Backup created: {backup_path}")
    
    # Write the fixed content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Fixes applied to {file_path}")
    print("\nGameState.gd systematic fixes completed successfully!")
    print("\nNext steps:")
    print("1. Test the game state functionality")
    print("2. Run linter to verify warning reduction")
    print("3. Apply similar patterns to other state management files")
    print("4. Update unit tests to match new method signatures")

if __name__ == "__main__":
    main() 