# From Sub.LibSSL 1.1 to Net.OpenSSL

The original ZIP is retained outside this module. Its wrapper and examples were
read as historical source; no executable from the archive was run, and no
example private keys were copied into the replacement.

The archive's OpenSSL header identifies **1.1.0e (16 February 2017)**. "libssl 1.1"
is also the wrapper's version; these are separate version numbers.

## Why a rewrite was justified

These are source-review findings, not claims that a particular released program
was exploited:

| Original issue | Replacement design |
| --- | --- |
| Client verification mode is not enabled; certificate status checked before handshake; no hostname validation | Verification configured before handshake; OpenSSL checks chain and DNS/IP identity during handshake |
| Global socket and certificate-password state inside the wrapper type | Immutable contexts and independent connection/socket ownership |
| Native protocol-selection switches fall through their cases | Modern generic TLS methods with a minimum protocol version |
| Windows socket handles passed through 32-bit integer APIs | A custom BIO carries the full native socket handle |
| Write helpers ignore short writes/failures | Real byte counts, exact-count loops and bounded deadlines |
| Reads infer message completion from TLS/socket behavior | Ordinary stream semantics plus explicit optional framing |
| UTF-8 data sent with UTF-16 character counts and C-string termination | Explicit UTF-8 byte lengths; NUL-safe text frames |
| Native allocations and SSL objects have incomplete cleanup | Deterministic close paths and explicit OpenSSL reference ownership |
| Password callback does not honor the supplied destination capacity | Bounded callback, per-construction userdata, no interactive fallback |
| Native file-time helper returns a pointer to a stack array | Unrelated filesystem helpers omitted |
| A native SSL helper returns an uninitialized pointer | Checked constructors and allocation failures |

## API migration

| Old approach | New approach |
| --- | --- |
| `SSL_CTX.Create`, `Context`, then mutable identity/CA setup | `TOpenSSLContext.CreateClient` or `CreateServer` with complete configuration |
| `CAFile`, then `CAVerify` | Supply trusted CA locations to context creation; handshake must succeed |
| `SSLConnect(host, port)` | `TOpenSSLStream.Connect(context, host, port)` |
| `Bind`, `Accept` on the same SSL object | `TOpenSSLListener.Bind`, then a new stream from each `Accept` |
| Shared global socket | Each stream owns one connected BRL socket |
| `WriteBytes` / `ReadBytes` | Standard BRL exact-count pointer operations, or bounded byte-array frames |
| Old null-terminated `WriteString` / `ReadString` | Agreed application framing, e.g. `WriteText` / `ReadText` |
| `SendFile` / `RecieveFile` | An explicit file-transfer protocol over `ReadBytes` / `WriteBytes`; bound sizes and validate destinations at that layer |
| `Shutdown` / `Close` | `Shutdown` for orderly TLS closure; `Close` for immediate resource release |

This is intentionally not a binary or wire-compatible replacement. Both ends
must agree on application framing. Do not silently reinterpret old file or
string traffic as the new length-prefixed format. Applications already using a
defined protocol can use the raw byte-stream interface unchanged at that layer.

The original legacy code must not be submitted to bmx-ng. Any later upstream
proposal would contain the freshly written NG module and its own tests/docs.
