"""Tests for the source-entry to verification-record reconciliation."""
import unittest
from source_verification_status import summarize, reconcile


class SourceStatusTests(unittest.TestCase):
    def test_original_and_strengthened_proofs_are_not_conflated(self):
        source = {'a:1', 'a:2', 'a:3', 'a:4'}
        rules = [
            {'id': 'r1', 'legacy_id': 'a:1', 'verification': [
                {'domain': 'real', 'status': 'counterexample', 'certified': False}]},
            {'id': 'r1_fixed', 'legacy_id': 'a:1', 'findings': ['strengthened: add x != 0'],
             'verification': [{'domain': 'real', 'status': 'proved', 'certified': True}]},
            {'id': 'r2', 'legacy_id': 'a:2', 'verification': [
                {'domain': 'real', 'status': 'proved', 'certified': True}]},
            {'id': 'r3', 'legacy_id': 'a:3', 'verification': [
                {'domain': 'real', 'status': 'unproved', 'certified': False}]},
            {'id': 'external', 'legacy_id': 'outside:1', 'verification': []},
        ]
        result = summarize(source, rules, 'real')
        self.assertEqual(result['entries'], 4)
        self.assertEqual(result['original']['counterexample'], 1)
        self.assertEqual(result['original']['certified'], 1)
        self.assertEqual(result['original']['unproved'], 1)
        self.assertEqual(result['original']['no_original_record'], 1)
        self.assertEqual(result['with_certified_strengthened_variant'], 1)
        self.assertEqual(sum(result['original'].values()), 4)
        self.assertEqual(result['v1_records_outside_source'], 1)

    def test_details_preserve_proof_and_variant_links(self):
        rules = [
            {'id': 'r1', 'legacy_id': 'a:1', 'verification': [
                {'domain': 'real', 'status': 'counterexample', 'certified': False,
                 'theorem': 'counterexample'}]},
            {'id': 'r1_fixed', 'legacy_id': 'a:1', 'findings': ['strengthened: nonzero'],
             'verification': [{'domain': 'real', 'status': 'proved', 'certified': True,
                               'theorem': 'fixed_proof'}]},
        ]
        rows = reconcile({'a:1', 'a:2'}, rules, 'real')
        self.assertEqual(rows[0]['original']['verification']['theorem'], 'counterexample')
        self.assertEqual(rows[0]['variants'][0]['verification']['theorem'], 'fixed_proof')
        self.assertIsNone(rows[1]['original'])

    def test_rejects_ambiguous_originals_and_inconsistent_certification(self):
        base = {'id': 'r', 'legacy_id': 'a:1', 'verification': []}
        with self.assertRaisesRegex(ValueError, 'multiple original'):
            summarize({'a:1'}, [base, dict(base, id='s')], 'real')
        with self.assertRaisesRegex(ValueError, 'certified'):
            summarize({'a:1'}, [dict(base, verification=[
                {'domain': 'real', 'status': 'unproved', 'certified': True}])], 'real')

    def test_unsupported_is_not_counted_as_unproved(self):
        rule = {'id': 'r', 'legacy_id': 'a:1', 'verification': [
            {'domain': 'real', 'status': 'unsupported', 'certified': False}]}
        self.assertEqual(summarize({'a:1'}, [rule], 'real')['original']['unsupported'], 1)

    def test_variant_only_and_missing_domain(self):
        rule = {'id': 'x', 'legacy_id': 'a:1', 'findings': ['generalized: description'],
                'verification': [{'domain': 'complex', 'status': 'proved', 'certified': False}]}
        self.assertEqual(summarize({'a:1'}, [rule], 'real')['original']['no_original_record'], 1)
        original = dict(rule, findings=[])
        self.assertEqual(summarize({'a:1'}, [original], 'real')['original']['no_domain_record'], 1)


if __name__ == '__main__':
    unittest.main()
