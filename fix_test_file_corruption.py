#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Test File Corruption Fix Script

SAFETY FEATURES:
- Creates backups before any changes
- Dry-run mode to preview changes  
- File-by-file validation
- Rollback capability
- Detailed logging

Usage:
    python fix_test_file_corruption.py --dry-run    # Preview changes only
    python fix_test_file_corruption.py --single tests/examples/gdunit4_example_test.gd  # Test one file
    python fix_test_file_corruption.py --apply      # Apply all fixes
"""

import os
import re
import shutil
import argparse
from pathlib import Path
from typing import List, Tuple, Dict
import datetime

class TestFileCorruptionFixer:
    def __init__(self, backup_dir: str = "backups/test_corruption_fix"):
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.changes_log = []
        
    def create_backup(self, file_path: Path) -> Path:
        """Create timestamped backup of file"""
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"{file_path.name}_{timestamp}.backup"
        backup_path = self.backup_dir / backup_name
        shutil.copy2(file_path, backup_path)
        print(f"✓ Backup created: {backup_path}")
        return backup_path
    
    def validate_gdscript_syntax(self, content: str, file_path: Path) -> bool:
        """Basic validation that the content looks like valid GDScript"""
        lines = content.split('\n')
        
        # Check for basic structure
        has_extends = any(line.strip().startswith('extends ') for line in lines)
        has_balanced_quotes = content.count('"') % 2 == 0
        has_balanced_parens = content.count('(') == content.count(')')
        
        if not has_extends:
            print(f"⚠️  Warning: {file_path} doesn't have 'extends' statement")
            return False
            
        if not has_balanced_quotes:
            print(f"⚠️  Warning: {file_path} has unbalanced quotes")
            return False
            
        if not has_balanced_parens:
            print(f"⚠️  Warning: {file_path} has unbalanced parentheses")
            return False
            
        return True
    
    def fix_pattern_1_file_header(self, content: str) -> Tuple[str, int]:
        """Fix corrupted file headers with orphaned @warning_ignore"""
        fixes = 0
        
        # Pattern: @tool\n@warning_ignore("return_value_discarded")\n\textends GdUnit...
        pattern1 = re.compile(
            r'(@tool\s*\n)@warning_ignore\([^)]+\)\s*\n\s*extends\s+',
            re.MULTILINE
        )
        if pattern1.search(content):
            content = pattern1.sub(r'\1extends ', content)
            fixes += 1
            
        # Pattern: standalone @warning_ignore before extends
        pattern2 = re.compile(
            r'^@warning_ignore\([^)]+\)\s*\n\s*extends\s+',
            re.MULTILINE
        )
        if pattern2.search(content):
            content = pattern2.sub('extends ', content)
            fixes += 1
            
        return content, fixes
    
    def fix_pattern_2_variable_declarations(self, content: str) -> Tuple[str, int]:
        """Fix corrupted variable declarations"""
        fixes = 0
        
        # Pattern: var name: @warning_ignore("unsafe_call_argument")\n\tArray[Type] = []
        pattern = re.compile(
            r'(var\s+\w+):\s*@warning_ignore\([^)]+\)\s*\n\s*(Array\[[^\]]+\]\s*=\s*\[\])',
            re.MULTILINE
        )
        
        matches = pattern.findall(content)
        if matches:
            content = pattern.sub(r'\1: \2', content)
            fixes += len(matches)
            
        return content, fixes
    
    def fix_pattern_3_string_interpolations(self, content: str) -> Tuple[str, int]:
        """Fix corrupted string interpolations"""
        fixes = 0
        
        # Pattern: strings broken by @warning_ignore annotations
        patterns = [
            # "Type mismatch: @warning_ignore("integer_division")\n\texpected % s but @warning_ignore("integer_division")\n\tgot % s"
            (r'"Type mismatch: @warning_ignore\([^)]+\)\s*\n\s*expected\s*%\s*s\s*but\s*@warning_ignore\([^)]+\)\s*\n\s*got\s*%\s*s"',
             '"Type mismatch: expected %s but got %s"'),
            
            # "Failed to @warning_ignore("integer_division")\n\tcast % s @warning_ignore("integer_division")\n\tto % s: %s"
            (r'"Failed to @warning_ignore\([^)]+\)\s*\n\s*cast\s*%\s*s\s*@warning_ignore\([^)]+\)\s*\n\s*to\s*%\s*s:\s*%s"',
             '"Failed to cast %s to %s: %s"'),
        ]
        
        for pattern, replacement in patterns:
            regex = re.compile(pattern, re.MULTILINE)
            if regex.search(content):
                content = regex.sub(replacement, content)
                fixes += 1
                
        return content, fixes
    
    def fix_pattern_4_function_calls(self, content: str) -> Tuple[str, int]:
        """Fix corrupted function calls"""
        fixes = 0
        
        # Pattern: return @warning_ignore("unsafe_method_access")\n\tobj.method()
        pattern = re.compile(
            r'return\s+@warning_ignore\([^)]+\)\s*\n\s*(\w+\.[^(]+\([^)]*\))',
            re.MULTILINE
        )
        
        if pattern.search(content):
            content = pattern.sub(r'@warning_ignore("unsafe_method_access")\n\treturn \1', content)
            fixes += 1
            
        return content, fixes
    
    def fix_file(self, file_path: Path, dry_run: bool = True) -> Dict:
        """Fix corruption patterns in a single file"""
        print(f"\n{'🔍' if dry_run else '🔧'} Processing: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                original_content = f.read()
        except Exception as e:
            return {"error": f"Failed to read file: {e}", "fixes": 0}
        
        content = original_content
        total_fixes = 0
        
        # Apply all fix patterns
        content, fixes1 = self.fix_pattern_1_file_header(content)
        content, fixes2 = self.fix_pattern_2_variable_declarations(content)
        content, fixes3 = self.fix_pattern_3_string_interpolations(content)
        content, fixes4 = self.fix_pattern_4_function_calls(content)
        
        total_fixes = fixes1 + fixes2 + fixes3 + fixes4
        
        if total_fixes == 0:
            print("  ✓ No corruption patterns found")
            return {"fixes": 0, "success": True}
        
        # Validate the fixed content
        if not self.validate_gdscript_syntax(content, file_path):
            return {"error": "Fixed content failed validation", "fixes": total_fixes}
        
        # Show changes summary
        print(f"  📊 Found fixes: Header={fixes1}, Variables={fixes2}, Strings={fixes3}, Functions={fixes4}")
        
        if dry_run:
            print("  👀 DRY RUN - No changes written")
            return {"fixes": total_fixes, "success": True, "dry_run": True}
        
        # Create backup and apply changes
        backup_path = self.create_backup(file_path)
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  ✅ Fixed {total_fixes} corruption patterns")
            
            # Log the change
            self.changes_log.append({
                "file": str(file_path),
                "fixes": total_fixes,
                "backup": str(backup_path),
                "timestamp": datetime.datetime.now().isoformat()
            })
            
            return {"fixes": total_fixes, "success": True, "backup": backup_path}
            
        except Exception as e:
            return {"error": f"Failed to write file: {e}", "fixes": total_fixes}
    
    def find_test_files(self) -> List[Path]:
        """Find all test files that need fixing"""
        test_dirs = [
            "tests/examples",
            "tests/fixtures", 
            "tests/integration",
            "tests/mobile",
            "tests/performance", 
            "tests/templates",
            "tests/unit"
        ]
        
        test_files = []
        for test_dir in test_dirs:
            test_path = Path(test_dir)
            if test_path.exists():
                test_files.extend(test_path.rglob("*.gd"))
        
        # Also include root test files
        root_test_files = [
            "tests/run_five_parsecs_tests.gd",
            "tests/run_tests.gd"
        ]
        
        for root_file in root_test_files:
            root_path = Path(root_file)
            if root_path.exists():
                test_files.append(root_path)
        
        return sorted(test_files)
    
    def generate_report(self) -> str:
        """Generate a summary report of all changes"""
        if not self.changes_log:
            return "No changes were made."
        
        total_fixes = sum(change["fixes"] for change in self.changes_log)
        
        report = f"""
