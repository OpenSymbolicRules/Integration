#!/usr/bin/env python3
"""Reconcile v0.1 inventory entries and v1 verification records by legacy ID.

A match is provenance evidence, not proof that the translation preserves every
source assumption or the operational behavior of RUBI.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import sys


def variant_kind(rule):
    markers = {f.split(':', 1)[0] for f in rule.get('findings', [])}
    kinds = markers & {'strengthened', 'generalized'}
    if len(kinds) > 1:
        raise ValueError(f"ambiguous variant type: {rule['id']}")
    return next(iter(kinds), 'original')


def domain_verification(rule, domain):
    entries = [v for v in rule.get('verification', []) if v['domain'] == domain]
    if len(entries) > 1:
        raise ValueError(f"multiple {domain} verification records: {rule['id']}")
    if not entries:
        return None
    entry = entries[0]
    if entry['status'] not in {'proved', 'unproved', 'unsupported', 'counterexample'}:
        raise ValueError(f"unknown verification status: {entry['status']}")
    if entry['certified'] and entry['status'] != 'proved':
        raise ValueError(f"certified without a proof: {rule['id']}")
    return entry


def reconcile(source_ids, rules, domain):
    """Return traceable records, retaining the proof evidence for each variant."""
    by_source = defaultdict(list)
    for rule in rules:
        if rule.get('legacy_id') in source_ids:
            by_source[rule['legacy_id']].append(rule)
    rows = []
    for source_id in sorted(source_ids):
        original, variants = None, []
        for rule in by_source[source_id]:
            kind = variant_kind(rule)
            item = {'id': rule['id'], 'kind': kind,
                    'verification': domain_verification(rule, domain)}
            if kind == 'original':
                if original is not None:
                    raise ValueError(f'multiple original records for {source_id}')
                original = item
            else:
                variants.append(item)
        rows.append({'legacy_id': source_id, 'original': original, 'variants': variants})
    return rows


def summarize(source_ids, rules, domain):
    by_source = defaultdict(list)
    outside = 0
    for rule in rules:
        if rule.get('legacy_id') not in source_ids:
            outside += 1
        else:
            by_source[rule['legacy_id']].append(rule)
    counts = Counter({name: 0 for name in ('certified', 'proved_not_certified',
        'counterexample', 'unproved', 'unsupported', 'no_domain_record', 'no_original_record')})
    variants = Counter()
    for source_id in source_ids:
        group = by_source[source_id]
        originals = [r for r in group if variant_kind(r) == 'original']
        if len(originals) > 1:
            raise ValueError(f'multiple original records for {source_id}')
        if not originals:
            counts['no_original_record'] += 1
        else:
            verification = domain_verification(originals[0], domain)
            if verification is None:
                counts['no_domain_record'] += 1
            elif verification['status'] == 'proved':
                counts['certified' if verification['certified'] else 'proved_not_certified'] += 1
            else:
                counts[verification['status']] += 1
        for kind in ('strengthened', 'generalized'):
            if any((v := domain_verification(r, domain)) and v['certified']
                   for r in group if variant_kind(r) == kind):
                variants[kind] += 1
    return {'entries': len(source_ids), 'original': dict(counts),
            'with_certified_strengthened_variant': variants['strengthened'],
            'with_certified_generalized_variant': variants['generalized'],
            'v1_records_outside_source': outside}


def load_inventory(rules_dir):
    meta = json.loads((rules_dir / 'meta.json').read_text(encoding='utf-8'))
    identifiers = set()
    for relative in meta['load_order']:
        doc = json.loads((rules_dir / relative).read_text(encoding='utf-8'))
        for rule in doc['rules']:
            identifier = f"{doc['identity']}:{rule['id']}"
            if identifier in identifiers:
                raise ValueError(f'duplicate v0.1 identifier: {identifier}')
            identifiers.add(identifier)
    return identifiers


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rules', type=Path, default=root / 'rules')
    parser.add_argument('--v1', type=Path, default=root / 'v1/integration.osr.json')
    parser.add_argument('--details', action='store_true', help='include per-entry proof and variant records')
    args = parser.parse_args()
    source = load_inventory(args.rules)
    data = args.v1.read_bytes()
    document = json.loads(data)
    report = {
        'scope': 'OSR v0.1 entries listed in meta.json load_order; joined by legacy_id, not direct source-code equivalence.',
        'limitations': [
            'Proof statuses concern the migrated v1 encoding and the named domain, not the original RUBI program.',
            'Certification is restricted to the explicitly documented Lean semantic fragment, including integer-only powers.',
            'Variant totals overlap original status categories and are not additional source entries.',
            'Missing v1 records are not mathematical counterexamples or proof failures.',
            'Provenance identifiers alone do not establish faithful translation or RUBI execution priority.'
        ],
        'v1_sha256': hashlib.sha256(data).hexdigest(),
        'build': document['build'],
        'domains': {d: summarize(source, document['rules'], d) for d in ('real', 'complex')},
    }
    if args.details:
        report['entries'] = {d: reconcile(source, document['rules'], d) for d in ('real', 'complex')}
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f'status reconciliation failed: {error}', file=sys.stderr)
        sys.exit(1)
