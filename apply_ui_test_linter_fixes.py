#!/usr/bin/env python3
"""
UI Test Linter Fixes - Comprehensive Script
Fixes linter errors in UI test files for Five Parsecs Campaign Manager
"""

import os
import re
import shutil
from datetime import datetime
from typing import List, Tuple, Dict

# Target files to fix
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

class UITestLinterFixer:
    def __init__(self):
        self.fixes_applied = 0
        self.files_processed = 0
        self.backup_dir = f"backups/ui_test_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
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
    
    def fix_tab_indentation(self, content: str) -> Tuple[str, int]:
        """Convert tabs to spaces (4 spaces per tab)"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            if '\t' in line:
                # Convert tabs to 4 spaces, but preserve relative indentation
                new_line = line.expandtabs(4)
                if new_line != line:
                    fixes += 1
                fixed_lines.append(new_line)
            else:
                fixed_lines.append(line)
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_missing_indented_blocks(self, content: str) -> Tuple[str, int]:
        """Fix missing indented blocks after control structures"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Check for control structures that need indented blocks
            if (re.match(r'^(\s*)(if\s+.*:|for\s+.*:|while\s+.*:|func\s+.*->.*:|class\s+.*:|elif\s+.*:|else\s*:)$', line.strip() + ':') or
                line.strip().endswith(':') and any(keyword in line for keyword in ['if ', 'for ', 'while ', 'func ', 'class ', 'elif ', 'else'])):
                
                fixed_lines.append(line)
                
                # Check if next line is properly indented
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    current_indent = len(line) - len(line.lstrip())
                    
                    if next_line.strip() == "":
                        # Skip empty lines
                        i += 1
                        while i + 1 < len(lines) and lines[i + 1].strip() == "":
                            fixed_lines.append(lines[i + 1])
                            i += 1
                        
                        if i + 1 < len(lines):
                            next_line = lines[i + 1]
                        else:
                            # End of file, add pass
                            fixed_lines.append(' ' * (current_indent + 4) + 'pass')
                            fixes += 1
                            i += 1
                            continue
                    
                    next_indent = len(next_line) - len(next_line.lstrip()) if next_line.strip() else 0
                    
                    if next_line.strip() and next_indent <= current_indent:
                        # Next line is not properly indented, add pass
                        fixed_lines.append(' ' * (current_indent + 4) + 'pass')
                        fixes += 1
                else:
                    # End of file, add pass
                    current_indent = len(line) - len(line.lstrip())
                    fixed_lines.append(' ' * (current_indent + 4) + 'pass')
                    fixes += 1
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_orphaned_statements(self, content: str) -> Tuple[str, int]:
        """Fix orphaned statements outside functions"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        current_function = None
        in_class = False
        
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            
            # Track if we're in a class
            if re.match(r'^\s*class\s+\w+', line):
                in_class = True
                fixed_lines.append(line)
            elif re.match(r'^\s*func\s+\w+', line):
                current_function = line
                fixed_lines.append(line)
            elif stripped == "" or stripped.startswith('#'):
                fixed_lines.append(line)
            elif (stripped.startswith('_') and '=' in stripped and 
                  current_function is None and in_class and
                  not stripped.startswith('var ') and
                  not re.match(r'^\s*(if|for|while|func|class|elif|else)', line)):
                # This is an orphaned assignment, move to previous function
                if fixed_lines and 'func ' in fixed_lines[-2:]:
                    # Find the last function and add proper indentation
                    for j in range(len(fixed_lines) - 1, -1, -1):
                        if 'func ' in fixed_lines[j]:
                            indent = len(fixed_lines[j]) - len(fixed_lines[j].lstrip()) + 4
                            fixed_lines.append(' ' * indent + stripped)
                            fixes += 1
                            break
                    else:
                        fixed_lines.append(line)
                else:
                    fixed_lines.append(line)
            elif (re.match(r'^\s*(if|for|while)\s+', line) and 
                  current_function is None and in_class):
                # Orphaned control structure, skip or comment out
                fixed_lines.append('# ' + line + '  # ORPHANED - moved to comment')
                fixes += 1
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_dictionary_syntax(self, content: str) -> Tuple[str, int]:
        """Fix dictionary and array syntax errors"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Fix dictionary syntax - lines that start with a quoted key
            if (re.match(r'^\s*"[^"]*":\s*', line) and 
                not re.match(r'^\s*{\s*"', line) and
                not line.strip().endswith(',')):
                # This looks like a dictionary entry outside a dictionary
                # Skip it or comment it out
                fixed_lines.append('# ' + line + '  # ORPHANED DICT ENTRY')
                fixes += 1
            # Fix array continuation lines
            elif (re.match(r'^\s*"[^"]*"[,]?\s*$', line) and
                  i > 0 and not lines[i-1].strip().endswith('[')):
                # Orphaned array element
                fixed_lines.append('# ' + line + '  # ORPHANED ARRAY ELEMENT')
                fixes += 1
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_incomplete_functions(self, content: str) -> Tuple[str, int]:
        """Add pass statements to incomplete functions"""
        fixes = 0
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Check for function definitions
            if re.match(r'^\s*func\s+\w+.*->\s*\w*:?\s*$', line) or re.match(r'^\s*func\s+\w+\([^)]*\)\s*:\s*$', line):
                fixed_lines.append(line)
                
                # Look ahead to see if function has a body
                j = i + 1
                has_body = False
                func_indent = len(line) - len(line.lstrip())
                
                while j < len(lines):
                    next_line = lines[j]
                    if next_line.strip() == "":
                        j += 1
                        continue
                    
                    next_indent = len(next_line) - len(next_line.lstrip())
                    
                    if next_indent > func_indent:
                        has_body = True
                        break
                    elif next_indent <= func_indent and next_line.strip():
                        # Next item at same or lower level
                        break
                    
                    j += 1
                
                if not has_body:
                    fixed_lines.append(' ' * (func_indent + 4) + 'pass')
                    fixes += 1
            else:
                fixed_lines.append(line)
            
            i += 1
        
        return '\n'.join(fixed_lines), fixes
    
    def fix_inheritance_issues(self, content: str) -> Tuple[str, int]:
        """Fix class inheritance issues"""
        fixes = 0
        
        # Fix GdUnitGameTest inheritance issue
        if 'extends GdUnitGameTest' in content and 'Could not resolve super class inheritance' in str(content):
            content = content.replace('extends GdUnitGameTest', 'extends GdUnitTestSuite')
            fixes += 1
        
        return content, fixes
    
    def apply_comprehensive_fixes(self, file_path: str) -> int:
        """Apply all fixes to a single file"""
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
            
            # Apply fixes in order
            content, fixes = self.fix_tab_indentation(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Tab indentation fixes: {fixes}")
            
            content, fixes = self.fix_inheritance_issues(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Inheritance fixes: {fixes}")
            
            content, fixes = self.fix_missing_indented_blocks(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Missing indented block fixes: {fixes}")
            
            content, fixes = self.fix_incomplete_functions(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Incomplete function fixes: {fixes}")
            
            content, fixes = self.fix_dictionary_syntax(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Dictionary syntax fixes: {fixes}")
            
            content, fixes = self.fix_orphaned_statements(content)
            total_fixes += fixes
            if fixes > 0:
                print(f"  - Orphaned statement fixes: {fixes}")
            
            # Write the fixed content
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"  ✓ Applied {total_fixes} fixes to {file_path}")
            else:
                print(f"  - No fixes needed for {file_path}")
            
            return total_fixes
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            return 0
    
    def run(self):
        """Run the comprehensive linter fixes"""
        print("=" * 60)
        print("UI Test Linter Fixes - Comprehensive Script")
        print("=" * 60)
        
        total_fixes = 0
        processed_files = 0
        
        for file_path in TARGET_FILES:
            fixes = self.apply_comprehensive_fixes(file_path)
            total_fixes += fixes
            if fixes > 0:
                processed_files += 1
        
        print("\n" + "=" * 60)
        print("COMPREHENSIVE FIXES SUMMARY")
        print("=" * 60)
        print(f"Files processed: {processed_files}")
        print(f"Total fixes applied: {total_fixes}")
        print(f"Backup directory: {self.backup_dir}")
        print("=" * 60)
        
        return total_fixes > 0

if __name__ == "__main__":
    fixer = UITestLinterFixer()
    success = fixer.run()
    
    if success:
        print("\n✅ UI test linter fixes completed successfully!")
        print("Please review the changes and test the files.")
    else:
        print("\n❌ No fixes were applied or errors occurred.") 