# Net.OpenSSL

MIT · version 0.1.3

The distribution is one cross-platform module ZIP, with an
`openssl.mod/` root and native dependencies kept inside their target directories.

General TLS over TCP for BlitzMax-NG: clients, servers, mutual TLS, and upgrades
of existing TCP connections. This is a new implementation inspired by the
original `Sub.LibSSL` module. No legacy source, binaries, or example keys are
included in this module.

The mod belongs at `mod/net.mod/openssl.mod`, beside the other networking
backends. It uses `BRL.Socket`, `BRL.Stream`, and a small native OpenSSL bridge.
It does not modify the compiler, runtime, BRL, Net.MbedTLS, or libcurl.
`Net.OpenSSL` is a proposed local namespace, not a claim of upstream acceptance.

## What it provides

| API | Responsibility |
| --- | --- |
| `TOpenSSLContext.CreateClient(caFile, caPath, certFile, keyFile, password)` | Verified client configuration; optional client identity |
| `TOpenSSLContext.CreateServer(certFile, keyFile, password, caFile, caPath, requireClientCertificate)` | Server identity and optional mutual TLS |
| `TOpenSSLStream.Connect(context, host, port, timeoutMillis)` | TCP connection and verified TLS handshake |
| `TOpenSSLStream.Attach(context, socket, peerName, timeoutMillis)` | TLS on an existing, owned TCP socket, including STARTTLS |
| `TOpenSSLListener.Bind(context, port, host, backlog)` | Listener; defaults to loopback, supports ephemeral port zero |
| `listener.Accept(timeoutMillis, handshakeMillis)` | Independent TLS stream per accepted connection |
| `Read`, `Write`, `ReadBytes`, `WriteBytes` | Standard BRL byte-stream interface |
| `WriteFrame`, `ReadFrame`, `WriteText`, `ReadText` | Optional bounded application messages |
| `SetTimeout`, `Protocol`, `Cipher`, `Eof`, `Shutdown`, `Close` | Connection control and negotiated details |
| `OpenSSLVersion()` | Actual loaded library version |

The first release is synchronous. Sockets are nonblocking internally so a slow
peer cannot defeat an I/O deadline. It is not an event-loop API. Concurrent
servers can accept ordinary BRL TCP sockets, enforce their connection limit,
and dispatch each socket to a worker which calls `Attach` with a server context.

## Build

Download **`net-openssl-0.1.3.zip`** on every platform. Extract its `openssl.mod`
directory into **`BlitzMax/mod/net.mod/`**, beside modules such as `http.mod`
and `mbedtls.mod`. Create `net.mod` if it does not already exist. The result is
`BlitzMax/mod/net.mod/openssl.mod/openssl.bmx`; do not add an extra version folder.
The ZIP contains source, examples, tests, documentation, build helpers and
Windows x64 OpenSSL dependencies. BlitzMax selects the target internally.
There is no separate source or platform download.

Windows x64 is ready to compile after extraction. Linux uses its installed
OpenSSL 3 development package; macOS and Haiku use OpenSSL 3 plus `pkg-config`.
Other targets have experimental dependency recipes or manual port requirements
in [PLATFORMS.md](PLATFORMS.md). Their native libraries are not prebuilt in this
ZIP, so those routes are **not yet extract-and-compile targets**.

From `BlitzMax/mod/net.mod/openssl.mod`, with `bmk` on PATH:

```text
bmk makeapp -r -g x64 -t console examples/client.bmx
bmk makeapp -r -g x64 -t console examples/server.bmx
```

Use your installed toolchain's architecture when targeting another CPU.
`Import Net.OpenSSL` builds the module automatically as part of an application;
no separate module configuration or dependency build is needed on Windows x64
or on Linux with its development package installed.
Start with the [client/server walkthrough](examples/README.md) and its two
standalone `.bmx` example sources.

