"""Tests for the read-only source-definition coverage audit."""
import unittest
import os
from pathlib import Path

from audit_rubi_coverage import count_int_definitions, summarize_coverage, generate_report


class CoverageTests(unittest.TestCase):
    def test_counts_definitions_not_calls_strings_or_nested_comments(self):
        source = '''
        (* Int[ignored_, x_] := 0 (* Int[also_, x_] := 0 *) *)
        message = "Int[fake_, x_] := 4";
        Int[f[x_], x_Symbol] := Int[x, x] + 1;
        If[flag, Int[a_, x_] := 1, Int[b_, x_] := 2];
        Other[Int[x_,x_]] := 42;
        '''
        self.assertEqual(count_int_definitions(source), 3)

    def test_multiline_nested_patterns_and_unterminated_input(self):
        self.assertEqual(count_int_definitions('Int[\n f[x_[a_]],\n x_Symbol\n] := 1'), 1)
        with self.assertRaises(ValueError):
            count_int_definitions('Int[f[x_], x_Symbol := 1')
        with self.assertRaises(ValueError):
            count_int_definitions('Int[x_, x_] := 1 (* unclosed')

    def test_pinned_loader_source_when_available(self):
        root = Path(__file__).resolve().parent.parent
        vendor = Path(os.environ.get('OSR_RUBI_ROOT', root / 'vendor' / 'Rubi'))
        if not (vendor / 'Rubi' / 'Rubi.m').is_file():
            self.skipTest('RUBI submodule is not initialized')
        report = generate_report(vendor, root / 'rules')
        self.assertEqual(report['source_version'], '4.17.3.0')
        self.assertEqual(report['source_revision'], '61e9c18ea248061cd83c67882f7c91a73cef912d')
        self.assertEqual(report['loaded_files'], 198)
        self.assertEqual(report['summary']['source_definitions'], 7453)
        self.assertEqual(report['summary']['osr_entries'], sum(f['osr_entries'] for f in report['files']))
        self.assertTrue(any('1.4.1 Algebraic function simplification' in f['source'] for f in report['files']))

    def test_summary_never_calls_differences_missing_identities(self):
        rows = [dict(source_definitions=4, osr_entries=2),
                dict(source_definitions=2, osr_entries=5)]
        summary = summarize_coverage(rows)
        self.assertEqual(summary['source_definitions'], 6)
        self.assertEqual(summary['osr_entries'], 7)
        self.assertEqual(summary['files_with_fewer_entries'], 1)
        self.assertEqual(summary['files_with_more_entries'], 1)
        self.assertEqual(summary['net_entry_difference'], -1)
        self.assertNotIn('missing_rules', summary)


if __name__ == '__main__':
    unittest.main()
