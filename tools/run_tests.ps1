<#
.SYNOPSIS
  Corre los tests headless de tests/*_test.gd y resume el resultado.

.DESCRIPTION
  Usa el Godot indicado en -Godot, o en la variable de entorno GODOT, o el de
  Descargas como último recurso (igual que tools/export_web.ps1).

  Un test cuenta como fallido si se cumple CUALQUIERA de estas:
    - el proceso termina con código distinto de 0;
    - la salida contiene "SCRIPT ERROR", "Parse Error", una línea "ERROR:" o "FALLO";
    - nunca imprime la línea final "OK:";
    - tarda más de -TimeoutSeconds (un error de script directamente dentro de _initialize
      salta el _finish() y Godot queda corriendo para siempre).
  El segundo punto es importante: un error de script en tiempo de ejecución aborta la
  función del test pero Godot igual termina con código 0 y el test puede imprimir "OK:".

  Sale con código 0 si todo pasó y 1 si algo falló.

  Tests rápidos y lentos: un test es lento si su encabezado tiene una línea `## @lento` (los de
  animaciones, que esperan a que terminen tweens y partículas). Sin parámetros corren solo los rápidos;
  con -All, todos (antes de un commit de fase); con -Slow, solo los lentos. Un -Filter explícito incluye
  los lentos que coincidan: nombrar un test es pedirlo.

.EXAMPLE
  powershell -File tools/run_tests.ps1
  powershell -File tools/run_tests.ps1 -Filter "economy*"
  powershell -File tools/run_tests.ps1 -ShowOutput
  powershell -File tools/run_tests.ps1 -All
  powershell -File tools/run_tests.ps1 -Slow
#>
param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { Join-Path $env:USERPROFILE "Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }),
    [string]$Filter = "*",
    [int]$TimeoutSeconds = 60,
    [switch]$ShowOutput,
    [switch]$All,
    [switch]$Slow
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $Godot)) {
    throw "No encuentro Godot en '$Godot'. Pasalo con -Godot o definí la variable GODOT."
}

# Un test es lento si alguna línea de su encabezado (los comentarios de arriba) empieza con "## @lento".
function Test-IsSlow([System.IO.FileInfo]$File) {
    foreach ($line in (Get-Content -LiteralPath $File.FullName -Encoding UTF8 -TotalCount 15)) {
        if ($line -match "^\s*## @lento\b") { return $true }
    }
    return $false
}

$matching = Get-ChildItem (Join-Path $project "tests") -Filter "*_test.gd" |
    Where-Object { $_.BaseName -like $Filter } |
    Sort-Object Name
if (-not $matching) {
    throw "No hay tests que coincidan con '$Filter' en tests/."
}
$explicitFilter = $Filter -ne "*"
$tests = @()
$skippedSlow = @()
foreach ($file in $matching) {
    $isSlow = Test-IsSlow $file
    if ($Slow) { $wanted = $isSlow }
    elseif ($All -or $explicitFilter) { $wanted = $true }
    else { $wanted = -not $isSlow }
    if ($wanted) { $tests += $file } elseif ($isSlow) { $skippedSlow += $file.BaseName }
}
if (-not $tests) {
    throw "No hay tests para correr con estos parámetros (Filter '$Filter')."
}
# Se usa Process (y no `&` con 2>&1) porque en PowerShell 5.1 redirigir el stderr de un
# ejecutable nativo lo convierte en errores terminantes bajo $ErrorActionPreference = "Stop".
function Invoke-GodotTest([string]$ScriptName) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Godot
    $psi.Arguments = "--headless --path `"$project`" --script res://tests/$ScriptName"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) {
        $process.Kill()
        return [pscustomobject]@{ ExitCode = -1; Output = "TIMEOUT: el test tardó más de $TimeoutSeconds s y se canceló."; TimedOut = $true }
    }
    $process.WaitForExit()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = ($stdout.Result + "`n" + $stderr.Result); TimedOut = $false }
}

$results = @()
foreach ($test in $tests) {
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $run = Invoke-GodotTest $test.Name
    $watch.Stop()

    $lines = $run.Output -split "`r?`n"
    $problems = @($lines | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|^ERROR:|FALLO|^TIMEOUT" })
    $okLine = $lines | Where-Object { $_ -match "^OK:" } | Select-Object -First 1
    $passed = ($run.ExitCode -eq 0) -and ($problems.Count -eq 0) -and ($null -ne $okLine)

    $reason = ""
    if (-not $passed) {
        if ($run.ExitCode -ne 0) { $reason = "código de salida $($run.ExitCode)" }
        elseif ($problems.Count -gt 0) { $reason = "errores en la salida" }
        else { $reason = "no llegó a imprimir 'OK:'" }
    }

    $results += [pscustomobject]@{
        Test     = $test.BaseName
        Resultado = if ($passed) { "OK" } else { "FALLO" }
        Detalle  = if ($passed) { $okLine } else { $reason }
        Segundos = [math]::Round($watch.Elapsed.TotalSeconds, 1)
    }

    if ($ShowOutput -or -not $passed) {
        Write-Host ""
        Write-Host "=== $($test.Name) ===" -ForegroundColor Cyan
        if ($ShowOutput) {
            $lines | ForEach-Object { Write-Host $_ }
        }
        else {
            $problems | Select-Object -First 15 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        }
    }
}

Write-Host ""
$results | Format-Table -AutoSize
$failed = @($results | Where-Object { $_.Resultado -ne "OK" })
if ($failed.Count -gt 0) {
    Write-Host "FALLARON $($failed.Count) de $($results.Count) tests." -ForegroundColor Red
    exit 1
}
Write-Host "Pasaron los $($results.Count) tests." -ForegroundColor Green
if ($skippedSlow.Count -gt 0) {
    Write-Host "Se saltearon $($skippedSlow.Count) tests lentos ($($skippedSlow -join ', ')): correlos con -All o -Slow." -ForegroundColor Yellow
}
exit 0