Requires current BlitzMax-NG and OpenSSL 3 development headers/libraries. This
mod selects **OpenSSL 3.5 LTS**, with 3.5.8 used for Windows validation.
Use maintained patch releases from the [OpenSSL project](https://openssl-library.org/source/).
OpenSSL 1.1 is deliberately unsupported.

### Windows x64

The module ZIP already includes matching MinGW-compatible OpenSSL headers,
import libraries and DLLs:

```
openssl.mod/deps/win32.x64/include/openssl/ssl.h
openssl.mod/deps/win32.x64/lib/libssl.dll.a
openssl.mod/deps/win32.x64/lib/libcrypto.dll.a
openssl.mod/deps/win32.x64/bin/libssl-3-x64.dll
openssl.mod/deps/win32.x64/bin/libcrypto-3-x64.dll
```

`tools/build-openssl.sh` builds a checksum-pinned official source archive using
MSYS2/MinGW, Perl, and one make worker. It selects x64 or x86 from the compiler
and places each architecture in its own directory. It records dependency provenance.
An existing compatible development installation can be staged in the same
layout. Never mix old 1.1 headers with 3.x libraries.

```
bmk makeapp -r -g x64 -t console examples/client.bmx
```

The same cross-platform ZIP includes these Windows files, provenance and the
OpenSSL license; other targets ignore the `deps/win32.x64` directory.
Deploy the DLLs beside the application executable with:

```powershell
./tools/deploy-windows.ps1 -Executable C:/path/to/your/app.exe
```

The helper checks the executable's architecture and copies the corresponding
DLLs and license. Do not depend on whichever DLL a user's current directory
happens to provide. This Windows build needs only the two OpenSSL DLLs beyond
normal Windows system libraries; it does not require `libwinpthread-1.dll` at
application runtime. That DLL belongs to the local compiler toolchain.

### Linux

Install the distribution's OpenSSL 3 development package (`libssl-dev` on
Debian/Ubuntu), then build normally. Standard compiler/linker search paths are
used. Deployed applications declare a dependency on the distribution's matching
OpenSSL runtime package. Do not copy the Windows DLLs or an arbitrary `.so` into
Linux packages. The validation harness also requires Python 3 and `cryptography`.

### macOS

The source uses POSIX sockets and `SO_NOSIGPIPE`. Build flags use
`pkg-config --cflags openssl` and `pkg-config --libs-only-L openssl`.
Provide OpenSSL 3 and pkg-config. **macOS is not validated in this workspace.**
See `PLATFORMS.md` for native desktop architectures and the remaining mobile and
embedded work. Build configuration is architecture-specific; x64 binaries must
never be reused as if they were x86 or ARM libraries.

## Security and ownership contract

* Clients always verify the trust chain and expected DNS name or numeric IP.
  DNS connections send SNI. Numeric IPs require matching IP subject alternative
  names; a DNS SAN alone does not suffice. Supply IDNA names as ASCII A-labels.
* TLS 1.2 is the minimum, and security level 2 is the minimum. Stronger configured
  OpenSSL settings are preserved. Renegotiation and TLS compression are disabled.
  Compatibility options which accept an abrupt EOF or unsafe legacy handshakes
  are explicitly cleared.
  There is no public "skip verification" switch or plaintext fallback.
* CA files are PEM bundles; CA directories use OpenSSL's hashed layout. Empty CA
  arguments select OpenSSL defaults. **This does not automatically import the
  Windows certificate store.** On Windows, supply a maintained CA bundle
  explicitly. Never silently trust the server's own presented certificate.
* Certificate revocation checking (CRL/OCSP), pinning, custom verification
  callbacks and application authorization are not implemented. Standard chain,
  validity, purpose and identity verification do not establish revocation status.
  Deployments requiring these features need further work before adoption.
* Server contexts load a certificate chain and its matching PEM key. Password
  handling never prompts interactively and checks buffer lengths. The temporary
  native UTF-8 password buffer is wiped; the caller's immutable BlitzMax String
  cannot be reliably erased by this module.
* `requireClientCertificate=True` requires a trusted client certificate. The
  application still decides what that authenticated client may do. Supplying
  client CA locations without the flag verifies certificates when presented but
  allows clients without one.
* A context is immutable after construction. Connections hold OpenSSL references
  to it, so context `Close()` does not invalidate live connections. A listener
  needs its context to remain open while accepting more connections.
