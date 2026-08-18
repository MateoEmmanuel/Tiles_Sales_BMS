#!/bin/bash

# ============================================================================
# Tiles Selling BMS - macOS/Linux Setup Script
# ============================================================================
# This script automatically sets up the Flutter project with all dependencies
# It will:
#   1. Check if Flutter is installed
#   2. Check if Node.js is installed
#   3. Install Flutter dependencies
#   4. Install Firebase CLI tools
# ============================================================================

set -e

echo ""
echo "============================================================================"
echo "Tiles Selling BMS - Automatic Setup"
echo "============================================================================"
echo ""

# Check for Flutter
echo "Checking for Flutter..."
if ! command -v flutter &> /dev/null; then
    echo ""
    echo "ERROR: Flutter is not installed or not in PATH!"
    echo ""
    echo "Please install Flutter first from: https://flutter.dev/docs/get-started/install"
    echo ""
    exit 1
else
    echo "✓ Flutter found!"
    flutter --version
fi

echo ""
echo "Checking for Dart..."
if ! command -v dart &> /dev/null; then
    echo "ERROR: Dart not found! It should come with Flutter."
    exit 1
else
    echo "✓ Dart found!"
fi

echo ""
echo "Checking for Node.js..."
if ! command -v node &> /dev/null; then
    echo "WARNING: Node.js not found. Firebase CLI installation may fail."
    echo "Consider installing Node.js from: https://nodejs.org/"
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✓ Node.js found!"
    node --version
fi

echo ""
echo "============================================================================"
echo "Installing Flutter dependencies..."
echo "============================================================================"
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Running: flutter pub get"
flutter pub get

echo ""
echo "✓ Flutter dependencies installed!"

echo ""
echo "============================================================================"
echo "Installing Firebase CLI..."
echo "============================================================================"
echo ""

echo "Checking if npm is available..."
if ! command -v npm &> /dev/null; then
    echo "WARNING: npm not found. Skipping Firebase CLI installation."
    echo "You can install it later using: npm install -g firebase-tools"
else
    echo "Installing firebase-tools globally..."
    npm install -g firebase-tools || {
        echo "WARNING: Failed to install firebase-tools, but project setup is complete."
        echo "You can install it manually later using: npm install -g firebase-tools"
    }
fi

echo ""
echo "============================================================================"
echo "Installing FlutterFire CLI..."
echo "============================================================================"
echo ""

echo "Running: dart pub global activate flutterfire_cli"
dart pub global activate flutterfire_cli || {
    echo "WARNING: Failed to install flutterfire_cli"
    echo "You can install it manually later using: dart pub global activate flutterfire_cli"
}

echo ""
echo "============================================================================"
echo "Setup Complete!"
echo "============================================================================"
echo ""
echo "Next steps:"
echo "1. Open Firebase Console: https://console.firebase.google.com"
echo "2. Ensure your project has Firestore (not Realtime Database)"
echo "3. Run: flutterfire configure --project=tiles-selling-bms"
echo "4. Run the app: flutter run"
echo ""
echo "For more details, see: DATABASE_CONNECTION_SETUP.md"
echo ""
