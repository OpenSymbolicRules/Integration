"""Compare all loaded files and the manifest across formatting differences."""
import json
from pathlib import Path
import sys

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def check(generated, committed):
    paths = ['meta.json', *read(generated/'meta.json')['load_order']]
    for path in paths:
        if read(generated/path) != read(committed/path):
            raise ValueError(f'Changed integration profile: {path}')

if __name__ == '__main__':
    check(*(Path(p) for p in sys.argv[1:]))
