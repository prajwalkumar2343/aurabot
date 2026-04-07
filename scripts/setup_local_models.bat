@echo off
REM Setup script for local models on Windows

echo ==========================================
echo Local Models Setup
echo ==========================================
echo.

REM Check Python
echo [1/3] Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH
    echo Please install Python 3.9+ from https://python.org
    exit /b 1
)
echo [OK] Python is available

REM Install dependencies
echo.
echo [2/3] Installing dependencies...
pip install -q torch transformers pillow numpy sentencepiece protobuf huggingface_hub accelerate
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies
    exit /b 1
)
echo [OK] Dependencies installed

REM Download models
echo.
echo [3/3] Downloading models...
python download_models.py
if errorlevel 1 (
    echo [ERROR] Failed to download models
    exit /b 1
)

echo.
echo ==========================================
echo Setup complete!
echo ==========================================
echo.
echo You can now run the server:
echo   python local_model_server.py   (API only)
echo   python mem0_local.py           (with Mem0)
echo.
pause
