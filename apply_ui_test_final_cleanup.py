#!/usr/bin/env python3
"""
Final UI Test Cleanup - Phase 3
Handles remaining specific linter errors and final cleanup
"""

import os
import re
import shutil
from datetime import datetime
from typing import List, Tuple, Dict

TARGET_FILES = [
    "tests/unit/ui/campaign/test_campaign_phase_transitions.gd",
    "tests/unit/ui/campaign/test_campaign_phase_ui.gd", 
    "tests/unit/ui/campaign/test_campaign_ui.gd",
    "tests/unit/ui/campaign/test_event_item.gd",
    "tests/unit/ui/campaign/test_event_log.gd",
    "tests/unit/ui/campaign/test_phase_indicator.gd",
    "tests/unit/ui/themes/test_theme_manager.gd",
    "tests/unit/ui/campaign/test_resource_item.gd",
    "tests/unit/ui/campaign/test_resource_panel.gd"
]

class FinalUITestCleanup:
    def __init__(self):
        self.fixes_applied = 0
        self.files_processed = 0
        self.backup_dir = f"backups/ui_test_final_cleanup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
    def create_backup(self, file_path: str) -> bool:
        """Create backup of file before modification"""
        try:
            os.makedirs(self.backup_dir, exist_ok=True)
            backup_path = os.path.join(self.backup_dir, os.path.basename(file_path))
            shutil.copy2(file_path, backup_path)
            return True
        except Exception as e:
            print(f"Failed to create backup for {file_path}: {e}")
            return False
    
    def fix_orphaned_statements_between_functions(self, content: str) -> Tuple[str, int]:
        """Fix statements that appear between functions without proper indentation"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        current_function_indent = None
        
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            line_indent = len(line) - len(line.lstrip()) if line.strip() else 0
            
            # Track function definitions
            if re.match(r'^\s*func\s+', line):
                current_function_indent = line_indent
                fixed_lines.append(line)
            elif stripped == "" or stripped.startswith('#'):
                fixed_lines.append(line)
            elif re.match(r'^\s*class\s+', line):
                current_function_indent = None
                fixed_lines.append(line)
            # Handle orphaned statements like _phase_manager.transition_to(1)
            elif (re.match(r'^\s*[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_]', line) and
                  current_function_indent is not None and
                  line_indent <= current_function_indent):
                # This is an orphaned method call, move it into the previous function
                # Find the most recent function
                for j in range(len(fixed_lines) - 1, -1, -1):
                    if re.match(r'^\s*func\s+', fixed_lines[j]):
                        func_indent = len(fixed_lines[j]) - len(fixed_lines[j].lstrip())
                        proper_indent = ' ' * (func_indent + 4)
                        method_call_line = proper_indent + stripped
                        
                        # Insert after the function declaration
                        insert_pos = j + 1
                        # Skip empty lines and comments
                        while (insert_pos < len(fixed_lines) and 
                               (fixed_lines[insert_pos].strip() == '' or 
                                fixed_lines[insert_pos].strip().startswith('#') or
                                fixed_lines[insert_pos].strip() == 'pass')):
                            insert_pos += 1
                        
                        # If we found a pass, replace it; otherwise insert before
                        if (insert_pos - 1 < len(fixed_lines) and 
                            fixed_lines[insert_pos - 1].strip() == 'pass'):
                            fixed_lines[insert_pos - 1] = method_call_line
                        else:
                            fixed_lines.insert(insert_pos, method_call_line)
                        
                        fixes += 1
                        break
                else:
                    # No function found, comment it out
                    fixed_lines.append('    # ' + line + '  # ORPHANED METHOD CALL - commented out')
                    fixes += 1
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_missing_variable_declarations(self, content: str) -> Tuple[str, int]:
        """Add missing variable declarations in class bodies"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        # Track variables that need to be declared
        variables_used = set()
        variables_declared = set()
        
        # First pass: identify variables
        for line in lines:
            # Find variable assignments
            assign_match = re.match(r'^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=', line)
            if assign_match and not line.strip().startswith('var '):
                var_name = assign_match.group(1)
                if not var_name.startswith('_') or var_name in ['_component', '_event_log', '_phase_manager']:
                    variables_used.add(var_name)
            
            # Find variable declarations
            var_match = re.match(r'^\s*var\s+([a-zA-Z_][a-zA-Z0-9_]*)', line)
            if var_match:
                variables_declared.add(var_match.group(1))
        
        # Variables that need to be declared
        need_declaration = variables_used - variables_declared
        
        # Second pass: add declarations and fix structure
        i = 0
        in_class = False
        class_indent = 0
        declarations_added = False
        
        while i < len(lines):
            line = lines[i]
            
            if re.match(r'^\s*class\s+', line):
                in_class = True
                class_indent = len(line) - len(line.lstrip())
                fixed_lines.append(line)
                
                # Add variable declarations after class definition
                if need_declaration and not declarations_added:
                    for var_name in sorted(need_declaration):
                        if var_name in ['_component', '_event_log', '_phase_manager']:
                            fixed_lines.append(' ' * (class_indent + 4) + f'var {var_name}: Node = null')
                        else:
                            fixed_lines.append(' ' * (class_indent + 4) + f'var {var_name}: Variant')
                    fixed_lines.append('')  # Empty line after declarations
                    fixes += len(need_declaration)
                    declarations_added = True
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_incomplete_control_blocks(self, content: str) -> Tuple[str, int]:
        """Fix incomplete control blocks (if/for without proper bodies)"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Check for control structures
            if re.match(r'^\s*(if|for|while)\s+.*:\s*$', line):
                fixed_lines.append(line)
                
                # Check if the next non-empty line is properly indented
                j = i + 1
                has_body = False
                control_indent = len(line) - len(line.lstrip())
                
                while j < len(lines):
                    next_line = lines[j]
                    if next_line.strip() == "":
                        j += 1
                        continue
                    
                    next_indent = len(next_line) - len(next_line.lstrip())
                    
                    if next_indent > control_indent:
                        has_body = True
                        break
                    else:
                        # Next line at same level or lower, no body
                        break
                
                if not has_body:
                    fixed_lines.append(' ' * (control_indent + 4) + 'pass')
                    fixes += 1
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def clean_up_syntax_errors(self, content: str) -> Tuple[str, int]:
        """Clean up remaining syntax errors"""
        fixes = 0
        
        # Fix common patterns
        patterns = [
            # Fix incomplete function return types
            (r'(\s*func\s+\w+.*)->\s*$', r'\1-> void:'),
            # Fix missing colons after function definitions
            (r'(\s*func\s+\w+.*\))\s*$', r'\1:'),
            # Fix orphaned 'pass' statements that should be indented
            (r'^(\s*)pass\s*$', lambda m: m.group(1) + 'pass' if len(m.group(1)) > 0 else '    pass'),
        ]
        
        for pattern, replacement in patterns:
            if callable(replacement):
                content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            else:
                old_content = content
                content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
                if content != old_content:
                    fixes += content.count(replacement.split(':')[0]) - old_content.count(replacement.split(':')[0])
        
        return content, fixes
    
    def apply_final_cleanup(self, file_path: str) -> int:
        """Apply final cleanup to a single file"""
        if not os.path.exists(file_path):
            print(f"File not found: {file_path}")
            return 0
        
        # Create backup
        if not self.create_backup(file_path):
            print(f"Skipping {file_path} - backup failed")
            return 0
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            total_fixes = 0
            
            print(f"Processing {file_path}...")
            
            # Apply final cleanup fixes
            content, fixes = self.fix_orphaned_statements_between_functions(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Orphaned statement fixes: {fixes}")
            
            content, fixes = self.fix_missing_variable_declarations(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Variable declaration fixes: {fixes}")
            
            content, fixes = self.fix_incomplete_control_blocks(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Control block fixes: {fixes}")
            
            content, fixes = self.clean_up_syntax_errors(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Syntax error fixes: {fixes}")
            
            # Write the fixed content
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"  ✓ Applied {total_fixes} final fixes to {file_path}")
            else:
                print(f"  - No final fixes needed for {file_path}")
            
            return total_fixes
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            return 0
    
    def run(self):
        """Run the final cleanup"""
        print("=" * 60)
        print("Final UI Test Cleanup - Phase 3")
        print("=" * 60)
        
        total_fixes = 0
        processed_files = 0
        
        for file_path in TARGET_FILES:
            fixes = self.apply_final_cleanup(file_path)
            total_fixes += fixes
            if fixes > 0:
                processed_files += 1
        
        print("\n" + "=" * 60)
        print("FINAL CLEANUP SUMMARY")
        print("=" * 60)
        print(f"Files processed: {processed_files}")
        print(f"Total final fixes applied: {total_fixes}")
        print(f"Backup directory: {self.backup_dir}")
        print("=" * 60)
        
        return total_fixes > 0

if __name__ == "__main__":
    fixer = FinalUITestCleanup()
    success = fixer.run()
    
    if success:
        print("\n✅ Final UI test cleanup completed successfully!")
        print("Please review the changes and test the files.")
    else:
        print("\n❌ No final fixes were applied or errors occurred.") 