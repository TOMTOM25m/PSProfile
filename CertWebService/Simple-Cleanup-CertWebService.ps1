# CertWebService Simple Cleanup Script
param(
    [switch]$DryRun
)

Write-Host "=== CertWebService Simple Cleanup ===" -ForegroundColor Green
Write-Host "DryRun Mode: $DryRun" -ForegroundColor Yellow

$TargetPath = "\\itscmgmt03.srv.meduniwien.ac.at\C$\CertWebService"

# Core Files die bleiben
$CoreFiles = @(
    'CertWebService.ps1',
    'Restart-Service.ps1', 
    'RESTART.bat',
    'Setup-CertWebService-Scheduler.ps1',
    'PowerShell-Regelwerk-Universal-v10.1.0.md'
)

# Core Directories die bleiben
$CoreDirs = @('Config', 'Logs', 'Backup')

Write-Host "`nAnalyzing directory..." -ForegroundColor Yellow

try {
    $AllFiles = Get-ChildItem $TargetPath -File -ErrorAction Stop
    $AllDirs = Get-ChildItem $TargetPath -Directory -ErrorAction Stop
    
    Write-Host "Total files: $($AllFiles.Count)" -ForegroundColor Gray
    Write-Host "Total directories: $($AllDirs.Count)" -ForegroundColor Gray
    
    # Finde Files die archiviert werden
    $FilesToArchive = $AllFiles | Where-Object { $_.Name -notin $CoreFiles }
    Write-Host "Files to archive: $($FilesToArchive.Count)" -ForegroundColor Cyan
    
    # Finde Dirs die entfernt werden
    $DirsToRemove = $AllDirs | Where-Object { $_.Name -notin $CoreDirs -and $_.Name -ne 'Archive' }
    Write-Host "Directories to remove: $($DirsToRemove.Count)" -ForegroundColor Cyan
    
    if ($DryRun) {
        Write-Host "`nDRY RUN - Files that would be archived:" -ForegroundColor Yellow
        $FilesToArchive | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
        
        Write-Host "`nDRY RUN - Directories that would be removed:" -ForegroundColor Yellow  
        $DirsToRemove | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
        
        Write-Host "`nNo changes made in DryRun mode." -ForegroundColor Green
        return
    }
    
    # REAL CLEANUP
    Write-Host "`nStarting cleanup..." -ForegroundColor Yellow
    
    # Create Archive
    $ArchiveDir = Join-Path $TargetPath "Archive\Cleanup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -Path $ArchiveDir -ItemType Directory -Force | Out-Null
    Write-Host "Archive created: $ArchiveDir" -ForegroundColor Green
    
    # Archive files
    $ArchivedCount = 0
    foreach ($file in $FilesToArchive) {
        Move-Item $file.FullName (Join-Path $ArchiveDir $file.Name) -Force
        $ArchivedCount++
    }
    Write-Host "Archived $ArchivedCount files" -ForegroundColor Green
    
    # Remove directories
    $RemovedCount = 0
    foreach ($dir in $DirsToRemove) {
        # Backup before remove
        Copy-Item $dir.FullName (Join-Path $ArchiveDir $dir.Name) -Recurse -Force
        Remove-Item $dir.FullName -Recurse -Force
        $RemovedCount++
    }
    Write-Host "Removed $RemovedCount directories" -ForegroundColor Green
    
    # Create Scripts dir if missing
    $ScriptsDir = Join-Path $TargetPath "Scripts"
    if (-not (Test-Path $ScriptsDir)) {
        New-Item -Path $ScriptsDir -ItemType Directory -Force | Out-Null
        Write-Host "Created Scripts directory" -ForegroundColor Green
    }
    
    # Summary
    Write-Host "`n=== CLEANUP COMPLETED ===" -ForegroundColor Green
    $FinalFiles = Get-ChildItem $TargetPath -File
    $FinalDirs = Get-ChildItem $TargetPath -Directory
    
    Write-Host "Files: $($AllFiles.Count) → $($FinalFiles.Count)" -ForegroundColor White
    Write-Host "Directories: $($AllDirs.Count) → $($FinalDirs.Count)" -ForegroundColor White
    
    Write-Host "`nFinal structure:" -ForegroundColor Cyan
    Get-ChildItem $TargetPath | ForEach-Object {
        $type = if ($_.PSIsContainer) { "[DIR]" } else { "[FILE]" }
        Write-Host "  $type $($_.Name)" -ForegroundColor Gray
    }
    
    Write-Host "`nArchive location: $ArchiveDir" -ForegroundColor Cyan
    
    # Create summary file
    $Summary = "CertWebService Cleanup Summary`n" +
               "Date: $(Get-Date)`n" +
               "Files archived: $ArchivedCount`n" +
               "Directories removed: $RemovedCount`n" +
               "Archive location: $ArchiveDir`n"
    
    $SummaryFile = Join-Path $TargetPath "CLEANUP-SUMMARY.txt"
    $Summary | Out-File $SummaryFile -Encoding UTF8
    Write-Host "Summary saved: $SummaryFile" -ForegroundColor Gray
    
} catch {
    Write-Error "Cleanup failed: $($_.Exception.Message)"
}