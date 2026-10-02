# Platforms, build routes and deployment

The same API and TLS implementation are used across targets. Windows socket,
error and clock handling are isolated from the POSIX implementation. There is
no x86-specific assembly in the wrapper and no assumption that a socket handle
fits a BlitzMax Int.

`tools/targets.json` describes **27 target variants**. `openssl.bmx` contains
generated dependency-directory selection for all 27. A selector test also checks
four NG Android architecture aliases. **Two variants have runtime validation.**
The others are deliberately available as experimental build/port paths, not
excluded merely because this workstation cannot run them.

| Target family | Variants | Available implementation/build route | Validation |
| --- | --- | --- | --- |
| Windows | x64, x86 | MinGW helper; separate headers/import libraries/DLLs per target | x64 debug/release passed; x86 experimental |
| Windows ARM | ARM64, ARMv7 | Same Windows bridge; local dependency selection; official OpenSSL VC ARM targets plus compatible NG import libraries | Manual integration, untested |
| Linux | x64, x86, ARM32, ARM64, RISC-V32, RISC-V64 | System package by default; optional local native/cross build recipes | x64 debug/release passed; remaining variants experimental |
| Raspberry Pi Linux | ARM32, ARM64 | System package or explicit local build recipe | Experimental |
| macOS | Intel x64, Apple Silicon ARM64 | pkg-config by default; optional local native build recipes | Experimental |
| Haiku | x86, x64 | pkg-config or local OpenSSL Haiku build recipe; POSIX bridge, BRL's network linkage | Experimental |
| Android | ARMv7, ARM64, x86, x64, RISC-V64 | Per-ABI static/PIC OpenSSL build recipes and module selection | Experimental; RISC-V needs a suitable experimental NDK |
| iOS device | ARM64, ARMv7 | Per-SDK static OpenSSL recipes and module selection | Experimental; ARMv7 requires an older compatible SDK |
| iOS simulator | x64, ARM64, x86 | Separate simulator libraries and module selection | Experimental; x86 requires an older compatible SDK |
| Switch homebrew | ARM64 (`nx`) | Explicit local dependency hook and the POSIX-style socket bridge | A maintained OpenSSL/libnx port is still required; not a completed Switch TLS port |

Browser/WebAssembly and bare-metal `embedded` targets fail compilation with an
explicit transport requirement. Browser raw TCP is unavailable; bare-metal
OpenSSL needs platform entropy, threading, time and transport integration.
Weakening randomness or certificate checks is not an acceptable portability fix.
Existing NG TLS backends may be more appropriate for those environments.

## Default and local dependency selection

There is **one distribution archive**, `net-openssl-0.1.3.zip`, containing
`openssl.mod/`. Install that directory in `BlitzMax/mod/net.mod/` on every target.
The archive includes Windows x64 native dependencies; Linux uses distribution
packages and macOS/Haiku use their development installations. The remaining
experimental routes still require the dependencies described below. Listing a
route does not mean it has bundled native libraries or has been compiled.
Future target libraries belong inside this same module package, not separate
platform-specific module downloads.

Windows always uses `deps/win32.ARCH`. Android/iOS always use their corresponding
`deps/TARGET` directory. The Switch hook uses `deps/nx.arm64`.

Linux and Raspberry Pi use normal system development/runtime libraries by
default. macOS and Haiku use `pkg-config` to locate their system/development
OpenSSL installation. For a deliberately local desktop dependency, build it
under `deps/TARGET` and compile the application with `-ud openssl_local`.

The generated rules account for NG's overlapping conditions: `linux` also
matches Android/Pi, `macos` also matches iOS, and legacy `arm64v8a` also matches
`arm`. These overlaps must not select desktop or 32-bit libraries for a mobile
64-bit build. `tests/platform_selection.py` checks those cases.

## Build helpers

All source recipes pin OpenSSL 3.5.8 and verify the official archive's SHA-256.
They use one make worker and install into the module, not system directories.
They require the appropriate SDK/compiler; they do not download entire SDKs or
claim to make arbitrary host/target combinations interchangeable.

Windows x64/x86, from the matching MinGW-w64 MSYS2 shell:

```sh
bash tools/build-openssl.sh /absolute/path/to/build-work
```

Other native or cross targets, with Python 3.12+, Perl, make and the target tools:

