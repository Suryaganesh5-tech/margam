param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Task
)

try {
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {}

$ErrorActionPreference = "Continue"
if ([string]::IsNullOrWhiteSpace($Task)) {
    Write-Host ""
    Write-Host "MARGAM: No task was provided."
    Write-Host "Usage: margam `"your task here`""
    exit 2
}

if ($Task.Length -gt 12000) {
    Write-Host ""
    Write-Host "MARGAM: Task is too long."
    Write-Host "Maximum allowed length: 12000 characters."
    exit 2
}
# ============================================================
# MARGAM - Multi-model AI Router
# Built on top of Jcode
# Free-first + task-aware + agentic coding + fallback
# ============================================================

function Run-Jcode {
    param(
        [string]$ProviderProfile,
        [string]$Provider,
        [string]$Model,
        [string]$ToolProfile,
        [string]$Prompt
    )

    if ($ProviderProfile) {
        $result = & jcode `
            --provider-profile $ProviderProfile `
            --model $Model `
            --tool-profile $ToolProfile `
            run --json $Prompt
    }
    elseif ($Model) {
        $result = & jcode `
            --provider $Provider `
            --model $Model `
            --tool-profile $ToolProfile `
            run --json $Prompt
    }
    else {
        $result = & jcode `
            --provider $Provider `
            --tool-profile $ToolProfile `
            run --json $Prompt
    }

    $exitCode = [int]$LASTEXITCODE

    if ($exitCode -eq 0 -and $result) {
        try {
            $json = $result | ConvertFrom-Json

            if ($json.text) {
                Write-Host $json.text
            }
            else {
                Write-Host $result
            }
        }
        catch {
            Write-Host $result
        }
    }
    elseif ($result) {
        Write-Host $result
    }

    return $exitCode
}

function Test-ProviderAvailable {
    param(
        [string]$Provider
    )

    switch ($Provider) {
        "ollama" {
            try {
                $response = Invoke-WebRequest `
                    -Uri "http://localhost:11434/api/tags" `
                    -Method Get `
                    -TimeoutSec 3 `
                    -UseBasicParsing

                if ($response.StatusCode -eq 200) {
                    return $true
                }

                return $false
            }
            catch {
                return $false
            }
        }

        "openrouter" {
            return $true
        }

        "groq" {
            return $true
        }

        "gemini-api" {
            return $true
        }

        "openai" {
            return $true
        }

        default {
            return $false
        }
    }
}
# ============================================================
# NORMALIZE INPUT
# ============================================================

$lower = $Task.ToLowerInvariant()

# ============================================================
# KEYWORD GROUPS
# ============================================================

$codingWords = @(
    "code","coding","program","programming",
    "python","javascript","typescript","java","php",
    "html","css","sql","c++","c#",
    "node","react","next.js","vite","npm",
    "api","database","mongodb","mysql","postgresql",
    "website","web app","application","script",
    "algorithm","function","class","object",
    "variable","array","loop","json","xml","regex",
    "git","github","repository","repo",
    "terminal","powershell","cmd",
    "compiler","compile","package","library",
    "framework","frontend","backend",
    "full stack","fullstack"
)

$debugWords = @(
    "bug","bugs","debug","debugging",
    "error","errors","exception","crash","crashing",
    "fails","failed","failure",
    "not working","doesn't work","does not work",
    "broken","issue","problem",
    "fix this","fix the code","fix my code",
    "why is my code","why doesn't my code",
    "why does my code"
)

$agentWords = @(
    "create","edit","modify","change",
    "delete","rename","move",
    "install","uninstall",
    "configure","configuration",
    "setup","set up",
    "run","execute","test",
    "implement","refactor","build",
    "generate","make","update",
    "inspect","read the file",
    "check the file","check the project",
    "inspect the project",
    "work on","add to","remove from"
)

$complexWords = @(
    "architecture","system architecture",
    "large project","complex project",
    "complex application","complete application",
    "complete system","complete website",
    "build a complete","design a complete",
    "design a system","design the system",
    "enterprise","production",
    "production system","scalable","scalability",
    "microservices","distributed system",
    "security audit","security analysis",
    "security review",
    "entire repository","entire project",
    "entire application",
    "analyze entire","analyse entire",
    "review entire","debug entire",
    "full application","full website"
)

