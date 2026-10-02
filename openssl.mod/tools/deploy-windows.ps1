# SPDX-License-Identifier: MIT
param(
    [Parameter(Mandatory = $true)]
    [string] $Executable
)
$ErrorActionPreference = 'Stop'
$tlsExecutable = (Resolve-Path -LiteralPath $Executable).Path
$tlsReader = [IO.BinaryReader]::new([IO.File]::OpenRead($tlsExecutable))
try {
    if ($tlsReader.BaseStream.Length -lt 64 -or $tlsReader.ReadUInt16() -ne 0x5A4D) {
        throw 'The selected file is not a Windows PE executable.'
    }
    $tlsReader.BaseStream.Position = 0x3C
    $tlsHeaderOffset = $tlsReader.ReadUInt32()
    if ([long]$tlsHeaderOffset + 6 -gt $tlsReader.BaseStream.Length) { throw 'Invalid PE header offset.' }
    $tlsReader.BaseStream.Position = $tlsHeaderOffset
    if ($tlsReader.ReadUInt32() -ne 0x4550) { throw 'Invalid PE signature.' }
    $tlsMachine = $tlsReader.ReadUInt16()
} finally {
    $tlsReader.Dispose()
}
switch ($tlsMachine) {
    0x8664 { $tlsTarget = 'win32.x64'; $tlsDllNames = @('libssl-3-x64.dll', 'libcrypto-3-x64.dll') }
    0x014C { $tlsTarget = 'win32.x86'; $tlsDllNames = @('libssl-3.dll', 'libcrypto-3.dll') }
    0xAA64 { $tlsTarget = 'win32.arm64'; $tlsDllNames = @('libssl-3-arm64.dll', 'libcrypto-3-arm64.dll') }
    0x01C4 { $tlsTarget = 'win32.armv7'; $tlsDllNames = @('libssl-3-arm.dll', 'libcrypto-3-arm.dll') }
    default { throw ('No packaged runtime for PE machine 0x{0:X4}.' -f $tlsMachine) }
}
$tlsModule = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$tlsDependency = Join-Path $tlsModule "deps/$tlsTarget"
$tlsSources = @($tlsDllNames | ForEach-Object { Join-Path $tlsDependency "bin/$_" })
$tlsLicense = Join-Path $tlsDependency 'LICENSE-OpenSSL.txt'
foreach ($tlsSource in ($tlsSources + @($tlsLicense))) {
    if (-not (Test-Path -LiteralPath $tlsSource -PathType Leaf)) {
        throw "Missing dependency: $tlsSource. Stage this target's native libraries inside the module as described in PLATFORMS.md."
    }
}
$tlsDestination = [IO.Path]::GetDirectoryName($tlsExecutable)
foreach ($tlsSource in $tlsSources) {
    Copy-Item -LiteralPath $tlsSource -Destination $tlsDestination -Force
}
Copy-Item -LiteralPath $tlsLicense -Destination (Join-Path $tlsDestination 'LICENSE-OpenSSL.txt') -Force
Write-Output "Deployed OpenSSL runtime and license for $tlsTarget beside $tlsExecutable"
