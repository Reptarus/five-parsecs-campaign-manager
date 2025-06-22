#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Comprehensive Linter Pattern Fixer
Fixes the most common linter warning patterns with maximum efficiency.
"""

import os
import re
import sys
from pathlib import Path

class LinterPatternFixer:
    def __init__(self):
        self.files_processed = 0
        self.total_fixes = 0
        self.patterns_fixed = {
            'orphaned_return_null': 0,
            'corrupted_warning_ignore': 0,
            'unterminated_strings': 0,
            'parameter_mismatches': 0,
            'syntax_cleanup': 0
        }

    def process_all_files(self):
        """Process all .gd files in the project"""
        src_dirs = ['src/', 'tests/', 'tools/']
        
        for src_dir in src_dirs:
            if os.path.exists(src_dir):
                for root, dirs, files in os.walk(src_dir):
                    for file in files:
                        if file.endswith('.gd'):
                            file_path = os.path.join(root, file)
                            self.fix_file(file_path)

    def fix_file(self, file_path):
        """Fix all patterns in a single file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # Apply all fixes
            content = self.fix_orphaned_return_null(content)
            content = self.fix_corrupted_warning_ignore(content)  
            content = self.fix_unterminated_strings(content)
            content = self.fix_parameter_mismatches(content)
            content = self.fix_syntax_cleanup(content)
            
            # Only write if changes were made
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                self.files_processed += 1
                print(f"✅ Fixed: {file_path}")
            
        except Exception as e:
            print(f"❌ Error processing {file_path}: {e}")

    def fix_orphaned_return_null(self, content):
        """Fix orphaned 'return null' statements"""
        fixes = 0
        
        # Pattern 1: 'return null' after void functions
        patterns = [
            r'\n\s*return null\s*\n(?=func|\n|$)',
            r'{\s*return null\s*}',
            r':\s*return null\s*\n',
        ]
        
        for pattern in patterns:
            old_content = content
            content = re.sub(pattern, '\n', content, flags=re.MULTILINE)
            if content != old_content:
                fixes += 1
        
        self.patterns_fixed['orphaned_return_null'] += fixes
        return content

    def fix_corrupted_warning_ignore(self, content):
        """Fix corrupted @warning_ignore annotations"""
        fixes = 0
        
        # Remove orphaned @warning_ignore lines
        patterns = [
            r'^\s*@warning_ignore\([^)]*\)\s*$\n',  # Standalone lines
            r',\s*@warning_ignore\([^)]*\)\s*,',    # Middle of arrays
            r'\[\s*@warning_ignore\([^)]*\)\s*',    # Start of arrays
            r',\s*@warning_ignore\([^)]*\)\s*\]',   # End of arrays
            r'{\s*@warning_ignore\([^)]*\)\s*',     # Start of dicts
            r',\s*@warning_ignore\([^)]*\)\s*}',    # End of dicts
        ]
        
        replacements = ['', ',', '[', ']', '{', '}']
        
        for pattern, replacement in zip(patterns, replacements):
            old_content = content
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if content != old_content:
                fixes += 1
        
        self.patterns_fixed['corrupted_warning_ignore'] += fixes
        return content

    def fix_unterminated_strings(self, content):
        """Fix unterminated string literals"""
        fixes = 0
        
        # Pattern: Missing closing quotes in node paths
        patterns = [
            r'\$"([^"]*)\n',  # $"Path without closing quote
            r'= "([^"]*)\n(?!\s*")',  # var = "text without closing quote
        ]
        
        for pattern in patterns:
            matches = re.finditer(pattern, content)
            for match in matches:
                old_line = match.group(0)
                if not old_line.rstrip().endswith('"'):
                    new_line = old_line.rstrip() + '"\n'
                    content = content.replace(old_line, new_line)
                    fixes += 1
        
        self.patterns_fixed['unterminated_strings'] += fixes
        return content

    def fix_parameter_mismatches(self, content):
        """Fix parameter naming mismatches"""
        fixes = 0
        
        # Pattern: func name(_value) but code uses 'value'
        function_pattern = r'func\s+\w+\([^)]*_(\w+)[^)]*\)\s*(?:->\s*\w+)?\s*:\s*\n((?:.*\n)*?)(?=func|\nclass|\n@|\Z)'
        
        matches = re.finditer(function_pattern, content, re.MULTILINE)
        for match in matches:
            func_body = match.group(2)
            param_name = match.group(1)
            
            # Check if function body uses 'param_name' instead of '_param_name'
            if re.search(rf'\b{param_name}\b', func_body) and not re.search(rf'\b_{param_name}\b', func_body):
                # Replace usages in function body
                new_body = re.sub(rf'\b{param_name}\b', f'_{param_name}', func_body)
                content = content.replace(func_body, new_body)
                fixes += 1
        
        self.patterns_fixed['parameter_mismatches'] += fixes
        return content

    def fix_syntax_cleanup(self, content):
        """Fix various syntax issues"""
        fixes = 0
        
        # Pattern 1: Fix broken multi-line expressions with misplaced annotations
        patterns = [
            # return\n@warning_ignore -> return
            (r'return\s*\n\s*@warning_ignore\([^)]*\)\s*', 'return '),
            
            # property.method\n@warning_ignore -> property.method
            (r'(\w+)\s*\n\s*@warning_ignore\([^)]*\)\s*([.(\[])', r'\1\2'),
            
            # Fix broken function calls across lines
            (r'(\w+)\(\s*\n\s*@warning_ignore\([^)]*\)\s*', r'\1('),
            
            # Clean up double newlines after fixes
            (r'\n\s*\n\s*\n', '\n\n'),
        ]
        
        for pattern, replacement in patterns:
            old_content = content
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if content != old_content:
                fixes += 1
        
        self.patterns_fixed['syntax_cleanup'] += fixes
        return content

    def print_summary(self):
        """Print summary of fixes applied"""
        print("\n" + "="*60)
        print("🎯 LINTER PATTERN FIX SUMMARY")
        print("="*60)
        print(f"📁 Files Processed: {self.files_processed}")
        print(f"🔧 Total Fixes Applied: {sum(self.patterns_fixed.values())}")
        print("\n📊 Fixes by Category:")
        
        for pattern, count in self.patterns_fixed.items():
            emoji = "✅" if count > 0 else "⬜"
            pattern_name = pattern.replace('_', ' ').title()
            print(f"   {emoji} {pattern_name}: {count}")
        
        print("\n🚀 Most Impactful Fixes:")
        sorted_fixes = sorted(self.patterns_fixed.items(), key=lambda x: x[1], reverse=True)
        for pattern, count in sorted_fixes[:3]:
            if count > 0:
                pattern_name = pattern.replace('_', ' ').title()
                print(f"   🏆 {pattern_name}: {count} fixes")

def main():
    print("🔧 Five Parsecs Campaign Manager - Linter Pattern Fixer")
    print("="*60)
    
    fixer = LinterPatternFixer()
    fixer.process_all_files()
    fixer.print_summary()
    
    print("\n✨ Pattern fixing complete!")
    print("💡 Tip: Run the Godot editor to check remaining warnings")

if __name__ == "__main__":
    main() 