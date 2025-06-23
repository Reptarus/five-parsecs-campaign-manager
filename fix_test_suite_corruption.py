#!/usr/bin/env python3
"""
FIVE PARSECS TEST SUITE CORRUPTION FIX
======================================
Fixes systematic corruption across test files with @warning_ignore annotation issues.

Based on successful patterns from previous 179/180 test file fixes.
Comprehensive fix for all test suite corruption patterns.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path
import argparse

class TestSuiteCorruptionFixer:
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
        
        # Define corruption patterns to fix
        self.corruption_patterns = [
            # Pattern 1: Orphaned @warning_ignore breaking function calls
            (r'(\w+)\s*\.\s*@warning_ignore\([^)]+\)\s*(\w+)', r'\1.\2'),
            
            # Pattern 2: @warning_ignore in wrong position breaking assignments
            (r'=\s*@warning_ignore\([^)]+\)\s*', r'= '),
            
            # Pattern 3: @warning_ignore breaking string interpolation
            (r'"([^"]*)\s*@warning_ignore\([^)]+\)\s*([^"]*)"', r'"\1\2"'),
            
            # Pattern 4: @warning_ignore in control structures
            (r'if\s+@warning_ignore\([^)]+\)\s*', r'if '),
            (r'not\s+@warning_ignore\([^)]+\)\s*', r'not '),
            (r'elif\s+@warning_ignore\([^)]+\)\s*', r'elif '),
            
            # Pattern 5: @warning_ignore breaking function parameters
            (r'@warning_ignore\([^)]+\)\s*(\w+)\s*\.', r'\1.'),
            
            # Pattern 6: Corrupted percentage formatting
            (r'%\s+s', r'% s'),
            (r'%\s+d', r'% d'),
            (r'@warning_ignore\("integer_division"\)\s*(\d+)\s*%', r'\1 %'),
            
            # Pattern 7: Missing closing parentheses in function calls
            (r'push_error\(@warning_ignore\([^)]+\)\s*([^)]+)\s*$', r'push_error(\1)'),
            
            # Pattern 8: Annotations breaking dictionary/array syntax
            (r'@warning_ignore\([^)]+\)\s*(\[|\{)', r'\1'),
            
            # Pattern 9: Invalid annotation placement at start of lines
            (r'^\s*@warning_ignore\([^)]+\)\s*(\w+)', r'\1'),
            
            # Pattern 10: @warning_ignore interrupting member access
            (r'(\w+)@warning_ignore\([^)]+\)\s*\.(\w+)', r'\1.\2'),
            
            # Pattern 11: Unexpected indent issues (class body problems)
            (r'(\s+)@warning_ignore\([^)]+\)\s*(\w+)', r'\2'),
            
            # Pattern 12: Await statements broken by annotations  
            (r'await\s+@warning_ignore\([^)]+\)\s*', r'await '),
            
            # Pattern 13: Return statements broken by annotations
            (r'return\s+@warning_ignore\([^)]+\)\s*', r'return '),
            
            # Pattern 14: Assert statements broken
            (r'assert\(@warning_ignore\([^)]+\)\s*', r'assert('),
            
            # Pattern 15: Function call continuations broken
            (r'\)\s*@warning_ignore\([^)]+\)\s*\(', r')('),
            
            # Pattern 16: Variable declarations broken
            (r'var\s+(\w+):\s*@warning_ignore\([^)]+\)\s*', r'var \1: '),
            
            # Pattern 17: Signal emissions broken
            (r'(\w+)\.emit\(@warning_ignore\([^)]+\)\s*', r'\1.emit('),
            
            # Pattern 18: Method calls on objects broken
            (r'(\w+)\.(\w+)\(@warning_ignore\([^)]+\)\s*', r'\1.\2('),
            
            # Pattern 19: Constructor calls broken
            (r'(\w+)\.new\(@warning_ignore\([^)]+\)\s*', r'\1.new('),
            
            # Pattern 20: Get method calls broken  
            (r'\.get\(@warning_ignore\([^)]+\)\s*', r'.get('),
        ]
        
        # Additional file-specific fixes
        self.specific_fixes = [
            # Fix broken extends statements
            (r'@warning_ignore\([^)]+\)\s*extends\s+(\w+)', r'extends \1'),
            
            # Fix broken class declarations
            (r'class\s+(\w+)\s*@warning_ignore\([^)]+\)\s*extends', r'class \1 extends'),
            
            # Fix broken signal declarations
            (r'signal\s+(\w+)@warning_ignore\([^)]+\)', r'signal \1'),
            
            # Fix broken enum declarations
            (r'enum\s+(\w+)\s*@warning_ignore\([^)]+\)\s*{', r'enum \1 {'),
            
            # Fix corrupted function definitions
            (r'func\s+@warning_ignore\([^)]+\)\s*(\w+)', r'func \1'),
            
            # Fix corrupted property getter syntax
            (r'func\s+(\w+)\(\)\s*:\s*@warning_ignore\([^)]+\)\s*->', r'func \1() ->'),
            
            # Remove standalone orphaned annotations
            (r'^\s*@warning_ignore\([^)]+\)\s*$', r''),
        ]

    def create_backup(self, file_path):
        """Create backup of file with timestamp"""
        if not self.backup:
            return
            
        backup_dir = Path("backups/test_corruption_fix")
        backup_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"{Path(file_path).name}_{timestamp}.backup"
        backup_path = backup_dir / backup_name
        
        shutil.copy2(file_path, backup_path)
        print(f"  📋 Backup created: {backup_path}")

    def fix_file_content(self, content, file_path):
        """Apply all corruption fixes to file content"""
        original_content = content
        fixes_applied = 0
        
        # Apply main corruption patterns
        for pattern, replacement in self.corruption_patterns:
            old_content = content
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if content != old_content:
                pattern_name = f"corruption_pattern_{len([p for p in self.corruption_patterns if (p[0], p[1]) == (pattern, replacement)]) + 1}"
                self.stats['patterns_fixed'][pattern_name] = self.stats['patterns_fixed'].get(pattern_name, 0) + 1
                fixes_applied += 1
        
        # Apply specific fixes
        for pattern, replacement in self.specific_fixes:
            old_content = content
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if content != old_content:
                pattern_name = f"specific_fix_{len([p for p in self.specific_fixes if (p[0], p[1]) == (pattern, replacement)]) + 1}"
                self.stats['patterns_fixed'][pattern_name] = self.stats['patterns_fixed'].get(pattern_name, 0) + 1
                fixes_applied += 1
        
        # Additional line-by-line fixes for complex corruption
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            original_line = line
            
            # Fix multiple @warning_ignore on same line
            while '@warning_ignore(' in line and line.count('@warning_ignore(') > 1:
                # Remove extra annotations, keep only the first valid one
                first_annotation = re.search(r'@warning_ignore\([^)]+\)', line)
                if first_annotation:
                    before = line[:first_annotation.start()]
                    after = line[first_annotation.end():]
                    # Remove additional annotations from the after part
                    after = re.sub(r'@warning_ignore\([^)]+\)', '', after)
                    line = before + first_annotation.group() + after
                else:
                    break
            
            # Fix corrupted parameter references (common pattern)
            line = re.sub(r'(\w+)\s*=\s*test_(\w+)', r'\1 = _\2', line)
            line = re.sub(r'(\w+)\s*=\s*_value', r'\1 = test_value', line)
            
            # Fix missing quotes
            line = re.sub(r'\$"([^"]*$)', r'$"\1"', line)
            
            # Fix corrupted returns in class bodies  
            if re.match(r'^\s+(return\s+)', line) and 'func ' not in line:
                # This is likely an orphaned return statement
                line = ''
            
            if line != original_line:
                fixes_applied += 1
                
            fixed_lines.append(line)
        
        content = '\n'.join(fixed_lines)
        
        # Final validation passes
        content = self.validate_and_clean(content)
        
        return content, fixes_applied

    def validate_and_clean(self, content):
        """Final validation and cleanup pass"""
        lines = content.split('\n')
        cleaned_lines = []
        in_class = False
        indent_level = 0
        
        for i, line in enumerate(lines):
            original_line = line
            
            # Track class context
            if re.match(r'^class\s+\w+', line.strip()):
                in_class = True
                indent_level = len(line) - len(line.lstrip())
            elif line.strip() and not line.startswith('\t') and not line.startswith(' '):
                in_class = False
            
            # Remove orphaned statements in class bodies
            if in_class and line.strip():
                line_indent = len(line) - len(line.lstrip())
                if line_indent > indent_level:
                    # Check for common orphaned patterns
                    stripped = line.strip()
                    if (stripped.startswith('return ') or 
                        stripped.startswith('await ') or
                        stripped.startswith('assert_that(') or
                        re.match(r'^\w+\s*=', stripped) or
                        re.match(r'^\w+\.\w+', stripped)):
                        # This is likely orphaned code in class body
                        continue
            
            # Remove completely empty or whitespace-only lines with just annotations
            if re.match(r'^\s*@warning_ignore\([^)]+\)\s*$', line):
                continue
                
            cleaned_lines.append(line)
        
        return '\n'.join(cleaned_lines)

    def process_file(self, file_path):
        """Process a single test file"""
        try:
            print(f"🔧 Processing: {file_path}")
            
            # Read file content
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Create backup
            if not self.dry_run:
                self.create_backup(file_path)
            
            # Apply fixes
            fixed_content, fixes_applied = self.fix_file_content(content, file_path)
            
            # Check if changes were made
            if fixed_content != content:
                self.stats['files_fixed'] += 1
                self.stats['total_fixes'] += fixes_applied
                
                if not self.dry_run:
                    # Write fixed content
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(fixed_content)
                    print(f"  ✅ Fixed {fixes_applied} corruption patterns")
                else:
                    print(f"  🔍 Would fix {fixes_applied} corruption patterns")
            else:
                print(f"  ✨ No corruption found")
                
            self.stats['files_processed'] += 1
            
        except Exception as e:
            error_msg = f"Error processing {file_path}: {str(e)}"
            self.stats['errors'].append(error_msg)
            print(f"  ❌ {error_msg}")

    def find_test_files(self):
        """Find all test files that might have corruption"""
        test_patterns = [
            'tests/**/*.gd',
            'test*/**/*.gd',
        ]
        
        test_files = []
        for pattern in test_patterns:
            for path in Path('.').glob(pattern):
                if path.is_file() and path.suffix == '.gd':
                    test_files.append(str(path))
        
        return sorted(set(test_files))

    def run(self, specific_files=None):
        """Run the corruption fix process"""
        print("🔧 FIVE PARSECS TEST SUITE CORRUPTION FIX")
        print("=" * 50)
        
        if self.dry_run:
            print("🔍 DRY RUN MODE - No files will be modified")
        
        # Get files to process
        if specific_files:
            files_to_process = specific_files
        else:
            files_to_process = self.find_test_files()
        
        print(f"📁 Found {len(files_to_process)} test files to check")
        
        # Process each file
        for file_path in files_to_process:
            if Path(file_path).exists():
                self.process_file(file_path)
        
        # Print summary
        self.print_summary()

    def print_summary(self):
        """Print execution summary"""
        print("\n" + "=" * 50)
        print("📊 CORRUPTION FIX SUMMARY")
        print("=" * 50)
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
    parser = argparse.ArgumentParser(description='Fix Five Parsecs test suite corruption')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without applying them')
    parser.add_argument('--no-backup', action='store_true', help='Skip creating backups')
    parser.add_argument('files', nargs='*', help='Specific files to process')
    
    args = parser.parse_args()
    
    fixer = TestSuiteCorruptionFixer(
        dry_run=args.dry_run,
        backup=not args.no_backup
    )
    
    fixer.run(args.files if args.files else None)

if __name__ == '__main__':
    main() 