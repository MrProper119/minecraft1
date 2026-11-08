<#
.SYNOPSIS
  Автоматична синхронізація модів та конфігурацій для Minecraft 1.21.1 NeoForge.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Minecraft Modpack Synchronizer"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "     Синхронізація модпаку Minecraft 1.21.1 NeoForge" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

$repoRoot = $PSScriptRoot
$modsDir = Join-Path $repoRoot "mods"
$configDir = Join-Path $repoRoot "config"
$defaultConfigsDir = Join-Path $repoRoot "defaultconfigs"

# Визначаємо цільову папку Minecraft
$targetGameDir = $null
$defaultTLauncherVer = Join-Path $env:APPDATA ".minecraft\versions\2"

if ($repoRoot -like "*\.minecraft\versions\*") {
    $targetGameDir = $repoRoot
} elseif (Test-Path $defaultTLauncherVer) {
    $targetGameDir = $defaultTLauncherVer
} else {
    Write-Host "[!] Папку гри за замовчуванням ($defaultTLauncherVer) не знайдено." -ForegroundColor Yellow
    $inputPath = Read-Host "Введіть шлях до вашої версії Minecraft у лаунчері"
    if ($inputPath -and (Test-Path $inputPath)) {
        $targetGameDir = $inputPath
    } else {
        Write-Host "[-] Вказаний шлях не знайдено. Зупинка." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[*] Цільова папка гри: $targetGameDir" -ForegroundColor Green
Write-Host ""

# 1. Синхронізація конфігів та скриптів KubeJS
Write-Host "[1/3] Оновлення конфігураційних файлів та KubeJS..." -ForegroundColor Yellow
if ($targetGameDir -ne $repoRoot) {
    $targetConfig = Join-Path $targetGameDir "config"
    if (Test-Path $configDir) {
        if (-not (Test-Path $targetConfig)) { New-Item -ItemType Directory -Path $targetConfig -Force | Out-Null }
        Copy-Item -Path "$configDir\*" -Destination $targetConfig -Recurse -Force
    }
    $targetDefaultConfigs = Join-Path $targetGameDir "defaultconfigs"
    if (Test-Path $defaultConfigsDir) {
        if (-not (Test-Path $targetDefaultConfigs)) { New-Item -ItemType Directory -Path $targetDefaultConfigs -Force | Out-Null }
        Copy-Item -Path "$defaultConfigsDir\*" -Destination $targetDefaultConfigs -Recurse -Force
    }
    $kubejsDir = Join-Path $repoRoot "kubejs"
    $targetKubejs = Join-Path $targetGameDir "kubejs"
    if (Test-Path $kubejsDir) {
        if (-not (Test-Path $targetKubejs)) { New-Item -ItemType Directory -Path $targetKubejs -Force | Out-Null }
        Copy-Item -Path "$kubejsDir\*" -Destination $targetKubejs -Recurse -Force
    }
}
Write-Host "      Конфігурації успішно оновлено!" -ForegroundColor Green
Write-Host ""

# 2. Синхронізація модів
Write-Host "[2/3] Перевірка та завантаження модів..." -ForegroundColor Yellow
$targetMods = Join-Path $targetGameDir "mods"
if (-not (Test-Path $targetMods)) { New-Item -ItemType Directory -Path $targetMods -Force | Out-Null }

$pwFiles = Get-ChildItem -Path $modsDir -Filter "*.pw.toml"
$totalMods = $pwFiles.Count
$currentMod = 0
$validFilenames = @{}

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Packwiz-Sync/1.0 (Windows NT 10.0; Win64; x64)")

foreach ($pw in $pwFiles) {
    $currentMod++
    $content = Get-Content $pw.FullName -Raw

    $filenameMatch = [regex]::Match($content, 'filename\s*=\s*"([^"]+)"')
    if (-not $filenameMatch.Success) { continue }
    $modFilename = $filenameMatch.Groups[1].Value

    # Визначаємо URL для завантаження
    $modUrl = $null
    $urlMatch = [regex]::Match($content, 'url\s*=\s*"([^"]+)"')
    if ($urlMatch.Success) {
        $modUrl = $urlMatch.Groups[1].Value
    } else {
        $fileIdMatch = [regex]::Match($content, 'file-id\s*=\s*(\d+)')
        if ($fileIdMatch.Success) {
            $fileId = [int64]$fileIdMatch.Groups[1].Value
            $part1 = [Math]::Floor($fileId / 1000)
            $part2 = $fileId % 1000
            $safeName = [System.Uri]::EscapeDataString($modFilename)
            $modUrl = "https://edge.forgecdn.net/files/$part1/$part2/$safeName"
        }
    }

    $hashMatch = [regex]::Match($content, 'hash\s*=\s*"([^"]+)"')
    $expectedHash = if ($hashMatch.Success) { $hashMatch.Groups[1].Value.ToLower() } else { $null }

    $formatMatch = [regex]::Match($content, 'hash-format\s*=\s*"([^"]+)"')
    $hashFormat = if ($formatMatch.Success) { $formatMatch.Groups[1].Value.ToUpper() } else { "SHA1" }
    if ($hashFormat -eq "SHA-1") { $hashFormat = "SHA1" }
    if ($hashFormat -eq "SHA-512") { $hashFormat = "SHA512" }
    if ($hashFormat -eq "SHA-256") { $hashFormat = "SHA256" }

    $validFilenames[$modFilename.ToLower()] = $true

    $destPath = Join-Path $targetMods $modFilename
    $needDownload = $false

    if (-not (Test-Path $destPath)) {
        $needDownload = $true
    } elseif ($expectedHash) {
        $actualHash = (Get-FileHash -Path $destPath -Algorithm $hashFormat).Hash.ToLower()
        if ($actualHash -ne $expectedHash) {
            $needDownload = $true
        }
    }

    if ($needDownload) {
        $repoJarPath = Join-Path $modsDir $modFilename
        if (($targetGameDir -ne $repoRoot) -and (Test-Path -LiteralPath $repoJarPath)) {
            Write-Host "  [$currentMod/$totalMods] Копіювання з репозиторію: $modFilename" -ForegroundColor Cyan
            Copy-Item -LiteralPath $repoJarPath -Destination $destPath -Force
        } elseif ($modUrl) {
            Write-Host "  [$currentMod/$totalMods] Завантаження: $modFilename" -ForegroundColor Cyan
            try {
                $wc.DownloadFile($modUrl, $destPath)
            } catch {
                curl.exe -fSL -s "$modUrl" -o "$destPath"
            }
        }
    }
}
Write-Host "      Всі моди перевірено та актуалізовано!" -ForegroundColor Green
Write-Host ""

# 3. Видалення застарілих / вилучених модів
Write-Host "[3/3] Перевірка застарілих модів..." -ForegroundColor Yellow
$installedJars = Get-ChildItem -Path $targetMods -Filter "*.jar"
$removedCount = 0
$backupDir = Join-Path $targetGameDir "mods_backup"

foreach ($jar in $installedJars) {
    if (-not $validFilenames.ContainsKey($jar.Name.ToLower())) {
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        Write-Host "  [-] Переміщено у backup: $($jar.Name)" -ForegroundColor Magenta
        Move-Item -Path $jar.FullName -Destination (Join-Path $backupDir $jar.Name) -Force
        $removedCount++
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  Синхронізацію успішно завершено!" -ForegroundColor Green
Write-Host "  Активних модів у збірці: $totalMods" -ForegroundColor Green
if ($removedCount -gt 0) {
    Write-Host "  Застарілих/зайвих модів переміщено в backup: $removedCount" -ForegroundColor Yellow
}
Write-Host "  Тепер можна запускати Minecraft у TLauncher!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
