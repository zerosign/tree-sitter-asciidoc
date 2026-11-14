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

# Pattern for tree-sitter corpus tests:
# ===+\nNAME\n===+\nINPUT\n---+\nOUTPUT
pattern = r'=+\n(.*?)\n=+\n(.*?)\n-+\n(.*?)(?=\n=+|\Z)'
matches = re.findall(pattern, raw, re.DOTALL)

print(f"\n--- Pending Unlisted Specs Catalog ({len(matches)} tests) ---")
failed = 0
for name, source_code, expected_cst in matches:
    name = name.strip()
    source_code = source_code.strip() + "\n"
    
    cmd = ["tree-sitter", "parse"]
    proc = subprocess.run(cmd, cwd="tree-sitter-asciidoc", input=source_code, capture_output=True, text=True)
    
    has_error = "(ERROR" in proc.stdout or "(MISSING" in proc.stdout or proc.returncode != 0
    if has_error:
        print(f"  ❌ [FAILING] {name}")
        failed += 1
    else:
        print(f"  ⚠️ [DIFF/UNCONFIRMED] {name}")

print(f"\nSummary: {failed} failing with syntax errors, {len(matches) - failed} parsed without syntax error\n")
EOF