$knowledgeWords = @(
    "what is","what are","who is","who are",
    "when is","where is","why is","why are",
    "how does","how do","explain",
    "define","definition","meaning",
    "difference between","compare","comparison",
    "advantages","disadvantages","pros and cons",
    "summarize","summary","translate",
    "tell me about","teach me"
)

function Test-KeywordMatch {
    param(
        [string]$Text,
        [string[]]$Keywords
    )

    foreach ($keyword in $Keywords) {
        $pattern = "(?<![\p{L}\p{N}_])" + [regex]::Escape($keyword) + "(?![\p{L}\p{N}_])"

        if ($Text -match $pattern) {
            return $true
        }
    }

    return $false
}

# ============================================================
# MODEL CONFIGURATION
# ============================================================

$config = @{
    General = @{
        PrimaryProviderProfile = "local-ollama"
        PrimaryProvider        = "ollama"
        PrimaryModel           = "qwen2.5:3b"
        PrimaryToolProfile     = "none"
        FallbackProvider       = "openrouter"
        FallbackModel          = "openrouter/free"
        FallbackToolProfile    = "none"
    }

    Knowledge = @{
        PrimaryProvider        = "openrouter"
        PrimaryModel           = "openrouter/free"
        PrimaryToolProfile     = "minimal"
        FallbackProvider       = "gemini-api"
        FallbackModel          = "models/gemini-3.6-flash"
        FallbackToolProfile    = "minimal"
    }

    Coding = @{
        PrimaryProvider        = "openrouter"
        PrimaryModel           = "openrouter/free"
        PrimaryToolProfile     = "minimal"
        FallbackProvider       = "groq"
        FallbackModel          = "openai/gpt-oss-20b"
        FallbackToolProfile    = "minimal"
    }

    Agentic = @{
        PrimaryProvider        = "groq"
        PrimaryModel           = "openai/gpt-oss-20b"
        PrimaryToolProfile     = "minimal"
        FallbackProvider       = "gemini-api"
        FallbackModel          = "models/gemini-3.6-flash"
        FallbackToolProfile    = "minimal"
    }

    Complex = @{
        PrimaryProvider        = "openai"
        PrimaryModel           = "gpt-5.6-terra"
        PrimaryToolProfile     = "minimal"
        FallbackProvider       = "gemini-api"
        FallbackModel          = "models/gemini-3.6-flash"
        FallbackToolProfile    = "minimal"
    }
}

# ============================================================
# DETECTION
# ============================================================

$isCoding = $false
$isDebugging = $false
$isAgentic = $false
$isComplex = $false
$isKnowledge = $false

$isCoding = Test-KeywordMatch -Text $lower -Keywords $codingWords

$isDebugging = Test-KeywordMatch -Text $lower -Keywords $debugWords

$isAgentic = Test-KeywordMatch -Text $lower -Keywords $agentWords

$isComplex = Test-KeywordMatch -Text $lower -Keywords $complexWords

$isKnowledge = Test-KeywordMatch -Text $lower -Keywords $knowledgeWords

# ============================================================
# CLASSIFICATION
# ============================================================

if ($isComplex) {
    $TaskType = "Complex"
}
elseif ($isCoding -and $isAgentic -and -not $isDebugging) {
    $TaskType = "Agentic Coding"
}
elseif ($isDebugging) {
    $TaskType = "Debugging"
}
elseif ($isCoding) {
    $TaskType = "Coding"
}
elseif ($isKnowledge) {
    $TaskType = "Knowledge"
}
else {
    $TaskType = "General"
}

# ============================================================
# HEADER
# ============================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "              MARGAM AI ROUTER"
Write-Host "=========================================="
Write-Host ""
Write-Host "[ROUTER] Task type : $TaskType"

# ============================================================
# GENERAL
# ============================================================

