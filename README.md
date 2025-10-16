# Windows Workstation Provisioning

Provision a new Windows machine with your apps and Claude MCP config in ~15–25 minutes.

## Quick start

1) Open PowerShell as Administrator
2) Clone and run installer:

```powershell
# Clone this repo
cd $HOME
git clone https://github.com/evoluzion25/wn25.git windows-provisioning
cd windows-provisioning

# Run installer
Set-ExecutionPolicy Bypass -Scope Process -Force
./install.ps1
```

The script will:
- Install latest apps via WinGet (Node LTS, Python 3 latest, Chrome, Google Drive, VS Code, ClickUp, Docker Desktop, ChatGPT, LM Studio, Adobe Reader, PDFelement)
- Install Claude Desktop (via winget if available; otherwise opens the official download page)
- Set up Claude MCP servers (filesystem, memory, brave-search) via Node
- Create folders: C:\DevWorkspace\legal-docs and C:\DevWorkspace\legal-knowledge
- Write Claude config at %APPDATA%\Claude\claude_desktop_config.json

## Notes
- Some apps require sign-in on first launch (Google Drive, Docker, ClickUp, ChatGPT, Claude)
- VS Code: "evoluzion25" was your username, not an extension ID. Use Settings Sync to restore extensions/settings.
- Adobe Acrobat (full) vs Reader: this installs Reader by default; PDFelement covers PDF editing. Adjust packages if you own Acrobat Pro.
- Anywhere LLM is installed via npm globally (assumption)

## Update and push to GitHub (if you fork/rename)
```powershell
# Initialize and push to GitHub as 'wn25'
# Option A: auto-construct remote (prompts for username)
./scripts/init-and-push.ps1

# Option B: provide explicit remote or username
./scripts/init-and-push.ps1 -User "<you>"
# or
./scripts/init-and-push.ps1 -Remote "https://github.com/<you>/wn25.git"
```
