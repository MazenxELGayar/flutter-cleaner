# Flutter / IDE / cache cleanup — interactive multi-select (same UX as doctor_voice_doctor/scripts/build_all.ps1).
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\flutter_cleaner.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\flutter_cleaner.ps1

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

function Select-Multiple {
    param(
        [string[]]$Items,
        [string]$Title
    )

    $selected = @()
    for ($i = 0; $i -lt $Items.Count; $i++) { $selected += $false }

    $index = 0

    while ($true) {

        Clear-Host
        Write-Host $Title
        Write-Host "Arrows: move | Space: toggle | Enter: confirm"
        Write-Host ""

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $cursor = if ($i -eq $index) { ">" } else { " " }
            $check = if ($selected[$i]) { "[x]" } else { "[ ]" }
            Write-Host "$cursor $check $($Items[$i])"
        }

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        if ($key.VirtualKeyCode -eq 38 -and $index -gt 0) { $index-- }
        elseif ($key.VirtualKeyCode -eq 40 -and $index -lt ($Items.Count - 1)) { $index++ }
        elseif ($key.VirtualKeyCode -eq 32) { $selected[$index] = -not $selected[$index] }
        elseif ($key.VirtualKeyCode -eq 13) { break }
    }

    $result = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($selected[$i]) { $result += $i }
    }

    return $result
}

function Get-FvmVersionsRoot {
    if ($env:FVM_HOME) {
        return (Join-Path $env:FVM_HOME 'versions')
    }
    return (Join-Path $env:USERPROFILE 'fvm\versions')
}

