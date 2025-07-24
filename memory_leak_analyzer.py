

import re
from pathlib import Path

def analyze_memory_leaks():
    """
    Analyzes all GDScript files for memory leak patterns and anti-patterns.
    """
    src_path = Path("/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src")
    gdscript_files = list(src_path.glob("**/*.gd"))

    leak_patterns = {
        "missing_queue_free": re.compile(r"remove_child\((?!.*queue_free).+\)"),
        "unclosed_file_access": re.compile(r"FileAccess.open\((?!.*close).+\)", re.DOTALL),
        "unclosed_http_request": re.compile(r"HTTPRequest.new\((?!.*request_completed).+\)", re.DOTALL),
        "unconnected_signal": re.compile(r"signal.connect\((?!.*disconnect).+\)", re.DOTALL)
    }

    leak_risks = {
        "missing_queue_free": [],
        "unclosed_file_access": [],
        "unclosed_http_request": [],
        "unconnected_signal": []
    }

    for file_path in gdscript_files:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
                for leak_type, pattern in leak_patterns.items():
                    for match in pattern.finditer(content):
                        leak_risks[leak_type].append({
                            "file": str(file_path),
                            "line": content.count("\n", 0, match.start()) + 1,
                            "code": match.group(0).strip()
                        })
        except Exception as e:
            print(f"Could not read file {file_path}: {e}")

    _generate_markdown_report(len(gdscript_files), leak_risks)

def _generate_markdown_report(files_analyzed, leak_risks):
    report = "# Five Parsecs Campaign Manager - Memory Leak Analysis\n\n"
    total_risks = sum(len(v) for v in leak_risks.values())
    report += "## Executive Summary\n"
    report += f"- Files Analyzed: {files_analyzed}\n"
    report += f"- Memory Leak Risks Identified: {total_risks}\n"
    report += f"- High-Risk Files: {len(leak_risks['missing_queue_free']) + len(leak_risks['unclosed_file_access'])}\n"
    report += "- Estimated Memory Savings: [Not Calculated]\n\n"

    report += "## Pattern Analysis\n"
    report += "| Pattern Type | Occurrences | Risk Level | Est. Memory Impact |\n"
    report += "|--------------|-------------|------------|--------------------|\n"
    report += f"| Missing queue_free() | {len(leak_risks['missing_queue_free'])} | HIGH | High |\n"
    report += f"| Unclosed FileAccess | {len(leak_risks['unclosed_file_access'])} | MEDIUM | Medium |\n"
    report += f"| Unclosed HTTPRequest | {len(leak_risks['unclosed_http_request'])} | MEDIUM | Medium |\n"
    report += f"| Disconnected signals | {len(leak_risks['unconnected_signal'])} | LOW | Low |\n\n"

    report += "## Top 20 High-Risk Files\n"
    high_risk_files = (leak_risks["missing_queue_free"] + leak_risks["unclosed_file_access"])[:20]
    for i, risk in enumerate(high_risk_files, 1):
        report += f"{i}. [{risk['file']}:{risk['line']}] - `{risk['code']}` - High - Manual Review Required\n"

    report += "\n## Automated Fix Recommendations\n"
    report += "[Specific code changes for each pattern] - Not yet implemented\n\n"

    report += "## Implementation Priority\n"
    report += "1. IMMEDIATE: Files with potential data loss (Unclosed FileAccess)\n"
    report += "2. HIGH: Files with missing queue_free() calls\n"
    report += "3. MEDIUM: Files with unclosed HTTPRequest objects\n"
    report += "4. LOW: Files with potentially disconnected signals\n"

    with open("MEMORY_LEAK_AUDIT.md", "w", encoding="utf-8") as f:
        f.write(report)

if __name__ == "__main__":
    analyze_memory_leaks()

