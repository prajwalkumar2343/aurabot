@echo off
echo ==========================================
echo   AuraBot Electron - Windows Build Script
echo ==========================================
echo.

REM Check for Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed!
    echo Please install Node.js from https://nodejs.org/
    exit /b 1
)

echo [1/4] Installing dependencies...
call npm install
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies
    exit /b 1
)

echo.
echo [2/4] Compiling Go backend...
if exist "..\go\aurabot.exe" (
    echo Found existing backend, copying...
    copy /Y "..\go\aurabot.exe" "build\aurabot-backend.exe"
) else (
    echo Building Go backend...
    cd ..\go
    go build -o ..\electron\build\aurabot-backend.exe .
    cd ..\electron
)

if not exist "build\aurabot-backend.exe" (
    echo [ERROR] Failed to build Go backend
    exit /b 1
)

echo.
echo [3/4] Building Electron app...
call npm run build:win
if errorlevel 1 (
    echo [ERROR] Failed to build Electron app
    exit /b 1
)

echo.
echo [4/4] Build complete!
echo.
echo Output files:
echo   - dist\AuraBot Setup 1.0.0.exe (Installer)
echo   - dist\AuraBot-Portable-1.0.0.exe (Portable)
echo.
pause
