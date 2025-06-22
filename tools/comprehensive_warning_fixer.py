#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Comprehensive Warning Fixer
Addresses actual linter error patterns found in the codebase
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

class ComprehensiveWarningFixer:
    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root)
        self.fixes_applied = {
            'unterminated_strings': 0,
            'signal_modernization': 0,
            'type_annotations': 0,
            'argument_type_mismatches': 0,
            'warning_ignore_cleanup': 0,
            'syntax_cleanup': 0
        }
        self.files_processed = 0
        
    def fix_all_warnings(self):
        """Main entry point - fix all warning types"""
        print("🚀 Five Parsecs Campaign Manager - Comprehensive Warning Fixer")
        print("=" * 65)
        
        # Process all .gd files
        gd_files = list(self.project_root.rglob("*.gd"))
        print(f"📁 Found {len(gd_files)} .gd files")
        
        for file_path in gd_files:
            try:
                if self._should_skip_file(file_path):
                    continue
                    
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                
                # Apply fixes in order of importance
                content = self._fix_unterminated_strings(content, file_path)
                content = self._fix_argument_type_mismatches(content, file_path)  
                content = self._fix_signal_modernization(content, file_path)
                content = self._fix_type_annotations(content, file_path)
                content = self._cleanup_warning_ignores(content, file_path)
                content = self._fix_syntax_issues(content, file_path)
                
                # Write back if changed
                if content != original_content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    self.files_processed += 1
                    print(f"✅ Fixed: {file_path.relative_to(self.project_root)}")
                    
            except Exception as e:
                print(f"❌ Error processing {file_path}: {e}")
        
        self._print_summary()

    def _should_skip_file(self, file_path: Path) -> bool:
        """Skip addon files and other non-project files"""
        path_str = str(file_path)
        skip_patterns = [
            'addons/',
            'examples/',
            '.godot/',
            'build/',
            'temp/'
        ]
        return any(pattern in path_str for pattern in skip_patterns)

    def _fix_unterminated_strings(self, content: str, file_path: Path) -> str:
        """Fix unterminated string literals - CRITICAL"""
        fixed = content
        
        # Pattern 1: Extra quote at end of return statements
        # "return serialized_data.duplicate(true) ""
        pattern1 = r'(return\s+[^"]*)"(\s*$)'
        matches1 = re.finditer(pattern1, fixed, re.MULTILINE)
        for match in matches1:
            if match.group(0).count('"') % 2 != 0:  # Odd number of quotes
                old_line = match.group(0)
                new_line = match.group(1) + match.group(2)  # Remove extra quote
                fixed = fixed.replace(old_line, new_line)
                self.fixes_applied['unterminated_strings'] += 1
                print(f"    🔧 Fixed unterminated string in return statement")
        
        # Pattern 2: Malformed dictionary/array endings
        # "} ""
        pattern2 = r'(\}|\])\s*"(\s*$)'
        matches2 = re.finditer(pattern2, fixed, re.MULTILINE)
        for match in matches2:
            old_line = match.group(0)
            new_line = match.group(1) + match.group(2)  # Remove extra quote
            fixed = fixed.replace(old_line, new_line)
            self.fixes_applied['unterminated_strings'] += 1
            print(f"    🔧 Fixed malformed string at end of structure")
        
        # Pattern 3: Node path strings missing closing quotes
        # $"Path
        pattern3 = r'(\$"[^"]*?)(\s*\n)'
        if re.search(pattern3, fixed):
            fixed = re.sub(pattern3, r'\1"\2', fixed)
            self.fixes_applied['unterminated_strings'] += 1
            print(f"    🔧 Fixed unterminated node path string")
        
        return fixed

    def _fix_argument_type_mismatches(self, content: str, file_path: Path) -> str:
        """Fix function argument type mismatches"""
        fixed = content
        
        # Specific fix for EventManager.gd type mismatch
        if 'EventManager.gd' in str(file_path):
            # resolve_event(event_type) where event_type is Dictionary but should be GameEnum
            pattern = r'resolve_event\(event_type\)'
            if pattern in fixed:
                # Replace with proper type extraction
                fixed = fixed.replace(
                    'resolve_event(event_type)',
                    'resolve_event(event_type.get("type", GameEnums.GlobalEvent.NONE))'
                )
                self.fixes_applied['argument_type_mismatches'] += 1
                print(f"    🔧 Fixed argument type mismatch in resolve_event")
        
        return fixed

    def _fix_signal_modernization(self, content: str, file_path: Path) -> str:
        """Convert emit_signal() to modern .emit() syntax"""
        fixed = content
        
        # Pattern: emit_signal("signal_name", arg1, arg2) -> signal_name.emit(arg1, arg2)
        pattern = r'emit_signal\("([^"]+)"(?:,\s*([^)]*))?\)'
        
        def replace_emit_signal(match):
            signal_name = match.group(1)
            args = match.group(2) if match.group(2) else ""
            if args.strip():
                return f"{signal_name}.emit({args})"
            else:
                return f"{signal_name}.emit()"
        
        old_fixed = fixed
        fixed = re.sub(pattern, replace_emit_signal, fixed)
        
        if fixed != old_fixed:
            count = len(re.findall(pattern, old_fixed))
            self.fixes_applied['signal_modernization'] += count
            print(f"    🔧 Modernized {count} signal emissions")
        
        return fixed

    def _fix_type_annotations(self, content: str, file_path: Path) -> str:
        """Add type annotations to untyped variables"""
        fixed = content
        lines = fixed.split('\n')
        modified = False
        
        for i, line in enumerate(lines):
            # Pattern: var name: -> var name: Type
            if re.match(r'^\s*var\s+\w+\s*:\s*$', line):
                # Infer type from context
                var_name = re.search(r'var\s+(\w+)', line).group(1)
                
                # Look at next few lines for assignment clues
                inferred_type = self._infer_variable_type(lines, i, var_name)
                
                if inferred_type:
                    lines[i] = line.rstrip() + f' {inferred_type}'
                    modified = True
                    self.fixes_applied['type_annotations'] += 1
        
        if modified:
            fixed = '\n'.join(lines)
            print(f"    🔧 Added type annotations to untyped variables")
        
        return fixed

    def _infer_variable_type(self, lines: List[str], var_line: int, var_name: str) -> str:
        """Infer variable type from assignment patterns"""
        # Look at next 5 lines for assignment
        for i in range(var_line + 1, min(var_line + 6, len(lines))):
            line = lines[i].strip()
            
            if f'{var_name} =' in line:
                # Common patterns
                if '= []' in line or '.append(' in line:
                    return 'Array'
                elif '= {}' in line or '[' in line and ']' in line:
                    return 'Dictionary'
                elif '= ""' in line or '= \'\'' in line:
                    return 'String'
                elif '= true' in line or '= false' in line:
                    return 'bool'
                elif '= 0' in line or re.search(r'= \d+', line):
                    return 'int'
                elif '= 0.0' in line or re.search(r'= \d+\.\d+', line):
                    return 'float'
                elif 'Vector2' in line:
                    return 'Vector2'
                elif 'Vector3' in line:
                    return 'Vector3'
                elif '.new()' in line:
                    # Try to extract class name
                    match = re.search(r'(\w+)\.new\(\)', line)
                    if match:
                        return match.group(1)
        
        return 'Variant'  # Default fallback

    def _cleanup_warning_ignores(self, content: str, file_path: Path) -> str:
        """Clean up existing warning ignore comments"""
        fixed = content
        
        # Remove redundant "return value discarded (intentional)" comments
        # since we're modernizing signals anyway
        pattern = r'\s*#\s*warning:\s*return\s*value\s*discarded\s*\(intentional\)\s*'
        old_fixed = fixed
        fixed = re.sub(pattern, '', fixed, flags=re.IGNORECASE)
        
        if fixed != old_fixed:
            count = len(re.findall(pattern, old_fixed, re.IGNORECASE))
            self.fixes_applied['warning_ignore_cleanup'] += count
            print(f"    🔧 Cleaned up {count} redundant warning ignore comments")
        
        return fixed

    def _fix_syntax_issues(self, content: str, file_path: Path) -> str:
        """Fix various syntax issues"""
        fixed = content
        
        # Remove duplicate consecutive empty lines (keep max 2)
        old_fixed = fixed
        fixed = re.sub(r'\n\n\n+', '\n\n', fixed)
        
        # Fix trailing whitespace
        fixed = re.sub(r'[ \t]+$', '', fixed, flags=re.MULTILINE)
        
        # Ensure file ends with single newline
        fixed = fixed.rstrip() + '\n'
        
        if fixed != old_fixed:
            self.fixes_applied['syntax_cleanup'] += 1
            print(f"    🔧 Fixed syntax formatting issues")
        
        return fixed

    def _print_summary(self):
        """Print summary of fixes applied"""
        print("\n" + "=" * 65)
        print("📊 SUMMARY OF FIXES APPLIED")
        print("=" * 65)
        print(f"📁 Files processed: {self.files_processed}")
        print(f"🔧 Total fixes: {sum(self.fixes_applied.values())}")
        print()
        
        for category, count in self.fixes_applied.items():
            if count > 0:
                category_name = category.replace('_', ' ').title()
                print(f"   {category_name}: {count}")
        
        print("\n✅ Warning fixing complete!")
        print("🎯 Next steps:")
        print("   1. Test compilation in Godot")
        print("   2. Run your test suite")
        print("   3. Check for any remaining warnings")

if __name__ == "__main__":
    fixer = ComprehensiveWarningFixer()
    fixer.fix_all_warnings() 