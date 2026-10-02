# Validation record — 30 September 2026

The module is distributed as one cross-platform ZIP rooted at `openssl.mod/`,
installed under `mod/net.mod/`. The implementation matches the code used for
the validation runs recorded below. Later documentation and source-header
cleanup did not change executable code.

The 0.1.3 package acceptance procedure extracts the **same ZIP** into separate
Windows and Linux module installations, builds the packaged test driver and
both examples, and runs the 30 integration cases on each release build. Windows
uses only the DLLs supplied inside the ZIP; Linux uses its distribution OpenSSL.
Archive integrity, every manifest entry and the single `openssl.mod/` root are
checked before extraction. The release workspace records the archive digest,
build logs and results under `validation/openssl/package-0.1.3/`.

This is a tested development candidate, not an independently audited production
release. No known failure remains in the final test matrix below. No legacy
executable, DLL, key or source implementation was used in the new module.

| Target | Native TLS dependency | Configuration | Integration result |
| --- | --- | --- | --- |
| Windows x64, BlitzMax-NG bcc 0.165, MinGW GCC 12.2.0 | OpenSSL 3.5.8 built locally from the official release | Debug | 30/30 passed |
| Same | Same | Release | 30/30 passed |
| Linux x64, Ubuntu 24.04 under WSL, existing NG validation toolchain | Distribution OpenSSL 3.0.13 | Debug | 30/30 passed |
| Same | Same | Release | 30/30 passed |

The Linux version string describes the installed distribution library; it is
not a recommendation to deploy an unpatched upstream 3.0.13 tarball. Use maintained
distribution packages or a supported upstream patch release.

Additional checks:

* The native bridge passes `-Wall -Wextra -Werror -fsyntax-only` on Windows and Linux.
* A native lifecycle harness passes AddressSanitizer, UndefinedBehaviorSanitizer
  and LeakSanitizer on Linux. It runs 100 cycles of independent connections,
  contexts closed before their connections, fatal invalid-socket handshakes,
  rejected encrypted-key passwords, successful key loading and cleanup.
* Both Windows client/server examples compile in release mode and exchange the
  expected message over TLS 1.3 using a fresh certificate generated from the
  supplied example configuration. The runtime check restricts PATH to Windows
  System32 and uses the two OpenSSL DLLs beside the executables.
* Dependency routing selects exactly one directory for each of 27 variants and
  four additional NG Android architecture aliases. Regeneration is unchanged.
  The Python helper produces valid dry-run plans for all 22 automated
  non-Windows recipes. These are configuration checks, not cross-build results.
* The portable MSYS build helper passes Bash syntax checking. It has not received
  a separate clean end-to-end run under MSYS2. The tested dependency build used
  the workspace's MinGW tools and Git Perl, supplemented locally with missing
  modules from the corresponding official Perl 5.38.2 source.
* Dependency builds used one make worker. There was no full BaH/NG ecosystem build.
* The original archives passed integrity and per-file SHA-256 manifest checks. The
  extracted Windows dependency headers compile the bridge with strict warnings;
  its deployment helper installs the packaged DLLs and an encrypted-key context
  smoke test passes with PATH restricted to Windows System32.

## Integration cases

The peers use Python's `ssl` module, rather than two endpoints which both depend
on the new wrapper. Certificate fixtures are freshly generated with Python
`cryptography` and remain outside the deliverable.

1. Missing CA file rejected.
2. Certificate/private-key mismatch rejected.
3. Correct password loads an encrypted private key.
4. Incorrect password rejected without an interactive prompt.
5. Embedded NUL in a security-sensitive path rejected.
6. TLS 1.2: fragmented binary/UTF-8 traffic, embedded NUL, repeated and empty frames.
7. TLS 1.3: the same transfer tests.
8. DNS identity verification and SNI; address fallback within a short deadline.
9. Plaintext STARTTLS negotiation followed by attaching the existing socket.
10. IPv6 connection and numeric IP identity verification.
11. Numeric IP rejected when only a DNS SAN is present.
12. Untrusted issuer rejected.
13. Expired certificate rejected.
14. Certificate with the wrong extended-key purpose rejected.
15. Wrong expected hostname rejected.
16. Client mutual TLS succeeds.
17. Server-required client identity absence rejected.
18. Stalled handshake times out.
19. Stalled read times out.
20. Backpressured write times out.
21. A 0xffffffff frame length is rejected before payload allocation.
22. Truncated frame/TCP connection rejected.
23. TLS close_notify recognized as authenticated EOF.
24. Abrupt TCP EOF rejected.
25. Two NG server connections remain independent; existing streams survive context closure.
26. NG server mutual TLS succeeds.
27. NG server rejects a missing required client certificate.
28. NG server rejects TLS 1.1.
29. Listener accept deadline returns Null.
30. Abrupt EOF remains an error with a configuration requesting OpenSSL's
    `IgnoreUnexpectedEOF` compatibility option.

## Problems found and corrected during validation

The Windows linker needed explicit import-library names because bmk's static
link option does not resolve the `.dll.a` libraries through plain `-lssl` here.
The module now names them explicitly through the MinGW linker.

The first Windows DNS/SNI run exposed starvation of later resolved addresses by
a slow first TCP attempt. TCP attempts now share the remaining deadline across
the remaining addresses; TLS keeps the overall deadline. The regression passes
in both final Windows builds.

A directly launched GCC warning check initially lacked MinGW's `bin` directory
in its process PATH, which produced a `libwinpthread-1.dll` loader dialog from
`cc1.exe`. The DLL was already installed. The stalled check was stopped, its
process environment corrected, and the warning check passed. The workspace
Windows validation script now sets that PATH explicitly. This was a validation
tool launch error, not a DLL required by the module API or a failed TLS test.

## Dependency provenance

OpenSSL source:
<https://github.com/openssl/openssl/releases/download/openssl-3.5.8/openssl-3.5.8.tar.gz>

SHA-256, checked against the official release checksum:

```
a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
```

Final locally built Windows DLL SHA-256 values:

```
libssl-3-x64.dll
b96c91b0901d67d4335b6a2750b11d68807e8cb36a7d5cf583da4428309e5dab

libcrypto-3-x64.dll
2ad686f2a96cff8de0317a24d976dbb756648128e99857583cb590f3476c8196
```

The compiled OpenSSL directory defaults were normalized to native Windows paths.
The local runtime DLLs and import libraries are in the ignored `deps/win32.x64`
directory. The single cross-platform module ZIP includes them, public headers,
the matching CLI, dependency provenance and the OpenSSL license. Linux uses its
system development/runtime package. The ZIP excludes generated private keys,
certificate fixtures, legacy source and legacy binaries.

## Limits and reproduction evidence

macOS, 32-bit, mobile and embedded targets are untested. The native sanitizers
instrumented the wrapper/lifecycle harness, not a separately rebuilt instrumented
OpenSSL distribution. There has been no long-running fuzz campaign, full upstream
OpenSSL test-suite run, independent security review or production load test.
Revocation and other deliberately unimplemented features are listed in README.md.

In the development workspace, full logs, JSON results, generated fixtures and
build scripts live under `validation/openssl/`. Final test outputs are
`windows-debug/results.json`, `windows-release/results.json`,
`linux/debug/results.json`, `linux/release/results.json`, and
`linux/sanitizers.log`. `test-windows.ps1` and `test-linux.sh` reproduce the module
checks with the configured local toolchains. `build.ps1` plus
`finalize-native-paths.ps1` record the local OpenSSL build procedure.
`delivery-checks.json` records the example run and helper checks;
`cross-build-plans.json` contains the unexecuted cross-target plans.
