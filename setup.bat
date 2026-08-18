@echo off
REM ============================================================================
REM Tiles Selling BMS - Windows Setup Script
REM ============================================================================
REM This script automatically sets up the Flutter project with all dependencies
REM It will:
REM   1. Check if Flutter is installed
REM   2. Check if Node.js is installed
REM   3. Install Flutter dependencies
REM   4. Install Firebase CLI tools
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ============================================================================
echo Tiles Selling BMS - Automatic Setup
echo ============================================================================
echo.

REM Check for Flutter
echo Checking for Flutter...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Flutter is not installed or not in PATH!
    echo.
    echo Please install Flutter first from: https://flutter.dev/docs/get-started/install
    echo After installation, make sure flutter is added to your system PATH
    echo.
    pause
    exit /b 1
) else (
    echo ✓ Flutter found!
    flutter --version
)

echo.
echo Checking for Dart...
dart --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Dart not found! It should come with Flutter.
    pause
    exit /b 1
) else (
    echo ✓ Dart found!
)

echo.
echo Checking for Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo WARNING: Node.js not found. Firebase CLI installation may fail.
    echo Consider installing Node.js from: https://nodejs.org/
    echo.
    set /p continue="Continue anyway? (y/n): "
    if /i not "!continue!"=="y" exit /b 1
) else (
    echo ✓ Node.js found!
    node --version
)

echo.
echo ============================================================================
echo Installing Flutter dependencies...
echo ============================================================================
echo.

cd /d "%~dp0"

echo Running: flutter pub get
flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to get dependencies!
    pause
    exit /b 1
)

echo.
echo ✓ Flutter dependencies installed!

echo.
echo ============================================================================
echo Installing Firebase CLI...
echo ============================================================================
echo.

echo Checking if npm is available...
npm --version >nul 2>&1
if errorlevel 1 (
    echo WARNING: npm not found. Skipping Firebase CLI installation.
    echo You can install it later using: npm install -g firebase-tools
) else (
    echo Installing firebase-tools globally...
    npm install -g firebase-tools
    if errorlevel 1 (
        echo WARNING: Failed to install firebase-tools, but project setup is complete.
        echo You can install it manually later using: npm install -g firebase-tools
    ) else (
        echo ✓ Firebase CLI installed!
    )
)

echo.
echo ============================================================================
echo Installing FlutterFire CLI...
echo ============================================================================
echo.

echo Running: dart pub global activate flutterfire_cli
dart pub global activate flutterfire_cli
if errorlevel 1 (
    echo WARNING: Failed to install flutterfire_cli
    echo You can install it manually later using: dart pub global activate flutterfire_cli
) else (
    echo ✓ FlutterFire CLI installed!
)

echo.
echo ============================================================================
echo Setup Complete!
echo ============================================================================
echo.
echo Next steps:
echo 1. Open Firebase Console: https://console.firebase.google.com
echo 2. Ensure your project has Firestore (not Realtime Database)
echo 3. Run: flutterfire configure --project=tiles-selling-bms
echo 4. Run the app: flutter run
echo.
echo For more details, see: DATABASE_CONNECTION_SETUP.md
echo.

pause
