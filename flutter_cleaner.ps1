function Get-FolderSize($path) {
    if (!(Test-Path $path)) { return 0 }
    return (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
}

Write-Host "Enter root directory to scan for Flutter projects:"
$ROOT_DIR = Read-Host

if (!(Test-Path $ROOT_DIR)) {
    Write-Host "Directory not found"
    exit
}

Write-Host ""
Write-Host "Calculating folder size before cleanup..."

$sizeBefore = Get-FolderSize $ROOT_DIR

Write-Host ("Size before cleanup: {0:N2} GB" -f ($sizeBefore / 1GB))

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

$choice = Read-Host "Run flutter pub cache clean? (y/n)"
if ($choice -match "^[Yy]") {
    flutter pub cache clean
}

Write-Host ""

$choice = Read-Host "Clean Android Studio cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:LOCALAPPDATA\Google\AndroidStudio*" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean VS Code cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:APPDATA\Code\Cache" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Code\CachedData" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean Cursor cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:APPDATA\Cursor\Cache" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Cursor\CachedData" -Recurse -Force -ErrorAction SilentlyContinue
}

$choice = Read-Host "Clean Android / Gradle cache? (y/n)"
if ($choice -match "^[Yy]") {
    Remove-Item "$env:USERPROFILE\.gradle\caches" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Checking installed Android NDKs..."
Write-Host ""

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

    $ndk_choice = Read-Host "Type number of NDK to remove (0 to skip)"

    $ndk_num = 0
    if ([int]::TryParse($ndk_choice, [ref]$ndk_num) -and $ndk_num -ne 0) {
        $index = $ndk_num - 1
        if ($index -ge 0 -and $index -lt $ndks.Count) {
            $version = $ndks[$index]
            Remove-Item "$NDK_PATH\$version" -Recurse -Force
            Write-Host "Removed NDK $version"
        }
    }
}

Write-Host ""
Write-Host "Calculating folder size after cleanup..."

$sizeAfter = Get-FolderSize $ROOT_DIR

Write-Host ("Size after cleanup: {0:N2} GB" -f ($sizeAfter / 1GB))

$cleaned = $sizeBefore - $sizeAfter

Write-Host ""
Write-Host ("Space cleaned: {0:N2} GB ({1:N2} MB)" -f ($cleaned / 1GB), ($cleaned / 1MB))

Write-Host ""
Write-Host "Cleanup finished"
