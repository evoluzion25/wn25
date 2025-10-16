param(
  [string]$Remote,
  [string]$User
)

# Initialize git repo and push to provided remote
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "Git not found. Installing Git via winget..."
  winget install -e --id Git.Git -h --accept-source-agreements --accept-package-agreements
}

if (-not (Test-Path .git)) {
  git init
}

git add .
git commit -m "Initial provisioning scripts"

git branch -M main

git remote remove origin -ErrorAction SilentlyContinue | Out-Null

if (-not $Remote) {
  if (-not $User) {
    $User = Read-Host "Enter your GitHub username (to push to https://github.com/<user>/wn25.git)"
  }
  if (-not $User) { throw "GitHub username is required to construct remote URL." }
  $Remote = "https://github.com/$User/wn25.git"
}

git remote add origin $Remote

git push -u origin main
