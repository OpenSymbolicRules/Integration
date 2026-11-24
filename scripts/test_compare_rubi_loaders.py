"""Tests for comparing file identities across RUBI loader revisions."""
import unittest

from compare_rubi_loaders import parse_loader, compare_loaders


class LoaderComparisonTests(unittest.TestCase):
    def test_literal_and_filenamejoin_with_conditions(self):
        source = '''
Unprotect[Int];
LoadRules[$utilityPackage];
LoadRules["A/one"];
If[$LoadElementaryFunctionRules === True,
  LoadRules[FileNameJoin[{"B", "two"}]];
];
$RuleCount = Length[DownValues[Int]];
'''
        files = parse_loader(source)
        self.assertEqual([f['source'] for f in files], ['A/one', 'B/two'])
        self.assertFalse(files[0]['conditional_on_elementary'])
        self.assertTrue(files[1]['conditional_on_elementary'])

    def test_comparison_distinguishes_membership_and_order(self):
        old = [{'source': s} for s in ['A', 'B', 'C']]
        new = [{'source': s} for s in ['B', 'A', 'D']]
        report = compare_loaders(old, new)
        self.assertEqual(report['only_old'], ['C'])
        self.assertEqual(report['only_new'], ['D'])
        self.assertFalse(report['shared_relative_order_equal'])
        self.assertEqual(report['shared_files'], 2)

    def test_unknown_load_call_fails_closed(self):
        source = '''Unprotect[Int];
If[$LoadElementaryFunctionRules === True,
LoadRules[computed];
];
$RuleCount = Length[DownValues[Int]];'''
        with self.assertRaises(ValueError):
            parse_loader(source)


if __name__ == '__main__':
    unittest.main()
