# AgentHub 6.0 Clean

AgentHub 6.0 is provided here as a standalone tool inside HP3RC2. Existing HP3RC2 tools remain untouched.

## Publish the ZIP

Download `PS2RC-AgentHub-6.0-Clean.zip` from the ChatGPT conversation and save it in Downloads. Then run:

```powershell
irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/publish-archive.ps1 -OutFile "$env:TEMP\publish-agenthub6.ps1"
& "$env:TEMP\publish-agenthub6.ps1" -ZipPath "$HOME\Downloads\PS2RC-AgentHub-6.0-Clean.zip"
```

The publisher checks the archive SHA-256 before copying or pushing it. It uses the local Git Credential Manager and does not store a GitHub token.

## Install after the ZIP is published

```powershell
irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/install.ps1 | iex
```

Default install path: `F:\AI\PS2RC-AgentHub-6.0`. Set `$env:AGENTHUB6_INSTALL_ROOT` to choose another path. Existing target folders are never overwritten.

## Package integrity

SHA-256: `15064252d36e2da68b4301190ebe645a57ba6ad13318a04be7c097f6f051ce25`

The installer verifies this hash before extracting the archive. The ZIP was checked for archive integrity and contains the expected top-level folder `PS2RC-AgentHub-6.0/`.

For Ollama tuning, review and run `scripts/Configure-Ollama-6.ps1` separately on Main and Worker. Check local model names and endpoint addresses before production use.
