@ECHO OFF
CD %~dp0
call build-recv.cmd
CD %~dp0
call build-send.cmd
CD %~dp0
tar -a -c -f binaries-DOS-and-WIN7-32.zip binaries
pause
