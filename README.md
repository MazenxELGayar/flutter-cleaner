# flutter-cleaner

A PowerShell script to clean Flutter projects and free up disk space on Windows.

## Features

- Calculates disk space used before and after cleanup
- Recursively finds all Flutter projects and runs `flutter clean`
- Optionally cleans the Flutter pub cache (`flutter pub cache clean`)
- Optionally cleans Android Studio cache
- Optionally cleans VS Code cache
- Optionally cleans Cursor editor cache
- Optionally cleans Android / Gradle cache
- Lists installed Android NDKs and allows removing a selected version
- Shows total space saved

## Usage

1. Open PowerShell
2. Run the script:

```powershell
.\flutter_cleaner.ps1
```

3. Enter the root directory to scan for Flutter projects when prompted
4. Follow the interactive prompts to choose which caches to clean