if ($TaskType -eq "General") {

    Write-Host "[ROUTER] Strategy  : Local / Free"
    Write-Host "[ROUTER] Primary   : Ollama"
    Write-Host "[ROUTER] Model     : qwen2.5:3b"
    Write-Host "[ROUTER] Fallback  : OpenRouter FREE"
    Write-Host ""

    $prompt = @"
Answer the user's question accurately and clearly.

Rules:
- Do not invent facts.
- Keep the explanation proportional to the question.
- Use simple language unless technical detail is needed.
- If a fact is uncertain, say so.
- Prefer accuracy over unnecessary length.

User request:

$Task
"@

    $cfg = $config.General

        if ($cfg.PrimaryProvider -eq "ollama" -and -not (Test-ProviderAvailable -Provider "ollama")) {
        Write-Host "[ROUTER] Ollama is unavailable."
        Write-Host "[ROUTER] Using fallback: $($cfg.FallbackProvider)"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider $cfg.FallbackProvider `
            -Model $cfg.FallbackModel `
            -ToolProfile $cfg.FallbackToolProfile `
            -Prompt $prompt
    }
    else {
        $exit = Run-Jcode `
            -ProviderProfile $cfg.PrimaryProviderProfile `
            -Provider $cfg.PrimaryProvider `
            -Model $cfg.PrimaryModel `
            -ToolProfile $cfg.PrimaryToolProfile `
            -Prompt $prompt
    }

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] Ollama failed."
        Write-Host "[ROUTER] Fallback  : OpenRouter FREE"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider $cfg.FallbackProvider `
            -Model $cfg.FallbackModel `
            -ToolProfile $cfg.FallbackToolProfile `
            -Prompt $prompt
    }
}

# ============================================================
# KNOWLEDGE
# ============================================================

elseif ($TaskType -eq "Knowledge") {

    Write-Host "[ROUTER] Strategy  : Knowledge / Free"
    Write-Host "[ROUTER] Primary   : OpenRouter FREE"
    Write-Host "[ROUTER] Model     : OpenRouter Free Router"
    Write-Host "[ROUTER] Fallback  : Gemini"
    Write-Host ""

    $prompt = @"
Answer the user's question accurately and clearly.

Rules:
- Explain concepts in a useful way.
- Do not invent facts.
- Prefer accuracy over unnecessary length.
- Do not expose secrets, API keys, passwords, or tokens.

User request:

$Task
"@

    $cfg = $config.Knowledge

    $exit = Run-Jcode `
        -Provider $cfg.PrimaryProvider `
        -Model $cfg.PrimaryModel `
        -ToolProfile $cfg.PrimaryToolProfile `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] OpenRouter failed."
        Write-Host "[ROUTER] Fallback  : Gemini"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider $cfg.FallbackProvider `
            -Model $cfg.FallbackModel `
            -ToolProfile $cfg.FallbackToolProfile `
            -Prompt $prompt
    }
}

# ============================================================
# CODING
# ============================================================

