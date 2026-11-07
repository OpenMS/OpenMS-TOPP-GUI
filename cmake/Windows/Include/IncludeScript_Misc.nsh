##############################
### register filetypes (code borrowed from VLC project)
##
## The associations are written to Software\Classes of the registry hive of the install
## mode (SHCTX: HKLM for all users, HKCU for the current user), so that a current-user
## installation needs no administrator rights for them and the uninstaller of the same mode
## finds them again.

;; Registers one extension $R0 (e.g. ".mzData") for the program $R1 (e.g. TOPPView)
Function RegisterExtension
  ; back up the old value for the extension
  ReadRegStr $1 SHCTX "Software\Classes\$R0" ""
  StrCmp $1 "" NoBackup
    StrCmp $1 "OPENMS$R0" "NoBackup"
    WriteRegStr SHCTX "Software\Classes\$R0" "OPENMS.backup" $1
NoBackup:
  WriteRegStr SHCTX "Software\Classes\$R0" "" "OPENMS$R0"
  WriteRegStr SHCTX "Software\Classes\OPENMS$R0" "" "OPENMS data file ($R0)"
  WriteRegStr SHCTX "Software\Classes\OPENMS$R0\shell\open\command" "" '"$INSTDIR\bin\$R1.exe" "%1"'
  WriteRegStr SHCTX "Software\Classes\OPENMS$R0\DefaultIcon" "" '"$INSTDIR\share\OpenMS\OpenMS_$R1.ico",0'
FunctionEnd

;; Removes one extension that OpenMS owns, restoring the backed up value.
Function un.RegisterExtension
  ReadRegStr $1 SHCTX "Software\Classes\$R0" ""
  StrCmp $1 "OPENMS$R0" 0 NoOwn ; only do this if we own it
    ; Read the old value from Backup
    ReadRegStr $1 SHCTX "Software\Classes\$R0" "OPENMS.backup"
    StrCmp $1 "" 0 Restore ; if backup="" then delete the whole key
      DeleteRegKey SHCTX "Software\Classes\$R0"
    Goto NoOwn
Restore:
      WriteRegStr SHCTX "Software\Classes\$R0" "" $1
      DeleteRegValue SHCTX "Software\Classes\$R0" "OPENMS.backup"
NoOwn:
    DeleteRegKey SHCTX "Software\Classes\OPENMS$R0" ;Delete key with association settings
FunctionEnd

!macro RegisterExtensionSection EXT PROGRAMEXE
  Section ${EXT}
    SectionIn 1 3
    Push $R0
    Push $R1
    StrCpy $R0 ${EXT}
    StrCpy $R1 ${PROGRAMEXE}
    Call RegisterExtension
    Pop $R1
    Pop $R0
  SectionEnd
!macroend

!macro UnRegisterExtensionSection EXT PROGRAMEXE
  Push $R0
  Push $R1
  StrCpy $R0 ${EXT}
  StrCpy $R1 ${PROGRAMEXE}
  Call un.RegisterExtension
  Pop $R1
  Pop $R0
!macroend
