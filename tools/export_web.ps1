<#
.SYNOPSIS
  Exporta Pozo Profundo a Web en build/web/ usando el preset "Web".

.DESCRIPTION
  Usa el Godot indicado en -Godot, o en la variable de entorno GODOT, o el de
  Descargas como último recurso. Necesita los export templates instalados
  (Editor > Gestionar plantillas de exportación). Para probar el resultado:
    node tools/serve_web.mjs

.EXAMPLE
  powershell -File tools/export_web.ps1
  powershell -File tools/export_web.ps1 -DebugBuild
#>
param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { Join-Path $env:USERPROFILE "Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }),
    [switch]$DebugBuild
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $Godot)) {
    throw "No encuentro Godot en '$Godot'. Pasalo con -Godot o definí la variable GODOT."
}

$out = Join-Path $project "build\web"
New-Item -ItemType Directory -Force $out | Out-Null

$mode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }
Write-Host "Exportando Web ($mode) -> $out"
& $Godot --headless --path $project $mode "Web" (Join-Path $out "index.html")
if ($LASTEXITCODE -ne 0) {
    throw "La exportación falló (código $LASTEXITCODE)."
}

Get-ChildItem $out | Select-Object Name, @{n = "KB"; e = { [math]::Round($_.Length / 1KB) } } | Format-Table -AutoSize
Write-Host "Listo. Probalo con: node tools/serve_web.mjs"
