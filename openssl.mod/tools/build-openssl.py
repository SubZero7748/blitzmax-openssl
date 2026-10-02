# SPDX-License-Identifier: MIT
"""Build a pinned native/cross OpenSSL dependency, one worker, no system installs.

For Windows x86/x64 use build-openssl.sh in MSYS2. Manual targets need a port or
import-library conversion. --plan prints commands without building/downloading.
Requires Python with tarfile's data extraction filter (3.12+ recommended).
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
CATALOG = json.loads((ROOT / 'tools/targets.json').read_text())
VERSION = CATALOG['opensslVersion']
SHA = 'a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2'
URL = f'https://github.com/openssl/openssl/releases/download/openssl-{VERSION}/openssl-{VERSION}.tar.gz'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--target', choices=[t['id'] for t in CATALOG['targets']])
    parser.add_argument('--work', type=Path)
    parser.add_argument('--plan', action='store_true')
    parser.add_argument('--ndk', type=Path, help='Android NDK root')
    parser.add_argument('--api', type=int, default=21, help='Android API level; must not exceed app minSdk')
    parser.add_argument('--cross-prefix', help='Desktop cross-compiler prefix, e.g. aarch64-linux-gnu-')
    args = parser.parse_args()
    if args.list:
        for target in CATALOG['targets']:
            status = 'tested' if target['tested'] else 'experimental'
            print(f"{target['id']:24} {str(target['openssl']):28} {target['kind']:8} {status}")
        return
    if not args.target or not args.work:
        parser.error('--target and --work are required for plans/builds')
    target = next(t for t in CATALOG['targets'] if t['id'] == args.target)
    if target['kind'] in ('windows', 'manual'):
        parser.error('Use the Windows helper or the manual port instructions in PLATFORMS.md for this target')
    if args.api < 21:
        parser.error('This helper supports Android API 21 and later')
    mobile = target['kind'] == 'mobile'
    dependency = ROOT / 'deps' / args.target
    work = args.work.resolve()
    source = work / args.target / ('openssl-' + VERSION)
    configure = ['perl', './Configure', target['openssl'], 'no-tests', 'no-docs',
                 '--libdir=lib', '--prefix=' + str(dependency), '--openssldir=' + str(dependency / 'ssl')]
    configure += ['no-shared', 'no-module', 'no-engine', 'no-dso', '-fPIC'] if mobile else ['shared']
    env = os.environ.copy()
    if args.target.startswith('android.'):
        if args.cross_prefix:
            parser.error('Android Configure selects its compiler prefix from the NDK; do not pass --cross-prefix')
        configure.append('-D__ANDROID_API__=' + str(args.api))
        ndk = args.ndk or (Path(env['ANDROID_NDK_ROOT']) if 'ANDROID_NDK_ROOT' in env else None)
        if ndk:
            ndk = ndk.resolve()
            host = {'Linux': 'linux-x86_64', 'Darwin': 'darwin-x86_64', 'Windows': 'windows-x86_64'}[platform.system()]
            ndk_bin = ndk / 'toolchains/llvm/prebuilt' / host / 'bin'
            env['ANDROID_NDK_ROOT'] = str(ndk)
            env['PATH'] = str(ndk_bin) + os.pathsep + env.get('PATH', '')
            if not args.plan and not ndk_bin.is_dir():
                parser.error('NDK LLVM tool directory does not exist: ' + str(ndk_bin))
        elif not args.plan:
            parser.error('Supply --ndk or ANDROID_NDK_ROOT for an Android build')
    elif args.cross_prefix:
        configure.append('--cross-compile-prefix=' + args.cross_prefix)
    if args.target.startswith(('macos.', 'ios.')) and platform.system() != 'Darwin' and not args.plan:
        parser.error('Apple targets require a macOS host with the matching Xcode SDK')
    make = env.get('MAKE', 'make')
    commands = [configure, [make, '-j1', 'build_libs'], [make, '-j1', 'install_dev']]
    plan = {'target': args.target, 'tested': target['tested'], 'source_url': URL, 'sha256': SHA,
            'source_directory': str(source), 'dependency_directory': str(dependency), 'commands': commands,
            'notes': 'Mobile libraries are static/PIC; desktop builds are shared. SDK/compiler must match the NG app.'}
    if args.plan:
        print(json.dumps(plan, indent=2))
        return
    if not hasattr(tarfile, 'data_filter'):
        parser.error('Upgrade Python to a version providing safe tar extraction (3.12+ recommended)')
    work.mkdir(parents=True, exist_ok=True)
    archive = work / ('openssl-' + VERSION + '.tar.gz')
    if not archive.exists():
        # Chunked transfer; no archive-sized allocation.
        with urllib.request.urlopen(URL, timeout=60) as response, archive.open('wb') as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)
    with archive.open('rb') as source_file:
        digest = hashlib.file_digest(source_file, 'sha256').hexdigest()
    if digest != SHA:
        raise RuntimeError('Archive checksum mismatch; source was not extracted')
    if not source.exists():
        source.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive) as package:
            for member in package:
                if member.name != 'openssl-' + VERSION and not member.name.startswith('openssl-' + VERSION + '/'):
                    raise RuntimeError('Unexpected archive root')
            package.extractall(source.parent, filter='data')
    dependency.mkdir(parents=True, exist_ok=True)
    for command in commands:
        print(subprocess.list2cmdline(command), flush=True)
        subprocess.run(command, cwd=source, env=env, check=True)
    shutil.copy2(source / 'LICENSE.txt', dependency / 'LICENSE-OpenSSL.txt')
    (dependency / 'PROVENANCE.json').write_text(json.dumps(plan, indent=2), encoding='utf-8')
    print('Installed target dependency:', dependency)


if __name__ == '__main__':
    main()
