#!/usr/bin/env python3
"""
Five Parsecs Campaign Manager - Comprehensive Test Syntax Error Fixer

This script fixes all common syntax errors in test files including:
- Missing function bodies (Expected indented block after function declaration)
- Broken dictionary syntax (Expected end of statement after expression, found ":" instead)
- Missing closing brackets/parentheses
- Corrupted control flow structures
- Orphaned @warning_ignore annotations
- Missing return statements
- Malformed class definitions
- Broken lambda functions

SAFETY FEATURES:
- Creates backups before any changes
- Dry-run mode to preview changes
- File validation after fixes
- Detailed logging of all changes

Usage:
    python fix_all_test_syntax_errors.py --dry-run     # Preview changes only
    python fix_all_test_syntax_errors.py --apply       # Apply all fixes
    python fix_all_test_syntax_errors.py --single path/to/file.gd  # Fix single file
"""

import os
import re
import shutil
import argparse
from pathlib import Path
from typing import List, Tuple, Dict, Set
import datetime
import json

class ComprehensiveTestSyntaxFixer:
    def __init__(self, backup_dir: str = "backups/syntax_fix"):
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.changes_log = []
        self.total_fixes = 0
        
    def create_backup(self, file_path: Path) -> Path:
        """Create timestamped backup of file"""
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"{file_path.name}_{timestamp}.backup"
        backup_path = self.backup_dir / backup_name
        shutil.copy2(file_path, backup_path)
        return backup_path
    
    def fix_missing_function_bodies(self, content: str) -> Tuple[str, int]:
        """Fix functions with missing bodies"""
        fixes = 0
        lines = content.split('\n')
        result_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            
            # Check for function declaration without body
            if (re.match(r'^\s*func\s+\w+.*:\s*$', line) or 
                re.match(r'^\s*func\s+\w+.*->\s*\w+:\s*$', line)):
                
                result_lines.append(line)
                
                # Check if next line has proper indentation
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if (not next_line.strip() or 
                        not next_line.startswith('\t') or
                        next_line.strip().startswith('#') or
                        next_line.strip().startswith('func ') or
                        next_line.strip().startswith('var ') or
                        next_line.strip().startswith('class ') or
                        next_line.strip().startswith('signal ')):
                        
                        # Add pass statement
                        result_lines.append('\tpass')
                        fixes += 1
                else:
                    # End of file
                    result_lines.append('\tpass')
                    fixes += 1
            else:
                result_lines.append(line)
            
            i += 1
        
        return '\n'.join(result_lines), fixes
    
    def fix_broken_dictionaries(self, content: str) -> Tuple[str, int]:
        """Fix broken dictionary syntax"""
        fixes = 0
        
        # Pattern: standalone dictionary values without proper structure
        patterns = [
            # Fix: "key": value at start of line -> properly structure
            (r'^\s*"(\w+)":\s*([^,\n]+)(?:,?)\s*$', r'\t\t"\1": \2,'),
            
            # Fix: var dict = \n "key": value
            (r'(var\s+\w+(?:\s*:\s*Dictionary)?\s*=)\s*\n\s*"(\w+)":\s*([^,\n]+)', r'\1 {\n\t\t"\2": \3\n\t}'),
            
            # Fix: return \n "key": value
            (r'(return)\s*\n\s*"(\w+)":\s*([^,\n]+)', r'\1 {\n\t\t"\2": \3\n\t}'),
            
            # Fix: func name() -> Dictionary:\n\n\t\t"key": value
            (r'(func\s+\w+.*->\s*Dictionary:\s*\n)\s*\n\s*"(\w+)":\s*([^,\n]+)', r'\1\treturn {\n\t\t"\2": \3\n\t}'),
        ]
        
        for pattern, replacement in patterns:
            regex = re.compile(pattern, re.MULTILINE)
            if regex.search(content):
                content = regex.sub(replacement, content)
                fixes += 1
        
        return content, fixes
    
    def fix_missing_brackets(self, content: str) -> Tuple[str, int]:
        """Fix missing brackets and parentheses"""
        fixes = 0
        
        # Fix unmatched closing brackets
        patterns = [
            # Fix: Closing ) without opening
            (r'^\s*\)\s*\.', r''),
            
            # Fix: Closing ] without opening
            (r'^\s*\]\s*$', r''),
            
            # Fix: Closing } without opening
            (r'^\s*\}\s*$', r''),
            
            # Fix: Missing opening { for dictionary
            (r'(var\s+\w+\s*=)\s*\n\s*"(\w+)":', r'\1 {\n\t"\2":'),
        ]
        
        for pattern, replacement in patterns:
            regex = re.compile(pattern, re.MULTILINE)
            matches = regex.findall(content)
            if matches:
                content = regex.sub(replacement, content)
                fixes += len(matches) if isinstance(matches[0], str) else len(matches)
        
        return content, fixes
    
    def fix_control_flow_structures(self, content: str) -> Tuple[str, int]:
        """Fix broken control flow structures"""
        fixes = 0
        
        patterns = [
            # Fix: if condition: without body
            (r'(\s*if\s+[^:]+:\s*)\n\s*#.*\n', r'\1\n\t\tpass\n'),
            
            # Fix: else: without body
            (r'(\s*else:\s*)\n\s*#.*\n', r'\1\n\t\tpass\n'),
            
            # Fix: for loop without body
            (r'(\s*for\s+[^:]+:\s*)\n\s*#.*\n', r'\1\n\t\tpass\n'),
            
            # Fix: while loop without body
            (r'(\s*while\s+[^:]+:\s*)\n\s*#.*\n', r'\1\n\t\tpass\n'),
            
            # Fix: match pattern without body
            (r'(\s*\w+:\s*)\n\s*#.*\n', r'\1\n\t\tpass\n'),
        ]
        
        for pattern, replacement in patterns:
            regex = re.compile(pattern, re.MULTILINE)
            if regex.search(content):
                content = regex.sub(replacement, content)
                fixes += 1
        
        return content, fixes
    
    def fix_orphaned_annotations(self, content: str) -> Tuple[str, int]:
        """Fix orphaned @warning_ignore annotations"""
        fixes = 0
        
        # Remove orphaned @warning_ignore not followed by code
        pattern = re.compile(
            r'@warning_ignore\([^)]+\)\s*\n(?!\s*[a-zA-Z_])', 
            re.MULTILINE
        )
        
        matches = pattern.findall(content)
        if matches:
            content = pattern.sub('', content)
            fixes += len(matches)
        
        return content, fixes
    
    def fix_class_definitions(self, content: str) -> Tuple[str, int]:
        """Fix malformed class definitions"""
        fixes = 0
        
        # Fix class without body
        pattern = re.compile(
            r'(class\s+\w+(?:\s+extends\s+\w+)?:\s*)\n(?!\s*[a-zA-Z_])',
            re.MULTILINE
        )
        
        if pattern.search(content):
            content = pattern.sub(r'\1\n\tpass\n', content)
            fixes += 1
        
        return content, fixes
    
    def fix_lambda_functions(self, content: str) -> Tuple[str, int]:
        """Fix broken lambda functions"""
        fixes = 0
        
        patterns = [
            # Fix: func() -> void: without lambda body
            (r'(\s*func\([^)]*\)\s*->\s*\w+:\s*)\n(?!\s*[a-zA-Z_])', r'\1\n\t\tpass\n'),
            
            # Fix: standalone lambda errors
            (r'Standalone lambdas cannot be accessed[^\n]*\n', r''),
        ]
        
        for pattern, replacement in patterns:
            regex = re.compile(pattern, re.MULTILINE)
            if regex.search(content):
                content = regex.sub(replacement, content)
                fixes += 1
        
        return content, fixes
    
    def fix_indentation_issues(self, content: str) -> Tuple[str, int]:
        """Fix indentation mismatch issues"""
        fixes = 0
        
        # Fix common indentation problems
        patterns = [
            # Fix: Unexpected indent after comment
            (r'#[^\n]*\n(\s*)([a-zA-Z_]\w*)', r'#\n\1\2'),
            
            # Fix: Unexpected dedent
            (r'\n\s*Err \| Unindent doesn\'t match[^\n]*\n', r'\n'),
        ]
        
        for pattern, replacement in patterns:
            regex = re.compile(pattern, re.MULTILINE)
            if regex.search(content):
                content = regex.sub(replacement, content)
                fixes += 1
        
        return content, fixes
    
    def fix_method_calls(self, content: str) -> Tuple[str, int]:
        """Fix broken method calls and statements"""
        fixes = 0
        
        patterns = [
            # Fix: auto_free() call removed -> auto_free(node)
            (r'auto_free\(\) call removed', r'# auto_free(node)'),
            
            # Fix: track_node() call removed -> track_node(node)
            (r'track_node\(\) call removed', r'# track_node(node)'),
            
            # Fix: add_child() call removed -> add_child(node)
            (r'add_child\(\) call removed', r'# add_child(node)'),
            
            # Fix: assert_that() call removed -> pass
            (r'# assert_that\(\) call removed', r'pass'),
            
            # Fix: await call removed -> pass
            (r'# await call removed', r'pass'),
            
            # Fix: return statement removed -> pass
            (r'# return statement removed', r'pass'),
            
            # Fix: continue statement removed -> pass
            (r'# continue statement removed', r'pass'),
        ]
        
        for pattern, replacement in patterns:
            content = re.sub(pattern, replacement, content)
            fixes += content.count(replacement) - content.count(pattern)
        
        return content, fixes
    
    def clean_error_messages(self, content: str) -> Tuple[str, int]:
        """Remove linter error messages from content"""
        fixes = 0
        
        # Remove lines that are clearly linter errors
        error_patterns = [
            r'Err \|[^\n]*\n',
            r'___\n',
            r'Expected [^\n]*\n',
            r'Unexpected [^\n]*\n',
            r'Missing [^\n]*\n',
            r'Unmatched [^\n]*\n',
            r'Invalid [^\n]*\n',
        ]
        
        for pattern in error_patterns:
            matches = re.findall(pattern, content)
            if matches:
                content = re.sub(pattern, '', content)
                fixes += len(matches)
        
        return content, fixes
    
    def validate_basic_syntax(self, content: str) -> bool:
        """Basic validation of GDScript syntax"""
        # Check for balanced brackets
        if content.count('(') != content.count(')'):
            return False
        if content.count('[') != content.count(']'):
            return False
        if content.count('{') != content.count('}'):
            return False
        
        # Check for proper class structure
        lines = content.split('\n')
        has_extends = any(line.strip().startswith('extends ') for line in lines)
        
        return has_extends or any('class ' in line for line in lines)
    
    def fix_file(self, file_path: Path, dry_run: bool = True) -> Dict:
        """Apply all fixes to a single file"""
        print(f"\n{'🔍' if dry_run else '🔧'} Processing: {file_path.name}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                original_content = f.read()
        except Exception as e:
            return {"error": f"Failed to read file: {e}", "fixes": 0}
        
        content = original_content
        total_fixes = 0
        
        # Apply all fix patterns
        print("  📝 Applying fixes...")
        
        content, fixes1 = self.fix_orphaned_annotations(content)
        content, fixes2 = self.fix_missing_function_bodies(content)
        content, fixes3 = self.fix_broken_dictionaries(content)
        content, fixes4 = self.fix_missing_brackets(content)
        content, fixes5 = self.fix_control_flow_structures(content)
        content, fixes6 = self.fix_class_definitions(content)
        content, fixes7 = self.fix_lambda_functions(content)
        content, fixes8 = self.fix_indentation_issues(content)
        content, fixes9 = self.fix_method_calls(content)
        content, fixes10 = self.clean_error_messages(content)
        
        total_fixes = fixes1 + fixes2 + fixes3 + fixes4 + fixes5 + fixes6 + fixes7 + fixes8 + fixes9 + fixes10
        
        if total_fixes == 0:
            print("  ✅ No syntax errors found")
            return {"fixes": 0, "success": True}
        
        # Show detailed breakdown
        fix_breakdown = {
            "Orphaned annotations": fixes1,
            "Missing function bodies": fixes2,
            "Broken dictionaries": fixes3,
            "Missing brackets": fixes4,
            "Control flow": fixes5,
            "Class definitions": fixes6,
            "Lambda functions": fixes7,
            "Indentation": fixes8,
            "Method calls": fixes9,
            "Error messages": fixes10
        }
        
        print(f"  📊 Fixes applied:")
        for category, count in fix_breakdown.items():
            if count > 0:
                print(f"    • {category}: {count}")
        
        if dry_run:
            print(f"  👀 DRY RUN - Would fix {total_fixes} issues")
            return {"fixes": total_fixes, "success": True, "dry_run": True, "breakdown": fix_breakdown}
        
        # Validate before writing
        if not self.validate_basic_syntax(content):
            print(f"  ⚠️  Warning: Fixed content may still have syntax issues")
        
        # Create backup and write
        backup_path = self.create_backup(file_path)
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"  ✅ Fixed {total_fixes} syntax errors")
            
            # Log the changes
            self.changes_log.append({
                "file": str(file_path),
                "fixes": total_fixes,
                "breakdown": fix_breakdown,
                "backup": str(backup_path),
                "timestamp": datetime.datetime.now().isoformat()
            })
            
            return {"fixes": total_fixes, "success": True, "backup": backup_path, "breakdown": fix_breakdown}
            
        except Exception as e:
            return {"error": f"Failed to write file: {e}", "fixes": total_fixes}
    
    def fix_all_test_files(self, test_dir: Path, dry_run: bool = True) -> Dict:
        """Fix all test files in directory"""
        if not test_dir.exists():
            return {"error": f"Test directory not found: {test_dir}"}
        
        # Find all .gd files
        test_files = list(test_dir.rglob("*.gd"))
        
        print(f"🎯 Found {len(test_files)} test files")
        print(f"{'🔍 DRY RUN MODE - Previewing changes' if dry_run else '🔧 APPLYING FIXES'}")
        
        results = {
            "total_files": len(test_files),
            "processed": 0,
            "successful": 0,
            "failed": 0,
            "total_fixes": 0,
            "files": []
        }
        
        for file_path in sorted(test_files):
            result = self.fix_file(file_path, dry_run)
            results["files"].append(result)
            results["processed"] += 1
            
            if result.get("success"):
                results["successful"] += 1
                results["total_fixes"] += result.get("fixes", 0)
            else:
                results["failed"] += 1
                print(f"  ❌ {result.get('error', 'Unknown error')}")
        
        return results
    
    def generate_report(self, results: Dict) -> str:
        """Generate a summary report"""
        report = []
        report.append("# Test Syntax Fix Report")
        report.append(f"Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Summary
        report.append("## Summary")
        report.append(f"- Total files: {results['total_files']}")
        report.append(f"- Processed: {results['processed']}")
        report.append(f"- Successful: {results['successful']}")
        report.append(f"- Failed: {results['failed']}")
        report.append(f"- Total fixes: {results['total_fixes']}")
        report.append("")
        
        # Details
        if results.get("files"):
            report.append("## File Details")
            for file_result in results["files"]:
                if file_result.get("fixes", 0) > 0:
                    report.append(f"### {Path(file_result.get('file', 'Unknown')).name}")
                    report.append(f"- Fixes: {file_result['fixes']}")
                    if "breakdown" in file_result:
                        for category, count in file_result["breakdown"].items():
                            if count > 0:
                                report.append(f"  - {category}: {count}")
                    report.append("")
        
        return "\n".join(report)


def main():
    parser = argparse.ArgumentParser(description="Fix test file syntax errors")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without applying")
    parser.add_argument("--apply", action="store_true", help="Apply all fixes")
    parser.add_argument("--single", type=str, help="Fix single file")
    parser.add_argument("--test-dir", type=str, default="tests", help="Test directory path")
    
    args = parser.parse_args()
    
    # Determine base directory (handle both relative and absolute paths)
    base_dir = Path.cwd()
    if "five-parsecs-campaign-manager" not in str(base_dir):
        # Try to find the project directory
        for parent in base_dir.parents:
            if (parent / "project.godot").exists():
                base_dir = parent
                break
    
    test_dir = base_dir / args.test_dir
    fixer = ComprehensiveTestSyntaxFixer()
    
    if args.single:
        # Fix single file
        single_file = Path(args.single)
        if not single_file.exists():
            single_file = base_dir / args.single
        
        if not single_file.exists():
            print(f"❌ File not found: {args.single}")
            return
        
        result = fixer.fix_file(single_file, dry_run=not args.apply)
        
        if result.get("success"):
            print(f"\n✅ Successfully processed {single_file.name}")
            if result.get("fixes", 0) > 0:
                print(f"   Fixed {result['fixes']} issues")
        else:
            print(f"\n❌ Failed to process {single_file.name}")
            print(f"   Error: {result.get('error')}")
    
    else:
        # Fix all files
        dry_run = not args.apply
        results = fixer.fix_all_test_files(test_dir, dry_run)
        
        if results.get("error"):
            print(f"❌ {results['error']}")
            return
        
        # Print summary
        print(f"\n📊 SUMMARY:")
        print(f"   Total files: {results['total_files']}")
        print(f"   Processed: {results['processed']}")
        print(f"   Successful: {results['successful']}")
        print(f"   Failed: {results['failed']}")
        print(f"   Total fixes: {results['total_fixes']}")
        
        if not dry_run:
            # Generate and save report
            report = fixer.generate_report(results)
            report_path = base_dir / "test_syntax_fix_report.md"
            with open(report_path, 'w', encoding='utf-8') as f:
                f.write(report)
            print(f"\n📄 Report saved: {report_path}")
        
        print(f"\n🎉 {'Preview complete!' if dry_run else 'All fixes applied!'}")
        
        if dry_run:
            print("\n💡 To apply these fixes, run with --apply flag")


if __name__ == "__main__":
    main() 