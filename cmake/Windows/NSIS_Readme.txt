The NSIS script of the Windows installer of the OpenMS GUI (NSIS.template.in, configured by
CPack, see cmake/package_nsis.cmake) and what it needs besides a standard NSIS 3 installation:

  Include/NsisMultiUser.nsh, NsisMultiUserLang.nsh  all-users/current-user installation (NsisMultiUser)
  Include/UAC.nsh, Plugins/x86-unicode/UAC.dll      elevation, used by NsisMultiUser (UAC plug-in, UAC_License.txt)
  Include/AdvUninstLog2.nsh                         uninstall log: the uninstaller removes only the logged files
  Include/IncludeScript_Misc.nsh                    file associations
  images/, *.ico                                    installer graphics and icons

Tested with NSIS 3.09 (the standard build; the GUI installer needs neither the large-string
build nor UltraModernUI, which the core installer uses).
