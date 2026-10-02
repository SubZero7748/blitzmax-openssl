# Try the client and server

The examples follow the small `SuperStrict`, `Framework BRL.StandardIO`,
`Import Module.Name` pattern used by existing NG module examples. Each is a
standalone source file. They exchange UTF-8 messages over TLS on loopback.

1. Install the module and its platform dependency as described in the main README.
2. Build both programs:

   ```text
   bmk makeapp -r -t console examples/server.bmx
   bmk makeapp -r -t console examples/client.bmx
   ```

3. On Windows, deploy the bundled runtime beside each executable:

   ```powershell
   ./tools/deploy-windows.ps1 -Executable ./examples/server.exe
   ./tools/deploy-windows.ps1 -Executable ./examples/client.exe
   ```

   On Linux, use the system OpenSSL runtime package.

4. Supply your own server certificate/key and trusted CA bundle. For a disposable
   **local-only demonstration**, create a short-lived self-signed certificate
   in the ignored `examples/test-certs` directory using an OpenSSL 3 CLI:

   ```text
   openssl req -config /absolute/path/to/examples/test-cert.cnf -x509 -newkey rsa:2048 -sha256 -days 2 -noenc -keyout server.key -out server.pem
   ```

   Run that command from `examples/test-certs` after creating the directory.
   The module ZIP includes the Windows x64 CLI at `deps/win32.x64/bin/openssl.exe`. The supplied
   configuration contains only public localhost names, never private keys. The test key is
   unencrypted: keep the directory private and never commit or deploy that key.

5. Start the server, then the client in a second terminal. Use **absolute paths**
   for certificate/key files: NG applications can start with their executable's
   directory as the working directory.

   ```text
   server /absolute/path/server.pem /absolute/path/server.key 8443
   client /absolute/path/server.pem localhost 8443
   ```

   On Windows use the `.exe` suffix; on Unix use `./server` and `./client`.
   In this disposable demonstration the generated self-signed certificate is
   deliberately supplied as the trust anchor. Real deployments use their
   provisioned certificate chain and trusted CA bundle.

The server prints its loopback listening address and serves one connection.
The client prints the TLS version/cipher, sends a message and prints the echo.
Both programs close their resources even when an operation throws.

`WriteText`/`ReadText` use this module's optional length-prefixed framing; both
examples agree to it. To implement another protocol, use the same TLS stream's
`Read`, `Write`, `ReadBytes` and `WriteBytes` methods with that protocol's framing.
The examples do not implement HTTP and do not restrict TLS to web traffic.