```sh
python3 tools/build-openssl.py --list
python3 tools/build-openssl.py --target android.arm64 --work /tmp/ng-tls-build --ndk /path/to/ndk --api 21 --plan
python3 tools/build-openssl.py --target android.arm64 --work /tmp/ng-tls-build --ndk /path/to/ndk --api 21
python3 tools/build-openssl.py --target ios.arm64 --work /tmp/ng-tls-build
python3 tools/build-openssl.py --target macos.arm64 --work /tmp/ng-tls-build
python3 tools/build-openssl.py --target linux.arm64 --work /tmp/ng-tls-build --cross-prefix aarch64-linux-gnu-
```

`--plan` only prints the build plan. Without it, the helper downloads/verifies
source and builds the libraries. Native builds need no cross-prefix. Set `CC`,
`AR`, `RANLIB` or the SDK environment as needed for a particular toolchain. The
Linux cross compiler needs the matching sysroot and libc. Android's Configure
selects its own compiler prefix from the NDK; do not pass a desktop cross-prefix.
Its API level must match the application's deployment contract.

Mobile recipes produce static, position-independent libraries with dynamic
provider/engine loading disabled. Link them into the NG application's native
binary; they do not require shipping desktop DLLs. Keep OpenSSL's license in the
application distribution. Rebuild/redeploy static applications for OpenSSL fixes.
Android applications also need their ordinary manifest/networking permissions.

Apple builds require macOS and the matching Xcode SDK. For ARM64 iOS simulator
libraries, select `ios.simulator.arm64` in the helper and compile the module with
`-ud openssl_ios_simulator`. This flag only selects dependency libraries: the NG
toolchain must also compile/link *all* application modules for the simulator SDK.
The inspected bmk has a default iOS device target setting, so that compiler/SDK
configuration needs particular attention. Device ARM64 archives cannot be reused
as simulator ARM64 archives merely because the CPU architecture is the same.

ARMv7 iOS, x86 iOS simulator and old Android `armeabi` aliases do not restore
support removed from modern SDKs. The Android ARM route builds current ARMv7 ABI
libraries; ARMv5 devices need a distinct older/custom toolchain effort.

## Manual Windows ARM and Switch routes

OpenSSL 3.5.8 supplies `VC-WIN64-ARM` and `VC-WIN32-ARM` configurations. Build with
the corresponding Microsoft/Clang developer environment. Stage public headers
and matching DLLs in `deps/win32.arm64` or `deps/win32.armv7`. The NG MinGW-style
link path expects GNU `libssl.dll.a` and `libcrypto.dll.a` import archives, so
generate compatible import libraries with the target's DLL tools; MSVC `.lib`
files are not simply interchangeable. The native ABI and runtime still need
testing on an actual ARM target. The automated MinGW helper covers x86/x64 only.

Switch has a module dependency directory hook, but no pretend generic-Linux
OpenSSL build recipe. A libnx-compatible port must supply OS entropy, monotonic
time, sockets, threads and secure configuration correctly. Put its public
headers and libraries in `deps/nx.arm64` before attempting the module build.
Do not bypass native RNG or verification errors to make it compile/run.

## Shipping applications

**Windows:** `tools/deploy-windows.ps1 -Executable /path/app.exe` reads the PE
architecture and deploys the matching DLLs and license beside the executable.
The supplied x64 DLL imports were inspected: they use only normal Windows
system libraries besides the other OpenSSL DLL. Compiler runtime DLLs are not
required by these application binaries.

**Linux:** declare a dependency on the distribution's OpenSSL runtime package.
The development package is needed only to compile. Use the distribution's actual
package name and version constraints so security fixes arrive through its normal
updates. The module ZIP contains no Linux shared libraries.

**macOS:** development can use pkg-config. A distributable app usually needs its
matching dylibs embedded/relinked/signed or an explicit managed dependency. That
application-bundle deployment remains unvalidated here.

The included Windows x64 dependency uses shared OpenSSL. Static desktop linkage is not a
tested mode of this release. Mobile static recipes are explicit and experimental.
Removing the DLLs from an existing Windows shared build does not make it static.

## Sources and maintenance

Target names and build constraints were checked against the official OpenSSL
3.5.8 `Configurations/10-main.conf`, `15-android.conf`, `15-ios.conf`,
`50-haiku.conf`, `50-win-onecore.conf`, `NOTES-ANDROID.md` and `NOTES-WINDOWS.md`.
Haiku's [socket header](https://github.com/haiku/haiku/blob/master/headers/posix/sys/socket.h)
provides the per-send `MSG_NOSIGNAL` behavior used by the bridge.

Edit `tools/targets.json`, then run `tools/generate-platforms.py` when adding a
variant. Regenerate and check the selector test before submitting a port. Reuse
the independent-peer integration suite on new targets and record the SDK,
compiler, OpenSSL version and actual runtime result separately from compilation.
