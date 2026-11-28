param(
    [string] $Godot = "godot"
)

$ErrorActionPreference = "Stop"
$project = Join-Path $PSScriptRoot "desktop"
$build = Join-Path $PSScriptRoot "web-build"
$dist = Join-Path $PSScriptRoot "dist"
New-Item -ItemType Directory -Force -Path $build, $dist | Out-Null
$version = (& $Godot --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notlike "4.7.2.stable*") {
    throw "Use the standard Godot 4.7.2 executable and matching Web export templates."
}

& $Godot --headless --path $project --editor --import
if ($LASTEXITCODE -ne 0) { throw "Godot project import failed." }
& $Godot --headless --path $project --export-release "Web" (Join-Path $build "index.html")
if ($LASTEXITCODE -ne 0) { throw "Web export failed." }
foreach ($name in "index.html", "index.wasm", "index.pck", "index.js") {
    if (!(Test-Path -LiteralPath (Join-Path $build $name) -PathType Leaf)) {
        throw "Missing Web export file: $name"
    }
}
$launcher = Join-Path $PSScriptRoot "tools/web"
foreach ($name in "serve_game.py", "启动网页版.cmd") {
    Copy-Item -LiteralPath (Join-Path $launcher $name) -Destination $build -Force
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "试玩说明.txt") -Destination $build -Force
$notices = Join-Path $build "licenses"
New-Item -ItemType Directory -Force -Path $notices | Out-Null
foreach ($notice in (Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "licenses") -File)) {
    Copy-Item -LiteralPath $notice.FullName -Destination $notices -Force
}
$archive = Join-Path $dist "BaiguChangqing-v1.20.2-Web.zip"
$files = @((Get-ChildItem -LiteralPath $build -File -Filter "index.*").FullName) + @(
    (Join-Path $build "serve_game.py"), (Join-Path $build "启动网页版.cmd"),
    (Join-Path $build "试玩说明.txt"), $notices
)
Compress-Archive -LiteralPath $files -DestinationPath $archive -CompressionLevel Optimal -Force
Get-Item -LiteralPath $archive | Select-Object FullName, Length
