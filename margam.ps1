param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Task
)

$ErrorActionPreference = "Continue"

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
        & jcode `
            --provider-profile $ProviderProfile `
            --model $Model `
            --tool-profile $ToolProfile `
            run $Prompt |
            ForEach-Object { Write-Host $_ }

        return [int]$LASTEXITCODE
    }

    if ($Model) {
        & jcode `
            --provider $Provider `
            --model $Model `
            --tool-profile $ToolProfile `
            run $Prompt |
            ForEach-Object { Write-Host $_ }

        return [int]$LASTEXITCODE
    }

    & jcode `
        --provider $Provider `
        --tool-profile $ToolProfile `
        run $Prompt |
        ForEach-Object { Write-Host $_ }

    return [int]$LASTEXITCODE
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

# ============================================================
# DETECTION
# ============================================================

$isCoding = $false
$isDebugging = $false
$isAgentic = $false
$isComplex = $false
$isKnowledge = $false

foreach ($word in $codingWords) {
    if ($lower.Contains($word)) {
        $isCoding = $true
        break
    }
}

foreach ($word in $debugWords) {
    if ($lower.Contains($word)) {
        $isDebugging = $true
        break
    }
}

foreach ($word in $agentWords) {
    if ($lower.Contains($word)) {
        $isAgentic = $true
        break
    }
}

foreach ($word in $complexWords) {
    if ($lower.Contains($word)) {
        $isComplex = $true
        break
    }
}

foreach ($word in $knowledgeWords) {
    if ($lower.Contains($word)) {
        $isKnowledge = $true
        break
    }
}

# ============================================================
# CLASSIFICATION
# ============================================================

if ($isComplex) {
    $TaskType = "Complex"
}
elseif ($isCoding -and ($isDebugging -or $isAgentic)) {
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

    $exit = Run-Jcode `
        -ProviderProfile "local-ollama" `
        -Model "qwen2.5:3b" `
        -ToolProfile "none" `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] Ollama failed."
        Write-Host "[ROUTER] Fallback  : OpenRouter FREE"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider "openrouter" `
            -Model "minimax/minimax-m2.7:free" `
            -ToolProfile "none" `
            -Prompt $prompt
    }
}

# ============================================================
# KNOWLEDGE
# ============================================================

elseif ($TaskType -eq "Knowledge") {

    Write-Host "[ROUTER] Strategy  : Knowledge / Free"
    Write-Host "[ROUTER] Primary   : OpenRouter FREE"
    Write-Host "[ROUTER] Model     : MiniMax M2.7 FREE"
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

    $exit = Run-Jcode `
        -Provider "openrouter" `
        -Model "minimax/minimax-m2.7:free" `
        -ToolProfile "minimal" `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] OpenRouter failed."
        Write-Host "[ROUTER] Fallback  : Gemini"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider "gemini-api" `
            -Model "models/gemini-3.6-flash" `
            -ToolProfile "minimal" `
            -Prompt $prompt
    }
}

# ============================================================
# CODING
# ============================================================

elseif ($TaskType -eq "Coding") {

    Write-Host "[ROUTER] Strategy  : Programming"
    Write-Host "[ROUTER] Primary   : OpenRouter FREE"
    Write-Host "[ROUTER] Model     : MiniMax M2.7 FREE"
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

    $exit = Run-Jcode `
        -Provider "openrouter" `
        -Model "minimax/minimax-m2.7:free" `
        -ToolProfile "minimal" `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] OpenRouter failed."
        Write-Host "[ROUTER] Fallback  : Groq"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider "groq" `
            -Model "openai/gpt-oss-20b" `
            -ToolProfile "minimal" `
            -Prompt $prompt
    }
}

# ============================================================
# DEBUGGING / AGENTIC CODING
# ============================================================

elseif ($TaskType -eq "Debugging" -or $TaskType -eq "Agentic Coding") {

    Write-Host "[ROUTER] Strategy  : Coding Agent + Verification"
    Write-Host "[ROUTER] Primary   : OpenRouter FREE"
    Write-Host "[ROUTER] Model     : MiniMax M2.7 FREE"
    Write-Host "[ROUTER] Fallback  : Groq"
    Write-Host ""

    $prompt = @"
Act as a careful coding agent.

User request:

$Task

WORKFLOW:

1. Inspect relevant files/project structure if available.
2. Understand the existing implementation before changing it.
3. Identify the root cause or exact requested modification.
4. Make the smallest safe changes.
5. Preserve unrelated functionality.
6. Check syntax and logic.
7. Run relevant tests or validation commands when possible.
8. If something fails, diagnose and fix it.
9. Verify that the requested result actually works.
10. Report:
   - changes made
   - tests/validation performed
   - verification result
   - remaining problems, if any

SAFETY:

- Never reveal API keys, passwords, tokens, or secrets.
- Do not perform unrelated destructive operations.
- Do not overwrite unrelated files.
- Ask before making major ambiguous changes.
"@

    $exit = Run-Jcode `
        -Provider "openrouter" `
        -Model "minimax/minimax-m2.7:free" `
        -ToolProfile "minimal" `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] OpenRouter failed."
        Write-Host "[ROUTER] Fallback  : Groq"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider "groq" `
            -Model "openai/gpt-oss-20b" `
            -ToolProfile "minimal" `
            -Prompt $prompt
    }
}

# ============================================================
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

    $exit = Run-Jcode `
        -Provider "openai" `
        -Model "gpt-5.6-terra" `
        -ToolProfile "minimal" `
        -Prompt $prompt

    if ($exit -ne 0) {
        Write-Host ""
        Write-Host "[ROUTER] OpenAI failed."
        Write-Host "[ROUTER] Fallback  : Gemini"
        Write-Host ""

        $exit = Run-Jcode `
            -Provider "gemini-api" `
            -Model "models/gemini-3.6-flash" `
            -ToolProfile "minimal" `
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
