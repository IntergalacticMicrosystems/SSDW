REM @ECHO OFF
CD %~dp0
cd ssdw-send
c:\pythons\python38-10-32\python "build-exe.py"
rd /s /q ..\binaries\ssdw-send
move dist ..\binaries\ssdw-send
pause
