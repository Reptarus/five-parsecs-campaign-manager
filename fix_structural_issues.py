#!/usr/bin/env python3
"""
Structural Issues Fixer for Five Parsecs Campaign Manager
Fixes remaining structural problems including mixed indentation, dictionary closures, and nested function issues.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

class StructuralIssuesFixer:
    def __init__(self):
        self.backup_dir = Path("backups") / f"structural_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.fixes_applied = {}
        self.total_fixes = 0
        
    def create_backup(self, file_path):
        """Create backup of original file"""
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = self.backup_dir / file_path.name
        shutil.copy2(file_path, backup_path)
        
    def fix_structural_issues(self, file_path):
        """Fix structural issues in a single file"""
        if not file_path.exists():
            return False
            
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Create backup
        self.create_backup(file_path)
        
        fixes_count = 0
        new_lines = []
        i = 0
        in_class = False
        class_indent_level = 0
        brace_stack = []
        
        while i < len(lines):
            line = lines[i]
            original_line = line
            
            # Track class context
            if re.match(r'^class\s+\w+', line.strip()):
                in_class = True
                class_indent_level = len(line) - len(line.lstrip())
            
            # Convert all tabs to spaces consistently
            if '\t' in line:
                line = line.replace('\t', '    ')
                fixes_count += 1
            
            # Fix dictionary and constant declaration issues
            if re.match(r'^\s*const\s+\w+\s*:=\s*{', line):
                # This starts a dictionary constant
                brace_stack.append('{')
                
                # Check if the dictionary is missing closing brace
                remaining_lines = lines[i+1:]
                found_closing = False
                for j, next_line in enumerate(remaining_lines):
                    if '}' in next_line:
                        found_closing = True
                        break
                    if re.match(r'^\s*(const|func|class|var)', next_line.strip()):
                        # Found another declaration before closing brace
                        break
                
                if not found_closing and i + 1 < len(lines):
                    # Add missing closing brace before the next major declaration
                    new_lines.append(line)
                    
                    # Look ahead to find where to insert the closing brace
                    j = i + 1
                    while j < len(lines) and not re.match(r'^\s*(const|func|class|var|#)', lines[j].strip()):
                        if lines[j].strip():  # Non-empty line
                            new_lines.append(lines[j])
                        j += 1
                    
                    # Add the missing closing brace
                    new_lines.append('}\n')
                    fixes_count += 1
                    i = j - 1  # Skip processed lines
                    i += 1
                    continue
            
            # Fix function declarations that are improperly indented in class
            if re.match(r'^\s*func\s+\w+', line.strip()) and in_class:
                current_indent = len(line) - len(line.lstrip())
                expected_indent = class_indent_level + 4
                
                if current_indent != expected_indent:
                    line = ' ' * expected_indent + line.strip() + '\n'
                    fixes_count += 1
            
            # Fix orphaned statements in class bodies
            if in_class and line.strip():
                current_indent = len(line) - len(line.lstrip())
                
                # Check for variable assignments that should be class members
                if re.match(r'^\s*\w+\s*=', line.strip()) and not line.strip().startswith('#'):
                    expected_indent = class_indent_level + 4
                    if current_indent != expected_indent and current_indent == 0:
                        line = ' ' * expected_indent + line.strip() + '\n'
                        fixes_count += 1
                
                # Check for signal declarations
                if re.match(r'^\s*signal\s+\w+', line.strip()):
                    expected_indent = class_indent_level + 4
                    if current_indent != expected_indent:
                        line = ' ' * expected_indent + line.strip() + '\n'
                        fixes_count += 1
            
            # Fix function body issues - ensure pass statements are properly indented
            if line.strip() == 'pass':
                # Check if this follows a function or control structure
                if i > 0:
                    prev_line = new_lines[-1] if new_lines else ""
                    if prev_line.strip().endswith(':'):
                        # Calculate proper indentation
                        prev_indent = len(prev_line) - len(prev_line.lstrip())
                        expected_indent = prev_indent + 4
                        current_indent = len(line) - len(line.lstrip())
                        
                        if current_indent != expected_indent:
                            line = ' ' * expected_indent + 'pass\n'
                            fixes_count += 1
            
            # Fix nested function issues - move improperly nested functions to class level
            if re.match(r'^\s{8,}func\s+\w+', line):  # Function indented more than 8 spaces
                if in_class:
                    # This might be overly indented - move to proper class level
                    expected_indent = class_indent_level + 4
                    line = ' ' * expected_indent + line.strip() + '\n'
                    fixes_count += 1
            
            # Fix dictionary elements that are orphaned
            if re.match(r'^\s*"[^"]*":\s*[^,}]*,?\s*$', line.strip()):
                # This looks like a dictionary element
                if i > 0:
                    prev_line = new_lines[-1] if new_lines else ""
                    current_indent = len(line) - len(line.lstrip())
                    
                    # If previous line contains an opening brace or is another dict element
                    if ('{' in prev_line or 
                        re.match(r'^\s*"[^"]*":\s*[^,}]*,?\s*$', prev_line.strip())):
                        
                        # Should be indented from the opening brace
                        if current_indent == 0:
                            line = '    ' + line.strip() + '\n'
                            fixes_count += 1
            
            # Remove empty lines that break structure
            if not line.strip() and i > 0 and i < len(lines) - 1:
                prev_line = new_lines[-1] if new_lines else ""
                next_line = lines[i + 1] if i + 1 < len(lines) else ""
                
                # Don't keep empty lines between certain constructs
                if (re.match(r'^\s*(func|class|const)', prev_line.strip()) and
                    re.match(r'^\s*\w+\s*=', next_line.strip())):
                    fixes_count += 1
                    i += 1
                    continue
            
            # Fix specific problematic patterns
            
            # Remove standalone operators or malformed lines
            if line.strip() in [':', '=', ',', ';', '_:', 'Err']:
                fixes_count += 1
                i += 1
                continue
            
            # Fix lines that start with unexpected tokens
            if re.match(r'^\s*(Err|Unexpected|Expected)', line.strip()):
                # These are probably error messages that shouldn't be in the code
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
            print(f"✅ Fixed {fixes_count} structural issues in {file_path.name}")
        
        return True
    
    def fix_target_files(self):
        """Fix structural issues in the specific files mentioned by the user"""
        
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
        
        print(f"🔧 Starting structural fixes for {len(target_files)} test files...")
        
        files_processed = 0
        files_fixed = 0
        
        for file_path_str in target_files:
            file_path = Path(file_path_str)
            
            if file_path.exists():
                if self.fix_structural_issues(file_path):
                    files_processed += 1
                    if str(file_path) in self.fixes_applied:
                        files_fixed += 1
                else:
                    print(f"❌ Failed to process {file_path}")
            else:
                print(f"⚠️  File not found: {file_path}")
        
        print(f"\n🎯 **STRUCTURAL FIX SUMMARY**")
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
    fixer = StructuralIssuesFixer()
    fixer.fix_target_files() 