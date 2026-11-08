param(
    [switch]$FromTLauncher
)

[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Синхронізація збірки Minecraft (GitHub -> TLauncher)"

$RepoUrl = "https://github.com/MrProper119/minecraft1.git"
$ApiBase = "https://api.github.com/repos/MrProper119/minecraft1"
$MinecraftRoot = Join-Path $env:APPDATA ".minecraft"
$VersionsRoot  = Join-Path $MinecraftRoot "versions"
$StateFile     = Join-Path $MinecraftRoot "modpack_sync_state.json"

# Зберігаємо власний код скрипту в пам'яті, щоб під час відкату на старі коміти скрипт не перезаписувався старою неробочою версією
$CurrentScriptPath = $MyInvocation.MyCommand.Path
$CurrentScriptContent = if ($CurrentScriptPath -and (Test-Path -LiteralPath $CurrentScriptPath)) {
    Get-Content -LiteralPath $CurrentScriptPath -Raw -Encoding UTF8
} else { $null }

# ---------------------------------------------------------------------------
# 1. Пошук Git
# ---------------------------------------------------------------------------
function Find-GitExecutable {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) { return $gitCmd.Source }

    $candidates = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    if (Test-Path "$env:LOCALAPPDATA\GitHubDesktop") {
        $ghDirs = Get-ChildItem -Path "$env:LOCALAPPDATA\GitHubDesktop" -Directory -Filter "app-*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($d in $ghDirs) {
            $candidates += Join-Path $d.FullName "resources\app\git\cmd\git.exe"
        }
    }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

# ---------------------------------------------------------------------------
# 2. Автоматичне встановлення перехоплювача запуску TLauncher.exe
# ---------------------------------------------------------------------------
function Install-TLauncherStartupHook {
    try {
        $tlExe = Join-Path $MinecraftRoot "TLauncher.exe"
        $tlOrig = Join-Path $MinecraftRoot "TLauncher_original.exe"
        $globalSyncPs1 = Join-Path $MinecraftRoot "sync.ps1"
        $globalSyncBat = Join-Path $MinecraftRoot "sync.bat"

        # Копіюємо актуальний sync.ps1 та sync.bat у корінь .minecraft
        if ($CurrentScriptContent) {
            Set-Content -LiteralPath $globalSyncPs1 -Value $CurrentScriptContent -Encoding UTF8 -Force
        }
        $batContent = "@echo off`r`nchcp 65001 > nul`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0sync.ps1`"`r`n"
        Set-Content -LiteralPath $globalSyncBat -Value $batContent -Encoding UTF8 -Force

        if (-not (Test-Path -LiteralPath $tlExe)) { return }

        # Перевіряємо, чи TLauncher.exe ще є оригінальним (більше 1 МБ), а TLauncher_original.exe ще не створено
        $tlItem = Get-Item -LiteralPath $tlExe -ErrorAction SilentlyContinue
        if ($tlItem -and ($tlItem.Length -gt 1000000)) {
            Copy-Item -LiteralPath $tlExe -Destination $tlOrig -Force
        }

        if (-not (Test-Path -LiteralPath $tlOrig)) { return }

        # Якщо TLauncher.exe вже наш легкий лаунчер (< 500 КБ), не перекомпільовуємо без потреби
        $tlItemNow = Get-Item -LiteralPath $tlExe -ErrorAction SilentlyContinue
        if ($tlItemNow -and ($tlItemNow.Length -lt 500000)) { return }

        $csc = Get-ChildItem "$env:WINDIR\Microsoft.NET\Framework64\v4*\csc.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
        if (-not $csc) {
            $csc = Get-ChildItem "$env:WINDIR\Microsoft.NET\Framework\v4*\csc.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
        }
        if (-not $csc) { return }

        $csCode = @"
using System;
using System.Diagnostics;
using System.IO;

class TLauncherSyncWrapper {
    [STAThread]
    static int Main(string[] args) {
        try {
            string mcDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), ".minecraft");
            string syncScript = Path.Combine(mcDir, "versions", "Test", "sync.ps1");
            if (!File.Exists(syncScript)) {
                syncScript = Path.Combine(mcDir, "sync.ps1");
            }

            int exitCode = 0;
            if (File.Exists(syncScript)) {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + syncScript + "\" -FromTLauncher";
                psi.WorkingDirectory = mcDir;
                psi.UseShellExecute = true;
                Process p = Process.Start(psi);
                if (p != null) {
                    p.WaitForExit();
                    exitCode = p.ExitCode;
                }
            }

            // Код 99 означає "Вийти без запуску TLauncher"
            if (exitCode == 99) {
                return 0;
            }

            string origExe = Path.Combine(mcDir, "TLauncher_original.exe");
            if (File.Exists(origExe)) {
                ProcessStartInfo tlPsi = new ProcessStartInfo();
                tlPsi.FileName = origExe;
                if (args != null && args.Length > 0) {
                    tlPsi.Arguments = string.Join(" ", args);
                }
                tlPsi.WorkingDirectory = mcDir;
                tlPsi.UseShellExecute = true;
                Process.Start(tlPsi);
            }
            return 0;
        } catch (Exception) {
            return 1;
        }
    }
}
"@
        $tempCs = Join-Path $env:TEMP "TLauncherSyncWrapper.cs"
        $tempExe = Join-Path $env:TEMP "TLauncher_wrapper.exe"
        Set-Content -LiteralPath $tempCs -Value $csCode -Encoding UTF8 -Force

        $iconPath = Join-Path $MinecraftRoot "libraries\minecraft.ico"
        $cscArgs = @("/nologo", "/target:winexe", "/out:$tempExe")
        if (Test-Path -LiteralPath $iconPath) {
            $cscArgs += "/win32icon:$iconPath"
        }
        $cscArgs += $tempCs

        & $csc.FullName @cscArgs | Out-Null
        if (Test-Path -LiteralPath $tempExe) {
            Copy-Item -LiteralPath $tempExe -Destination $tlExe -Force
            Remove-Item -LiteralPath $tempExe -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $tempCs -Force -ErrorAction SilentlyContinue
    } catch {
        # Ігноруємо помилки компіляції обгортки, щоб не блокувати синхронізацію
    }
}

