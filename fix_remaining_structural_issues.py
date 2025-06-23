#!/usr/bin/env python3
"""
Remaining Structural Issues Fixer for Five Parsecs Campaign Manager
Fixes very specific remaining structural problems that previous scripts missed.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

class RemainingStructuralFixer:
    def __init__(self):
        self.backup_dir = Path("backups") / f"remaining_structural_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.fixes_applied = {}
        self.total_fixes = 0
        
    def create_backup(self, file_path):
        """Create backup of original file"""
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = self.backup_dir / file_path.name
        shutil.copy2(file_path, backup_path)
        
    def fix_remaining_issues(self, file_path):
        """Fix remaining structural issues in a single file"""
        if not file_path.exists():
            return False
            
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Create backup
        self.create_backup(file_path)
        
        fixes_count = 0
        
        # Fix specific patterns in enemy_test_base.gd and similar files
        
        # 1. Fix missing closing braces for dictionaries
        content = re.sub(
            r'(const MOBILE_TEST_CONFIG := \{[^}]*)"min_frame_time": 16\.67 # Target 60fps,\s*\n\s*#',
            r'\1"min_frame_time": 16.67\n}\n#',
            content
        )
        if '# Target 60fps,' in content and 'const MOBILE_TEST_CONFIG' in content:
            fixes_count += 1
        
        # 2. Fix missing closing braces for TEST_ENEMY_STATES dictionary
        content = re.sub(
            r'("behavior": 2 as int # Placeholder for GameEnums\.AIBehavior\.DEFENSIVE,)\s*\n\s*\n\s*#',
            r'\1\n}\n}\n\n#',
            content
        )
        if '"behavior": 2 as int # Placeholder for GameEnums.AIBehavior.DEFENSIVE,' in content:
            fixes_count += 1
        
        # 3. Fix improperly nested functions - move them to proper class/module level
        # Look for functions that are indented more than they should be
        lines = content.split('\n')
        new_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            
            # Fix functions that are incorrectly indented (should be at module level)
            if re.match(r'^\s{8,}func\s+\w+', line):
                # Move to module level (no indentation)
                line = line.strip()
                fixes_count += 1
            
            # Fix nested statements that should be at module level
            elif re.match(r'^\s{8,}(if|for|while)\s+', line):
                # Reduce indentation significantly
                line = '    ' + line.strip()
                fixes_count += 1
            
            new_lines.append(line)
            i += 1
        
        content = '\n'.join(new_lines)
        
        # 4. Fix orphaned function parameters and statements
        content = re.sub(r'^if not _setup_enemy_campaign_system\(\):\s*$', '    if not _setup_enemy_campaign_system():', content, flags=re.MULTILINE)
        content = re.sub(r'^if not _setup_combat_system\(\):\s*$', '    if not _setup_combat_system():', content, flags=re.MULTILINE)
        content = re.sub(r'^if not _battlefield:\s*$', '    if not _battlefield:', content, flags=re.MULTILINE)
        content = re.sub(r'^if not _enemy_campaign_system:\s*$', '    if not _enemy_campaign_system:', content, flags=re.MULTILINE)
        content = re.sub(r'^if not _combat_system:\s*$', '    if not _combat_system:', content, flags=re.MULTILINE)
        
        if 'if not _setup_' in content:
            fixes_count += 3
        
        # 5. Fix orphaned variable assignments
        content = re.sub(r'^_enemy_data = null\s*$', '    _enemy_data = null', content, flags=re.MULTILINE)
        content = re.sub(r'^_battlefield = null\s*$', '    _battlefield = null', content, flags=re.MULTILINE)
        content = re.sub(r'^_enemy_campaign_system = null\s*$', '    _enemy_campaign_system = null', content, flags=re.MULTILINE)
        content = re.sub(r'^_combat_system = null\s*$', '    _combat_system = null', content, flags=re.MULTILINE)
        content = re.sub(r'^metrics\["', '    metrics["', content, flags=re.MULTILINE)
        
        if '_enemy_data = null' in content or 'metrics["' in content:
            fixes_count += 2
        
        # 6. Fix screen transition manager tab issues
        if 'transition_started.emit' in content:
            # Fix tab indentation in function bodies
            content = re.sub(r'\t+transition_started\.emit', '        transition_started.emit', content)
            content = re.sub(r'\t+transition_completed\.emit', '        transition_completed.emit', content)
            content = re.sub(r'\t+transition_interrupted\.emit', '        transition_interrupted.emit', content)
            content = re.sub(r'\t+transition_queue\.append', '        transition_queue.append', content)
            fixes_count += 4
        
        # 7. Fix function body indentation issues
        content = re.sub(r'^    is_transition_active = true\s*$', '        is_transition_active = true', content, flags=re.MULTILINE)
        content = re.sub(r'^    current_transition_type = ', '        current_transition_type = ', content, flags=re.MULTILINE)
        content = re.sub(r'^    transition_duration = ', '        transition_duration = ', content, flags=re.MULTILINE)
        content = re.sub(r'^    was_interrupted_flag = ', '        was_interrupted_flag = ', content, flags=re.MULTILINE)
        
        if 'is_transition_active = true' in content:
            fixes_count += 3
        
        # 8. Fix specific problematic method calls
        content = re.sub(r'enemy\.call\("engage_target": ,target\)', 'enemy.call("engage_target", target)', content)
        content = re.sub(r'enemy\.call\(": initialize",data\)', 'enemy.call("initialize", data)', content)
        content = re.sub(r'enemy\.call\(": move_to",', 'enemy.call("move_to", ', content)
        content = re.sub(r'enemy\.call\(": engage_target",', 'enemy.call("engage_target", ', content)
        content = re.sub(r'data\.call\(": set_" \+ key,', 'data.call("set_" + key, ', content)
        
        if '": initialize"' in content or '": move_to"' in content:
            fixes_count += 2
        
        # Write the fixed content back to file
        if fixes_count > 0:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            self.fixes_applied[str(file_path)] = fixes_count
            self.total_fixes += fixes_count
            print(f"✅ Fixed {fixes_count} remaining structural issues in {file_path.name}")
        
        return True
    
    def fix_target_files(self):
        """Fix remaining structural issues in the specific files mentioned by the user"""
        
        target_files = [
            "tests/fixtures/runner/run_tests.gd",
            "tests/fixtures/specialized/campaign_test.gd", 
            "tests/fixtures/specialized/enemy_test_base.gd",
            "tests/mobile/mission/test_mobile_campaign.gd",
            "tests/performance/test_mission_performance.gd",
            "tests/unit/campaign/test_campaign_phase_transitions.gd",
            "tests/performance/enemy/test_enemy_large_groups.gd",
            "tests/unit/campaign/test_campaign_state.gd",
            "tests/unit/campaign/test_patron.gd",
            "tests/unit/campaign/test_ship_component_system.gd",
            "tests/unit/campaign/test_ship_component_unit.gd",
            "tests/unit/campaign/test_resource_system.gd",
            "tests/unit/campaign/test_story_quest_data.gd",
            "tests/unit/campaign/test_unified_story_system.gd",
            "tests/unit/core/test_game_settings.gd",
            "tests/unit/core/test_game_state_adapter.gd",
            "tests/unit/core/test_game_state.gd",
            "tests/unit/core/test_save_manager.gd",
            "tests/unit/mission/test_mission_template.gd",
            "tests/unit/ship/test_ship_creation.gd",
            "tests/unit/ship/test_ship.gd",
            "tests/unit/terrain/test_position_validator.gd",
            "tests/unit/tutorial/test_tutorial_system.gd",
            "tests/unit/ui/campaign/test_action_panel.gd",
            "tests/unit/ui/campaign/test_campaign_phase_transitions.gd",
            "tests/unit/ui/campaign/test_event_item.gd",
            "tests/unit/ui/campaign/test_event_log.gd",
            "tests/unit/ui/screens/campaign/test_config_panel.gd",
            "tests/unit/ui/screens/test_screen_transition_manager.gd",
            "tests/unit/ui/test_rule_editor.gd"
        ]
        
        print(f"🔧 Starting remaining structural fixes for {len(target_files)} test files...")
        
        files_processed = 0
        files_fixed = 0
        
        for file_path_str in target_files:
            file_path = Path(file_path_str)
            
            if file_path.exists():
                if self.fix_remaining_issues(file_path):
                    files_processed += 1
                    if str(file_path) in self.fixes_applied:
                        files_fixed += 1
                else:
                    print(f"❌ Failed to process {file_path}")
            else:
                print(f"⚠️  File not found: {file_path}")
        
        print(f"\n🎯 **REMAINING STRUCTURAL FIX SUMMARY**")
        print(f"Files processed: {files_processed}")
        print(f"Files with fixes: {files_fixed}")
        print(f"Total fixes applied: {self.total_fixes}")
        print(f"Backup directory: {self.backup_dir}")
        
        if self.fixes_applied:
            print(f"\n📝 **FILES WITH REMAINING FIXES:**")
            sorted_fixes = sorted(self.fixes_applied.items(), key=lambda x: x[1], reverse=True)
            for file_path, count in sorted_fixes:
                print(f"  {Path(file_path).name}: {count} fixes")

if __name__ == "__main__":
    fixer = RemainingStructuralFixer()
    fixer.fix_target_files() 