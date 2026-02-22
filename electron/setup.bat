@echo off
echo ==========================================
echo   AuraBot Electron - Setup
echo ==========================================
echo.

REM Check for Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed!
    echo.
    echo Please install Node.js 18+ from https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo [1/3] Node.js version:
node --version
echo.

echo [2/3] Installing dependencies...
call npm install
if errorlevel 1 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo.

echo [3/3] Checking Go backend...
if exist "..\go\aurabot.exe" (
    echo Found existing backend, copying...
    copy /Y "..\go\aurabot.exe" "build\aurabot-backend.exe"
) else (
    echo [WARNING] Go backend not found!
    echo Please compile it first:
    echo   cd ..\go ^&^& go build -o aurabot.exe .
    echo.
    echo Or run: make build-go from the root directory
)
echo.

echo ==========================================
echo   Setup complete!
echo ==========================================
echo.
echo To start the app in development mode:
echo   npm run dev:win
echo.
echo To build for production:
echo   npm run build:win
echo.
pause
