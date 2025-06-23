#!/usr/bin/env python3
"""
Final Linter Error Fixer for Five Parsecs Campaign Manager
Addresses the remaining linter errors that previous scripts didn't catch.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

class FinalLinterErrorFixer:
    def __init__(self):
        self.backup_dir = Path("backups") / f"final_linter_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.fixes_applied = {}
        self.total_fixes = 0
        
    def create_backup(self, file_path):
        """Create backup of original file"""
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = self.backup_dir / file_path.name
        shutil.copy2(file_path, backup_path)
        
    def fix_final_linter_errors(self, file_path):
        """Fix remaining linter errors in a single file"""
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
            
            # 1. Fix functions missing bodies - add proper indented pass statements
            if re.match(r'^\s*func\s+\w+.*:\s*$', line.strip()):
                new_lines.append(line)
                
                # Check if next line has proper indentation or is another declaration
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    current_indent = len(line) - len(line.lstrip())
                    expected_body_indent = current_indent + 4
                    
                    # If next line is not properly indented function body
                    if (next_line.strip() and 
                        (len(next_line) - len(next_line.lstrip()) <= current_indent or
                         re.match(r'^\s*(func|class|#|if|for|while)', next_line.strip()))):
                        # Add missing function body
                        new_lines.append(' ' * expected_body_indent + 'pass\n')
                        fixes_count += 1
                i += 1
                continue
            
            # 2. Fix orphaned if statements that should be in function bodies
            if re.match(r'^\s*if\s+.*:\s*$', line.strip()) and not line.strip().startswith('#'):
                current_indent = len(line) - len(line.lstrip())
                
                # Check if this is an orphaned if statement (should be inside a function)
                if current_indent == 0 or current_indent == 4:
                    # Look back to see if we're inside a function
                    in_function = False
                    for j in range(i-1, max(0, i-10), -1):
                        if j < len(new_lines):
                            prev_line = new_lines[j]
                            if re.match(r'^\s*func\s+', prev_line.strip()):
                                in_function = True
                                break
                            elif re.match(r'^\s*(class|#)', prev_line.strip()):
                                break
                    
                    if in_function:
                        # Properly indent the if statement
                        line = '        ' + line.strip() + '\n'
                        fixes_count += 1
                        
                        # Also need to add pass statement for the if body
                        new_lines.append(line)
                        new_lines.append('            pass\n')
                        fixes_count += 1
                        i += 1
                        continue
            
            # 3. Fix orphaned for/while statements
            if re.match(r'^\s*(for|while)\s+.*:\s*$', line.strip()) and not line.strip().startswith('#'):
                current_indent = len(line) - len(line.lstrip())
                
                if current_indent <= 4:
                    # Look back to see if we're inside a function
                    in_function = False
                    for j in range(i-1, max(0, i-10), -1):
                        if j < len(new_lines):
                            prev_line = new_lines[j]
                            if re.match(r'^\s*func\s+', prev_line.strip()):
                                in_function = True
                                break
                    
                    if in_function:
                        # Properly indent the loop statement
                        line = '        ' + line.strip() + '\n'
                        fixes_count += 1
                        
                        # Add pass statement for the loop body
                        new_lines.append(line)
                        new_lines.append('            pass\n')
                        fixes_count += 1
                        i += 1
                        continue
            
            # 4. Fix orphaned variable assignments in class bodies
            if (re.match(r'^\s*\w+\s*=', line.strip()) and 
                not line.strip().startswith('#') and 
                not re.match(r'^\s*var\s+', line.strip())):
                
                current_indent = len(line) - len(line.lstrip())
                
                # Check if this should be inside a function
                if current_indent == 0:
                    # Look back to see context
                    in_class = False
                    in_function = False
                    
                    for j in range(i-1, max(0, i-20), -1):
                        if j < len(new_lines):
                            prev_line = new_lines[j]
                            if re.match(r'^\s*func\s+', prev_line.strip()):
                                in_function = True
                                break
                            elif re.match(r'^class\s+', prev_line.strip()):
                                in_class = True
                                break
                    
                    if in_function or in_class:
                        # Properly indent the assignment
                        if in_function:
                            line = '        ' + line.strip() + '\n'
                        else:
                            line = '    ' + line.strip() + '\n'
                        fixes_count += 1
            
            # 5. Fix incomplete dictionary declarations
            if re.match(r'^\s*"[^"]*":\s*[^,}]*,?\s*$', line.strip()):
                # This looks like a dictionary element that might be orphaned
                current_indent = len(line) - len(line.lstrip())
                
                if current_indent == 0:
                    # Look back for context
                    for j in range(i-1, max(0, i-5), -1):
                        if j < len(new_lines):
                            prev_line = new_lines[j]
                            if '{' in prev_line or re.match(r'^\s*"[^"]*":', prev_line.strip()):
                                # Should be indented as dictionary element
                                line = '    ' + line.strip() + '\n'
                                fixes_count += 1
                                break
            
            # 6. Fix missing return statements and function bodies
            if line.strip() == 'pass' and i > 0:
                prev_line = new_lines[-1] if new_lines else ""
                
                # If pass follows a function declaration, ensure it's properly indented
                if re.match(r'^\s*func\s+.*:\s*$', prev_line.strip()):
                    current_indent = len(line) - len(line.lstrip())
                    prev_indent = len(prev_line) - len(prev_line.lstrip())
                    expected_indent = prev_indent + 4
                    
                    if current_indent != expected_indent:
                        line = ' ' * expected_indent + 'pass\n'
                        fixes_count += 1
            
            # 7. Fix specific problematic patterns from the linter errors
            
            # Fix "Unexpected X in class body" errors by moving statements to proper functions
            if (line.strip().startswith('super.') or 
                line.strip().startswith('_game_state =') or
                line.strip().startswith('_phase_manager =') or
                line.strip().startswith('_campaign_system =')):
                
                current_indent = len(line) - len(line.lstrip())
                if current_indent <= 4:
                    # These should be in function bodies
                    line = '        ' + line.strip() + '\n'
                    fixes_count += 1
            
            # 8. Fix enum closing braces
            if (line.strip().startswith('enum ') and 
                i + 1 < len(lines) and 
                not '}' in ''.join(lines[i:i+10])):
                # Look ahead to find where enum should end
                enum_content = []
                j = i + 1
                while j < len(lines) and j < i + 10:
                    if (lines[j].strip() and 
                        not re.match(r'^\s*(class|func|#)', lines[j].strip()) and
                        not lines[j].strip() == '}'):
                        enum_content.append(lines[j])
                    else:
                        break
                    j += 1
                
                if enum_content:
                    new_lines.append(line)
                    new_lines.extend(enum_content)
                    new_lines.append('}\n')
                    fixes_count += 1
                    i = j - 1
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
            print(f"✅ Fixed {fixes_count} final linter errors in {file_path.name}")
        
        return True
    
    def fix_target_files(self):
        """Fix final linter errors in the specific files mentioned by the user"""
        
        target_files = [
            "tests/fixtures/runner/run_tests.gd",
            "tests/mobile/mission/test_mobile_campaign.gd",
            "tests/performance/enemy/test_enemy_large_groups.gd",
            "tests/performance/test_mission_performance.gd",
            "tests/unit/campaign/test_campaign_phase_transitions.gd",
            "tests/unit/campaign/test_campaign_state.gd",
            "tests/unit/campaign/test_patron.gd",
            "tests/unit/campaign/test_ship_component_system.gd",
            "tests/unit/campaign/test_ship_component_unit.gd",
            "tests/unit/campaign/test_story_quest_data.gd",
            "tests/unit/campaign/test_unified_story_system.gd",
            "tests/unit/core/test_game_settings.gd",
            "tests/unit/core/test_game_state_adapter.gd",
            "tests/unit/core/test_game_state.gd",
            "tests/unit/core/test_save_manager.gd",
            "tests/unit/mission/test_mission_template.gd",
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
        
        print(f"🔧 Starting final linter error fixes for {len(target_files)} test files...")
        
        files_processed = 0
        files_fixed = 0
        
        for file_path_str in target_files:
            file_path = Path(file_path_str)
            
            if file_path.exists():
                if self.fix_final_linter_errors(file_path):
                    files_processed += 1
                    if str(file_path) in self.fixes_applied:
                        files_fixed += 1
                else:
                    print(f"❌ Failed to process {file_path}")
            else:
                print(f"⚠️  File not found: {file_path}")
        
        print(f"\n🎯 **FINAL LINTER ERROR FIX SUMMARY**")
        print(f"Files processed: {files_processed}")
        print(f"Files with fixes: {files_fixed}")
        print(f"Total fixes applied: {self.total_fixes}")
        print(f"Backup directory: {self.backup_dir}")
        
        if self.fixes_applied:
            print(f"\n📝 **FILES WITH FINAL FIXES:**")
            sorted_fixes = sorted(self.fixes_applied.items(), key=lambda x: x[1], reverse=True)
            for file_path, count in sorted_fixes:
                print(f"  {Path(file_path).name}: {count} fixes")

if __name__ == "__main__":
    fixer = FinalLinterErrorFixer()
    fixer.fix_target_files() 