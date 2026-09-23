param(
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

function Invoke-Tool {
    param([string]$Name, [string[]]$Arguments)

    # Ferramenta que escreve em stderr sem falhar derrubaria o script sob
    # ErrorActionPreference = Stop, entao o veredito e o exit code.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Name @Arguments 2>&1 | ForEach-Object { "$_" } | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous

    if ($code -ne 0) {
        Write-Error "$Name failed with exit code $code"
        exit $code
    }
}

if (-not $SkipInstall) {
    Write-Host "wally install" -ForegroundColor DarkGray
    Invoke-Tool "wally" @("install")
}

Write-Host "rogen build" -ForegroundColor DarkGray
Invoke-Tool "rogen" @("build")

Write-Host "rojo sourcemap" -ForegroundColor DarkGray
Invoke-Tool "rojo" @("sourcemap", "default.project.json", "-o", "sourcemap.json")

$folders = @("Packages", "ServerPackages", "DevPackages") | Where-Object { Test-Path -LiteralPath $_ }
if ($folders.Count -eq 0) {
    Write-Host "no package folder to patch"
    exit 0
}

Write-Host "wally-package-types: $($folders -join ', ')" -ForegroundColor DarkGray
Invoke-Tool "wally-package-types" (@("--sourcemap", "sourcemap.json") + $folders)

$patched = 0
foreach ($folder in $folders) {
    foreach ($shim in Get-ChildItem -LiteralPath $folder -Filter *.lua -File) {
        if (Select-String -LiteralPath $shim.FullName -Pattern "^export type" -Quiet) {
            $patched++
        }
    }
}

Write-Host "$patched shim(s) reexportando tipos"