function Get-FvmExe {
    $c = Get-Command fvm.exe -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $c = Get-Command fvm -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

function Remove-FvmVersionSafe {
    param([Parameter(Mandatory)][string]$VersionName)

    $fvmExe = Get-FvmExe
    if ($fvmExe) {
        Write-Host "  fvm remove $VersionName"
        & $fvmExe remove $VersionName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  fvm remove failed (exit $LASTEXITCODE). Trying folder delete..." -ForegroundColor Yellow
        }
        else {
            return
        }
    }

    $dir = Join-Path (Get-FvmVersionsRoot) $VersionName
    if (Test-Path $dir) {
        Write-Host "  Removing folder: $dir"
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- paths ---
$androidStudioRoot = "$env:LOCALAPPDATA\Google"
$vscode = "$env:APPDATA\Code"
$cursor = "$env:APPDATA\Cursor"
$gradle = "$env:USERPROFILE\.gradle"
$androidBuild = "$env:LOCALAPPDATA\Android\build-cache"
$emulator = "$env:USERPROFILE\.android\avd"
$NDK_PATH = "$env:LOCALAPPDATA\Android\Sdk\ndk"

Write-Host "Enter root directory to scan for Flutter projects (Enter = current directory):"
$ROOT_DIR = Read-Host

if ([string]::IsNullOrWhiteSpace($ROOT_DIR)) {
    $ROOT_DIR = (Get-Location).Path
}

if (!(Test-Path $ROOT_DIR)) {
    Write-Host "Directory not found"
    exit 1
}

Write-Host ""
Write-Host "Using directory: $ROOT_DIR"
Write-Host "Gathering sizes (may take a moment)..."

$asSize = 0
Get-ChildItem $androidStudioRoot -Directory -Filter "AndroidStudio*" -ErrorAction SilentlyContinue | ForEach-Object {
    $asSize += (Get-FolderSize $_.FullName)
}

$fvmVersionsRoot = Get-FvmVersionsRoot
$fvmDirs = @(Get-ChildItem $fvmVersionsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
$fvmTotal = 0
foreach ($d in $fvmDirs) { $fvmTotal += (Get-FolderSize $d.FullName) }

$ndkDirs = @()
if (Test-Path $NDK_PATH) {
    $ndkDirs = @(Get-ChildItem $NDK_PATH -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
}

$szGradle = Format-Size (Get-FolderSize $gradle)
$szAndroidBuild = Format-Size (Get-FolderSize $androidBuild)
$szVscode = Format-Size (Get-FolderSize $vscode)
$szCursor = Format-Size (Get-FolderSize $cursor)
$szEmulator = Format-Size (Get-FolderSize $emulator)
$szAs = Format-Size $asSize
$szFvmTotal = Format-Size $fvmTotal
$fvmCount = $fvmDirs.Count
$ndkCount = $ndkDirs.Count

$menuItems = @(
    @{ id = 'flutter_projects'; label = 'Flutter projects: flutter clean (all pubspec.yaml under root)' }
    @{ id = 'pub_cache';        label = 'Flutter pub cache clean (flutter pub cache clean)' }
    @{ id = 'gradle';           label = "Gradle: caches + daemon + native ($szGradle)" }
    @{ id = 'android_build';    label = "Android build cache ($szAndroidBuild)" }
    @{ id = 'vscode';           label = "VS Code: Cache + CachedData + GPUCache only ($szVscode app dir)" }
    @{ id = 'cursor';           label = "Cursor: Cache + CachedData + GPUCache only ($szCursor app dir)" }
    @{ id = 'as';               label = "Android Studio: safe caches only ($szAs under AndroidStudio*)" }
    @{ id = 'emulator';         label = "Emulator AVD snapshots only ($szEmulator AVD dir)" }
    @{ id = 'fvm';              label = "FVM: remove selected SDK(s) - $szFvmTotal in $fvmCount version(s) under $fvmVersionsRoot" }
    @{ id = 'ndk';             label = "Android NDK: remove selected folder(s) - $ndkCount under Sdk\ndk" }
)

$labels = @($menuItems | ForEach-Object { $_.label })
$selectedIndexes = Select-Multiple -Items $labels -Title "Select cleanups to run"

if ($selectedIndexes.Count -eq 0) {
    Write-Host ""
    Write-Host "Nothing selected. Exiting."
    exit 0
}

$selectedIds = @{}
foreach ($i in $selectedIndexes) {
    $selectedIds[$menuItems[$i].id] = $true
}

Write-Host ""
Write-Host "Calculating folder size under root (before)..."
$sizeBefore = Get-FolderSize $ROOT_DIR
Write-Host "Size before (root tree): $(Format-Size $sizeBefore)"

# --- run in stable order (not menu index order) ---
$runOrder = @(
    'flutter_projects',
    'pub_cache',
    'gradle',
    'android_build',
    'vscode',
    'cursor',
    'as',
    'emulator',
    'fvm',
    'ndk'
)

foreach ($id in $runOrder) {
    if (-not $selectedIds[$id]) { continue }

    switch ($id) {

        'flutter_projects' {
            Write-Host ""
            Write-Host "=== Flutter: flutter clean under root ==="
            $pubspecs = Get-ChildItem -Path $ROOT_DIR -Recurse -Filter pubspec.yaml -ErrorAction SilentlyContinue
            $n = 0
            foreach ($pubspec in $pubspecs) {
                $projectDir = $pubspec.Directory.FullName
                Write-Host "  $projectDir"
                Push-Location $projectDir
                try {
                    $fvm = Get-FvmExe
                    if ($fvm) {
                        & $fvm flutter clean
                    }
                    else {
                        flutter clean
                    }
                }
                finally {
                    Pop-Location
                }
                $n++
            }
            Write-Host "  Done ($n project(s))."
        }

        'pub_cache' {
            Write-Host ""
            Write-Host "=== Flutter pub cache clean ==="
            $fvm = Get-FvmExe
            if ($fvm) {
                & $fvm flutter pub cache clean
            }
            else {
                flutter pub cache clean
            }
        }

        'gradle' {
            Write-Host ""
            Write-Host "=== Gradle (caches, daemon, native) ==="
            foreach ($rel in @('caches', 'daemon', 'native')) {
                $p = Join-Path $gradle $rel
                if (Test-Path $p) {
                    Write-Host "  Removing: $p"
                    Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        'android_build' {
            Write-Host ""
            Write-Host "=== Android build cache ==="
            if (Test-Path $androidBuild) {
                Write-Host "  Removing: $androidBuild"
                Remove-Item $androidBuild -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        'vscode' {
            Write-Host ""
            Write-Host "=== VS Code cache folders ==="
            foreach ($rel in @('Cache', 'CachedData', 'GPUCache')) {
                $p = Join-Path $vscode $rel
                if (Test-Path $p) {
                    Write-Host "  Removing: $p"
                    Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        'cursor' {
            Write-Host ""
            Write-Host "=== Cursor cache folders ==="
            foreach ($rel in @('Cache', 'CachedData', 'GPUCache')) {
                $p = Join-Path $cursor $rel
                if (Test-Path $p) {
                    Write-Host "  Removing: $p"
                    Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        'as' {
            Write-Host ""
            Write-Host "=== Android Studio (safe cache paths) ==="
            Get-ChildItem $androidStudioRoot -Directory -Filter "AndroidStudio*" -ErrorAction SilentlyContinue | ForEach-Object {
                $root = $_.FullName
                $targets = @(
                    (Join-Path $root 'caches')
                    (Join-Path $root 'system\caches')
                    (Join-Path $root 'system\compile-server')
                    (Join-Path $root 'log')
                    (Join-Path $root 'logs')
                )
                foreach ($p in $targets) {
                    if (Test-Path $p) {
                        Write-Host "  Removing: $p"
                        Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }

        'emulator' {
            Write-Host ""
            Write-Host "=== Emulator snapshots ==="
            Get-ChildItem "$emulator\*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $snap = Join-Path $_.FullName 'snapshots'
                if (Test-Path $snap) {
                    Write-Host "  Removing: $snap"
                    Remove-Item $snap -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        'fvm' {
            Write-Host ""
            Write-Host "=== FVM SDK versions ==="
            $dirs = @(Get-ChildItem (Get-FvmVersionsRoot) -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
            if ($dirs.Count -eq 0) {
                Write-Host "  No versions under $(Get-FvmVersionsRoot)"
            }
            else {
                $vLabels = @($dirs | ForEach-Object {
                    $sz = Format-Size (Get-FolderSize $_.FullName)
                    "$($_.Name)  ($sz)"
                })
                $picked = Select-Multiple -Items $vLabels -Title "Select FVM SDK(s) to REMOVE (Space = toggle)"
                foreach ($pi in $picked) {
                    $ver = $dirs[$pi].Name
                    Write-Host "  Removing FVM version: $ver"
                    Remove-FvmVersionSafe -VersionName $ver
                }
            }
        }

        'ndk' {
            Write-Host ""
            Write-Host "=== Android NDK folders ==="
            if ($ndkDirs.Count -eq 0) {
                Write-Host "  Nothing under $NDK_PATH"
            }
            else {
                $ndkLabels = @($ndkDirs | ForEach-Object {
                    $sz = Format-Size (Get-FolderSize $_.FullName)
                    "$($_.Name)  ($sz)"
                })
                $pickedNdk = Select-Multiple -Items $ndkLabels -Title "Select NDK folder(s) to REMOVE"
                foreach ($ni in $pickedNdk) {
                    $folder = $ndkDirs[$ni].FullName
                    Write-Host "  Removing: $folder"
                    Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

Write-Host ""
Write-Host "Calculating size under root (after)..."
$sizeAfter = Get-FolderSize $ROOT_DIR
Write-Host "Size after (root tree): $(Format-Size $sizeAfter)"
$cleaned = $sizeBefore - $sizeAfter
Write-Host "Delta (root only): $(Format-Size $cleaned)"
Write-Host ""
Write-Host "Done."
