# SPDX-License-Identifier: MIT
"""Regenerate the explicitly marked dependency-selection block only."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
targets = json.loads((root / 'tools/targets.json').read_text())['targets']
start = "' BEGIN GENERATED PLATFORM OPTIONS"
end = "' END GENERATED PLATFORM OPTIONS"
lines = [start]
for target in targets:
    condition = target['condition']
    if target['kind'] == 'desktop':
        condition = '(' + condition + ') And openssl_local'
    prefix = '%PWD%/deps/' + target['id']
    lines.extend(['?' + condition, 'ModuleInfo "CC_OPTS: -I' + prefix + '/include"',
                  'ModuleInfo "LD_OPTS: -L' + prefix + '/lib"'])
lines.extend(['?((macos And Not ios) Or haiku) And Not openssl_local',
              'ModuleInfo "CC_OPTS: `pkg-config --cflags openssl`"',
              'ModuleInfo "LD_OPTS: `pkg-config --libs-only-L openssl`"',
              '?emscripten Or embedded',
              'ModuleInfo "CC_OPTS: -DBMX_TLS_UNSUPPORTED_TRANSPORT"', '?', end])
path = root / 'openssl.bmx'
source = path.read_text(encoding='utf-8')
a = source.index(start)
b = source.index(end, a) + len(end)
path.write_text(source[:a] + '\n'.join(lines) + source[b:], encoding='utf-8')
print(f'Generated dependency selection for {len(targets)} target variants.')
