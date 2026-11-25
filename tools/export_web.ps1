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

# Key secreta nueva (sb_secret_...) o JWT cuyo rol es service_role: se saltan las reglas de la base (RLS).
function Test-SecretKey([string]$Key) {
    if ($Key.StartsWith("sb_secret_")) { return $true }
    $parts = $Key.Split(".")
    if ($parts.Count -ne 3) { return $false }
    $payload = $parts[1].Replace("-", "+").Replace("_", "/")
    while ($payload.Length % 4 -ne 0) { $payload += "=" }
    try {
        $claims = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
    }
    catch {
        return $false
    }
    return $claims.role -eq "service_role"
}

# data/online.json va empaquetado en el juego: lo que tenga lo puede leer cualquiera que lo baje. Se revisa antes
# de exportar, y un JSON roto corta acá en vez de dar un build que en silencio no manda nada.
$config = Join-Path $project "data\online.json"
if (Test-Path $config) {
    $text = Get-Content -Raw -Encoding UTF8 $config
    try {
        $online = $text | ConvertFrom-Json
    }
    catch {
        throw "data/online.json no es un JSON válido: $($_.Exception.Message)"
    }
    $key = ([string]$online.supabase_key).Trim()
    if ($text.Contains("sb_secret_") -or (Test-SecretKey $key)) {
        throw "data/online.json tiene una key SECRETA: quedaría publicada dentro del juego. Poné la publishable (sb_publishable_...) y, si la secreta ya se compartió, rotala en Supabase."
    }
    if (-not $online.supabase_url -or -not $key) {
        Write-Host "AVISO: data/online.json sin supabase_url o supabase_key: este build no manda métricas." -ForegroundColor Yellow
    }
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

# Lo que usa la pantalla de carga (web/shell.html). Cada fuente va con su licencia.
foreach ($file in "PixelifySans.ttf", "OFL.txt", "VT323Digits.ttf", "VT323-OFL.txt") {
    Copy-Item (Join-Path $project "assets\fonts\$file") $out
}
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
