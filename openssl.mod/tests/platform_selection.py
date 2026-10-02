# SPDX-License-Identifier: MIT
"""Check target selection including NG's inherited platform/architecture flags.
This checks routing, not SDK availability, C compilation or target execution.
"""
import ast
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
targets = json.loads((ROOT / 'tools/targets.json').read_text())['targets']


def matches(expression, flags):
    tree = ast.parse(expression.replace(' And ', ' and ').replace(' Or ', ' or ')
                     .replace('Not ', 'not '), mode='eval')

    def visit(node):
        if isinstance(node, ast.Expression):
            return visit(node.body)
        if isinstance(node, ast.Name):
            return node.id in flags
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            return not visit(node.operand)
        if isinstance(node, ast.BoolOp):
            if isinstance(node.op, ast.And):
                return all(visit(value) for value in node.values)
            if isinstance(node.op, ast.Or):
                return any(visit(value) for value in node.values)
        raise AssertionError('Unexpected condition syntax')
    return visit(tree)


def check(target_id, architecture=None):
    parts = target_id.split('.')
    system = parts[0]
    arch = architecture or parts[-1]
    flags = {system, arch}
    if system in ('android', 'raspberrypi'):
        flags.add('linux')
    if system == 'ios':
        flags.add('macos')
    if 'simulator' in parts:
        flags.add('openssl_ios_simulator')
    if arch in ('armeabi', 'armeabiv7a', 'arm64v8a'):
        flags.add('arm')
    selected = [t['id'] for t in targets if matches(t['condition'], flags)]
    assert selected == [target_id], (target_id, arch, selected)


for target in targets:
    check(target['id'])
for target_id, alias in [('android.armv7', 'arm'), ('android.armv7', 'armeabi'),
                         ('android.armv7', 'armeabiv7a'), ('android.arm64', 'arm64v8a')]:
    check(target_id, alias)
print(f'{len(targets)} targets and 4 NG architecture aliases select exactly one dependency directory.')
