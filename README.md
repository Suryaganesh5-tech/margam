# MARGAM

**MARGAM** is a task-aware, multi-model AI router built on top of the Jcode CLI.

It automatically chooses an AI provider based on the type of request and uses fallbacks when a primary provider fails.

## Routing

| Task type | Primary | Fallback |
|---|---|---|
| General | Ollama — Qwen 2.5 3B | OpenRouter Free |
| Knowledge | OpenRouter — MiniMax M2.7 Free | Gemini |
| Coding | OpenRouter — MiniMax M2.7 Free | Groq |
| Debugging / Agentic Coding | OpenRouter — MiniMax M2.7 Free | Groq |
| Complex | OpenAI — GPT-5.6 Terra | Gemini |

## Features

- Task-aware routing
- Free-first design
- Local Ollama support
- Multiple cloud providers
- Automatic fallback
- Coding and debugging workflow
- Minimal tool profiles for safer execution
- Explicit reasoning model for complex tasks
- Secret-safe prompts

## Requirements

- Windows with PowerShell
- Jcode installed and available as `jcode`
- Ollama installed for the local route
- Provider credentials configured in Jcode for the providers you want to use

MARGAM does **not** contain API keys or credentials.

## Usage

Run the PowerShell router:

```powershell
.\margam.ps1 "Explain what an API is"
```

Examples:

```powershell
.\margam.ps1 "What is virtualization?"
.\margam.ps1 "Write a Python program to check prime numbers."
.\margam.ps1 "Debug my Python program and fix the error."
.\margam.ps1 "Design a scalable architecture for a food delivery platform."
```

## Installing the `margam` command

The repository contains `margam.ps1`. You can create your own PowerShell function or Windows launcher that points to this script.

Example PowerShell function:

```powershell
function margam {
    param([Parameter(Mandatory=$true, Position=0)][string]$Task)
    & "$HOME\margam\margam.ps1" $Task
}
```

For a permanent command, place the project in a stable folder and add an appropriate launcher to a directory on your PATH.

## Architecture

```text
User
  |
  v
MARGAM PowerShell Router
  |
  +--> General ---------> Ollama / Qwen 2.5 3B
  |
  +--> Knowledge -------> OpenRouter / MiniMax
  |                          |
  |                          +--> Gemini fallback
  |
  +--> Coding ----------> OpenRouter / MiniMax
  |                          |
  |                          +--> Groq fallback
  |
  +--> Agentic Coding --> OpenRouter / MiniMax
  |                          |
  |                          +--> Groq fallback
  |
  +--> Complex ---------> OpenAI / GPT-5.6 Terra
                             |
                             +--> Gemini fallback
```

## Project status

MARGAM is currently a PowerShell router/wrapper around Jcode. The routing logic is separate from the Jcode application itself.

The project can later be rewritten as a native Rust CLI without changing the routing design.

## Security

Never commit:

- API keys
- OAuth tokens
- passwords
- `.env` files containing secrets
- private configuration files

Provider credentials should remain in your local Jcode configuration.

## License

MIT
