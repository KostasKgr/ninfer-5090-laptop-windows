@echo off
REM ============================================================================
REM  QUASAR QAT + MTP4 + Vision
REM ============================================================================
setlocal

REM Resolve beside this launcher first, so the released archive is portable wherever it is
REM extracted, then fall back to the source tree so the same file works while developing.
set "SERVE=%~dp0ninfer-serve.exe"
if not exist "%SERVE%" set "SERVE=C:\AI\ninfer-v3-windows\build\apps\ninfer-serve.exe"
set "MODEL=%~dp0models\qwen3_8_27b_nvfp4qat.v3.ninfer"
if not exist "%MODEL%" set "MODEL=C:\AI\models\qwen3_8_27b_nvfp4qat.v3.ninfer"

if not exist "%SERVE%" (
    echo [ERROR] Engine not found.
    echo         Expected ninfer-serve.exe beside this launcher,
    echo         or a source build at C:\AI\ninfer-v3-windows\build\apps\ninfer-serve.exe
    pause
    exit /b 1
)
if not exist "%MODEL%" (
    echo [ERROR] Artifact not found.
    echo         Expected %~dp0models\qwen3_8_27b_nvfp4qat.v3.ninfer
    echo         or C:\AI\models\qwen3_8_27b_nvfp4qat.v3.ninfer
    echo         Run download_model.bat to fetch it.
    pause
    exit /b 1
)

REM --- Preflight ---------------------------------------------------------------------------
REM Each check replaces a failure that is otherwise cryptic: a missing FFmpeg DLL makes the
REM process exit 0xC0000135 before printing a reason, a busy port yields a bare bind error, and
REM a second model on this 32 GB card yields a runtime-reservation FATAL.
for %%F in ("%SERVE%") do set "SERVE_DIR=%%~dpF"

for %%D in (avcodec avformat avutil swscale swresample) do (
    if not exist "%SERVE_DIR%%%D-*.dll" (
        echo [ERROR] FFmpeg runtime DLL missing: %%D-*.dll
        echo         The engine needs all five beside the executable, in:
        echo             %SERVE_DIR%
        echo         build_windows.bat stages them from the ffmpeg\bin directory it downloads.
        echo         Without them the engine exits 0xC0000135 without printing a reason.
        pause
        exit /b 1
    )
)

netstat -ano | findstr ":8086" | findstr /I "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [ERROR] Port 8086 is already in use.
    echo         Something is already listening there. Stop it, or change the --port flag
    echo         in this launcher. To see what holds it:
    echo             netstat -ano ^| findstr ":8086"
    pause
    exit /b 1
)

tasklist /FI "IMAGENAME eq ninfer-serve.exe" 2>nul | find /I "ninfer-serve.exe" >nul
if not errorlevel 1 (
    echo [WARN]  A ninfer-serve.exe process is already running.
    echo         This card holds one model at a time, so starting another may fail with a
    echo         runtime-reservation error, or the running server may stop answering.
    choice /C YN /N /M "Continue anyway? [Y/N] "
    if errorlevel 2 exit /b 1
)

"%SERVE%" "%MODEL%" ^
  --vision ^
  --spec mtp ^
  --draft-tokens 4 ^
  --lm-head-draft ^
  --host 127.0.0.1 ^
  --port 8086 ^
  --model-id qwen3.8-27b-quasar-v3-mtp4-vision ^
   --max-context 65536 ^
  --device-state-slots 1 ^
  --kv-capacity auto ^
  --kv-dtype fp8 ^
  --prefill-chunk 8192 ^
  --max-concurrency 1 ^
  --host-state-slots 8 ^
  --host-kv-mib 8192 ^
  --max-shared-prefixes 7 ^
  --max-private-continuations 8 ^
  --max-long-anchors-per-continuation 4 ^
  --preserve-thinking ^
  --default-max-tokens 4096 ^
  --default-thinking-budget 3072 ^
  --pending-timeout-ms 600000

pause
