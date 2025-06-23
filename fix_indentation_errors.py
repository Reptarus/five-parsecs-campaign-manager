#!/usr/bin/env python3
"""
Indentation Error Fixer for Five Parsecs Campaign Manager
Fixes indentation issues in test files including missing blocks, mixed tabs/spaces, and orphaned indents.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

class IndentationFixer:
    def __init__(self):
        self.backup_dir = Path("backups") / f"indentation_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.fixes_applied = {}
        self.total_fixes = 0
        
    def create_backup(self, file_path):
        """Create backup of original file"""
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = self.backup_dir / file_path.name
        shutil.copy2(file_path, backup_path)
        
    def fix_indentation_errors(self, file_path):
        """Fix indentation errors in a single file"""
        if not file_path.exists():
            return False
            
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Create backup
        self.create_backup(file_path)
        
        fixes_count = 0
        new_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            original_line = line
            
            # Convert tabs to spaces (4 spaces per tab)
            if '\t' in line:
                line = line.replace('\t', '    ')
                fixes_count += 1
            
            # Fix missing indented blocks after function declarations
            if re.match(r'.*func\s+\w+\([^)]*\)\s*(->\s*\w+\s*)?:\s*$', line.strip()):
                # Check if next line exists and is properly indented
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.strip() and not next_line.startswith('    ') and not next_line.startswith('\t'):
                        # Add proper indentation
                        new_lines.append(line)
                        new_lines.append('    pass\n')
                        i += 1
                        fixes_count += 1
                        continue
            
            # Fix missing indented blocks after if/for/while statements
            if re.match(r'.*\b(if|for|while|elif|else)\b.*:\s*$', line.strip()) and not line.strip().startswith('#'):
                # Check if next line exists and is properly indented
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.strip() and not next_line.startswith('    ') and not next_line.startswith('\t'):
                        # Add proper indentation
                        new_lines.append(line)
                        new_lines.append('    pass\n')
                        i += 1
                        fixes_count += 1
                        continue
            
            # Fix missing indented blocks after match patterns
            if re.match(r'.*\b(match)\b.*:\s*$', line.strip()):
                # Check if next line exists and is properly indented
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.strip() and not next_line.startswith('    ') and not next_line.startswith('\t'):
                        # Add proper indentation
                        new_lines.append(line)
                        new_lines.append('    pass\n')
                        i += 1
                        fixes_count += 1
                        continue
            
            # Fix missing indented blocks after class declarations
            if re.match(r'.*class\s+\w+.*:\s*$', line.strip()):
                # Check if next line exists and is properly indented
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.strip() and not next_line.startswith('    ') and not next_line.startswith('\t'):
                        # Add proper indentation
                        new_lines.append(line)
                        new_lines.append('    pass\n')
                        i += 1
                        fixes_count += 1
                        continue
            
            # Fix missing indented blocks after enum declarations
            if re.match(r'.*enum\s+\w+.*:\s*$', line.strip()):
                # Check if next line exists and is properly indented
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if next_line.strip() and not next_line.startswith('    ') and not next_line.startswith('\t'):
                        # Add proper indentation
                        new_lines.append(line)
                        new_lines.append('    NONE = 0\n')
                        i += 1
                        fixes_count += 1
                        continue
            
            # Remove orphaned indented lines that don't belong to any block
            if line.strip() and (line.startswith('    ') or line.startswith('\t')):
                # Check if previous line ended a block or is a comment
                if i > 0:
                    prev_line = new_lines[-1] if new_lines else ""
                    if (not prev_line.strip().endswith(':') and 
                        not prev_line.strip().startswith('#') and
                        prev_line.strip() and
                        not re.match(r'.*(if|for|while|elif|else|func|class|match).*:', prev_line.strip())):
                        # This might be an orphaned indent - move to proper level
                        line = line.lstrip()
                        fixes_count += 1
            
            # Fix specific patterns from the error messages
            
            # Fix dictionary syntax errors (orphaned colons and values)
            if re.match(r'^["\w]+:\s*$', line.strip()):
                # Orphaned dictionary key - remove the line
                fixes_count += 1
                i += 1
                continue
                
            # Fix orphaned return statements
            if line.strip() == 'return false' or line.strip() == 'return true':
                # Check if this is orphaned
                if i > 0 and not new_lines[-1].strip().endswith(':'):
                    line = '    ' + line.strip() + '\n'
                    fixes_count += 1
            
            # Fix specific error patterns
            
            # Remove lines that are just "pass" without proper context
            if line.strip() == 'pass' and i > 0:
                prev_line = new_lines[-1] if new_lines else ""
                if not prev_line.strip().endswith(':'):
                    # This pass doesn't belong here
                    fixes_count += 1
                    i += 1
                    continue
            
            new_lines.append(line)
            i += 1
        
        # Write the fixed content back to file
        if fixes_count > 0:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            
            self.fixes_applied[str(file_path)] = fixes_count
            self.total_fixes += fixes_count
            print(f"✅ Fixed {fixes_count} indentation issues in {file_path.name}")
        
        return True
    
    def fix_all_files(self):
        """Fix indentation errors in all specified test files"""
        
        # List of files to fix based on user's request
        test_files = [
            "tests/fixtures/helpers/campaign_test_helper.gd",
            "tests/fixtures/runner/run_tests.gd", 
            "tests/fixtures/specialized/battle_test.gd",
            "tests/fixtures/specialized/campaign_test.gd",
            "tests/fixtures/specialized/enemy_test_base.gd",
            "tests/fixtures/test_suite.gd",
            "tests/integration/battle/test_battle_phase_flow.gd",
            "tests/integration/campaign/test_campaign_phase_manager.gd",
            "tests/integration/enemy/test_enemy_group_tactics.gd",
            "tests/mobile/mission/test_mobile_campaign.gd",
            "tests/mobile/ui/test_mobile_ui.gd",
            "tests/performance/combat/perf_test_battle_system.gd",
            "tests/performance/enemy/test_enemy_large_groups.gd",
            "tests/performance/test_mission_performance.gd",
            "tests/performance/perf_test_battle_system.gd",
            "tests/unit/battle/test_battle_events_system.gd",
            "tests/performance/test_table_processor.gd",
            "tests/unit/battle/ai/test_enemy_state.gd",
            "tests/unit/campaign/test_campaign_phase_transitions.gd",
            "tests/unit/campaign/test_campaign_state.gd",
            "tests/unit/campaign/test_game_state_manager.gd",
            "tests/unit/campaign/test_patron.gd",
            "tests/unit/campaign/test_resource_system.gd",
            "tests/unit/campaign/test_rival.gd",
            "tests/unit/campaign/test_ship_component_system.gd",
            "tests/unit/campaign/test_ship_component_unit.gd",
            "tests/unit/campaign/test_story_quest_data.gd",
            "tests/unit/campaign/test_unified_story_system.gd",
            "tests/unit/core/test_game_settings.gd",
            "tests/unit/core/test_save_manager.gd",
            "tests/unit/core/test_game_state_adapter.gd",
            "tests/unit/core/test_game_state.gd",
            "tests/unit/core/test_sector_manager.gd",
            "tests/unit/core/test_serializable_resource.gd",
            "tests/unit/ship/test_hull_component.gd",
            "tests/unit/mission/test_mission_template.gd",
            "tests/unit/ship/test_engine_component.gd",
            "tests/unit/ship/test_medical_bay_component.gd",
            "tests/unit/ship/test_ship_creation.gd",
            "tests/unit/ship/test_ship.gd",
            "tests/unit/ship/test_weapon_component.gd",
            "tests/unit/ship/test_weapon.gd",
            "tests/unit/ships/test_ship.gd",
            "tests/unit/story/test_story_track_system.gd",
            "tests/unit/terrain/test_position_validator.gd",
            "tests/unit/tutorial/test_tutorial_system.gd",
            "tests/unit/ui/base/component_test_base.gd",
            "tests/unit/ui/campaign/test_action_button.gd",
            "tests/unit/ui/campaign/test_action_panel.gd",
            "tests/unit/ui/campaign/test_campaign_phase_transitions.gd",
            "tests/unit/ui/campaign/test_campaign_ui.gd",
            "tests/unit/ui/themes/test_theme_manager.gd",
            "tests/unit/ui/campaign/test_event_item.gd",
            "tests/examples/gdunit4_example_test.gd",
            "tests/unit/ui/campaign/test_event_log.gd",
            "tests/fixtures/base/gdunit_game_test.gd",
            "tests/unit/ui/screens/campaign/test_campaign_setup_screen.gd",
            "tests/unit/ui/screens/campaign/test_config_panel.gd",
            "tests/unit/ui/screens/campaign/test_upkeep_phase_ui.gd",
            "tests/unit/ui/screens/test_ui_manager.gd",
            "tests/unit/ui/test_rule_editor.gd"
        ]
        
        print(f"🔧 Starting indentation fixes for {len(test_files)} test files...")
        
        files_processed = 0
        files_fixed = 0
        
        for file_path_str in test_files:
            file_path = Path(file_path_str)
            
            if file_path.exists():
                if self.fix_indentation_errors(file_path):
                    files_processed += 1
                    if str(file_path) in self.fixes_applied:
                        files_fixed += 1
                else:
                    print(f"❌ Failed to process {file_path}")
            else:
                print(f"⚠️  File not found: {file_path}")
        
        print(f"\n🎯 **INDENTATION FIX SUMMARY**")
        print(f"Files processed: {files_processed}")
        print(f"Files with fixes: {files_fixed}")
        print(f"Total fixes applied: {self.total_fixes}")
        print(f"Backup directory: {self.backup_dir}")
        
        if self.fixes_applied:
            print(f"\n📝 **TOP FILES WITH MOST FIXES:**")
            sorted_fixes = sorted(self.fixes_applied.items(), key=lambda x: x[1], reverse=True)
            for file_path, count in sorted_fixes[:10]:
                print(f"  {Path(file_path).name}: {count} fixes")

if __name__ == "__main__":
    fixer = IndentationFixer()
    fixer.fix_all_files() 