# ---------------------------------------------------------------------------
# 3. Завантаження / збереження стану
# ---------------------------------------------------------------------------
function Load-SyncState {
    if (Test-Path -LiteralPath $StateFile) {
        try {
            return Get-Content -LiteralPath $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {}
    }
    return [PSCustomObject]@{
        LastTargetDir = Join-Path $VersionsRoot "Test"
        LastCommit    = ""
    }
}

function Save-SyncState($targetDir, $commitSha) {
    try {
        $obj = @{
            LastTargetDir = $targetDir
            LastCommit    = $commitSha
            UpdatedAt     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $obj | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8 -Force
    } catch {}
}

# ---------------------------------------------------------------------------
# 4. Вибір папки для завантаження збірки
# ---------------------------------------------------------------------------
function Select-TargetFolder($defaultDir) {
    if (-not (Test-Path -LiteralPath $VersionsRoot)) {
        New-Item -ItemType Directory -Path $VersionsRoot -Force | Out-Null
    }

    while ($true) {
        Write-Host ""
        Write-Host "==================================================================" -ForegroundColor Cyan
        Write-Host "   КРОК 1: Оберіть папку для завантаження / оновлення збірки" -ForegroundColor Cyan
        Write-Host "==================================================================" -ForegroundColor Cyan

        $versionDirs = @()
        $versionPaths = @($defaultDir)
        $otherDirs = Get-ChildItem -LiteralPath $VersionsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $defaultDir } |
            Sort-Object LastWriteTime -Descending
        foreach ($od in $otherDirs) {
            $versionPaths += $od.FullName
        }

        Write-Host "  [0] Пропустити синхронізацію і одразу запустити TLauncher" -ForegroundColor Yellow
        for ($i = 0; $i -lt $versionPaths.Count; $i++) {
            $idx = $i + 1
            $dirPath = $versionPaths[$i]
            $dirName = Split-Path $dirPath -Leaf
            $exists = Test-Path -LiteralPath $dirPath
            $gitBadge = if ($exists -and (Test-Path (Join-Path $dirPath ".git"))) { "[Git]" } elseif (-not $exists) { "[Нова]" } else { "     " }
            $defBadge = if ($idx -eq 1) { " (За замовчуванням - натисніть Enter)" } else { "" }
            $color = if ($idx -eq 1) { "Green" } else { "White" }
            Write-Host ("  [{0}] {1,-16} {2} -> {3}{4}" -f $idx, $dirName, $gitBadge, $dirPath, $defBadge) -ForegroundColor $color
        }
        Write-Host "  [N] Створити нову папку у .minecraft\versions\<Назва>" -ForegroundColor Cyan
        Write-Host "  [B] Обрати будь-яку папку через Провідник Windows (вікно вибору)" -ForegroundColor Cyan
        Write-Host "  [P] Ввести власний повний шлях до папки вручну" -ForegroundColor Cyan
        Write-Host "  [Q] Вийти (не запускати TLauncher)" -ForegroundColor DarkGray
        Write-Host ""

        $choice = (Read-Host "Ваш вибір (Enter = [1], 0 = пропустити)").Trim()

        if ([string]::IsNullOrEmpty($choice)) {
            $chosenPath = $versionPaths[0]
            if (-not (Test-Path -LiteralPath $chosenPath)) {
                New-Item -ItemType Directory -Path $chosenPath -Force | Out-Null
            }
            return $chosenPath
        }

        if ($choice -eq "0" -or $choice -ieq "S") {
            return "SKIP"
        }
        if ($choice -ieq "Q") {
            return "QUIT"
        }
        if ($choice -ieq "N") {
            $newName = (Read-Host "Введіть назву нової папки версії (наприклад, Modpack_New)").Trim()
            if (-not [string]::IsNullOrEmpty($newName)) {
                $invalid = [System.IO.Path]::GetInvalidFileNameChars()
                foreach ($ch in $invalid) { $newName = $newName.Replace($ch, '_') }
                $newPath = Join-Path $VersionsRoot $newName
                if (-not (Test-Path -LiteralPath $newPath)) {
                    New-Item -ItemType Directory -Path $newPath -Force | Out-Null
                }
                return $newPath
            }
            continue
        }
        if ($choice -ieq "B") {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
                $dlg.Description = "Оберіть папку, куди завантажити збірку Minecraft"
                $dlg.SelectedPath = $VersionsRoot
                $dlg.ShowNewFolderButton = $true
                if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    return $dlg.SelectedPath
                }
            } catch {
                Write-Host "[!] Не вдалося відкрити вікно Провідника. Введіть шлях вручну." -ForegroundColor Red
            }
            continue
        }
        if ($choice -ieq "P") {
            $customPath = (Read-Host "Введіть повний шлях до папки (або назву папки у .minecraft\versions)").Trim('"').Trim()
            if (-not [string]::IsNullOrEmpty($customPath)) {
                if (-not [System.IO.Path]::IsPathRooted($customPath)) {
                    $customPath = Join-Path $VersionsRoot $customPath
                }
                if (-not (Test-Path -LiteralPath $customPath)) {
                    New-Item -ItemType Directory -Path $customPath -Force | Out-Null
                }
                return $customPath
            }
            continue
        }

        # Перевіряємо чи введено номер зі списку
        $num = 0
        if ([int]::TryParse($choice, [ref]$num)) {
            if ($num -ge 1 -and $num -le $versionPaths.Count) {
                $chosenPath = $versionPaths[$num - 1]
                if (-not (Test-Path -LiteralPath $chosenPath)) {
                    New-Item -ItemType Directory -Path $chosenPath -Force | Out-Null
                }
                return $chosenPath
            }
        }

        # Якщо користувач одразу ввів шлях або назву папки
        if ([System.IO.Path]::IsPathRooted($choice)) {
            if (-not (Test-Path -LiteralPath $choice)) {
                New-Item -ItemType Directory -Path $choice -Force | Out-Null
            }
            return $choice
        } else {
            $candidate = Join-Path $VersionsRoot $choice
            if (-not (Test-Path -LiteralPath $candidate)) {
                New-Item -ItemType Directory -Path $candidate -Force | Out-Null
            }
            return $candidate
        }
    }
}

