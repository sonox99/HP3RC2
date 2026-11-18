# AgentHub 6.0 Clean

AgentHub 6.0 is published here as a standalone HP3RC2 tool. Existing HP3RC2 tools and files are left unchanged.

## One-time package publish

The ChatGPT GitHub connection can commit source text but cannot upload binary release assets. To place the ZIP in this repository, download `PS2RC-AgentHub-6.0-Clean.zip` from the conversation and run this script locally:

```powershell
.\publish-archive.ps1 -ZipPath "$HOME\Downloads\PS2RC-AgentHub-6.0-Clean.zip"
```

The script uses your local Git credential manager; it does not ask for or store a GitHub token.

## Install after the archive has been published

```powershell
irm https://raw.githubusercontent.com/sonox99/HP3RC2/main/tools/agenthub-6.0/install.ps1 | iex
```

Default install path: `F:\AI\PS2RC-AgentHub-6.0`. Set `$env:AGENTHUB6_INSTALL_ROOT` to choose another path. Existing installations are not overwritten.

The installer verifies SHA-256 `7330b9c47e4c5ca894ee0422fbd5a206067fc8611e9bf79b8ee8d28803761072` before extracting the ZIP.
