$filePath = "f:\VSCode\Profile\Modules\FL-Gui.psm1"
$content = Get-Content -Path $filePath -Raw

# Define the corrected Initialize-LocalizationFiles function content
$newInitializeLocalizationFilesFunction = @"
function Initialize-LocalizationFiles {
    param(
        [string]`$ConfigDirectory
    )
    `$deFile = Join-Path `$ConfigDirectory 'de-DE.json'
    `$enFile = Join-Path `$ConfigDirectory 'en-US.json'

    # Always overwrite to ensure the files are correct and up-to-date with the script version.
    Write-Log -Level DEBUG ""Ensuring default German localization file is up-to-date.""
    `$deVersion = `$Global:Config.LanguageFileVersions['de-DE']
    @""
{
  ""Version"": ""`$deVersion"",
  ""TabGeneral"": ""Allgemein"",
  ""LblLanguage"": ""Sprache"",
  ""LblEnvironment"": ""Umgebung"",
  ""WhatIfLabel"": ""Simulationsmodus ausführen (WhatIf)"",
  ""HelpEnv"": ""DEV für Debugging und Simulation, PROD für den produktiven Einsatz."",
  ""HelpWhatIf"": ""Simuliert nur Aktionen im DEV-Modus, ohne Änderungen vorzunehmen."",
  ""TabPaths"": ""Pfade / Logging"",
  ""GrpLoggingPaths"": ""Protokollierungs-Pfade"",
  ""HelpLoggingPaths"": ""Definiert die Speicherorte für Log- und Report-Dateien."",
  ""GrpTemplatePaths"": ""Vorlagen-Pfade"",
  ""HelpTemplatePaths"": ""Pfade zu den PowerShell-Profilvorlagen, die verwendet werden sollen."",
  ""LblStdTemplate"": ""Standard-Profil (profile.ps1)"",
  ""LblTemplateX"": ""Erweitertes Profil (profileX.ps1)"",
  ""LblTemplateMOD"": ""Modernes Profil (ProfileMOD.ps1)"",
  ""LblLogDir"": ""Log-Verzeichnis"",
  ""LblReportDir"": ""Report-Verzeichnis"",
  ""ChkArchive"": ""Log-Archivierung aktivieren"",
  ""ChkEventLog"": ""Windows Event Log aktivieren"",
  ""TabBackup"": ""Backup"",
  ""HelpBackup"": ""Aktiviert und konfiguriert automatische Backups der Profile."",
  ""ChkBackupEnabled"": ""Backup aktivieren"",
  ""LblBackupPath"": ""Backup-Pfad"",
  ""TabMail"": ""E-Mail"",
  ""HelpMail"": ""Konfiguriert die E-Mail-Benachrichtigungen für den Skriptstatus."",
  ""ChkMailEnabled"": ""Mail-Benachrichtigung aktivieren"",
  ""LblSmtpServer"": ""SMTP-Server"",
  ""LblSender"": ""Absender"",
  ""LblDevRecipient"": ""Empfänger (DEV)"",
  ""LblProdRecipient"": ""Empfänger (PROD)"",
  ""HelpMailProd"": ""Mehrere Empfänger mit Semikolon (;)."",
  ""BtnOK"": ""OK"",
  ""BtnApply"": ""Anwenden"",
  ""BtnCancel"": ""Abbrechen"",
  ""BtnBrowse"": "" ... "",
  ""RestartTitle"": ""Sprachwechsel"",
  ""RestartMessage"": ""Um die Sprache zu ändern, muss das Konfigurationsfenster neu gestartet werden. Aktuelle Änderungen speichern und neu starten?"",
  ""TabUpdate"": ""Update"",
  ""ChkGitUpdateEnabled"": ""Automatische Updates via Git aktivieren"",
  ""HelpGitUpdate"": ""Wenn aktiviert, werden die Profil-Vorlagen vor der Ausführung aus dem angegebenen Git-Repository geklont/aktualisiert. Git muss auf dem System installiert sein."",
  ""LblGitRepoUrl"": ""Repository URL"",
  ""LblGitBranch"": ""Branch"",
  ""LblGitCachePath"": ""Lokaler Cache-Pfad""
}
""@ | Set-Content -Path `$deFile -Encoding UTF8

    Write-Log -Level DEBUG ""Ensuring default English localization file is up-to-date.""
    `$enVersion = `$Global:Config.LanguageFileVersions['en-US']
    @""
{
  ""Version"": ""`$enVersion"",
  ""TabGeneral"": ""General"",
  ""LblLanguage"": ""Language"",
  ""LblEnvironment"": ""Environment"",
  ""WhatIfLabel"": ""Run in Simulation Mode (WhatIf)"",
  ""HelpEnv"": ""DEV for debugging and simulation, PROD for productive use."",
  ""HelpWhatIf"": ""Only simulates actions in DEV mode without making changes."",
  ""TabPaths"": ""Paths / Logging"",
  ""GrpLoggingPaths"": ""Logging Paths"",
  ""HelpLoggingPaths"": ""Defines the storage locations for log and report files."",
  ""GrpTemplatePaths"": ""Template Paths"",
  ""HelpTemplatePaths"": ""Paths to the PowerShell profile templates to be used."",
  ""LblStdTemplate"": ""Standard Profile (profile.ps1)"",
  ""LblTemplateX"": ""Extended Profile (profileX.ps1)"",
  ""LblTemplateMOD"": ""Modern Profile (ProfileMOD.ps1)"",
  ""LblLogDir"": ""Log Directory"",
  ""LblReportDir"": ""Report Directory"",
  ""ChkArchive"": ""Enable Log Archiving"",
  ""ChkEventLog"": ""Enable Windows Event Log"",
  ""TabBackup"": ""Backup"",
  ""HelpBackup"": ""Enables and configures automatic backups of the profiles."",
  ""ChkBackupEnabled"": ""Enable Backup"",
  ""LblBackupPath"": ""Backup Path"",
  ""TabMail"": ""E-Mail"",
  ""HelpMail"": ""Configures the e-mail notifications for the script status."",
  ""ChkMailEnabled"": ""Enable Mail Notification"",
  ""LblSmtpServer"": ""SMTP Server"",
  ""LblSender"": ""Sender"",
  ""LblDevRecipient"": ""Recipient (DEV)"",
  ""LblProdRecipient"": ""Recipient (PROD)"",
  ""HelpMailProd"": ""Mehrere Empfänger mit Semikolon (;)."",
  ""BtnOK"": ""OK"",
  ""BtnApply"": ""Anwenden"",
  ""BtnCancel"": ""Abbrechen"",
  ""BtnBrowse"": "" ... "",
  ""RestartTitle"": ""Language Change"",
  ""RestartMessage"": ""To apply the language change, the configuration window must be restarted. Save current changes and restart?"",
  ""TabUpdate"": ""Update"",
  ""ChkGitUpdateEnabled"": ""Enable automatic updates via Git"",
  ""HelpGitUpdate"": ""If enabled, the profile templates will be cloned/updated from the specified Git repository before execution. Git must be installed on the system."",
  ""LblGitRepoUrl"": ""Repository URL"",
  ""LblGitBranch"": ""Branch"",
  ""LblGitCachePath"": ""Local Cache Path""
}
""@ | Set-Content -Path `$enFile -Encoding UTF8
}
"@

# Use regex to find the function block
$pattern = "(?smi)function\s+Initialize-LocalizationFiles\s*\{.*?^\}"
$oldFunctionMatch = $content | Select-String -Pattern $pattern

if ($oldFunctionMatch) {
    $oldFunction = $oldFunctionMatch.Matches[0].Value
    $updatedContent = $content -replace [regex]::Escape($oldFunction), $newInitializeLocalizationFilesFunction
    Set-Content -Path $filePath -Value $updatedContent -Encoding UTF8
    Write-Host "Successfully updated Initialize-LocalizationFiles function in $filePath"
} else {
    Write-Host "Error: Could not find Initialize-LocalizationFiles function in $filePath"
}
