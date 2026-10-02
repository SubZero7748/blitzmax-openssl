# Net.OpenSSL for BlitzMax-NG

OpenSSL 3 TLS-over-TCP streams for BlitzMax-NG, integrated with `BRL.Socket`
and `BRL.Stream`. Version **0.1.3** supports verified clients, servers,
mutual TLS, and upgrades of existing TCP connections (including STARTTLS).
Clients verify the certificate chain and DNS/IP identity; TLS 1.2 is the minimum.

This repository contains the `openssl.mod` module, its examples, tests,
documentation, and build tools. Community pull requests and platform testing
are welcome. It is an independent community project using the `Net.OpenSSL`
namespace; it has not been accepted into the upstream bmx-ng distribution.

## Install

Place the **`openssl.mod` directory** inside your BlitzMax-NG installation:

```text
BlitzMax/
  mod/
    net.mod/
      openssl.mod/
        openssl.bmx
        glue.c
        examples/
        tests/
        tools/
```

Use the installation belonging to the MaxIDE or `bmk` you actually launch.
Compile an application containing `Import Net.OpenSSL`, or start with the
[client and server examples](openssl.mod/examples/README.md).

### Release package

The [Subsoft.net download](https://subsoft.net/download/24) is the single
cross-platform **net-openssl-0.1.3.zip** package. It includes matching Windows
x64 OpenSSL headers, import libraries and DLLs under `openssl.mod/deps/win32.x64`.
Extract `openssl.mod` into `BlitzMax/mod/net.mod`.

### Git checkout

Git contains source and build helpers. Native dependencies, generated files and
release ZIPs are not committed. GitHub's automatic source ZIP likewise contains
only the repository files; it is not the packaged Subsoft.net release.

* **Windows x64:** build the dependency with
  [tools/build-openssl.sh](openssl.mod/tools/build-openssl.sh), or copy the
  `openssl.mod/deps/win32.x64` directory from the matching Subsoft.net package
  into your installed module. The [Windows instructions](openssl.mod/README.md#windows-x64)
  also cover deploying the DLLs beside your executable.
* **Linux:** install your distribution's OpenSSL 3 development package
  (`libssl-dev` on Debian/Ubuntu), then build normally.
* **Other targets:** follow [PLATFORMS.md](openssl.mod/PLATFORMS.md) for native
  dependencies, SDKs, and experimental build routes.

From the installed `openssl.mod` directory, with `bmk` on PATH:

```text
bmk makeapp -single -r -g x64 -t console examples/client.bmx
bmk makeapp -single -r -g x64 -t console examples/server.bmx
```

Use your target architecture in place of `x64` when appropriate.

## Documentation and contributions

* [Module API, installation and security contract](openssl.mod/README.md)
* [Client/server walkthrough](openssl.mod/examples/README.md)
* [Platform support and build routes](openssl.mod/PLATFORMS.md)
* [Validation results and limitations](openssl.mod/VALIDATION.md)
* [Migration from the original Sub.LibSSL API](openssl.mod/MIGRATION.md)
* [Contributing and running tests](CONTRIBUTING.md)

Windows and Linux x64 have recorded debug/release runtime validation, with
30 integration cases passing on each. Other target routes remain experimental;
the platform guide distinguishes configuration checks from real target tests.

## License

[MIT](LICENSE). The module's copyright notice is in
[openssl.mod/openssl.bmx](openssl.mod/openssl.bmx). OpenSSL is a separate
dependency under the Apache License 2.0 and retains its own notices.
