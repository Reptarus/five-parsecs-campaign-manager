#!/usr/bin/env python3
"""
TARGETED FIX FOR REMAINING TEST SUITE CORRUPTION
===============================================
Fixes specific remaining corruption patterns that the first script missed.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path
import argparse

class RemainingCorruptionFixer:
    def __init__(self, dry_run=False, backup=True):
        self.dry_run = dry_run
        self.backup = backup
        self.stats = {
            'files_processed': 0,
            'files_fixed': 0,
            'total_fixes': 0,
            'patterns_fixed': {},
            'errors': []
        }
        
        # Targeted patterns for remaining corruption
        self.remaining_patterns = [
            # Missing return statements in functions
            (r'if result is (\w+):\s*$', r'if result is \1:\n\t\treturn result'),
            
            # Fix broken parameter references  
            (r'(\w+):\s*(\w+)\s*=\s*_value', r'\1: \2 = test_value'),
            (r'typeof\(_value\)', r'typeof(test_value)'),
            
            # Fix broken string interpolation
            (r'% s', r'%s'),
            (r'% d', r'%d'),
            (r'shouldbe', r'should be'),
            (r'inphase', r'in phase'),
            
            # Fix incomplete function calls  
            (r'push_error\("([^"]+)"\s*$', r'push_error("\1")'),
            
            # Fix broken await statements
            (r'^(\s*)await get_tree\(\)\.process_frame\s*$', r'\1await get_tree().process_frame'),
            
            # Fix incomplete if statements
            (r'if (\w+):\s*$\s*$', r'if \1:\n\t\treturn \1'),
            
            # Fix orphaned assert_that calls
            (r'assert_that\(([^)]+)\)\.override_failure_message\(\s*@warning_ignore\([^)]+\)\s*([^)]+)\)\.is_true\(\)', 
             r'assert_that(\1).override_failure_message(\2).is_true()'),
            
            # Fix broken dictionary access
            (r'get_\s*%\s*s', r'get_%s'),
            
            # Fix method calls broken by spaces
            (r'(\w+)\.call\("([^"]+)",\s*([^)]+)\)\s*$', r'\1.call("\2", \3)'),
            
            # Fix missing function body content
            (r'func\s+(\w+)\([^)]*\)\s*->\s*(\w+):\s*$\s*var\s+(\w+):\s*(\w+)\s*=\s*typeof\(test_value\)\s*$\s*$', 
             r'func \1() -> \2:\n\tvar \3: \4 = typeof(test_value)\n\treturn \3 == TYPE_\2'),
        ]
    
    def create_backup(self, file_path):
        """Create backup of file with timestamp"""
        if not self.backup:
            return
            
        backup_dir = Path("backups/remaining_corruption_fix")
        backup_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"{Path(file_path).name}_{timestamp}.backup"
        backup_path = backup_dir / backup_name
        
        shutil.copy2(file_path, backup_path)
        print(f"  📋 Backup created: {backup_path}")

    def fix_file_content(self, content, file_path):
        """Apply targeted fixes to file content"""
        original_content = content
        fixes_applied = 0
        
        # Apply targeted patterns
        for pattern, replacement in self.remaining_patterns:
            old_content = content
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if content != old_content:
                pattern_name = f"remaining_pattern_{len([p for p in self.remaining_patterns if (p[0], p[1]) == (pattern, replacement)]) + 1}"
                self.stats['patterns_fixed'][pattern_name] = self.stats['patterns_fixed'].get(pattern_name, 0) + 1
                fixes_applied += 1
        
        # Line-by-line fixes for complex issues
        lines = content.split('\n')
        fixed_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            original_line = line
            
            # Fix incomplete function bodies
            if re.match(r'^\s*if result is \w+:\s*$', line):
                # Check if next line is empty or doesn't have return
                if i + 1 < len(lines) and (lines[i + 1].strip() == '' or not 'return' in lines[i + 1]):
                    # Extract the type from the if statement
                    match = re.match(r'^\s*if result is (\w+):\s*$', line)
                    if match:
                        type_name = match.group(1)
                        indent = line[:len(line) - len(line.lstrip())]
                        fixed_lines.append(line)
                        fixed_lines.append(f"{indent}\treturn result")
                        fixes_applied += 1
                        i += 1
                        continue
            
            # Fix await statements that got corrupted
            if 'await get_tree().process_frame' in line and line.strip().endswith('await get_tree().process_frame'):
                line = line.rstrip()
                fixes_applied += 1
            
            # Fix broken string formatting in constants
            if 'const ERROR_' in line and ('% s' in line or '% d' in line):
                line = line.replace('% s', '%s').replace('% d', '%d')
                line = line.replace('shouldbe', 'should be').replace('inphase', 'in phase')
                fixes_applied += 1
            
            # Fix parameter name issues
            if '_value' in line and 'test_value' not in line:
                line = line.replace('_value', 'test_value')
                fixes_applied += 1
            
            if line != original_line:
                fixes_applied += 1
                
            fixed_lines.append(line)
            i += 1
        
        content = '\n'.join(fixed_lines)
        
        return content, fixes_applied

    def process_file(self, file_path):
        """Process a single test file"""
        try:
            print(f"🔧 Processing: {file_path}")
            
            # Read file content
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Apply fixes
            fixed_content, fixes_applied = self.fix_file_content(content, file_path)
            
            # Check if changes were made
            if fixed_content != content:
                self.stats['files_fixed'] += 1
                self.stats['total_fixes'] += fixes_applied
                
                if not self.dry_run:
                    # Create backup
                    self.create_backup(file_path)
                    
                    # Write fixed content
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(fixed_content)
                    print(f"  ✅ Fixed {fixes_applied} remaining corruption patterns")
                else:
                    print(f"  🔍 Would fix {fixes_applied} remaining corruption patterns")
            else:
                print(f"  ✨ No remaining corruption found")
                
            self.stats['files_processed'] += 1
            
        except Exception as e:
            error_msg = f"Error processing {file_path}: {str(e)}"
            self.stats['errors'].append(error_msg)
            print(f"  ❌ {error_msg}")

    def find_test_files_with_issues(self):
        """Find test files that likely still have corruption"""
        test_files = []
        
        # Look for files with known problematic patterns
        for path in Path('.').glob('tests/**/*.gd'):
            if path.is_file():
                try:
                    with open(path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                    # Check for remaining corruption patterns
                    if any(pattern in content for pattern in [
                        '% s', '% d', '_value', 'shouldbe', 'inphase',
                        'if result is', 'await get_tree().process_frame\n\t\t',
                        'typeof(_value)'
                    ]):
                        test_files.append(str(path))
                except:
                    pass
        
        return sorted(test_files)

    def run(self, specific_files=None):
        """Run the remaining corruption fix process"""
        print("🔧 TARGETED FIX FOR REMAINING TEST SUITE CORRUPTION")
        print("=" * 55)
        
        if self.dry_run:
            print("🔍 DRY RUN MODE - No files will be modified")
        
        # Get files to process
        if specific_files:
            files_to_process = specific_files
        else:
            files_to_process = self.find_test_files_with_issues()
        
        print(f"📁 Found {len(files_to_process)} test files with remaining issues")
        
        # Process each file
        for file_path in files_to_process:
            if Path(file_path).exists():
                self.process_file(file_path)
        
        # Print summary
        self.print_summary()

    def print_summary(self):
        """Print execution summary"""
        print("\n" + "=" * 55)
        print("📊 REMAINING CORRUPTION FIX SUMMARY")
        print("=" * 55)
        print(f"📁 Files processed: {self.stats['files_processed']}")
        print(f"✅ Files fixed: {self.stats['files_fixed']}")
        print(f"🔧 Total fixes applied: {self.stats['total_fixes']}")
        
        if self.stats['patterns_fixed']:
            print("\n📋 Patterns fixed:")
            for pattern, count in sorted(self.stats['patterns_fixed'].items()):
                print(f"  • {pattern}: {count} fixes")
        
        if self.stats['errors']:
            print(f"\n❌ Errors encountered: {len(self.stats['errors'])}")
            for error in self.stats['errors']:
                print(f"  • {error}")
        
        success_rate = (self.stats['files_fixed'] / max(1, self.stats['files_processed'])) * 100
        print(f"\n🎯 Success rate: {success_rate:.1f}%")

def main():
    parser = argparse.ArgumentParser(description='Fix remaining Five Parsecs test suite corruption')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without applying them')
    parser.add_argument('--no-backup', action='store_true', help='Skip creating backups')
    parser.add_argument('files', nargs='*', help='Specific files to process')
    
    args = parser.parse_args()
    
    fixer = RemainingCorruptionFixer(
        dry_run=args.dry_run,
        backup=not args.no_backup
    )
    
    fixer.run(args.files if args.files else None)

if __name__ == '__main__':
    main() 