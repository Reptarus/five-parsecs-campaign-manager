#!/usr/bin/env python3
"""
Fix Linter Errors Script for Five Parsecs Campaign Manager
Addresses remaining syntax and linter errors in test files.
"""

import os
import re
import shutil
from datetime import datetime
from pathlib import Path

class LinterErrorFixer:
    def __init__(self, workspace_root=".", dry_run=True):
        self.workspace_root = Path(workspace_root)
        self.dry_run = dry_run
        self.fixes_applied = {}
        self.backup_dir = self.workspace_root / "backups" / f"linter_fixes_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Statistics
        self.files_processed = 0
        self.total_fixes = 0
        
    def create_backup(self, file_path):
        """Create backup of original file"""
        if not self.dry_run:
            self.backup_dir.mkdir(parents=True, exist_ok=True)
            backup_path = self.backup_dir / file_path.name
            shutil.copy2(file_path, backup_path)
            print(f"✓ Backup created: {backup_path}")
    
    def fix_dictionary_syntax(self, content):
        """Fix dictionary syntax errors"""
        fixes = 0
        
        # Fix malformed dictionary keys with extra commas
        patterns = [
            # Fix "key": {, -> "key": {
            (r'"([^"]+)":\s*\{\s*,', r'"\1": {'),
            # Fix missing colons in dictionary declarations
            (r'const\s+([A-Z_]+)\s*:=\s*\{\s*([^}]*?)\s*([^:}]+)\s*([^}]*?)\s*\}', 
             lambda m: f'const {m.group(1)} := {{\n\t\t{self._fix_dict_content(m.group(2) + m.group(3) + m.group(4))}\n\t}}'),
            # Fix dictionary entries missing colons
            (r'^\s*"([^"]+)"\s+([^:,}]+)\s*,?\s*$', r'\t"\1": \2,'),
        ]
        
        for pattern, replacement in patterns:
            if callable(replacement):
                content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            else:
                new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
                if new_content != content:
                    fixes += len(re.findall(pattern, content, flags=re.MULTILINE))
                    content = new_content
        
        return content, fixes
    
    def _fix_dict_content(self, dict_content):
        """Helper to fix dictionary content"""
        lines = dict_content.strip().split('\n')
        fixed_lines = []
        
        for line in lines:
            line = line.strip()
            if line and not line.startswith('#') and ':' not in line and '=' not in line:
                # Try to infer if this should be a key-value pair
                if '"' in line and not line.endswith(':'):
                    # Looks like a malformed key-value pair
                    parts = line.split('"')
                    if len(parts) >= 3:
                        key = parts[1]
                        value_part = '"'.join(parts[2:]).strip()
                        if value_part.startswith(','):
                            value_part = value_part[1:].strip()
                        if value_part:
                            line = f'"{key}": {value_part}'
                        else:
                            line = f'"{key}": ""'
            fixed_lines.append(line)
        
        return '\n\t\t'.join(fixed_lines)
    
    def fix_function_bodies(self, content):
        """Fix missing function body indentation"""
        fixes = 0
        
        patterns = [
            # Fix functions with missing bodies after declaration
            (r'(func\s+[^(]+\([^)]*\)\s*->\s*[^:]+:)\s*\n\s*(Err\s*\|\s*Expected indented block after function declaration\.)',
             r'\1\n\t\tpass'),
            # Fix functions that just have 'pass' without proper indentation
            (r'(func\s+[^(]+\([^)]*\)\s*->\s*[^:]+:)\s*\n(Err\s*\|\s*Expected indented block after function declaration\.)\s*\n(\d+\s*\|\s*pass)',
             r'\1\n\t\tpass'),
            # Fix lambda functions
            (r'(func\s*\([^)]*\)\s*->\s*[^:]+:)\s*\n\s*(Err\s*\|\s*Expected indented block after lambda declaration\.)',
             r'\1\n\t\tpass'),
        ]
        
        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if new_content != content:
                fixes += len(re.findall(pattern, content, flags=re.MULTILINE))
                content = new_content
        
        return content, fixes
    
    def fix_control_flow_blocks(self, content):
        """Fix missing indented blocks after control flow statements"""
        fixes = 0
        
        patterns = [
            # Fix if statements with missing blocks
            (r'(\s*if\s+[^:]+:)\s*\n\s*(Err\s*\|\s*Expected indented block after "if" block\.)',
             r'\1\n\t\t\tpass'),
            # Fix for loops with missing blocks  
            (r'(\s*for\s+[^:]+:)\s*\n\s*(Err\s*\|\s*Expected indented block after "for" block\.)',
             r'\1\n\t\t\tpass'),
            # Fix while loops with missing blocks
            (r'(\s*while\s+[^:]+:)\s*\n\s*(Err\s*\|\s*Expected indented block after "while" block\.)',
             r'\1\n\t\t\tpass'),
            # Fix else statements with missing blocks
            (r'(\s*else:)\s*\n\s*(Err\s*\|\s*Expected indented block after "else" block\.)',
             r'\1\n\t\t\tpass'),
        ]
        
        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if new_content != content:
                fixes += len(re.findall(pattern, content, flags=re.MULTILINE))
                content = new_content
        
        return content, fixes
    
    def fix_enum_syntax(self, content):
        """Fix enum syntax errors"""
        fixes = 0
        
        patterns = [
            # Fix missing enum closing braces and identifiers
            (r'(enum\s+\w+\s*\{[^}]*?)\s*(Err\s*\|\s*Expected identifier for enum key\..*?)(Err\s*\|\s*Expected closing "\}" for enum\.)',
             r'\1\n\t\tNONE = 0\n\t}'),
            # Fix enum declarations without proper structure
            (r'(enum\s+\w+\s*\{)\s*([^}]*?)(Err[^}]*Expected closing "\}" for enum[^}]*)',
             r'\1\n\t\tNONE = 0\n\t}'),
        ]
        
        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            if new_content != content:
                fixes += 1
                content = new_content
        
        return content, fixes
    
    def fix_class_declarations(self, content):
        """Fix class declaration issues"""
        fixes = 0
        
        patterns = [
            # Fix class declarations with missing bodies
            (r'(class\s+\w+[^:]*:)\s*\n\s*(Err\s*\|\s*Expected indented block after class declaration\.)',
             r'\1\n\tpass'),
        ]
        
        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if new_content != content:
                fixes += len(re.findall(pattern, content, flags=re.MULTILINE))
                content = new_content
        
        return content, fixes
    
    def fix_statement_errors(self, content):
        """Fix various statement-level errors"""
        fixes = 0
        
        patterns = [
            # Fix unexpected identifiers in class body
            (r'\n\s*(Err\s*\|\s*Unexpected "[^"]*" in class body\.)\s*\n',
             r'\n'),
            # Fix expected end of file errors
            (r'\n\s*(Err\s*\|\s*Expected end of file\.)\s*\n',
             r'\n'),
            # Fix unindent errors
            (r'\n\s*(Err\s*\|\s*Unindent doesn\'t match the previous indentation level\.)\s*\n',
             r'\n'),
            # Remove orphaned error comments
            (r'\n\s*(Err\s*\|[^\n]*)\n',
             r'\n'),
        ]
        
        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if new_content != content:
                fixes += len(re.findall(pattern, content, flags=re.MULTILINE))
                content = new_content
        
        return content, fixes
    
    def fix_string_and_expression_errors(self, content):
        """Fix string and expression syntax errors"""
        fixes = 0
        
        patterns = [
            # Fix dictionary key syntax
            (r'(\s*)"([^"]+)"([^:,}]*),\s*', r'\1"\2": \3,'),
            # Fix closing brace mismatches
            (r'(Err\s*\|\s*Closing "[^"]*" doesn\'t match[^.]*\.)', r''),
            # Fix expected expression errors
            (r'(Err\s*\|\s*Expected expression[^.]*\.)', r''),
        ]
        
        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if new_content != content:
                fixes += len(re.findall(pattern, content, flags=re.MULTILINE))
                content = new_content
        
        return content, fixes
    
    def fix_specific_godot_patterns(self, content):
        """Fix Godot-specific syntax patterns"""
        fixes = 0
        
        patterns = [
            # Fix tab character warnings in ship test files
            (r'Err \| Used tab character for indentation instead of space[^\n]*\n', r''),
            # Fix incomplete dictionary declarations
            (r'var\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*Dictionary\s*=\s*\{\s*\n\s*Err[^}]*\n', 
             r'var \1: Dictionary = {}\n'),
            # Fix malformed constant declarations
            (r'const\s+([A-Z_]+)\s*:=\s*\{\s*\n[^}]*?Expected[^}]*?\n\s*\}', 
             r'const \1 := {}'),
        ]
        
        for pattern, replacement in patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            if new_content != content:
                fixes += len(re.findall(pattern, content, flags=re.MULTILINE | re.DOTALL))
                content = new_content
        
        return content, fixes
    
    def process_file(self, file_path):
        """Process a single file to fix linter errors"""
        try:
            print(f"\n📝 Processing: {file_path}")
            
            with open(file_path, 'r', encoding='utf-8') as f:
                original_content = f.read()
            
            content = original_content
            file_fixes = 0
            
            # Apply all fix categories
            fix_methods = [
                ('Dictionary Syntax', self.fix_dictionary_syntax),
                ('Function Bodies', self.fix_function_bodies), 
                ('Control Flow Blocks', self.fix_control_flow_blocks),
                ('Enum Syntax', self.fix_enum_syntax),
                ('Class Declarations', self.fix_class_declarations),
                ('Statement Errors', self.fix_statement_errors),
                ('String/Expression Errors', self.fix_string_and_expression_errors),
                ('Godot Patterns', self.fix_specific_godot_patterns),
            ]
            
            for category_name, fix_method in fix_methods:
                content, fixes = fix_method(content)
                if fixes > 0:
                    print(f"  ✓ {category_name}: {fixes} fixes")
                    file_fixes += fixes
            
            if file_fixes > 0:
                self.fixes_applied[str(file_path)] = file_fixes
                self.total_fixes += file_fixes
                
                if not self.dry_run:
                    self.create_backup(file_path)
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"  💾 Applied {file_fixes} fixes to {file_path}")
                else:
                    print(f"  🔍 DRY RUN: Would apply {file_fixes} fixes to {file_path}")
            else:
                print(f"  ✨ No fixes needed for {file_path}")
            
            self.files_processed += 1
            
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
            test_path = self.workspace_root / test_dir
            if test_path.exists():
                test_files.extend(test_path.rglob("*.gd"))
        
        return sorted(test_files)
    
    def generate_report(self):
        """Generate a summary report"""
        print(f"\n{'='*60}")
        print(f"LINTER ERROR FIXING REPORT")
        print(f"{'='*60}")
        print(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE EXECUTION'}")
        print(f"Files Processed: {self.files_processed}")
        print(f"Total Fixes Applied: {self.total_fixes}")
        print(f"Files Modified: {len(self.fixes_applied)}")
        
        if self.fixes_applied:
            print(f"\nFiles with fixes:")
            for file_path, fix_count in sorted(self.fixes_applied.items()):
                print(f"  {Path(file_path).name}: {fix_count} fixes")
        
        if not self.dry_run and self.backup_dir.exists():
            print(f"\nBackups created in: {self.backup_dir}")
        
        print(f"{'='*60}")
    
    def run(self):
        """Main execution method"""
        print("🔧 Five Parsecs Campaign Manager - Linter Error Fixer")
        print(f"Workspace: {self.workspace_root}")
        print(f"Mode: {'DRY RUN' if self.dry_run else 'LIVE EXECUTION'}")
        
        test_files = self.find_test_files()
        print(f"\nFound {len(test_files)} test files to process")
        
        for file_path in test_files:
            self.process_file(file_path)
        
        self.generate_report()

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Fix linter errors in Five Parsecs test files")
    parser.add_argument("--dry-run", action="store_true", default=True,
                       help="Preview changes without applying them")
    parser.add_argument("--apply", action="store_true", 
                       help="Apply the fixes (overrides --dry-run)")
    parser.add_argument("--workspace", default=".", 
                       help="Path to workspace root")
    
    args = parser.parse_args()
    
    # If --apply is specified, turn off dry_run
    dry_run = args.dry_run and not args.apply
    
    fixer = LinterErrorFixer(args.workspace, dry_run=dry_run)
    fixer.run()

if __name__ == "__main__":
    main() 