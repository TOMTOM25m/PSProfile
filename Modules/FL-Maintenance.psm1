<#
.SYNOPSIS
    [EN] Module for handling maintenance tasks.
    [DE] Modul für die Handhabung von Wartungsaufgaben.
.DESCRIPTION
    [EN] This module contains functions for log archiving, local asset initialization, and updating templates from Git.
    [DE] Dieses Modul enthält Funktionen für die Log-Archivierung, die Initialisierung lokaler Assets und die Aktualisierung von Vorlagen aus Git.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.08.29
    Version:        v09.04.00
    MUW-Regelwerk:  v7.3.0
    Copyright:      © 2025 Flecki Garnreiter
#>

function Invoke-ArchiveMaintenance {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    if (-not $Global:Config.Logging.ArchiveLogs) {
        Write-Log -Level INFO -Message "Log archiving is disabled."
        return
    }
    Write-Log -Level INFO -Message "Starting archive maintenance..."
    $logConf = $Global:Config.Logging
    $use7Zip = (Test-Path $logConf.SevenZipPath) -and ($logConf.SevenZipPath.EndsWith("7z.exe"))

    $cutoffDate = (Get-Date).AddDays(-$logConf.LogRetentionDays)
    $logsToArchive = Get-ChildItem -Path $logConf.LogPath -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    if ($logsToArchive) {
        $archiveName = "$($Global:ScriptName -replace '\.ps1', '')_$((Get-Date).AddMonths(-1).ToString('yyyy_MM')).zip"
        $archivePath = Join-Path $logConf.LogPath $archiveName
        Write-Log -Level INFO -Message "Archiving $($logsToArchive.Count) log files to '$archivePath'..."
        try {
            if ($PSCmdlet.ShouldProcess($archivePath, "Create Archive")) {
                if ($use7Zip) {
                    $filesString = $logsToArchive.FullName -join '" "'
                    Start-Process -FilePath $logConf.SevenZipPath -ArgumentList "a -tzip `"$archivePath`" `"$filesString`"" -Wait -NoNewWindow
                }
                else {
                    Compress-Archive -Path $logsToArchive.FullName -DestinationPath $archivePath -Update
                }
                $logsToArchive | Remove-Item -Force
            }
        }
        catch { Write-Log -Level ERROR -Message "Archiving failed: $($_.Exception.Message)" }
    }
    $archiveCutoffDate = (Get-Date).AddDays(-$logConf.ArchiveRetentionDays)
    Get-ChildItem -Path $logConf.LogPath -Filter "*.zip" | Where-Object { $_.LastWriteTime -lt $archiveCutoffDate } | ForEach-Object {
        Write-Log -Level INFO -Message "Deleting old archive: $($_.FullName)"
        if ($PSCmdlet.ShouldProcess($_.FullName, "Delete old archive")) {
            $_ | Remove-Item -Force
        }
    }
}

function Initialize-LocalAssets {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()
    
    $logoPath = $Global:Config.Logging.LogoPath
    $logoUncPath = $Global:Config.UNCPaths.Logo

    if (-not (Test-Path $logoPath) -and (Test-Path $logoUncPath)) {
        Write-Log -Level INFO -Message "Local logo not found. Attempting to copy from UNC path: $logoUncPath"
        $localImageDir = Split-Path $logoPath -Parent
        if (-not (Test-Path $localImageDir)) {
            if ($PSCmdlet.ShouldProcess($localImageDir, "Create Image Directory")) {
                New-Item -Path $localImageDir -ItemType Directory | Out-Null
            }
        }
        if ($PSCmdlet.ShouldProcess($logoPath, "Copy Logo from UNC")) {
            try {
                Copy-Item -Path $logoUncPath -Destination $logoPath -Force -ErrorAction Stop
                Write-Log -Level INFO -Message "Logo successfully copied to $logoPath"
            }
            catch {
                Write-Log -Level WARNING -Message "Could not copy logo from UNC path: $($_.Exception.Message)"
            }
        }
    }
}

function Invoke-GitUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $gitConfig = $Global:Config.GitUpdate
    if (-not $gitConfig.Enabled) {
        Write-Log -Level INFO -Message "Git update feature is disabled."
        return $null
    }

    Write-Log -Level INFO -Message "Starting Git update for profile templates..."

    $gitPath = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $gitPath) {
        throw "Git is not installed or not in the system's PATH. Cannot perform Git update."
    }
    Write-Log -Level DEBUG -Message "Found git.exe at: $($gitPath.Source)"

    $cachePath = $gitConfig.LocalCachePath
    if (-not (Test-Path $cachePath)) {
        if ($PSCmdlet.ShouldProcess($cachePath, "Create Git cache directory")) {
            New-Item -Path $cachePath -ItemType Directory -Force | Out-Null
        }
    }

    $repoDir = Join-Path $cachePath "repository"

    if (-not (Test-Path (Join-Path $repoDir ".git"))) {
        Write-Log -Level INFO -Message "Local repository not found. Cloning from $($gitConfig.RepositoryUrl)..."
        $cloneArgs = "clone --branch $($gitConfig.Branch) --single-branch `"$($gitConfig.RepositoryUrl)`" `"$repoDir`""
        if ($PSCmdlet.ShouldProcess($gitConfig.RepositoryUrl, "Clone Repository")) {
            $process = Start-Process -FilePath $gitPath.Source -ArgumentList $cloneArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
            if ($process.ExitCode -ne 0) { throw "Git clone failed with exit code $($process.ExitCode)." }
            Write-Log -Level INFO -Message "Repository cloned successfully."
        }
    }
    else {
        Write-Log -Level INFO -Message "Local repository found. Fetching updates..."
        if ($PSCmdlet.ShouldProcess($repoDir, "Update Repository (git fetch & reset)")) {
            $fetchArgs = "-C `"$repoDir`" fetch origin"
            $resetArgs = "-C `"$repoDir`" reset --hard origin/$($gitConfig.Branch)"
            & $gitPath.Source $fetchArgs.Split(' ') | Out-Null
            & $gitPath.Source $resetArgs.Split(' ') | Out-Null
            Write-Log -Level INFO -Message "Repository updated successfully to latest version from branch '$($gitConfig.Branch)'."
        }
    }
    return $repoDir
}

Export-ModuleMember -Function Invoke-ArchiveMaintenance, Initialize-LocalAssets, Invoke-GitUpdate

# --- End of module --- v09.04.00 ; Regelwerk: v7.3.0 ---
