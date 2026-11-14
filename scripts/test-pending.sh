#!/usr/bin/env bash
set -euo pipefail

CORPUS_FILE="tree-sitter-asciidoc/test/corpus_pending/unlisted_specs.txt"

if [ ! -f "$CORPUS_FILE" ]; then
  echo "Pending corpus file not found: $CORPUS_FILE"
  exit 1
fi

python3 - <<'EOF'
import re
import subprocess

corpus_path = "tree-sitter-asciidoc/test/corpus_pending/unlisted_specs.txt"
with open(corpus_path, "r", encoding="utf-8") as f:
    raw = f.read()

pattern = r'={10,}\n(.*?)\n={10,}\n(.*?)\n-{10,}\n(.*?)(?=\n={10,}|\Z)'
matches = re.findall(pattern, raw, re.DOTALL)

def normalize_cst(s):
    # remove range annotations like [0, 0] - [1, 0]
    s = re.sub(r'\s*\[\d+,\s*\d+\]\s*-\s*\[\d+,\s*\d+\]', '', s)
    lines = [line.rstrip() for line in s.strip().split('\n') if line.strip()]
    return '\n'.join(lines)

print(f"\n--- Pending Unlisted Specs Catalog ({len(matches)} tests) ---")
passed = 0
for name, source_code, expected_cst in matches:
    name = name.strip()
    source_code = source_code.strip() + "\n"
    
    cmd = ["tree-sitter", "parse"]
    proc = subprocess.run(cmd, cwd="tree-sitter-asciidoc", input=source_code, capture_output=True, text=True)
    
    has_error = "(ERROR" in proc.stdout or "(MISSING" in proc.stdout or proc.returncode != 0
    if has_error:
        print(f"  ❌ [ERROR] {name}")
    else:
        actual_norm = normalize_cst(proc.stdout)
        expected_norm = normalize_cst(expected_cst)
        if actual_norm == expected_norm:
            print(f"  ✅ [MATCH] {name}")
            passed += 1
        else:
            print(f"  ⚠️ [DIFF]  {name}")
            print("   --- Expected:")
            print("   " + "\n   ".join(expected_norm.split("\n")[:6]))
            print("   --- Actual:")
            print("   " + "\n   ".join(actual_norm.split("\n")[:6]))

print(f"\nSummary: {passed}/{len(matches)} matching expected CST\n")
EOF
