# Tiles Selling BMS - Setup Instructions

This document provides step-by-step instructions for setting up the Tiles Selling Business Management System on a new computer.

## Quick Start (Automated)

### Windows Users
Simply double-click the `setup.bat` file in the project root directory and follow the prompts:
```
setup.bat
```

### macOS/Linux Users
Open Terminal in the project directory and run:
```bash
bash setup.sh
```

The script will automatically:
- ✅ Verify Flutter installation
- ✅ Install project dependencies
- ✅ Install Firebase CLI tools
- ✅ Install FlutterFire CLI

---

## Manual Setup (If Automated Setup Doesn't Work)

### Prerequisites
Before you begin, ensure you have installed:

1. **Flutter SDK** (includes Dart)
   - Download from: https://flutter.dev/docs/get-started/install
   - Follow platform-specific installation instructions
   - Verify installation:
     ```
     flutter --version
     dart --version
     ```

2. **Node.js & npm**
   - Download from: https://nodejs.org/
   - Verify installation:
     ```
     node --version
     npm --version
     ```

3. **Git** (optional, but recommended)
   - Download from: https://git-scm.com/

### Step 1: Install Flutter Dependencies
Navigate to the project directory and run:
```bash
flutter pub get
```

### Step 2: Install Firebase Tools
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

### Step 3: Authenticate with Firebase
```bash
firebase login
```

### Step 4: Configure Firebase for the Project
```bash
flutterfire configure --project=tiles-selling-bms
```

This will generate the `firebase_options.dart` file with your project credentials.

### Step 5: Run the App
```bash
flutter run
```

---

## Troubleshooting

### "Flutter not found" Error
**Solution:** 
- Ensure Flutter is installed
- Add Flutter to your system PATH
- Restart your terminal/command prompt

### "firebase login" shows an error
**Solution:**
- Ensure you're using the correct Google account that owns the Firebase project
- Check your internet connection
- Try running: `firebase login --no-localhost`

### "flutterfire configure" fails
**Solution:**
- Ensure Firebase CLI is authenticated: `firebase login`
- Verify the project ID is correct: `tiles-selling-bms`
- Check that your Firebase project has Firestore enabled (not just Realtime Database)

### Build fails with Android/iOS errors
**Solution:**
- Run `flutter clean` and try again
- Update Flutter: `flutter upgrade`
- Check platform-specific setup: `flutter doctor`

### "Firestore connection fails" at runtime
**Solution:**
- Verify `firebase_options.dart` has correct credentials
- Check Firebase security rules aren't too restrictive
- Ensure the device/emulator has internet connection
- View detailed logs in the Connection Status Screen UI

---

## Project Structure

```
tiles_selling_bms/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── services/
│   │   ├── firebase_service.dart          # Firebase connection service
│   │   └── firebase_options.dart          # Firebase configuration (auto-generated)
│   └── screens/
│       └── connection_status_screen.dart  # Connection status UI
├── android/                               # Android-specific code
├── ios/                                   # iOS-specific code
├── windows/                               # Windows-specific code
├── macos/                                 # macOS-specific code
├── linux/                                 # Linux-specific code
├── web/                                   # Web-specific code
├── pubspec.yaml                           # Flutter dependencies
├── setup.bat                              # Windows setup script
├── setup.sh                               # macOS/Linux setup script
├── DATABASE_CONNECTION_SETUP.md           # Firebase connection guide
└── README.md                              # Project overview
```

---

## Environment Variables (Optional)

You can set environment variables for faster setup:

### Windows (PowerShell)
```powershell
$env:FLUTTER_HOME = "C:\path\to\flutter"
$env:PATH += ";$env:FLUTTER_HOME\bin"
```

### macOS/Linux (Bash)
```bash
export FLUTTER_HOME="/path/to/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"
```

---

## What Gets Installed

| Component | Purpose | Version |
|-----------|---------|---------|
| Flutter SDK | UI framework | Latest |
| Dart SDK | Programming language | Included with Flutter |
| Firebase Core | Backend initialization | ^3.1.0 |
| Cloud Firestore | Database | ^5.0.0 |
| Firebase CLI | Firebase management | Latest |
| FlutterFire CLI | Flutter-Firebase integration | ^1.4.1 |

---

## Next Steps After Setup

1. **Configure Firebase Credentials**
   - Run: `flutterfire configure --project=tiles-selling-bms`
   - Select platforms you need (Android, iOS, Web, etc.)

2. **Verify Database Connection**
   - Run: `flutter run`
   - Check the Connection Status Screen for green indicator
   - Review logs for any errors

3. **Explore the Codebase**
   - Start with `lib/main.dart`
   - Review `DATABASE_CONNECTION_SETUP.md` for architecture details
   - Check `Important-notes.txt` for system requirements

4. **Begin Development**
   - Create feature branches: `git checkout -b feature/your-feature`
   - Implement features based on requirements
   - Push changes: `git push origin feature/your-feature`

---

## Support & Documentation

- **Flutter Docs:** https://flutter.dev/docs
- **Firebase Docs:** https://firebase.google.com/docs
- **Dart Docs:** https://dart.dev/guides
- **Project Notes:** See `Important-notes.txt` for system requirements

---

## System Requirements

### Minimum
- **RAM:** 4GB
- **Disk Space:** 2GB for Flutter SDK + project files
- **OS:** Windows 7+, macOS 10.11+, Ubuntu 16.04+

### Recommended
- **RAM:** 8GB
- **Disk Space:** 5GB
- **OS:** Windows 10+, macOS 11+, Ubuntu 20.04+

---

**Last Updated:** 2026-08-19
**Status:** Ready for deployment
