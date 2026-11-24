#!/usr/bin/env python3
"""Compare file-loading sequences at two RUBI Git revisions without a checkout."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

from audit_rubi_order import conditional_range, strip_wolfram_comments


def parse_loader(source):
    clean = strip_wolfram_comments(source)
    try:
        clean = clean[clean.index('Unprotect[Int]'):clean.index('$RuleCount = Length[DownValues[Int]]')]
    except ValueError as exc:
        raise ValueError('RUBI integration load region not found') from exc
    begin, end = conditional_range(clean)
    result, seen, offset = [], set(), 0
    for line in clean.splitlines(keepends=True):
        stripped = line.strip()
        if 'LoadRules[' in stripped:
            if stripped == 'LoadRules[$utilityPackage];':
                offset += len(line)
                continue
            filename_join = re.fullmatch(r'LoadRules\s*\[\s*FileNameJoin\s*\[\s*\{(.*)\}\s*\]\s*\]\s*;?', stripped)
            literal = re.fullmatch(r'LoadRules\s*\[\s*("(?:[^"\\]|\\.)*")\s*\]\s*;?', stripped)
            try:
                if filename_join:
                    components = json.loads('[' + filename_join.group(1) + ']')
                    if not components or not all(isinstance(x, str) and x for x in components):
                        raise ValueError('nonliteral path components')
                    path = '/'.join(components)
                elif literal:
                    path = json.loads(literal.group(1))
                else:
                    raise ValueError(f'unsupported load call: {stripped}')
            except json.JSONDecodeError as exc:
                raise ValueError(f'unsupported literal in load call: {stripped}') from exc
            if not path or path in seen:
                raise ValueError(f'empty or duplicate source path: {path}')
            seen.add(path)
            result.append({'source': path, 'conditional_on_elementary': begin < offset < end})
        offset += len(line)
    return result


def compare_loaders(old, new):
    old_paths = [row['source'] for row in old]
    new_paths = [row['source'] for row in new]
    old_set, new_set = set(old_paths), set(new_paths)
    return {'old_files': len(old_paths), 'new_files': len(new_paths),
            'shared_files': len(old_set & new_set),
            'shared_relative_order_equal': [x for x in old_paths if x in new_set] ==
                                           [x for x in new_paths if x in old_set],
            'only_old': [x for x in old_paths if x not in new_set],
            'only_new': [x for x in new_paths if x not in old_set]}


def git(repository, *args):
    return subprocess.check_output(['git', '-C', str(repository), *args], text=True, stderr=subprocess.PIPE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rubi_repository', type=Path)
    parser.add_argument('old_revision')
    parser.add_argument('new_revision')
    args = parser.parse_args()
    old_commit = git(args.rubi_repository, 'rev-parse', '--verify', args.old_revision + '^{commit}').strip()
    new_commit = git(args.rubi_repository, 'rev-parse', '--verify', args.new_revision + '^{commit}').strip()
    old_source = git(args.rubi_repository, 'show', old_commit + ':Rubi/Rubi.m')
    new_source = git(args.rubi_repository, 'show', new_commit + ':Rubi/Rubi.m')
    comparison = compare_loaders(parse_loader(old_source), parse_loader(new_source))
    comparison.update(old_revision=old_commit, new_revision=new_commit,
        limitations=['File identities and relative load order only, not runtime rule priority.',
                     'Both elementary-conditional and unconditional files are included.'])
    print(json.dumps(comparison, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'RUBI loader comparison failed: {error}', file=sys.stderr)
        sys.exit(1)
