#!/usr/bin/env python3
"""Compare source definition counts with OSR entries, without changing either tree.

Counts are syntactic: conditional branches and definitions overridden at runtime
are counted independently. Differences do not identify corresponding rules.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from audit_rubi_order import audit_order, strip_wolfram_comments


def mask_strings(source):
    result = list(source)
    quoted = False
    i = 0
    while i < len(source):
        char = source[i]
        if quoted:
            result[i] = ' ' if char != '\n' else '\n'
            if char == '\\':
                i += 1
                if i >= len(source):
                    raise ValueError('unterminated string escape')
                result[i] = ' ' if source[i] != '\n' else '\n'
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
            result[i] = ' '
        i += 1
    if quoted:
        raise ValueError('unterminated string')
    return ''.join(result)


def count_int_definitions(source):
    clean = mask_strings(strip_wolfram_comments(source))
    count = 0
    for match in re.finditer(r'(?<![A-Za-z0-9_$`])Int\s*\[', clean):
        opening = clean.find('[', match.start())
        stack = [']']
        i = opening + 1
        while i < len(clean) and stack:
            char = clean[i]
            if char in '[{(':  # match the complete argument list, including nested patterns
                stack.append({'[': ']', '{': '}', '(': ')'}[char])
            elif char in ']})':
                if char != stack.pop():
                    raise ValueError(f'mismatched bracket at offset {i}')
            i += 1
        if stack:
            raise ValueError(f'unclosed Int application at offset {match.start()}')
        if re.match(r'\s*:=', clean[i:]):
            count += 1
    return count


def summarize_coverage(rows):
    source = sum(row['source_definitions'] for row in rows)
    entries = sum(row['osr_entries'] for row in rows)
    return {'source_definitions': source, 'osr_entries': entries,
            'net_entry_difference': source - entries,
            'files_with_fewer_entries': sum(row['osr_entries'] < row['source_definitions'] for row in rows),
            'files_with_more_entries': sum(row['osr_entries'] > row['source_definitions'] for row in rows),
            'empty_files_with_source_definitions': sum(not row['osr_entries'] and row['source_definitions'] > 0 for row in rows)}


def generate_report(rubi_root, rules_root):
    documents = {}
    for path in sorted(rules_root.rglob('*.json')):
        if path.name == 'meta.json':
            continue
        doc = json.loads(path.read_text(encoding='utf-8'))
        identity = doc.get('identity', '')
        if not identity.startswith('rubi:') or identity[5:] in documents:
            raise ValueError(f'missing or duplicate RUBI identity: {path}')
        documents[identity[5:]] = (str(path.relative_to(rules_root)), [r['id'] for r in doc['rules']])
    loader = rubi_root / 'Rubi' / 'Rubi.m'
    order = audit_order(loader.read_text(encoding='utf-8'), documents, elementary=True)
    rows = []
    for item in order['files']:
        source = rubi_root / 'Rubi' / 'IntegrationRules' / (item['source'] + '.m')
        data = source.read_bytes()
        rows.append({'source': item['source'], 'osr_file': item['osr_file'],
                     'file_order': item['file_order'],
                     'source_definitions': count_int_definitions(data.decode('utf-8')),
                     'osr_entries': len(item['rule_ids_in_osr_array_order']),
                     'source_sha256': hashlib.sha256(data).hexdigest()})
    paclet = (rubi_root / 'Rubi' / 'PacletInfo.m').read_text(encoding='utf-8')
    version = re.search(r'\bVersion\s*->\s*"([^"]+)"', paclet)
    if not version:
        raise ValueError('RUBI version not found in PacletInfo.m')
    try:
        revision = subprocess.check_output(['git', '-C', str(rubi_root), 'rev-parse', 'HEAD'],
                                         text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        revision = None
    return {'source_version': version.group(1), 'source_revision': revision,
            'loader_sha256': hashlib.sha256(loader.read_bytes()).hexdigest(),
            'elementary_enabled': True, 'loaded_files': len(rows),
            'excluded_files': len(order['not_loaded']), 'summary': summarize_coverage(rows),
            'limitations': ['Counts are source syntax and OSR entries, not proof statuses.',
                'Each conditional branch is counted independently; source counts are not runtime rule counts.',
                'Count differences do not identify missing or equivalent rules, and do not prove priority.',
                'Only Int[...] immediately followed by := is counted; guarded or other definitions can be missed.'],
            'files': rows, 'not_loaded': order['not_loaded']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rubi_root', type=Path)
    parser.add_argument('rules_root', type=Path)
    args = parser.parse_args()
    print(json.dumps(generate_report(args.rubi_root, args.rules_root), indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(f'RUBI coverage audit failed: {error}', file=sys.stderr)
        sys.exit(1)
