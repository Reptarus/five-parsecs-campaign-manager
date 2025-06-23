#!/usr/bin/env python3
"""
Advanced UI Test Linter Fixes - Phase 2
Handles complex structural issues and remaining linter errors
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

class AdvancedUITestFixer:
    def __init__(self):
        self.fixes_applied = 0
        self.files_processed = 0
        self.backup_dir = f"backups/ui_test_advanced_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
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
    
    def fix_orphaned_dictionary_entries(self, content: str) -> Tuple[str, int]:
        """Fix orphaned dictionary entries and malformed dictionaries"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            
            # Pattern 1: Lines like '"current_phase": 0,' outside dictionaries
            if re.match(r'^\s*"[^"]*":\s*[^,]*,?\s*$', stripped) and not stripped.startswith('#'):
                # Look back to see if we're in a dictionary context
                in_dict_context = False
                for j in range(i-1, max(0, i-10), -1):
                    prev_line = lines[j].strip()
                    if '{' in prev_line or prev_line.endswith('= {') or 'dict' in prev_line.lower():
                        in_dict_context = True
                        break
                    if prev_line and not prev_line.startswith('#') and not re.match(r'^\s*"[^"]*":', prev_line):
                        break
                
                if not in_dict_context:
                    fixed_lines.append('    # ' + line + '  # ORPHANED DICT ENTRY - commented out')
                    fixes += 1
                else:
                    fixed_lines.append(line)
            
            # Pattern 2: Standalone array elements
            elif re.match(r'^\s*"[^"]*",?\s*$', stripped) and not stripped.startswith('#'):
                # Check if this is an orphaned array element
                in_array_context = False
                for j in range(i-1, max(0, i-5), -1):
                    prev_line = lines[j].strip()
                    if '[' in prev_line or 'Array' in prev_line:
                        in_array_context = True
                        break
                    if prev_line and not prev_line.startswith('#') and not re.match(r'^\s*"[^"]*"', prev_line):
                        break
                
                if not in_array_context:
                    fixed_lines.append('    # ' + line + '  # ORPHANED ARRAY ELEMENT - commented out')
                    fixes += 1
                else:
                    fixed_lines.append(line)
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_orphaned_control_structures(self, content: str) -> Tuple[str, int]:
        """Fix orphaned if/for/while statements outside function bodies"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        current_function_indent = None
        in_function = False
        
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            line_indent = len(line) - len(line.lstrip()) if line.strip() else 0
            
            # Track function context
            if re.match(r'^\s*func\s+', line):
                current_function_indent = line_indent
                in_function = True
                fixed_lines.append(line)
            elif stripped == "" or stripped.startswith('#'):
                fixed_lines.append(line)
            elif re.match(r'^\s*class\s+', line):
                in_function = False
                current_function_indent = None
                fixed_lines.append(line)
            # Check for orphaned control structures
            elif re.match(r'^\s*(if\s+|for\s+|while\s+)', line):
                if current_function_indent is None or line_indent <= current_function_indent:
                    # This is orphaned - move to previous function or comment out
                    fixed_lines.append('    # ' + line + '  # ORPHANED CONTROL STRUCTURE - commented out')
                    
                    # Also handle the next line if it's an orphaned pass/indent
                    if i + 1 < len(lines) and lines[i + 1].strip() in ['pass', '']:
                        i += 1
                        if lines[i].strip():
                            fixed_lines.append('    # ' + lines[i] + '  # ORPHANED - commented out')
                    
                    fixes += 1
                else:
                    fixed_lines.append(line)
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_orphaned_assignments(self, content: str) -> Tuple[str, int]:
        """Fix orphaned variable assignments outside function context"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        current_function_indent = None
        last_function_line = None
        
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            line_indent = len(line) - len(line.lstrip()) if line.strip() else 0
            
            # Track function context
            if re.match(r'^\s*func\s+', line):
                current_function_indent = line_indent
                last_function_line = len(fixed_lines)
                fixed_lines.append(line)
            elif stripped == "" or stripped.startswith('#'):
                fixed_lines.append(line)
            elif re.match(r'^\s*class\s+', line):
                current_function_indent = None
                fixed_lines.append(line)
            # Check for orphaned assignments (like _component = null)
            elif (re.match(r'^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*=', line) and 
                  not line.strip().startswith('var ') and
                  (current_function_indent is None or line_indent <= current_function_indent)):
                
                if last_function_line is not None:
                    # Try to move this assignment into the last function
                    proper_indent = ' ' * (current_function_indent + 4) if current_function_indent is not None else '    '
                    assignment_line = proper_indent + stripped
                    
                    # Insert after the last function definition
                    insert_pos = last_function_line + 1
                    # Skip any existing content to find good insertion point
                    while (insert_pos < len(fixed_lines) and 
                           (fixed_lines[insert_pos].strip() == '' or 
                            fixed_lines[insert_pos].strip().startswith('#'))):
                        insert_pos += 1
                    
                    fixed_lines.insert(insert_pos, assignment_line)
                    fixes += 1
                else:
                    # No function to move to, comment it out
                    fixed_lines.append('    # ' + line + '  # ORPHANED ASSIGNMENT - commented out')
                    fixes += 1
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_incomplete_structures(self, content: str) -> Tuple[str, int]:
        """Fix incomplete function definitions and class structures"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Handle incomplete function signatures
            if re.match(r'^\s*func\s+\w+.*->\s*$', line) or line.strip().endswith('->'):
                # Incomplete return type, add void
                line = line.rstrip() + ' void:'
                fixes += 1
            
            # Handle functions missing colons
            elif re.match(r'^\s*func\s+\w+.*\)\s*$', line) and not line.strip().endswith(':'):
                line = line.rstrip() + ':'
                fixes += 1
            
            fixed_lines.append(line)
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_expected_end_of_file_errors(self, content: str) -> Tuple[str, int]:
        """Fix 'Expected end of file' errors by cleaning up file endings"""
        fixes = 0
        
        # Remove trailing content that might cause end-of-file issues
        lines = content.split('\n')
        
        # Find the last meaningful line
        last_meaningful = len(lines) - 1
        while last_meaningful >= 0:
            line = lines[last_meaningful].strip()
            if line and not line.startswith('#'):
                break
            last_meaningful -= 1
        
        if last_meaningful < len(lines) - 1:
            # Remove extra trailing lines
            lines = lines[:last_meaningful + 1]
            fixes += 1
        
        # Ensure file ends with a single newline
        content = '\n'.join(lines)
        if not content.endswith('\n'):
            content += '\n'
            fixes += 1
        
        return content, fixes
    
    def apply_advanced_fixes(self, file_path: str) -> int:
        """Apply advanced fixes to a single file"""
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
            
            # Apply advanced fixes in order
            content, fixes = self.fix_orphaned_dictionary_entries(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Orphaned dictionary fixes: {fixes}")
            
            content, fixes = self.fix_orphaned_control_structures(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Orphaned control structure fixes: {fixes}")
            
            content, fixes = self.fix_orphaned_assignments(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Orphaned assignment fixes: {fixes}")
            
            content, fixes = self.fix_incomplete_structures(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Incomplete structure fixes: {fixes}")
            
            content, fixes = self.fix_expected_end_of_file_errors(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - End-of-file fixes: {fixes}")
            
            # Write the fixed content
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"  ✓ Applied {total_fixes} advanced fixes to {file_path}")
            else:
                print(f"  - No advanced fixes needed for {file_path}")
            
            return total_fixes
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            return 0
    
    def run(self):
        """Run the advanced linter fixes"""
        print("=" * 60)
        print("Advanced UI Test Linter Fixes - Phase 2")
        print("=" * 60)
        
        total_fixes = 0
        processed_files = 0
        
        for file_path in TARGET_FILES:
            fixes = self.apply_advanced_fixes(file_path)
            total_fixes += fixes
            if fixes > 0:
                processed_files += 1
        
        print("\n" + "=" * 60)
        print("ADVANCED FIXES SUMMARY")
        print("=" * 60)
        print(f"Files processed: {processed_files}")
        print(f"Total advanced fixes applied: {total_fixes}")
        print(f"Backup directory: {self.backup_dir}")
        print("=" * 60)
        
        return total_fixes > 0

if __name__ == "__main__":
    fixer = AdvancedUITestFixer()
    success = fixer.run()
    
    if success:
        print("\n✅ Advanced UI test linter fixes completed successfully!")
        print("Please review the changes and test the files.")
    else:
        print("\n❌ No advanced fixes were applied or errors occurred.") 