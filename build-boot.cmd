REM @ECHO OFF
CD %~dp0
cd ssdw-boot
c:\pythons\python38-10-32\python "build-exe.py"
rd /s /q ..\binaries\ssdw-boot
move dist ..\binaries\ssdw-boot
pause
