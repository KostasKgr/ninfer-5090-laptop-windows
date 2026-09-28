# start_quasar_v3.ps1
# QUASAR QAT + Vision launchers (dflash2 / mtp4) for the laptop card.
# Replaces start_quasar_v3_*_for_laptop.bat.
#
# The engine is launched directly instead of via a .bat under cmd.exe, so
# Ctrl-C reaches ninfer-serve.exe without the "Terminate batch job (Y/N)?"
# prompt, and there is no trailing "pause" after a clean exit.
#
# Usage:
#   .\start_quasar_v3.ps1                  # interactive model choice
#   .\start_quasar_v3.ps1 -Spec dflash2    # skip the prompt
#   powershell -NoProfile -ExecutionPolicy Bypass -File start_quasar_v3.ps1

param(
    [ValidateSet('dflash2', 'mtp4')]
    [string]$Spec
)

$ErrorActionPreference = 'Stop'

$Presets = @{
    dflash2 = [pscustomobject]@{
        Spec           = 'dflash2'
        DraftTokens    = 7
        MaxContext     = 45056
        ModelId        = 'qwen3.8-27b-quasar-v3-dflash2-vision'
        MaxTokens      = 6144
        ThinkingBudget = 3072
    }
    mtp4    = [pscustomobject]@{
        Spec           = 'mtp'
        DraftTokens    = 4
        MaxContext     = 65536
        ModelId        = 'qwen3.8-27b-quasar-v3-mtp4-vision'
        MaxTokens      = 6144
        ThinkingBudget = 3072
    }
}

$Port = 8086

function Stop-Launch([string]$Message) {
    Write-Host $Message
    exit 1
}

if (-not $Spec) {
    Write-Host "Choose NInfer model:"
    Write-Host "  1) DFlash2 (default)"
    Write-Host "  2) MTP4"
    $choice = (Read-Host "Selection [1]").Trim()
    if ($choice -eq '2') {
        $Spec = 'mtp4'
    }
    elseif ($choice -eq '1' -or $choice -eq '') {
        $Spec = 'dflash2'
    }
    else {
        Stop-Launch "[ERROR] Invalid selection: $choice"
    }
}

$P = $Presets[$Spec]

# Resolve beside this launcher first, so the released archive is portable wherever it is
# extracted, then fall back to the source tree so the same file works while developing.
$SERVE = Join-Path $PSScriptRoot 'ninfer-serve.exe'
if (-not (Test-Path $SERVE)) { $SERVE = 'C:\AI\ninfer-v3-windows\build\apps\ninfer-serve.exe' }
$MODEL = Join-Path $PSScriptRoot 'models\qwen3_8_27b_nvfp4qat.v3.ninfer'
if (-not (Test-Path $MODEL)) { $MODEL = 'C:\AI\models\qwen3_8_27b_nvfp4qat.v3.ninfer' }

if (-not (Test-Path $SERVE)) {
    Stop-Launch "[ERROR] Engine not found.`n        Expected ninfer-serve.exe beside this launcher,`n        or a source build at C:\AI\ninfer-v3-windows\build\apps\ninfer-serve.exe"
}
if (-not (Test-Path $MODEL)) {
    Stop-Launch "[ERROR] Model artifact not found.`n        Expected $MODEL`n        or C:\AI\models\qwen3_8_27b_nvfp4qat.v3.ninfer`n        Run download_model.bat to fetch it."
}

# --- Preflight ---------------------------------------------------------------------------
# Each check replaces a failure that is otherwise cryptic: a missing FFmpeg DLL makes the
# process exit 0xC0000135 before printing a reason, a busy port yields a bare bind error,
# and a second model on this 32 GB card yields a runtime-reservation FATAL.

$ServeDir = Split-Path $SERVE -Parent
foreach ($D in 'avcodec', 'avformat', 'avutil', 'swscale', 'swresample') {
    if (-not (Get-ChildItem -Path $ServeDir -Filter "$D-*.dll" -ErrorAction SilentlyContinue)) {
        Stop-Launch "[ERROR] FFmpeg runtime DLL missing: $D-*.dll`n        The engine needs all five beside the executable, in:`n            $ServeDir`n        build_windows.bat stages them from the ffmpeg\bin directory it downloads.`n        Without them the engine exits 0xC0000135 without printing a reason."
    }
}

if (netstat -ano | Select-String ":$Port" | Select-String -SimpleMatch 'LISTENING') {
    Stop-Launch "[ERROR] Port $Port is already in use.`n        Something is already listening there. Stop it, or change the --port flag.`n        To see what holds it: netstat -ano | findstr :$Port"
}

if (Get-Process -Name 'ninfer-serve' -ErrorAction SilentlyContinue) {
    Write-Warning "A ninfer-serve.exe process is already running."
    Write-Warning "This card holds one model at a time, so starting another may fail with a"
    Write-Warning "runtime-reservation error, or the running server may stop answering."
    $ans = Read-Host 'Continue anyway? [y/N]'
    if ($ans -notmatch '^[Yy]') { exit 1 }
}

# --- Launch ------------------------------------------------------------------------------
# Foreground call: Ctrl-C is broadcast to this process group and ninfer-serve.exe
# handles it itself; without a cmd.exe batch job there is no "Terminate batch job" prompt.

$ServeArgs = @(
    $MODEL
    '--vision'
    '--spec', $P.Spec
    '--draft-tokens', $P.DraftTokens
    '--lm-head-draft'
    '--host', '127.0.0.1'
    '--port', $Port
    '--model-id', $P.ModelId
    '--max-context', $P.MaxContext
    '--device-state-slots', 1
    '--kv-capacity', 'auto'
    '--kv-dtype', 'fp8'
    '--prefill-chunk', 8192
    '--max-concurrency', 1
    '--host-state-slots', 8
    '--host-kv-mib', 8192
    '--max-shared-prefixes', 7
    '--max-private-continuations', 8
    '--max-long-anchors-per-continuation', 4
    '--preserve-thinking'
    '--default-max-tokens', $P.MaxTokens
    '--default-thinking-budget', $P.ThinkingBudget
    '--pending-timeout-ms', 600000
)

Write-Host "Starting: $SERVE"
Write-Host "Model:    $MODEL"
Write-Host "Spec:     $($P.Spec)  (port $Port)"

& $SERVE @ServeArgs
exit $LASTEXITCODE
