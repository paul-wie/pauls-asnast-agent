# Windows start: loads .env, picks podman or docker, generates .github/mcp.json, starts Copilot in the repo root.
# Usage (VPN on):  .\scripts\start.ps1      Override runtime:  $env:PASS_CONTAINER_RUNTIME = 'docker'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
if (-not (Test-Path .env)) { throw ".env missing - create it with your tokens (see README.md)." }
Get-Content .env | Where-Object { $_ -match '^\s*(export\s+)?[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object {
  $line = $_ -replace '^\s*export\s+', ''
  $name, $value = $line -split '=', 2
  Set-Item -Path "Env:$($name.Trim())" -Value $value.Trim().Trim('"').Trim("'")
}

$runtime = $env:PASS_CONTAINER_RUNTIME
if (-not $runtime) { $runtime = foreach ($r in 'podman', 'docker') { if (Get-Command $r -ErrorAction SilentlyContinue) { $r; break } } }
if (-not $runtime) { throw 'Neither podman nor docker found on PATH.' }
& $runtime info *> $null
if ($LASTEXITCODE -ne 0) { throw "$runtime engine not reachable (start Docker Desktop / podman machine)." }
"container runtime: $runtime"

$tpl = Get-Content (Join-Path '.github' 'mcp.template.json') -Raw
[IO.File]::WriteAllText((Join-Path (Join-Path $root '.github') 'mcp.json'), $tpl.Replace('__RUNTIME__', $runtime), (New-Object Text.UTF8Encoding $false))

foreach ($v in 'JIRA_PERSONAL_TOKEN', 'CONFLUENCE_PERSONAL_TOKEN') {
  "{0}: {1}" -f $v, $(if ((Get-Item "Env:$v" -ErrorAction SilentlyContinue).Value) { 'loaded' } else { 'MISSING' })
}
copilot
