function Get-FolderSize($path) {
    if (!(Test-Path $path)) { return 0 }
    return (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
}

function Format-Size($bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    else { return "$bytes B" }
}

Write-Host "Enter root directory to scan for Flutter projects (Enter = current directory):"
$ROOT_DIR = Read-Host

if ([string]::IsNullOrWhiteSpace($ROOT_DIR)) {
    $ROOT_DIR = (Get-Location).Path
}

if (!(Test-Path $ROOT_DIR)) {
    Write-Host "Directory not found"
    exit
}

Write-Host ""
Write-Host "Using directory: $ROOT_DIR"

Write-Host ""
Write-Host "Calculating folder size..."
$sizeBefore = Get-FolderSize $ROOT_DIR
Write-Host "Size before cleanup: $(Format-Size $sizeBefore)"

Write-Host ""
Write-Host "Searching for Flutter projects..."

$pubspecs = Get-ChildItem -Path $ROOT_DIR -Recurse -Filter pubspec.yaml -ErrorAction SilentlyContinue
$projects = 0

foreach ($pubspec in $pubspecs) {

    $projectDir = $pubspec.Directory.FullName
    Write-Host "Cleaning Flutter project: $projectDir"

    Push-Location $projectDir
    flutter clean
    Pop-Location

    $projects++
}

Write-Host ""
Write-Host "Cleaned $projects Flutter projects"
Write-Host ""

# Flutter pub cache
$choice = Read-Host "Run flutter pub cache clean? (y/n)"
if ($choice -match "^[Yy]") {
    flutter pub cache clean
}

# Paths
$androidStudio = "$env:LOCALAPPDATA\Google\AndroidStudio"
$vscode = "$env:APPDATA\Code"
$cursor = "$env:APPDATA\Cursor"
$gradle = "$env:USERPROFILE\.gradle"
$androidBuild = "$env:LOCALAPPDATA\Android\build-cache"
$emulator = "$env:USERPROFILE\.android\avd"

Write-Host ""
Write-Host "Cache sizes:"
Write-Host "Android Studio: $(Format-Size (Get-FolderSize $androidStudio))"
Write-Host "VS Code: $(Format-Size (Get-FolderSize $vscode))"
Write-Host "Cursor: $(Format-Size (Get-FolderSize $cursor))"
Write-Host "Gradle: $(Format-Size (Get-FolderSize $gradle))"
Write-Host "Android build cache: $(Format-Size (Get-FolderSize $androidBuild))"
Write-Host "Emulator AVD: $(Format-Size (Get-FolderSize $emulator))"

Write-Host ""

$choice = Read-Host "Clean Android Studio cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:LOCALAPPDATA\Google\AndroidStudio*" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean VS Code cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:APPDATA\Code\Cache" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Code\CachedData" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Code\GPUCache" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean Cursor cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:APPDATA\Cursor\Cache" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Cursor\CachedData" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Cursor\GPUCache" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean Gradle caches? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:USERPROFILE\.gradle\caches" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\.gradle\daemon" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\.gradle\native" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean Android build cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$androidBuild" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean emulator snapshots? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:USERPROFILE\.android\avd\*\snapshots" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Checking installed Android NDKs..."

$NDK_PATH = "$env:LOCALAPPDATA\Android\Sdk\ndk"

if (Test-Path $NDK_PATH) {

    $ndks = @()
    $i = 1

    Write-Host "0 - Skip"

    Get-ChildItem $NDK_PATH -Directory | ForEach-Object {
        Write-Host "$i - NDK $($_.Name)"
        $ndks += $_.Name
        $i++
    }

    $ndk_choice = Read-Host "Type number of NDK to remove"

    $num = 0
    if ([int]::TryParse($ndk_choice, [ref]$num) -and $num -ne 0) {

        $index = $num - 1

        if ($index -ge 0 -and $index -lt $ndks.Count) {

            $version = $ndks[$index]
            Remove-Item "$NDK_PATH\$version" -Recurse -Force
            Write-Host "Removed NDK $version"
        }
    }
}

Write-Host ""
Write-Host "Calculating size after cleanup..."

$sizeAfter = Get-FolderSize $ROOT_DIR

Write-Host "Size after cleanup: $(Format-Size $sizeAfter)"

$cleaned = $sizeBefore - $sizeAfter

Write-Host ""
Write-Host "Space cleaned: $(Format-Size $cleaned)"
Write-Host ""
Write-Host "Cleanup finished"
