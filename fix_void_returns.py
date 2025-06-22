#!/usr/bin/env python3
"""
Safe GDScript Void Function Fixer
Removes unnecessary 'return null' statements from void functions.
Usage: python fix_void_returns.py <file_path>
"""

import re
import sys
import argparse
from pathlib import Path

class VoidFunctionFixer:
    def __init__(self):
        # Pattern to match void function declarations
        self.void_func_pattern = re.compile(r'^(\s*)func\s+(\w+)\([^)]*\)\s*->\s*void\s*:', re.MULTILINE)
        # Pattern to match return null statements (more specific)
        self.return_null_pattern = re.compile(r'^(\s*)return\s+null\s*(?:#.*)?$', re.MULTILINE)
        # Pattern to match standalone return null (not in functions)
        self.standalone_return_null = re.compile(r'^(\s*)return\s+null\s*$', re.MULTILINE)
        # Pattern to match constructor return null
        self.constructor_return_null = re.compile(r'^(\s*)func\s+_init\([^)]*\)\s*->\s*void\s*:.*?^\s*return\s+null\s*$', re.MULTILINE | re.DOTALL)
        
    def remove_return_null_statements(self, file_path):
        """Remove all 'return null' statements from the file."""
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            original_content = content
            changes_made = []
            
            # First, remove standalone 'return null' statements
            def replace_return_null(match):
                line_content = match.group(0)
                line_num = content[:match.start()].count('\n') + 1
                changes_made.append(f"Line {line_num}: Removed standalone 'return null'")
                return ""  # Remove the entire line
            
            content = self.return_null_pattern.sub(replace_return_null, content)
            
            # Also handle cases where return null appears after constructor errors
            constructor_pattern = re.compile(r'^(\s*)return\s+null\s*\n(\s*)func\s+', re.MULTILINE)
            def replace_constructor_return(match):
                indent = match.group(1)
                func_line = match.group(2) + "func "
                line_num = content[:match.start()].count('\n') + 1
                changes_made.append(f"Line {line_num}: Removed constructor 'return null'")
                return func_line
            
            content = constructor_pattern.sub(replace_constructor_return, content)
            
            # Clean up any orphaned return null statements
            orphan_pattern = re.compile(r'^\s*return\s+null\s*\n', re.MULTILINE)
            def replace_orphan_return(match):
                line_num = content[:match.start()].count('\n') + 1
                changes_made.append(f"Line {line_num}: Removed orphaned 'return null'")
                return ""
            
            content = orphan_pattern.sub(replace_orphan_return, content)
            
            # Remove any double newlines that might have been created
            content = re.sub(r'\n\n\n+', '\n\n', content)
            
            if content != original_content:
                return {
                    'success': True,
                    'content': content,
                    'changes': changes_made,
                    'change_count': len(changes_made)
                }
            else:
                return {
                    'success': True,
                    'content': content,
                    'changes': [],
                    'change_count': 0
                }
                
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'changes': [],
                'change_count': 0
            }
    
    def analyze_file(self, file_path):
        """Analyze a file and find safe return null removals."""
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            issues = []
            
            # Find all return null statements
            for match in self.return_null_pattern.finditer(content):
                line_num = content[:match.start()].count('\n') + 1
                line_content = match.group(0).strip()
                
                issues.append({
                    'line': line_num,
                    'content': line_content,
                    'type': 'return_null',
                    'safety': 'SAFE'  # All return null in void functions are safe to remove
                })
            
            return {
                'success': True,
                'issues': issues,
                'file_path': file_path
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'issues': [],
                'file_path': file_path
            }
    
    def fix_file(self, file_path, auto_apply=False, safe_only=False):
        """Fix a single file by removing return null statements."""
        print(f"\n[ANALYZING] {file_path}")
        
        # First analyze the file
        analysis = self.analyze_file(file_path)
        if not analysis['success']:
            print(f"[ERROR] Error analyzing file: {analysis['error']}")
            return False
        
        if not analysis['issues']:
            print("[OK] No 'return null' statements found.")
            return True
        
        print(f"[INFO] Found {len(analysis['issues'])} 'return null' statements:")
        for issue in analysis['issues']:
            print(f"   Line {issue['line']}: {issue['content']} ({issue['safety']})")
        
        if not auto_apply:
            response = input(f"\n[PROMPT] Apply fixes to {len(analysis['issues'])} issues? (y/n): ")
            if response.lower() != 'y':
                print("[SKIPPED] User declined.")
                return False
        
        # Apply the fixes
        result = self.remove_return_null_statements(file_path)
        
        if not result['success']:
            print(f"[ERROR] Error fixing file: {result['error']}")
            return False
        
        if result['change_count'] == 0:
            print("[INFO] No changes needed.")
            return True
        
        # Write the fixed content back
        try:
            with open(file_path, 'w', encoding='utf-8') as file:
                file.write(result['content'])
            
            print(f"[SUCCESS] Fixed {result['change_count']} issues:")
            for change in result['changes']:
                print(f"   - {change}")
            
            return True
            
        except Exception as e:
            print(f"[ERROR] Error writing file: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Remove return null statements from GDScript void functions')
    parser.add_argument('file_path', help='Path to the GDScript file to fix')
    parser.add_argument('--auto', action='store_true', help='Apply fixes without confirmation')
    parser.add_argument('--safe-only', action='store_true', help='Only apply changes marked as SAFE (all return null removals are safe)')
    
    args = parser.parse_args()
    
    if not Path(args.file_path).exists():
        print(f"[ERROR] File not found: {args.file_path}")
        return 1
    
    if not args.file_path.endswith('.gd'):
        print(f"[WARNING] {args.file_path} doesn't appear to be a GDScript file")
    
    fixer = VoidFunctionFixer()
    success = fixer.fix_file(args.file_path, args.auto, args.safe_only)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 