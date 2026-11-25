#!/usr/bin/env python3
"""Build the expanded default profile from the previous default OSR snapshot and RUBI."""
import argparse
import json
from pathlib import Path
import subprocess
from check_duplicate_rules import canonical_payload

BASE = '75c07bb98d2e90586d826449a18cff43c5344edc'
ROOT = Path(__file__).resolve().parents[1]


def positions(needles, haystack):
    matches = []
    for i, value in enumerate(haystack):
        if len(matches) < len(needles) and value == needles[len(matches)]:
            matches.append(i)
    return matches


def integrate(old, fresh):
    before, after = [[canonical_payload(r) for r in rules] for rules in (old, fresh)]
    left = positions(before, after)
    if len(left) != len(old):
        return old, 'Existing entries do not form a subsequence of the converted source'
    right = positions(before[::-1], after[::-1])
    if left != [len(after)-1-i for i in reversed(right)]:
        return old, 'Multiple source positions fit an existing rule'
    existing = dict(zip(left, old))
    next_id = max((r['id'] for r in old), default=0) + 1
    merged = []
    for i, r in enumerate(fresh):
        if i in existing:
            merged.append(existing[i])
        else:
            merged.append(dict(r, id=next_id))
            next_id += 1
    return merged, None


def baseline(path):
    return json.loads(subprocess.check_output(['git','-C',ROOT,'show',f'{BASE}:rules/{path}']))


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=4, ensure_ascii=False)+'\n', encoding='utf-8')


def build(source, output):
    source_meta = json.loads((source/'meta.json').read_text())
    meta = baseline('meta.json')
    if meta['load_order'] != source_meta['load_order'] or meta['converter']['source_commit'] != source_meta['converter']['source_commit']:
        raise ValueError('Source revision or loader order differs from baseline')
    count = 0
    for path in meta['load_order']:
        old = baseline(path)
        fresh = json.loads((source/path).read_text())
        rules, reason = integrate(old['rules'], fresh['rules'])
        if reason:
            raise ValueError(f'{path}: {reason}')
        delta = len(rules) - len(old['rules'])
        if delta:
            for head, symbol in fresh['semantics'].items():
                if old['semantics'].get(head, symbol) != symbol:
                    raise ValueError(f'{path}: incompatible mapping for {head}')
            old['semantics'].update(fresh['semantics'])
            old['rules'] = rules
            count += delta
        write(output/path, old)
    meta['rule_count'] += count
    meta['test_count'] = sum(len(json.loads(p.read_bytes())['tests']) for p in (ROOT / 'tests').rglob('*.json'))
    extensions = source_meta['extensions']
    derivative, = (e for e in extensions if e['name'] == 'Derivative')
    derivative['semantics'] += ' Fixtures can also use symbolic or negative orders. Preserve these formally.'
    meta['extensions'] = extensions + [
        {'name': 'Defer', 'arity': 1, 'semantics':
         'Fixture operator. Preserve the unevaluated source head. Defer[Subst] is a held substitution. '
         'See https://reference.wolfram.com/language/ref/Defer.html'},
    ]
    meta['feature_flags']['load_show_steps'] = False
    write(output/'meta.json', meta)
    print(f'{count} entries added in source order')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('new_output', type=Path)
    args = parser.parse_args()
    if args.new_output.exists():
        parser.error('output already exists')
    build(args.source, args.new_output)
