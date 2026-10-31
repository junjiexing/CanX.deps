# SPDX-License-Identifier: GPL-3.0-or-later
#
# Package one Windows dependency build into
# artifacts/deps/canx-deps-windows-<arch>.tar.gz. The tarball mirrors the
# CanX .cache/windows-msvc[-<arch>] layout:
#   prefix/                                  aria2, mpv, libplacebo, zimg, lua
#   build/aria2-shim/Release/                canx_aria2.lib
#   build/quickjs-shim/Release/              canx_quickjs.lib
#   vcpkg-installed/<arch>-windows-static/   lib + include
#   vcpkg-installed/x64-windows/bin/         vulkan-1.dll (host audit loader)

[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string] $Architecture = 'x64',
    [string] $CacheRoot,
    [string] $Dist
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($CacheRoot)) {
    $cacheName = if ($Architecture -eq 'x64') { 'windows-msvc' } else { "windows-msvc-$Architecture" }
    $CacheRoot = Join-Path $repositoryRoot ".cache\$cacheName"
}
elseif (-not [IO.Path]::IsPathRooted($CacheRoot)) {
    $CacheRoot = Join-Path $repositoryRoot $CacheRoot
}
$CacheRoot = [IO.Path]::GetFullPath($CacheRoot)
if ([string]::IsNullOrWhiteSpace($Dist)) {
    $Dist = Join-Path $repositoryRoot 'artifacts\deps'
}
elseif (-not [IO.Path]::IsPathRooted($Dist)) {
    $Dist = Join-Path $repositoryRoot $Dist
}

$triplet = "$Architecture-windows-static"
$expected = @(
    (Join-Path $CacheRoot 'prefix\aria2\lib\aria2.lib'),
    (Join-Path $CacheRoot 'prefix\mpv\lib\libmpv.a'),
    (Join-Path $CacheRoot 'prefix\libplacebo\lib\libplacebo.a'),
    (Join-Path $CacheRoot 'prefix\zimg\lib\z.lib'),
    (Join-Path $CacheRoot 'build\aria2-shim\Release\canx_aria2.lib'),
    (Join-Path $CacheRoot 'build\quickjs-shim\Release\canx_quickjs.lib'),
    (Join-Path $CacheRoot "vcpkg-installed\$triplet\lib"),
    (Join-Path $CacheRoot 'vcpkg-installed\x64-windows\bin\vulkan-1.dll'))
$missing = @($expected | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing.Count -ne 0) {
    throw "Windows dependency build output is missing:`n$($missing -join "`n")"
}

$staging = Join-Path $CacheRoot 'deps-staging'
if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Force -Path `
    (Join-Path $staging 'prefix'), `
    (Join-Path $staging 'build\aria2-shim'), `
    (Join-Path $staging 'build\quickjs-shim'), `
    (Join-Path $staging 'vcpkg-installed\x64-windows\bin') | Out-Null
Copy-Item -LiteralPath (Join-Path $CacheRoot 'prefix') -Destination $staging -Recurse -Force
Copy-Item -LiteralPath (Join-Path $CacheRoot 'build\aria2-shim\Release') `
    -Destination (Join-Path $staging 'build\aria2-shim') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $CacheRoot 'build\quickjs-shim\Release') `
    -Destination (Join-Path $staging 'build\quickjs-shim') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $CacheRoot "vcpkg-installed\$triplet") `
    -Destination (Join-Path $staging 'vcpkg-installed') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $CacheRoot 'vcpkg-installed\x64-windows\bin\vulkan-1.dll') `
    -Destination (Join-Path $staging 'vcpkg-installed\x64-windows\bin') -Force

New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$archive = Join-Path $Dist "canx-deps-windows-$Architecture.tar.gz"
if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive -Force
}
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
& $tar -czf $archive -C $staging prefix build vcpkg-installed
if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
Remove-Item -LiteralPath $staging -Recurse -Force

"CANX_DEPS_PACKAGE_OK package=$archive"
