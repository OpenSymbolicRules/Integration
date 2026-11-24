"""Check packaged source, exact conversion membership and original source order."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / 'converter/recovery'


class RecoveryTests(unittest.TestCase):
    def test_archive_and_default_profile(self):
        vendor = Path(os.environ.get('OSR_RUBI_ROOT', ROOT / 'vendor/Rubi'))
        paths = json.loads((ARCHIVE / 'files.json').read_text())
        manifest = json.loads((ROOT / 'rules/meta.json').read_text())
        self.assertEqual(paths, [p for p in manifest['load_order'] if p in set(paths)])
        self.assertEqual(len(set(paths)), 30)
        for path in paths:
            with self.subTest(path=path):
                record = json.loads((ARCHIVE / path).read_text())
                profile = json.loads((ROOT / 'rules' / path).read_text())
                self.assertEqual(record['revision'], manifest['converter']['source_commit'])
                self.assertEqual('rubi:' + record['source_path'][:-2], profile['identity'])
                rows = record['blocks']
                source = ''.join(r['source'] for r in rows).encode()
                self.assertEqual(hashlib.sha256(source).hexdigest(), record['source_sha256'])
                if (vendor / '.git').exists():
                    blob = record['revision'] + ':Rubi/IntegrationRules/' + record['source_path']
                    self.assertEqual(source, subprocess.check_output(['git', '-C', vendor, 'show', blob]))
                archived = [r['rule'] for r in rows if r['status'] == 'converted']
                ids = {r['id'] for r in archived}
                self.assertEqual([r for r in profile['rules'] if r['id'] in ids], archived)
                for row in rows:
                    if 'rule' in row:
                        self.assertEqual(row['ordinal'], row['rule']['id'])
                    if row['status'] == 'candidate':
                        self.assertTrue(row['required_heads'])
                    if row['status'] == 'source_only':
                        self.assertTrue(row['reason'])
                        self.assertEqual(row['source_ast']['head'], 'SetDelayed')


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--compare':
        generated = Path(sys.argv[2])
        for relative in json.loads((ARCHIVE / 'files.json').read_text()):
            for tree in ('converter/recovery',):
                path = Path(tree) / relative
                if json.loads((ROOT / path).read_text()) != json.loads((generated / path).read_text()):
                    sys.exit(f'Regeneration differs for {path}')
        del sys.argv[1:]
    unittest.main()
