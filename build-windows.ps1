param(
    [string] $Godot = "godot"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$project = Join-Path $root "desktop"
$windows = Join-Path $root "Windows"
$dist = Join-Path $root "dist"
$output = Join-Path $windows "百谷长青.exe"
$pack = Join-Path $windows "百谷长青.pck"

New-Item -ItemType Directory -Force -Path $windows, $dist | Out-Null
$version = (& $Godot --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notlike "4.7.2.stable*") {
    throw "Use the standard Godot 4.7.2 executable and matching Windows export templates."
}
& $Godot --headless --path $project --editor --import
if ($LASTEXITCODE -ne 0) { throw "Godot project import failed." }
& $Godot --headless --path $project --export-release "Windows Desktop" $output
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $pack)) { throw "Windows export failed." }

$notices = Join-Path $windows "licenses"
New-Item -ItemType Directory -Force -Path $notices | Out-Null
foreach ($name in "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt") {
    Copy-Item -LiteralPath (Join-Path (Join-Path $root "licenses") $name) -Destination $notices -Force
}
$quickStart = Join-Path $windows "试玩说明.txt"
Copy-Item -LiteralPath (Join-Path $root "试玩说明.txt") -Destination $quickStart -Force
$archive = Join-Path $dist "RiceByTheRiver-Windows-x64.zip"
Compress-Archive -LiteralPath @($output, $pack, $quickStart, $notices) -DestinationPath $archive -CompressionLevel Optimal -Force
Get-Item -LiteralPath $archive | Select-Object FullName, Length
