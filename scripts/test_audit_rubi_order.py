"""Tests for the read-only RUBI source load-order audit."""
import unittest
import os
from pathlib import Path
import json

from audit_rubi_order import audit_order, strip_wolfram_comments


class RubiOrderTests(unittest.TestCase):
    def test_comments_conditions_and_rule_positions(self):
        source = r'''
Unprotect[Int];
LoadRules[$utilityPackage];
LoadRules[FileNameJoin[{"A", "first"}]];
(* Disabled LoadRules[FileNameJoin[{"A", "ignored"}]]; (* nested *) *)
If[$LoadElementaryFunctionRules===True,
  LoadRules[FileNameJoin[{"B", "second"}]];
];
LoadRules[FileNameJoin[{"C", "third"}]];
$RuleCount = Length[DownValues[Int]];
'''
        docs = {
            'A/first': ('a.json', [31, 12]),
            'B/second': ('b.json', [7]),
            'C/third': ('c.json', []),
            'orphan': ('orphan.json', [8]),
        }
        report = audit_order(source, docs, elementary=True)
        self.assertEqual([x['source'] for x in report['files']], ['A/first', 'B/second', 'C/third'])
        self.assertEqual(report['files'][0]['rule_ids_in_osr_array_order'], [31, 12])
        self.assertTrue(report['files'][1]['conditional_on_elementary'])
        self.assertEqual(report['not_loaded'][0]['source'], 'orphan')
        disabled = audit_order(source, docs, elementary=False)
        self.assertEqual([x['source'] for x in disabled['files']], ['A/first', 'C/third'])

    def test_unmatched_and_unsupported_calls_fail_closed(self):
        prefix = 'Unprotect[Int];\nIf[$LoadElementaryFunctionRules===True,\n];\n'
        suffix = '\n$RuleCount = Length[DownValues[Int]];'
        with self.assertRaises(ValueError):
            audit_order(prefix + 'LoadRules[unknown];' + suffix, {}, elementary=True)
        with self.assertRaises(ValueError):
            audit_order(prefix + 'LoadRules[FileNameJoin[{"missing"}]];' + suffix, {}, elementary=True)

    def test_nested_comments_do_not_erase_strings(self):
        clean = strip_wolfram_comments('"(* literal *)" (* x (* y *) z *) keep')
        self.assertIn('"(* literal *)"', clean)
        self.assertIn('keep', clean)
        with self.assertRaises(ValueError):
            strip_wolfram_comments('(* unclosed')

    def test_default_manifest_matches_pinned_source_when_available(self):
        root = Path(__file__).resolve().parent.parent
        vendor = Path(os.environ.get('OSR_RUBI_ROOT', root / 'vendor' / 'Rubi'))
        source = vendor / 'Rubi' / 'Rubi.m'
        if not source.is_file():
            self.skipTest('RUBI submodule is not initialized')
        docs = {}
        for path in (root / 'rules').rglob('*.json'):
            if path.name == 'meta.json':
                continue
            data = json.loads(path.read_text())
            docs[data['identity'][5:]] = (str(path.relative_to(root / 'rules')),
                                          [r['id'] for r in data['rules']])
        report = audit_order(source.read_text(), docs, elementary=True)
        meta = json.loads((root / 'rules' / 'meta.json').read_text())
        self.assertEqual(meta['load_order'],
                         [entry['osr_file'] for entry in report['files']])
        self.assertEqual(meta['rule_count'], sum(len(item[1]) for item in docs.values()))
        self.assertEqual(len(report['files']), 198)
        self.assertEqual(len(report['not_loaded']), 23)
        self.assertEqual(sum(len(entry['rule_ids_in_osr_array_order']) for entry in report['files']), 5504)
        self.assertEqual(sum(not entry['rule_ids_in_osr_array_order'] for entry in report['files']), 19)
        self.assertFalse(any('Normalizing algebraic functions' in entry['source']
                             for entry in report['files']))


if __name__ == '__main__':
    unittest.main()
