#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=beta
#AutoIt3Wrapper_Outfile=..\Berechtigungsstruktur auslesen.exe
#AutoIt3Wrapper_Outfile_x64=..\Berechtigungsstruktur auslesen64.exe
#AutoIt3Wrapper_Compression=3
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Fileversion=3.0.0.7
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=3079
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AutoIt3Wrapper_Run_Tidy=y
#Tidy_Parameters=/gd /rel
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <AD.au3>
#include <Array.au3>
#include <Constants.au3>
#include <Date.au3>
#include <File.au3>
#include <GUIConstantsEx.au3>
Global $logfile = @TempDir & '\AS' & Random(1214, 2358745) & 'LFE.tmp'
Global $logfile1 = @TempDir & '\AS' & Random(1214, 2358745) & 'LFA.tmp'
Global $tempfile = @TempDir & '\AS' & Random(1214, 2358745) & 'TMPTXT.tmp'
Global $aGroups, $aMembers[1], $aMembers1[1], $I, $S, $aMem[1], $Member, $a, $string, $sSamAccountName, $grp2u, $folderoutput, $folder, $MEMresult, $aCaclsResult
#region ### START Koda GUI section ### Form=C:\Users\tom\Documents\AutoIt\Report_User_Per_Verz.kxf
$UvonVerzAuslesen = GUICreate("User Rechte aus Verzeichniss auslesen", 382, 337, 260, 183)
$Start = GUICtrlCreateButton("Start", 127, 30, 99, 25)
$Cancle = GUICtrlCreateButton("Beenden", 140, 278, 99, 33)
$Label1 = GUICtrlCreateLabel("Verzeichnis zum Auswerten der Berechtigungen eingeben:", 15, 8, 350, 17)
$speichern_unter = GUICtrlCreateInput(@ScriptDir & "\Auswertungen", 15, 93, 350, 21)
$Label2 = GUICtrlCreateLabel("Speichern unter:", 15, 69, 82, 17)
$Label3 = GUICtrlCreateLabel("Report anzeigen:", 15, 176, 105, 17)
GUICtrlSetState(-1, $GUI_HIDE)
$Report_Anz_liste = GUICtrlCreateCombo("", 15, 200, 350, 25)
GUICtrlSetState(-1, $GUI_HIDE)
$Rep_Per_Mail_Button = GUICtrlCreateButton("Report per E-Mail Versenden", 204, 232, 163, 25)
GUICtrlSetState(-1, $GUI_HIDE)
$View_Rep_BTTN = GUICtrlCreateButton("Report Anzeigen", 15, 232, 123, 25)
GUICtrlSetState(-1, $GUI_HIDE)
$Verz_add = GUICtrlCreateButton("Verzeichnis hinzufügen", 116, 126, 155, 25)
GUICtrlSetState(-1, $GUI_HIDE)
GUISetState(@SW_SHOW)
#endregion ### END Koda GUI section ###
Global $folder
Global $foldera
Global $Ausgabefile = StringReplace($folder & "_" & _DateTimeFormat(_NowCalc(), 2) & ".log", "\", "_")
Global $Combifile = 'User_in_Verzeichnisen_Rechte.txt'
$folderoutput = GUICtrlRead($speichern_unter)
If FileExists($folderoutput & "\" & $Combifile) Then FileDelete($folderoutput & "\" & $Combifile)
While 1
	Local $nMsg = GUIGetMsg()
	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			$folderoutput = GUICtrlRead($speichern_unter)
			FileDelete(@TempDir & '\AS*')
			Exit
		Case $Cancle
			$folderoutput = GUICtrlRead($speichern_unter)
			FileDelete(@TempDir & '\AS*')
			Exit
		Case $Start
			$folder = FileSelectFolder("Ordner wählen", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}", 4)
;~ 			$folder = FileSelectFolder("Ordner wählen", "Y:\", 4)
			Global $lfolder = $folder
			$folderoutput = GUICtrlRead($speichern_unter)
			Global $AD_DOM = _AD_Call_DOM()
			$Ausgabefile = StringReplace($folder & "_" & _DateTimeFormat(_NowCalc(), 2) & ".log", "\", "_")
			$Ausgabefile = StringTrimLeft($Ausgabefile, 3)
			$Ausgabefile = _Folder_List($folder)
			If Not $Ausgabefile = 0 Then
				GUICtrlSetState($Start, $GUI_HIDE)
				GUICtrlSetState($Label3, $GUI_SHOW)
				GUICtrlSetState($View_Rep_BTTN, $GUI_SHOW)
				GUICtrlSetState($Verz_add, $GUI_SHOW)
				GUICtrlSetData($Report_Anz_liste, $Ausgabefile, $Ausgabefile)
				GUICtrlSetState($Report_Anz_liste, $GUI_SHOW)
			Else
				MsgBox(64, "ERROR", "Leider gibt es keine auswertbare Daten!!")
			EndIf
		Case $View_Rep_BTTN
			$folderoutput = GUICtrlRead($speichern_unter)
			Local $auswahl = GUICtrlRead($Report_Anz_liste)
			If FileExists($Ausgabefile) Then
				If FileExists(@ProgramFilesDir & "\Notepad++\notepad++.exe") Then
					Run(@ProgramFilesDir & "\Notepad++\notepad++.exe " & $Ausgabefile)
				Else
					Run("Notepad.exe " & $Ausgabefile)
				EndIf
			EndIf
		Case $Verz_add
			$folder = FileSelectFolder("Ordner wählen", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}", 4, $lfolder)
			$lfolder = $folder
			$folderoutput = GUICtrlRead($speichern_unter)
			Global $AD_DOM = _AD_Call_DOM()
			Local $logfile = _FolderACL($foldera)
			Global $grpfile = _Gruppen_Berechtigung_auslesen($AD_DOM, $folder, $logfile)
			Local $Combifil = _File_combi($grpfile)
			GUICtrlSetData($Report_Anz_liste, $Combifil, $Combifil)
	EndSwitch
WEnd
Func _Folder_List($folder)
;~ 	Local $flag = MsgBox(52, "Verzeichnisauswahl", "Wollen sie alle Unterverzeichnisse auswählen?")
	Local $flag = 6
	Select
		Case $flag = 6 ; yes
			Local $aFileList = _FolderListee($folder)
;~ 			_ArrayDisplay($aFileList)
			If IsArray($aFileList) Or Not $aFileList[1] = "" Then
				For $a = 1 To $aFileList[0] - 1
					Local $logf = _FolderACL($aFileList[$a])
					$file = FileOpen($logfile1, 257)
					If $file = -1 Then
						MsgBox(0, "Fehler", "Die Datei $logfile1 konnte nicht geöffnet werden.")
						Exit
					EndIf
					FileWrite($file, $logf)
					FileClose($file)
;~ 					RunWait("Notepad.exe " & $logfile1)
					$element = _Gruppen_Berechtigung_auslesen($AD_DOM, '"' & $aFileList[$a] & '"', $logfile1)
					If FileExists($logfile1) Then FileDelete($logfile1)
				Next
				$Ausgabefil = _File_combi($element)
				Return $Ausgabefil
			Else
				MsgBox(64, "ERROR", "Leider gibt es keine Unterverzeichnisse!!")
			EndIf
		Case $flag = 7 ; no
			$logfile = _FolderACL($foldera)
			Global $grpfile = _Gruppen_Berechtigung_auslesen($AD_DOM, $folder, $logfile)
			FileMove($grpfile, $folderoutput & "\" & $Ausgabefile, 1)
			Return $folderoutput & "\" & $Ausgabefile
	EndSelect
EndFunc   ;==>_Folder_List
Func _File_combi($grpfile)
	Local $Combi = FileOpen($folderoutput & "\" & $Combifile, 10)
	Local $grpfile_alt = FileRead($folderoutput & "\" & $Ausgabefile)
	Local $grpfile_neu = FileRead($grpfile)
	FileWrite($Combi, $grpfile_alt)
	FileWrite($Combi, $grpfile_neu)
	FileClose($Combi)
	FileMove($folderoutput & "\" & $Combifile, $folderoutput & "\" & $Ausgabefile, 1)
	Return $folderoutput & "\" & $Ausgabefile
EndFunc   ;==>_File_combi
Func _Gruppen_Berechtigung_auslesen($AD_DOM, $folder, $logfile)
	#region	; erstes einlesen des Logfiles, es sind alle \ konvertiert in *
	Global $DOM_LEN = StringLen($AD_DOM) + 1
	Dim $aRecords, $aTMP[1], $aTMPa, $aTMPb, $aUVWSTRG
;~ 	RunWait("Notepad.exe " & $logfile)
;~ 	_ReplaceStringInFile($logfile, $folder, $folder & @CRLF)
	_ReplaceStringInFile($logfile, "NT AUTHORITY\SYSTEM", "xxxxxxx")
	_ReplaceStringInFile($logfile, "UVW\Administrator", "xxxxxxx")
	_ReplaceStringInFile($logfile, "UVW\Domain Admins", "xxxxxxx")
	_ReplaceStringInFile($logfile, "BUILTIN\Administrators", "xxxxxxx")
	_ReplaceStringInFile($logfile, ", Synchronize", "")
	_ReplaceStringInFile($logfile, "Allow", ",Allow,")
	_ReplaceStringInFile($logfile, "\", ',')
	_ReplaceStringInFile($logfile, "FullControl", "Voller Zugriff Admin")
	_ReplaceStringInFile($logfile, "Modify", "Voller Zugriff")
	_ReplaceStringInFile($logfile, "ReadAndExecute", "Nur Lesen")
	If Not _FileReadToArray($logfile, $aRecords) Then
		MsgBox(4096, "Fehler", "Fehler beim Einlesen der Datei in das Array!" & @CRLF & "Fehlercode: " & @error)
		Exit
	EndIf
	#endregion	; erstes einlesen des Logfiles, es sind alle \ konvertiert in *
	#region 	; entfernen der ungewünschten auswertungs-Usereinträge
	_ArrayDelete($aRecords, 0)
	_ArrayInsert($aRecords, 0, UBound($aRecords) + 1)
	_ArraySort($aRecords, 0, 1)
	For $x = 1 To $aRecords[0]
		If Not @error Then
			$I = 0
			While $I <= $aRecords[0]
				$iIndex = _ArraySearch($aRecords, 'xxxxxxx', 0, 0, 0, 1)
;~ 				MsgBox(0, "", $iIndex & " " & @error)
				If Not @error Then _ArrayDelete($aRecords, $iIndex)
;~
				$I = $I + 1
			WEnd
		EndIf
		_ArrayDelete($aRecords, 0)
		$iIndex = UBound($aRecords); anzahl der rows im array
		_ArrayInsert($aRecords, 0, $iIndex + 1)
;~ 			_ArrayDisplay($aRecords)
	Next
	#endregion 	; entfernen der ungewünschten auswertungs-Usereinträge
	#region	; Leere Zeilen im Array entfernen
;~ 	_ArrayDisplay($aTMP)
	#endregion	; Leere Zeilen im Array entfernen
	Global $caclstemp = FileOpen($tempfile, 1)
	; Schreibe in das Logfile  die MasterZeile
	Local $caclsresult = "------------------------------------------------------------------- " & @CRLF & "Verzeichnis: " & @TAB & @TAB & $folder & @CRLF
	#region ; abändern der Perm-Bezeichnung auf Leserlich
	FileWriteLine($caclstemp, $caclsresult)
	$iIndex = UBound($aRecords)
	For $I = 1 To $iIndex - 1
		$aTMPa = StringSplit($aRecords[$I], ',')
		_ArrayDelete($aTMPa, 0)
		$iIndex = UBound($aTMPa); anzahl der rows im array
		_ArrayInsert($aTMPa, 0, $iIndex + 1)
;~ 		_ArrayDisplay($aTMPa)
		If Not IsArray($aTMPa) Or $aTMPa[1] = "" Then
			MsgBox(4096, "AAAis not a array", $aTMPa)
			Exit
		EndIf
		#endregion ; abändern der Perm-Bezeichnung auf Leserlich
;~ 		MsgBox(4096, $folder, $aTMPa[2])
		Local $arights = _ArraySearch($aTMPa, 'allow') + 1
		Local $aOrg = _ArraySearch($aTMPa, 'UVW') + 1
		$caclsresult = "Berechtigungsgruppe (Intern): " & @TAB & $aTMPa[$aOrg] _
				 & @CRLF & "Berechtigung: " & @TAB & $aTMPa[$arights] & @CRLF & "User: "
;~ 		MsgBox(4096, "$aTMPa[$aOrg]", $aTMPa[$aOrg])
		FileWriteLine($caclstemp, $caclsresult)
		Local $grp = StringStripWS($aTMPa[$aOrg], 3)
		Local $aMembers = _Grp2USR_konvert($grp)
;~ 		_ArrayDisplay($aMembers)
		If IsArray($aMembers) Then
			; löse die Mitgliderliste auf
			If Not $aMembers[0] = 0 Then
				For $m = 1 To UBound($aMembers) - 1
					_AD_Open()
					Local $na = _AD_GetObjectAttribute($aMembers[$m], "DisplayName")
					_AD_Close()
					$aTMPb = StringSplit($aMembers[$m], ",")
					$aTMPb[1] = StringTrimLeft($aTMPb[1], 3)
					Local $taab = @TAB
					If StringLen($na) < 16 Then $taab = @TAB & @TAB
					FileWriteLine($caclstemp, $na & $taab & " (" & $aTMPb[1] & ") ")
				Next
			Else
				FileWriteLine($caclstemp, "Kein User")
			EndIf
		Else
			FileWriteLine($caclstemp, "Kein User")
		EndIf
		FileWriteLine($caclstemp, @CRLF)
;~ 		_ArrayDelete($aRecords, 1)
	Next
	FileClose($caclstemp)
	Return $tempfile
EndFunc   ;==>_Gruppen_Berechtigung_auslesen
Func _AD_Call_DOM()
	_AD_Open()
	Global $aDC = _AD_ListDomainControllers()
	_AD_Close()
	Local $bDC = StringSplit($aDC[1][2], ".")
	Local $AD_DOM = $bDC[2]
	Return $AD_DOM
EndFunc   ;==>_AD_Call_DOM
Func _Grp2USR_konvert($Gruppe)
;~ 	MsgBox(0, "$Gruppe", $Gruppe)
	Local $aGruppe
	_AD_Open()
	If @error > 0 Then
		MsgBox(64, "Active Directory Functions ", "The current user is not a member of any group")
	Else
		Local $aGruppe = _AD_GetGroupMembers($Gruppe)
;~ 		Local $aGruppe = _AD_GetGroupMembers('oe_pers_admin')
		If @error > 0 Then
			MsgBox(64, "Active Directory Functions - Example 1", "The group '" & $Gruppe & "' has no members")
		EndIf
	EndIf
	_AD_Close()
	Return $aGruppe
EndFunc   ;==>_Grp2USR_konvert
Func _Run_DOS($COMMAND)
	$foo = Run(@ComSpec & " /k chcp 850 && " & $COMMAND & " && Exit", '', @SW_HIDE, $STDOUT_CHILD)
	$line = ""
	While 1
		$line &= StdoutRead($foo)
		If @error Then ExitLoop
	WEnd
	Return $line
EndFunc   ;==>_Run_DOS
Func _Run_PS($COMMAND)
	Local $foo = Run(@SystemDir & '\WindowsPowerShell\v1.0\powershell.exe ' & $COMMAND, '', @SW_HIDE, $STDOUT_CHILD)
	Local $line = ""
	While 1
		$line &= StdoutRead($foo)
		If @error Then ExitLoop
	WEnd
;~ 	MsgBox(0, "", $line)
	Return $line
EndFunc   ;==>_Run_PS
Func _FolderListee($dire)
;~ Local $dire ="Y:\Personalabteilung"
	Local $aFileList
	Local $aRet
	If FileExists(@TempDir & '\dire.txt') Then FileDelete(@TempDir & '\dire.txt')
	_Run_PS('get-childitem "' & $dire & '" | Where-Object { $_.PSIsContainer } | ForEach-Object { $_.FullName}|out-file -filepath "' & @TempDir & '\dire.txt" -encoding "UNICODE" -Append ')
	_FileReadToArray(@TempDir & '\dire.txt', $aFileList)
	$aRet = _ArrayRemoveBlanks($aFileList)
	Return $aRet
EndFunc   ;==>_FolderListee
Func _FolderACL($dire)
;~ Local $dire ="Y:\Personalabteilung\Schreibbüro"
	Local $aFileList
	Local $ret = ""
	If FileExists(@TempDir & '\ACL.txt') Then FileDelete(@TempDir & '\ACL.txt')
	_Run_PS("(Get-Acl -path '" & $dire & "').AccessToString|out-file -filepath " & @TempDir & "\ACL.txt -encoding 'UNICODE' -Append ")
	_FileReadToArray(@TempDir & '\ACL.txt', $aFileList)
	$aRet = _ArrayRemoveBlanks($aFileList)
	_ArrayDelete($aRet, 0)
	For $S = 0 To UBound($aRet) - 1
		$ret = $ret & $aRet[$S] & @CRLF
	Next
	Return $ret
EndFunc   ;==>_FolderACL
; Removes Elemets that contain only whitespace characters and returns the new array.
; The count of the return is at $aRet[0].
Func _ArrayRemoveBlanks($aID)
	Local $sTmp = ''
	Local $aTMP
	For $I = 0 To UBound($aID) - 1
		If StringRegExpReplace($aID[$I], "\s", "") Then $sTmp &= $aID[$I] & Chr(0)
	Next
	$aTMP = StringSplit(StringTrimRight($sTmp, 1), Chr(0))
	_ArrayDelete($aTMP, 1)
	$aTMP[0] = UBound($aTMP)
	Return $aTMP
EndFunc   ;==>_ArrayRemoveBlanks
