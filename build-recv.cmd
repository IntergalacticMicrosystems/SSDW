REM @ECHO OFF
cd ssdwrecv
"C:\Program Files\NASM\nasm.exe" ssdw.asm -O0 -fbin -l ssdw.lst -Lp -ossdw.com
copy ssdw.com ..\binaries
pause
