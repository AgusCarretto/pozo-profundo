<#
.SYNOPSIS
  Exporta Pozo Profundo a Web en build/web/ usando el preset "Web" y arma el zip para itch.io.

.DESCRIPTION
  Usa el Godot indicado en -Godot, o en la variable de entorno GODOT, o el de
  Descargas como último recurso. Necesita los export templates instalados
  (Editor > Gestionar plantillas de exportación).

  El zip (build/pozo-profundo-web-v<versión>.zip, con index.html en la raíz) se arma solo en release:
  es lo que se sube a itch.io. La URL y la key de Supabase y el link de "Opinar" salen de
  data/online.json (copiá data/online.example.json); sin ese archivo el juego anda igual, pero no manda
  métricas ni muestra "Opinar".

  Para probar el resultado:  node tools/serve_web.mjs

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

$build = Join-Path $project "build"
$out = Join-Path $build "web"
# build/ es solo salida: se vacía el export anterior para que nada viejo llegue al zip, y Godot la ignora.
if (Test-Path $out) {
    Remove-Item -Recurse -Force $out
}
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType File -Force (Join-Path $build ".gdignore") | Out-Null

$mode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }
Write-Host "Exportando Web ($mode) -> $out"
& $Godot --headless --path $project $mode "Web" (Join-Path $out "index.html")
if ($LASTEXITCODE -ne 0) {
    throw "La exportación falló (código $LASTEXITCODE)."
}
if (-not (Test-Path (Join-Path $out "index.pck"))) {
    throw "La exportación no dejó index.pck en $out."
}

# Lo que usa la pantalla de carga (web/shell.html). La licencia acompaña a la fuente.
Copy-Item (Join-Path $project "assets\fonts\PixelifySans.ttf") $out
Copy-Item (Join-Path $project "assets\fonts\OFL.txt") $out
Copy-Item (Join-Path $project "assets\sprites\generated\rock_earth.png") (Join-Path $out "loading_rock.png")

Get-ChildItem $out | Select-Object Name, @{n = "KB"; e = { [math]::Round($_.Length / 1KB) } } | Format-Table -AutoSize

if (-not (Test-Path (Join-Path $project "data\online.json"))) {
    Write-Host "AVISO: no existe data/online.json: este build no manda métricas ni muestra 'Opinar'." -ForegroundColor Yellow
}

if (-not $DebugBuild) {
    $settings = Get-Content -Raw -Encoding UTF8 (Join-Path $project "project.godot")
    if ($settings -notmatch 'config/version="([^"]+)"') {
        throw "project.godot no tiene config/version."
    }
    $zip = Join-Path $build "pozo-profundo-web-v$($Matches[1]).zip"
    # Los archivos sueltos (sin la carpeta) para que index.html quede en la raíz del zip.
    $files = Get-ChildItem -File $out | Where-Object { $_.Extension -ne ".import" }
    if (Test-Path $zip) {
        Remove-Item -Force $zip
    }
    Compress-Archive -LiteralPath $files.FullName -DestinationPath $zip
    Write-Host ("Zip para itch.io: {0} ({1:N1} MB)" -f $zip, ((Get-Item $zip).Length / 1MB))
}
Write-Host "Listo. Probalo con: node tools/serve_web.mjs"
