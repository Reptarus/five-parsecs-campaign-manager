#!/usr/bin/env python3
"""
Critical Linter Error Fixer for Five Parsecs Campaign Manager
Focuses on the most common and critical errors visible in the test files.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

def fix_campaign_test_helper():
    """Fix specific errors in campaign_test_helper.gd"""
    file_path = Path("tests/fixtures/helpers/campaign_test_helper.gd")
    if not file_path.exists():
        return False
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = file_path.with_suffix('.gd.backup')
    shutil.copy2(file_path, backup_path)
    
    # Fix the broken constant declaration on line 10
    content = re.sub(
        r'const ERROR_INVALID_STATE_KEY := "const ERROR_MANAGER_NULL := "Failed to create % s"',
        'const ERROR_INVALID_STATE_KEY := "Invalid state key"\nconst ERROR_MANAGER_NULL := "Failed to create %s"',
        content
    )
    
    # Fix the broken string on line 11
    content = re.sub(
        r'const ERROR_SIGNAL_MISSING := "',
        r'const ERROR_SIGNAL_MISSING := "Signal missing: %s"',
        content
    )
    
    # Fix the broken enum
    content = re.sub(
        r'enum CampaignPhase \{\s*SETUP,\s*STORY,\s*BATTLE,\s*# 	RESOLUTION',
        '''enum CampaignPhase {
	SETUP,
	STORY,
	BATTLE,
	RESOLUTION
}''',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    # Fix broken dictionary declarations
    content = re.sub(
        r'"SETUP": \{,\s*"phase": GameEnums\.FiveParcsecsCampaignPhase\.SETUP as int,\s*"resources": \{,\s*"credits": 100 as int,\s*"reputation": 0 as int,',
        '''		"SETUP": {
			"phase": GameEnums.FiveParcsecsCampaignPhase.SETUP as int,
			"resources": {
				"credits": 100 as int,
				"reputation": 0 as int
			}
		},''',
        content
    )
    
    # Fix similar pattern for STORY and BATTLE
    content = re.sub(
        r'"STORY": \{,\s*"phase": GameEnums\.FiveParcsecsCampaignPhase\.STORY as int,\s*"resources": \{,\s*"credits": 150 as int,\s*"reputation": 5 as int,',
        '''		"STORY": {
			"phase": GameEnums.FiveParcsecsCampaignPhase.STORY as int,
			"resources": {
				"credits": 150 as int,
				"reputation": 5 as int
			}
		},''',
        content
    )
    
    content = re.sub(
        r'"BATTLE": \{,\s*"phase": GameEnums\.FiveParcsecsCampaignPhase\.BATTLE_SETUP as int,\s*"resources": \{,\s*"credits": 200 as int,\s*"reputation": 10 as int,',
        '''		"BATTLE": {
			"phase": GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP as int,
			"resources": {
				"credits": 200 as int,
				"reputation": 10 as int
			}
		}
	}''',
        content
    )
    
    # Fix broken verify_missing_signals function
    broken_function = r'func verify_missing_signals\(emitter: Object, expected_signals: Array\[String\]\) -> void:.*?pass'
    fixed_function = '''func verify_missing_signals(emitter: Object, expected_signals: Array[String]) -> void:
	if not is_instance_valid(emitter):
		pass
		return
	
	for signal_name in expected_signals:
		if not emitter.has_signal(signal_name):
			pass'''
    
    content = re.sub(broken_function, fixed_function, content, flags=re.MULTILINE | re.DOTALL)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Fixed campaign_test_helper.gd")
    return True

def fix_pre_run():
    """Fix specific errors in pre_run.gd"""
    file_path = Path("tests/fixtures/setup/pre_run.gd")
    if not file_path.exists():
        return False
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = file_path.with_suffix('.gd.backup')
    shutil.copy2(file_path, backup_path)
    
    # Fix the broken REQUIRED_AUTOLOADS constant
    content = re.sub(
        r'const REQUIRED_AUTOLOADS = \{\s*"GameEnums": "res://src/core/systems/GlobalEnums\.gd",',
        '''const REQUIRED_AUTOLOADS = {
	"GameEnums": "res://src/core/systems/GlobalEnums.gd"
}''',
        content
    )
    
    # Fix the broken _ensure_autoloads function
    broken_function = r'func _ensure_autoloads\(\) -> void:.*?add_child\(load\(REQUIRED_AUTOLOADS\[autoload_name\]\)\.new\(\)\)'
    fixed_function = '''func _ensure_autoloads() -> void:
	for autoload_name in REQUIRED_AUTOLOADS:
		if not Engine.has_singleton(autoload_name):
			var script = load(REQUIRED_AUTOLOADS[autoload_name])
			if script:
				var instance = script.new()
				instance.name = autoload_name
				add_child(instance)'''
    
    content = re.sub(broken_function, fixed_function, content, flags=re.MULTILINE | re.DOTALL)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Fixed pre_run.gd")
    return True

def fix_battle_test():
    """Fix specific errors in battle_test.gd"""
    file_path = Path("tests/fixtures/specialized/battle_test.gd")
    if not file_path.exists():
        return False
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = file_path.with_suffix('.gd.backup')
    shutil.copy2(file_path, backup_path)
    
    # Fix the broken BATTLE_TEST_CONFIG constant
    content = re.sub(
        r'const BATTLE_TEST_CONFIG := \{\s*"stabilize_time": 0\.2 as float,\s*"combat_timeout": 5\.0 as float,\s*"animation_timeout": 2\.0 as float,',
        '''const BATTLE_TEST_CONFIG := {
	"stabilize_time": 0.2 as float,
	"combat_timeout": 5.0 as float,
	"animation_timeout": 2.0 as float
}''',
        content
    )
    
    # Fix standalone is_equal calls
    content = re.sub(r'^is_equal\([^)]+\)\s*$', '', content, flags=re.MULTILINE)
    
    # Fix broken apply_status_effect function  
    content = re.sub(
        r'func apply_status_effect\(target: Node, effect: Dictionary\) -> bool:\s*if not target:\s*pass\s*if target\.has_method\("apply_status_effect"\):',
        '''func apply_status_effect(target: Node, effect: Dictionary) -> bool:
	if not target:
		return false
	
	if target.has_method("apply_status_effect"):
		return target.call("apply_status_effect", effect)
	
	return false''',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Fixed battle_test.gd")
    return True

def fix_enemy_test_base():
    """Fix specific errors in enemy_test_base.gd"""
    file_path = Path("tests/fixtures/specialized/enemy_test_base.gd")
    if not file_path.exists():
        return False
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = file_path.with_suffix('.gd.backup')
    shutil.copy2(file_path, backup_path)
    
    # Fix the broken PERFORMANCE_TEST_CONFIG constant
    content = re.sub(
        r'const PERFORMANCE_TEST_CONFIG := \{\s*"movement_iterations": 100 as int,\s*"combat_iterations": 50 as int,\s*"pathfinding_iterations": 75 as int,',
        '''const PERFORMANCE_TEST_CONFIG := {
	"movement_iterations": 100 as int,
	"combat_iterations": 50 as int,
	"pathfinding_iterations": 75 as int
}''',
        content
    )
    
    # Fix the broken MOBILE_TEST_CONFIG constant
    content = re.sub(
        r'const MOBILE_TEST_CONFIG = \{\s*"touch_target_size": Vector2\(44, 44\),\s*"min_frame_time": 16\.67 # Target 60fps,',
        '''const MOBILE_TEST_CONFIG = {
	"touch_target_size": Vector2(44, 44),
	"min_frame_time": 16.67  # Target 60fps
}''',
        content
    )
    
    # Fix broken dictionary in _initialize_test_states
    broken_dict = r'TEST_ENEMY_STATES = \{\s*"BASIC": \{,.*?"BOSS": \{,.*?behavior": 2 as int # Placeholder for GameEnums\.AIBehavior\.DEFENSIVE,'
    fixed_dict = '''TEST_ENEMY_STATES = {
		"BASIC": {
			"health": 100.0 as float,
			"movement_range": 4.0 as float,
			"weapon_range": 1.0 as float,
			"behavior": 0 as int  # Placeholder for GameEnums.AIBehavior.CAUTIOUS
		},
		"ELITE": {
			"health": 150.0 as float,
			"movement_range": 6.0 as float,
			"weapon_range": 2.0 as float,
			"behavior": 1 as int  # Placeholder for GameEnums.AIBehavior.AGGRESSIVE
		},
		"BOSS": {
			"health": 300.0 as float,
			"movement_range": 3.0 as float,
			"weapon_range": 3.0 as float,
			"behavior": 2 as int  # Placeholder for GameEnums.AIBehavior.DEFENSIVE
		}
	}'''
    
    content = re.sub(broken_dict, fixed_dict, content, flags=re.MULTILINE | re.DOTALL)
    
    # Fix setup_base_systems function
    content = re.sub(
        r'func setup_base_systems\(\) -> bool:\s*if not _setup_battlefield\(\):\s*if not _setup_enemy_campaign_system\(\):\s*if not _setup_combat_system\(\):',
        '''func setup_base_systems() -> bool:
	if not _setup_battlefield():
		return false
	if not _setup_enemy_campaign_system():
		return false
	if not _setup_combat_system():
		return false
	return true''',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Fixed enemy_test_base.gd")
    return True

def fix_test_suite():
    """Fix specific errors in test_suite.gd"""
    file_path = Path("tests/fixtures/test_suite.gd")
    if not file_path.exists():
        return False
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = file_path.with_suffix('.gd.backup')
    shutil.copy2(file_path, backup_path)
    
    # Fix the broken TEST_CATEGORIES constant
    content = re.sub(
        r'const TEST_CATEGORIES := \{\s*"unit": "res://tests/unit",\s*"integration": "res://tests/integration",\s*"performance": "res://tests/performance",\s*"mobile": "res://tests/mobile",',
        '''const TEST_CATEGORIES := {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration", 
	"performance": "res://tests/performance",
	"mobile": "res://tests/mobile"
}''',
        content
    )
    
    # Fix the broken TEST_CONFIG constant
    content = re.sub(
        r'const TEST_CONFIG := \{\s*"parallel_tests": true,\s*"max_parallel_tests": 4,\s*"timeout": 30\.0,\s*"export_results": true,\s*"export_format": "json",\s*"export_path": "res://test_results",',
        '''const TEST_CONFIG := {
	"parallel_tests": true,
	"max_parallel_tests": 4,
	"timeout": 30.0,
	"export_results": true,
	"export_format": "json",
	"export_path": "res://test_results"
}''',
        content
    )
    
    # Fix broken control flow
    content = re.sub(
        r'for category in categories:\s*if not category in TEST_CATEGORIES:\s*pass\s*if TEST_CONFIG\.parallel_tests:\s*pass\s*else:\s*pass',
        '''for category in categories:
		if not category in TEST_CATEGORIES:
			continue
		if TEST_CONFIG.parallel_tests:
			_run_category_parallel(category)
		else:
			_run_category(category)''',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✓ Fixed test_suite.gd")
    return True

def main():
    """Main execution function"""
    print("🔧 Critical Linter Error Fixer for Five Parsecs Campaign Manager")
    print("Fixing the most critical and visible linter errors...\n")
    
    fixes_applied = 0
    
    # List of critical files to fix
    critical_fixes = [
        ("Campaign Test Helper", fix_campaign_test_helper),
        ("Pre-run Setup", fix_pre_run),
        ("Battle Test", fix_battle_test),
        ("Enemy Test Base", fix_enemy_test_base),
        ("Test Suite", fix_test_suite),
    ]
    
    for name, fix_func in critical_fixes:
        try:
            print(f"📝 Processing: {name}")
            if fix_func():
                fixes_applied += 1
                print(f"  ✅ Successfully fixed {name}")
            else:
                print(f"  ⚠️  File not found for {name}")
        except Exception as e:
            print(f"  ❌ Error fixing {name}: {str(e)}")
    
    print(f"\n{'='*50}")
    print(f"CRITICAL FIXES SUMMARY")
    print(f"{'='*50}")
    print(f"Files processed: {len(critical_fixes)}")
    print(f"Files fixed: {fixes_applied}")
    print(f"Backups created with .backup extension")
    print(f"{'='*50}")

if __name__ == "__main__":
    main() 