* `Attach` requires an owning `TSocket`; ownership transfers after argument
  validation, including on handshake failure. The stream makes the socket
  nonblocking. Do not retain/use its raw socket for plaintext I/O or close it
  elsewhere. No bytes may remain in a separate plaintext read buffer at upgrade.
* Instances are not safe for simultaneous operations. Serialize operations on a
  stream. A context may be shared for creating connections, but do not race
  `Close` against its use. Use explicit `Close`; GC cleanup is only a fallback.
* Native socket handles retain their full width on 64-bit Windows. The BIO does
  not close the socket; the owning BRL socket closes it exactly once.

## Stream semantics and deadlines

TLS preserves a byte stream, not application messages. `Read` may return fewer
bytes than requested. `Write` reports its actual count. The exact byte methods
loop until the full count is transferred or throw. Raw pointer arguments must
refer to buffers of at least the requested size, as with other BRL streams.

All timeout arguments are positive milliseconds. The connect default is 10 s;
I/O is 30 s; orderly shutdown is 5 s. One deadline covers a whole exact byte
operation or frame, including partial transfers. Connection attempts and TLS
share a deadline **after** BRL's synchronous DNS lookup. DNS itself is not bounded
by this API; use a pre-resolved connected socket plus `Attach` where that matters.

`Accept` has separate accept and handshake deadlines. Accept timeout returns
Null; certificate/handshake failures throw. Its simple implementation handles
one handshake at a time, so production servers need their own admission limits
and worker scheduling to prevent one slow handshake delaying others.

Fatal TLS errors, I/O timeouts and malformed frames close that connection and
throw `TOpenSSLException`. Clean TLS `close_notify` makes `Read` return zero;
abrupt TCP EOF throws. `Eof` reports an observed close or a locally closed stream;
it does not probe the socket. Consuming an exact byte count that runs past clean
EOF also throws because the application message is incomplete.

`Shutdown` exchanges TLS close notifications and closes the connection even if
it fails. Consume outstanding application messages first; the peer must also
participate. `Close` releases resources immediately without a blocking handshake.
Calling it twice is harmless. A peer sees an abrupt EOF if `Close` is used without
an orderly shutdown.

Frames use a four-byte unsigned big-endian length, then exactly that many bytes.
The default maximum is 16 MiB. Incoming lengths are checked **before payload
allocation**. Empty frames are valid. Both peers must agree to this framing;
it is not compatible with the old module's implicit string/file boundaries.
UTF-8 text frames preserve embedded NUL characters. `ReadText` uses the runtime's
UTF-8 decoder; protocols requiring strict rejection of malformed UTF-8 should
validate the byte frame themselves. Inherited BRL string/line operations retain
their normal BRL semantics.

## Validation

Build `tests/driver.bmx` in debug and release mode, then run:

```
python tests/integration.py /absolute/path/to/driver /absolute/path/to/results
```

The suite creates fresh local test keys and certificates and uses Python TLS
peers on loopback. It covers valid and invalid authentication, TLS 1.2/1.3,
IPv4/IPv6, SNI, mutual TLS, a plaintext-to-TLS upgrade, fragmented binary and UTF-8
frames, size limits, deadlines, close notifications, independent connections and
context lifetime. Test keys belong only in the ignored results directory.

`tests/native_lifecycle.c` additionally supports AddressSanitizer,
UndefinedBehaviorSanitizer and LeakSanitizer on Linux. These tests do not
constitute an independent audit or prove that all vulnerabilities are absent.
See `VALIDATION.md` for the actual tested configurations and results.

The [platform guide](PLATFORMS.md) covers 27 target variants, including experimental
mobile and alternative desktop routes. Windows/Linux x64 have runtime validation;
the other entries state their remaining SDK or port requirements explicitly.

## Deliberate scope

No HTTPS parser, HTTP client, WebSocket protocol, UDP/DTLS, QUIC, ALPN selection,
certificate issuance toolkit, automatic file transfer protocol or timestamp
preservation is included. Those are separate layers or future additions.
Net.MbedTLS already supplies a general TLS backend; this module adds an OpenSSL
choice and BRL stream integration, rather than filling an alleged total absence
of TLS in NG. See `MIGRATION.md` for the legacy assessment and API mapping.