elseif ($TaskType -eq "Coding") {

    Write-Host "[ROUTER] Strategy  : Programming"
    Write-Host "[ROUTER] Primary   : OpenRouter FREE"
    Write-Host "[ROUTER] Model     : OpenRouter Free Router"
    Write-Host "[ROUTER] Fallback  : Groq"
    Write-Host ""

    $prompt = @"
Act as an expert programming assistant.

Solve the user's request accurately.

Requirements:
- Produce correct, practical code.
- Prefer simple maintainable solutions.
- Follow the requested language and framework.
- Check syntax and logic before responding.
- Explain important parts when useful.
- Do not expose secrets, API keys, passwords, or tokens.

User request:

$Task
"@

            $cfg = $config.Coding

    $exit = Run-Jcode `
        -Provider $cfg.PrimaryProvider `
        -Model $cfg.PrimaryModel `
        -ToolProfile $cfg.PrimaryToolProfile `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] OpenRouter failed."
        Write-Host "[ROUTER] Fallback  : Groq"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider $cfg.FallbackProvider `
            -Model $cfg.FallbackModel `
            -ToolProfile $cfg.FallbackToolProfile `
            -Prompt $prompt
    }
}
# ============================================================
# ============================================================
# DEBUGGING / AGENTIC CODING
# ============================================================

elseif ($TaskType -eq "Debugging" -or $TaskType -eq "Agentic Coding") {

    Write-Host "[ROUTER] Strategy  : Coding Agent + Verification"
    Write-Host "[ROUTER] Primary   : Groq FREE"
    Write-Host "[ROUTER] Model     : GPT-OSS-20B"
    Write-Host "[ROUTER] Fallback  : Gemini"
    Write-Host ""

    $prompt = @"
Act as a careful coding agent running on Windows 11.

ENVIRONMENT:
- The operating system is Windows 11.
- Prefer PowerShell or Windows CMD-compatible commands.
- Do NOT use Linux/macOS-only commands such as find, grep, sed, awk, rm, chmod, or Unix shell syntax.
- Do NOT assume bash is available.
- Use Windows-compatible paths and commands.
- Python is available as `python`.
- Work only inside the current project/workspace unless the user explicitly requests otherwise.

USER REQUEST:

$Task

WORKFLOW:

1. Inspect the relevant files and project structure before making changes.
2. Understand the existing implementation before modifying it.
3. Identify the exact requested change or root cause.
4. Make the smallest safe change necessary.
5. Preserve unrelated functionality.
6. Do not overwrite or delete unrelated files.
7. Check syntax and logic after editing.
8. Prefer non-interactive tests whenever possible.
9. Never run a command that waits for user input unless the user explicitly requested an interactive program.
10. For Python programs, prefer non-interactive validation such as:
    python -c "..."
    or a test script with predefined inputs.
11. Run relevant tests or validation commands when possible.
12. If a command fails, diagnose the failure and try a Windows-compatible alternative.
13. If a tool or command is unavailable, do not repeatedly retry it; use an appropriate alternative.
14. Verify that the requested result actually works.
15. Do NOT create Git commits, push to GitHub, reset branches, or alter Git history unless the user explicitly asks for Git operations.
16. Do not claim a test passed unless you actually ran it and observed the result.

SAFETY:

- Never reveal API keys, passwords, tokens, or other secrets.
- Do not expose secret values found in files or environment variables.
- Do not perform unrelated destructive operations.
- Do not overwrite unrelated files.
- Ask before making major ambiguous changes.
- Keep changes focused on the user's request.

FINAL REPORT:

Report briefly:
- Changes made
- Tests/validation performed
- Verification result
- Remaining problems, if any
"@

        $cfg = $config.Agentic

    $exit = Run-Jcode `
        -Provider $cfg.PrimaryProvider `
        -Model $cfg.PrimaryModel `
        -ToolProfile $cfg.PrimaryToolProfile `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] Groq failed."
        Write-Host "[ROUTER] Fallback  : Gemini"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider $cfg.FallbackProvider `
            -Model $cfg.FallbackModel `
            -ToolProfile $cfg.FallbackToolProfile `
            -Prompt $prompt
    }
}

# COMPLEX
# ============================================================

elseif ($TaskType -eq "Complex") {

    Write-Host "[ROUTER] Strategy  : Maximum Reasoning"
    Write-Host "[ROUTER] Primary   : OpenAI"
    Write-Host "[ROUTER] Model     : GPT-5.6 Terra"
    Write-Host "[ROUTER] Fallback  : Gemini"
    Write-Host ""

    $prompt = @"
You are handling a complex technical task.

Analyze the request carefully before answering.

For software or system tasks:

1. Understand all requirements.
2. Break the problem into logical components.
3. Consider edge cases.
4. Consider security and reliability.
5. Choose practical technologies and architecture.
6. Inspect relevant project files when available.
7. Make minimal safe changes when modification is requested.
8. Test or validate the result when possible.
9. Verify the final result.
10. Clearly state assumptions and limitations.

Prefer correctness and practical implementation over unnecessary complexity.

Never expose secrets, API keys, passwords, or tokens.

User request:

$Task
"@

        $cfg = $config.Complex

    $exit = Run-Jcode `
        -Provider $cfg.PrimaryProvider `
        -Model $cfg.PrimaryModel `
        -ToolProfile $cfg.PrimaryToolProfile `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] OpenAI failed."
        Write-Host "[ROUTER] Fallback  : Gemini"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider $cfg.FallbackProvider `
            -Model $cfg.FallbackModel `
            -ToolProfile $cfg.FallbackToolProfile `
            -Prompt $prompt
    }
}

# ============================================================
# FINAL STATUS
# ============================================================

Write-Host ""

if ($exit -eq 0) {
    Write-Host "[ROUTER] Status    : SUCCESS"
}
else {
    Write-Host "[ROUTER] Status    : FAILED"
    Write-Host "[ROUTER] Exit code : $exit"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "                  DONE"
Write-Host "=========================================="
Write-Host ""
