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
