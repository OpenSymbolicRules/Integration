import unittest
from merge_source_edition import integrate


def rule(i, x):
    return dict(id=i, pattern=['Int',x,'x_symbol'], constraints=[], result=x)


class MergeTests(unittest.TestCase):
    def test_inserts_in_source_order_and_keeps_old_provenance(self):
        old = dict(rule(9,'b'), provenance={'method':'converted'})
        result, reason = integrate([old], [rule(1,'a'),rule(2,'b'),rule(3,'c')])
        self.assertIsNone(reason)
        self.assertEqual(result, [rule(10,'a'),old,rule(11,'c')])

    def test_binary_atan_in_retained_and_reconciled_entries(self):
        from merge_source_edition import upgrade_atan
        old = rule(37, ['Add', ['Atan', 'y'], ['Atan', 'y', 'x']])
        old['constraints'] = [['NeQ', ['Atan', 0, 'x'], 0]]
        doc = {'rules': [old], 'semantics': {'Atan': 'openmath:transc1#arctan'}}
        upgrade_atan(doc)
        self.assertEqual(doc['semantics'], {'Atan': 'openmath:transc1#arctan', 'Atan2': 'openmath:transc2#arctan'})
        self.assertEqual(old['constraints'], [['NeQ', ['Atan2', 0, 'x'], 0]])
        new = rule(8, ['Add', ['Atan', 'y'], ['Atan2', 'y', 'x']])
        new['constraints'] = old['constraints']
        self.assertEqual(integrate([old], [new]), ([old], None))
        self.assertEqual(old['id'], 37)
        self.assertEqual(old['result'], new['result'])

    def test_ambiguous_missing_and_guard_changed(self):
        old = [rule(1,'a')]
        for fresh in ([rule(1,'a'),rule(2,'a')], [rule(1,'b')],
                      [dict(rule(1,'a'),constraints=[['NeQ','a',0]])]):
            self.assertIsNotNone(integrate(old,fresh)[1])

    def test_packaged_sum_rule_is_guarded_and_uses_the_pinned_helper(self):
        import json
        from pathlib import Path
        root = Path(__file__).resolve().parents[1] / 'rules'
        meta = json.loads((root / 'meta.json').read_text())
        path, = [p for p in meta['load_order'] if Path(p).name.startswith('1.4.1-')]
        doc = json.loads((root / path).read_text())
        rule, = [r for r in doc['rules'] if r['result'] == ['IntSum','u','x']]
        self.assertEqual(rule['constraints'], [['SumQ','u']])
        self.assertTrue(rule['provenance']['sources'][0]['locator'].endswith('.m#9'))
        self.assertFalse(meta['feature_flags']['load_show_steps'])
        ext = {entry['name']: entry for entry in meta['extensions']}
        self.assertEqual(ext['Star']['arity'], 2)
        self.assertEqual(ext['IntSum']['arity'], 2)

    def test_fixture_count_and_vocabulary(self):
        import json
        from pathlib import Path
        root = Path(__file__).resolve().parents[1]
        meta = json.loads((root / "rules/meta.json").read_bytes())
        count = sum(len(json.loads(p.read_bytes())["tests"]) for p in (root / "tests").rglob("*.json"))
        self.assertEqual(meta["test_count"], count)
        extensions = {entry["name"]: entry for entry in meta["extensions"]}
        self.assertEqual(extensions["Derivative"]["arity"], 1)
        self.assertEqual(extensions["Defer"]["arity"], 1)

    def test_packaged_quadratic_section_keeps_both_bounds_and_scoped_rules(self):
        import json
        from pathlib import Path
        root = Path(__file__).resolve().parents[1] / 'rules'
        path, = root.rglob('1.2.1.1-*.json')
        rules = json.loads(path.read_bytes())['rules']
        by_id = {r['id']: r for r in rules}
        self.assertIn(['LessEqual', 3, ['Denominator', 'p'], 4], by_id[13]['constraints'])
        with_d, with_q = [r for r in rules if r['provenance']['sources'][0]['locator'].endswith(('.m#21', '.m#22'))]
        self.assertEqual(with_d['result'][2][-1], ['LessEqual', 3, 'd', 4])
        self.assertIn('Hypergeometric2F1', str(with_q['result']))

    def test_maintenance_derivatives_match_release_payloads(self):
        import json
        from pathlib import Path
        from check_duplicate_rules import canonical_payload
        root = Path(__file__).resolve().parents[1]
        path = Path('rules/9-miscellaneous/9.1-Derivative-integration-rules.json')
        regular, release = [json.loads((base / path).read_bytes())['rules']
                            for base in (root, root / 'editions/rubi-4.17.3.0')]
        self.assertEqual([canonical_payload(r) for r in regular], [canonical_payload(r) for r in release])
        self.assertEqual([r['references'] for r in regular], [r['references'] for r in release])

    def test_build_rejects_an_unmatched_previously_loaded_rule(self):
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import patch
        from merge_source_edition import build
        meta = {'load_order': ['section.json'], 'converter': {'source_commit': 'pin'}, 'rule_count': 1}
        old = {'section': 'test', 'semantics': {}, 'rules': [rule(1, 'a')]}
        with tempfile.TemporaryDirectory() as tmp, patch('merge_source_edition.baseline',
                                                         side_effect=[meta, old]):
            root = Path(tmp)
            (root / 'meta.json').write_text(json.dumps(meta))
            (root / 'section.json').write_text(json.dumps(dict(old, rules=[rule(1, 'b')])))
            with self.assertRaisesRegex(ValueError, 'section.json'):
                build(root, root / 'out')
