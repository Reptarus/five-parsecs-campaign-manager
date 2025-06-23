#!/usr/bin/env python3
"""
Complex Indentation Issues Fixer for Five Parsecs Campaign Manager
Handles more sophisticated indentation problems that require context analysis.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

class ComplexIndentationFixer:
    def __init__(self):
        self.backup_dir = Path("backups") / f"complex_indentation_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.fixes_applied = {}
        self.total_fixes = 0
        
    def create_backup(self, file_path):
        """Create backup of original file"""
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = self.backup_dir / file_path.name
        shutil.copy2(file_path, backup_path)
        
    def fix_complex_indentation(self, file_path):
        """Fix complex indentation issues in a single file"""
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
        in_function = False
        class_indent_level = 0
        
        while i < len(lines):
            line = lines[i]
            original_line = line
            
            # Track class and function context
            if re.match(r'^class\s+\w+', line.strip()):
                in_class = True
                class_indent_level = len(line) - len(line.lstrip())
                
            elif re.match(r'^\s*func\s+\w+', line.strip()):
                in_function = True
                
            # Fix orphaned statements that should be inside classes/functions
            if line.strip() and not line.strip().startswith('#'):
                
                # Fix orphaned variable assignments in class body
                if re.match(r'^\s*\w+\s*=', line.strip()) and in_class:
                    current_indent = len(line) - len(line.lstrip())
                    expected_indent = class_indent_level + 4
                    if current_indent != expected_indent:
                        line = ' ' * expected_indent + line.strip() + '\n'
                        fixes_count += 1
                
                # Fix orphaned enum values
                if re.match(r'^\s*[A-Z_]+\s*=\s*\d+', line.strip()) and in_class:
                    current_indent = len(line) - len(line.lstrip())
                    expected_indent = class_indent_level + 4
                    if current_indent != expected_indent:
                        line = ' ' * expected_indent + line.strip() + '\n'
                        fixes_count += 1
                
                # Fix lines that should be at module level (not indented)
                if re.match(r'^\s+(extends|class_name|@tool)', line.strip()):
                    line = line.strip() + '\n'
                    fixes_count += 1
                
                # Fix dictionary elements that are orphaned
                if re.match(r'^\s*"[^"]*":\s*[^,\}]*,?\s*$', line.strip()):
                    # This looks like a dictionary element - check context
                    if i > 0:
                        prev_line = new_lines[-1] if new_lines else ""
                        if ('{' in prev_line or 
                            re.match(r'^\s*"[^"]*":\s*[^,\}]*,?\s*$', prev_line.strip())):
                            # Should be indented relative to the opening brace
                            current_indent = len(line) - len(line.lstrip())
                            if current_indent == 0:
                                line = '    ' + line.strip() + '\n'
                                fixes_count += 1
                
                # Fix function calls that are orphaned
                if re.match(r'^\s*\w+\([^)]*\)', line.strip()) and not line.strip().startswith('func'):
                    # Check if this should be indented
                    if i > 0:
                        prev_line = new_lines[-1] if new_lines else ""
                        if (prev_line.strip().endswith(':') or
                            re.match(r'^\s*(if|for|while|else)', prev_line.strip())):
                            current_indent = len(line) - len(line.lstrip())
                            expected_indent = len(prev_line) - len(prev_line.lstrip()) + 4
                            if current_indent != expected_indent:
                                line = ' ' * expected_indent + line.strip() + '\n'
                                fixes_count += 1
                
                # Fix signal declarations that are orphaned
                if re.match(r'^\s*signal\s+\w+', line.strip()) and in_class:
                    current_indent = len(line) - len(line.lstrip())
                    expected_indent = class_indent_level + 4
                    if current_indent != expected_indent:
                        line = ' ' * expected_indent + line.strip() + '\n'
                        fixes_count += 1
                
                # Fix "var" declarations that are orphaned
                if re.match(r'^\s*var\s+\w+', line.strip()) and in_class:
                    current_indent = len(line) - len(line.lstrip())
                    expected_indent = class_indent_level + 4
                    if current_indent != expected_indent:
                        line = ' ' * expected_indent + line.strip() + '\n'
                        fixes_count += 1
                
                # Fix const declarations that are orphaned
                if re.match(r'^\s*const\s+\w+', line.strip()) and in_class:
                    current_indent = len(line) - len(line.lstrip())
                    expected_indent = class_indent_level + 4
                    if current_indent != expected_indent:
                        line = ' ' * expected_indent + line.strip() + '\n'
                        fixes_count += 1
            
            # Fix specific problematic patterns
            
            # Remove standalone curly braces that don't belong
            if line.strip() in ['{', '}'] and not (i > 0 and new_lines[-1].strip().endswith('{')):
                fixes_count += 1
                i += 1
                continue
            
            # Fix unexpected Dedent/Indent errors
            if 'Dedent' in line or 'Indent' in line and line.strip().startswith('Err'):
                # This is probably a stray error message
                fixes_count += 1
                i += 1
                continue
            
            # Fix lines that are just standalone operators or keywords
            if line.strip() in ['_:', 'Err', 'else:', 'pass']:
                if line.strip() == 'pass':
                    # Keep pass but check indentation
                    if i > 0:
                        prev_line = new_lines[-1] if new_lines else ""
                        if prev_line.strip().endswith(':'):
                            expected_indent = len(prev_line) - len(prev_line.lstrip()) + 4
                            line = ' ' * expected_indent + 'pass\n'
                            fixes_count += 1
                else:
                    # Remove the problematic line
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
            print(f"✅ Fixed {fixes_count} complex indentation issues in {file_path.name}")
        
        return True
    
    def fix_all_files(self):
        """Fix complex indentation errors in all test files"""
        
        # Get all .gd files in the tests directory
        test_files = []
        test_dir = Path("tests")
        
        if test_dir.exists():
            for gd_file in test_dir.rglob("*.gd"):
                test_files.append(str(gd_file))
        
        print(f"🔧 Starting complex indentation fixes for {len(test_files)} test files...")
        
        files_processed = 0
        files_fixed = 0
        
        for file_path_str in test_files:
            file_path = Path(file_path_str)
            
            if file_path.exists():
                if self.fix_complex_indentation(file_path):
                    files_processed += 1
                    if str(file_path) in self.fixes_applied:
                        files_fixed += 1
                else:
                    print(f"❌ Failed to process {file_path}")
            else:
                print(f"⚠️  File not found: {file_path}")
        
        print(f"\n🎯 **COMPLEX INDENTATION FIX SUMMARY**")
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
    fixer = ComplexIndentationFixer()
    fixer.fix_all_files() 