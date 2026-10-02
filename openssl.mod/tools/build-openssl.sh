#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Run from a MinGW-w64 MSYS2 shell with Perl, curl, tar, and make available.
# Usage: bash tools/build-openssl.sh /absolute/path/to/build-work
set -euo pipefail
module_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=${1:?Supply a separate build-work directory}
mkdir -p -- "$work"
work=$(cd -- "$work" && pwd)
case "$(gcc -dumpmachine)" in
    x86_64-w64-mingw32) openssl_target=mingw64; bmx_target=win32.x64 ;;
    i686-w64-mingw32) openssl_target=mingw; bmx_target=win32.x86 ;;
    *) echo 'This helper requires a MinGW-w64 x64 or x86 compiler.' >&2; exit 1 ;;
esac
command -v cygpath >/dev/null
command -v perl >/dev/null
make_command=${MAKE:-make}
command -v "$make_command" >/dev/null
version=3.5.8
sha=a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
archive="$work/openssl-$version.tar.gz"
url="https://github.com/openssl/openssl/releases/download/openssl-$version/openssl-$version.tar.gz"
if [ ! -f "$archive" ]; then
    curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "$url"
fi
printf '%s  %s\n' "$sha" "$archive" | sha256sum --check --status
source_root="$work/$bmx_target/openssl-$version"
if [ ! -d "$source_root" ]; then
    mkdir -p -- "$work/$bmx_target"
    tar -xzf "$archive" -C "$work/$bmx_target"
fi
prefix="$module_root/deps/$bmx_target"
mkdir -p -- "$prefix"
native_prefix=$(cygpath -m "$prefix")
cd -- "$source_root"
perl Configure "$openssl_target" shared no-tests no-docs --libdir=lib \
    "--prefix=$prefix" "--openssldir=$prefix/ssl"
# Installation uses MSYS paths; native DLL defaults must use Windows paths.
runtime_paths=("OPENSSLDIR=$native_prefix/ssl"
               "ENGINESDIR=$native_prefix/lib/engines-3"
               "MODULESDIR=$native_prefix/lib/ossl-modules")
"$make_command" -j1 "${runtime_paths[@]}"
"$make_command" -j1 "${runtime_paths[@]}" install_sw
cp LICENSE.txt "$prefix/LICENSE-OpenSSL.txt"
printf 'OpenSSL %s\nSource: %s\nSHA256: %s\nCompiler: %s\n' \
    "$version" "$url" "$sha" "$(gcc --version | head -n 1)" > "$prefix/PROVENANCE.txt"
"$prefix/bin/openssl.exe" version -a
