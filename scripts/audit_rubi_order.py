#!/usr/bin/env python3
"""Read-only comparison of OSR file ordering with the pinned RUBI loader."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


def strip_wolfram_comments(source):
    out = list(source)
    i = depth = 0
    quoted = False
    while i < len(source):
        if depth:
            if source.startswith('(*', i):
                out[i:i+2] = '  '; depth += 1; i += 2
            elif source.startswith('*)', i):
                out[i:i+2] = '  '; depth -= 1; i += 2
            else:
                if source[i] != '\n': out[i] = ' '
                i += 1
        elif not quoted and source.startswith('(*', i):
            out[i:i+2] = '  '; depth = 1; i += 2
        elif quoted and source[i] == '\\':
            i += 2
        elif source[i] == '"':
            quoted = not quoted; i += 1
        else:
            i += 1
    if depth or quoted:
        raise ValueError('unterminated comment or string in RUBI source')
    return ''.join(out)


def conditional_range(source):
    matches = list(re.finditer(r'\bIf\s*\[', source))
    if len(matches) != 1:
        raise ValueError('unexpected conditional load structure')
    start = matches[0].start()
    if not re.match(r'If\s*\[\s*\$LoadElementaryFunctionRules\s*===\s*True\s*,', source[start:]):
        raise ValueError('unsupported load condition')
    opening = source.index('[', start)
    depth, quoted, i = 0, False, opening
    while i < len(source):
        c = source[i]
        if quoted and c == '\\':
            i += 2; continue
        if c == '"':
            quoted = not quoted
        elif not quoted and c == '[':
            depth += 1
        elif not quoted and c == ']':
            depth -= 1
            if depth == 0:
                return start, i
        i += 1
    raise ValueError('unterminated elementary-function load block')


def audit_order(source, documents, elementary=True):
    clean = strip_wolfram_comments(source)
    try:
        clean = clean[clean.index('Unprotect[Int]'):clean.index('$RuleCount = Length[DownValues[Int]]')]
    except ValueError as exc:
        raise ValueError('RUBI integration load region not found') from exc
    begin, end = conditional_range(clean)
    files, seen = [], set()
    offset = 0
    for line in clean.splitlines(keepends=True):
        stripped = line.strip()
        if 'LoadRules[' in stripped:
            if stripped == 'LoadRules[$utilityPackage];':
                offset += len(line); continue
            match = re.fullmatch(r'LoadRules\s*\[\s*FileNameJoin\s*\[\s*\{(.*)\}\s*\]\s*\]\s*;?', stripped)
            if not match:
                raise ValueError(f'unsupported load call: {stripped}')
            try:
                components = json.loads('[' + match.group(1) + ']')
            except json.JSONDecodeError as exc:
                raise ValueError(f'unsupported file path in load call: {stripped}') from exc
            if not components or not all(isinstance(x, str) and x for x in components):
                raise ValueError('nonliteral RUBI file path')
            source_path = '/'.join(components)
            if source_path in seen:
                raise ValueError(f'duplicate RUBI load: {source_path}')
            seen.add(source_path)
            conditional = begin < offset < end
            if elementary or not conditional:
                if source_path not in documents:
                    raise ValueError(f'no uniquely identified OSR file for {source_path}')
                file_path, ids = documents[source_path]
                files.append({'file_order': len(files) + 1, 'source': source_path,
                              'osr_file': file_path, 'conditional_on_elementary': conditional,
                              'rule_ids_in_osr_array_order': ids})
        offset += len(line)
    not_loaded = [{'source': key, 'osr_file': value[0], 'rules': len(value[1])}
                  for key, value in sorted(documents.items())
                  if key not in {item['source'] for item in files}]
    return {'elementary_enabled': elementary, 'files': files, 'not_loaded': not_loaded}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rubi_root', type=Path)
    parser.add_argument('rules_root', type=Path)
    parser.add_argument('--no-elementary', action='store_true')
    args = parser.parse_args()
    source_file = args.rubi_root / 'Rubi' / 'Rubi.m'
    raw = source_file.read_bytes()
    documents = {}
    for path in sorted(args.rules_root.rglob('*.json')):
        if path.name == 'meta.json': continue
        doc = json.loads(path.read_text())
        identity = doc.get('identity', '')
        if not identity.startswith('rubi:') or identity[5:] in documents:
            raise ValueError(f'missing or duplicate RUBI identity: {path}')
        documents[identity[5:]] = (str(path.relative_to(args.rules_root)),
                                   [rule['id'] for rule in doc['rules']])
    report = audit_order(raw.decode('utf-8'), documents, elementary=not args.no_elementary)
    report['limitations'] = ('File load sequence only; OSR array positions and rule IDs are '
        'not a proof of Mathematica runtime priority. Converted or missing rules are not inferred.')
    report['source_sha256'] = hashlib.sha256(raw).hexdigest()
    paclet = (args.rubi_root / 'Rubi' / 'PacletInfo.m').read_text()
    version = re.search(r'\bVersion\s*->\s*"([^"]+)"', paclet)
    if not version:
        raise ValueError('RUBI version not found in PacletInfo.m')
    report['source_version'] = version.group(1)
    try:
        report['source_revision'] = subprocess.check_output(
            ['git', '-C', str(args.rubi_root), 'rev-parse', 'HEAD'],
            text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        report['source_revision'] = None
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(f'RUBI order audit failed: {error}', file=sys.stderr)
        sys.exit(1)
