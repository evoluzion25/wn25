#requires -Version 5.1
[CmdletBinding()]
param(
  [switch]$NoReboot,
  [string]$LogDir,
  [switch]$SkipConnectivityCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine log directory (default to script folder or temp)
$scriptRoot = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($LogDir)) {
  $LogDir = if ($scriptRoot) { $scriptRoot } else { $env:TEMP }
}
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$global:WN25_LogPath = Join-Path $LogDir ("install-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

try {
  Start-Transcript -Path $global:WN25_LogPath -Force | Out-Null
} catch {}

Write-Host "==> Windows Workstation Provisioning starting..." -ForegroundColor Cyan
Write-Host ("Logging to: {0}" -f $global:WN25_LogPath) -ForegroundColor DarkGray

# Ensure running as Administrator
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
  throw "Please run this script as Administrator."
}

# Enable TLS 1.2/1.3 for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Make sure WinGet is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "WinGet not found. Please ensure Windows 11/Windows 10 with App Installer." -ForegroundColor Yellow
}

# Basic connectivity check (optional)
function Test-InternetConnection {
  param([int]$TimeoutSec = 8)
  try {
    $r = Invoke-WebRequest -Uri 'https://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec $TimeoutSec
    if ($r.StatusCode -eq 200 -and $r.Content -match 'Microsoft Connect Test') { return $true }
  } catch {}
  try {
    Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
  } catch { return $false }
}

if (-not $SkipConnectivityCheck) {
  Write-Host "Checking internet connectivity..." -ForegroundColor Cyan
  $online = Test-InternetConnection
  if (-not $online) {
    Write-Host "No internet connection detected. The installer relies on online sources (winget, npm)." -ForegroundColor Yellow
    $resp = Read-Host "Continue anyway? (y/N)"
    if ($resp -notmatch '^(y|Y)') { Write-Host "Aborting per user choice."; goto :cleanup }
  }
}

# Create base folders
$devRoot = 'C:\\DevWorkspace'
$legalDocs = Join-Path $devRoot 'legal-docs'
$legalKnowledge = Join-Path $devRoot 'legal-knowledge'
New-Item -ItemType Directory -Force -Path $devRoot,$legalDocs,$legalKnowledge | Out-Null

# Core apps via WinGet
$packages = @(
  @{ Id = 'OpenJS.NodeJS.LTS'; Name = 'Node.js LTS (latest)' },
  # Use floating Python 3 channel to always get latest 3.x
  @{ Id = 'Python.Python.3'; Name = 'Python 3 (latest)' },
  @{ Id = 'Google.Chrome'; Name = 'Google Chrome' },
  @{ Id = 'Google.Drive'; Name = 'Google Drive for Desktop' },
  @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code' },
  @{ Id = 'ClickUp.ClickUp'; Name = 'ClickUp' },
  @{ Id = 'Docker.DockerDesktop'; Name = 'Docker Desktop' },
  @{ Id = 'OpenAI.ChatGPT'; Name = 'ChatGPT' },
  @{ Id = 'LMStudio.LMStudio'; Name = 'LM Studio' },
  @{ Id = 'Adobe.Acrobat.Reader.64-bit'; Name = 'Adobe Acrobat Reader' },
  @{ Id = 'Wondershare.PDFelement'; Name = 'Wondershare PDFelement' }
)

foreach ($p in $packages) {
  Install-WinGetPackage -Id $p.Id -Name $p.Name
}

# VS Code: no forced extensions here; 'evoluzion25' is the username. Recommend enabling Settings Sync.
Write-Host "Tip: Sign into VS Code with your account and enable Settings Sync to restore your environment." -ForegroundColor Cyan

# Install Claude Desktop (prefer WinGet for latest; fallback to manual)
Write-Host "Installing Claude Desktop (latest)..."
try {
  & winget install -e --id Anthropic.Claude -h --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) { throw "winget failed with exit code $LASTEXITCODE" }
} catch {
  Write-Host "Winget install for Claude failed or package unavailable. Opening download page..." -ForegroundColor Yellow
  try { Start-Process "https://claude.ai/download" } catch {}
  Write-Host "Please install Claude Desktop from the opened page, then re-run this script if needed." -ForegroundColor Yellow
}

# NPM global tools (MCP servers + Anywhere LLM)
if (Get-Command npm -ErrorAction SilentlyContinue) {
  Write-Host "Installing global npm tools (MCP servers, anywhere-llm)..."
  npm install -g @modelcontextprotocol/server-filesystem @modelcontextprotocol/server-memory @modelcontextprotocol/server-brave-search anywhere-llm
} else {
  Write-Host "npm not found; skipping MCP servers and anywhere-llm global install." -ForegroundColor Yellow
}

# Write Claude Desktop MCP config
$claudeConfigDir = Join-Path $env:APPDATA 'Claude'
$claudeConfigPath = Join-Path $claudeConfigDir 'claude_desktop_config.json'
New-Item -ItemType Directory -Force -Path $claudeConfigDir | Out-Null

$claudeConfig = @{
  mcpServers = @{
    'brave-search' = @{
      command = 'npx'
      args = @('-y','@modelcontextprotocol/server-brave-search')
      env  = @{ 'BRAVE_API_KEY' = 'REPLACE_WITH_YOUR_KEY' }
    }
    filesystem = @{
      command = 'npx'
      args = @('-y','@modelcontextprotocol/server-filesystem', $legalDocs)
    }
    memory = @{
      command = 'npx'
      args = @('-y','@modelcontextprotocol/server-memory')
    }
  }
} | ConvertTo-Json -Depth 6

$claudeConfig | Out-File -FilePath $claudeConfigPath -Encoding UTF8
Write-Host "Claude MCP config written to $claudeConfigPath"

# Add convenience desktop shortcuts for LM Studio and Claude if present
function Add-Shortcut {
  param([string]$Target, [string]$Name)
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\\$Name.lnk")
  $shortcut.TargetPath = $Target
  $shortcut.Save()
}

$lmPath = "$env:LOCALAPPDATA\\Programs\\LM-Studio\\LM Studio.exe"
if (Test-Path $lmPath) { Add-Shortcut -Target $lmPath -Name 'LM Studio' }

$claudePath = "$env:LOCALAPPDATA\\Programs\\Claude\\Claude.exe"
if (Test-Path $claudePath) { Add-Shortcut -Target $claudePath -Name 'Claude' }

Write-Host "==> Provisioning complete. Review any warnings above." -ForegroundColor Green

if (-not $NoReboot) {
  Write-Host "A reboot is recommended to finalize PATH updates. Reboot now? (Y/N)"
  $key = Read-Host
  if ($key -match '^(y|Y)') { Restart-Computer }
}

:cleanup
try { Stop-Transcript | Out-Null } catch {}
