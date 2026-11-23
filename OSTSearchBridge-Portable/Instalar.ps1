$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = Join-Path $here "OSTSearchBridge.exe"
if (-not (Test-Path $exe)) { throw "OSTSearchBridge.exe n?o encontrado." }

function Find-SteamRoot {
  $candidates = @()
  try { $k = Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue; if ($k.SteamPath) { $candidates += $k.SteamPath }; if ($k.InstallPath) { $candidates += $k.InstallPath } } catch {}
  try { $k = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue; if ($k.InstallPath) { $candidates += $k.InstallPath } } catch {}
  $candidates += 'C:\Program Files (x86)\Steam'; $candidates += 'C:\Program Files\Steam'
  foreach ($c in $candidates | Select-Object -Unique) {
    if (-not $c) { continue }
    $p = [System.IO.Path]::GetFullPath($c)
    if (Test-Path (Join-Path $p 'steam.exe')) { return $p }
  }
  return $null
}

$steam = Find-SteamRoot
if (-not $steam) { $steam = Read-Host "Cole o caminho da raiz do Steam (onde fica steam.exe)" }
if (-not (Test-Path (Join-Path $steam 'steam.exe'))) { throw "Raiz do Steam inv?lida: $steam" }

$targetDir = Join-Path $env:LOCALAPPDATA 'OSTSearchBridge'
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Copy-Item $exe (Join-Path $targetDir 'OSTSearchBridge.exe') -Force
$cacheSrc = Join-Path $here 'cache'
if (Test-Path $cacheSrc) {
  $cacheDst = Join-Path $targetDir 'cache'
  New-Item -ItemType Directory -Path $cacheDst -Force | Out-Null
  Copy-Item (Join-Path $cacheSrc '*') $cacheDst -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($d in @('OpenSteamTool.dll','dwmapi.dll','xinput1_4.dll')) {
  $src = Join-Path (Join-Path $here 'ost-release') $d
  if (Test-Path $src) { Copy-Item $src (Join-Path $steam $d) -Force; Write-Host "Instalado: $d" }
}

$toml = Join-Path $steam 'opensteamtool.toml'
if (-not (Test-Path $toml)) {
@"
[log]
level = "debug"

[manifest]
url = "steamrun"
timeout_resolve_ms = 5000
timeout_connect_ms = 5000
timeout_send_ms = 10000
timeout_recv_ms = 10000

[lua]
paths = []

[inject]
enabled = false

[remote]
url_template = "https://raw.githubusercontent.com/JYM34/steam-monitor/{channel}/{component}/{sha256}.toml"

[stats]
enable_api = true
"@ | Set-Content -Path $toml -Encoding UTF8
}
New-Item -ItemType Directory -Path (Join-Path $steam 'config\lua') -Force | Out-Null
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item -Path $runKey -Force | Out-Null
Set-ItemProperty -Path $runKey -Name 'OSTSearchBridge' -Value ('"' + (Join-Path $targetDir 'OSTSearchBridge.exe') + '" --with-steam')
$desktop = [Environment]::GetFolderPath('Desktop')
$ws = New-Object -ComObject WScript.Shell
foreach ($name in @('OST Search Bridge.lnk','Steam (OST).lnk')) {
  $s = $ws.CreateShortcut((Join-Path $desktop $name))
  $s.TargetPath = Join-Path $targetDir 'OSTSearchBridge.exe'
  $s.Arguments = '--with-steam'
  $s.WorkingDirectory = $targetDir
  $s.IconLocation = (Join-Path $steam 'steam.exe') + ',0'
  $s.Save()
}
Start-Process -FilePath (Join-Path $targetDir 'OSTSearchBridge.exe') -ArgumentList '--install-autostart' -WindowStyle Hidden -Wait
Write-Host 'Instala??o conclu?da. Atalhos criados na ?rea de trabalho.'