FIVE PARSECS TEST FILE CORRUPTION FIX REPORT
============================================
Timestamp: {datetime.datetime.now().isoformat()}
Files processed: {len(self.changes_log)}
Total fixes applied: {total_fixes}

CHANGES LOG:
"""
        
        for change in self.changes_log:
            report += f"  📁 {change['file']}\n"
            report += f"     Fixes: {change['fixes']}\n"
            report += f"     Backup: {change['backup']}\n"
            report += f"     Time: {change['timestamp']}\n\n"
        
        report += f"""
ROLLBACK INSTRUCTIONS:
If you need to rollback changes, restore files from: {self.backup_dir}
"""
        
        return report

def main():
    parser = argparse.ArgumentParser(description="Fix Five Parsecs test file corruption")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without applying them")
    parser.add_argument("--apply", action="store_true", help="Apply fixes to all files")
    parser.add_argument("--single", help="Fix a single file (path)")
    parser.add_argument("--backup-dir", default="backups/test_corruption_fix", help="Backup directory")
    
    args = parser.parse_args()
    
    if not any([args.dry_run, args.apply, args.single]):
        parser.print_help()
        return
    
    fixer = TestFileCorruptionFixer(args.backup_dir)
    
    if args.single:
        # Fix single file
        file_path = Path(args.single)
        if not file_path.exists():
            print(f"❌ File not found: {file_path}")
            return
        
        result = fixer.fix_file(file_path, dry_run=args.dry_run)
        if result.get("error"):
            print(f"❌ Error: {result['error']}")
        else:
            print(f"✅ Completed with {result['fixes']} fixes")
    
    else:
        # Fix all files
        test_files = fixer.find_test_files()
        print(f"Found {len(test_files)} test files to process")
        
        if args.dry_run:
            print("\n🔍 DRY RUN MODE - No changes will be made\n")
        else:
            print(f"\n🔧 APPLYING FIXES - Backups will be created in {args.backup_dir}\n")
        
        success_count = 0
        error_count = 0
        total_fixes = 0
        
        for file_path in test_files:
            result = fixer.fix_file(file_path, dry_run=args.dry_run)
            
            if result.get("error"):
                print(f"❌ {file_path}: {result['error']}")
                error_count += 1
            else:
                success_count += 1
                total_fixes += result.get("fixes", 0)
        
        # Generate report
        print(f"\n📊 SUMMARY:")
        print(f"  ✅ Successful: {success_count}")
        print(f"  ❌ Errors: {error_count}")
        print(f"  🔧 Total fixes: {total_fixes}")
        
        if not args.dry_run and fixer.changes_log:
            report = fixer.generate_report()
            report_path = Path("test_corruption_fix_report.txt")
            with open(report_path, 'w') as f:
                f.write(report)
            print(f"  📄 Report saved: {report_path}")

if __name__ == "__main__":
    main() 