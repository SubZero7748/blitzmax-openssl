# Contributing to Net.OpenSSL

Bug fixes, documentation improvements, examples, and verified platform support
are welcome. For larger API changes, open an issue first to discuss the design.

## Pull requests

1. Fork this repository and create a branch for your change.
2. Keep changes focused on `openssl.mod` and its supporting documentation.
   Preserve the module directory layout and existing licensing notices.
3. Install your edited `openssl.mod` under `BlitzMax/mod/net.mod/` and provide
   the native dependencies described in the [README](README.md#git-checkout).
   If your Git checkout is elsewhere, sync your edits to that installed copy
   before building. Use the corresponding installation's `bmk` and MaxIDE.
4. Run checks appropriate to the change and record the results in your PR.
   State the OS, CPU architecture, BlitzMax-NG version, OpenSSL version, and
   debug/release configuration. Clearly label untested targets.
5. Open a pull request against this repository's `main` branch.

Keep native dependencies, compiled outputs, archives, and generated test keys
out of commits. The release download is one cross-platform module ZIP hosted
on Subsoft.net; repository changes remain ordinary source files.

## Tests

Run these commands from the installed `openssl.mod` directory. `bmk` must be
on PATH. Use a Python 3 environment with `cryptography` installed for the
integration suite. Keep that environment outside the source tree or in `.venv/`.

Check platform routing:

```text
python tests/platform_selection.py
```

For code changes, build the integration driver in both configurations:

```text
bmk makeapp -single -g x64 -t console -o tests/driver-debug tests/driver.bmx
bmk makeapp -single -r -g x64 -t console -o tests/driver-release tests/driver.bmx
```

Use the architecture you are testing instead of `x64`. On Windows, `bmk` adds
`.exe` to the output names. Deploy the matching DLLs beside both executables:

```powershell
./tools/deploy-windows.ps1 -Executable ./tests/driver-debug.exe
./tools/deploy-windows.ps1 -Executable ./tests/driver-release.exe
```

Run the suite separately for each executable:

```text
python tests/integration.py tests/driver-debug tests/results/debug
python tests/integration.py tests/driver-release tests/results/release
```

On Windows, use `tests/driver-debug.exe` and `tests/driver-release.exe` in those
two commands. Results and temporary certificate fixtures stay in the ignored
`tests/results/` directory. The suite uses independent Python TLS peers on
loopback and generates fresh test certificates; never reuse those keys.

Changes affecting the public API should also compile and exercise the
[client/server examples](openssl.mod/examples/README.md). See the
[validation record](openssl.mod/VALIDATION.md) for native lifecycle and sanitizer
coverage and its limitations. Documentation-only changes do not require a full
TLS test run; check affected links and command examples.

## Reporting problems

For ordinary bugs, open an issue with a minimal example, exact error output,
and the toolchain/platform details above. Remove credentials and private keys
from logs before posting. For a suspected vulnerability, use GitHub's private
**Report a vulnerability** option in this repository's Security tab.
