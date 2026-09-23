param(
    [string]$Src    = "src",
    [string]$Filter = "*",
    [string]$Defs   = "",
    [switch]$Detail
)

$ErrorActionPreference = "Stop"

if (-not $Defs) {
    $candidates = @(
        "$env:APPDATA/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau",
        "$env:APPDATA/Antigravity/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau"
    )
    $Defs = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

$lsp = Get-ChildItem "$env:USERPROFILE/.vscode/extensions" -Filter "johnnymorganz.luau-lsp-*" -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $lsp) {
    Write-Error "luau-lsp not found. Install the johnnymorganz.luau-lsp extension in VS Code."
    exit 1
}
$engine = Join-Path $lsp.FullName "bin/server.exe"

& rogen build 2>&1 | Out-Null

# Mapa proprio: o luau-lsp do editor tem um watcher que reescreve o sourcemap.json,
# e as duas escritas se atropelam. E --include-non-scripts para que pasta de
# asset (ReplicatedStorage.Assets) exista para o type-check.
$map = "sourcemap.analyze.json"
& rojo sourcemap default.project.json --include-non-scripts -o $map 2>&1 | Out-Null
if (-not (Test-Path -LiteralPath $map)) {
    Write-Error "rojo did not produce the sourcemap. Install it with: rokit add rojo-rbx/rojo"
    exit 1
}

Write-Host "engine: luau-lsp + Rojo sourcemap + Roblox definitions" -ForegroundColor DarkGray

$files = Get-ChildItem -Path $Src -Recurse -Filter *.luau |
    Where-Object { $_.FullName -like $Filter }

$args = @("analyze", "--sourcemap=$map", "--flag:LuauSolverV2=true")
if ($Defs) { $args += "--definitions=$Defs" }
$args += $files.FullName

$previous = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$output = & $engine @args 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch '\[INFO\]' }
$ErrorActionPreference = $previous

$errors = @($output | Select-String 'TypeError|SyntaxError' | ForEach-Object { $_.Line } | Select-Object -Unique)
$cycles = @($output | Select-String 'Cyclic module dependency')

if ($Detail -and $errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "  $_" }
}
if ($cycles.Count -gt 0) {
    Write-Host "$($cycles.Count) cyclic require(s)." -ForegroundColor Red
}

Write-Host "total: $($errors.Count) error(s), $($cycles.Count) cycle(s)"
