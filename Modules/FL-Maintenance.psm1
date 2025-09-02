<#
.SYNOPSIS
    [DE] Modul für Wartungsaufgaben wie Archivierung.
    [EN] Module for maintenance tasks like archiving.
.NOTES
    Author:         Flecki (Tom) Garnreiter
    Created on:     2025.08.29
    Last modified:  2025.09.02
    Version:        v11.2.1
    MUW-Regelwerk:  v8.2.0
    Notes:          [DE] Versionsnummer für Release-Konsistenz aktualisiert.
                    [EN] Updated version number for release consistency.
    Copyright:      © 2025 Flecki Garnreiter
    License:        MIT License
#>

function Invoke-ArchiveMaintenance {
    [CmdletBinding()]
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
            # Log-Archivierung wird immer ausgeführt, unabhängig vom WhatIf-Modus
            if ($use7Zip) {
                $filesString = $logsToArchive.FullName -join '" "'
                Start-Process -FilePath $logConf.SevenZipPath -ArgumentList "a -tzip `"$archivePath`" `"$filesString`"" -Wait -NoNewWindow
            }
            else {
                Compress-Archive -Path $logsToArchive.FullName -DestinationPath $archivePath -Update
            }
            $logsToArchive | Remove-Item -Force
        }
        catch { Write-Log -Level ERROR -Message "Archiving failed: $($_.Exception.Message)" }
    }
    $archiveCutoffDate = (Get-Date).AddDays(-$logConf.ArchiveRetentionDays)
    Get-ChildItem -Path $logConf.LogPath -Filter "*.zip" | Where-Object { $_.LastWriteTime -lt $archiveCutoffDate } | ForEach-Object {
        Write-Log -Level INFO -Message "Deleting old archive: $($_.FullName)"
        # Alte Archive werden immer gelöscht, unabhängig vom WhatIf-Modus
        $_ | Remove-Item -Force
    }
}

function Initialize-LocalAssets {
    [CmdletBinding()]
    param()
    Write-Log -Level DEBUG -Message "Initializing local assets..."

    if (-not ($Global:Config.GuiAssets -and $Global:Config.UNCPaths)) {
        Write-Log -Level DEBUG -Message "GuiAssets or UNCPaths not defined in config. Skipping asset initialization."
        return
    }

    # Define assets to check and copy
    $assets = @{
        Logo = @{
            Dest = $Global:Config.GuiAssets.LogoPath
            File = "MedUniWien_logo.png"
        }
        Icon = @{
            Dest = $Global:Config.GuiAssets.IconPath
            File = "MedUniWien_logo.ico"
        }
    }

    foreach ($assetName in $assets.Keys) {
        $asset = $assets[$assetName]
        $destPath = $asset.Dest
        
        if ($null -eq $destPath) {
            Write-Log -Level DEBUG -Message "Destination path for asset '$assetName' is null. Skipping."
            continue
        }

        if (-not (Test-Path $destPath)) {
            $uncDir = $Global:Config.UNCPaths.AssetDirectory
            if ($null -eq $uncDir) {
                Write-Log -Level DEBUG -Message "UNC asset directory not configured. Cannot copy '$assetName'."
                continue
            }

            $sourcePath = Join-Path $uncDir $asset.File
            if (Test-Path $sourcePath) {
                Write-Log -Level INFO -Message "Local $assetName not found. Attempting to copy from UNC path: $sourcePath"
                $localDir = Split-Path $destPath -Parent
                if (-not (Test-Path $localDir)) {
                    New-Item -Path $localDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                }
                try {
                    Copy-Item -Path $sourcePath -Destination $destPath -Force -ErrorAction Stop
                    Write-Log -Level INFO -Message "$assetName successfully copied to $destPath"
                }
                catch {
                    Write-Log -Level WARNING -Message "Could not copy $assetName from UNC path: $($_.Exception.Message)"
                }
            } else {
                Write-Log -Level WARNING -Message "Source asset '$sourcePath' not found on UNC path. Cannot copy."
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

    $cachePath = $gitConfig.CachePath
    if (-not (Test-Path $cachePath)) {
        if ($PSCmdlet.ShouldProcess($cachePath, "Create Git cache directory")) {
            New-Item -Path $cachePath -ItemType Directory -Force | Out-Null
        }
    }

    $repoDir = Join-Path $cachePath "repository"

    if (-not (Test-Path (Join-Path $repoDir ".git"))) {
        Write-Log -Level INFO -Message "Local repository not found. Cloning from $($gitConfig.RepoUrl)..."
        $cloneArgs = "clone --branch $($gitConfig.Branch) --single-branch `"$($gitConfig.RepoUrl)`" `"$repoDir`""
        if ($PSCmdlet.ShouldProcess($gitConfig.RepoUrl, "Clone Repository")) {
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

# --- End of module --- v11.2.1 ; Regelwerk: v8.2.0 ---