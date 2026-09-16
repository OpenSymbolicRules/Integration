#!/usr/bin/env bash
# Count rules and tests across all OSR JSON files
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES_DIR="$REPO_ROOT/rules"
TESTS_DIR="$REPO_ROOT/tests"

python3 -c "
import json, os, glob

rules_dir = '$RULES_DIR'
tests_dir = '$TESTS_DIR'

rule_files = sorted(glob.glob(os.path.join(rules_dir, '**/*.json'), recursive=True))
rule_files = [f for f in rule_files if not f.endswith('meta.json')]
total_rules = 0
empty_rule_files = 0
for f in rule_files:
    data = json.load(open(f))
    n = len(data.get('rules', []))
    total_rules += n
    if n == 0:
        empty_rule_files += 1

test_files = sorted(glob.glob(os.path.join(tests_dir, '**/*.json'), recursive=True))
total_tests = 0
for f in test_files:
    data = json.load(open(f))
    total_tests += len(data.get('tests', []))

print(f'Rule files:        {len(rule_files)}')
print(f'  with rules:      {len(rule_files) - empty_rule_files}')
print(f'  empty (0 rules): {empty_rule_files}')
print(f'Total rules:       {total_rules}')
print()
print(f'Test files:        {len(test_files)}')
print(f'Total tests:       {total_tests}')
"