# ---------------------------------------------------------------------------
# 5. Отримання списку гілок та комітів з GitHub / локального Git
# ---------------------------------------------------------------------------
function Get-RepositoryCommits($gitExe, $targetDir) {
    $branches = @()
    $commits  = @()
    $seenShas = @{}

    # Шукаємо будь-який локальний репозиторій для швидкого git fetch
    $refRepo = $null
    if (Test-Path (Join-Path $targetDir ".git")) {
        $refRepo = $targetDir
    } elseif (Test-Path (Join-Path $VersionsRoot "Test\.git")) {
        $refRepo = Join-Path $VersionsRoot "Test"
    } elseif ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot ".git"))) {
        $refRepo = $PSScriptRoot
    }

    if ($refRepo -and $gitExe) {
        Write-Host "[*] Отримання списку актуальних гілок та комітів із GitHub..." -ForegroundColor Yellow
        & $gitExe -C $refRepo remote set-url origin $RepoUrl 2>$null
        & $gitExe -C $refRepo fetch origin --prune --quiet 2>$null

        $branchLines = & $gitExe -C $refRepo for-each-ref --sort=-committerdate "refs/remotes/origin" --format="%(refname:short)|%(objectname:short)|%(objectname)|%(committerdate:short)|%(subject)" 2>$null
        foreach ($line in $branchLines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 5
            if ($parts.Count -lt 5) { continue }
            $bName = $parts[0] -replace '^origin/', ''
            if ($bName -eq "HEAD" -or $bName -eq "origin" -or $bName -eq "sync-script") { continue }
            $branches += [PSCustomObject]@{
                Name      = $bName
                ShortSha  = $parts[1]
                FullSha   = $parts[2]
                Date      = $parts[3]
                Message   = $parts[4]
            }
        }

        $logLines = & $gitExe -C $refRepo log --exclude="refs/remotes/origin/sync-script" --remotes=origin --date=short --pretty=format:"%h|%H|%ad|%D|%s" -n 20 2>$null
        foreach ($line in $logLines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|', 5
            if ($parts.Count -lt 5) { continue }
            $fullSha = $parts[1]
            if ($seenShas.ContainsKey($fullSha)) { continue }
            $seenShas[$fullSha] = $true

            $refs = ($parts[3] -replace 'HEAD -> [^,]+,?\s*', '' -replace 'origin/', '').Trim(', ')
            $commits += [PSCustomObject]@{
                ShortSha = $parts[0]
                FullSha  = $fullSha
                Date     = $parts[2]
                Refs     = $refs
                Message  = $parts[4]
            }
        }
    }

    # Якщо локального .git ще немає (перший запуск у друга), запитуємо через GitHub REST API
    if ($commits.Count -eq 0) {
        Write-Host "[*] Запит списку гілок та комітів через GitHub API..." -ForegroundColor Yellow
        try {
            $headers = @{ "User-Agent" = "MinecraftModpackSync/2.0" }
            $apiBranches = Invoke-RestMethod -Uri "$ApiBase/branches" -Headers $headers -TimeoutSec 10
            foreach ($b in $apiBranches) {
                if ($b.name -eq "sync-script") { continue }
                $bSha = $b.commit.sha
                $branches += [PSCustomObject]@{
                    Name     = $b.name
                    ShortSha = $bSha.Substring(0, 7)
                    FullSha  = $bSha
                    Date     = ""
                    Message  = ""
                }
                $apiCommits = Invoke-RestMethod -Uri "$ApiBase/commits?sha=$($b.name)&per_page=10" -Headers $headers -TimeoutSec 10
                foreach ($c in $apiCommits) {
                    $cSha = $c.sha
                    if ($seenShas.ContainsKey($cSha)) { continue }
                    $seenShas[$cSha] = $true
                    $msg = ($c.commit.message -split "`r?`n")[0]
                    $dateStr = if ($c.commit.committer.date) { $c.commit.committer.date.ToString().Substring(0, 10) } else { "" }
                    $commits += [PSCustomObject]@{
                        ShortSha = $cSha.Substring(0, 7)
                        FullSha  = $cSha
                        Date     = $dateStr
                        Refs     = $b.name
                        Message  = $msg
                    }
                }
            }
        } catch {
            # Fallback на git ls-remote
            if ($gitExe) {
                $lsLines = & $gitExe ls-remote --heads $RepoUrl 2>$null
                foreach ($l in $lsLines) {
                    if ($l -match '^([0-9a-f]{40})\s+refs/heads/(.+)$') {
                        $sha = $Matches[1]
                        $bName = $Matches[2]
                        $branches += [PSCustomObject]@{
                            Name     = $bName
                            ShortSha = $sha.Substring(0, 7)
                            FullSha  = $sha
                            Date     = ""
                            Message  = "Гілка $bName"
                        }
                        if (-not $seenShas.ContainsKey($sha)) {
                            $seenShas[$sha] = $true
                            $commits += [PSCustomObject]@{
                                ShortSha = $sha.Substring(0, 7)
                                FullSha  = $sha
                                Date     = ""
                                Refs     = $bName
                                Message  = "Останній коміт гілки $bName"
                            }
                        }
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        Branches = $branches
        Commits  = $commits
        RefRepo  = $refRepo
    }
}

# ---------------------------------------------------------------------------
# 6. Вибір конкретного коміту або гілки
# ---------------------------------------------------------------------------
function Select-TargetCommit($gitExe, $targetDir, $repoData) {
    $branches = $repoData.Branches
    $commits  = $repoData.Commits

    $currentInstalledSha = $null
    if (Test-Path (Join-Path $targetDir ".git")) {
        $currentInstalledSha = (& $gitExe -C $targetDir rev-parse --short HEAD 2>$null)
    }

    while ($true) {
        Write-Host ""
        Write-Host "==================================================================" -ForegroundColor Cyan
        Write-Host "   КРОК 2: Оберіть який саме коміт (або гілку) завантажувати" -ForegroundColor Cyan
        Write-Host "==================================================================" -ForegroundColor Cyan
        Write-Host "  Цільова папка: $targetDir" -ForegroundColor Gray
        if ($currentInstalledSha) {
            Write-Host "  Зараз у папці встановлено коміт: $currentInstalledSha" -ForegroundColor Yellow
        }
        Write-Host ""

        if ($branches.Count -gt 0) {
            Write-Host "  Доступні гілки (Branches):" -ForegroundColor Magenta
            for ($b = 0; $b -lt $branches.Count; $b++) {
                $br = $branches[$b]
                $bIdx = "B$($b + 1)"
                Write-Host ("    [{0}] Гілка: {1,-26} (останній коміт: {2}) {3}" -f $bIdx, $br.Name, $br.ShortSha, $br.Message) -ForegroundColor Gray
            }
            Write-Host ""
        }

        Write-Host "  Останні коміти в репозиторії:" -ForegroundColor Green
        Write-Host "    [0] Пропустити синхронізацію і запустити TLauncher" -ForegroundColor Yellow

        for ($i = 0; $i -lt $commits.Count; $i++) {
            $idx = $i + 1
            $c = $commits[$i]
            $refBadge = if ($c.Refs) { "($($c.Refs)) " } else { "" }
            $defBadge = if ($idx -eq 1) { " <-- [За замовчуванням: Enter]" } else { "" }
            $curBadge = if ($currentInstalledSha -and ($c.FullSha.StartsWith($currentInstalledSha) -or $c.ShortSha -eq $currentInstalledSha)) { " [ВСТАНОВЛЕНО]" } else { "" }
            $color = if ($idx -eq 1) { "Green" } elseif ($curBadge) { "Yellow" } else { "White" }
            $msgShort = if ($c.Message.Length -gt 68) { $c.Message.Substring(0, 65) + "..." } else { $c.Message }
            Write-Host ("    [{0,2}] {1} | {2} | {3}{4}{5}{6}" -f $idx, $c.ShortSha, $c.Date, $refBadge, $msgShort, $curBadge, $defBadge) -ForegroundColor $color
        }

        Write-Host ""
        $inputVal = (Read-Host "Введіть номер коміту [1..$($commits.Count)], код гілки [B1..B$($branches.Count)], або хеш коміту (Enter = [1])").Trim()

        if ([string]::IsNullOrEmpty($inputVal)) {
            if ($commits.Count -gt 0) {
                return $commits[0]
            }
        }

        if ($inputVal -eq "0" -or $inputVal -ieq "S") {
            return "SKIP"
        }
        if ($inputVal -ieq "Q") {
            return "QUIT"
        }

        # Вибір гілки за кодом B1, B2...
        if ($inputVal -match '^[Bb](\d+)$') {
            $bNum = [int]$Matches[1]
            if ($bNum -ge 1 -and $bNum -le $branches.Count) {
                $br = $branches[$bNum - 1]
                return [PSCustomObject]@{
                    ShortSha = $br.ShortSha
                    FullSha  = $br.FullSha
                    Refs     = $br.Name
                    Message  = "Гілка $($br.Name)"
                }
            }
        }

        # Вибір коміту за номером 1..N
        $cNum = 0
        if ([int]::TryParse($inputVal, [ref]$cNum)) {
            if ($cNum -ge 1 -and $cNum -le $commits.Count) {
                return $commits[$cNum - 1]
            }
        }

        # Перевірка чи введено назву гілки
        foreach ($br in $branches) {
            if ($br.Name -ieq $inputVal) {
                return [PSCustomObject]@{
                    ShortSha = $br.ShortSha
                    FullSha  = $br.FullSha
                    Refs     = $br.Name
                    Message  = "Гілка $($br.Name)"
                }
            }
        }

        # Перевірка чи введено хеш коміту зі списку
        foreach ($c in $commits) {
            if ($c.ShortSha -ieq $inputVal -or $c.FullSha.StartsWith($inputVal, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $c
            }
        }

        # Довільний хеш або гілка, введена вручну
        return [PSCustomObject]@{
            ShortSha = $inputVal
            FullSha  = $inputVal
            Refs     = $inputVal
            Message  = "Вказаний вручну коміт/гілка: $inputVal"
        }
    }
}

# ---------------------------------------------------------------------------
# 7. Синхронізація вибраного коміту у вибрану папку
# ---------------------------------------------------------------------------
function Sync-ModpackToFolder($gitExe, $targetDir, $selectedCommit, $refRepo) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "   КРОК 3: Завантаження та синхронізація збірки" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  Папка призначення : $targetDir" -ForegroundColor Green
    Write-Host "  Обраний коміт     : $($selectedCommit.ShortSha) ($($selectedCommit.Message))" -ForegroundColor Green
    Write-Host ""

    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $targetGitDir = Join-Path $targetDir ".git"

    # Якщо в цільовій папці ще немає .git, але на ПК вже є локальний клон (наприклад у Test),
    # копіюємо .git кеш для миттєвого розгортання без повторного скачування гігабайтів з інтернету
    if (-not (Test-Path -LiteralPath $targetGitDir)) {
        if ($refRepo -and ($refRepo -ne $targetDir) -and (Test-Path (Join-Path $refRepo ".git"))) {
            Write-Host "[1/4] Копіювання локального кешу Git із $refRepo (швидка ініціалізація)..." -ForegroundColor Yellow
            Copy-Item -LiteralPath (Join-Path $refRepo ".git") -Destination $targetGitDir -Recurse -Force
        } else {
            Write-Host "[1/4] Ініціалізація Git-репозиторію у $targetDir..." -ForegroundColor Yellow
            & $gitExe -C $targetDir init
            & $gitExe -C $targetDir remote add origin $RepoUrl 2>$null
        }
    }

    & $gitExe -C $targetDir remote set-url origin $RepoUrl 2>$null

    Write-Host "[2/4] Завантаження даних коміту $($selectedCommit.ShortSha) з GitHub..." -ForegroundColor Yellow
    & $gitExe -C $targetDir fetch origin $selectedCommit.FullSha 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $gitExe -C $targetDir fetch origin --all --prune
    }

    Write-Host "[3/4] Встановлення файлів коміту $($selectedCommit.ShortSha) (світи saves/ та карти xaero/ зберігаються)..." -ForegroundColor Yellow
    # Знімаємо блокування індексу якщо лишився index.lock
    $lockFile = Join-Path $targetGitDir "index.lock"
    if (Test-Path -LiteralPath $lockFile) { Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue }

    & $gitExe -C $targetDir checkout -f $selectedCommit.FullSha
    & $gitExe -C $targetDir reset --hard $selectedCommit.FullSha

    # Очищення зайвих модів у папці mods/, які не належать до обраного коміту
    Write-Host "[4/4] Перевірка чистоти папки mods/ та налаштування профілю TLauncher..." -ForegroundColor Yellow
    $modsDir = Join-Path $targetDir "mods"
    if (Test-Path -LiteralPath $modsDir) {
        # Видаляємо старі .deactivation файли
        Get-ChildItem -LiteralPath $modsDir -Filter "*.deactivation" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

        $trackedModsLines = & $gitExe -C $targetDir ls-tree -r --name-only HEAD "mods/" 2>$null
        $trackedJars = @{}
        foreach ($tm in $trackedModsLines) {
            if ($tm -like "mods/*.jar") {
                $jarName = (Split-Path $tm -Leaf).ToLower()
                $trackedJars[$jarName] = $true
            }
        }

        if ($trackedJars.Count -gt 0) {
            $backupDir = Join-Path $targetDir "mods_backup"
            $installedJars = Get-ChildItem -LiteralPath $modsDir -Filter "*.jar" -ErrorAction SilentlyContinue
            $movedCount = 0
            foreach ($jar in $installedJars) {
                if (-not $trackedJars.ContainsKey($jar.Name.ToLower())) {
                    if (-not (Test-Path -LiteralPath $backupDir)) {
                        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                    }
                    Move-Item -LiteralPath $jar.FullName -Destination (Join-Path $backupDir $jar.Name) -Force
                    Write-Host "      [-] Прибрано зайвий мод (переміщено у mods_backup): $($jar.Name)" -ForegroundColor Magenta
                    $movedCount++
                }
            }
        }
    }

    # Якщо цільова папка в .minecraft\versions\<FolderName> має назву відмінну від Test,
    # створюємо <FolderName>.json та <FolderName>.jar для TLauncher
    $folderName = Split-Path $targetDir -Leaf
    $parentDir  = Split-Path $targetDir -Parent
    if ($parentDir -ieq $VersionsRoot) {
        $testJson = Join-Path $targetDir "Test.json"
        $testJar  = Join-Path $targetDir "Test.jar"
        $targetJson = Join-Path $targetDir "$folderName.json"
        $targetJar  = Join-Path $targetDir "$folderName.jar"

        if (($folderName -ne "Test") -and (Test-Path -LiteralPath $testJson)) {
            $jsonRaw = Get-Content -LiteralPath $testJson -Raw -Encoding UTF8
            $jsonUpdated = $jsonRaw -replace '"id"\s*:\s*"Test"', "`"id`": `"$folderName`""
            Set-Content -LiteralPath $targetJson -Value $jsonUpdated -Encoding UTF8 -Force
        }
        if (($folderName -ne "Test") -and (Test-Path -LiteralPath $testJar) -and (-not (Test-Path -LiteralPath $targetJar))) {
            Copy-Item -LiteralPath $testJar -Destination $targetJar -Force
        }

        # Автоматично обираємо цю версію у TLauncher (tlauncher-2.0.properties)
        $tlPropsPath = Join-Path $MinecraftRoot "tlauncher-2.0.properties"
        if (Test-Path -LiteralPath $tlPropsPath) {
            try {
                $propsContent = Get-Content -LiteralPath $tlPropsPath -Raw -Encoding UTF8
                $propsContent = $propsContent -replace '(?m)^login\.version\.game=.*$', "login.version.game=$folderName"
                $propsContent = $propsContent -replace '(?m)^modpack\.combobox\.name=.*$', "modpack.combobox.name=$folderName"
                Set-Content -LiteralPath $tlPropsPath -Value $propsContent -Encoding UTF8 -Force
            } catch {}
        }
    }

    # Відновлюємо актуальний sync.ps1 та sync.bat у цільовій папці (на випадок відкату на старий коміт)
    if ($CurrentScriptContent) {
        Set-Content -LiteralPath (Join-Path $targetDir "sync.ps1") -Value $CurrentScriptContent -Encoding UTF8 -Force
        Set-Content -LiteralPath (Join-Path $MinecraftRoot "sync.ps1") -Value $CurrentScriptContent -Encoding UTF8 -Force
    }
    $batText = "@echo off`r`nchcp 65001 > nul`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0sync.ps1`"`r`n"
    Set-Content -LiteralPath (Join-Path $targetDir "sync.bat") -Value $batText -Encoding UTF8 -Force

    Save-SyncState -targetDir $targetDir -commitSha $selectedCommit.FullSha

    $modCount = (Get-ChildItem -LiteralPath (Join-Path $targetDir "mods") -Filter "*.jar" -ErrorAction SilentlyContinue).Count
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "   СИНХРОНІЗАЦІЮ УСПІШНО ЗАВЕРШЕНО!" -ForegroundColor Green
    Write-Host "   Папка збірки : $targetDir" -ForegroundColor Green
    Write-Host "   Коміт        : $($selectedCommit.ShortSha)" -ForegroundColor Green
    Write-Host "   Активних модів: $modCount" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# ===========================================================================
# ГОЛОВНИЙ ПОТІК ВИКОНАННЯ
# ===========================================================================
Install-TLauncherStartupHook

$gitExe = Find-GitExecutable
if (-not $gitExe) {
    Write-Host "[!] Git не знайдено на комп'ютері! Будь ласка, встановіть Git (https://git-scm.com/)." -ForegroundColor Red
    Read-Host "Натисніть Enter для виходу"
    exit 1
}

$state = Load-SyncState
$defaultDir = if ($state.LastTargetDir) { $state.LastTargetDir } else { Join-Path $VersionsRoot "Test" }

$selectedDir = Select-TargetFolder -defaultDir $defaultDir
if ($selectedDir -eq "SKIP") {
    Write-Host "[*] Синхронізацію пропущено. Запускаємо TLauncher..." -ForegroundColor Yellow
    exit 0
}
if ($selectedDir -eq "QUIT") {
    exit 99
}

$repoData = Get-RepositoryCommits -gitExe $gitExe -targetDir $selectedDir
$selectedCommit = Select-TargetCommit -gitExe $gitExe -targetDir $selectedDir -repoData $repoData

if ($selectedCommit -eq "SKIP") {
    Write-Host "[*] Синхронізацію пропущено. Запускаємо TLauncher..." -ForegroundColor Yellow
    exit 0
}
if ($selectedCommit -eq "QUIT") {
    exit 99
}

Sync-ModpackToFolder -gitExe $gitExe -targetDir $selectedDir -selectedCommit $selectedCommit -refRepo $repoData.RefRepo

if (-not $FromTLauncher) {
    Write-Host ""
    $runTl = (Read-Host "Запустити TLauncher зараз? (Enter/Y = Так, N = Ні)").Trim()
    if ([string]::IsNullOrEmpty($runTl) -or $runTl -ieq "Y" -or $runTl -ieq "Т") {
        $tlOrig = Join-Path $MinecraftRoot "TLauncher_original.exe"
        $tlExe  = Join-Path $MinecraftRoot "TLauncher.exe"
        if (Test-Path -LiteralPath $tlOrig) {
            Start-Process -FilePath $tlOrig -WorkingDirectory $MinecraftRoot
        } elseif (Test-Path -LiteralPath $tlExe) {
            Start-Process -FilePath $tlExe -WorkingDirectory $MinecraftRoot
        }
    }
}

exit 0
