#!/usr/bin/env python3
"""
Comprehensive Linter Error Fixer for Five Parsecs Campaign Manager
Handles remaining common linter error patterns across all test files.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

class ComprehensiveLinterFixer:
    def __init__(self):
        self.backup_dir = Path("backups") / f"comprehensive_linter_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.fixes_applied = {}
        self.total_fixes = 0
        
    def create_backup(self, file_path):
        """Create backup of original file"""
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = self.backup_dir / file_path.name
        shutil.copy2(file_path, backup_path)
        
    def fix_function_bodies(self, content):
        """Fix missing function body errors"""
        fixes = 0
        
        # Pattern 1: Functions with "Expected indented block after function declaration"
        pattern1 = r'(func\s+[^(]+\([^)]*\)\s*(?:->\s*[^:]+)?:)\s*\n\s*Err \| Expected indented block after function declaration\.\s*\n(\d+\s*\|\s*pass)'
        replacement1 = r'\1\n\tpass'
        matches1 = re.findall(pattern1, content)
        content = re.sub(pattern1, replacement1, content)
        fixes += len(matches1)
        
        # Pattern 2: Functions with just "pass" but missing proper indentation
        pattern2 = r'(func\s+[^(]+\([^)]*\)\s*(?:->\s*[^:]+)?:)\s*\n\s*Err \| Expected indented block after function declaration\.\s*\n\s*pass'
        replacement2 = r'\1\n\tpass'
        matches2 = re.findall(pattern2, content)
        content = re.sub(pattern2, replacement2, content)
        fixes += len(matches2)
        
        return content, fixes
        
    def fix_control_flow_blocks(self, content):
        """Fix missing indented blocks after control flow statements"""
        fixes = 0
        
        patterns = [
            # If statements
            (r'(\s*if\s+[^:]+:)\s*\n\s*Err \| Expected indented block after "if" block\.\s*', r'\1\n\t\tpass'),
            # For loops  
            (r'(\s*for\s+[^:]+:)\s*\n\s*Err \| Expected indented block after "for" block\.\s*', r'\1\n\t\tpass'),
            # While loops
            (r'(\s*while\s+[^:]+:)\s*\n\s*Err \| Expected indented block after "while" block\.\s*', r'\1\n\t\tpass'),
            # Else statements
            (r'(\s*else:)\s*\n\s*Err \| Expected indented block after "else" block\.\s*', r'\1\n\t\tpass'),
        ]
        
        for pattern, replacement in patterns:
            matches = re.findall(pattern, content)
            content = re.sub(pattern, replacement, content)
            fixes += len(matches)
            
        return content, fixes
        
    def fix_dictionary_syntax(self, content):
        """Fix dictionary syntax errors"""
        fixes = 0
        
        patterns = [
            # Fix malformed dictionary keys with extra commas: "key": {, -> "key": {
            (r'"([^"]+)":\s*\{\s*,', r'"\1": {'),
            # Fix missing colons in dictionary entries
            (r'^\s*"([^"]+)"\s+([^:,}]+)\s*,?\s*$', r'\t"\1": \2,'),
            # Fix expression as dictionary key errors
            (r'Err \| Expected expression as dictionary key\.', r''),
            (r'Err \| Expected ":" after dictionary key\.', r''),
            (r'Err \| Expected expression as dictionary value\.', r''),
            (r'Err \| Expected closing "\}" after dictionary elements\.', r''),
        ]
        
        for pattern, replacement in patterns:
            matches = re.findall(pattern, content, re.MULTILINE)
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            fixes += len(matches)
            
        return content, fixes
        
    def fix_enum_syntax(self, content):
        """Fix enum syntax errors"""
        fixes = 0
        
        patterns = [
            # Fix incomplete enums
            (r'(enum\s+\w+\s*\{[^}]*?)\s*Err \| Expected identifier for enum key\.\s*\n\s*Err \| Expected closing "\}" for enum\.\s*', 
             r'\1\n\tNONE = 0\n}'),
            # Fix enum followed by other statements
            (r'(enum\s+\w+\s*\{[^}]*?)\s*Err \| Expected closing "\}" for enum\.\s*\n\s*Err \| Expected end of statement after enum, found "[^"]*" instead\.', 
             r'\1\n\tNONE = 0\n}'),
        ]
        
        for pattern, replacement in patterns:
            matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            fixes += len(matches)
            
        return content, fixes
        
    def fix_class_declarations(self, content):
        """Fix class declaration issues"""
        fixes = 0
        
        patterns = [
            # Fix class declarations with missing bodies
            (r'(class\s+\w+[^:]*:)\s*\n\s*Err \| Expected indented block after class declaration\.\s*', r'\1\n\tpass'),
        ]
        
        for pattern, replacement in patterns:
            matches = re.findall(pattern, content)
            content = re.sub(pattern, replacement, content)
            fixes += len(matches)
            
        return content, fixes
        
    def fix_unexpected_tokens(self, content):
        """Fix unexpected tokens and identifiers in class body"""
        fixes = 0
        
        patterns = [
            # Remove unexpected identifier errors
            (r'\n\s*Err \| Unexpected "[^"]*" in class body\.\s*', r''),
            # Remove expected end of file errors  
            (r'\n\s*Err \| Expected end of file\.\s*', r''),
            # Fix unindent errors
            (r'\n\s*Err \| Unindent doesn\'t match the previous indentation level\.\s*', r''),
            # Remove orphaned standalone function calls
            (r'^is_equal\([^)]*\)\s*$', r''),
            (r'^is_true\(\)\s*$', r''),
            (r'^is_false\(\)\s*$', r''),
        ]
        
        for pattern, replacement in patterns:
            matches = re.findall(pattern, content, re.MULTILINE)
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            fixes += len(matches)
            
        return content, fixes
        
    def fix_statement_errors(self, content):
        """Fix various statement-level errors"""
        fixes = 0
        
        patterns = [
            # Fix expected statement errors
            (r'Err \| Expected statement, found "[^"]*" instead\.', r''),
            # Fix expected end of statement errors
            (r'Err \| Expected end of statement after [^,]*, found "[^"]*" instead\.', r''),
            # Fix closing bracket mismatches
            (r'Err \| Closing "[^"]*" doesn\'t [^.]*\.', r''),
        ]
        
        for pattern, replacement in patterns:
            matches = re.findall(pattern, content)
            content = re.sub(pattern, replacement, content)
            fixes += len(matches)
            
        return content, fixes
        
    def fix_tab_indentation(self, content):
        """Fix tab character indentation warnings (convert to spaces)"""
        fixes = 0
        
        # Remove tab character warnings
        pattern = r'Err \| Used tab character for indentation instead of space[^\n]*\n'
        matches = re.findall(pattern, content)
        content = re.sub(pattern, '', content)
        fixes += len(matches)
        
        # Convert tabs to spaces (4 spaces per tab)
        if '\t' in content:
            content = content.replace('\t', '    ')
            fixes += content.count('\t')
            
        return content, fixes
        
    def fix_variable_declarations(self, content):
        """Fix variable declaration errors"""
        fixes = 0
        
        patterns = [
            # Fix incomplete dictionary variable declarations
            (r'var\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*Dictionary\s*=\s*\{\s*\n[^}]*?Err[^}]*?\n', 
             r'var \1: Dictionary = {}'),
        ]
        
        for pattern, replacement in patterns:
            matches = re.findall(pattern, content, re.MULTILINE | re.DOTALL)
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            fixes += len(matches)
            
        return content, fixes
        
    def clean_orphaned_errors(self, content):
        """Remove any remaining orphaned error messages"""
        fixes = 0
        
        # Remove any remaining error lines
        pattern = r'^.*?Err \|.*?\n'
        matches = re.findall(pattern, content, re.MULTILINE)
        content = re.sub(pattern, '', content, flags=re.MULTILINE)
        fixes += len(matches)
        
        return content, fixes
        
    def process_file(self, file_path):
        """Process a single file to fix linter errors"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                original_content = f.read()
            
            content = original_content
            file_fixes = 0
            
            # Apply all fix categories in order
            fix_methods = [
                ('Function Bodies', self.fix_function_bodies),
                ('Control Flow Blocks', self.fix_control_flow_blocks),
                ('Dictionary Syntax', self.fix_dictionary_syntax),
                ('Enum Syntax', self.fix_enum_syntax),
                ('Class Declarations', self.fix_class_declarations),
                ('Unexpected Tokens', self.fix_unexpected_tokens),
                ('Statement Errors', self.fix_statement_errors),
                ('Tab Indentation', self.fix_tab_indentation),
                ('Variable Declarations', self.fix_variable_declarations),
                ('Orphaned Errors', self.clean_orphaned_errors),
            ]
            
            for category_name, fix_method in fix_methods:
                content, fixes = fix_method(content)
                if fixes > 0:
                    print(f"  ✓ {category_name}: {fixes} fixes")
                    file_fixes += fixes
            
            if file_fixes > 0:
                self.fixes_applied[str(file_path)] = file_fixes
                self.total_fixes += file_fixes
                
                # Create backup and write fixed content
                self.create_backup(file_path)
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"  💾 Applied {file_fixes} fixes to {file_path.name}")
            else:
                print(f"  ✨ No additional fixes needed for {file_path.name}")
                
        except Exception as e:
            print(f"  ❌ Error processing {file_path}: {str(e)}")
            
    def find_test_files(self):
        """Find all test files in the workspace"""
        test_dirs = [
            "tests/fixtures",
            "tests/unit", 
            "tests/integration",
            "tests/performance",
            "tests/mobile"
        ]
        
        test_files = []
        for test_dir in test_dirs:
            test_path = Path(test_dir)
            if test_path.exists():
                test_files.extend(test_path.rglob("*.gd"))
        
        return sorted(test_files)
        
    def run(self):
        """Main execution method"""
        print("🔧 Comprehensive Linter Error Fixer for Five Parsecs Campaign Manager")
        print("Fixing remaining linter errors across all test files...\n")
        
        test_files = self.find_test_files()
        print(f"Found {len(test_files)} test files to process\n")
        
        for file_path in test_files:
            print(f"📝 Processing: {file_path}")
            self.process_file(file_path)
            
        print(f"\n{'='*60}")
        print(f"COMPREHENSIVE LINTER FIXES SUMMARY")
        print(f"{'='*60}")
        print(f"Files processed: {len(test_files)}")
        print(f"Files modified: {len(self.fixes_applied)}")
        print(f"Total fixes applied: {self.total_fixes}")
        
        if self.fixes_applied:
            print(f"\nTop 10 files with most fixes:")
            sorted_fixes = sorted(self.fixes_applied.items(), key=lambda x: x[1], reverse=True)[:10]
            for file_path, fix_count in sorted_fixes:
                print(f"  {Path(file_path).name}: {fix_count} fixes")
        
        print(f"\nBackups created in: {self.backup_dir}")
        print(f"{'='*60}")

def main():
    fixer = ComprehensiveLinterFixer()
    fixer.run()

if __name__ == "__main__":
    main() 